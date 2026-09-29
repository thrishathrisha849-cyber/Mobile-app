import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum AiRecordingState { idle, listening, paused, stopped }

/// Voice input for Content Buddy AI (Phase E).
///
/// A single app-lifetime instance (same shape as `PodcastPlayerController`)
/// wrapping `speech_to_text`: idle/listening/paused/stopped state, a
/// duration ticker, and the sound-level stream that drives the waveform.
///
/// **Owns transcription itself** — `speech_to_text` streams recognized text
/// directly from the OS recognizer, so there's no separate
/// "recording -> file -> upload -> transcribe" pipeline and no audio file
/// ever exists on disk to clean up (FR-007, FR-008: only the transcript,
/// never raw audio, ever leaves the device or the recognizer session).
///
/// `speech_to_text` has no native pause/resume — pausing here means
/// finalizing the current listen segment (via `stop()`) and accumulating its
/// text; resuming starts a fresh listen segment. The combined transcript is
/// simply the join of all finalized segments plus the live partial result.
class AiRecordingController extends ChangeNotifier {
  AiRecordingController._internal();
  static final AiRecordingController instance =
      AiRecordingController._internal();

  static const Duration maxDuration = Duration(minutes: 3);
  static const Duration _pauseFor = Duration(seconds: 5);

  final SpeechToText _speech = SpeechToText();

  AiRecordingState _state = AiRecordingState.idle;
  String _accumulatedText = '';
  String _liveSegmentText = '';
  double _soundLevel = 0.0;
  int _elapsedSeconds = 0;
  Timer? _ticker;
  bool _capReached = false;

  /// Called once when the 3-minute cap is hit, so the UI can surface a
  /// notice alongside the auto-stop.
  VoidCallback? onCapReached;

  AiRecordingState get state => _state;
  bool get isListening => _state == AiRecordingState.listening;
  bool get isPaused => _state == AiRecordingState.paused;
  int get elapsedSeconds => _elapsedSeconds;
  double get soundLevel => _soundLevel;

  /// The best-effort transcript so far: finalized segments plus whatever
  /// partial words the recognizer currently has in flight.
  String get transcript => _joinNonEmpty([_accumulatedText, _liveSegmentText]);

  String _joinNonEmpty(List<String> parts) =>
      parts.where((p) => p.trim().isNotEmpty).join(' ').trim();

  /// Requests OS mic permission (via `speech_to_text`'s own init, which
  /// triggers it) and prepares the recognizer. The caller (T031) handles
  /// the actual permission_handler flow and denial messaging before calling
  /// this — this just confirms the recognizer itself is ready.
  Future<bool> ensureInitialized() async {
    if (_speech.isAvailable) return true;
    return _speech.initialize(
      onError: (_) => _handleSegmentEnd(),
      onStatus: (_) {},
    );
  }

  Future<bool> start() async {
    if (_state == AiRecordingState.listening) return true;
    final ready = await ensureInitialized();
    if (!ready) return false;

    _accumulatedText = '';
    _liveSegmentText = '';
    _elapsedSeconds = 0;
    _capReached = false;
    _state = AiRecordingState.listening;
    notifyListeners();
    _startTicker();
    return _listenSegment();
  }

  Future<void> pause() async {
    if (_state != AiRecordingState.listening) return;
    _ticker?.cancel();
    await _speech.stop();
    _state = AiRecordingState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != AiRecordingState.paused) return;
    _state = AiRecordingState.listening;
    notifyListeners();
    _startTicker();
    await _listenSegment();
  }

  /// Cancels the recording and discards everything — no transcript is kept.
  Future<void> cancelRecording() async {
    _ticker?.cancel();
    await _speech.cancel();
    _accumulatedText = '';
    _liveSegmentText = '';
    _elapsedSeconds = 0;
    _state = AiRecordingState.idle;
    notifyListeners();
  }

  /// Stops recording and returns the final transcript for the caller to
  /// show in an editable field before send (FR-007). Returns '' if nothing
  /// was recognized.
  Future<String> stopAndFinish() async {
    _ticker?.cancel();
    if (_state == AiRecordingState.listening) {
      await _speech.stop();
      // Give the platform's final-result timer a moment to deliver the last
      // finalResult callback before we read the accumulated transcript.
      await Future.delayed(const Duration(milliseconds: 300));
    }
    final result = transcript;
    _state = AiRecordingState.stopped;
    notifyListeners();
    return result;
  }

  /// Resets back to idle after the caller is done with the reviewed
  /// transcript (sent or discarded).
  void reset() {
    _ticker?.cancel();
    _accumulatedText = '';
    _liveSegmentText = '';
    _elapsedSeconds = 0;
    _soundLevel = 0.0;
    _state = AiRecordingState.idle;
    notifyListeners();
  }

  Future<bool> _listenSegment() async {
    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          pauseFor: _pauseFor,
        ),
      );
      return true;
    } catch (_) {
      _handleSegmentEnd();
      return false;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _liveSegmentText = result.recognizedWords;
    if (result.finalResult) {
      _accumulatedText = _joinNonEmpty([_accumulatedText, _liveSegmentText]);
      _liveSegmentText = '';
      _handleSegmentEnd();
    }
    notifyListeners();
  }

  /// A segment ended on its own (e.g. the device's built-in pause timeout)
  /// while we're still meant to be "listening" (not paused/cancelled by the
  /// user) — start a fresh segment so the user doesn't have to tap Resume
  /// just because the OS recognizer paused itself. A short delay avoids
  /// restarting the native session in the same tick it just finished on,
  /// which some platform implementations reject.
  void _handleSegmentEnd() {
    if (_state != AiRecordingState.listening) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_state == AiRecordingState.listening) _listenSegment();
    });
  }

  void _onSoundLevelChange(double level) {
    _soundLevel = level;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
      if (_elapsedSeconds >= maxDuration.inSeconds && !_capReached) {
        _capReached = true;
        _ticker?.cancel();
        // The caller's onCapReached handler is expected to call
        // stopAndFinish() itself (mirroring the Stop button path) so there
        // is exactly one place that finalizes the transcript.
        onCapReached?.call();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _speech.cancel();
    super.dispose();
  }
}
