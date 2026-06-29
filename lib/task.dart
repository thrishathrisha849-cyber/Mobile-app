import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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
// 90-Day Tasks Screen (Mastery Progress Screen)
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
              'stepName': 'STEP 0 — ONBOARDING & SETUP',
              'title': 'Attend Onboarding Call / Watch Replay',
              'subtitle': 'Attend the live onboarding kick-off session or watch the video replay to align on the core 90-day execution framework.',
              'points': 250,
              'type': 'SCREENSHOT',
              'isCompleted': true,
              'isMilestone': false,
              'estimated': '60 Minutes',
              'difficulty': 'Foundational Level',
              'deliverables': [
                'Completed onboarding profile registration.',
                'Joined the community groups.',
                'Watched the onboarding framework recording.'
              ]
            },
            {
              'id': '2',
              'day': 'D02',
              'step': 1,
              'stepName': 'STEP 1 — BMC & METRICS',
              'title': 'Fill Customer Segment in BMC',
              'subtitle': 'Define the high-value target audience for your product. Focus on psychological triggers, spending capacity, and pain points that align with your unique value proposition. This document will serve as the foundation for your acquisition strategy.',
              'points': 500,
              'type': 'UPLOAD FILE',
              'isCompleted': false,
              'isMilestone': false,
              'estimated': '45 Minutes',
              'difficulty': 'Executive Level',
              'deliverables': [
                'Identified demographic markers (Age, Location, Income).',
                'Psychographic profile (Values, Interests, Lifestyle).',
                'Pain point mapping against product features.'
              ]
            },
            {
              'id': '3',
              'day': 'D10',
              'step': 2,
              'stepName': 'STEP 2 — CUSTOMER INTERVIEWS',
              'title': 'Conduct 5 Customer Interviews',
              'subtitle': 'Validate the core problem statement with potential target clients and record feedback. Gather qualitative data regarding their constraints.',
              'points': 300,
              'type': 'UPLOAD FILE',
              'isCompleted': false,
              'isMilestone': false,
              'estimated': '120 Minutes',
              'difficulty': 'Strategic Level',
              'deliverables': [
                'Drafted question guide for client interviews.',
                'Completed interviews with 5 potential buyers.',
                'Summarized feedback worksheets.'
              ]
            },
            {
              'id': '4',
              'day': 'D25',
              'step': 3,
              'stepName': 'STEP 3 — MVP LANDING PAGE',
              'title': 'Launch Landing Page MVP',
              'subtitle': 'Create a simple landing page showcasing the offer value proposition and signup form. Collect early subscriber signups.',
              'points': 400,
              'type': 'SCREENSHOT',
              'isCompleted': false,
              'isMilestone': false,
              'estimated': '90 Minutes',
              'difficulty': 'Execution Level',
              'deliverables': [
                'Set up domain and landing page design layout.',
                'Drafted lead capture copywriting.',
                'Configured subscriber database triggers.'
              ]
            },
            {
              'id': '5',
              'day': 'D45',
              'step': 4,
              'stepName': 'STEP 4 — MILESTONE',
              'title': 'Step 4 Final Submission',
              'subtitle': 'Consolidate all learnings, customer interviews, and MVP landing page analytics from Step 4 into the final execution template.',
              'points': 500,
              'type': 'PDF UPLOAD',
              'isCompleted': false,
              'isMilestone': true,
              'estimated': '90 Minutes',
              'difficulty': 'Mastery Level',
              'deliverables': [
                'Compiled customer interview analysis report.',
                'Landing page conversion rate metrics screenshot.',
                'Finalized offer messaging framework document.'
              ]
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

                  // Tasks List (Tapping opens details page)
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsScreen(
              taskIndex: originalIndex,
              onTaskCompleted: () {
                _loadTasks();
              },
            ),
          ),
        );
      },
      child: Container(
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
                Row(
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
      ),
    );
  }
}

// ----------------------------------------------------
// NEW Task Details Screen
// ----------------------------------------------------
class TaskDetailsScreen extends StatefulWidget {
  final int taskIndex;
  final VoidCallback onTaskCompleted;

