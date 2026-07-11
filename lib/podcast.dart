import 'dart:io';
import 'package:flutter/material.dart';
import 'main.dart';
import 'profile.dart';
import 'podcast_service.dart';
import 'podcast_player_controller.dart';
import 'notification_service.dart';

const Color _kPodcastRed = Color(0xFFE50914);

// ────────────────────────────────────────────────────────────────
// Shared building blocks (reused by the home screen, "See All"
// screens and the series detail screen so the look stays identical
// everywhere audio content is listed or played).
// ────────────────────────────────────────────────────────────────

PreferredSizeWidget buildPodcastAppBar(BuildContext context,
    {Widget? leading}) {
  NotificationBadge.instance.ensureLoaded();
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0.0,
    leading: leading ??
        Builder(
          builder: (ctx) => IconButton(
            icon:
                Icon(Icons.menu_rounded, color: context.textColor, size: 24.0),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
    title: const AppLogo.appBar(),
    centerTitle: true,
    actions: [
      Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.scaffoldBg.withOpacity(0.3),
            border: Border.all(color: context.borderCol),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                ).createShader(bounds),
                child: const Icon(Icons.whatshot_rounded,
                    color: Colors.white, size: 14.0),
              ),
              const Positioned(
                bottom: 1.5,
                child: Text('12',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12.0),
      IconButton(
        icon: AnimatedBuilder(
          animation: NotificationBadge.instance,
          builder: (context, _) {
            final count = NotificationBadge.instance.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined,
                    color: context.textColor, size: 22.0),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2.0),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      decoration: const BoxDecoration(
                          color: _kPodcastRed, shape: BoxShape.circle),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.0,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        onPressed: () {
          Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()))
              .then((_) => NotificationBadge.instance.refresh());
        },
      ),
      GestureDetector(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()));
        },
        child: Container(
          width: 28.0,
          height: 28.0,
          margin: const EdgeInsets.only(right: 16.0),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kPodcastRed, width: 1.0)),
          child: ProfileScreen.profileImagePath != null
              ? ClipOval(
                  child: Image.file(File(ProfileScreen.profileImagePath!),
                      width: 28.0, height: 28.0, fit: BoxFit.cover),
                )
              : ClipOval(
                  child: Image.network(
                    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                    width: 28.0,
                    height: 28.0,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 28.0,
                      height: 28.0,
                      color: context.cardBg,
                      child: Icon(Icons.person,
                          color: context.subTextColor, size: 16.0),
                    ),
                  ),
                ),
        ),
      ),
    ],
  );
}

Widget _networkCover(
  BuildContext context,
  String? url, {
  required double width,
  required double height,
  required double radius,
}) {
  final placeholder = Container(
    width: width,
    height: height,
    color: context.cardBg,
    child: Icon(Icons.podcasts_rounded,
        color: context.subTextColor, size: width * 0.35),
  );
  if (url == null || url.isEmpty) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius), child: placeholder);
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (context, error, stackTrace) => placeholder,
    ),
  );
}

Widget buildPodcastCategoryChip(
    BuildContext context, String label, bool isSelected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isSelected ? _kPodcastRed : context.cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
            color: isSelected ? Colors.transparent : context.borderCol),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : context.subTextColor,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Widget buildPodcastContinueListeningCard(
    BuildContext context, Map<String, dynamic> item,
    {required VoidCallback onPlay}) {
  final double progress =
      ((item['progress'] as num?) ?? 0.0).toDouble().clamp(0.0, 1.0);
  return GestureDetector(
    // Tapping anywhere on the card (not just the small play icon) resumes
    // this episode from its saved position.
    onTap: onPlay,
    child: Container(
      width: 220.0,
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          _networkCover(context, item['cover'] as String?,
              width: 48.0, height: 48.0, radius: 8.0),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (item['title'] ?? '') as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.textColor,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3.0),
                Text(
                  [
                    if ((item['speaker'] as String?)?.trim().isNotEmpty == true)
                      item['speaker'] as String,
                    (item['timeLeft'] ?? '') as String,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.subTextColor, fontSize: 10.0),
                ),
                const SizedBox(height: 6.0),
                Container(
                  width: double.infinity,
                  height: 2.5,
                  decoration: BoxDecoration(
                      color: context.borderCol,
                      borderRadius: BorderRadius.circular(1.25)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                          color: _kPodcastRed,
                          borderRadius: BorderRadius.circular(1.25)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration:
                BoxDecoration(color: context.borderCol, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
                color: _kPodcastRed, size: 16.0),
          ),
        ],
      ),
    ),
  );
}

