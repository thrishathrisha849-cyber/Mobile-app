import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart'; // Import theme context properties like context.isDark

class LevelData {
  final String role;
  final String desc;
  final double requiredXp;
  final double x; // ratio of screen width [0.0, 1.0]
  final double y; // y coordinate in layout

  const LevelData({
    required this.role,
    required this.desc,
    required this.requiredXp,
    required this.x,
    required this.y,
  });
}

const List<LevelData> levels = [
  LevelData(
      role: 'Orientation',
      desc: 'Get familiar with the course structure, tools, and how grading works.',
      requiredXp: 40,
      x: 0.5,
      y: 60),
  LevelData(
      role: 'Foundations',
      desc: 'Core concepts and terminology every later module builds on.',
      requiredXp: 70,
      x: 0.78,
      y: 180),
  LevelData(
      role: 'Core Skills',
      desc: 'Hands-on exercises building the actual skill, not just theory.',
      requiredXp: 110,
      x: 0.5,
      y: 300),
  LevelData(
      role: 'Applied Practice',
      desc: 'Real-world case studies — apply what you learned under messier conditions.',
      requiredXp: 150,
      x: 0.22,
      y: 420),
  LevelData(
      role: 'Assessment',
      desc: 'Timed quiz covering every module so far. No partial credit for effort.',
      requiredXp: 200,
      x: 0.5,
      y: 540),
  LevelData(
      role: 'Certification',
      desc: 'Final project review and certificate issue — the actual credential.',
      requiredXp: 260,
      x: 0.78,
      y: 660),
];

class LevelState {
  double xp;
  bool done;
  int fails;
  int stars;

  LevelState({
    this.xp = 0.0,
    this.done = false,
    this.fails = 0,
    this.stars = 0,
  });
}

class CourseQuestScreen extends StatefulWidget {
  const CourseQuestScreen({super.key});

  @override
  State<CourseQuestScreen> createState() => _CourseQuestScreenState();
}

