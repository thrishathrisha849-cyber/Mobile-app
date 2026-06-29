import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // State variables matching the screenshot
  int _currentStep = 4;
  int _totalSteps = 12;
  int _dayCount = 43;
  double _progressPercentage = 47.8;
  int _totalPoints = 4820;
  int _dayStreak = 7;
  int _tasksCompleted = 40;

  String? _selectedFileName;
  String? _selectedFilePath;
  bool _isSubmitting = false;

  // Recent achievements list
  List<Map<String, dynamic>> _achievements = [
    {
      'day': 'D42',
      'title': 'Technical Architecture Review',
      'time': 'Completed 14 hours ago',
    },
    {
      'day': 'D41',
      'title': 'Stakeholder Presentation Deck',
      'time': 'Completed yesterday',
    },
    {
      'day': 'D40',
      'title': 'Competitive Analysis Matrix',
      'time': 'Completed 2 days ago',
    },
  ];

  // List of upcoming spotlights
  final List<Map<String, dynamic>> _upcomingSpotlights = [
    {
      'step': 4,
      'title': 'Step 4 — Website: Product Description Draft',
      'description': 'Draft the technical specifications and value proposition copy for the primary product landing page. Focus on conversion-driven executive language.',
      'reward': 100,
      'dayCode': 'D43',
    },
    {
      'step': 5,
      'title': 'Step 5 — Email Sequence Copywriting',
      'description': 'Write a high-converting cold email sequence for the initial outreach campaign targeting enterprise clients.',
      'reward': 100,
      'dayCode': 'D44',
    },
    {
      'step': 6,
      'title': 'Step 6 — Lead Magnet Design & Outline',
      'description': 'Design the visual layout and structure the detailed outline for the primary lead magnet PDF document.',
      'reward': 100,
      'dayCode': 'D45',
    },
    {
      'step': 7,
      'title': 'Step 7 — Marketing Funnel Analytics Setup',
      'description': 'Configure Google Analytics events and conversion tracking tags for the main marketing funnel pathways.',
      'reward': 100,
      'dayCode': 'D46',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tbt_spotlight_state.json');
  }

  Future<void> _loadState() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        setState(() {
          _currentStep = data['currentStep'] ?? 4;
          _progressPercentage = data['progressPercentage'] ?? 47.8;
          _totalPoints = data['totalPoints'] ?? 4820;
          _tasksCompleted = data['tasksCompleted'] ?? 40;
          _dayStreak = data['dayStreak'] ?? 7;
          _dayCount = data['dayCount'] ?? 43;
          _achievements = List<Map<String, dynamic>>.from(data['achievements']);
        });
      }
    } catch (e) {
      debugPrint('Error loading spotlight state: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final file = await _getLocalFile();
      final data = {
        'currentStep': _currentStep,
        'progressPercentage': _progressPercentage,
        'totalPoints': _totalPoints,
        'tasksCompleted': _tasksCompleted,
        'dayStreak': _dayStreak,
        'dayCount': _dayCount,
        'achievements': _achievements,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('Error saving spotlight state: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  void _submitFile() {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a file first! 📁'),
          backgroundColor: Color(0xFFD30814),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate network submission upload
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final currentSpotlight = _upcomingSpotlights.firstWhere(
        (s) => s['step'] == _currentStep,
        orElse: () => _upcomingSpotlights.first,
      );

      setState(() {
        _isSubmitting = false;

        // 1. Update points and completion counts
        _totalPoints += (currentSpotlight['reward'] as int);
        _tasksCompleted += 1;
        _progressPercentage = double.parse((_progressPercentage + 1.2).toStringAsFixed(1));
        _dayCount += 1;

        // 2. Add to achievements list
        _achievements.insert(0, {
          'day': currentSpotlight['dayCode'],
          'title': (currentSpotlight['title'] as String).replaceFirst(RegExp(r'Step \d+ — '), ''),
          'time': 'Completed just now',
        });

        // 3. Move to next step if available
        if (_currentStep < _totalSteps) {
          _currentStep += 1;
        }

        _selectedFileName = null;
        _selectedFilePath = null;
      });

      _saveState();

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF27AE60), size: 28.0),
              SizedBox(width: 10.0),
              Text('Step Submitted!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Congratulations! You have completed the task and earned +${currentSpotlight['reward']} TBT Points! 🎉',
            style: const TextStyle(color: Color(0xFFD1D1D6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Great!', style: TextStyle(color: Color(0xFFD30814), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Find active spotlight details
    final activeSpotlight = _upcomingSpotlights.firstWhere(
      (s) => s['step'] == _currentStep,
      orElse: () => {
        'step': _currentStep,
        'title': 'Step $_currentStep - Upcoming Strategy Session',
        'description': 'Draft and finalize the core operational deliverables for the next stage of business growth.',
        'reward': 100,
        'dayCode': 'D$_dayCount',
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button & Navigation
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.0),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16.0),

                  // Header Greetings
                  const Text(
                    'GOOD MORNING',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 10.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  const Text(
                    'Hi Arjun S.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Mastery Progress Card (Interactive)
                  _buildMasteryProgressCard(),
                  const SizedBox(height: 16.0),

                  // Stats Row
                  _buildStatsRow(),
                  const SizedBox(height: 28.0),

                  // Today's Spotlight Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TODAY\'S SPOTLIGHT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Step $_currentStep of $_totalSteps',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Spotlight Card
                  _buildSpotlightCard(activeSpotlight),
                  const SizedBox(height: 28.0),

                  // Recent Achievements Section
                  const Text(
                    'RECENT ACHIEVEMENTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Achievements List
                  ..._achievements.map((item) => _buildAchievementItem(item)),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasteryProgressCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NinetyDayTasksScreen()),
        ).then((_) {
          // Reload state if modified in child screen
          _loadState();
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFFD30814).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: const Color(0xFFD30814).withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              child: const Text(
                'MASTERY PROGRESS',
                style: TextStyle(
                  color: Color(0xFFD30814),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Day $_dayCount ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const TextSpan(
                              text: '/ 90',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        'You\'ve surpassed ${(_progressPercentage - 0.8).toStringAsFixed(0)}% of the curriculum. Your velocity is 12% higher than the cohort average.',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24.0),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76.0,
                      height: 76.0,
                      child: CircularProgressIndicator(
                        value: _progressPercentage / 100,
                        strokeWidth: 6.0,
                        backgroundColor: Colors.white.withOpacity(0.04),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD30814)),
                      ),
                    ),
                    Text(
                      '$_progressPercentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events_rounded,
            label: 'TOTAL POINTS',
            value: _totalPoints.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: _buildStatCard(
            icon: Icons.whatshot_rounded,
            label: 'DAY STREAK',
            value: _dayStreak.toString(),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_rounded,
            label: 'TASKS COMPLETED',
            value: _tasksCompleted.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD30814), size: 18.0),
          const SizedBox(height: 8.0),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD30814),
              fontSize: 15.0,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightCard(Map<String, dynamic> spotlight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD30814),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const Text(
                  'HIGH PRIORITY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '+ ${spotlight['reward']} PTS REWARD',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Text(
            spotlight['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.0,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            spotlight['description'],
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12.0,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20.0),

          // File Picker / Upload button
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFileName != null ? Icons.insert_drive_file_rounded : Icons.cloud_upload_outlined,
                    color: _selectedFileName != null ? const Color(0xFF27AE60) : Colors.white38,
                    size: 24.0,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    _selectedFileName ?? 'UPLOAD REQUIRED',
                    style: TextStyle(
                      color: _selectedFileName != null ? Colors.white : Colors.white38,
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD30814),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2.0,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Submit File',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6.0),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14.0),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.03),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: const Color(0xFFD30814).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              item['day'],
              style: const TextStyle(
                color: Color(0xFFD30814),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
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
                const SizedBox(height: 4.0),
                Text(
                  item['time'],
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF27AE60),
            size: 20.0,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// NEW 90-Day Tasks Screen (Mastery Progress Screen)
// ----------------------------------------------------
class NinetyDayTasksScreen extends StatefulWidget {
  const NinetyDayTasksScreen({super.key});

  @override
  State<NinetyDayTasksScreen> createState() => _NinetyDayTasksScreenState();
}

class _NinetyDayTasksScreenState extends State<NinetyDayTasksScreen> {
  String _activeFilter = 'All';
  List<Map<String, dynamic>> _tasks = [];

  final List<String> _filters = [
    'All',
    'Step 0',
    'Step 1',
    'Step 2',
    'Step 3',
    'Step 4',
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<File> _getTasksFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tbt_90day_tasks.json');
  }

  Future<File> _getPointsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tbt_spotlight_state.json');
  }

  Future<void> _loadTasks() async {
    try {
      final file = await _getTasksFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(json.decode(content));
        });
      } else {
        setState(() {
          _tasks = [
            {
              'id': '1',
              'day': 'D01',
              'step': 0,
              'stepName': 'STEP 0 - ONBOARDING',
              'title': 'Attend Onboarding Call / Watch Replay',
              'subtitle': 'Detailed analysis of your target demographic including pain points and expectations.',
              'points': 250,
              'type': 'SCREENSHOT',
              'isCompleted': true,
              'isMilestone': false,
            },
            {
              'id': '2',
              'day': 'D02',
              'step': 1,
              'stepName': 'STEP 1 - BMC',
              'title': 'Fill Customer Segment in BMC',
              'subtitle': 'Identify 3 direct competitors and list their unique value propositions compared to yours.',
              'points': 150,
              'type': 'UPLOAD FILE',
              'isCompleted': false,
              'isMilestone': false,
            },
            {
              'id': '3',
              'day': 'D10',
              'step': 2,
              'stepName': 'STEP 2 - VALIDATION',
              'title': 'Conduct 5 Customer Interviews',
              'subtitle': 'Validate the core problem statement with potential target clients and record feedback.',
              'points': 300,
              'type': 'UPLOAD FILE',
              'isCompleted': false,
              'isMilestone': false,
            },
            {
              'id': '4',
              'day': 'D25',
              'step': 3,
              'stepName': 'STEP 3 - MVP',
              'title': 'Launch Landing Page MVP',
              'subtitle': 'Create a simple landing page showcasing the offer value proposition and signup form.',
              'points': 400,
              'type': 'SCREENSHOT',
              'isCompleted': false,
              'isMilestone': false,
            },
            {
              'id': '5',
              'day': 'D45',
              'step': 4,
              'stepName': 'STEP 4 - MILESTONE',
              'title': 'Step 4 Final Submission',
              'subtitle': 'Consolidate all learnings from Step 4 into the final execution template.',
              'points': 500,
              'type': 'PDF UPLOAD',
              'isCompleted': false,
              'isMilestone': true,
            },
          ];
        });
        _saveTasks();
      }
    } catch (e) {
      debugPrint('Error loading 90-day tasks: $e');
    }
  }

  Future<void> _saveTasks() async {
    try {
      final file = await _getTasksFile();
      await file.writeAsString(json.encode(_tasks));
    } catch (e) {
      debugPrint('Error saving 90-day tasks: $e');
    }
  }

  Future<void> _completeTask(int index) async {
    final task = _tasks[index];
    if (task['isCompleted']) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null) {
        setState(() {
          _tasks[index]['isCompleted'] = true;
        });
        await _saveTasks();

        // Load points file and update total points & completed task count
        final pointsFile = await _getPointsFile();
        int currentPoints = 4820;
        int currentCompleted = 40;
        double progressPercentage = 47.8;
        int dayCount = 43;
        Map<String, dynamic> data = {};

        if (await pointsFile.exists()) {
          final content = await pointsFile.readAsString();
          data = Map<String, dynamic>.from(json.decode(content));
          currentPoints = data['totalPoints'] ?? 4820;
          currentCompleted = data['tasksCompleted'] ?? 40;
          progressPercentage = data['progressPercentage'] ?? 47.8;
          dayCount = data['dayCount'] ?? 43;
        }

        currentPoints += (task['points'] as int);
        currentCompleted += 1;
        progressPercentage = double.parse((progressPercentage + 1.2).toStringAsFixed(1));
        dayCount += 1;
        
        data['totalPoints'] = currentPoints;
        data['tasksCompleted'] = currentCompleted;
        data['progressPercentage'] = progressPercentage;
        data['dayCount'] = dayCount;
        
        // Add to achievements
        List<dynamic> achievements = data['achievements'] != null 
            ? List.from(data['achievements']) 
            : [];
        achievements.insert(0, {
          'day': task['day'],
          'title': task['title'],
          'time': 'Completed just now',
        });
        data['achievements'] = achievements;

        await pointsFile.writeAsString(json.encode(data));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task Completed! +${task['points']} Points! 🎉'),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter tasks based on step filter
    List<Map<String, dynamic>> filteredTasks = _tasks.where((task) {
      if (_activeFilter == 'All') return true;
      final stepNum = int.tryParse(_activeFilter.replaceFirst('Step ', '')) ?? 0;
      return task['step'] == stepNum;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8.0),
                  // Title Section
                  const Text(
                    '90-Day Tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  const Text(
                    'Track every task, every step of the way',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // Horizontal Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _filters.map((filter) {
                        final isActive = _activeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeFilter = filter;
                              });
                            },
                            borderRadius: BorderRadius.circular(20.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFD30814) : const Color(0xFF141416),
                                borderRadius: BorderRadius.circular(24.0),
                                border: Border.all(
                                  color: isActive ? const Color(0xFFD30814) : Colors.white.withOpacity(0.04),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  color: isActive ? Colors.white : const Color(0xFF8E8E93),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 28.0),

                  // Tasks List
                  ...filteredTasks.asMap().entries.map((entry) {
                    final idx = _tasks.indexOf(entry.value);
                    return _build90DayTaskCard(entry.value, idx);
                  }),
                  const SizedBox(height: 32.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build90DayTaskCard(Map<String, dynamic> task, int originalIndex) {
    final bool isCompleted = task['isCompleted'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Day Pill, Step Name, Done status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFD30814).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  task['day'],
                  style: const TextStyle(
                    color: Color(0xFFD30814),
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              if (task['stepName'] != null)
                Text(
                  task['stepName'].toString(),
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 8.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              const Spacer(),
              if (isCompleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFFD30814), size: 12.0),
                    SizedBox(width: 4.0),
                    Text(
                      'DONE',
                      style: TextStyle(
                        color: Color(0xFFD30814),
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Title
          Text(
            task['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8.0),

          // Subtitle
          Text(
            task['subtitle'],
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12.0,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20.0),

          // Bottom Row: Points, Action trigger type, Milestone pill
          Row(
            children: [
              // Points Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFD30814), size: 14.0),
                  const SizedBox(width: 4.0),
                  Text(
                    '${task['points']} PTS',
                    style: const TextStyle(
                      color: Color(0xFFD30814),
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16.0),

              // Action Trigger type (clickable if pending)
              InkWell(
                onTap: isCompleted ? null : () => _completeTask(originalIndex),
                borderRadius: BorderRadius.circular(4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      color: isCompleted ? const Color(0xFF636366) : Colors.white38,
                      size: 14.0,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      task['type'].toString(),
                      style: TextStyle(
                        color: isCompleted ? const Color(0xFF636366) : Colors.white38,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Milestone Tag
              if (task['isMilestone'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: const Text(
                    'MILESTONE',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
