import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart';
import 'profile.dart';

// Global database of posts so that main.dart can insert new posts dynamically
final List<Map<String, dynamic>> communityPosts = [
  {
    'name': 'Arun Prakash',
    'role': 'Business Owner • Chennai',
    'time': '2h ago',
    'badge': '10X Growth',
    'badgeColor': const Color(0xFFCC0000),
    'avatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    'content': 'Before joining Tamil Business Tribe, I was struggling to get consistent clients. Within 6 months, my business grew 10X! The strategies, accountability and support from the coaches are unmatched. 🙏',
    'hasVideo': true,
    'videoThumbnail': 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600',
    'likes': 124,
    'comments': 18,
    'shares': 6,
    'isLiked': true,
    'isBookmarked': false,
    'isFollowing': true,
    'isMentor': false,
  },
  {
    'name': 'Kavitha R',
    'role': 'Boutique Owner • Coimbatore',
    'time': '5h ago',
    'badge': '5X Growth',
    'badgeColor': const Color(0xFFD4AF37),
    'avatarUrl': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    'content': 'From barely making ₹20K/month to ₹1L+/month! 🎯 The business framework and marketing strategies taught here are pure gold. Thank you Tamil Business Tribe! ❤️',
    'likes': 96,
    'comments': 12,
    'shares': 4,
    'isLiked': true,
    'isBookmarked': true,
    'isFollowing': false,
    'isMentor': false,
  },
  {
    'name': 'Suresh D',
    'role': 'Digital Marketer • Madurai',
    'time': '1d ago',
    'badge': 'Strategy',
    'badgeColor': const Color(0xFFCC0000),
    'avatarUrl': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
    'content': "The way of coaching here is next level. They don't just teach, they implement with us. Weekly calls, task tracking, and real feedback - this is why I stay consistent! 💪",
    'likes': 64,
    'comments': 9,
    'shares': 3,
    'isLiked': true,
    'isBookmarked': false,
    'isFollowing': false,
    'isMentor': true,
  },
  {
    'name': 'Nandhini S',
    'role': 'Handmade Jewelry Business • Erode',
    'time': '1d ago',
    'badge': '10X Growth',
    'badgeColor': const Color(0xFFCC0000),
    'avatarUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
    'content': 'Breakthrough moment! 🎉 Hit my highest sales month ever. From local sales to pan India orders. The community support and strategies are powerful!',
    'hasImages': true,
    'images': [
      'special_text_card',
      'https://images.unsplash.com/photo-1617038260897-41a1f14a8ca0?w=300',
      'https://images.unsplash.com/photo-1538168191891-6383b4724016?w=300',
    ],
    'likes': 112,
    'comments': 15,
    'shares': 5,
    'isLiked': true,
    'isBookmarked': false,
    'isFollowing': true,
    'isMentor': false,
  },
  {
    'name': 'Manikandan V',
    'role': 'IT Service Provider • Trichy',
    'time': '1d ago',
    'badge': 'Strategy',
    'badgeColor': const Color(0xFFCC0000),
    'avatarUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
    'content': 'Implemented the client acquisition strategy and doubled my MRR in just 90 days. Systems + Execution = Results! 🔥',
    'likes': 82,
    'comments': 7,
    'shares': 2,
    'isLiked': true,
    'isBookmarked': false,
    'isFollowing': false,
    'isMentor': false,
  },
];

// Persistent File Storage Utilities
Future<void> savePostsToLocal() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/community_posts.json');
    final listToSave = communityPosts.map((post) {
      final Map<String, dynamic> copy = Map.from(post);
      if (copy['badgeColor'] is Color) {
        copy['badgeColorValue'] = (copy['badgeColor'] as Color).value;
        copy.remove('badgeColor');
      }
      return copy;
    }).toList();
    await file.writeAsString(jsonEncode(listToSave));
  } catch (e) {
    debugPrint('Error saving posts to local storage: $e');
  }
}