  const TaskDetailsScreen({
    super.key,
    required this.taskIndex,
    required this.onTaskCompleted,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late Map<String, dynamic> _taskDetails;
  List<Map<String, dynamic>> _allTasks = [];
  String? _selectedFileName;
  String? _selectedFilePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }

  Future<File> _getTasksFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tbt_90day_tasks.json');
  }

  Future<File> _getPointsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tbt_spotlight_state.json');
  }

  Future<void> _loadTaskDetails() async {
    try {
      final file = await _getTasksFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        _allTasks = List<Map<String, dynamic>>.from(json.decode(content));
        setState(() {
          _taskDetails = _allTasks[widget.taskIndex];
        });
      }
    } catch (e) {
      debugPrint('Error loading task details: $e');
    }
  }

  Future<void> _pickFile() async {
    if (_taskDetails['isCompleted']) return;

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

  void _submitTask() async {
    if (_taskDetails['isCompleted']) return;

    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a proof file first! 📁'),
          backgroundColor: Color(0xFFD30814),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Simulate network upload
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // 1. Mark task completed in 90-day task list
      _allTasks[widget.taskIndex]['isCompleted'] = true;
      final file = await _getTasksFile();
      await file.writeAsString(json.encode(_allTasks));

      // 2. Load points file and update total points & completed task count
      final pointsFile = await _getPointsFile();
      int currentPoints = 4820;
      int currentCompleted = 40;
      double progressPercentage = 47.8;
      int dayCount = 43;
      Map<String, dynamic> pointsData = {};

      if (await pointsFile.exists()) {
        final content = await pointsFile.readAsString();
        pointsData = Map<String, dynamic>.from(json.decode(content));
        currentPoints = pointsData['totalPoints'] ?? 4820;
        currentCompleted = pointsData['tasksCompleted'] ?? 40;
        progressPercentage = pointsData['progressPercentage'] ?? 47.8;
        dayCount = pointsData['dayCount'] ?? 43;
      }

      currentPoints += (_taskDetails['points'] as int);
      currentCompleted += 1;
      progressPercentage = double.parse((progressPercentage + 1.2).toStringAsFixed(1));
      dayCount += 1;

      pointsData['totalPoints'] = currentPoints;
      pointsData['tasksCompleted'] = currentCompleted;
      pointsData['progressPercentage'] = progressPercentage;
      pointsData['dayCount'] = dayCount;

      // Add to achievements list
      List<dynamic> achievements = pointsData['achievements'] != null
          ? List.from(pointsData['achievements'])
          : [];
      achievements.insert(0, {
        'day': _taskDetails['day'],
        'title': _taskDetails['title'],
        'time': 'Completed just now',
      });
      pointsData['achievements'] = achievements;

      await pointsFile.writeAsString(json.encode(pointsData));

      widget.onTaskCompleted();

      setState(() {
        _isSubmitting = false;
        _taskDetails['isCompleted'] = true;
      });

      if (!mounted) return;

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
              Text('Task Completed!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Success! Task submitted. Earned +${_taskDetails['points']} TBT Points! 🎉',
            style: const TextStyle(color: Color(0xFFD1D1D6)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Pop back to NinetyDayTasksScreen
              },
              child: const Text('Perfect', style: TextStyle(color: Color(0xFFD30814), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      debugPrint('Error submitting task: $e');
    }
  }

  void _markAsAlreadyCompleted() async {
    if (_taskDetails['isCompleted']) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (!mounted) return;

      // 1. Mark task completed in 90-day task list
      _allTasks[widget.taskIndex]['isCompleted'] = true;
      final file = await _getTasksFile();
      await file.writeAsString(json.encode(_allTasks));

      // 2. Load points file and update total points & completed task count
      final pointsFile = await _getPointsFile();
      int currentPoints = 4820;
      int currentCompleted = 40;
      double progressPercentage = 47.8;
      int dayCount = 43;
      Map<String, dynamic> pointsData = {};

      if (await pointsFile.exists()) {
        final content = await pointsFile.readAsString();
        pointsData = Map<String, dynamic>.from(json.decode(content));
        currentPoints = pointsData['totalPoints'] ?? 4820;
        currentCompleted = pointsData['tasksCompleted'] ?? 40;
        progressPercentage = pointsData['progressPercentage'] ?? 47.8;
        dayCount = pointsData['dayCount'] ?? 43;
      }

      currentPoints += (_taskDetails['points'] as int);
      currentCompleted += 1;
      progressPercentage = double.parse((progressPercentage + 1.2).toStringAsFixed(1));
      dayCount += 1;

      pointsData['totalPoints'] = currentPoints;
      pointsData['tasksCompleted'] = currentCompleted;
      pointsData['progressPercentage'] = progressPercentage;
      pointsData['dayCount'] = dayCount;

      // Add to achievements list
      List<dynamic> achievements = pointsData['achievements'] != null
          ? List.from(pointsData['achievements'])
          : [];
      achievements.insert(0, {
        'day': _taskDetails['day'],
        'title': _taskDetails['title'],
        'time': 'Completed just now',
      });
      pointsData['achievements'] = achievements;

      await pointsFile.writeAsString(json.encode(pointsData));

      widget.onTaskCompleted();

      setState(() {
        _isSubmitting = false;
        _taskDetails['isCompleted'] = true;
      });

      if (!mounted) return;

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
              Text('Task Completed!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Success! Task marked as completed. Earned +${_taskDetails['points']} TBT Points! 🎉',
            style: const TextStyle(color: Color(0xFFD1D1D6)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Pop back to NinetyDayTasksScreen
              },
              child: const Text('Perfect', style: TextStyle(color: Color(0xFFD30814), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      debugPrint('Error marking task as completed: $e');
    }
  }

  void _playVideo() {
    showDialog(
      context: context,
      builder: (context) => const VideoPlayDialog(assetPath: 'assets/images/tbt_logo_video.mp4'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allTasks.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFD30814)))),
      );
    }

    final isCompleted = _taskDetails['isCompleted'] ?? false;
    final title = _taskDetails['title'] ?? '';

    // Split title dynamically or display
    Widget titleWidget;
    if (title.contains('BMC')) {
      titleWidget = RichText(
        text: const TextSpan(
          style: TextStyle(color: Colors.white, fontSize: 28.0, fontWeight: FontWeight.w900, height: 1.15),
          children: [
            TextSpan(text: 'Fill Customer\nSegment in\n'),
            TextSpan(text: 'BMC', style: TextStyle(color: Color(0xFFD30814))),
          ],
        ),
      );
    } else {
      final words = title.split(' ');
      if (words.length > 2) {
        final lastWord = words.last;
        final firstPart = title.substring(0, title.length - lastWord.length);
        titleWidget = RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 28.0, fontWeight: FontWeight.w900, height: 1.15),
            children: [
              TextSpan(text: firstPart),
              TextSpan(text: lastWord, style: const TextStyle(color: Color(0xFFD30814))),
            ],
          ),
        );
      } else {
        titleWidget = Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 28.0, fontWeight: FontWeight.w900, height: 1.15),
        );
      }
    }

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
                  // Step Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD30814).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      _taskDetails['stepName'] ?? 'STEP TASK',
                      style: const TextStyle(
                        color: Color(0xFFD30814),
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Dynamic Title
                  titleWidget,
                  const SizedBox(height: 24.0),

                  // Rewards/Estimated Info Grid
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem(Icons.stars_rounded, 'REWARDS', '${_taskDetails['points']} XP Points'),
                            const SizedBox(height: 16.0),
                            _buildInfoItem(Icons.bar_chart_rounded, 'DIFFICULTY', _taskDetails['difficulty'] ?? 'Executive Level'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem(Icons.access_time_filled_rounded, 'ESTIMATED', _taskDetails['estimated'] ?? '45 Minutes'),
                            const SizedBox(height: 16.0),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28.0),

                  // Task Description
                  Text(
                    _taskDetails['subtitle'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13.0,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28.0),

                  // Video preview widget
                  GestureDetector(
                    onTap: _playVideo,
                    child: Container(
                      width: double.infinity,
                      height: 160.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.0),
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1542744094-3a31f103e35f?w=500&h=300&fit=crop'),
                          fit: BoxFit.cover,
                          opacity: 0.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.0),
                              color: Colors.black38,
                            ),
                          ),
                          const CircleAvatar(
                            radius: 28.0,
                            backgroundColor: Color(0xFFD30814),
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36.0),
                          ),
                          Positioned(
                            left: 16.0,
                            bottom: 16.0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'EXPERT INSIGHT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2.0),
                                Text(
                                  'Watch: The Art of Segmentation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28.0),

                  // Deliverables Section
                  _buildSectionHeader(Icons.checklist_rounded, 'Deliverables'),
                  const SizedBox(height: 12.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: Colors.white.withOpacity(0.03), width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (_taskDetails['deliverables'] as List<dynamic>?)?.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 5.0,
                                    height: 5.0,
                                    margin: const EdgeInsets.only(top: 6.0),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD30814),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Text(
                                      item.toString(),
                                      style: const TextStyle(
                                        color: Color(0xFFD1D1D6),
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList() ??
                          [],
                    ),
                  ),
                  const SizedBox(height: 28.0),

                  // Submit Proof Section
                  _buildSectionHeader(Icons.drive_folder_upload_rounded, 'Submit Proof'),
                  const SizedBox(height: 12.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: Colors.white.withOpacity(0.03), width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _pickFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF050505),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.white.withOpacity(0.04)
                                    : const Color(0xFFD30814).withOpacity(0.2),
                                style: BorderStyle.solid,
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : (_selectedFileName != null
                                          ? Icons.insert_drive_file_rounded
                                          : Icons.cloud_upload_outlined),
                                  color: isCompleted
                                      ? const Color(0xFFD30814)
                                      : (_selectedFileName != null ? const Color(0xFF27AE60) : Colors.white24),
                                  size: 28.0,
                                ),
                                const SizedBox(height: 12.0),
                                Text(
                                  isCompleted
                                      ? 'Task Completed Successfully'
                                      : (_selectedFileName ?? 'Drag and drop your file'),
                                  style: TextStyle(
                                    color: isCompleted
                                        ? const Color(0xFFD30814)
                                        : (_selectedFileName != null ? Colors.white : Colors.white70),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                if (!isCompleted)
                                  Text(
                                    _selectedFileName != null
                                        ? 'Tap to change file'
                                        : 'PDF, PNG, or JPG (Max 10MB)',
                                    style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!isCompleted) ...[
                          const SizedBox(height: 20.0),
                          SizedBox(
                            width: double.infinity,
                            height: 48.0,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitTask,
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
                                  : const Text(
                                      'SUBMIT TASK FOR REVIEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Center(
                            child: TextButton(
                              onPressed: _isSubmitting ? null : _markAsAlreadyCompleted,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              ),
                              child: const Text(
                                'MARK AS ALREADY COMPLETED',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 36.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD30814), size: 16.0),
        const SizedBox(width: 8.0),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 14.0,
          backgroundColor: const Color(0xFF141416),
          child: Icon(icon, color: const Color(0xFFD30814), size: 14.0),
        ),
        const SizedBox(width: 12.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 7.0,
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
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// Video Player Dialog overlay
// ----------------------------------------------------
class VideoPlayDialog extends StatefulWidget {
  final String assetPath;
  const VideoPlayDialog({super.key, required this.assetPath});

  @override
  State<VideoPlayDialog> createState() => _VideoPlayDialogState();
}

class _VideoPlayDialogState extends State<VideoPlayDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expert Insight Video',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                        Align(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _controller.value.isPlaying ? _controller.pause() : _controller.play();
                              });
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              radius: 24,
                              child: Icon(
                                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD30814)),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
