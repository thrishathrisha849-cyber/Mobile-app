import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'assessment_service.dart';

enum AssessmentAudioState { idle, loading, playing, paused, ended, unavailable, error }

/// Single-clip audio playback for the question currently on screen, modeled
/// on podcast_player_controller.dart's one-AudioPlayer-wrapped-in-a-
/// ChangeNotifier shape, but scoped to one question at a time instead of a
/// queue. Priority: (1) admin-uploaded clip (a base64 data: URI embedded on
/// the question), (2) cached neural TTS (fetched from the backend). There is
/// no browser-speech-equivalent third tier on mobile (no built-in Flutter
/// TTS dependency) — a question with neither becomes [unavailable], which
/// the UI should render as "no audio for this question" rather than an
/// error. (See the migration plan's audio-fallback-tier decision.)
class AssessmentAudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  AssessmentAudioState state = AssessmentAudioState.idle;
  String? _activeQuestionId;
  String? _errorMessage;
  String get errorMessage => _errorMessage ?? 'Audio could not be played.';

  AssessmentAudioController() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        state = AssessmentAudioState.ended;
        notifyListeners();
      }
    });
  }

  String? get activeQuestionId => _activeQuestionId;

  Future<File> _writeTempFile(List<int> bytes, String ext) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/assessment_audio_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Starts playback for [question] (from the start), stopping anything
  /// else first. `question` is the raw Map returned by GET /assessment/
  /// questions — fields read: `_id`, `hasAudio`, `audioUrl` (a data: URI),
  /// `neuralAudio` (bool flag).
  Future<void> playQuestion(Map<String, dynamic> question, String token) async {
    await stop();
    final qid = question['_id'] as String;
    _activeQuestionId = qid;
    state = AssessmentAudioState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      File? file;
      final audioUrl = question['audioUrl'] as String?;
      if (question['hasAudio'] == true && audioUrl != null && audioUrl.isNotEmpty) {
        file = await _dataUriToFile(audioUrl);
      } else if (question['neuralAudio'] == true) {
        final bytes = await AssessmentService.instance.fetchQuestionAudio(qid, token);
        if (bytes != null) file = await _writeTempFile(bytes, 'mp3');
      }

      if (_activeQuestionId != qid) return; // superseded by a newer call
      if (file == null) {
        state = AssessmentAudioState.unavailable;
        notifyListeners();
        return;
      }
      await _player.setFilePath(file.path);
      if (_activeQuestionId != qid) return;
      await _player.play();
      state = AssessmentAudioState.playing;
      notifyListeners();
    } catch (e) {
      debugPrint('[AssessmentAudioController] playback failed: $e');
      if (_activeQuestionId == qid) {
        state = AssessmentAudioState.error;
        _errorMessage = 'Audio could not be played. Please try again.';
        notifyListeners();
      }
    }
  }

  Future<File> _dataUriToFile(String dataUri) async {
    final commaIdx = dataUri.indexOf(',');
    final header = dataUri.substring(5, commaIdx); // after "data:"
    final base64Part = dataUri.substring(commaIdx + 1);
    final bytes = base64Decode(base64Part);
    final ext = header.contains('wav') ? 'wav' : (header.contains('ogg') ? 'ogg' : 'mp3');
    return _writeTempFile(bytes, ext);
  }

  Future<void> togglePause() async {
    if (state == AssessmentAudioState.playing) {
      await _player.pause();
      state = AssessmentAudioState.paused;
      notifyListeners();
    } else if (state == AssessmentAudioState.paused || state == AssessmentAudioState.ended) {
      if (state == AssessmentAudioState.ended) await _player.seek(Duration.zero);
      await _player.play();
      state = AssessmentAudioState.playing;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _activeQuestionId = null;
    try {
      await _player.stop();
    } catch (_) {
      /* ignore */
    }
    state = AssessmentAudioState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
