import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr/qr.dart';
import 'main.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static String? profileImagePath;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _notificationsEnabled = true;
  bool _profileVisibility = true;
  bool _isCardFlipped = false;
  double _cardTiltX = 0.0;
  double _cardTiltY = 0.0;

  // Profile data
  String _userName = 'Thrisha';
  String _userRole = 'Co-Founder, Creative Studios';
  String _userLocation = 'Chennai, Tamil Nadu';
  String _companyName = 'Creative Studios';
  String _companyIndustry = 'Design & Digital Marketing';
  String _companySize = '12 Members';



  Future<String?> _loadProfilePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile_path.txt');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Error loading profile path: $e');
    }
    return null;
  }

  Future<void> _initProfileImage() async {
    if (ProfileScreen.profileImagePath == null) {
      final savedPath = await _loadProfilePath();
      if (savedPath != null && await File(savedPath).exists()) {
        setState(() {
          ProfileScreen.profileImagePath = savedPath;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initProfileImage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareProfile() {
    Share.share('Check out Thrisha\'s profile on Tamil Business Tribe: TBT Elite Member ID: TBT-ELITE-4820');
  }

  void _showEditProfileSheet() {
    final nameController = TextEditingController(text: _userName);
    final roleController = TextEditingController(text: _userRole);
    final locationController = TextEditingController(text: _userLocation);
    final companyController = TextEditingController(text: _companyName);
    final industryController = TextEditingController(text: _companyIndustry);
    final sizeController = TextEditingController(text: _companySize);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F11),
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                const Text(
                  'Edit Business Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20.0),
                _buildTextField('Full Name', nameController),
                const SizedBox(height: 16.0),
                _buildTextField('Role / Designation', roleController),
                const SizedBox(height: 16.0),
                _buildTextField('Location', locationController),
                const SizedBox(height: 16.0),
                _buildTextField('Company Name', companyController),
                const SizedBox(height: 16.0),
                _buildTextField('Industry', industryController),
                const SizedBox(height: 16.0),
                _buildTextField('Team Size', sizeController),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _userName = nameController.text.trim();
                      _userRole = roleController.text.trim();
                      _userLocation = locationController.text.trim();
                      _companyName = companyController.text.trim();
                      _companyIndustry = industryController.text.trim();
                      _companySize = sizeController.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully! 🎉'),
                        backgroundColor: Color(0xFF27AE60),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD30814),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8.0),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1C1C1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFF2C2C2E), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFD30814), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 84.0,
      height: 84.0,
      color: const Color(0xFF48484A),
      child: const Icon(
        Icons.person,
        color: Colors.white70,
        size: 40.0,
      ),
    );
  }

  void _showProfileAvatarOptions(BuildContext context) {
    showProfileAvatarOptionsSheet(
      context: context,
      onPhotoChanged: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.0),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Elite Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20.0),
                      onPressed: _shareProfile,
                    ),
                  ],
                ),
              ),

              // Profile Content Scroll View
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16.0),
                          _buildProfileHero(),
                          const SizedBox(height: 24.0),
                          _buildStatsRow(),
                          const SizedBox(height: 28.0),
                          _buildMembershipCardGesture(),
                          const SizedBox(height: 28.0),
                          _buildTabBarSection(),
                          const SizedBox(height: 16.0),
                          _buildTabContentSection(),
                          const SizedBox(height: 28.0),
                          _buildSettingsSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header / Profile details component
  Widget _buildProfileHero() {
    return Column(
      children: [
        // Avatar with Glowing indicator
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96.0,
              height: 96.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFD30814),
                    Color(0xFFFF5E62),
                    Color(0xFFFFD97D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD30814).withOpacity(0.4),
                    blurRadius: 16.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
            ),
            Container(
              width: 90.0,
              height: 90.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F0F11),
              ),
            ),
            GestureDetector(
              onTap: () => _showProfileAvatarOptions(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44.0),
                child: ProfileScreen.profileImagePath != null
                    ? Image.file(
                        File(ProfileScreen.profileImagePath!),
                        width: 84.0,
                        height: 84.0,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                      )
                    : Image.network(
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop&crop=face',
                        width: 84.0,
                        height: 84.0,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                      ),
              ),
            ),
            Positioned(
              bottom: 2.0,
              right: 2.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: const Color(0xFF0F0F11), width: 1.5),
                ),
                child: const Text(
                  'ONLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Text(
          _userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6.0),
        Text(
          _userRole,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_rounded, color: Color(0xFFD30814), size: 14.0),
            const SizedBox(width: 4.0),
            Text(
              _userLocation,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        // Badge row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeroBadge('10X Growth Club', const Color(0xFFD30814)),
            const SizedBox(width: 8.0),
            _buildHeroBadge('Pillar of Sakthi', const Color(0xFFD4AF37)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: color.withOpacity(0.35), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, color: color, size: 14.0),
          const SizedBox(width: 6.0),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Stats Counters
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFF232326), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('12 Days', 'Daily Streak', Icons.whatshot_rounded, const Color(0xFFFF5E3A)),
          _buildVerticalDivider(),
          _buildStatItem('142', 'Connections', Icons.people_alt_rounded, const Color(0xFF2F80ED)),
          _buildVerticalDivider(),
          _buildStatItem('2,450', 'TBT Points', Icons.stars_rounded, const Color(0xFFFFD97D)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16.0),
            const SizedBox(width: 4.0),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 32.0,
      width: 1.0,
      color: const Color(0xFF2C2C2E),
    );
  }

  // Tiltable Double-Sided Membership Card Gesture Listener
  Widget _buildMembershipCardGesture() {
    return GestureDetector(
      onPanUpdate: (details) {
        // Calculate tilt values based on drag offset relative to card size
        setState(() {
          _cardTiltY += details.delta.dx * 0.003;
          _cardTiltX -= details.delta.dy * 0.003;

          // Clamp angles to prevent full rotation on simple drags
          _cardTiltX = _cardTiltX.clamp(-0.4, 0.4);
          _cardTiltY = _cardTiltY.clamp(-0.4, 0.4);
        });
      },
      onPanEnd: (_) {
        // Reset tilt back smoothly
        setState(() {
          _cardTiltX = 0.0;
          _cardTiltY = 0.0;
        });
      },
      onTap: () {
        setState(() {
          _isCardFlipped = !_isCardFlipped;
        });
      },
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(_cardTiltX)
          ..rotateY(_cardTiltY + (_isCardFlipped ? 3.14159 : 0.0)),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            // Smoothly rotate the switching card faces
            final rotate = Tween(begin: 3.14159, end: 0.0).animate(animation);
            return AnimatedBuilder(
              animation: rotate,
              builder: (context, widget) {
                final isFront = child.key == const ValueKey('card_front');
                var tilt = rotate.value;
                if (!isFront) tilt = tilt - 3.14159;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(tilt),
                  alignment: Alignment.center,
                  child: child,
                );
              },
            );
          },
          child: _isCardFlipped ? _buildCardBack() : _buildCardFront(),
        ),
      ),
    );
  }

  // Premium Virtual Membership Card Front
  Widget _buildCardFront() {
    return Container(
      key: const ValueKey('card_front'),
      height: 220.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F24),
            Color(0xFF0F0F12),
            Color(0xFF050507),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD4AF).withOpacity(0.04),
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30.0,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Elegant glow layer
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD30814).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Metallic Accent lines
          Positioned(
            left: 24,
            top: 24,
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFFFFD700), size: 24.0),
                const SizedBox(width: 8.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'TAMIL BUSINESS TRIBE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'ELITE NETWORK CARD',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1.0),
                color: const Color(0xFFFFD700).withOpacity(0.05),
              ),
              child: const Text(
                'ELITE',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  _companyName,
                  style: const TextStyle(
                    color: Color(0xFFD1D1D6),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: Row(
              children: [
                _buildCardFooterDetail('MEMBER ID', 'TBT-ELITE-4820'),
                const SizedBox(width: 32.0),
                _buildCardFooterDetail('EXPIRES', '06/2027'),
              ],
            ),
          ),
          // Tap hint
          Positioned(
            right: 24,
            bottom: 24,
            child: Row(
              children: const [
                Icon(Icons.flip_camera_android_rounded, color: Color(0xFFFFD700), size: 14.0),
                SizedBox(width: 4.0),
                Text(
                  'TAP TO FLIP',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 40,
            top: 75,
            child: Container(
              width: 57.0,
              height: 57.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(
                  child: ProfileScreen.profileImagePath != null
                      ? Image.file(
                          File(ProfileScreen.profileImagePath!),
                          width: 54.0,
                          height: 54.0,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                          width: 54.0,
                          height: 54.0,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 54.0,
                            height: 54.0,
                            color: const Color(0xFF2C2C2E),
                            child: const Icon(Icons.person, color: Colors.white70, size: 24.0),
                          ),
                        ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Premium Virtual Membership Card Back (QR Code / Verify)
  Widget _buildCardBack() {
    return Container(
      key: const ValueKey('card_back'),
      height: 220.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F0F12),
            Color(0xFF1A1A22),
            Color(0xFF0A0A0E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30.0,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom mock QR Code inside a premium grid border
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        blurRadius: 15.0,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    size: const Size(90, 90),
                    painter: QRPainter('TBT Member: $_userName\nID: TBT-ELITE-4820\nCompany: $_companyName'),
                  ),
                ),
                const SizedBox(height: 12.0),
                const Text(
                  'SCAN TO VERIFY MEMBERSHIP',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            child: Transform(
              transform: Matrix4.identity()..scale(-1.0, 1.0),
              alignment: Alignment.center,
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF27AE60), size: 20.0),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Row(
              children: const [
                Icon(Icons.flip_camera_android_rounded, color: Colors.white60, size: 14.0),
                SizedBox(width: 4.0),
                Text(
                  'TAP TO FLIP',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardFooterDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 8.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Dynamic Tabs section
  Widget _buildTabBarSection() {
    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF232326), width: 1.0),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFD30814),
          borderRadius: BorderRadius.circular(12.0),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8E8E93),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
        tabs: const [
          Tab(text: 'Business'),
          Tab(text: 'My Wins'),
          Tab(text: 'Trophies'),
        ],
      ),
    );
  }

  // Fixed container to fit tab contents
  Widget _buildTabContentSection() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        switch (_tabController.index) {
          case 0:
            return _buildBusinessTab();
          case 1:
            return _buildWinsTab();
          case 2:
          default:
            return _buildTrophyTab();
        }
      },
    );
  }

  // Tab 1: Business Profile View
  Widget _buildBusinessTab() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFF232326), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Company Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _showEditProfileSheet,
                child: Row(
                  children: const [
                    Icon(Icons.edit_note_rounded, color: Color(0xFFD30814), size: 18.0),
                    SizedBox(width: 4.0),
                    Text(
                      'EDIT',
                      style: TextStyle(
                        color: Color(0xFFD30814),
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildBusinessRow('Company Name', _companyName, Icons.business_rounded),
          _buildBusinessRow('Industry', _companyIndustry, Icons.category_rounded),
          _buildBusinessRow('Team Size', _companySize, Icons.people_rounded),
          _buildBusinessRow('Registered Office', 'Adyar, Chennai', Icons.location_on_rounded),
          const SizedBox(height: 8.0),
          const Divider(color: Color(0xFF232326), height: 24.0),
          const Text(
            'Target Network',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10.0),
          const Text(
            'Looking to connect with SaaS founders, agency owners, and digital content creators in Tamil Nadu to collaborate on creative branding projects.',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13.0,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(icon, color: Colors.white70, size: 16.0),
          ),
          const SizedBox(width: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab 2: User Wins Timeline
  Widget _buildWinsTab() {
    final List<Map<String, String>> mockWins = [
      {
        'title': 'Hit 15 Active Retainer Clients! 🎯',
        'desc': 'Excited to announce that Creative Studios has closed 4 new retainers this week! Kudos to the design team.',
        'time': '2 days ago',
        'likes': '34',
      },
      {
        'title': 'Morning Ritual 12-day Consistency Streak 🔥',
        'desc': 'Woke up at 5:00 AM, wrote morning pages, meditated, exercised, and planned day. Consistency pays off.',
        'time': '1 week ago',
        'likes': '58',
      },
      {
        'title': 'Presented at Chennai TBT Meetup 🎤',
        'desc': 'Shared insights on visual branding & copywriting strategies for local businesses. Incredible networking energy!',
        'time': '2 weeks ago',
        'likes': '82',
      },
    ];

    return Column(
      children: mockWins.map((win) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFF232326), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      win['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    win['time']!,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 11.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                win['desc']!,
                style: const TextStyle(
                  color: Color(0xFFD1D1D6),
                  fontSize: 13.0,
                  height: 1.35,
                ),
              ),
              const Divider(color: Color(0xFF232326), height: 24.0),
              Row(
                children: [
                  const Icon(Icons.thumb_up_alt_rounded, color: Color(0xFFD30814), size: 14.0),
                  const SizedBox(width: 6.0),
                  Text(
                    '${win['likes']} support reactions',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // Tab 3: Trophy Grid Section
  Widget _buildTrophyTab() {
    final List<Map<String, dynamic>> trophies = [
      {'name': 'Elite Networker', 'icon': Icons.connect_without_contact_rounded, 'color': const Color(0xFF2F80ED), 'desc': 'Connected with over 100 TBT business owners.'},
      {'name': 'Habit Maker', 'icon': Icons.whatshot_rounded, 'color': const Color(0xFFFF5E3A), 'desc': 'Maintained a 10-day Morning Ritual completion streak.'},
      {'name': 'Stage Sharer', 'icon': Icons.campaign_rounded, 'color': const Color(0xFF27AE60), 'desc': 'Spoke as a presenter or helper in a TBT virtual/local meetup.'},
      {'name': 'Rising Star', 'icon': Icons.trending_up_rounded, 'color': const Color(0xFFFFD97D), 'desc': 'Achieved 5X or higher business growth certified by mentoring.'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 12.0,
        childAspectRatio: 1.1,
      ),
      itemCount: trophies.length,
      itemBuilder: (context, index) {
        final trophy = trophies[index];
        return InkWell(
          onTap: () {
            _showTrophyDialog(trophy['name'], trophy['desc'], trophy['icon'], trophy['color']);
          },
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: trophy['color'].withOpacity(0.2), width: 1.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: trophy['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(trophy['icon'], color: trophy['color'], size: 26.0),
                ),
                const SizedBox(height: 12.0),
                Text(
                  trophy['name'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'Tap details',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 10.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTrophyDialog(String name, String desc, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Dialog(
            backgroundColor: const Color(0xFF0F0F11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(icon, color: color, size: 48.0),
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: const BorderSide(color: Color(0xFF2C2C2E)),
                      ),
                    ),
                    child: const Text('Great!'),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // General settings layout
  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFF232326), width: 1.0),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined, color: Color(0xFFD30814), size: 20.0),
            title: const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            subtitle: const Text('Get alerts for wins, updates & comments', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11.5)),
            value: _notificationsEnabled,
            activeColor: const Color(0xFFD30814),
            onChanged: (val) {
              setState(() {
                _notificationsEnabled = val;
              });
            },
          ),
          const Divider(color: Color(0xFF232326), height: 1.0, indent: 16.0, endIndent: 16.0),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined, color: Color(0xFFD30814), size: 20.0),
            title: const Text('Public Visibility', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            subtitle: const Text('Allow non-connections to view portfolio', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11.5)),
            value: _profileVisibility,
            activeColor: const Color(0xFFD30814),
            onChanged: (val) {
              setState(() {
                _profileVisibility = val;
              });
            },
          ),
          const Divider(color: Color(0xFF232326), height: 1.0, indent: 16.0, endIndent: 16.0),
          ListTile(
            leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFD30814), size: 20.0),
            title: const Text('My Account', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14.0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsDetailScreen(
                    title: 'My Account',
                    content: _buildAccountDetailContent(),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF232326), height: 1.0, indent: 16.0, endIndent: 16.0),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded, color: Color(0xFFD30814), size: 20.0),
            title: const Text('Support', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14.0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupportCenterScreen(),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF232326), height: 1.0, indent: 16.0, endIndent: 16.0),
          ListTile(
            leading: const Icon(Icons.gavel_rounded, color: Color(0xFFD30814), size: 20.0),
            title: const Text('Terms & Conditions', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14.0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsDetailScreen(
                    title: 'Terms & Conditions',
                    content: _buildTermsContent(),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF232326), height: 1.0, indent: 16.0, endIndent: 16.0),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFD30814), size: 20.0),
            title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14.0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsDetailScreen(
                    title: 'Privacy Policy',
                    content: _buildPrivacyContent(),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF232326), height: 1.0, indent: 16.0, endIndent: 16.0),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFD30814), size: 20.0),
            title: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14.0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogoutConfirmationScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 40.0),
              ),
              const SizedBox(height: 12.0),
              const Text(
                'Elite Lifetime Member',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4.0),
              const Text(
                'Member ID: TBT-ELITE-4820',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32.0),
        _buildInfoTile('Full Name', _userName, Icons.person_outline_rounded),
        _buildInfoTile('Email Address', 'thrisha@studios.com', Icons.mail_outline_rounded),
        _buildInfoTile('Phone Number', '+91 98765 43210', Icons.phone_android_rounded),
        _buildInfoTile('Designation', _userRole, Icons.badge_outlined),
        _buildInfoTile('Company', _companyName, Icons.business_outlined),
        _buildInfoTile('Account Status', 'Active', Icons.verified_user_outlined, statusColor: const Color(0xFF27AE60)),
        const SizedBox(height: 32.0),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditProfileSheet();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD30814), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            child: const Text(
              'Edit Account Details',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {Color? statusColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF232326), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8E8E93), size: 20.0),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  value,
                  style: TextStyle(
                    color: statusColor ?? Colors.white,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terms & Conditions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6.0),
        const Text(
          'Last updated: June 2026',
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.0),
        ),
        const SizedBox(height: 20.0),
        _buildPolicySection('1. Acceptance of Terms', 'By accessing or using the Tamil Business Tribe app, you agree to comply with and be bound by these Terms and Conditions. If you do not agree, please do not use our services.'),
        _buildPolicySection('2. Member Account & Security', 'You are responsible for keeping your credentials confidential. Any activity taking place on your registered profile is your exclusive liability. Please inform support immediately of any unauthorized access.'),
        _buildPolicySection('3. Community Guidelines', 'The Tamil Business Tribe thrives on cooperation, respect, and mutual business growth. Members must not post spam, offensive content, or violate the privacy of other members. Infringing items will be removed without notice.'),
        _buildPolicySection('4. Premium Services & Fees', 'Elite memberships, ticket bookings, and special mentor workshops are subject to payments. All fees are non-refundable except as explicitly specified in our cancellation terms.'),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6.0),
        const Text(
          'Last updated: June 2026',
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12.0),
        ),
        const SizedBox(height: 20.0),
        _buildPolicySection('1. Information We Collect', 'We collect business information, company metadata, profile photo references, and contact details during elite registration to facilitate community interactions and networking metrics.'),
        _buildPolicySection('2. How We Use Data', 'Your information is utilized to maintain your virtual membership card, custom badge rewards, and timeline statistics. We do not sell or leak member records to third-party databases.'),
        _buildPolicySection('3. Storage & Security', 'We employ secure encryption standards to store credentials and transaction data. Only approved TBT mentors have access to metrics for accountability and task evaluation.'),
        _buildPolicySection('4. Your Privacy Rights', 'You can restrict details shown to public members by enabling "Public Visibility" in settings, or request account deletions by emailing support.'),
      ],
    );
  }

  Widget _buildPolicySection(String heading, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13.0,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsDetailScreen extends StatelessWidget {
  final String title;
  final Widget content;

  const ProfileSettingsDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.0),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48.0),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoutConfirmationScreen extends StatefulWidget {
  const LogoutConfirmationScreen({super.key});

  @override
  State<LogoutConfirmationScreen> createState() => _LogoutConfirmationScreenState();
}

