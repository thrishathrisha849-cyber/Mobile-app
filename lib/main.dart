import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'community.dart';
import 'profile.dart';
import 'podcast.dart';
import 'courses.dart';
import 'task.dart';

class SessionManager {
  static Future<File> _getSessionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/session_state.txt');
  }

  static Future<bool> isLoggedIn() async {
    try {
      final file = await _getSessionFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return content.trim() == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<void> setLoggedIn(bool loggedIn) async {
    try {
      final file = await _getSessionFile();
      await file.writeAsString(loggedIn ? 'true' : 'false');
    } catch (e) {
      debugPrint('Error writing session: $e');
    }
  }
}

class SavedBooksManager {
  static Future<File> _getSaveFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/saved_books_state.txt');
  }

  static Future<List<String>> getSavedBooks() async {
    try {
      final file = await _getSaveFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      return content.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> toggleSaveBook(String bookTitle) async {
    final saved = await getSavedBooks();
    if (saved.contains(bookTitle)) {
      saved.remove(bookTitle);
    } else {
      saved.add(bookTitle);
    }
    final file = await _getSaveFile();
    await file.writeAsString(saved.join('\n'));
  }
  
  static Future<bool> isBookSaved(String bookTitle) async {
    final saved = await getSavedBooks();
    return saved.contains(bookTitle);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tamil Business Tribe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD32F2F),
          surface: Color(0xFF121214),
          onSurface: Colors.white,
        ),
      ),
      home: const TBTVideoSplashScreen(),
    );
  }
}

class TBTVideoSplashScreen extends StatefulWidget {
  const TBTVideoSplashScreen({super.key});

  @override
  State<TBTVideoSplashScreen> createState() => _TBTVideoSplashScreenState();
}

