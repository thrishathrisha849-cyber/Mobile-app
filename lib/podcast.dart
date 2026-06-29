import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'profile.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All', 'Free', 'Paid', 'Marketing'];

  // Local database matching the courses list in the user screenshot
  final List<Map<String, dynamic>> _courses = [
    {
      'id': '1',
      'title': 'Mastering Drip Marketing',
      'instructor': 'Sakthivel Paneerselvam',
      'category': 'Marketing',
      'isFree': true,
      'price': 0,
      'durationText': '6 WEEKS',
      'lessonsCount': 18,
      'lessonsCompleted': 12,
      'progress': 0.66,
      'color': const Color(0xFF220304),
      'accent': const Color(0xFFD30814),
      'cover': 'assets/images/ebook covers/zero 1.png',
      'description': 'Secure your business assets with industry-grade defense protocols and master sequence-based email and message flows.',
    },
    {
      'id': '2',
      'title': 'Digital Marketing Excellence',
      'instructor': 'Sakthivel Paneerselvam',
      'category': 'Marketing',
      'isFree': false,
      'price': 4999,
      'durationText': '8 WEEKS',
      'lessonsCount': 24,
      'lessonsCompleted': 8,
      'progress': 0.33,
      'color': const Color(0xFF0F172A),
      'accent': const Color(0xFF38BDF8),
      'cover': 'assets/images/ebook covers/gurilla 1.png',
      'description': 'Scale your reach through data-driven performance marketing, conversion rate optimization, and high-impact content loops.',
    },
    {
      'id': '3',
      'title': 'Business Scalability 101',
      'instructor': 'TBT Team Expert',
      'category': 'Business',
      'isFree': false,
      'price': 2499,
      'durationText': '4 WEEKS',
      'lessonsCount': 12,
      'lessonsCompleted': 0,
      'progress': 0.0,
      'color': const Color(0xFF065F46),
      'accent': const Color(0xFF34D399),
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
      'description': 'Architect your business for 10x growth with robust financial modelling, structured delegation pipelines, and key operation frameworks.',
    }
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCategoryTab(String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD30814) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 13.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PodcastDetailScreen(course: course),
          ),
        ).then((_) {
          setState(() {});
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.03),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Cover Image Container with play button overlay
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90.0,
                  height: 90.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: course['color'],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.asset(
                      course['cover'],
                      fit: BoxFit.cover,
                      width: 90.0,
                      height: 90.0,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: course['color'],
                        child: Center(
                          child: Icon(Icons.podcasts_rounded, color: course['accent'], size: 24.0),
                        ),
                      ),
                    ),
                  ),
                ),
                // Play overlay signature
                Container(
                  width: 32.0,
                  height: 32.0,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 0.8),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14.0),
            // Right Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    course['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  // Bottom Row: Duration & Price Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.white30,
                            size: 13.0,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            course['durationText'],
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (course['isFree'])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD30814),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else
                        Text(
                          '₹ ${course['price']}',
                          style: const TextStyle(
                            color: Color(0xFFD30814),
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically filter lists
    final filteredCourses = _courses.where((course) {
      final matchesSearch = course['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesCategory = true;
      if (_selectedCategory == 'Free') {
        matchesCategory = course['isFree'] == true;
      } else if (_selectedCategory == 'Paid') {
        matchesCategory = course['isFree'] == false;
      } else if (_selectedCategory == 'Marketing') {
        matchesCategory = course['category'] == 'Marketing';
      }

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24.0),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menu option coming soon!'), duration: Duration(seconds: 1)),
            );
          },
        ),
        title: Image.asset(
          'assets/images/TBT C Pvt Final logo-04.png',
          height: 44.0,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          // Fire Streak Widget
          Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: const Color(0xFF2C2C2E),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.whatshot_rounded,
                      color: Colors.white,
                      size: 14.0,
                    ),
                  ),
                  const Positioned(
                    bottom: 1.5,
                    child: Text(
                      '12',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          // Notification Bell
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white, size: 22.0),
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD30814),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
          // Profile Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) {
                setState(() {});
              });
            },
            child: Container(
              width: 28.0,
              height: 28.0,
              margin: const EdgeInsets.only(right: 16.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD30814),
                  width: 1.0,
                ),
              ),
              child: ProfileScreen.profileImagePath != null
                  ? ClipOval(
                      child: Image.file(
                        File(ProfileScreen.profileImagePath!),
                        width: 28.0,
                        height: 28.0,
                        fit: BoxFit.cover,
                      ),
                    )
                  : ClipOval(
                      child: Image.network(
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                        width: 28.0,
                        height: 28.0,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E0304), // Dark Red Glow backdrop
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Text(
                      'Level Up Your Tribe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18.0),
                    // Search Bar container matching design
                    Container(
                      height: 48.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.white30, size: 20.0),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 14.0),
                              cursorColor: const Color(0xFFD30814),
                              decoration: const InputDecoration(
                                hintText: 'Search courses, topics...',
                                hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              child: const Icon(Icons.clear_rounded, color: Colors.white30, size: 18.0),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    // Categories horizontal bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _categories.map((c) => _buildCategoryTab(c)).toList(),
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    // Available Courses Header Grid Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Courses',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All courses is coming soon!'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: const Text(
                            'VIEW ALL',
                            style: TextStyle(
                              color: Color(0xFFD30814),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    // Main Courses list representation
                    filteredCourses.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Text(
                                'No courses found.',
                                style: TextStyle(color: Colors.white30, fontSize: 13.0),
                              ),
                            ),
                          )
                        : Column(
                            children: filteredCourses.map((c) => _buildCourseCard(c)).toList(),
                          ),
                    const SizedBox(height: 80.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PodcastDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const PodcastDetailScreen({super.key, required this.course});

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  // Seekbar and audio state variables
  bool _isPlaying = false;
  int _currentSeconds = 522; // 08:42
  final int _totalSeconds = 1458; // 24:18
  Timer? _playbackTimer;

  // Active playing episode details
  String _activeEpisodeTitle = "The Power of Self Belief";
  String _activeSeriesName = "Mindset Mastery";
  String _activeCover = "assets/images/ebook covers/zero 1.png";
  String _activeDescription = "Master your mind, Transform your life.";

  String _selectedCategory = "All";

  // Data for sections matching the user's screenshot
  final List<Map<String, dynamic>> _continueListeningList = [
    {
      'title': 'The Power of Self Belief',
      'timeLeft': '18 min left',
      'progress': 0.35,
      'series': 'Mindset Mastery',
      'cover': 'assets/images/ebook covers/zero 1.png',
      'durationSecs': 1458,
      'currentSecs': 522,
    },
    {
      'title': 'Discipline Equals Freedom',
      'timeLeft': '12 min left',
      'progress': 0.55,
      'series': 'Mindset Mastery',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
      'durationSecs': 1200,
      'currentSecs': 540,
    },
    {
      'title': 'Focus Builds Success',
      'timeLeft': '6 min left',
      'progress': 0.80,
      'series': 'Mindset Mastery',
      'cover': 'assets/images/ebook covers/kassu 1.png',
      'durationSecs': 1800,
      'currentSecs': 1440,
    }
  ];

  final List<String> _categories = ["All", "Mindset", "Business", "Growth", "Leadership", "Discipline"];

  final List<Map<String, dynamic>> _episodesList = [
    {
      'title': 'How to Build an Unstoppable Mindset',
      'info': '24 min',
      'category': 'Mindset',
      'desc': 'Learn the core principles to build mental strength and stay unstoppable in any situation.',
      'cover': 'assets/images/ebook covers/zero 1.png',
      'durationSecs': 1440,
    },
    {
      'title': 'Break Your Limits',
      'info': '20 min',
      'category': 'Growth',
      'desc': 'Step out of your comfort zone and unlock your true potential.',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
      'durationSecs': 1200,
    },
    {
      'title': 'Success is a Choice',
      'info': '16 min',
      'category': 'Business',
      'desc': 'Your daily choices shape your future. Choose wisely and win consistently.',
      'cover': 'assets/images/ebook covers/kassu 1.png',
      'durationSecs': 960,
    }
  ];

  final List<Map<String, dynamic>> _featuredSeries = [
    {
      'title': '90 DAYS TRANSFORMATION',
      'episodesCount': '12 Episodes',
      'cover': 'assets/images/tbt_2.jpeg',
    },
    {
      'title': 'CEO THINKING',
      'episodesCount': '8 Episodes',
      'cover': 'assets/images/whatsapp_image.jpeg',
    }
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate active track based on course title
    _activeEpisodeTitle = widget.course['title'] ?? 'The Power of Self Belief';
    _activeSeriesName = widget.course['category'] ?? 'Mindset Mastery';
    _activeCover = widget.course['cover'] ?? 'assets/images/ebook covers/zero 1.png';
    _activeDescription = widget.course['description'] ?? 'Master your mind, Transform your life.';
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(() {
            if (_currentSeconds < _totalSeconds) {
              _currentSeconds++;
            } else {
              _isPlaying = false;
              _playbackTimer?.cancel();
            }
          });
        });
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _rewind10() {
    setState(() {
      _currentSeconds = (_currentSeconds - 10).clamp(0, _totalSeconds);
    });
  }

  void _forward10() {
    setState(() {
      _currentSeconds = (_currentSeconds + 10).clamp(0, _totalSeconds);
    });
  }

  void _skipNext() {
    int currentIndex = _episodesList.indexWhere((ep) => ep['title'] == _activeEpisodeTitle);
    if (currentIndex != -1 && currentIndex < _episodesList.length - 1) {
      final nextEp = _episodesList[currentIndex + 1];
      _playTrack(nextEp['title'], 'Mindset Mastery', nextEp['cover'], totalSecs: nextEp['durationSecs']);
    } else {
      final firstEp = _episodesList[0];
      _playTrack(firstEp['title'], 'Mindset Mastery', firstEp['cover'], totalSecs: firstEp['durationSecs']);
    }
  }

  void _skipPrevious() {
    int currentIndex = _episodesList.indexWhere((ep) => ep['title'] == _activeEpisodeTitle);
    if (currentIndex > 0) {
      final prevEp = _episodesList[currentIndex - 1];
      _playTrack(prevEp['title'], 'Mindset Mastery', prevEp['cover'], totalSecs: prevEp['durationSecs']);
    } else {
      final lastEp = _episodesList[_episodesList.length - 1];
      _playTrack(lastEp['title'], 'Mindset Mastery', lastEp['cover'], totalSecs: lastEp['durationSecs']);
    }
  }

  void _playTrack(String title, String series, String cover, {int currentSecs = 0, int totalSecs = 1200, String desc = ""}) {
    setState(() {
      _activeEpisodeTitle = title;
      _activeSeriesName = series;
      _activeCover = cover;
      _activeDescription = desc.isNotEmpty ? desc : "Master your mind, Transform your life.";
      _currentSeconds = currentSecs;
      _isPlaying = true;
      
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_currentSeconds < totalSecs) {
            _currentSeconds++;
          } else {
            _isPlaying = false;
            _playbackTimer?.cancel();
          }
        });
      });
    });
  }

  String _formatTime(int secondsCount) {
    final int minutes = secondsCount ~/ 60;
    final int seconds = secondsCount % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCategoryTab(String cat) {
    final isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = cat;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD30814) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Text(
          cat,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildContinueListeningCard(Map<String, dynamic> item) {
    return Container(
      width: 220.0,
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          // Left Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              item['cover'],
              width: 48.0,
              height: 48.0,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 48.0,
                height: 48.0,
                color: const Color(0xFF2C2C2E),
                child: const Icon(Icons.podcasts_rounded, color: Colors.white30, size: 20.0),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          // Middle Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3.0),
                Text(
                  item['timeLeft'],
                  style: const TextStyle(color: Colors.white30, fontSize: 10.0),
                ),
                const SizedBox(height: 6.0),
                // Tiny linear progress bar matching screenshot
                Container(
                  width: double.infinity,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(1.25),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: item['progress'],
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD30814),
                        borderRadius: BorderRadius.circular(1.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          // Play button trigger
          GestureDetector(
            onTap: () => _playTrack(item['title'], item['series'], item['cover'], currentSecs: item['currentSecs'], totalSecs: item['durationSecs']),
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFFD30814),
                size: 16.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Poster image
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              item['cover'],
              width: 54.0,
              height: 54.0,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 54.0,
                height: 54.0,
                color: const Color(0xFF2C2C2E),
                child: const Icon(Icons.podcasts_rounded, color: Colors.white30, size: 22.0),
              ),
            ),
          ),
          const SizedBox(width: 14.0),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3.0),
                // Time & Category row matching mockup
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white30, fontSize: 10.5),
                    children: [
                      TextSpan(text: '${item['info']} • '),
                      TextSpan(
                        text: item['category'],
                        style: const TextStyle(color: Color(0xFFD30814), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  item['desc'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white30, fontSize: 11.0, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          // Play button & More
          Column(
            children: [
              GestureDetector(
                onTap: () => _playTrack(item['title'], 'Mindset Mastery', item['cover'], totalSecs: item['durationSecs'], desc: item['desc']),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFFD30814),
                  size: 22.0,
                ),
              ),
              const SizedBox(height: 12.0),
              const Icon(
                Icons.more_vert_rounded,
                color: Colors.white30,
                size: 18.0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> item) {
    return Container(
      width: 180.0,
      height: 110.0,
      margin: const EdgeInsets.only(right: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          children: [
            // Background visual cover
            Positioned.fill(
              child: Image.asset(
                item['cover'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1C1C1E),
                  child: const Center(
                    child: Icon(Icons.podcasts_rounded, color: Colors.white30, size: 28.0),
                  ),
                ),
              ),
            ),
            // Bottom black shadow overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
            // Text Details & Play action
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
                          item['title'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          item['episodesCount'],
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // Solid red play button
                  Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD30814),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Filter episodes list dynamically
      final filteredEpisodes = _episodesList.where((episode) {
        if (_selectedCategory == 'All') return true;
        return episode['category'] == _selectedCategory;
      }).toList();

      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
            onPressed: () => Navigator.pop(context),
          ),
          title: Image.asset(
            'assets/images/TBT C Pvt Final logo-04.png',
            height: 44.0,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              'Tamil Business Tribe',
              style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
          ),
        centerTitle: true,
        actions: [
          // Fire Streak Widget
          Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: const Color(0xFF2C2C2E),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.whatshot_rounded,
                      color: Colors.white,
                      size: 14.0,
                    ),
                  ),
                  const Positioned(
                    bottom: 1.5,
                    child: Text(
                      '12',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          // Notification Bell
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white, size: 22.0),
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD30814),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
          // Profile Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) {
                setState(() {});
              });
            },
            child: Container(
              width: 28.0,
              height: 28.0,
              margin: const EdgeInsets.only(right: 16.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD30814),
                  width: 1.0,
                ),
              ),
              child: ProfileScreen.profileImagePath != null
                  ? ClipOval(
                      child: Image.file(
                        File(ProfileScreen.profileImagePath!),
                        width: 28.0,
                        height: 28.0,
                        fit: BoxFit.cover,
                      ),
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
                          color: const Color(0xFF2C2C2E),
                          child: const Icon(Icons.person, color: Colors.white30, size: 16.0),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120.0), // Padding to make room for bottom mini player
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Featured Media Player Section with dynamic seeker & controls
                Container(
                  width: double.infinity,
                  height: 380.0,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD30814).withOpacity(0.12),
                        blurRadius: 30.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Backdrop dynamic cover image with mentor banner fallback
                      Positioned.fill(
                        child: ClipRRect(
                          child: Image.asset(
                            _activeCover,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/mentor_banner.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, st) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF1E0304), Color(0xFF0A0A0A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Backdrop black-red gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.5),
                                const Color(0xFF0A0A0A).withOpacity(0.95),
                                const Color(0xFF0A0A0A),
                              ],
                              stops: const [0.0, 0.4, 0.85, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Text Info
                      Positioned(
                        top: 24.0,
                        left: 20.0,
                        right: 20.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/TBT C Pvt Final logo-04.png',
                              height: 28.0,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 12.0),
                            Row(
                              children: [
                                const Icon(Icons.mic, color: Color(0xFFD30814), size: 14.0),
                                const SizedBox(width: 6.0),
                                Text(
                                  _activeSeriesName.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFD30814),
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              _activeEpisodeTitle.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              _activeDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Seek bar & controls positioned at the bottom of player card
                      Positioned(
                        bottom: 16.0,
                        left: 20.0,
                        right: 20.0,
                        child: Column(
                          children: [
                            // 1. Red Frequency Visualizer Waveform
                            Container(
                              height: 28.0,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(45, (index) {
                                  // Create soundwave pattern (bell curve envelope)
                                  double factor = 1.0 - ((index - 22).abs() / 22.0);
                                  double minH = 3.0;
                                  double maxH = 26.0;
                                  double h = minH + (maxH - minH) * factor * (index % 3 == 0 ? 0.95 : (index % 2 == 0 ? 0.7 : 0.45));
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 3.2,
                                    height: _isPlaying 
                                        ? (h * (0.55 + (0.75 * (0.5 - (0.5 * (index % 2 == 0 ? 1 : -1) * (index % 3 == 0 ? 0.8 : 0.45))))))
                                        : h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD30814),
                                      borderRadius: BorderRadius.circular(1.6),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            // Custom Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.0,
                                activeTrackColor: const Color(0xFFD30814),
                                inactiveTrackColor: Colors.white12,
                                thumbColor: const Color(0xFFD30814),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                overlayColor: const Color(0xFFD30814).withOpacity(0.12),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: _totalSeconds.toDouble(),
                                value: _currentSeconds.toDouble().clamp(0.0, _totalSeconds.toDouble()),
                                onChanged: (val) {
                                  setState(() {
                                    _currentSeconds = val.toInt();
                                  });
                                },
                              ),
                            ),
                            // Seeker times row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTime(_currentSeconds),
                                    style: const TextStyle(color: Colors.white30, fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _formatTime(_totalSeconds),
                                    style: const TextStyle(color: Colors.white30, fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            // Music Controls Button Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // 10s Rewind
                                IconButton(
                                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 24.0),
                                  onPressed: _rewind10,
                                ),
                                // Skip Previous
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28.0),
                                  onPressed: _skipPrevious,
                                ),
                                // Big Circular Play Pause
                                GestureDetector(
                                  onTap: _togglePlayPause,
                                  child: Container(
                                    width: 52.0,
                                    height: 52.0,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD30814),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 32.0,
                                    ),
                                  ),
                                ),
                                // Skip Next
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28.0),
                                  onPressed: _skipNext,
                                ),
                                // 10s Forward
                                IconButton(
                                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 24.0),
                                  onPressed: _forward10,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),

                // 2. Continue Listening Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Continue Listening',
                        style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'See All',
                        style: TextStyle(color: Color(0xFFD30814), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20.0, right: 8.0),
                  child: Row(
                    children: _continueListeningList.map((item) => _buildContinueListeningCard(item)).toList(),
                  ),
                ),
                const SizedBox(height: 28.0),

                // 3. Categories horizontal selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: const Text(
                    'Categories',
                    style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20.0, right: 8.0),
                  child: Row(
                    children: _categories.map((c) => _buildCategoryTab(c)).toList(),
                  ),
                ),
                const SizedBox(height: 28.0),

                // 4. Latest Episodes Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Latest Episodes',
                        style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'See All',
                        style: TextStyle(color: Color(0xFFD30814), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: filteredEpisodes.map((item) => _buildEpisodeItem(item)).toList(),
                  ),
                ),
                const SizedBox(height: 24.0),

                // 5. Featured Series Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Featured Series',
                        style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'See All',
                        style: TextStyle(color: Color(0xFFD30814), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
                SizedBox(
                  height: 110.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(left: 20.0, right: 8.0),
                    child: Row(
                      children: _featuredSeries.map((item) => _buildSeriesCard(item)).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 6. Sticky bottom mini player overlay card
          Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: Container(
              height: 70.0,
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04), width: 0.8)),
              ),
              child: Column(
                children: [
                  // Playback mini track progress line
                  Container(
                    width: double.infinity,
                    height: 2.0,
                    color: Colors.white.withOpacity(0.06),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (_currentSeconds / _totalSeconds).clamp(0.0, 1.0),
                      child: Container(color: const Color(0xFFD30814)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          // Small square album art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: Image.asset(
                              _activeCover,
                              width: 40.0,
                              height: 40.0,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 40.0,
                                height: 40.0,
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(Icons.podcasts_rounded, color: Colors.white30, size: 16.0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _activeEpisodeTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  _activeSeriesName,
                                  style: const TextStyle(color: Color(0xFFD30814), fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          // Control buttons
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 20.0),
                            onPressed: _rewind10,
                          ),
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24.0,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 20.0),
                            onPressed: _forward10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    } catch (e, stack) {
      debugPrint("Error rendering player: $e\n$stack");
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48.0),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Render Error in Player Screen',
                    style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13.0),
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    stack.toString(),
                    style: const TextStyle(color: Colors.white30, fontSize: 10.0),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