class _LogoutConfirmationScreenState extends State<LogoutConfirmationScreen> {
  bool _isLoggingOut = false;
  bool _isLoggedOut = false;

  void _triggerLogout() {
    setState(() {
      _isLoggingOut = true;
    });

    SessionManager.setLoggedIn(false).then((_) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            _isLoggingOut = false;
            _isLoggedOut = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _isLoggingOut
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(
                          color: Color(0xFFD30814),
                        ),
                        SizedBox(height: 24.0),
                        Text(
                          'Logging out safely...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          'Saving your local statistics and wins',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13.0,
                          ),
                        ),
                      ],
                    )
                  : _isLoggedOut
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Color(0xFF27AE60),
                                size: 60.0,
                              ),
                            ),
                            const SizedBox(height: 24.0),
                            const Text(
                              'Successfully Logged Out',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              'You have been logged out of Tamil Business Tribe.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 14.0,
                              ),
                            ),
                            const SizedBox(height: 32.0),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD30814),
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.0),
                                  ),
                                ),
                                child: const Text(
                                  'Login Again',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD30814).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFD30814),
                                size: 50.0,
                              ),
                            ),
                            const SizedBox(height: 24.0),
                            const Text(
                              'Confirm Logout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              'Are you sure you want to log out of your elite member profile?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 14.0,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 36.0),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF2C2C2E)),
                                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16.0),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _triggerLogout,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD30814),
                                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'Log Out',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class RaiseTicketScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onTicketCreated;

  const RaiseTicketScreen({super.key, required this.onTicketCreated});

  @override
  State<RaiseTicketScreen> createState() => _RaiseTicketScreenState();
}

