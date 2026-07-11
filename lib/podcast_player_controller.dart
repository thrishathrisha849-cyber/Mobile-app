import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'podcast_service.dart';

/// Shared playback controller for the Podcast module.
///
/// A single app-lifetime instance (no state-management package exists in
/// this app) so the mini player and playback position survive navigation
/// between the podcast home and its "See All"/series screens.
///
/// Also observes app lifecycle (`WidgetsBindingObserver`) so the current
/// position is saved immediately when the app is backgrounded, not just on
/// the periodic autosave tick or an explicit pause.
class PodcastPlayerController extends ChangeNotifier
    with WidgetsBindingObserver {
  PodcastPlayerController._internal() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final PodcastPlayerController instance =
      PodcastPlayerController._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final PodcastService _service = PodcastService.instance;

  Map<String, dynamic>? _currentEpisode;
  List<Map<String, dynamic>> _queue = [];
  String? _anonymousUserId;

  /// Set by the Podcast home screen so it can refresh its "Continue
  /// Listening" list the instant an episode finishes, instead of only on
  /// the next manual refresh/navigation.
  VoidCallback? onEpisodeCompleted;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _saveCurrentProgress();
    }
  }

  Timer? _progressSaveTimer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  Map<String, dynamic>? get currentEpisode => _currentEpisode;
  bool get hasEpisode => _currentEpisode != null;
  bool get isPlaying => _audioPlayer.playing;

  Duration get position => _audioPlayer.position;
  Duration get duration =>
      _audioPlayer.duration ??
      Duration(seconds: (_currentEpisode?['durationSecs'] as int?) ?? 0);

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  Future<void> _ensureUserId() async {
    _anonymousUserId ??= await _service.getOrCreateAnonymousUserId();
  }

  /// Loads and plays [episode]. If [queue] is provided it becomes the list
  /// used for skip next/previous (e.g. the currently filtered episode list).
  Future<void> loadAndPlay(
    Map<String, dynamic> episode, {
    List<Map<String, dynamic>>? queue,
    int startPositionSeconds = 0,
  }) async {
    await _ensureUserId();
    _saveCurrentProgress();

    _currentEpisode = episode;
    if (queue != null) _queue = queue;
    notifyListeners();

    final audioUrl = episode['audioUrl'] as String? ?? '';
    if (audioUrl.isEmpty) return;

    try {
      await _audioPlayer.setUrl(audioUrl);
      if (startPositionSeconds > 0) {
        await _audioPlayer.seek(Duration(seconds: startPositionSeconds));
      }
      await _audioPlayer.play();
      _startAutosaveTimer();
      _listenForCompletion();
    } catch (e) {
      debugPrint('PodcastPlayerController: failed to load audio: $e');
    }
    notifyListeners();
  }

  void _listenForCompletion() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        _handleEpisodeCompleted();
      }
    });
  }

  Future<void> _handleEpisodeCompleted() async {
    final episode = _currentEpisode;
    if (episode != null && _anonymousUserId != null) {
      await _service.markCompleted(
        userId: _anonymousUserId!,
        episodeId: episode['id'] as String,
        totalDurationSeconds: duration.inSeconds,
      );
      onEpisodeCompleted?.call();
    }
    if (_queue.length > 1) {
      await skipNext();
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentEpisode == null) return;
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      _progressSaveTimer?.cancel();
      _saveCurrentProgress();
    } else {
      await _audioPlayer.play();
      _startAutosaveTimer();
    }
    notifyListeners();
  }

  Future<void> seekForward10() async {
    final target = _audioPlayer.position + const Duration(seconds: 10);
    final maxDuration = _audioPlayer.duration ?? target;
    await _audioPlayer.seek(target > maxDuration ? maxDuration : target);
  }

  Future<void> seekBack10() async {
    final target = _audioPlayer.position - const Duration(seconds: 10);
    await _audioPlayer.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> seekTo(Duration newPosition) async {
    await _audioPlayer.seek(newPosition);
  }

  Future<void> skipNext() async {
    if (_currentEpisode == null || _queue.isEmpty) return;
    final currentId = _currentEpisode!['id'];
    final index = _queue.indexWhere((e) => e['id'] == currentId);
    if (index == -1) return;
    final nextIndex = (index + 1) % _queue.length;
    await loadAndPlay(_queue[nextIndex], queue: _queue);
  }

  Future<void> skipPrevious() async {
    if (_currentEpisode == null || _queue.isEmpty) return;
    final currentId = _currentEpisode!['id'];
    final index = _queue.indexWhere((e) => e['id'] == currentId);
    if (index == -1) return;
    final prevIndex = (index - 1 + _queue.length) % _queue.length;
    await loadAndPlay(_queue[prevIndex], queue: _queue);
  }

  void _startAutosaveTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _saveCurrentProgress());
  }

  void _saveCurrentProgress() {
    final episode = _currentEpisode;
    final userId = _anonymousUserId;
    if (episode == null || userId == null) return;
    final currentSecs = _audioPlayer.position.inSeconds;
    if (currentSecs <= 0) return;
    final totalSecs = duration.inSeconds;
    // Completion is recorded exclusively by markCompleted() (called from
    // _handleEpisodeCompleted). Skipping here prevents this call — which
    // may fire right after completion, e.g. via skipNext()'s loadAndPlay()
    // flushing the outgoing episode's progress — from clobbering the
    // completed flag back to false with a stale "in progress" row.
    if (totalSecs > 0 && currentSecs >= totalSecs) return;
    _service.saveProgress(
      userId: userId,
      episodeId: episode['id'] as String,
      currentPositionSeconds: currentSecs,
      totalDurationSeconds: duration.inSeconds,
    );
  }

  /// Persists the current position immediately (e.g. when the user
  /// navigates away from the podcast module) instead of waiting for the
  /// periodic autosave timer.
  void saveProgressNow() => _saveCurrentProgress();
}