Future<void> loadPostsFromLocal() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/community_posts.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      final List<Map<String, dynamic>> loadedPosts = decoded.map((item) {
        final Map<String, dynamic> post = Map<String, dynamic>.from(item);
        if (post.containsKey('badgeColorValue')) {
          post['badgeColor'] = Color(post['badgeColorValue'] as int);
          post.remove('badgeColorValue');
        } else {
          post['badgeColor'] = const Color(0xFFCC0000);
        }
        return post;
      }).toList();
      
      if (loadedPosts.isNotEmpty) {
        communityPosts.clear();
        communityPosts.addAll(loadedPosts);
      }
    }
  } catch (e) {
    debugPrint('Error loading posts from local storage: $e');
  }
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _activeTab = 0; // 0: For You, 1: Following, 2: Mentors

  // Simulated Video Player States
  final Map<String, bool> _playingVideos = {};
  final Map<String, double> _videoProgress = {};
  final Map<String, int> _videoElapsed = {};

  @override
  void initState() {
    super.initState();
    _loadPersistedPosts();
  }

  Future<void> _loadPersistedPosts() async {
    await loadPostsFromLocal();
    if (mounted) {
      setState(() {});
    }
  }

  void _togglePlayVideo(String userName) {
    final isPlaying = _playingVideos[userName] ?? false;
    setState(() {
      if (isPlaying) {
        _playingVideos[userName] = false;
      } else {
        _playingVideos[userName] = true;
        _videoProgress[userName] ??= 0.0;
        _videoElapsed[userName] ??= 0;
        _startVideoUpdateLoop(userName);
      }
    });
  }

  void _startVideoUpdateLoop(String userName) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _playingVideos[userName] != true) {
        return false;
      }
      setState(() {
        double currentProgress = _videoProgress[userName] ?? 0.0;
        int elapsed = _videoElapsed[userName] ?? 0;
        currentProgress += 0.005; // Simulate 20s playback
        if (currentProgress >= 1.0) {
          currentProgress = 0.0;
          elapsed = 0;
          _playingVideos[userName] = false;
        } else {
          elapsed = (currentProgress * 20).toInt();
        }
        _videoProgress[userName] = currentProgress;
        _videoElapsed[userName] = elapsed;
      });
      return true;
    });
  }

  // Toggles follow/unfollow and refreshes layout
  void _toggleFollow(Map<String, dynamic> post) {
    setState(() {
      final isFollowing = post['isFollowing'] == true;
      post['isFollowing'] = !isFollowing;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing 
                ? 'Unfollowed ${post['name']}' 
                : 'Following ${post['name']} now!',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: isFollowing ? const Color(0xFFCC0000) : const Color(0xFF27AE60),
        ),
      );
    });
    savePostsToLocal();
  }

  // Toggle Bookmark
  void _toggleBookmark(Map<String, dynamic> post) {
    setState(() {
      final isBookmarked = post['isBookmarked'] == true;
      post['isBookmarked'] = !isBookmarked;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBookmarked 
                ? 'Removed from Saved Items' 
                : 'Saved post successfully!',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF121214),
        ),
      );
    });
    savePostsToLocal();
  }

  // Native share action
  void _sharePost(Map<String, dynamic> post) {
    Share.share(
      'Check out this update by ${post['name']} in Tamil Business Tribe:\n\n"${post['content']}"',
      subject: 'Post by ${post['name']}',
    );
    setState(() {
      post['shares'] = (post['shares'] as int) + 1;
    });
    savePostsToLocal();
  }

  // Report post mock dialogue
  void _reportPost(String userName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you! Post from $userName has been reported for review.'),
        backgroundColor: const Color(0xFFCC0000),
      ),
    );
  }

  // Mock message window
  void _showMessagePrompt(String userName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat thread with $userName...'),
        backgroundColor: const Color(0xFF2F80ED),
      ),
    );
  }

  // Detail user profile sheet
  void _showUserProfile(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isFollowing = post['isFollowing'] == true;
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.0,
                    height: 5.0,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  GestureDetector(
                    onTap: () => showProfilePhotoDialog(context, post['avatarUrl'] as String),
                    child: CircleAvatar(
                      radius: 40.0,
                      backgroundColor: const Color(0xFF2C2C2E),
                      child: ClipOval(
                        child: post['avatarUrl'].toString().startsWith('http') || post['avatarUrl'].toString().startsWith('assets/')
                            ? (post['avatarUrl'].toString().startsWith('http')
                                ? Image.network(
                                    post['avatarUrl'] as String,
                                    width: 80.0,
                                    height: 80.0,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFF1C1C1E),
                                      child: Center(
                                        child: Text(
                                          (post['name'] as String).substring(0, 1),
                                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    post['avatarUrl'] as String,
                                    width: 80.0,
                                    height: 80.0,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFF1C1C1E),
                                      child: Center(
                                        child: Text(
                                          (post['name'] as String).substring(0, 1),
                                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ))
                            : Image.file(
                                File(post['avatarUrl'] as String),
                                width: 80.0,
                                height: 80.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: Center(
                                    child: Text(
                                      (post['name'] as String).substring(0, 1),
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    post['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    post['role'] as String,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14.0,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      'Member ID: TBT-${post['name'].hashCode.abs().toString().substring(0, 5)}',
                      style: const TextStyle(
                        color: Color(0xFFCC0000),
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.white12 : const Color(0xFFCC0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                        icon: Icon(isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded),
                        label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                        onPressed: () {
                          setModalState(() {
                            _toggleFollow(post);
                          });
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                        icon: const Icon(Icons.message_rounded),
                        label: const Text('Message'),
                        onPressed: () {
                          Navigator.pop(context);
                          _showMessagePrompt(post['name']);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Popup dialog/sheet for post actions (three-dots)
  void _showPostActions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        final isFollowing = post['isFollowing'] == true;
        final isBookmarked = post['isBookmarked'] == true;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.0,
                height: 5.0,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 20.0),
              ListTile(
                leading: Icon(
                  isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                  color: Colors.white,
                ),
                title: Text(
                  isFollowing ? 'Unfollow ${post['name']}' : 'Follow ${post['name']}',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFollow(post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text('Share post link', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _sharePost(post);
                },
              ),
              ListTile(
                leading: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: Colors.white,
                ),
                title: Text(
                  isBookmarked ? 'Remove from Saved' : 'Save post',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleBookmark(post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFCC0000)),
                title: const Text('Report post', style: TextStyle(color: Color(0xFFCC0000))),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(post['name']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Interactive sheet to add and display comments
  void _showCommentsDialog(Map<String, dynamic> post) {
    if (post['commentsList'] == null) {
      post['commentsList'] = <String>[
        'Great achievement! Keep growing.',
        'Inspirational journey, Tamil Business Tribe coaches are indeed excellent.',
      ];
    }
    
    final List<String> comments = post['commentsList'] as List<String>;
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20.0,
                left: 20.0,
                right: 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.0,
                      height: 5.0,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  const Text(
                    'Comments',
                    style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12.0),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200.0),
                    child: comments.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14.0,
                                      backgroundColor: const Color(0xFFCC0000),
                                      child: const Icon(Icons.person, size: 14.0, color: Colors.white),
                                    ),
                                    const SizedBox(width: 10.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'TBT Member',
                                            style: TextStyle(color: Colors.white70, fontSize: 11.0, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 3.0),
                                          Text(
                                            comments[index],
                                            style: const TextStyle(color: Colors.white, fontSize: 13.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Colors.white10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFFCC0000)),
                        onPressed: () {
                          if (commentController.text.trim().isNotEmpty) {
                            setState(() {
                              comments.add(commentController.text.trim());
                              post['comments'] = comments.length;
                            });
                            savePostsToLocal();
                            setModalState(() {
                              commentController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Get dynamic feed views
  List<Map<String, dynamic>> _getFilteredPosts() {
    if (_activeTab == 0) {
      return communityPosts;
    } else if (_activeTab == 1) {
      return communityPosts.where((post) => post['isFollowing'] == true).toList();
    } else {
      return communityPosts.where((post) => post['isMentor'] == true).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 500 ? 500.0 : screenWidth;
    final filteredPosts = _getFilteredPosts();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Top Custom Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 26.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      const Text(
                        'Community',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 24.0,
                      ),
                      const SizedBox(width: 16.0),
                      // Notification Bell with Badge
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 24.0,
                            ),
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3.0),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCC0000),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                                child: const Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      // Red circle plus button
                      Container(
                        width: 32.0,
                        height: 32.0,
                        decoration: const BoxDecoration(
                          color: Color(0xFFCC0000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Tab Bar Navigation Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTabButton('For You', 0),
                      _buildTabButton('Following', 1),
                      _buildTabButton('Mentors', 2),
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),

                // Scrollable Feed List
                Expanded(
                  child: filteredPosts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: filteredPosts.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemBuilder: (context, index) {
                            final post = filteredPosts[index];
                            return FadeInSlideTransition(
                              key: ValueKey(post['name'] + post['content'].hashCode.toString()),
                              delay: Duration(milliseconds: index * 80),
                              child: _buildPostCard(post),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(contentWidth),
    );
  }

  Widget _buildEmptyState() {
    String message = '';
    IconData icon = Icons.feed_rounded;
    if (_activeTab == 1) {
      message = 'You are not following anyone yet.\nExplore the For You feed to follow members!';
      icon = Icons.person_add_rounded;
    } else if (_activeTab == 2) {
      message = 'No mentor posts available at the moment.';
      icon = Icons.school_rounded;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white24, size: 48.0),
            const SizedBox(height: 16.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14.0,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFCC0000) : Colors.grey,
              fontSize: 14.0,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6.0),
          if (isActive)
            Container(
              width: 50.0,
              height: 2.0,
              color: const Color(0xFFCC0000),
            ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User profile row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showUserProfile(post),
                child: CircleAvatar(
                  radius: 20.0,
                  backgroundColor: const Color(0xFF2C2C2E),
                  child: ClipOval(
                    child: post['avatarUrl'].toString().startsWith('http') || post['avatarUrl'].toString().startsWith('assets/')
                        ? (post['avatarUrl'].toString().startsWith('http')
                            ? Image.network(
                                post['avatarUrl'] as String,
                                width: 40.0,
                                height: 40.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: Center(
                                    child: Text(
                                      (post['name'] as String).substring(0, 1),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              )
                            : Image.asset(
                                post['avatarUrl'] as String,
                                width: 40.0,
                                height: 40.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: Center(
                                    child: Text(
                                      (post['name'] as String).substring(0, 1),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ))
                        : Image.file(
                            File(post['avatarUrl'] as String),
                            width: 40.0,
                            height: 40.0,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF1C1C1E),
                              child: Center(
                                child: Text(
                                  (post['name'] as String).substring(0, 1),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showUserProfile(post),
                          child: Text(
                            post['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        _buildBadge(post['badge'] as String, post['badgeColor'] as Color),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${post['role']} • ${post['time']}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.grey,
                  size: 20.0,
                ),
                onPressed: () => _showPostActions(post),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Post text content
          Text(
            post['content'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12.0),

          // Video attachment (if any)
          if (post['hasVideo'] == true) ...[
            _buildVideoPlayer(post),
            const SizedBox(height: 12.0),
          ],

          // Images grid/row (if any)
          if (post['hasImages'] == true && post['images'] is List) ...[
            _buildPostImages(post['images'] as List),
            const SizedBox(height: 12.0),
          ],

          // Interaction row (likes, comments, share, bookmark)
          Row(
            children: [
              // Like
              GestureDetector(
                onTap: () {
                  setState(() {
                    final isLiked = post['isLiked'] == true;
                    post['isLiked'] = !isLiked;
                    post['likes'] = (post['likes'] as int) + (isLiked ? -1 : 1);
                  });
                  savePostsToLocal();
                },
                child: _buildInteractionItem(
                  icon: post['isLiked'] == true ? Icons.favorite : Icons.favorite_border,
                  iconColor: post['isLiked'] == true ? const Color(0xFFCC0000) : Colors.grey,
                  count: post['likes'] as int,
                ),
              ),
              const SizedBox(width: 16.0),
              // Comment
              GestureDetector(
                onTap: () => _showCommentsDialog(post),
                child: _buildInteractionItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: Colors.grey,
                  count: post['comments'] as int,
                ),
              ),
              const SizedBox(width: 16.0),
              // Share
              GestureDetector(
                onTap: () => _sharePost(post),
                child: _buildInteractionItem(
                  icon: Icons.share_outlined,
                  iconColor: Colors.grey,
                  count: post['shares'] as int,
                ),
              ),
              const Spacer(),
              // Bookmark
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  post['isBookmarked'] == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: post['isBookmarked'] == true ? const Color(0xFFD4AF37) : Colors.grey,
                  size: 20.0,
                ),
                onPressed: () => _toggleBookmark(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostImages(List images) {
    // Case 1: Nandhini S custom 3-image container layout
    if (images.length == 3 && images[0] == 'special_text_card') {
      return SizedBox(
        height: 120.0,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                ),
                padding: const EdgeInsets.all(8.0),
                child: const Center(
                  child: Text(
                    'FROM ₹30K TO\n₹3L+ PER\nMONTH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFCC0000),
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: _buildSingleImageWidget(images[1] as String),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: _buildSingleImageWidget(images[2] as String),
              ),
            ),
          ],
        ),
      );
    }

    // Case 2: Single full-width image
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildSingleImageWidget(images[0] as String),
        ),
      );
    }

    // Case 3: Multiple images in horizontal scrolling row
    return SizedBox(
      height: 120.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            width: 120.0,
            margin: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: _buildSingleImageWidget(images[index] as String),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleImageWidget(String path) {
    if (path.startsWith('http') || path.startsWith('https')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Icon(Icons.image_not_supported_rounded, color: Colors.white24),
        ),
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Icon(Icons.image_not_supported_rounded, color: Colors.white24),
        ),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Icon(Icons.image_not_supported_rounded, color: Colors.white24),
        ),
      );
    }
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: color.withOpacity(0.5), width: 1.0),
        color: color.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label.contains('Growth') ? Icons.trending_up_rounded : Icons.flash_on_rounded,
            size: 9.0,
            color: color,
          ),
          const SizedBox(width: 3.0),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionItem({
    required IconData icon,
    required Color iconColor,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 18.0,
        ),
        const SizedBox(width: 4.0),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12.0,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(Map<String, dynamic> post) {
    final userName = post['name'] as String;
    final isPlaying = _playingVideos[userName] ?? false;
    final progress = _videoProgress[userName] ?? 0.0;
    final elapsed = _videoElapsed[userName] ?? 0;
    final videoThumbnail = post['videoThumbnail'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _togglePlayVideo(userName),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  videoThumbnail,
                  width: double.infinity,
                  height: 200.0,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200.0,
                    color: const Color(0xFF1C1C1E),
                    child: const Icon(Icons.video_library_rounded, color: Colors.white24, size: 40),
                  ),
                ),
              ),
              if (isPlaying)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              Container(
                width: 54.0,
                height: 54.0,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36.0,
                ),
              ),
            ],
          ),
        ),
        if (isPlaying || progress > 0.0) ...[
          const SizedBox(height: 6.0),
          Row(
            children: [
              Text(
                '00:${elapsed.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey, fontSize: 10.0),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2.0),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCC0000)),
                    minHeight: 4.0,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              const Text(
                '00:20',
                style: TextStyle(color: Colors.grey, fontSize: 10.0),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBottomNavigationBar(double barWidth) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: barWidth,
              height: 75.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Glassmorphic background layer
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24.0),
                        topRight: Radius.circular(24.0),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF990000).withOpacity(0.35),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24.0),
                              topRight: Radius.circular(24.0),
                            ),
                            border: Border.all(
                              color: const Color(0xFF990000).withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Navigation items layer (on top of background, no clipping)
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildBottomNavItem(0, Icons.home, 'HOME', true)),
                        Expanded(child: _buildBottomNavItem(1, Icons.emoji_events, 'WINS', false)),
                        Expanded(child: _buildVoiceOfSakthiItem(2)),
                        Expanded(child: _buildBottomNavItem(3, Icons.school, 'COURSES', false)),
                        Expanded(child: _buildBottomNavItem(4, Icons.person, 'PROFILE', false)),
                      ],
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

  Widget _buildBottomNavItem(int index, IconData icon, String label, bool isSelected) {
    if (isSelected) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        height: 52.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFF990000),
              size: 20.0,
            ),
            const SizedBox(height: 3.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF990000),
                  fontSize: 10.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          Navigator.pop(context, index);
        },
        child: Container(
          height: 52.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.65),
                size: 22.0,
              ),
              const SizedBox(height: 4.0),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildVoiceOfSakthiItem(int index) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, index);
      },
      child: Container(
        height: 75.0,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -24.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54.0,
                    height: 54.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 1.5,
                      ),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/nav  bar.jpeg'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VOICE OF SAKTHI',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
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
}