class _RaiseTicketScreenState extends State<RaiseTicketScreen> {
  int _currentStep = 1; // 1: Issue Details, 2: Attachments, 3: Review

  // Form states
  String? _selectedCategory;
  final TextEditingController _subjectController = TextEditingController();
  String _priority = 'Medium'; // Low, Medium, High
  final TextEditingController _descriptionController = TextEditingController();

  List<String> _attachments = [];

  bool _isSubmitted = false;
  String _submittedTicketId = '';
  String _selectedContactMethod = 'WHATSAPP'; // EMAIL, WHATSAPP

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_selectedCategory == null ||
          _subjectController.text.trim().isEmpty ||
          _descriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all the details to proceed!'),
            backgroundColor: Color(0xFFCC0000),
          ),
        );
        return;
      }
      setState(() {
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      setState(() {
        _currentStep = 3;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _submitTicket() {
    final ticketId = '#TBT-${2000 + (DateTime.now().millisecond % 1000)}';
    final ticketTitle = _subjectController.text.trim();
    final newTicket = {
      'id': ticketId,
      'title': ticketTitle.isNotEmpty ? ticketTitle : 'New Support Request',
      'fullTitle': ticketTitle.isNotEmpty ? ticketTitle : 'New Support Request',
      'category': _selectedCategory != null ? _selectedCategory!.toUpperCase() : 'GENERAL',
      'status': 'OPEN',
      'statusColor': const Color(0xFF2F80ED),
      'updatedText': 'Updated Just Now',
      'agentName': 'Agent',
      'agentAvatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop&crop=face',
      'messages': [
        {
          'sender': 'user',
          'senderName': 'Alexander',
          'text': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : 'No description provided.',
          'time': 'SENT - Just Now',
        }
      ],
    };
    widget.onTicketCreated(newTicket);
    setState(() {
      _submittedTicketId = ticketId;
      _isSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildSuccessScreen();
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom header matching support center style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFFD30814), size: 24.0),
                      onPressed: _previousStep,
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'Raise a Ticket',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.0),
                        child: ProfileScreen.profileImagePath != null
                            ? Image.file(
                                File(ProfileScreen.profileImagePath!),
                                width: 36.0,
                                height: 36.0,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100&h=100&fit=crop&crop=face',
                                width: 36.0,
                                height: 36.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 36.0,
                                  height: 36.0,
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(Icons.person, color: Colors.white70, size: 20.0),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stepper Row
              const SizedBox(height: 16.0),
              _buildStepper(),
              const SizedBox(height: 24.0),

              // Main content card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 3) ...[
                            const Text.rich(
                              TextSpan(
                                text: 'Final ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Review.',
                                    style: TextStyle(
                                      color: Color(0xFFD30814),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            const Text(
                              'CONFIRM DETAILS BEFORE SUBMISSION',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 11.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 20.0),
                          ],
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(color: const Color(0xFF232326)),
                            ),
                            child: Stack(
                              children: [
                                if (_currentStep == 3)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    right: 0,
                                    height: 4.0,
                                    child: Container(
                                      color: const Color(0xFFD30814),
                                    ),
                                  )
                                else
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: 4.0,
                                    child: Container(
                                      color: const Color(0xFFD30814),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                                  child: _buildCurrentStepContent(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          if (_currentStep == 3) ...[
                            _buildGuaranteedResponseTimeCard(),
                            const SizedBox(height: 24.0),
                          ],
                          _buildBottomButton(),
                          if (_currentStep == 3) ...[
                            const SizedBox(height: 16.0),
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _currentStep = 1;
                                  });
                                },
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF8E8E93), size: 16.0),
                                label: const Text(
                                  'EDIT DETAILS',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16.0),
                            Center(
                              child: Text(
                                'STEP $_currentStep OF 3 COMPLETED',
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (_currentStep == 2) ...[
                              const SizedBox(height: 16.0),
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentStep = 3;
                                    });
                                  },
                                  child: const Text(
                                    'Skip this step',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13.0,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 32.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep = 1;
              });
            }
          },
          child: _buildStepNode(1, 'DETAILS', _currentStep >= 1),
        ),
        _buildStepLine(_currentStep >= 2),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_currentStep > 2) {
              setState(() {
                _currentStep = 2;
              });
            }
          },
          child: _buildStepNode(2, 'ATTACHMENTS', _currentStep >= 2),
        ),
        _buildStepLine(_currentStep >= 3),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_currentStep > 3) {
              setState(() {
                _currentStep = 3;
              });
            }
          },
          child: _buildStepNode(3, 'REVIEW', _currentStep >= 3),
        ),
      ],
    );
  }

  Widget _buildStepNode(int step, String label, bool isActive) {
    final isCurrent = _currentStep == step;
    final isCompleted = _currentStep > step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32.0,
          height: 32.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFFD30814) : const Color(0xFF1C1C1E),
            border: isCurrent
                ? Border.all(color: Colors.white, width: 1.5)
                : Border.all(color: const Color(0xFF2C2C2E), width: 1.0),
            boxShadow: isActive && isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFD30814).withOpacity(0.4),
                      blurRadius: 8.0,
                      spreadRadius: 2.0,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16.0)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF8E8E93),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? const Color(0xFFD30814) : const Color(0xFF8E8E93),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0, left: 8.0, right: 8.0),
      child: Container(
        width: 45.0,
        height: 2.0,
        color: isCompleted ? const Color(0xFFD30814) : const Color(0xFF2C2C2E),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Content();
      case 2:
        return _buildStep2Content();
      case 3:
      default:
        return _buildStep3Content();
    }
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tell us your issue',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8.0),
        const Text(
          'Please provide as much detail as possible so our executive support team can assist you efficiently.',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 13.0,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28.0),

        _buildFieldLabel('CATEGORY'),
        const SizedBox(height: 8.0),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          hint: const Text('Select a category', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14.0)),
          dropdownColor: const Color(0xFF141416),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.keyboard_double_arrow_down_rounded, color: Color(0xFF8E8E93)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1C1C1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFD30814)),
            ),
          ),
          items: ['Payments', 'Technicals', 'Community'].map((cat) {
            return DropdownMenuItem<String>(value: cat, child: Text(cat));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedCategory = val;
            });
          },
        ),
        const SizedBox(height: 24.0),

        _buildFieldLabel('SUBJECT'),
        const SizedBox(height: 8.0),
        TextField(
          controller: _subjectController,
          style: const TextStyle(color: Colors.white, fontSize: 14.0),
          decoration: InputDecoration(
            hintText: 'Briefly describe the issue',
            hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
            filled: true,
            fillColor: const Color(0xFF1C1C1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFD30814)),
            ),
          ),
        ),
        const SizedBox(height: 24.0),

        _buildFieldLabel('PRIORITY LEVEL'),
        const SizedBox(height: 8.0),
        Row(
          children: [
            _buildPriorityButton('Low', const Color(0xFF8E8E93)),
            const SizedBox(width: 12.0),
            _buildPriorityButton('Medium', const Color(0xFFD4AF37)),
            const SizedBox(width: 12.0),
            _buildPriorityButton('High', const Color(0xFFD30814)),
          ],
        ),
        const SizedBox(height: 24.0),

        _buildFieldLabel('DETAILED DESCRIPTION'),
        const SizedBox(height: 8.0),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white, fontSize: 14.0),
          decoration: InputDecoration(
            hintText: 'Provide specific steps to reproduce the issue or context for your request...',
            hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
            filled: true,
            fillColor: const Color(0xFF1C1C1E),
            contentPadding: const EdgeInsets.all(16.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFD30814)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supporting Evidence',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24.0),

        InkWell(
          onTap: () async {
            final ImagePicker picker = ImagePicker();
            try {
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() {
                  _attachments.add(image.path);
                });
              }
            } catch (e) {
              debugPrint('Error picking image: $e');
            }
          },
          borderRadius: BorderRadius.circular(16.0),
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: const Color(0xFFD30814).withOpacity(0.3),
              borderRadius: 16.0,
              dashLength: 6.0,
              gap: 4.0,
            ),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF141416).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.cloud_upload_outlined, color: Colors.white70, size: 36.0),
                    SizedBox(height: 12.0),
                    Text(
                      'Tap to upload files',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6.0),
                    Text(
                      'PDF, PNG, or JPG (Max 5MB each)',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24.0),

        if (_attachments.isNotEmpty) ...[
          Column(
            children: _attachments.map((file) => _buildAttachmentItem(file)).toList(),
          ),
          const SizedBox(height: 12.0),
          _buildAddMoreButton(),
          const SizedBox(height: 24.0),
        ],

        _buildProTipCard(),
      ],
    );
  }

  Widget _buildAttachmentItem(String filePath) {
    final isLocalFile = filePath.startsWith('/') || filePath.contains(':\\') || filePath.contains('cache') || filePath.contains('picker');
    final fileName = isLocalFile ? filePath.split(Platform.isWindows ? '\\' : '/').last : filePath;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF232326)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: const Color(0xFFD30814).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: const Color(0xFFD30814).withOpacity(0.2)),
            ),
            child: const Icon(Icons.image_outlined, color: Color(0xFFD30814), size: 22.0),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  '240 KB',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20.0),
            onPressed: () {
              setState(() {
                _attachments.remove(filePath);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreButton() {
    return InkWell(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        try {
          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            setState(() {
              _attachments.add(image.path);
            });
          }
        } catch (e) {
          debugPrint('Error picking image: $e');
        }
      },
      borderRadius: BorderRadius.circular(12.0),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: const Color(0xFF2C2C2E),
          borderRadius: 12.0,
          dashLength: 4.0,
          gap: 4.0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          alignment: Alignment.center,
          child: const Text(
            '+ + Add More Files',
            style: TextStyle(
              color: Color(0xFFD30814),
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProTipCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF232326)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4.0,
            child: Container(
              color: const Color(0xFFF2C94C),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 4.0),
                const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF2C94C), size: 22.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRO TIP',
                        style: TextStyle(
                          color: Color(0xFFF2C94C),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      const Text(
                        'For faster resolution, ensure your screenshots clearly show the transaction ID and timestamp.',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12.0,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Content() {
    final priorityColor = _priority == 'High'
        ? const Color(0xFFD30814)
        : (_priority == 'Medium' ? const Color(0xFFD4AF37) : const Color(0xFF8E8E93));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewLabel('CATEGORY'),
                  const SizedBox(height: 6.0),
                  Text(
                    _selectedCategory ?? 'None',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewLabel('PRIORITY'),
                const SizedBox(height: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.0,
                        height: 6.0,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        _priority.toUpperCase(),
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24.0),

        _buildReviewLabel('SUBJECT'),
        const SizedBox(height: 6.0),
        Text(
          _subjectController.text.isEmpty ? 'No subject provided' : _subjectController.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24.0),

        _buildReviewLabel('DESCRIPTION'),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F11),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0xFF1C1C1E)),
          ),
          child: Text(
            _descriptionController.text.isEmpty
                ? 'No detailed description provided.'
                : _descriptionController.text,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 13.0,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 24.0),

        const Divider(color: Color(0xFF232326), height: 1.0),
        const SizedBox(height: 20.0),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewLabel('ATTACHMENTS'),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, color: Colors.white70, size: 18.0),
                      const SizedBox(width: 4.0),
                      Text(
                        '${_attachments.length} ${_attachments.length == 1 ? 'File' : 'Files'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewLabel('CONTACT VIA'),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedContactMethod = 'EMAIL';
                        });
                      },
                      child: _buildContactPill('EMAIL', const Color(0xFFD30814), _selectedContactMethod == 'EMAIL'),
                    ),
                    const SizedBox(width: 8.0),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedContactMethod = 'WHATSAPP';
                        });
                      },
                      child: _buildContactPill('WHATSAPP', const Color(0xFFD30814), _selectedContactMethod == 'WHATSAPP'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF8E8E93),
        fontSize: 10.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildContactPill(String method, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.08) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: isActive ? color.withOpacity(0.3) : const Color(0xFF2C2C2E)),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: isActive ? color : const Color(0xFF8E8E93),
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGuaranteedResponseTimeCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF232326)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4.0,
            child: Container(
              color: const Color(0xFF27AE60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 4.0),
                const Icon(Icons.timer_outlined, color: Color(0xFF27AE60), size: 22.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Guaranteed Response Time',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 6.0),
                      Text(
                        'Based on your executive tier, this ticket will be resolved within 4–8 hours.',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12.0,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFFD30814), size: 24.0),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'Raise a Ticket',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.0),
                        child: ProfileScreen.profileImagePath != null
                            ? Image.file(
                                File(ProfileScreen.profileImagePath!),
                                width: 36.0,
                                height: 36.0,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100&h=100&fit=crop&crop=face',
                                width: 36.0,
                                height: 36.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 36.0,
                                  height: 36.0,
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(Icons.person, color: Colors.white70, size: 20.0),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60.0),
                          Lottie.asset(
                            'assets/images/completed.json',
                            width: 130,
                            height: 130,
                            repeat: false,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF27AE60).withOpacity(0.08),
                                border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3), width: 2.0),
                              ),
                              child: const Center(
                                child: Icon(Icons.check_circle_rounded, color: Color(0xFF27AE60), size: 64.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32.0),
                          const Text(
                            'TICKET SUBMITTED!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          const Text(
                            'team will get back to you within\n4-8 hours',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 40.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(color: const Color(0xFF232326)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'REFERENCE ID',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 10.0),
                                Text(
                                  _submittedTicketId,
                                  style: const TextStyle(
                                    color: Color(0xFFD30814),
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                final ticketTitle = _subjectController.text.trim();
                                final ticketId = _submittedTicketId;
                                final newTicket = {
                                  'id': ticketId,
                                  'title': ticketTitle.isNotEmpty ? ticketTitle : 'New Support Request',
                                  'status': 'OPEN',
                                  'statusColor': const Color(0xFF2F80ED),
                                  'category': _selectedCategory ?? 'GENERAL',
                                  'description': _descriptionController.text.trim(),
                                };
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TrackTicketsScreen(initialTicket: newTicket),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD30814),
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Track My Ticket',
                                    style: TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8.0),
                                  Icon(Icons.arrow_forward, color: Colors.white, size: 16.0),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2C2C2E)),
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: const Text(
                                'Back to Support Home',
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40.0),
                          const Text(
                            '—  TBT SUPPORT OFFICIAL  —',
                            style: TextStyle(
                              color: Color(0xFF444446),
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 40.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityButton(String level, Color color) {
    final isSelected = _priority == level;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _priority = level;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF2C2C2E),
              width: 1.25,
            ),
          ),
          child: Center(
            child: Text(
              level,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF8E8E93),
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF8E8E93),
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildBottomButton() {
    String label = '';
    if (_currentStep == 1) {
      label = 'Next: Add Attachments';
    } else if (_currentStep == 2) {
      label = 'Next: Review & Submit';
    } else {
      label = 'SUBMIT TICKET';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _currentStep == 3 ? _submitTicket : _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD30814),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 5.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8.0),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 16.0),
          ],
        ),
      ),
    );
  }
}

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  String _selectedTopic = 'Payments'; // Payments, Technicals, Community
  List<Map<String, dynamic>> get _myTickets => TrackTicketsScreen.allTickets;

  List<Map<String, dynamic>> _getHelpTopics() {
    if (_selectedTopic == 'Payments') {
      return [
        {
          'title': 'Subscription & Billing',
          'icon': Icons.account_balance_wallet_outlined,
        },
        {
          'title': 'Invoice & GST Inquiries',
          'icon': Icons.receipt_long_outlined,
        },
        {
          'title': 'Refund Policy & Status',
          'icon': Icons.assignment_return_outlined,
        },
      ];
    } else if (_selectedTopic == 'Technicals') {
      return [
        {
          'title': 'Course Access & Recordings',
          'icon': Icons.play_circle_outline_rounded,
        },
        {
          'title': 'Login & Password Issues',
          'icon': Icons.lock_outline_rounded,
        },
        {
          'title': 'Video Player Lagging',
          'icon': Icons.videocam_outlined,
        },
      ];
    } else {
      return [
        {
          'title': 'Account Privacy & Security',
          'icon': Icons.shield_outlined,
        },
        {
          'title': 'Community Group Rules',
          'icon': Icons.groups_outlined,
        },
        {
          'title': 'Reporting Spam or Abuse',
          'icon': Icons.report_problem_outlined,
        },
      ];
    }
  }



  void _showCallUsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F11),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12.0),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(2.0))),
              const SizedBox(height: 24.0),
              const Text('Contact Elite Support Helpline', style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20.0),
              ListTile(
                leading: const Icon(Icons.phone_rounded, color: Color(0xFF27AE60)),
                title: const Text('Call Helpline (Toll-Free)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('1800 309 4820', style: TextStyle(color: Color(0xFF8E8E93))),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: Color(0xFF2C2C2E)),
              ListTile(
                leading: const Icon(Icons.message_rounded, color: Color(0xFF2F80ED)),
                title: const Text('Chat on WhatsApp Support', style: TextStyle(color: Colors.white)),
                subtitle: const Text('+91 94444 88888', style: TextStyle(color: Color(0xFF8E8E93))),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Support Center Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFFD30814), size: 24.0),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'Support Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    // Support agent avatar
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.0),
                        child: ProfileScreen.profileImagePath != null
                            ? Image.file(
                                File(ProfileScreen.profileImagePath!),
                                width: 36.0,
                                height: 36.0,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100&h=100&fit=crop&crop=face',
                                width: 36.0,
                                height: 36.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 36.0,
                                  height: 36.0,
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(Icons.person, color: Colors.white70, size: 20.0),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Support Page Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Help Banner Hero Card
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 4.0,
                                  child: Container(color: const Color(0xFFD30814)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: const Text(
                                          'How can we help\nyou?',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18.0,
                                            fontWeight: FontWeight.bold,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF27AE60).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(20.0),
                                          border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.2)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF27AE60),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            const Text(
                                              'SUPPORT\nONLINE',
                                              style: TextStyle(
                                                color: Color(0xFF27AE60),
                                                fontSize: 9.0,
                                                fontWeight: FontWeight.bold,
                                                height: 1.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28.0),

                          // Quick Actions Row
                          _buildSectionHeader('QUICK ACTIONS'),
                          const SizedBox(height: 12.0),
                          Row(
                            children: [
                              // Card 1: Raise Ticket
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RaiseTicketScreen(
                                          onTicketCreated: (newTicket) {
                                            setState(() {
                                              _myTickets.insert(0, newTicket);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Ticket created successfully! 🎫'),
                                                backgroundColor: Color(0xFF27AE60),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(20.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141416),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: const Color(0xFF232326)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD30814).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12.0),
                                            border: Border.all(color: const Color(0xFFD30814).withOpacity(0.2)),
                                          ),
                                          child: const Icon(Icons.confirmation_num_outlined, color: Color(0xFFD30814), size: 24.0),
                                        ),
                                        const SizedBox(height: 20.0),
                                        const Text(
                                          'Raise Ticket',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              // Card 2: Call Us
                              Expanded(
                                child: InkWell(
                                  onTap: _showCallUsBottomSheet,
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(20.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141416),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: const Color(0xFF232326)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD30814).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12.0),
                                            border: Border.all(color: const Color(0xFFD30814).withOpacity(0.2)),
                                          ),
                                          child: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFFD30814), size: 24.0),
                                        ),
                                        const SizedBox(height: 20.0),
                                        const Text(
                                          'Call Us',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
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
                          const SizedBox(height: 28.0),

                          // Browse Help Topics
                          _buildSectionHeader('BROWSE HELP TOPICS'),
                          const SizedBox(height: 12.0),
                          // Horizontal chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: ['Payments', 'Technicals', 'Community'].map((topic) {
                                final isSelected = _selectedTopic == topic;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTopic = topic;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12.0),
                                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141416),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFD30814) : const Color(0xFF2C2C2E),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      topic,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                                        fontSize: 13.0,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          // Help Topics List
                          Column(
                            children: _getHelpTopics().map((help) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141416),
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: const Color(0xFF232326)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(help['icon'], color: const Color(0xFFFFD4AF).withOpacity(0.85), size: 20.0),
                                    const SizedBox(width: 16.0),
                                    Expanded(
                                      child: Text(
                                        help['title'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14.0),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 28.0),

                          // My Recent Tickets Row Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('MY RECENT TICKETS'),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TrackTicketsScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'VIEW ALL',
                                  style: TextStyle(
                                    color: Color(0xFFD30814),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // Recent Tickets List
                          Column(
                            children: _myTickets.map((ticket) {
                              return GestureDetector(
                                onTap: () {
                                  final selected = {
                                    'id': ticket['id'],
                                    'title': ticket['title'],
                                    'status': ticket['status'],
                                    'statusColor': ticket['statusColor'],
                                    'category': ticket['id'] == '#TBT-2048'
                                        ? 'BILLING & PAYMENTS'
                                        : 'TECHNICAL SUPPORT',
                                    'description': ticket['title'],
                                  };
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TrackTicketsScreen(initialTicket: selected),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF141416),
                                    borderRadius: BorderRadius.circular(16.0),
                                    border: Border.all(color: const Color(0xFF232326)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1C1C1E),
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),
                                        child: const Icon(Icons.description_outlined, color: Colors.white70, size: 20.0),
                                      ),
                                      const SizedBox(width: 16.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ticket['id'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4.0),
                                            Text(
                                              ticket['title'],
                                              style: const TextStyle(
                                                color: Color(0xFF8E8E93),
                                                fontSize: 12.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                        decoration: BoxDecoration(
                                          color: ticket['statusColor'].withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(16.0),
                                          border: Border.all(color: ticket['statusColor'].withOpacity(0.35)),
                                        ),
                                        child: Text(
                                          ticket['status'],
                                          style: TextStyle(
                                            color: ticket['statusColor'],
                                            fontSize: 10.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFFFD4AF),
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}

// Custom painter to generate a real QR Code inside the virtual card back
class QRPainter extends CustomPainter {
  final String data;
  final Color color;

  QRPainter(this.data, {this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Find the smallest QR Code version that can fit the data
      QrCode? qrCode;
      for (int type = 3; type <= 40; type++) {
        try {
          final qr = QrCode(type, QrErrorCorrectLevel.L);
          qr.addData(data);
          qrCode = qr;
          break;
        } catch (_) {}
      }

      if (qrCode == null) return;

      final qrImage = QrImage(qrCode);
      final double squareSize = size.width / qrImage.moduleCount;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (int x = 0; x < qrImage.moduleCount; x++) {
        for (int y = 0; y < qrImage.moduleCount; y++) {
          if (qrImage.isDark(y, x)) {
            canvas.drawRect(
              Rect.fromLTWH(x * squareSize, y * squareSize, squareSize, squareSize),
              paint,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error painting QR Code: $e');
    }
  }

  @override
  bool shouldRepaint(covariant QRPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashLength = 5.0,
    this.gap = 3.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = dashLength;
        if (distance + length > metric.length) {
          canvas.drawPath(metric.extractPath(distance, metric.length), paint);
        } else {
          canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        }
        distance += length + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class TrackTicketsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialTicket;
  const TrackTicketsScreen({super.key, this.initialTicket});

  // Global static list of all tickets to persist in memory
  static final List<Map<String, dynamic>> allTickets = [
    {
      'id': '#TBT-2048',
      'title': 'Billing Discrepancy: Tier 3 Membership',
      'fullTitle': 'Billing Discrepancy: Tier 3 Membership Renewal',
      'category': 'BILLING & PAYMENTS',
      'status': 'IN PROGRESS',
      'statusColor': const Color(0xFFD4AF37),
      'updatedText': 'Updated 12m ago',
      'agentName': 'Sarah',
      'agentAvatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face',
      'messages': [
        {
          'sender': 'user',
          'senderName': 'Alexander',
          'text': 'Hi, I noticed my last renewal for the Tier 3 Executive Membership was charged twice on my American Express card. Could you please look into this and process a refund for the duplicate transaction?',
          'time': 'SENT - 10:26 AM',
        },
        {
          'sender': 'agent',
          'senderName': 'Sarah',
          'text': "Hello Alexander, thank you for reaching out. I'm Sarah from the Billing team. I've located both transactions in our system. It appears there was a momentary sync lag during the processing window.",
          'time': 'SARAH - 10:42 AM',
        },
        {
          'sender': 'user',
          'senderName': 'Alexander',
          'text': 'Thanks Sarah, that\'s great news. Just one more thing—will this affect my access to the exclusive content until the refund clears?',
          'time': 'SENT - 10:45 AM',
        },
      ],
    },
    {
      'id': '#TBT-1992',
      'title': 'Course Content Access Issue',
      'fullTitle': 'Course Content Access Issue',
      'category': 'COURSE ACCESS',
      'status': 'RESOLVED',
      'statusColor': const Color(0xFF27AE60),
      'updatedText': 'Updated 2d ago',
      'agentName': 'Vijay',
      'agentAvatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face',
      'messages': [
        {
          'sender': 'user',
          'senderName': 'Alexander',
          'text': 'I bought the new masterclass, but the contents are showing as locked in my profile dashboard. Please unlock.',
          'time': 'SENT - 2d ago',
        },
        {
          'sender': 'agent',
          'senderName': 'Vijay',
          'text': 'Hello, the course has been unlocked for your account. Please reload the app and let us know if you face any further issues.',
          'time': 'VIJAY - 2d ago',
        },
        {
          'sender': 'user',
          'senderName': 'Alexander',
          'text': 'It works now! Thank you so much for the quick response.',
          'time': 'SENT - 2d ago',
        },
      ],
    },
    {
      'id': '#TBT-1855',
      'title': 'API Key Integration Support',
      'fullTitle': 'API Key Integration Support',
      'category': 'DEVELOPER TOOLS',
      'status': 'OPEN',
      'statusColor': const Color(0xFF2F80ED),
      'updatedText': 'Updated 5d ago',
      'agentName': 'Rahul',
      'agentAvatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face',
      'messages': [
        {
          'sender': 'user',
          'senderName': 'Alexander',
          'text': 'We are getting a 403 Forbidden error when trying to fetch developer APIs from our CRM backend.',
          'time': 'SENT - 5d ago',
        },
        {
          'sender': 'agent',
          'senderName': 'Rahul',
          'text': "Hello, we are checking the server logs. It seems your API key wasn't activated on our production node yet. I'll get back to you shortly.",
          'time': 'RAHUL - 5d ago',
        },
      ],
    },
  ];

  @override
  State<TrackTicketsScreen> createState() => _TrackTicketsScreenState();
}

class _TrackTicketsScreenState extends State<TrackTicketsScreen> {
  late List<Map<String, dynamic>> _tickets;
  late String _selectedTicketId;
  String _selectedFilter = 'All'; // All, Open, In Progress, Resolved
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tickets = TrackTicketsScreen.allTickets;

    if (widget.initialTicket != null) {
      final exists = _tickets.any((t) => t['id'] == widget.initialTicket!['id']);
      if (!exists) {
        final ticket = {
          'id': widget.initialTicket!['id'],
          'title': widget.initialTicket!['title'],
          'fullTitle': widget.initialTicket!['title'],
          'category': widget.initialTicket!['category'] ?? 'GENERAL',
          'status': widget.initialTicket!['status'],
          'statusColor': widget.initialTicket!['statusColor'] ?? const Color(0xFF2F80ED),
          'updatedText': 'Updated Just Now',
          'agentName': 'Agent',
          'agentAvatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop&crop=face',
          'messages': [
            {
              'sender': 'user',
              'senderName': 'Alexander',
              'text': widget.initialTicket!['description'] ?? 'No description provided.',
              'time': 'SENT - Just Now',
            },
          ],
        };
        _tickets.insert(0, ticket);
        _selectedTicketId = ticket['id'] as String;
      } else {
        _selectedTicketId = widget.initialTicket!['id'] as String;
        final idx = _tickets.indexWhere((t) => t['id'] == widget.initialTicket!['id']);
        if (idx != -1 && (_tickets[idx]['messages'] == null || (_tickets[idx]['messages'] as List).isEmpty)) {
          _tickets[idx]['messages'] = [
            {
              'sender': 'user',
              'senderName': 'Alexander',
              'text': widget.initialTicket!['description'] ?? 'Ticket submitted.',
              'time': 'SENT - Just Now',
            }
          ];
        }
      }
    } else {
      _selectedTicketId = _tickets.isNotEmpty ? _tickets.first['id'] as String : '#TBT-2048';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic> get _activeTicket {
    return _tickets.firstWhere(
      (t) => t['id'] == _selectedTicketId,
      orElse: () => _tickets.first,
    );
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_selectedFilter == 'All') return _tickets;
    return _tickets.where((t) {
      final status = t['status'] as String;
      if (_selectedFilter == 'Open') return status == 'OPEN';
      if (_selectedFilter == 'In Progress') return status == 'IN PROGRESS';
      if (_selectedFilter == 'Resolved') return status == 'RESOLVED';
      return true;
    }).toList();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      final active = _activeTicket;
      (active['messages'] as List).add({
        'sender': 'user',
        'senderName': 'Alexander',
        'text': text,
        'time': 'SENT - Just Now',
      });
      _messageController.clear();
    });

    _scrollToBottom();

    // Auto-reply
    final activeId = _selectedTicketId;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _selectedTicketId != activeId) return;
      setState(() {
        final active = _tickets.firstWhere((t) => t['id'] == activeId);
        final agentName = active['agentName'] ?? 'Agent';
        (active['messages'] as List).add({
          'sender': 'agent',
          'senderName': agentName,
          'text': "We have received your update. A member of our support team is looking into this and will respond shortly.",
          'time': "${agentName.toUpperCase()} - Just Now",
        });
      });
      _scrollToBottom();
    });
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileExtension = result.files.single.extension?.toLowerCase() ?? '';

        setState(() {
          final active = _activeTicket;
          (active['messages'] as List).add({
            'sender': 'user',
            'senderName': 'Alexander',
            'text': 'Attachment: $fileName',
            'time': 'SENT - Just Now',
            'isAttachment': true,
            'attachmentPath': filePath,
            'attachmentName': fileName,
            'attachmentType': _getAttachmentType(fileExtension),
          });
        });

        _scrollToBottom();

        // Simulate agent auto-reply acknowledging attachment
        final activeId = _selectedTicketId;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted || _selectedTicketId != activeId) return;
          setState(() {
            final active = _tickets.firstWhere((t) => t['id'] == activeId);
            final agentName = active['agentName'] ?? 'Agent';
            (active['messages'] as List).add({
              'sender': 'agent',
              'senderName': agentName,
              'text': "I've received your attachment ($fileName). Our team will review it and get back to you.",
              'time': "${agentName.toUpperCase()} - Just Now",
            });
          });
          _scrollToBottom();
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  String _getAttachmentType(String ext) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return 'image';
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv'].contains(ext)) {
      return 'video';
    } else if (['mp3', 'wav', 'm4a', 'aac', 'flac'].contains(ext)) {
      return 'audio';
    } else if (['ppt', 'pptx'].contains(ext)) {
      return 'ppt';
    } else {
      return 'file';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      resizeToAvoidBottomInset: true,
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
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header
              _buildHeader(),
              // Layout Builder for Responsiveness
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 768) {
                      return _buildWideLayout();
                    } else {
                      return _buildMobileLayout();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFD30814), size: 24.0),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8.0),
          const Text(
            'TBT Support',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // User Avatar
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.0),
              child: ProfileScreen.profileImagePath != null
                  ? Image.file(
                      File(ProfileScreen.profileImagePath!),
                      width: 36.0,
                      height: 36.0,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100&h=100&fit=crop&crop=face',
                      width: 36.0,
                      height: 36.0,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 36.0,
                        height: 36.0,
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(Icons.person, color: Colors.white70, size: 20.0),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel (Ticket List)
        SizedBox(
          width: 340.0,
          child: Column(
            children: [
              _buildListHeader(),
              _buildFilterChips(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: _filteredTickets.map((t) => _buildTicketCard(t, isMobile: false)).toList(),
                ),
              ),
            ],
          ),
        ),
        // Divider
        Container(
          width: 1,
          color: const Color(0xFF232326),
        ),
        // Right Panel (Active Ticket Chat)
        Expanded(
          child: _buildChatPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Column(
      children: [
        if (!isKeyboardOpen) ...[
          _buildListHeader(),
          _buildFilterChips(),
          // Horizontally scrollable list of ticket cards
          SizedBox(
            height: 110.0,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              physics: const BouncingScrollPhysics(),
              children: _filteredTickets.map((t) => _buildTicketCard(t, isMobile: true)).toList(),
            ),
          ),
          const SizedBox(height: 12.0),
        ],
        // Expanded Chat Panel
        Expanded(
          child: _buildChatPanel(),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'My Tickets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RaiseTicketScreen(
                    onTicketCreated: (newTicket) {
                      setState(() {
                        final exists = _tickets.any((t) => t['id'] == newTicket['id']);
                        if (!exists) {
                          final ticket = {
                            'id': newTicket['id'],
                            'title': newTicket['title'],
                            'fullTitle': newTicket['title'],
                            'category': 'GENERAL',
                            'status': newTicket['status'],
                            'statusColor': newTicket['statusColor'] ?? const Color(0xFF2F80ED),
                            'updatedText': 'Updated Just Now',
                            'agentName': 'Agent',
                            'agentAvatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop&crop=face',
                            'messages': [
                              {
                                'sender': 'user',
                                'senderName': 'Alexander',
                                'text': 'Ticket submitted.',
                                'time': 'SENT - Just Now',
                              },
                            ],
                          };
                          _tickets.insert(0, ticket);
                          _selectedTicketId = ticket['id'] as String;
                        }
                      });
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 14.0),
            label: const Text(
              'New Ticket',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD30814),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Open', 'In Progress', 'Resolved'];
    return Container(
      height: 36.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isActive = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF8E8E93),
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isActive,
              selectedColor: const Color(0xFFD30814),
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: BorderSide(
                  color: isActive ? const Color(0xFFD30814) : const Color(0xFF2C2C2E),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, {required bool isMobile}) {
    final isActive = ticket['id'] == _selectedTicketId;
    final statusColor = (ticket['statusColor'] ?? const Color(0xFF2F80ED)) as Color;

    Widget cardContent = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isActive)
            Container(
              width: 4,
              color: const Color(0xFFD30814),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      ticket['category'] == 'BILLING & PAYMENTS'
                          ? Icons.credit_card_rounded
                          : ticket['category'] == 'COURSE ACCESS'
                              ? Icons.school_outlined
                              : Icons.settings_outlined,
                      color: isActive ? const Color(0xFFD30814) : Colors.white70,
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ticket['id'],
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          ticket['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          ticket['updatedText'] ?? 'Updated Just Now',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 10.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          ticket['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 8.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isActive && ticket['agentAvatar'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9.0),
                          child: Image.network(
                            ticket['agentAvatar'],
                            width: 18.0,
                            height: 18.0,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTicketId = ticket['id'] as String;
        });
        _scrollToBottom();
      },
      child: Container(
        width: isMobile ? 260.0 : double.infinity,
        margin: isMobile
            ? const EdgeInsets.only(right: 12.0, bottom: 8.0, top: 4.0)
            : const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isActive ? const Color(0xFFD30814).withOpacity(0.5) : const Color(0xFF232326),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    final active = _activeTicket;
    final messages = active['messages'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ticket details header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: active['category'] ?? 'GENERAL',
                        style: const TextStyle(
                          color: Color(0xFFD30814),
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        children: [
                          const TextSpan(
                            text: '   -   ',
                            style: TextStyle(color: Color(0xFF8E8E93)),
                          ),
                          TextSpan(
                            text: 'ID: ${active['id']}',
                            style: const TextStyle(color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      active['fullTitle'] ?? active['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Ticket Created Tag divider
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: const Text(
              'TICKET CREATED - OCT 12, 10:24 AM',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Chat Stream List with Scrollbar
        Expanded(
          child: Scrollbar(
            controller: _chatScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 4.0,
            radius: const Radius.circular(2.0),
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index] as Map<String, dynamic>;
                final isUser = msg['sender'] == 'user';
                return _buildChatMessage(msg, isUser, active['agentAvatar']);
              },
            ),
          ),
        ),
        // Message Input Box
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> msg, bool isUser, String? agentAvatar) {
    final isAttachment = msg['isAttachment'] == true;
    final attachmentType = msg['attachmentType'] as String?;
    final attachmentPath = msg['attachmentPath'] as String?;
    final attachmentName = msg['attachmentName'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            GestureDetector(
              onTap: () {
                if (agentAvatar != null) {
                  showProfilePhotoDialog(context, agentAvatar);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: agentAvatar != null
                    ? Image.network(
                        agentAvatar,
                        width: 30.0,
                        height: 30.0,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 30.0,
                          height: 30.0,
                          color: const Color(0xFF2C2C2E),
                          child: const Icon(Icons.person, color: Colors.white70, size: 16.0),
                        ),
                      )
                    : Container(
                        width: 30.0,
                        height: 30.0,
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(Icons.person, color: Colors.white70, size: 16.0),
                      ),
              ),
            ),
            const SizedBox(width: 10.0),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFD30814) : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16.0),
                      topRight: const Radius.circular(16.0),
                      bottomLeft: isUser ? const Radius.circular(16.0) : const Radius.circular(4.0),
                      bottomRight: isUser ? const Radius.circular(4.0) : const Radius.circular(16.0),
                    ),
                  ),
                  child: isAttachment
                      ? _buildAttachmentView(attachmentType, attachmentPath, attachmentName, isUser)
                      : Text(
                          msg['text'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            height: 1.4,
                          ),
                        ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  msg['time'],
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8.0),
        ],
      ),
    );
  }

  Widget _buildAttachmentView(String? type, String? path, String? name, bool isUser) {
    if (type == 'image' && path != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.file(
              File(path),
              width: 180,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 180,
                height: 120,
                color: Colors.black26,
                child: const Icon(Icons.broken_image, color: Colors.white30, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            name ?? 'image.jpg',
            style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = Colors.white70;

    if (type == 'video') {
      iconData = Icons.video_library_rounded;
      iconColor = Colors.amber;
    } else if (type == 'audio') {
      iconData = Icons.audiotrack_rounded;
      iconColor = Colors.cyan;
    } else if (type == 'ppt') {
      iconData = Icons.slideshow_rounded;
      iconColor = Colors.orange;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconData, color: iconColor, size: 24),
        const SizedBox(width: 8.0),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? 'file',
                style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2.0),
              Text(
                type?.toUpperCase() ?? 'FILE',
                style: const TextStyle(color: Colors.white70, fontSize: 9.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F11),
        border: Border(
          top: BorderSide(color: Color(0xFF1C1C1E)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFF8E8E93)),
            onPressed: _pickAttachment,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14.0),
                decoration: const InputDecoration(
                  hintText: 'Type your response...',
                  hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 14.0),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                color: Color(0xFFD30814),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18.0),
            ),
          ),
        ],
      ),
    );
  }
}

void showProfilePhotoDialog(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28.0),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
                child: _buildDialogImage(imageUrl),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildDialogImage(String imageUrl) {
  if (imageUrl.startsWith('http')) {
    final highResUrl = imageUrl.replaceAll('w=100&h=100', 'w=500&h=500').replaceAll('w=200&h=200', 'w=500&h=500');
    return Image.network(
      highResUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  } else if (imageUrl.startsWith('assets/')) {
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  } else {
    return Image.file(
      File(imageUrl),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }
}

Widget _buildPlaceholder() {
  return Container(
    width: 300,
    height: 300,
    color: const Color(0xFF1C1C1E),
    child: const Icon(Icons.person, color: Colors.white70, size: 100.0),
  );
}

void showProfileAvatarOptionsSheet({
  required BuildContext context,
  required VoidCallback onPhotoChanged,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0F0F11),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12.0),
                Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.white70),
                  title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSaveProfileImage(context, ImageSource.gallery, onPhotoChanged);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Colors.white70),
                  title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSaveProfileImage(context, ImageSource.camera, onPhotoChanged);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_rounded, color: Colors.white70),
                  title: const Text('View Photo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    showProfilePhotoDialog(
                      context,
                      ProfileScreen.profileImagePath ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop&crop=face',
                    );
                  },
                ),
                if (ProfileScreen.profileImagePath != null)
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: Color(0xFFD30814)),
                    title: const Text('Remove Photo', style: TextStyle(color: Color(0xFFD30814))),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      ProfileScreen.profileImagePath = null;
                      try {
                        final directory = await getApplicationDocumentsDirectory();
                        final file = File('${directory.path}/profile_path.txt');
                        if (await file.exists()) {
                          await file.delete();
                        }
                      } catch (e) {
                        debugPrint('Error deleting profile path: $e');
                      }
                      onPhotoChanged();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile photo removed'),
                          backgroundColor: Color(0xFF2C2C2E),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12.0),
              ],
            ),
          );
        }
      );
    },
  );
}