class _CourseQuestScreenState extends State<CourseQuestScreen>
    with TickerProviderStateMixin {
  late List<LevelState> _states;
  int _currentIdx = 0;
  int _activePanelIdx = 0;

  // Shake animation controller
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Floating text tracker
  final List<Map<String, dynamic>> _floatingTexts = [];
  final double _mapHeight = 740.0;

  @override
  void initState() {
    super.initState();
    _resetStates();

    // Setup shake animation for quiz failure
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 8.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  void _resetStates() {
    _states = List.generate(
        levels.length,
        (index) => LevelState(
              xp: 0.0,
              done: false,
              fails: 0,
              stars: 0,
            ));
    _currentIdx = 0;
    _activePanelIdx = 0;
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0).then((_) => _shakeController.reverse());
  }

  void _onStudySession(double studyGain) {
    if (_currentIdx >= levels.length) return;
    final state = _states[_currentIdx];
    final requiredXp = levels[_currentIdx].requiredXp;

    setState(() {
      state.xp = math.min(requiredXp, state.xp + studyGain);
      // Spawn floating points
      _floatingTexts.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': '+${studyGain.toStringAsFixed(0)} XP',
        'yOffset': 0.0,
      });
    });
  }

  void _onTakeQuiz() {
    if (_currentIdx >= levels.length) return;
    final state = _states[_currentIdx];
    final requiredXp = levels[_currentIdx].requiredXp;

    if (state.xp >= requiredXp) {
      // Clear level
      setState(() {
        state.done = true;
        state.stars = state.fails == 0 ? 3 : (state.fails == 1 ? 2 : 1);
        _currentIdx++;
        _activePanelIdx = math.min(levels.length - 1, _currentIdx);
      });

      _showCelebrationDialog(levels[_currentIdx - 1].role, state.stars);
    } else {
      // Fail penalty: deduct 40% of XP
      setState(() {
        state.fails++;
        final double deduction = state.xp * 0.4;
        state.xp = math.max(0.0, state.xp - deduction);
      });
      _triggerShake();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Quiz failed — not enough prep. Lost 40% of the progress meter.'),
          backgroundColor: const Color(0xFFD30814),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCelebrationDialog(String moduleRole, int starsEarned) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _CelebrationDialog(
          moduleRole: moduleRole,
          starsEarned: starsEarned,
          onClose: () => Navigator.pop(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    int totalStars = _states.fold(0, (sum, state) => sum + state.stars);
    final bool allDone = _currentIdx >= levels.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFF7F7F9),
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'COURSE QUEST',
          style: TextStyle(
            color: textColor,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _resetStates();
              });
            },
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Color(0xFFE50914),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: GlassmorphicBackground(
        child: Column(
          children: [
            // Sticky top HUD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Learning Path',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFFFD97D), size: 16.0),
                        const SizedBox(width: 6.0),
                        Text(
                          '$totalStars / ${levels.length * 3} Stars',
                          style: TextStyle(
                            color: const Color(0xFFFFD97D),
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Header Banner Info
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                            'Module Path',
                            style: TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Clear each module to advance the path. Study to fill the progress meter, then take the quiz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map segment with path & nodes
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        return Container(
                          height: _mapHeight,
                          width: width,
                          margin: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Stack(
                            children: [
                              // 1. Curved dotted path line
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: PathPainter(
                                    levels: levels,
                                    currentIdx: _currentIdx,
                                    isDark: isDark,
                                  ),
                                ),
                              ),

                              // 2. Interactive node circles
                              ...List.generate(levels.length, (index) {
                                final level = levels[index];
                                final state = _states[index];

                                final bool isDone = state.done;
                                final bool isActive = index == _currentIdx;
                                final bool isLocked = index > _currentIdx;

                                final double left = level.x * width - 37;
                                final double top = level.y - 37;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  child: BouncingNode(
                                    active: isActive,
                                    child: GestureDetector(
                                      onTap: isLocked
                                          ? null
                                          : () {
                                              setState(() {
                                                _activePanelIdx = index;
                                              });
                                            },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 64.0,
                                            height: 64.0,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: isLocked
                                                  ? LinearGradient(
                                                      colors: [
                                                        Colors.grey.shade400,
                                                        Colors.grey.shade600
                                                      ],
                                                    )
                                                  : (isDone
                                                      ? const LinearGradient(
                                                          colors: [
                                                            Color(0xFF27AE60),
                                                            Color(0xFF2E9B5E)
                                                          ],
                                                        )
                                                      : const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFFD97D),
                                                            Color(0xFFE50914)
                                                          ],
                                                        )),
                                              border: Border.all(
                                                color: _activePanelIdx == index
                                                    ? const Color(0xFFE50914)
                                                    : Colors.white,
                                                width: 3.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.15),
                                                  blurRadius: 8.0,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: isLocked
                                                  ? const Icon(Icons.lock_rounded,
                                                      color: Colors.white, size: 20.0)
                                                  : Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 20.0,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (isDone) ...[
                                            const SizedBox(height: 4.0),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(3, (starIdx) {
                                                final bool hasStar = starIdx < state.stars;
                                                return Icon(
                                                  Icons.star_rate_rounded,
                                                  size: 14.0,
                                                  color: hasStar
                                                      ? const Color(0xFFFFD97D)
                                                      : Colors.white.withOpacity(0.3),
                                                );
                                              }),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),

                    // Level Detail Control Card
                    if (!allDone) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            double offset = 0.0;
                            if (_shakeController.isAnimating) {
                              offset = math.sin(_shakeController.value * 6 * math.pi) *
                                  _shakeAnimation.value;
                            }
                            return Transform.translate(
                              offset: Offset(offset, 0.0),
                              child: child,
                            );
                          },
                          child: GlassmorphicCard(
                            padding: const EdgeInsets.all(22.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Module ${_activePanelIdx + 1}',
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (_states[_activePanelIdx].done)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF27AE60).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: const Text(
                                          'COMPLETED',
                                          style: TextStyle(
                                            color: Color(0xFF27AE60),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  levels[_activePanelIdx].role,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10.0),
                                Text(
                                  levels[_activePanelIdx].desc,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20.0),

                                // Meter Progress Row
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Prep Meter',
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${_states[_activePanelIdx].xp.toStringAsFixed(0)} / ${levels[_activePanelIdx].requiredXp.toStringAsFixed(0)} XP',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8.0),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10.0),
                                      child: Container(
                                        height: 14.0,
                                        color: isDark ? Colors.black12 : Colors.grey.shade200,
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final double percent = math.min(
                                                1.0,
                                                _states[_activePanelIdx].xp /
                                                    levels[_activePanelIdx].requiredXp);
                                            return Stack(
                                              children: [
                                                Container(
                                                  width: constraints.maxWidth * percent,
                                                  decoration: const BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Color(0xFFFFD97D),
                                                        Color(0xFFE50914)
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24.0),

                                // Panel Study & Quiz Buttons
                                if (_activePanelIdx == _currentIdx) ...[
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                final double gain = 4 + math.Random().nextDouble() * 7;
                                                _onStudySession(gain);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isDark
                                                    ? Colors.white.withOpacity(0.08)
                                                    : Colors.black.withOpacity(0.04),
                                                elevation: 0.0,
                                                padding:
                                                    const EdgeInsets.symmetric(vertical: 14.0),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12.0),
                                                  side: BorderSide(
                                                    color: isDark
                                                        ? Colors.white.withOpacity(0.12)
                                                        : Colors.black.withOpacity(0.1),
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                'Study Session',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 13.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12.0),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: _onTakeQuiz,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFE50914),
                                                padding:
                                                    const EdgeInsets.symmetric(vertical: 14.0),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                              ),
                                              child: const Text(
                                                'Take the Quiz',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Render floating particles
                                      ..._floatingTexts.map((fMap) {
                                        return Positioned(
                                          left: 40.0,
                                          bottom: 10.0,
                                          child: _FloatingPoints(
                                            text: fMap['text'],
                                            onFinished: () {
                                              setState(() {
                                                _floatingTexts.removeWhere(
                                                    (element) => element['id'] == fMap['id']);
                                              });
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    _states[_activePanelIdx].done
                                        ? 'You have completed this module.'
                                        : 'Clear previous modules to unlock.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 12.0,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (allDone) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                        child: GlassmorphicCard(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(Icons.workspace_premium_rounded,
                                  color: Color(0xFFFFD97D), size: 48.0),
                              const SizedBox(height: 12.0),
                              Text(
                                '🎉 Course Cleared!',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'Congratulations! You completed the learning path. Reset to improve your star ratings.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 13.0,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class PathPainter extends CustomPainter {
  final List<LevelData> levels;
  final int currentIdx;
  final bool isDark;

  PathPainter({
    required this.levels,
    required this.currentIdx,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    for (int i = 1; i < levels.length; i++) {
      final Path segmentPath = Path();
      final double px = levels[i - 1].x * w;
      final double py = levels[i - 1].y;
      final double x = levels[i].x * w;
      final double y = levels[i].y;

      segmentPath.moveTo(px, py);
      segmentPath.quadraticBezierTo(
        (px + x) / 2,
        (py + y) / 2 - 10,
        x,
        y,
      );

      final bool isCompleted = i <= currentIdx;
      final Paint segmentPaint = Paint()
        ..color = isCompleted
            ? const Color(0xFFE50914)
            : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      _drawDashedPathSegment(canvas, segmentPath, segmentPaint);
    }
  }

  void _drawDashedPathSegment(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    const double dashLength = 6.0;
    const double gapLength = 8.0;

    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double currentDashLength = math.min(dashLength, metric.length - distance);
        final Path extract = metric.extractPath(distance, distance + currentDashLength);
        canvas.drawPath(extract, paint);
        distance += currentDashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.currentIdx != currentIdx || oldDelegate.isDark != isDark;
  }
}

class BouncingNode extends StatefulWidget {
  final Widget child;
  final bool active;

  const BouncingNode({super.key, required this.child, required this.active});

  @override
  State<BouncingNode> createState() => _BouncingNodeState();
}

class _BouncingNodeState extends State<BouncingNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BouncingNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _FloatingPoints extends StatefulWidget {
  final String text;
  final VoidCallback onFinished;

  const _FloatingPoints({
    required this.text,
    required this.onFinished,
  });

  @override
  State<_FloatingPoints> createState() => _FloatingPointsState();
}

class _FloatingPointsState extends State<_FloatingPoints>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _yOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _yOffset = Tween<double>(begin: 0.0, end: -50.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, _yOffset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(
              widget.text,
              style: const TextStyle(
                color: Color(0xFFE50914),
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CelebrationDialog extends StatefulWidget {
  final String moduleRole;
  final int starsEarned;
  final VoidCallback onClose;

  const _CelebrationDialog({
    required this.moduleRole,
    required this.starsEarned,
    required this.onClose,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starAnimations;

  @override
  void initState() {
    super.initState();

    _starControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    _starAnimations = _starControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ),
      );
    }).toList();

    // Sequence star pops
    for (int i = 0; i < widget.starsEarned; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 180), () {
        if (mounted) {
          _starControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32.0),
          child: GlassmorphicCard(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nice Work! 🎉',
                  style: TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${widget.moduleRole} module complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13.0,
                  ),
                ),
                const SizedBox(height: 24.0),

                // Sequential stars pop
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final bool hasStar = index < widget.starsEarned;
                    return AnimatedBuilder(
                      animation: _starAnimations[index],
                      builder: (context, child) {
                        final double scale = hasStar ? _starAnimations[index].value : 1.0;
                        final double opacity = hasStar ? 1.0 : 0.25;
                        return Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.0),
                              child: Icon(
                                Icons.stars_rounded,
                                color: Color(0xFFFFD97D),
                                size: 48.0,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                const SizedBox(height: 32.0),

                ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  child: const Text(
                    'Next Level',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
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