class _TBTVideoSplashScreenState extends State<TBTVideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/images/tbt_logo_video.mp4');
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.play();
      }
    }).catchError((error) {
      debugPrint('Error initializing video splash: $error');
      _navigateToMain();
    });

    _controller.addListener(() {
      if (mounted && _controller.value.position >= _controller.value.duration) {
        _navigateToMain();
      }
    });

    // Fallback timer to navigate to main app after 6 seconds in case of loading issues
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      _navigateToMain();
    });
  }

  void _navigateToMain() async {
    if (!_navigated && mounted) {
      _navigated = true;
      _fallbackTimer?.cancel();
      _controller.pause();
      
      final loggedIn = await SessionManager.isLoggedIn();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => loggedIn ? const PostPopupScreen() : const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD30814)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostPopupScreen extends StatefulWidget {
  const PostPopupScreen({super.key});

  @override
  State<PostPopupScreen> createState() => _PostPopupScreenState();
}

class _PostPopupScreenState extends State<PostPopupScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;
  XFile? _pickedImage;
  XFile? _pickedVideo;
  PlatformFile? _pickedAudio;
  String _visibility = 'Public';

  int _currentCarouselPage = 0;
  late final PageController _carouselPageController;
  Timer? _carouselTimer;
  final ScrollController _scrollController = ScrollController();
  bool _showPostCard = true;
  bool _isPostCardExpanded = true;
  int _currentTabIndex = 0;
  final GlobalKey _mentorCardKey = GlobalKey();

  // Morning Ritual states
  bool _showMorningRitual = true;
  bool _isMorningRitualExpanded = true;
  int _currentRitualStep = 0;
  late final PageController _ritualPageController;
  final List<bool?> _ritualAnswers = List.filled(5, null);

  // List of popular emojis grouped for a premium selection feel
  final List<String> _emojis = [
    // Smileys
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '😉', '😌', '😍', '🥰', '😘', '😋', '😛', '😜', '😎',
    '🤩', '🥳', '😏', '🤔', '🤨', '😐', '😑', '🙄', '😬', '😴',
    // Hands & Gestures
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '👋', '👏', '🙏', '🙌',
    // Hearts & Miscellaneous
    '❤️', '💖', '🔥', '🚀', '🎉', '🌟', '✨', '💯', '🎈', '💼',
    '📈', '💡', '🏆', '🎯', '🤝', '📣', '🔔', '🌍', '🇮🇳', '💻'
  ];

  @override
  void initState() {
    super.initState();
    _ritualPageController = PageController(initialPage: 0);
    // Start at a large index that is a multiple of 2 (so initial page translates to 0)
    _carouselPageController = PageController(initialPage: 1000);
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_carouselPageController.hasClients) {
        _carouselPageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Hide emoji picker when keyboard is focused
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
     _carouselTimer?.cancel();
     _carouselPageController.dispose();
     _ritualPageController.dispose();
     _scrollController.dispose();
     _textController.dispose();
     _focusNode.dispose();
     super.dispose();
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;

    if (selection.start < 0) {
      // If there's no active cursor position, append emoji to the end
      _textController.text = text + emoji;
      // Move cursor to the end
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else {
      // Insert emoji at current cursor selection
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      final int newOffset = selection.start + emoji.length;
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
        ),
      );
      if (result != null && result.isNotEmpty) {
        final File? file = await result.first.file;
        if (file != null) {
          setState(() {
            _pickedImage = XFile(file.path);
            _pickedVideo = null; // Clear video
            _pickedAudio = null; // Clear audio
            _showEmojiPicker = false; // Hide emoji drawer
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting photo: $e'),
          backgroundColor: const Color(0xFFD30814),
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.video,
        ),
      );
      if (result != null && result.isNotEmpty) {
        final File? file = await result.first.file;
        if (file != null) {
          setState(() {
            _pickedVideo = XFile(file.path);
            _pickedImage = null; // Clear image
            _pickedAudio = null; // Clear audio
            _showEmojiPicker = false; // Hide emoji drawer
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: const Color(0xFFD30814),
        ),
      );
    }
  }

  Future<void> _pickAudio() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedAudio = result.files.single;
          _pickedImage = null; // Clear image
          _pickedVideo = null; // Clear video
          _showEmojiPicker = false; // Hide emoji drawer
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting audio: $e'),
          backgroundColor: const Color(0xFFD30814),
        ),
      );
    }
  }

  void _showVisibilitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12.0),
              // Drag handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              const SizedBox(height: 20.0),
              const Text(
                'Who can see this?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.white70),
                title: const Text('Public', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Anyone on or off Tamil Business Tribe',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.0),
                ),
                trailing: _visibility == 'Public'
                    ? const Icon(Icons.check, color: Color(0xFFD30814))
                    : null,
                onTap: () {
                  setState(() {
                    _visibility = 'Public';
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Color(0xFF2C2C2E)),
              ListTile(
                leading: const Icon(Icons.people_alt_rounded, color: Colors.white70),
                title: const Text('Friends', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Your connections on Tamil Business Tribe',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.0),
                ),
                trailing: _visibility == 'Friends'
                    ? const Icon(Icons.check, color: Color(0xFFD30814))
                    : null,
                onTap: () {
                  setState(() {
                    _visibility = 'Friends';
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F11),
              Color(0xFF050505),
            ],
          ),
        ),
        child: Column(
          children: [
            // Fixed TBT Header Section
            SafeArea(
              bottom: false,
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SizedBox(
                    height: 70.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          // Left Menu Icon
                          _buildCustomMenuIcon(),
                          // Centered Logo
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              child: _buildTBTLogo(),
                            ),
                          ),
                          // Right Action Icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildStreakWidget(),
                              const SizedBox(width: 16.0),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                                child: _buildNotificationWidget(),
                              ),
                              const SizedBox(width: 16.0),
                              _buildProfileAvatar(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Scrollable Content Section
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: 120.0,
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Greeting text
                        const Text(
                          'Hi, Thrisha',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        // Main Post Card
                        if (_showPostCard) Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141416),
                            borderRadius: BorderRadius.circular(28.0),
                            border: Border.all(
                              color: const Color(0xFF232326),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 30.0,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _isPostCardExpanded
                                          ? 'What did you achieve today? 🚀'
                                          : 'What did you achieve today?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isPostCardExpanded = !_isPostCardExpanded;
                                      });
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2C2C2E),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isPostCardExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        color: const Color(0xFFD1D1D6),
                                        size: 24.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isPostCardExpanded) ...[
                                const SizedBox(height: 6.0),
                                const Text(
                                  'Share your progress, inspire others, celebrate wins!',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isPostCardExpanded) ...[
                      const SizedBox(height: 24.0),

                    // Main input container
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: const Color(0xFF2C2C2E),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Avatar, Text Input & Smiley Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: ProfileScreen.profileImagePath != null
                                    ? Image.file(
                                        File(ProfileScreen.profileImagePath!),
                                        width: 40.0,
                                        height: 40.0,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                                        width: 40.0,
                                        height: 40.0,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 40.0,
                                            height: 40.0,
                                            color: const Color(0xFF48484A),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white70,
                                              size: 20.0,
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(width: 12.0),

                              // TextField Input
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: TextField(
                                    controller: _textController,
                                    focusNode: _focusNode,
                                    maxLines: null,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.0,
                                    ),
                                    decoration: const InputDecoration.collapsed(
                                      hintText: 'Share your wins, big or small...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF7C7C80),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),

                              // Smiley Face Icon
                              IconButton(
                                icon: const Icon(
                                  Icons.emoji_emotions_outlined,
                                  color: Color(0xFF8E8E93),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showEmojiPicker = !_showEmojiPicker;
                                    if (_showEmojiPicker) {
                                      _focusNode.unfocus();
                                    } else {
                                      _focusNode.requestFocus(); // Open keyboard
                                    }
                                  });
                                },
                              ),
                            ],
                          ),

                          // Custom Animated Emoji Picker Drawer
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _showEmojiPicker
                                ? Container(
                                    margin: const EdgeInsets.only(top: 20.0),
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF121214),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: const Color(0xFF242426),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: GridView.builder(
                                      padding: const EdgeInsets.all(12.0),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        mainAxisSpacing: 8.0,
                                        crossAxisSpacing: 8.0,
                                      ),
                                      itemCount: _emojis.length,
                                      itemBuilder: (context, index) {
                                        return InkWell(
                                          onTap: () => _insertEmoji(_emojis[index]),
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: Center(
                                            child: Text(
                                              _emojis[index],
                                              style: const TextStyle(fontSize: 22.0),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Image Preview Widget
                          if (_pickedImage != null)
                            Container(
                              margin: const EdgeInsets.only(top: 20.0),
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(
                                  color: const Color(0xFF2C2C2E),
                                  width: 1.0,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15.0),
                                    child: Image.file(
                                      File(_pickedImage!.path),
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8.0,
                                    right: 8.0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pickedImage = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Video Preview Widget
                          if (_pickedVideo != null)
                            Container(
                              margin: const EdgeInsets.only(top: 20.0),
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF121214),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(
                                  color: const Color(0xFF2C2C2E),
                                  width: 1.0,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.video_library_rounded,
                                          color: Color(0xFF27AE60),
                                          size: 40.0,
                                        ),
                                        const SizedBox(height: 8.0),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          child: Text(
                                            _pickedVideo!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 8.0,
                                    right: 8.0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pickedVideo = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Audio Preview Widget
                          if (_pickedAudio != null)
                            Container(
                              margin: const EdgeInsets.only(top: 20.0),
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF121214),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(
                                  color: const Color(0xFF2C2C2E),
                                  width: 1.0,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 16.0),
                                        const Icon(
                                          Icons.audiotrack_rounded,
                                          color: Color(0xFF9B51E0),
                                          size: 32.0,
                                        ),
                                        const SizedBox(width: 12.0),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 48.0),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _pickedAudio!.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4.0),
                                                Text(
                                                  '${(_pickedAudio!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                                  style: const TextStyle(
                                                    color: Color(0xFF8E8E93),
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 8.0,
                                    right: 8.0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pickedAudio = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 36.0),

                          // Media row items divider & layout
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121214),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: const Color(0xFF242426),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMediaItem(
                                  icon: Icons.image,
                                  color: const Color(0xFF2F80ED),
                                  label: 'Photo',
                                  onTap: _pickImage,
                                ),
                                _buildDivider(),
                                _buildMediaItem(
                                  icon: Icons.videocam,
                                  color: const Color(0xFF27AE60),
                                  label: 'Video',
                                  onTap: _pickVideo,
                                ),
                                _buildDivider(),
                                _buildMediaItem(
                                  icon: Icons.mic,
                                  color: const Color(0xFF9B51E0),
                                  label: 'Audio',
                                  onTap: _pickAudio,
                                ),
                                _buildDivider(),
                                _buildMediaItem(
                                  icon: Icons.rocket_launch,
                                  color: const Color(0xFFEB5757),
                                  label: 'Milestone',
                                  onTap: () {
                                    setState(() {
                                      _isPostCardExpanded = false;
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (_mentorCardKey.currentContext != null) {
                                        Scrollable.ensureVisible(_mentorCardKey.currentContext!, duration: const Duration(milliseconds: 300));
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Public/Friends Selection Button
                        Flexible(
                          child: InkWell(
                            onTap: _showVisibilitySelector,
                            borderRadius: BorderRadius.circular(24.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 10.0,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24.0),
                                border: Border.all(
                                  color: const Color(0xFF2C2C2E),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _visibility == 'Public' ? Icons.public : Icons.people_alt_rounded,
                                    color: const Color(0xFFD1D1D6),
                                    size: 18.0,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _visibility,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF8E8E93),
                                    size: 18.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),

                        // Post to Community Button
                        Flexible(
                          child: InkWell(
                            onTap: () {
                              if (_textController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter post content!'),
                                    backgroundColor: Color(0xFFCC0000),
                                  ),
                                );
                                return;
                              }
                              
                              // Insert new post to global communityPosts database
                              communityPosts.insert(0, {
                                'name': 'Sakthi (You)',
                                'role': 'TBT Member',
                                'time': 'Just now',
                                'badge': 'Milestone',
                                'badgeColor': const Color(0xFFCC0000),
                                'avatarUrl': 'assets/images/nav  bar.jpeg',
                                'content': _textController.text.trim(),
                                'likes': 0,
                                'comments': 0,
                                'shares': 0,
                                'isLiked': false,
                                'isBookmarked': false,
                                'isFollowing': false,
                                'isMentor': false,
                                'hasImages': _pickedImage != null,
                                if (_pickedImage != null)
                                  'images': [ _pickedImage!.path ],
                                'hasVideo': _pickedVideo != null,
                                if (_pickedVideo != null)
                                  'videoThumbnail': 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600',
                              });

                              // Enforce maximum of 10 posts in the feed
                              if (communityPosts.length > 10) {
                                communityPosts.removeRange(10, communityPosts.length);
                              }

                              // Persist updated posts list to local storage
                              savePostsToLocal();

                              setState(() {
                                _textController.clear();
                                _pickedImage = null;
                                _pickedVideo = null;
                                _pickedAudio = null;
                                _isPostCardExpanded = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Successfully posted to Community! 🎉'),
                                  backgroundColor: Color(0xFF27AE60),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(24.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 10.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD30814),
                                borderRadius: BorderRadius.circular(24.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD30814).withOpacity(0.3),
                                    blurRadius: 10.0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Post to Community',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 16.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Container(key: _mentorCardKey, child: _buildMentorPosterCard()),
                    const SizedBox(height: 16.0),
                    _buildCarouselIndicator(),
                    if (_showMorningRitual) ...[
                      const SizedBox(height: 24.0),
                      _buildMorningRitualCard(),
                    ],
                    const SizedBox(height: 24.0),
                    _buildMenuGrid(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
  bottomNavigationBar: _buildBottomNavigationBar(),
);
}

  IconData _getRitualIcon(int index) {
    switch (index) {
      case 0:
        return Icons.wb_sunny_outlined;
      case 1:
        return Icons.self_improvement;
      case 2:
        return Icons.track_changes;
      case 3:
        return Icons.fitness_center;
      case 4:
      default:
        return Icons.local_cafe;
    }
  }

  String _getRitualSubtitle(int index) {
    switch (index) {
      case 0:
        return "Build clarity. Boost focus. Start your day right.";
      case 1:
        return "Calm your mind. Find presence. Center yourself.";
      case 2:
        return "Prioritize tasks. Direct your energy. Stay productive.";
      case 3:
        return "Activate your body. Boost energy. Stay healthy.";
      case 4:
      default:
        return "Nourish your body. Fuel your mind for the day.";
    }
  }

  List<TextSpan> _getRitualQuestionSpans(int index) {
    switch (index) {
      case 0:
        return const [
          TextSpan(text: 'Did you write your '),
          TextSpan(
            text: 'morning pages?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 1:
        return const [
          TextSpan(text: 'Did you meditate '),
          TextSpan(
            text: 'for 10 minutes?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 2:
        return const [
          TextSpan(text: 'Did you plan your '),
          TextSpan(
            text: 'daily goals?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 3:
        return const [
          TextSpan(text: 'Did you exercise or '),
          TextSpan(
            text: 'stretch today?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 4:
      default:
        return const [
          TextSpan(text: 'Did you eat a '),
          TextSpan(
            text: 'healthy breakfast?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
    }
  }

  void _handleRitualAnswer(bool answer) {
    setState(() {
      _ritualAnswers[_currentRitualStep] = answer;
      if (_currentRitualStep < 4) {
        _currentRitualStep++;
        _ritualPageController.animateToPage(
          _currentRitualStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _currentRitualStep = 5; // Completion state
      }
    });
  }

  Future<void> _shareAssetImage(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = Directory.systemTemp;
      final fileName = assetPath.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('Error sharing asset: $e');
    }
  }

  Widget _buildMorningRitualCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(28.0),
        border: Border.all(
          color: const Color(0xFFFF3B30).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withOpacity(0.08),
            blurRadius: 24.0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              // Ritual Tag
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.4),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        color: Color(0xFFFF3B30),
                        size: 16.0,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    const Expanded(
                      child: Text(
                        'MORNING RITUAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              // Step counter pill
              if (_currentRitualStep < 5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '${_currentRitualStep + 1} / 5',
                    style: const TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12.0),
              // Dropdown button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMorningRitualExpanded = !_isMorningRitualExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMorningRitualExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFD1D1D6),
                    size: 16.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Progress lines
          Row(
            children: List.generate(5, (index) {
              final isCompletedOrActive = _currentRitualStep >= 5 || index <= _currentRitualStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: index == 0 ? 0.0 : 4.0),
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: isCompletedOrActive
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(2.0),
                    boxShadow: isCompletedOrActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withOpacity(0.6),
                              blurRadius: 6.0,
                              spreadRadius: 1.0,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          if (_isMorningRitualExpanded) ...[
            const SizedBox(height: 24.0),

          // Main Step PageView or Completion screen
          if (_currentRitualStep < 5) ...[
            SizedBox(
              height: 200.0,
              child: PageView.builder(
                controller: _ritualPageController,
                itemCount: 5,
                onPageChanged: (int page) {
                  setState(() {
                    _currentRitualStep = page;
                  });
                },
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glow Sun / Step Icon
                      Container(
                        width: 60.0,
                        height: 60.0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF3B30),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withOpacity(0.3),
                              blurRadius: 12.0,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getRitualIcon(index),
                          color: const Color(0xFFFF3B30),
                          size: 26.0,
                        ),
                      ),
                      const SizedBox(height: 18.0),
                      // Question
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                          children: _getRitualQuestionSpans(index),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Subtitle
                      Text(
                        _getRitualSubtitle(index),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 14.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24.0),

            // Footer Actions
            Row(
              children: [
                // Not Yet Button
                Expanded(
                  child: InkWell(
                    onTap: () => _handleRitualAnswer(false),
                    borderRadius: BorderRadius.circular(16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: const Color(0xFF2C2C2E),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.close_rounded,
                            color: Color(0xFF8E8E93),
                            size: 18.0,
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            'Not Yet',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                // Yes Button
                Expanded(
                  child: InkWell(
                    onTap: () => _handleRitualAnswer(true),
                    borderRadius: BorderRadius.circular(16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF3B30),
                            Color(0xFFFF5E3A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withOpacity(0.3),
                            blurRadius: 10.0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18.0,
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            'Yes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Completed State
            Column(
              children: [
                const SizedBox(height: 20.0),
                Container(
                  width: 60.0,
                  height: 60.0,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 12.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 32.0,
                  ),
                ),
                const SizedBox(height: 18.0),
                const Text(
                  'Morning Ritual Completed!',
                  style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Success! You checked off ${_ritualAnswers.where((e) => e == true).length} of 5 morning habits.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 10.0),
              ],
            ),
          ],
          ],
        ],
      ),
    );
  }

  Widget _buildMediaItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 16.0,
          ),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD1D1D6),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 16.0,
      width: 1.0,
      color: const Color(0xFF2C2C2E),
    );
  }

  Widget _buildCustomMenuIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
        const SizedBox(height: 5.0),
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
        const SizedBox(height: 5.0),
        Container(
          width: 11,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
      ],
    );
  }

  Widget _buildTBTLogo() {
    return Image.asset(
      'assets/images/TBT C Pvt Final logo-04.png',
      height: 68.0,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign, color: Color(0xFFD30814), size: 20.0),
            const SizedBox(width: 4.0),
            const Text(
              'TBT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakWidget() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.3),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(bounds),
            child: const Icon(
              Icons.whatshot_rounded,
              color: Colors.white,
              size: 18.0,
            ),
          ),
          const Positioned(
             bottom: 2,
             child: Text(
               '12',
               style: TextStyle(
                 color: Colors.white,
                 fontSize: 9.0,
                 fontWeight: FontWeight.w900,
                 shadows: [
                   Shadow(
                     color: Colors.black,
                     blurRadius: 3.0,
                     offset: Offset(0, 1),
                   ),
                 ],
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationWidget() {
    return Stack(
      children: [
        const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 22.0,
        ),
        Positioned(
          right: 1,
          top: 1,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFD30814),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFD30814),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: ProfileScreen.profileImagePath != null
              ? Image.file(
                  File(ProfileScreen.profileImagePath!),
                  width: 24.0,
                  height: 24.0,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                  width: 24.0,
                  height: 24.0,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 24.0,
                      height: 24.0,
                      color: const Color(0xFF48484A),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 14.0,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildMentorPosterCard() {
    final List<String> images = [
      'assets/images/whatsapp_image.jpeg',
      'assets/images/tbt_2.jpeg',
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.5),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Stack(
            children: [
              PageView.builder(
                controller: _carouselPageController,
                onPageChanged: (int index) {
                  setState(() {
                    _currentCarouselPage = index % images.length;
                  });
                },
                itemBuilder: (context, index) {
                  final imageIndex = index % images.length;
                  return Image.asset(
                    images[imageIndex],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF0F0F11),
                        alignment: Alignment.center,
                        child: Text(
                          'TBT Poster ${imageIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              Positioned(
                top: 16.0,
                right: 16.0,
                child: BlinkingShareButton(
                  onTap: () {
                    final assetPath = images[_currentCarouselPage];
                    _shareAssetImage(assetPath);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: _currentCarouselPage == 0 ? 7 : 5,
          height: _currentCarouselPage == 0 ? 7 : 5,
          decoration: BoxDecoration(
            color: _currentCarouselPage == 0 ? Colors.white : const Color(0xFF48484A),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6.0),
        Container(
          width: _currentCarouselPage == 1 ? 7 : 5,
          height: _currentCarouselPage == 1 ? 7 : 5,
          decoration: BoxDecoration(
            color: _currentCarouselPage == 1 ? Colors.white : const Color(0xFF48484A),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInSlideTransition(
          delay: const Duration(milliseconds: 100),
          child: Row(
            children: [
              Expanded(
                child: AnimatedGlassCard(
                  title: 'Community',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF00F2FE),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CommunityScreen()),
                    ).then((value) {
                      if (value is int) {
                        setState(() {
                          _currentTabIndex = value;
                        });
                        if (value == 4) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          ).then((_) {
                            setState(() {
                              _currentTabIndex = 0;
                            });
                          });
                        }
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: AnimatedGlassCard(
                  title: 'Courses',
                  icon: Icons.school_rounded,
                  color: const Color(0xFFF2994A),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoursesScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),
        FadeInSlideTransition(
          delay: const Duration(milliseconds: 250),
          child: Row(
            children: [
              Expanded(
                child: AnimatedGlassCard(
                  title: 'Podcast',
                  icon: Icons.podcasts_rounded,
                  color: const Color(0xFFE285FF),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PodcastScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: AnimatedGlassCard(
                  title: 'Workshop',
                  icon: Icons.co_present_rounded,
                  color: const Color(0xFFFF5E62),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),
        FadeInSlideTransition(
          delay: const Duration(milliseconds: 400),
          child: Row(
            children: [
              Expanded(
                child: AnimatedGlassCard(
                  title: 'E-Book',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF38EF7D),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EBooksLibraryScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: AnimatedGlassCard(
                  title: 'Task',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF2F80ED),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TasksScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildBottomNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = screenWidth > 500 ? 500.0 : screenWidth;

    return NativeGlassNavigationBar(
      tabs: const [
        NativeGlassTab(icon: 'home', label: 'HOME'),
        NativeGlassTab(icon: 'trophy', label: 'WINS'),
        NativeGlassTab(icon: 'avatar', label: 'VOICE OF SAKTHI'),
        NativeGlassTab(icon: 'school', label: 'COURSES'),
        NativeGlassTab(icon: 'person', label: 'PROFILE'),
      ],
      fallback: Container(
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
                          Expanded(child: _buildNavItem(0, Icons.home, 'HOME')),
                          Expanded(child: _buildNavItem(1, Icons.emoji_events, 'WINS')),
                          Expanded(child: _buildVoiceOfSakthiItem(2)),
                          Expanded(child: _buildNavItem(3, Icons.school, 'COURSES')),
                          Expanded(child: _buildNavItem(4, Icons.person, 'PROFILE')),
                        ],
                      ),
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    if (isSelected) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        height: 52.0,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
              color: Colors.white,
              size: 20.0,
            ),
            const SizedBox(height: 3.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CoursesScreen()),
            ).then((_) {
              setState(() {
                _currentTabIndex = 0;
              });
            });
            return;
          }
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ).then((_) {
              setState(() {
                _currentTabIndex = 0;
              });
            });
            return;
          }
          setState(() {
            _currentTabIndex = index;
          });
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
    final isSelected = _currentTabIndex == index;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PodcastScreen()),
        ).then((_) {
          setState(() {
            _currentTabIndex = 0;
          });
        });
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
                        color: isSelected ? Colors.white : Colors.amber.shade700,
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
                        color: isSelected ? Colors.yellow : Colors.white,
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

class BlinkingShareButton extends StatefulWidget {
  final VoidCallback onTap;

  const BlinkingShareButton({super.key, required this.onTap});

  @override
  State<BlinkingShareButton> createState() => _BlinkingShareButtonState();
}

class _BlinkingShareButtonState extends State<BlinkingShareButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2),
                border: Border.all(
                  color: const Color(0xFFD30814).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 18.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class FadeInSlideTransition extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeInSlideTransition({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<FadeInSlideTransition> createState() => _FadeInSlideTransitionState();
}

class _FadeInSlideTransitionState extends State<FadeInSlideTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _offset = Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class AnimatedGlassCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isFullWidth;
  final VoidCallback onTap;

  const AnimatedGlassCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.94;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          height: widget.isFullWidth ? 80.0 : 110.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.5),
            child: widget.isFullWidth
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.color, size: 30.0),
                      const SizedBox(width: 12.0),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.color, size: 32.0),
                      const SizedBox(height: 10.0),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    SessionManager.setLoggedIn(true).then((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PostPopupScreen()),
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD30814),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0202), // Subtle dark red glow
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20.0),
                    Image.asset(
                      'assets/images/TBT C Pvt Final logo-04.png',
                      height: 90.0,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'TBT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12.0),
                    Container(
                      width: 32.0,
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD30814),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    const Text(
                      'YOUR BUSINESS. ELEVATED.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    Container(
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.03),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          const Text(
                            'Sign In to access your courses, webinars & books',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.0,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white, fontSize: 14.0),
                              decoration: const InputDecoration(
                                hintText: 'Enter your email address',
                                hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                                prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.white30, size: 20.0),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 14.0),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13.0),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 20.0),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.white30,
                                    size: 20.0,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Color(0xFFD30814),
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          SizedBox(
                            width: double.infinity,
                            height: 48.0,
                            child: ElevatedButton(
                              onPressed: _handleSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD30814),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 0.0,
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Join TBT',
                            style: TextStyle(
                              color: Color(0xFFD30814),
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'TERMS OF SERVICE',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          width: 3.0,
                          height: 3.0,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        const Text(
                          'PRIVACY POLICY',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    const Text(
                      '© 2026 Tamil Business Tribe. All rights reserved.',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 9.0,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendLink() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Color(0xFFD30814),
        ),
      );
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFFD30814),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32.0,
                  ),
                ),
                const SizedBox(height: 20.0),
                const Text(
                  'Link Sent!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'A password reset link has been successfully sent to $email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13.0,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  height: 44.0,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD30814),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0.0,
                    ),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
              Color(0xFF1A0202), // Subtle dark red glow
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10.0),
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 90.0,
                          height: 90.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141416),
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10.0,
                                spreadRadius: 1.0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mail_outline_rounded,
                            color: Colors.white30,
                            size: 44.0,
                          ),
                        ),
                        Positioned(
                          bottom: -6.0,
                          right: -6.0,
                          child: Container(
                            width: 34.0,
                            height: 34.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD30814),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD30814).withOpacity(0.4),
                                  blurRadius: 8.0,
                                  spreadRadius: 1.0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 16.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36.0),
                    const Text(
                      'Forgot your password?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        "Enter your registered email and we'll send you a reset link.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13.0,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36.0),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'EMAIL ADDRESS',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Enter your email address',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                          prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.white30, size: 20.0),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _handleSendLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD30814),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0.0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Send Reset Link',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.0),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Remember your password? ",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Back to Sign In',
                            style: TextStyle(
                              color: Color(0xFFD30814),
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48.0),
                    const Text(
                      'CONTACT SUPPORT IF YOU\'RE HAVING TROUBLE',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  String _selectedInterest = 'Courses';
  bool _whatsAppUpdates = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleJoin() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('All fields are required');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WelcomeTBTScreen(userName: name),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD30814),
      ),
    );
  }

  Widget _buildInterestChip(String label, IconData icon) {
    final isSelected = _selectedInterest == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInterest = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD30814) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white30,
              size: 16.0,
            ),
            const SizedBox(width: 8.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CREATE ACCOUNT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
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
              Color(0xFF1A0202), // Subtle dark red glow
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10.0),
                    Image.asset(
                      'assets/images/TBT C Pvt Final logo-04.png',
                      height: 90.0,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'TBT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 36.0),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Full Name',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white30, size: 20.0),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email Address',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                          prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.white30, size: 20.0),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Phone / WhatsApp',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                          prefixIcon: Icon(Icons.phone_iphone_rounded, color: Colors.white30, size: 20.0),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 12.0),
                        child: Text(
                          'For exclusive webinar reminders',
                          style: TextStyle(color: Colors.white38, fontSize: 10.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13.0),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 20.0),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white30,
                              size: 20.0,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                        decoration: const InputDecoration(
                          hintText: 'Confirm Password',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 13.0),
                          prefixIcon: Icon(Icons.shield_outlined, color: Colors.white30, size: 20.0),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PRIMARY INTEREST',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.start,
                      children: [
                        _buildInterestChip('Courses', Icons.assignment_outlined),
                        _buildInterestChip('Webinars', Icons.ondemand_video_rounded),
                        _buildInterestChip('Books', Icons.menu_book_rounded),
                        _buildInterestChip('Networking', Icons.people_outline_rounded),
                      ],
                    ),
                    const SizedBox(height: 28.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'WhatsApp updates & reminders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: _whatsAppUpdates,
                          onChanged: (val) {
                            setState(() {
                              _whatsAppUpdates = val;
                            });
                          },
                          activeColor: const Color(0xFFD30814),
                          activeTrackColor: const Color(0xFFD30814).withOpacity(0.4),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.white12,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _handleJoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD30814),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0.0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'JOIN TAMIL BUSINESS TRIBE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.0),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: TextStyle(color: Colors.white24, fontSize: 11.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: OutlinedButton(
                        onPressed: () {
                          _showError('Google Sign-In is not configured yet');
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.png',
                              height: 18.0,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.g_mobiledata_rounded, color: Colors.black);
                              },
                            ),
                            const SizedBox(width: 12.0),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already a member? ",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFFD30814),
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeTBTScreen extends StatefulWidget {
  final String userName;
  const WelcomeTBTScreen({super.key, required this.userName});

  @override
  State<WelcomeTBTScreen> createState() => _WelcomeTBTScreenState();
}

class _WelcomeTBTScreenState extends State<WelcomeTBTScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  late Animation<double> _titleOpacity;
  late Animation<double> _titleSlide;
  late Animation<double> _checkScale;
  late Animation<double> _welcomeOpacity;
  late Animation<double> _welcomeSlide;
  late Animation<double> _nameOpacity;
  late Animation<double> _nameSlide;
  late Animation<double> _badgeScale;
  late Animation<double> _buttonOpacity;
  late Animation<double> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: -30.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
    ));

    _welcomeOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );
    _welcomeSlide = Tween<double>(begin: 20.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    ));

    _nameOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    );
    _nameSlide = Tween<double>(begin: 20.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    ));

    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.9, curve: Curves.elasticOut),
    ));

    _buttonOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<double>(begin: 30.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleExplore() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PostPopupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0202), // Premium subtle dark red glow
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20.0),
                        Transform.translate(
                          offset: Offset(0.0, _titleSlide.value),
                          child: Opacity(
                            opacity: _titleOpacity.value,
                            child: const Text(
                              'TAMIL BUSINESS\nTRIBE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD30814),
                                fontSize: 28.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48.0),
                        
                        Transform.scale(
                          scale: _checkScale.value,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 90.0,
                                  height: 90.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFD30814).withOpacity(0.1),
                                    border: Border.all(
                                      color: const Color(0xFFD30814).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 60.0,
                                  height: 60.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFD30814),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD30814).withOpacity(0.4),
                                        blurRadius: 12.0,
                                        spreadRadius: 1.0,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 32.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40.0),

                        Transform.translate(
                          offset: Offset(0.0, _welcomeSlide.value),
                          child: Opacity(
                            opacity: _welcomeOpacity.value,
                            child: const Text(
                              'Welcome to TBT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12.0),

                        Transform.translate(
                          offset: Offset(0.0, _nameSlide.value),
                          child: Opacity(
                            opacity: _nameOpacity.value,
                            child: Text(
                              'Hello, ${widget.userName} 👋',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),

                        Transform.scale(
                          scale: _badgeScale.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: const Color(0xFFD30814).withOpacity(0.35),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'MASTER MEMBER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80.0),

                        Transform.translate(
                          offset: Offset(0.0, _buttonSlide.value),
                          child: Opacity(
                            opacity: _buttonOpacity.value,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 52.0,
                                  child: ElevatedButton(
                                    onPressed: _handleExplore,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD30814),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14.0),
                                      ),
                                      elevation: 0.0,
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Explore TBT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8.0),
                                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18.0),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32.0),
                                const Text(
                                  'AUTHORIZED EXECUTIVE ACCESS ONLY',
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class EBooksScreen extends StatefulWidget {
  const EBooksScreen({super.key});

  @override
  State<EBooksScreen> createState() => _EBooksScreenState();
}

class _EBooksScreenState extends State<EBooksScreen> {
  String _selectedCategory = 'All Library';
  bool _isSaved = false;

  final List<String> _categories = [
    'All Library',
    'Entrepreneurship',
    'Marketing',
    'Sales',
    'Personal Finance'
  ];

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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD30814) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Text(
          category.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBookCover({
    required String title,
    required String subtitle,
    required Color baseColor,
    required Color accentColor,
    String? imagePath,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
    double width = 120.0,
    double height = 180.0,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8.0,
            spreadRadius: 1.0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: imagePath != null
            ? Image.asset(
                imagePath,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackCover(title, subtitle, baseColor, accentColor, width, height, badgeText, badgeColor, badgeTextColor);
                },
              )
            : _buildFallbackCover(title, subtitle, baseColor, accentColor, width, height, badgeText, badgeColor, badgeTextColor),
      ),
    );
  }

  Widget _buildFallbackCover(
    String title,
    String subtitle,
    Color baseColor,
    Color accentColor,
    double width,
    double height,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.6),
            baseColor,
            baseColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white70,
                      size: 12.0,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: baseColor == Colors.yellow ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: width > 130 ? 15.0 : 11.0,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: baseColor == Colors.yellow ? Colors.black54 : Colors.white54,
                        fontSize: width > 130 ? 9.5 : 8.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'TBT LIBRARY',
                  style: TextStyle(
                    color: baseColor == Colors.yellow ? Colors.black38 : Colors.white30,
                    fontSize: 7.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: 8.0,
              left: 8.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFFD30814),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    color: badgeTextColor ?? Colors.white,
                    fontSize: 8.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleReadBook(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReaderScreen(bookTitle: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'e-books',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22.0),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search is coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
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
              Color(0xFF1F0304), // Warm dark red/crimson gradient backdrop
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TBT CURATED COLLECTION',
                  style: TextStyle(
                    color: Color(0xFFD30814),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Zero Rupee\nMarketing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.0,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 20.0),

                Row(
                  children: [
                    _buildStatCol('24', 'BOOKS'),
                    _buildStatDivider(),
                    _buildStatCol('Free', 'ACCESS'),
                    _buildStatDivider(),
                    _buildStatCol('PDF+AUDIO', 'FORMATS'),
                  ],
                ),
                const SizedBox(height: 28.0),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _categories.map((c) => _buildCategoryTab(c)).toList(),
                  ),
                ),
                const SizedBox(height: 24.0),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8.0),
                          Center(
                            child: _buildBookCover(
                              title: 'Zero Rupee',
                              subtitle: 'MARKETING',
                              baseColor: const Color(0xFF1E293B),
                              accentColor: const Color(0xFF0F172A),
                              imagePath: 'assets/images/ebook covers/zero 1.png',
                              width: 140.0,
                              height: 210.0,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            children: const [
                              Icon(Icons.star_rounded, color: Color(0xFFD30814), size: 16.0),
                              SizedBox(width: 4.0),
                              Text(
                                '4.9 / 5.0',
                                style: TextStyle(
                                  color: Color(0xFFD30814),
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10.0),
                          const Text(
                            'Zero Rupee Marketing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10.0),
                          const Text(
                            'Notes on Startups, or How to Build the Future. Peter Thiel presents an optimistic view of the future of progress and a new way of thinking about innovation.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44.0,
                                  child: ElevatedButton(
                                    onPressed: () => _handleReadBook('Zero Rupee Marketing'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD30814),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'READ NOW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              SizedBox(
                                height: 44.0,
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSaved = !_isSaved;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_isSaved ? 'Saved to library!' : 'Removed from library!'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white.withOpacity(0.08)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    backgroundColor: _isSaved ? const Color(0xFFD30814).withOpacity(0.1) : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                        color: _isSaved ? const Color(0xFFD30814) : Colors.white60,
                                        size: 16.0,
                                      ),
                                      const SizedBox(width: 6.0),
                                      Text(
                                        'SAVE',
                                        style: TextStyle(
                                          color: _isSaved ? const Color(0xFFD30814) : Colors.white70,
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD30814).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: const Color(0xFFD30814),
                              width: 1.0,
                            ),
                          ),
                          child: const Text(
                            'MUST READ',
                            style: TextStyle(
                              color: Color(0xFFD30814),
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36.0),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Browse All Books',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          'WHAT THE TRIBE IS READING',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All library books is coming soon!')),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
                const SizedBox(height: 20.0),

                SizedBox(
                  height: 260.0,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      GestureDetector(
                        onTap: () => _handleReadBook('Guerrilla Marketing'),
                        child: Container(
                          width: 120.0,
                          margin: const EdgeInsets.only(right: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBookCover(
                                title: 'Guerrilla',
                                subtitle: 'MARKETING',
                                baseColor: Colors.yellow,
                                accentColor: Colors.amber,
                                imagePath: 'assets/images/ebook covers/gurilla 1.png',
                                badgeText: 'FREE',
                                badgeColor: const Color(0xFFD30814),
                                badgeTextColor: Colors.white,
                              ),
                              const SizedBox(height: 10.0),
                              const Text(
                                'Guerrilla Marketing',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                'SAKTHIVEL PANEERSELVAM',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _handleReadBook('Kassu'),
                        child: Container(
                          width: 120.0,
                          margin: const EdgeInsets.only(right: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBookCover(
                                title: 'Kassu',
                                subtitle: 'TBT EDITION',
                                baseColor: const Color(0xFF0F172A),
                                accentColor: const Color(0xFF1E293B),
                                imagePath: 'assets/images/ebook covers/kassu 1.png',
                                badgeText: 'POPULAR',
                                badgeColor: Colors.white,
                                badgeTextColor: Colors.black,
                              ),
                              const SizedBox(height: 10.0),
                              const Text(
                                'Kassu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                'SAKTHIVEL PANEERSELVAM',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String val, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white30,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24.0,
      width: 1.0,
      color: Colors.white.withOpacity(0.08),
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
    );
  }
}

class BookReaderScreen extends StatefulWidget {
  final String bookTitle;
  const BookReaderScreen({super.key, required this.bookTitle});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  bool _isLoading = true;
  int _currentPage = 0;
  final int _totalPages = 4;
  
  late ScrollController _scrollController;
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  
  // Height of each page container including margin/padding for scroll calculations
  final double _pageHeight = 524.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // Calculate current visible page index based on scroll offset divided by page height
    final double offset = _scrollController.offset;
    final int newPage = (offset / _pageHeight).round().clamp(0, _totalPages - 1);
    
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
    }
  }

  void _zoom(double factor) {
    setState(() {
      _currentScale = (_currentScale * factor).clamp(1.0, 3.0);
      _transformationController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  void _navigateToPage(int index) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      index * _pageHeight,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  String _getPdfFileName() {
    return '${widget.bookTitle.toLowerCase().replaceAll(' ', '_')}.pdf';
  }

  Future<String?> _saveFileToDownloads(String filename) async {
    try {
      final header = '%PDF-1.4\n';
      final obj1 = '1 0 obj\n<<\n  /Type /Catalog\n  /Pages 2 0 R\n>>\nendobj\n';
      final obj2 = '2 0 obj\n<<\n  /Type /Pages\n  /Kids [3 0 R]\n  /Count 1\n>>\nendobj\n';
      final text = 'BT\n/F1 18 Tf\n50 800 Td\n(Tamil Business Tribe E-Book) Tj\n0 -30 Td\n(Book Title: ${widget.bookTitle}) Tj\n0 -25 Td\n(Verified digital copy successfully downloaded.) Tj\nET';
      final textBytes = utf8.encode(text);
      final streamLen = textBytes.length;
      final obj3 = '3 0 obj\n<<\n  /Type /Page\n  /Parent 2 0 R\n  /Resources <<\n    /Font <<\n      /F1 <<\n        /Type /Font\n        /Subtype /Type1\n        /BaseFont /Helvetica\n      >>\n    >>\n  >>\n  /MediaBox [0 0 595 842]\n  /Contents 4 0 R\n>>\nendobj\n';
      final obj4Header = '4 0 obj\n<< /Length $streamLen >>\nstream\n';
      final obj4Footer = '\nendstream\nendobj\n';

      final List<int> bytesList = [];
      final List<int> offsets = [];

      void addString(String s) {
        bytesList.addAll(utf8.encode(s));
      }

      addString(header);
      offsets.add(bytesList.length);
      addString(obj1);
      offsets.add(bytesList.length);
      addString(obj2);
      offsets.add(bytesList.length);
      addString(obj3);
      offsets.add(bytesList.length);
      addString(obj4Header);
      bytesList.addAll(textBytes);
      addString(obj4Footer);

      final startXref = bytesList.length;
      addString('xref\n0 5\n0000000000 65535 f \n');
      for (final offset in offsets) {
        final offsetStr = offset.toString().padLeft(10, '0');
        addString('$offsetStr 00000 n \n');
      }

      addString('trailer\n<<\n  /Size 5\n  /Root 1 0 R\n>>\nstartxref\n$startXref\n%%EOF\n');
      final bytes = Uint8List.fromList(bytesList);

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select where to save the e-book:',
        fileName: filename,
        bytes: bytes,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        return outputFile;
      }
      return null;
    } catch (e) {
      debugPrint('Error saving download: $e');
      return null;
    }
  }

  void _startDownload(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0.0;
        String? savedPath;
        bool isWriting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
              if (progress >= 1.0) {
                timer.cancel();
                if (!isWriting) {
                  isWriting = true;
                  _saveFileToDownloads(_getPdfFileName()).then((path) {
                    savedPath = path;
                    Future.delayed(const Duration(seconds: 1), () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF27AE60),
                            duration: const Duration(seconds: 4),
                            content: Text(
                              savedPath != null
                                  ? 'Downloaded! Saved to: $savedPath'
                                  : '${_getPdfFileName()} successfully downloaded to your device!',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0),
                            ),
                          ),
                        );
                      }
                    });
                  });
                }
              } else {
                setDialogState(() {
                  progress += 0.1;
                  if (progress > 1.0) progress = 1.0;
                });
              }
            });

            return Dialog(
              backgroundColor: const Color(0xFF141416),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: progress >= 1.0 
                            ? const Color(0xFF27AE60).withOpacity(0.12)
                            : const Color(0xFFD30814).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        progress >= 1.0 ? Icons.check_rounded : Icons.downloading_rounded,
                        color: progress >= 1.0 ? const Color(0xFF27AE60) : const Color(0xFFD30814),
                        size: 32.0,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      progress >= 1.0 ? 'Saving File...' : 'Downloading E-Book...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      _getPdfFileName(),
                      style: const TextStyle(color: Colors.white38, fontSize: 12.0),
                    ),
                    const SizedBox(height: 20.0),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? const Color(0xFF27AE60) : const Color(0xFFD30814),
                      ),
                      minHeight: 4.0,
                    ),
                    const SizedBox(height: 10.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 12.0, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          progress >= 1.0 ? 'Writing...' : 'Loading...',
                          style: const TextStyle(color: Colors.white30, fontSize: 12.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPdfPage(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return _buildCoverPage();
      case 1:
        return _buildTableOfContents();
      case 2:
        return _buildContentPage1();
      case 3:
        return _buildContentPage2();
      default:
        return Container();
    }
  }

  String _getBookCoverAsset() {
    final title = widget.bookTitle.toLowerCase();
    if (title.contains('zero')) {
      return 'assets/images/ebook covers/zero 1.png';
    } else if (title.contains('gurilla') || title.contains('guerrilla')) {
      return 'assets/images/ebook covers/gurilla 1.png';
    } else if (title.contains('kassu')) {
      return 'assets/images/ebook covers/kassu 1.png';
    } else if (title.contains('medico')) {
      return 'assets/images/ebook covers/medicoprenure 1.png';
    }
    return 'assets/images/ebook covers/zero 1.png'; // default fallback
  }

  Widget _buildCoverPage() {
    return Container(
      color: Colors.white,
      child: Image.asset(
        _getBookCoverAsset(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 4.0,
                  width: 80.0,
                  color: const Color(0xFFD30814),
                ),
                Column(
                  children: [
                    Text(
                      widget.bookTitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 26.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    const Text(
                      'TBT EXCLUSIVE CURATED EDITION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.menu_book_rounded,
                  color: const Color(0xFFD30814).withOpacity(0.8),
                  size: 80.0,
                ),
                Column(
                  children: const [
                    Text(
                      'SAKTHIVEL PANEERSELVAM',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 6.0),
                    Text(
                      'TAMIL BUSINESS TRIBE PRESS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableOfContents() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TABLE OF CONTENTS',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 24.0),
          _buildTocItem('Chapter 1: The Zero-Budget Shift', 'Page 3'),
          _buildTocItem('Chapter 2: Viral Loop Mechanics', 'Page 8'),
          _buildTocItem('Chapter 3: Trust Currency & Authority', 'Page 14'),
          _buildTocItem('Chapter 4: TBT Scaling Framework', 'Page 22'),
          _buildTocItem('Chapter 5: Execution Playbook', 'Page 30'),
        ],
      ),
    );
  }

  Widget _buildTocItem(String title, String page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            page,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPage1() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHAPTER 1: THE ZERO-BUDGET SHIFT',
            style: TextStyle(
              color: Color(0xFFD30814),
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12.0),
          const Text(
            'Understanding Distribution Dynamics',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: Text(
              'Zero Rupee Marketing is not about having a zero-budget strategy; it is about building massive organic momentum through leveraging distribution networks, content strategies, and referral dynamics. Many startups fail because they confuse spending money with getting users.\n\nIn reality, the best growth channels are built, not bought. To build a highly effective, low-budget organic engine, you must understand the distribution mechanics. We live in an era where trust has become the primary currency. Customers don\'t buy because they saw an ad; they buy because they heard a recommendation. That is the core pillar of the Tamil Business Tribe model.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.85),
                fontSize: 13.0,
                height: 1.6,
                fontFamily: 'Georgia',
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('ZERO RUPEE MARKETING', style: TextStyle(color: Colors.grey, fontSize: 8.0)),
              Text('Page 3 of 42', style: TextStyle(color: Colors.grey, fontSize: 8.0, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentPage2() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHAPTER 1: THE ZERO-BUDGET SHIFT',
            style: TextStyle(
              color: Color(0xFFD30814),
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12.0),
          const Text(
            'The Advantage of Constraint',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: Text(
              'When you start with zero budget, your constraints become your ultimate superpower. They force you to be deeply empathetic, exceptionally creative, and laser-focused on actual customer value. Every rupee you don\'t spend on ads is a rupee you can invest in elevating your user experience.\n\nBy leveraging community structures and micro-influencer dynamics, businesses can achieve exponential scale without traditional customer acquisition cost (CAC) inflation. The tribe is the message.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.85),
                fontSize: 13.0,
                height: 1.6,
                fontFamily: 'Georgia',
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('ZERO RUPEE MARKETING', style: TextStyle(color: Colors.grey, fontSize: 8.0)),
              Text('Page 4 of 42', style: TextStyle(color: Colors.grey, fontSize: 8.0, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPageContainer(int index) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
        width: double.infinity,
        height: 500.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10.0,
              spreadRadius: 2.0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: _buildPdfPage(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.bookTitle,
              style: const TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2.0),
            Text(
              _getPdfFileName(),
              style: const TextStyle(color: Colors.white38, fontSize: 10.0),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 20.0),
            onPressed: () => _zoom(0.8),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20.0),
            onPressed: () => _zoom(1.25),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20.0),
            onPressed: () => _startDownload(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(
                    color: Color(0xFFD30814),
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    'Opening PDF Viewer...',
                    style: TextStyle(color: Colors.white54, fontSize: 13.0),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      maxScale: 3.0,
                      minScale: 1.0,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _totalPages,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          return _buildPdfPageContainer(index);
                        },
                      ),
                    ),
                  ),
                  Container(
                    color: const Color(0xFF141416),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.navigate_before_rounded, color: Colors.white70),
                          onPressed: _currentPage > 0
                              ? () => _navigateToPage(_currentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page ${_currentPage + 1} of $_totalPages',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigate_next_rounded, color: Colors.white70),
                          onPressed: _currentPage < _totalPages - 1
                              ? () => _navigateToPage(_currentPage + 1)
                              : null,
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

class EBooksLibraryScreen extends StatefulWidget {
  const EBooksLibraryScreen({super.key});

  @override
  State<EBooksLibraryScreen> createState() => _EBooksLibraryScreenState();
}

class _EBooksLibraryScreenState extends State<EBooksLibraryScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Fiction', 'Business', 'Tech'];

  @override
  void initState() {
    super.initState();
    _loadProfilePath();
  }

  Future<void> _loadProfilePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile_path.txt');
      if (await file.exists()) {
        final path = await file.readAsString();
        if (mounted && path.isNotEmpty && await File(path).exists()) {
          setState(() {
            ProfileScreen.profileImagePath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile path in library: $e');
    }
  }

  Widget _buildCategoryTab(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD30814) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedBook(String title, String author, Color baseColor, Color accentColor, {String? coverImagePath}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookReaderScreen(bookTitle: title),
          ),
        );
      },
      child: Container(
        width: 140.0,
        margin: const EdgeInsets.only(right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Realistic Cover
            Container(
              height: 200.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8.0,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: coverImagePath != null
                          ? Image.asset(
                              coverImagePath,
                              width: 140.0,
                              height: 200.0,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildFallbackFeaturedCover(title, baseColor, accentColor),
                            )
                          : _buildFallbackFeaturedCover(title, baseColor, accentColor),
                    ),
                    Positioned(
                      top: 8.0,
                      right: 8.0,
                      child: FutureBuilder<bool>(
                        future: SavedBooksManager.isBookSaved(title),
                        builder: (context, snapshot) {
                          final isSaved = snapshot.data ?? false;
                          return GestureDetector(
                            onTap: () async {
                              await SavedBooksManager.toggleSaveBook(title);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: isSaved ? const Color(0xFFFCA5A5) : Colors.white70,
                                size: 16.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackFeaturedCover(String title, Color baseColor, Color accentColor) {
    return Container(
      width: 140.0,
      height: 200.0,
      decoration: BoxDecoration(
        color: baseColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.6),
            baseColor,
            baseColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.bookmark_outline_rounded, color: Colors.white38, size: 16.0),
                ),
                Text(
                  title.toUpperCase(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontFamily: 'Georgia',
                  ),
                ),
                const Text(
                  'TBT PRESS',
                  style: TextStyle(color: Colors.white24, fontSize: 7.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryItem({
    required String title,
    required String author,
    required Color coverBaseColor,
    required Color coverAccentColor,
    String? coverImagePath,
    String? progressLabel,
    double? progressPercent,
    String? pagesLeftText,
    bool showResume = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookReaderScreen(bookTitle: title),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.03),
          ),
        ),
        child: Row(
          children: [
            // Miniature Book Cover
            Container(
              width: 50.0,
              height: 70.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4.0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: coverImagePath != null
                    ? Image.asset(
                        coverImagePath,
                        width: 50.0,
                        height: 70.0,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildFallbackLibraryCover(title, coverBaseColor, coverAccentColor),
                      )
                    : _buildFallbackLibraryCover(title, coverBaseColor, coverAccentColor),
              ),
            ),
            const SizedBox(width: 14.0),
            // Middle Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    author,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // Progress Row
                  if (progressLabel != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          progressLabel,
                          style: TextStyle(
                            color: progressLabel == 'FINISHED'
                                ? const Color(0xFFFCA5A5)
                                : progressLabel == 'NOT STARTED'
                                    ? Colors.white30
                                    : const Color(0xFFEF4444),
                            fontSize: 9.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (pagesLeftText != null)
                          Text(
                            pagesLeftText,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  if (progressPercent != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6.0),
                      width: double.infinity,
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progressPercent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: progressLabel == 'FINISHED'
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFD30814),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            // Right Side Action
            if (showResume)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCA5A5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: const Color(0xFFFCA5A5).withOpacity(0.3),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Resume',
                  style: TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (showResume) const SizedBox(width: 8.0),
            if (showResume)
              const Icon(Icons.more_vert_rounded, color: Colors.white30, size: 18.0),
            if (progressLabel == 'FINISHED')
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFFFCA5A5), size: 18.0),
            const SizedBox(width: 8.0),
            FutureBuilder<bool>(
              future: SavedBooksManager.isBookSaved(title),
              builder: (context, snapshot) {
                final isSaved = snapshot.data ?? false;
                return GestureDetector(
                  onTap: () async {
                    await SavedBooksManager.toggleSaveBook(title);
                    setState(() {});
                  },
                  child: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? const Color(0xFFFCA5A5) : Colors.white30,
                    size: 20.0,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackLibraryCover(String title, Color coverBaseColor, Color coverAccentColor) {
    return Container(
      width: 50.0,
      height: 70.0,
      decoration: BoxDecoration(
        color: coverBaseColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            coverAccentColor.withOpacity(0.5),
            coverBaseColor,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Center(
              child: Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 6.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSearching = false;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _featuredList = const [
    {
      'title': 'Zero Rupee Marketing',
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/zero 1.png',
      'base': Color(0xFF220304),
      'accent': Color(0xFF110101),
    },
    {
      'title': 'Medicopreneur',
      'author': 'TBT Expert',
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
      'base': Color(0xFF1E293B),
      'accent': Color(0xFF0F172A),
    },
  ];

  final List<Map<String, dynamic>> _libraryList = const [
    {
      'title': 'Zero Rupee Marketing',
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/zero 1.png',
      'base': Color(0xFF3B0707),
      'accent': Color(0xFF180202),
      'label': '64% READ',
      'percent': 0.64,
      'pagesText': '54 pages left',
      'showResume': false,
    },
    {
      'title': 'Guerrilla Marketing',
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
      'base': Color(0xFF111827),
      'accent': Color(0xFF030712),
      'label': '40% READ',
      'percent': 0.40,
      'pagesText': '88 pages left',
      'showResume': true,
    },
    {
      'title': 'Kassu',
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/kassu 1.png',
      'base': Color(0xFF0F172A),
      'accent': Color(0xFF020617),
      'label': 'FINISHED',
      'percent': 1.0,
      'pagesText': 'Completed',
      'showResume': false,
    },
    {
      'title': 'Medicopreneur',
      'author': 'TBT Expert',
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
      'base': Color(0xFF065F46),
      'accent': Color(0xFF022C22),
      'label': '12% READ',
      'percent': 0.12,
      'pagesText': '176 pages left',
      'showResume': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Filter lists based on search query
    final filteredFeatured = _featuredList
        .where((book) => book['title']!.toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final filteredLibrary = _libraryList
        .where((book) => book['title']!.toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  cursorColor: const Color(0xFFD30814),
                  decoration: const InputDecoration(
                    hintText: 'Search books...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13.0),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              )
            : const Text(
                'e-books',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
        centerTitle: true,
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22.0),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22.0),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 22.0),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SavedBooksScreen()),
                    ).then((_) {
                      setState(() {});
                    });
                  },
                ),
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    ).then((_) {
                      setState(() {});
                    });
                  },
                  child: Center(
                    child: Container(
                      width: 28.0,
                      height: 28.0,
                      margin: const EdgeInsets.only(right: 16.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
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
                          : const Icon(Icons.person_rounded, color: Colors.white70, size: 16.0),
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
              Color(0xFF1E0304),
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filteredFeatured.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Featured Arrivals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AllBooksCatalogScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'VIEW ALL',
                          style: TextStyle(
                            color: Color(0xFFD30814),
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    height: 256.0,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredFeatured.length,
                      itemBuilder: (context, index) {
                        final book = filteredFeatured[index];
                        return _buildFeaturedBook(
                          book['title']!,
                          book['author']!,
                          book['base']!,
                          book['accent']!,
                          coverImagePath: book['cover']!,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _categories.map((c) => _buildCategoryTab(c)).toList(),
                  ),
                ),
                const SizedBox(height: 24.0),

                Row(
                  children: [
                    Text(
                      _searchQuery.isNotEmpty ? 'Search Results' : 'Your Library',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${filteredLibrary.length} Books',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),

                if (filteredLibrary.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text(
                        'No books found matching search.',
                        style: TextStyle(color: Colors.white38, fontSize: 13.0),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredLibrary.length,
                    itemBuilder: (context, index) {
                      final book = filteredLibrary[index];
                      return _buildLibraryItem(
                        title: book['title']!,
                        author: book['author']!,
                        coverBaseColor: book['base']!,
                        coverAccentColor: book['accent']!,
                        coverImagePath: book['cover']!,
                        progressLabel: book['label'],
                        progressPercent: book['percent'],
                        pagesLeftText: book['pagesText'],
                        showResume: book['showResume'] ?? false,
                      );
                    },
                  ),
                const SizedBox(height: 28.0),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1917),
                    borderRadius: BorderRadius.circular(16.0),
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1507842217343-583bb7270b66?q=80&w=600'),
                      fit: BoxFit.cover,
                      opacity: 0.15,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0),
                      gradient: LinearGradient(
                        begin: Alignment.bottomRight,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Discover your\nNext Obsession',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.0,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        const Text(
                          'Explore our curated collection of over 50,000 titles across every genre imaginable.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12.0,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        SizedBox(
                          height: 40.0,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AllBooksCatalogScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFCA5A5).withOpacity(0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              elevation: 0.0,
                            ),
                            child: const Text(
                              'VIEW ALL',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AllBooksCatalogScreen extends StatefulWidget {
  const AllBooksCatalogScreen({super.key});

  @override
  State<AllBooksCatalogScreen> createState() => _AllBooksCatalogScreenState();
}

class _AllBooksCatalogScreenState extends State<AllBooksCatalogScreen> {
  bool _isSearching = false;
  String _searchQuery = '';

  final List<Map<String, String>> _catalog = const [
    {
      'title': 'Zero Rupee Marketing',
      'cover': 'assets/images/ebook covers/zero 1.png',
    },
    {
      'title': 'Guerrilla Marketing',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
    },
    {
      'title': 'Kassu',
      'cover': 'assets/images/ebook covers/kassu 1.png',
    },
    {
      'title': 'Medicopreneur',
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
    },
    {
      'title': 'Zero Budget Scaling',
      'cover': 'assets/images/ebook covers/zero 1.png',
    },
    {
      'title': 'Guerrilla Brand Secret',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
    },
    {
      'title': 'TBT Kassu Tactics',
      'cover': 'assets/images/ebook covers/kassu 1.png',
    },
    {
      'title': 'Medicopreneur Scale',
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
    },
    {
      'title': 'Distribution Power',
      'cover': 'assets/images/ebook covers/zero 1.png',
    },
    {
      'title': 'Organic Growth Funnel',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
    },
    {
      'title': 'Money Magnet Mindset',
      'cover': 'assets/images/ebook covers/kassu 1.png',
    },
    {
      'title': 'Doctor Business Hub',
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
    },
    {
      'title': 'Start From Zero Rupee',
      'cover': 'assets/images/ebook covers/zero 1.png',
    },
    {
      'title': 'Viral Marketing Tricks',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
    },
    {
      'title': 'Psychology of Cash',
      'cover': 'assets/images/ebook covers/kassu 1.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredCatalog = _catalog
        .where((book) => book['title']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  cursorColor: const Color(0xFFD30814),
                  decoration: const InputDecoration(
                    hintText: 'Search catalog...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13.0),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              )
            : const Text(
                'Book Catalog',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
        centerTitle: true,
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22.0),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22.0),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
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
              Color(0xFF1E0304),
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: filteredCatalog.isEmpty
              ? const Center(
                  child: Text(
                    'No books found in catalog.',
                    style: TextStyle(color: Colors.white30, fontSize: 14.0),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredCatalog.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.56,
                  ),
                  itemBuilder: (context, index) {
                    final book = filteredCatalog[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookReaderScreen(bookTitle: book['title']!),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6.0,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.asset(
                                        book['cover']!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: const Color(0xFF1C1C1E),
                                            child: const Icon(Icons.book_rounded, color: Colors.white30),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 4.0,
                                      right: 4.0,
                                      child: FutureBuilder<bool>(
                                        future: SavedBooksManager.isBookSaved(book['title']!),
                                        builder: (context, snapshot) {
                                          final isSaved = snapshot.data ?? false;
                                          return GestureDetector(
                                            onTap: () async {
                                              await SavedBooksManager.toggleSaveBook(book['title']!);
                                              setState(() {});
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4.0),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                                color: isSaved ? const Color(0xFFFCA5A5) : Colors.white,
                                                size: 14.0,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            book['title']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class SavedBooksScreen extends StatefulWidget {
  const SavedBooksScreen({super.key});

  @override
  State<SavedBooksScreen> createState() => _SavedBooksScreenState();
}

class _SavedBooksScreenState extends State<SavedBooksScreen> {
  final Map<String, Map<String, dynamic>> _bookMetadata = const {
    'Zero Rupee Marketing': {
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/zero 1.png',
      'base': Color(0xFF3B0707),
      'accent': Color(0xFF180202),
      'label': '64% READ',
      'percent': 0.64,
      'pagesText': '54 pages left',
    },
    'Guerrilla Marketing': {
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/gurilla 1.png',
      'base': Color(0xFF111827),
      'accent': Color(0xFF030712),
      'label': '40% READ',
      'percent': 0.40,
      'pagesText': '88 pages left',
    },
    'Kassu': {
      'author': 'Sakthivel Paneerselvam',
      'cover': 'assets/images/ebook covers/kassu 1.png',
      'base': Color(0xFF0F172A),
      'accent': Color(0xFF020617),
      'label': 'FINISHED',
      'percent': 1.0,
      'pagesText': 'Completed',
    },
    'Medicopreneur': {
      'author': 'TBT Expert',
      'cover': 'assets/images/ebook covers/medicoprenure 1.png',
      'base': Color(0xFF065F46),
      'accent': Color(0xFF022C22),
      'label': '12% READ',
      'percent': 0.12,
      'pagesText': '176 pages left',
    },
  };

  String _getCoverForBook(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('zero')) return 'assets/images/ebook covers/zero 1.png';
    if (lower.contains('gurilla') || lower.contains('guerrilla')) return 'assets/images/ebook covers/gurilla 1.png';
    if (lower.contains('kassu') || lower.contains('money') || lower.contains('cash')) return 'assets/images/ebook covers/kassu 1.png';
    return 'assets/images/ebook covers/medicoprenure 1.png';
  }

  Widget _buildSavedLibraryItem(String title) {
    final meta = _bookMetadata[title];
    final author = meta?['author'] ?? 'Tamil Business Tribe';
    final cover = meta?['cover'] ?? _getCoverForBook(title);
    final baseColor = meta?['base'] ?? const Color(0xFF1C1C1E);
    final progressLabel = meta?['label'];
    final progressPercent = meta?['percent'];
    final pagesLeftText = meta?['pagesText'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.03),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookReaderScreen(bookTitle: title),
                ),
              ).then((_) {
                setState(() {});
              });
            },
            child: Container(
              width: 50.0,
              height: 70.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4.0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: Image.asset(
                  cover,
                  width: 50.0,
                  height: 70.0,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: baseColor,
                    child: const Icon(Icons.book_rounded, color: Colors.white30),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookReaderScreen(bookTitle: title),
                  ),
                ).then((_) {
                  setState(() {});
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    author,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  if (progressLabel != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          progressLabel,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 9.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (pagesLeftText != null)
                          Text(
                            pagesLeftText,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  if (progressPercent != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6.0),
                      width: double.infinity,
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progressPercent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD30814),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          IconButton(
            icon: const Icon(Icons.bookmark_rounded, color: Color(0xFFFCA5A5), size: 22.0),
            onPressed: () async {
              await SavedBooksManager.toggleSaveBook(title);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Books',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
              Color(0xFF1E0304),
              Color(0xFF0A0A0A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<String>>(
            future: SavedBooksManager.getSavedBooks(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD30814),
                  ),
                );
              }
              final saved = snapshot.data!;
              if (saved.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        color: Colors.white.withOpacity(0.15),
                        size: 64.0,
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'No Saved Books yet',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      const Text(
                        'Tap the bookmark icon on any book to save it here.',
                        style: TextStyle(color: Colors.white30, fontSize: 12.0),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                physics: const BouncingScrollPhysics(),
                itemCount: saved.length,
                itemBuilder: (context, index) {
                  return _buildSavedLibraryItem(saved[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