Future<void> _pickAndSaveProfileImage(BuildContext context, ImageSource source, VoidCallback onPhotoChanged) async {
  final ImagePicker picker = ImagePicker();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedFile = await File(image.path).copy('${directory.path}/$fileName');
      
      ProfileScreen.profileImagePath = savedFile.path;
      try {
        final file = File('${directory.path}/profile_path.txt');
        await file.writeAsString(savedFile.path);
      } catch (e) {
        debugPrint('Error saving profile path: $e');
      }
      
      onPhotoChanged();
      
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully! 🎉'),
          backgroundColor: Color(0xFF27AE60),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error picking profile image: $e');
    messenger.showSnackBar(
      SnackBar(
        content: Text('Error updating photo: $e'),
        backgroundColor: const Color(0xFFD30814),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'New Course Published: Advanced Cryptographic Protocols',
      'subtitle': 'Duration: 6 Weeks · Free',
      'time': '2 hours ago',
      'icon': Icons.shield_rounded,
      'iconColor': const Color(0xFFD30814),
      'isUnread': true,
    },
    {
      'title': 'Price Updated: Digital Marketing Excellence',
      'subtitle': 'Duration: 8 Weeks · ₹ 4,999',
      'time': '5 hours ago',
      'icon': Icons.trending_up_rounded,
      'iconColor': const Color(0xFFD30814),
      'isUnread': true,
    },
    {
      'title': 'Course Updated: Business Scalability 101',
      'subtitle': 'Duration: 4 Weeks · ₹ 2,499',
      'time': 'Yesterday',
      'icon': Icons.business_rounded,
      'iconColor': const Color(0xFF8E8E93),
      'isUnread': false,
    },
    {
      'title': 'New Mentor Session: Strategic Leadership with Anbarasu',
      'subtitle': 'Duration: 1 Hour · Premium',
      'time': '2 days ago',
      'icon': Icons.psychology_rounded,
      'iconColor': const Color(0xFF8E8E93),
      'isUnread': false,
    },
  ];

  void _markAllRead() {
    setState(() {
      for (var notification in _notifications) {
        notification['isUnread'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: Color(0xFF1C1C1E),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/TBT C Pvt Final logo-04.png',
              height: 52.0, // Large Brand Logo in AppBar
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8.0),
            const Text(
              'Alerts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: Color(0xFFD30814),
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16.0),
                // Prominent brand header with a large logo inside
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: const Color(0xFFD30814).withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD30814).withOpacity(0.04),
                          blurRadius: 20.0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/TBT C Pvt Final logo-04.png',
                          height: 76.0, // Huge logo
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14.0),
                        const Text(
                          'Tamil Business Tribe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Stay updated with your latest tribe alerts & notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                const Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12.0),
                Expanded(
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: const Color(0xFF2C2C2E),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Unread Red Dot
                            if (item['isUnread'] == true) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 18.0, right: 8.0),
                                width: 6.0,
                                height: 6.0,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD30814),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 14.0),
                            ],
                            
                            // Icon Container
                            Container(
                              width: 48.0,
                              height: 48.0,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: item['iconColor'] as Color,
                                size: 24.0,
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    item['subtitle'] as String,
                                    style: const TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    item['time'] as String,
                                    style: const TextStyle(
                                      color: Color(0xFF6E6E73),
                                      fontSize: 11.5,
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
