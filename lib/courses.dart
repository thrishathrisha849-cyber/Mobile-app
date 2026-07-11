import 'dart:io';
import 'package:flutter/material.dart';
import 'profile.dart';
import 'main.dart';
import 'notification_service.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  @override
  void initState() {
    super.initState();
    NotificationBadge.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = context.textColor;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const TbtAppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: textColor, size: 24.0),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppLogo.appBar(),
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
                  color: context.borderCol,
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
            icon: AnimatedBuilder(
              animation: NotificationBadge.instance,
              builder: (context, _) {
                final count = NotificationBadge.instance.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_outlined,
                        color: textColor, size: 22.0),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2.0),
                          constraints:
                              const BoxConstraints(minWidth: 14, minHeight: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD30814),
                            shape: BoxShape.circle,
                          ),
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
                    builder: (context) => const NotificationsScreen()),
              ).then((_) => NotificationBadge.instance.refresh());
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
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF1E0304), // Dark Red Glow backdrop
                    Color(0xFF0B0B0F),
                    Color(0xFF0B0B0F),
                  ]
                : const [
                    Color(0xFFFFECEE),
                    Color(0xFFF5F5F5),
                    Color(0xFFFFFFFF),
                  ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Premium lock / Course Icon with glow
              Container(
                width: 90.0,
                height: 90.0,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD30814).withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD30814).withOpacity(0.08),
                      blurRadius: 24.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFFD30814),
                  size: 40.0,
                ),
              ),
              const SizedBox(height: 24.0),
              Text(
                'No Enrolled Courses',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10.0),
              Text(
                'Start your learning journey today! Any courses you enroll in will be displayed here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black54,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28.0),
              // Explore Catalog Button
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Course Catalog is coming soon!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD30814),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Explore Catalog',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
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