Widget buildPodcastEpisodeItem(
  BuildContext context,
  Map<String, dynamic> episode, {
  required VoidCallback onPlay,
  VoidCallback? onMore,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12.0),
    padding: const EdgeInsets.all(12.0),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(12.0),
      border: Border.all(color: context.borderCol),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _networkCover(context, episode['cover'] as String?,
            width: 54.0, height: 54.0, radius: 8.0),
        const SizedBox(width: 14.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (episode['title'] ?? '') as String,
                style: TextStyle(
                    color: context.textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3.0),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: context.subTextColor, fontSize: 10.5),
                  children: [
                    TextSpan(text: '${episode['info'] ?? ''} • '),
                    TextSpan(
                      text: (episode['category'] ?? '') as String,
                      style: const TextStyle(
                          color: _kPodcastRed, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                (episode['desc'] ?? '') as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.subTextColor, fontSize: 11.0, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8.0),
        Column(
          children: [
            GestureDetector(
              onTap: onPlay,
              child: const Icon(Icons.play_circle_outline_rounded,
                  color: _kPodcastRed, size: 22.0),
            ),
            const SizedBox(height: 12.0),
            GestureDetector(
              onTap: onMore ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('More options coming soon!'),
                          duration: Duration(seconds: 1)),
                    );
                  },
              child: Icon(Icons.more_vert_rounded,
                  color: context.subTextColor, size: 18.0),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildPodcastSeriesCard(BuildContext context, Map<String, dynamic> series,
    {required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 180.0,
      height: 110.0,
      margin: const EdgeInsets.only(right: 12.0),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: context.borderCol),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          children: [
            Positioned.fill(
                child: _CoverBackground(url: series['cover'] as String?)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.85)
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12.0,
              left: 12.0,
              right: 12.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (series['title'] ?? '') as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          (series['episodesCount'] ?? '') as String,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: const BoxDecoration(
                        color: _kPodcastRed, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 16.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CoverBackground extends StatelessWidget {
  final String? url;
  const _CoverBackground({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: context.cardBg,
        child: Center(
            child: Icon(Icons.podcasts_rounded,
                color: context.subTextColor, size: 28.0)),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: context.cardBg,
        child: Center(
            child: Icon(Icons.podcasts_rounded,
                color: context.subTextColor, size: 28.0)),
      ),
    );
  }
}

Widget buildPodcastLoadingState(BuildContext context) {
  return Center(
    child: CircularProgressIndicator(color: _kPodcastRed.withOpacity(0.85)),
  );
}

Widget buildPodcastEmptyState(BuildContext context, String message,
    {IconData icon = Icons.podcasts_rounded}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 40.0),
    child: Column(
      children: [
        Container(
          width: 64.0,
          height: 64.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kPodcastRed.withOpacity(0.08),
            border: Border.all(color: _kPodcastRed.withOpacity(0.3)),
          ),
          child: Icon(icon, color: _kPodcastRed, size: 28.0),
        ),
        const SizedBox(height: 14.0),
        Text(message,
            style: TextStyle(
                color: context.subTextColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget buildPodcastErrorState(
    BuildContext context, String message, VoidCallback onRetry) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64.0,
          height: 64.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kPodcastRed.withOpacity(0.08),
            border: Border.all(color: _kPodcastRed.withOpacity(0.3)),
          ),
          child: const Icon(Icons.wifi_off_rounded,
              color: _kPodcastRed, size: 28.0),
        ),
        const SizedBox(height: 14.0),
        Text(
          'Something went wrong',
          style: TextStyle(
              color: context.textColor,
              fontSize: 15.0,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6.0),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.subTextColor, fontSize: 12.5),
        ),
        const SizedBox(height: 18.0),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPodcastRed,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0)),
            padding:
                const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          ),
          child: const Text('Retry',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ────────────────────────────────────────────────────────────────
// Mini player — reactive, shared across every podcast screen via the
// PodcastPlayerController singleton so it survives navigation.
// ────────────────────────────────────────────────────────────────

class PodcastMiniPlayer extends StatelessWidget {
  const PodcastMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PodcastPlayerController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final episode = controller.currentEpisode;
        if (episode == null) return const SizedBox.shrink();

        return StreamBuilder<Duration>(
          stream: controller.positionStream,
          initialData: controller.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final total = controller.duration;
            final fraction = total.inSeconds > 0
                ? (position.inSeconds / total.inSeconds).clamp(0.0, 1.0)
                : 0.0;

            return Container(
              height: 70.0,
              decoration: BoxDecoration(
                color: context.cardBg,
                border: Border(
                    top: BorderSide(color: context.borderCol, width: 0.8)),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 2.0,
                    color: context.borderCol,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(color: _kPodcastRed),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _networkCover(context, episode['cover'] as String?,
                              width: 40.0, height: 40.0, radius: 4.0),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  (episode['title'] ?? '') as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  ((episode['seriesTitle'] ??
                                          episode['category']) ??
                                      '') as String,
                                  style: const TextStyle(
                                      color: _kPodcastRed,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          IconButton(
                            icon: Icon(Icons.replay_10_rounded,
                                color: context.subTextColor, size: 20.0),
                            onPressed: controller.seekBack10,
                          ),
                          IconButton(
                            icon: Icon(
                              controller.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: context.textColor,
                              size: 24.0,
                            ),
                            onPressed: controller.togglePlayPause,
                          ),
                          IconButton(
                            icon: Icon(Icons.forward_10_rounded,
                                color: context.subTextColor, size: 20.0),
                            onPressed: controller.seekForward10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Podcast Home Screen
// ────────────────────────────────────────────────────────────────

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final PodcastService _service = PodcastService.instance;

  bool _isLoading = true;
  bool _isEpisodesLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _episodes = [];
  List<Map<String, dynamic>> _continueListening = [];
  List<Map<String, dynamic>> _featuredSeries = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    PodcastPlayerController.instance.onEpisodeCompleted =
        _refreshContinueListening;
    _loadAll();
  }

  @override
  void dispose() {
    // Save the exact position immediately on navigating away, rather than
    // relying solely on the periodic autosave tick (playback itself keeps
    // going via the app-lifetime PodcastPlayerController/mini player).
    PodcastPlayerController.instance.saveProgressNow();
    if (PodcastPlayerController.instance.onEpisodeCompleted ==
        _refreshContinueListening) {
      PodcastPlayerController.instance.onEpisodeCompleted = null;
    }
    super.dispose();
  }

  /// Re-fetches just the Continue Listening list so a just-finished episode
  /// disappears immediately instead of lingering until the next manual
  /// refresh.
  Future<void> _refreshContinueListening() async {
    if (!mounted) return;
    final userId = await _service.getOrCreateAnonymousUserId();
    final continueListening = await _service.fetchContinueListening(userId);
    if (!mounted) return;
    setState(() => _continueListening = continueListening);
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = await _service.getOrCreateAnonymousUserId();
      final results = await Future.wait([
        _service.fetchCategories(),
        _service.fetchEpisodes(
            categoryId: _selectedCategoryId, page: 1, limit: 10),
        _service.fetchFeaturedSeries(),
        _service.fetchContinueListening(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0];
        _episodes = results[1];
        _featuredSeries = results[2];
        _continueListening = results[3];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not load podcasts. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onCategorySelected(String? categoryId) async {
    if (categoryId == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _isEpisodesLoading = true;
    });
    try {
      final episodes = await _service.fetchEpisodes(
          categoryId: categoryId, page: 1, limit: 10);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _isEpisodesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEpisodesLoading = false);
    }
  }

  Map<String, dynamic>? get _fallbackHeaderEpisode {
    if (_continueListening.isNotEmpty) return _continueListening.first;
    if (_episodes.isNotEmpty) return _episodes.first;
    return null;
  }

  void _handleHeaderPlayPause(Map<String, dynamic>? headerEpisode) {
    final controller = PodcastPlayerController.instance;
    if (controller.currentEpisode == null) {
      if (headerEpisode != null) {
        controller.loadAndPlay(
          headerEpisode,
          queue: _episodes,
          startPositionSeconds: (headerEpisode['currentSecs'] as int?) ?? 0,
        );
      }
    } else {
      controller.togglePlayPause();
    }
  }

  void _openSeeAll(PodcastSeeAllType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PodcastSeeAllScreen(type: type)),
    ).then((_) => _loadAll());
  }

  void _openSeriesDetail(String seriesId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PodcastSeriesDetailScreen(seriesId: seriesId)),
    ).then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const TbtAppDrawer(),
      appBar: buildPodcastAppBar(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.themeGradients,
          ),
        ),
        child: _isLoading
            ? buildPodcastLoadingState(context)
            : _errorMessage != null
                ? Center(
                    child: buildPodcastErrorState(
                        context, _errorMessage!, _loadAll))
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = PodcastPlayerController.instance;
    final headerEpisode = controller.currentEpisode ?? _fallbackHeaderEpisode;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final activeEpisode = controller.currentEpisode ?? headerEpisode;
        final showMiniPlayer = controller.hasEpisode;

        return Stack(
          children: [
            RefreshIndicator(
              color: _kPodcastRed,
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: EdgeInsets.only(bottom: showMiniPlayer ? 100.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderPlayer(context, activeEpisode),
                    const SizedBox(height: 24.0),
                    if (_continueListening.isNotEmpty) ...[
                      _buildSectionHeader(
                          context,
                          'Continue Listening',
                          () =>
                              _openSeeAll(PodcastSeeAllType.continueListening)),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        height: 90.0,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.only(left: 20.0, right: 8.0),
                          children: _continueListening
                              .map((item) => buildPodcastContinueListeningCard(
                                    context,
                                    item,
                                    onPlay: () => controller.loadAndPlay(
                                      item,
                                      queue: _episodes,
                                      startPositionSeconds:
                                          (item['currentSecs'] as int?) ?? 0,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 28.0),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text('Categories',
                          style: TextStyle(
                              color: context.textColor,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12.0),
                    SizedBox(
                      height: 36.0,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20.0, right: 8.0),
                        children: [
                          buildPodcastCategoryChip(
                              context,
                              'All',
                              _selectedCategoryId == null,
                              () => _onCategorySelected(null)),
                          ..._categories.map((cat) => buildPodcastCategoryChip(
                                context,
                                cat['name'] as String,
                                _selectedCategoryId == cat['id'],
                                () => _onCategorySelected(cat['id'] as String),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    _buildSectionHeader(context, 'Latest Episodes',
                        () => _openSeeAll(PodcastSeeAllType.latestEpisodes)),
                    const SizedBox(height: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _isEpisodesLoading
                          ? buildPodcastLoadingState(context)
                          : _episodes.isEmpty
                              ? buildPodcastEmptyState(
                                  context, 'No episodes found.')
                              : Column(
                                  children: _episodes
                                      .map((ep) => buildPodcastEpisodeItem(
                                            context,
                                            ep,
                                            onPlay: () =>
                                                controller.loadAndPlay(ep,
                                                    queue: _episodes),
                                          ))
                                      .toList(),
                                ),
                    ),
                    const SizedBox(height: 24.0),
                    if (_featuredSeries.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Featured Series',
                          () => _openSeeAll(PodcastSeeAllType.featuredSeries)),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        height: 110.0,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.only(left: 20.0, right: 8.0),
                          children: _featuredSeries
                              .map((series) => buildPodcastSeriesCard(
                                    context,
                                    series,
                                    onTap: () => _openSeriesDetail(
                                        series['id'] as String),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showMiniPlayer)
              const Positioned(
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: PodcastMiniPlayer()),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See All',
                style: TextStyle(
                    color: _kPodcastRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPlayer(
      BuildContext context, Map<String, dynamic>? episode) {
    final controller = PodcastPlayerController.instance;

    // Single duration source for this whole player: the live audio player's
    // own duration when this episode is the one actually loaded (the same
    // value the progress bar's total-time label uses), falling back to the
    // backend duration only when the player hasn't loaded one. Computed once
    // here so the total-time label and the duration text below the controls
    // can never disagree.
    final isActiveEpisode = controller.currentEpisode != null &&
        episode != null &&
        controller.currentEpisode!['id'] == episode['id'];
    final totalSeconds = isActiveEpisode
        ? controller.duration.inSeconds
        : ((episode?['durationSecs'] as int?) ?? 0);
    final durationLabel = PodcastService.formatClock(totalSeconds);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        boxShadow: [
          BoxShadow(
              color: _kPodcastRed.withOpacity(0.12),
              blurRadius: 30.0,
              spreadRadius: 2.0)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image — clean, no overlay content on top of it.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _CoverBackground(url: episode?['cover'] as String?),
          ),
          const SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: StreamBuilder<Duration>(
              stream: controller.positionStream,
              initialData: controller.position,
              builder: (context, snapshot) {
                final position = isActiveEpisode
                    ? (snapshot.data ?? Duration.zero)
                    : Duration.zero;
                final currentSeconds = position.inSeconds
                    .clamp(0, totalSeconds > 0 ? totalSeconds : 0);
                final isPlaying = isActiveEpisode && controller.isPlaying;

                return Column(
                  children: [
                    Container(
                      height: 28.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(45, (index) {
                          double factor = 1.0 - ((index - 22).abs() / 22.0);
                          double minH = 3.0;
                          double maxH = 26.0;
                          double h = minH +
                              (maxH - minH) *
                                  factor *
                                  (index % 3 == 0
                                      ? 0.95
                                      : (index % 2 == 0 ? 0.7 : 0.45));
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 3.2,
                            height: isPlaying
                                ? (h *
                                    (0.55 +
                                        (0.75 *
                                            (0.5 -
                                                (0.5 *
                                                    (index % 2 == 0 ? 1 : -1) *
                                                    (index % 3 == 0
                                                        ? 0.8
                                                        : 0.45))))))
                                : h,
                            decoration: BoxDecoration(
                                color: _kPodcastRed,
                                borderRadius: BorderRadius.circular(1.6)),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.0,
                        activeTrackColor: _kPodcastRed,
                        inactiveTrackColor: context.borderCol,
                        thumbColor: _kPodcastRed,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                        overlayColor: _kPodcastRed.withOpacity(0.12),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14.0),
                      ),
                      child: Slider(
                        min: 0.0,
                        max: totalSeconds > 0 ? totalSeconds.toDouble() : 1.0,
                        value: currentSeconds.toDouble().clamp(0.0,
                            totalSeconds > 0 ? totalSeconds.toDouble() : 1.0),
                        onChanged: episode == null
                            ? null
                            : (val) {
                                if (isActiveEpisode) {
                                  controller
                                      .seekTo(Duration(seconds: val.toInt()));
                                }
                              },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(PodcastService.formatClock(currentSeconds),
                              style: TextStyle(
                                  color: context.subTextColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold)),
                          Text(PodcastService.formatClock(totalSeconds),
                              style: TextStyle(
                                  color: context.subTextColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(Icons.replay_10_rounded,
                              color: context.subTextColor, size: 24.0),
                          onPressed: controller.seekBack10,
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_previous_rounded,
                              color: context.textColor, size: 28.0),
                          onPressed: controller.skipPrevious,
                        ),
                        GestureDetector(
                          onTap: () => _handleHeaderPlayPause(episode),
                          child: Container(
                            width: 52.0,
                            height: 52.0,
                            decoration: const BoxDecoration(
                                color: _kPodcastRed, shape: BoxShape.circle),
                            child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 32.0),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next_rounded,
                              color: context.textColor, size: 28.0),
                          onPressed: controller.skipNext,
                        ),
                        IconButton(
                          icon: Icon(Icons.forward_10_rounded,
                              color: context.subTextColor, size: 24.0),
                          onPressed: controller.seekForward10,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20.0),
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mic,
                                  color: _kPodcastRed, size: 14.0),
                              const SizedBox(width: 6.0),
                              Expanded(
                                child: Text(
                                  ((episode?['seriesTitle'] ??
                                          episode?['category'] ??
                                          '') as String)
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _kPodcastRed,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            (episode?['title'] ??
                                    'Select an episode to start listening')
                                as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.textColor,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w900,
                                height: 1.15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: context.subTextColor, size: 14.0),
                        const SizedBox(width: 4.0),
                        Text(
                          durationLabel,
                          style: TextStyle(
                              color: context.subTextColor,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                _ExpandableDescription(
                  text: (episode?['desc'] ??
                      'Browse categories and latest episodes below.') as String,
                  style: TextStyle(
                      color: context.subTextColor, fontSize: 13.0, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _ExpandableDescription({required this.text, required this.style});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isTruncated = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : 2,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: widget.style,
            ),
            if (isTruncated || _expanded)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _expanded ? 'less' : '... more',
                    style: const TextStyle(
                        color: _kPodcastRed,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────
// "See All" screen — Continue Listening / Latest Episodes / Featured
// Series, with search + category filter + pagination where relevant.
// ────────────────────────────────────────────────────────────────

enum PodcastSeeAllType { continueListening, latestEpisodes, featuredSeries }

class PodcastSeeAllScreen extends StatefulWidget {
  final PodcastSeeAllType type;
  const PodcastSeeAllScreen({super.key, required this.type});

  @override
  State<PodcastSeeAllScreen> createState() => _PodcastSeeAllScreenState();
}

class _PodcastSeeAllScreenState extends State<PodcastSeeAllScreen> {
  final PodcastService _service = PodcastService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _page = 1;
  static const int _pageSize = 10;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String _searchQuery = '';

  String get _title {
    switch (widget.type) {
      case PodcastSeeAllType.continueListening:
        return 'Continue Listening';
      case PodcastSeeAllType.latestEpisodes:
        return 'Latest Episodes';
      case PodcastSeeAllType.featuredSeries:
        return 'Featured Series';
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.type != PodcastSeeAllType.latestEpisodes) return;
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      if (widget.type == PodcastSeeAllType.latestEpisodes) {
        _categories = await _service.fetchCategories();
      }
      final items = await _fetchPage(1);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _hasMore = items.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this list. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    switch (widget.type) {
      case PodcastSeeAllType.continueListening:
        final userId = await _service.getOrCreateAnonymousUserId();
        return _service.fetchContinueListening(userId);
      case PodcastSeeAllType.latestEpisodes:
        return _service.fetchEpisodes(
          categoryId: _selectedCategoryId,
          page: page,
          limit: _pageSize,
          search: _searchQuery,
        );
      case PodcastSeeAllType.featuredSeries:
        return _service.fetchFeaturedSeries();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final items = await _fetchPage(nextPage);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(items);
        _hasMore = items.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || _searchController.text != value) return;
      _loadInitial();
    });
  }

  void _onCategorySelected(String? categoryId) {
    if (categoryId == _selectedCategoryId) return;
    setState(() => _selectedCategoryId = categoryId);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PodcastPlayerController.instance;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: buildPodcastAppBar(
        context,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kPodcastRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.themeGradients),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      bottom: controller.hasEpisode ? 70.0 : 0.0),
                  child: Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 4.0),
                        child: Text(_title,
                            style: TextStyle(
                                color: context.textColor,
                                fontSize: 22.0,
                                fontWeight: FontWeight.w900)),
                      ),
                      if (widget.type == PodcastSeeAllType.latestEpisodes) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 12.0),
                          child: Container(
                            height: 48.0,
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(color: context.borderCol),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded,
                                    color: context.subTextColor, size: 20.0),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(
                                        color: context.textColor,
                                        fontSize: 14.0),
                                    cursorColor: _kPodcastRed,
                                    decoration: InputDecoration(
                                      hintText: 'Search episodes...',
                                      hintStyle: TextStyle(
                                          color: context.subTextColor
                                              .withOpacity(0.6),
                                          fontSize: 13.0),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 36.0,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.only(left: 20.0, right: 8.0),
                            children: [
                              buildPodcastCategoryChip(
                                  context,
                                  'All',
                                  _selectedCategoryId == null,
                                  () => _onCategorySelected(null)),
                              ..._categories
                                  .map((cat) => buildPodcastCategoryChip(
                                        context,
                                        cat['name'] as String,
                                        _selectedCategoryId == cat['id'],
                                        () => _onCategorySelected(
                                            cat['id'] as String),
                                      )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12.0),
                      ] else
                        const SizedBox(height: 12.0),
                      Expanded(
                          child: RefreshIndicator(
                              color: _kPodcastRed,
                              onRefresh: _loadInitial,
                              child: _buildList(context))),
                    ],
                  ),
                ),
                if (controller.hasEpisode)
                  const Positioned(
                      bottom: 0.0,
                      left: 0.0,
                      right: 0.0,
                      child: PodcastMiniPlayer()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_isLoading) return buildPodcastLoadingState(context);
    if (_errorMessage != null)
      return Center(
          child: buildPodcastErrorState(context, _errorMessage!, _loadInitial));
    if (_items.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: buildPodcastEmptyState(context, 'No episodes found.'),
      );
    }

    final controller = PodcastPlayerController.instance;

    return ListView.builder(
      controller: _scrollController,
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 24.0),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child:
                Center(child: CircularProgressIndicator(color: _kPodcastRed)),
          );
        }

        final item = _items[index];
        switch (widget.type) {
          case PodcastSeeAllType.continueListening:
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: buildPodcastContinueListeningCard(
                context,
                item,
                onPlay: () => controller.loadAndPlay(item,
                    queue: _items,
                    startPositionSeconds: (item['currentSecs'] as int?) ?? 0),
              ),
            );
          case PodcastSeeAllType.latestEpisodes:
            return buildPodcastEpisodeItem(context, item,
                onPlay: () => controller.loadAndPlay(item, queue: _items));
          case PodcastSeeAllType.featuredSeries:
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: buildPodcastSeriesCard(
                context,
                item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PodcastSeriesDetailScreen(
                          seriesId: item['id'] as String)),
                ),
              ),
            );
        }
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Series Detail Screen
// ────────────────────────────────────────────────────────────────

class PodcastSeriesDetailScreen extends StatefulWidget {
  final String seriesId;
  const PodcastSeriesDetailScreen({super.key, required this.seriesId});

  @override
  State<PodcastSeriesDetailScreen> createState() =>
      _PodcastSeriesDetailScreenState();
}

class _PodcastSeriesDetailScreenState extends State<PodcastSeriesDetailScreen> {
  final PodcastService _service = PodcastService.instance;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _series;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final series = await _service.fetchSeriesById(widget.seriesId);
      if (!mounted) return;
      setState(() {
        _series = series;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this series. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = PodcastPlayerController.instance;
    final episodes =
        (_series?['episodes'] as List<Map<String, dynamic>>?) ?? [];

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: buildPodcastAppBar(
        context,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kPodcastRed, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.themeGradients),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      bottom: controller.hasEpisode ? 70.0 : 0.0),
                  child: _isLoading
                      ? buildPodcastLoadingState(context)
                      : _errorMessage != null
                          ? Center(
                              child: buildPodcastErrorState(
                                  context, _errorMessage!, _load))
                          : RefreshIndicator(
                              color: _kPodcastRed,
                              onRefresh: _load,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 200.0,
                                      width: double.infinity,
                                      child: _CoverBackground(
                                          url: _series?['cover'] as String?),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (_series?['title'] ?? '') as String,
                                            style: TextStyle(
                                                color: context.textColor,
                                                fontSize: 22.0,
                                                fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 8.0),
                                          Text(
                                            (_series?['desc'] ?? '') as String,
                                            style: TextStyle(
                                                color: context.subTextColor,
                                                fontSize: 13.0,
                                                height: 1.4),
                                          ),
                                          const SizedBox(height: 20.0),
                                          Text(
                                            'Episodes',
                                            style: TextStyle(
                                                color: context.textColor,
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 12.0),
                                          episodes.isEmpty
                                              ? buildPodcastEmptyState(
                                                  context, 'No episodes found.')
                                              : Column(
                                                  children: episodes
                                                      .map((ep) =>
                                                          buildPodcastEpisodeItem(
                                                            context,
                                                            ep,
                                                            onPlay: () => controller
                                                                .loadAndPlay(ep,
                                                                    queue:
                                                                        episodes),
                                                          ))
                                                      .toList(),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                ),
                if (controller.hasEpisode)
                  const Positioned(
                      bottom: 0.0,
                      left: 0.0,
                      right: 0.0,
                      child: PodcastMiniPlayer()),
              ],
            ),
          );
        },
      ),
    );
  }
}
