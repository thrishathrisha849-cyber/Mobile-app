import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TaskItem {
  String id;
  String title;
  bool isCompleted;
  String category;

  TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'category': category,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
        category: json['category'] ?? 'General',
      );
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskItem> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  String _selectedCategory = 'Business';
  String _activeFilter = 'All';

  final List<String> _categories = ['Business', 'Marketing', 'Learning', 'Personal'];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tbt_tasks.json');
  }

  Future<void> _loadTasks() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        setState(() {
          _tasks = jsonList.map((json) => TaskItem.fromJson(json)).toList();
        });
      } else {
        // Add default seed tasks if no file exists
        setState(() {
          _tasks = [
            TaskItem(id: '1', title: 'Plan weekly social media content', category: 'Marketing'),
            TaskItem(id: '2', title: 'Attend TBT mastermind call', category: 'Business', isCompleted: true),
            TaskItem(id: '3', title: 'Complete module 3 of Elite Sales Course', category: 'Learning'),
            TaskItem(id: '4', title: 'Review business metrics & OKRs', category: 'Business'),
          ];
        });
        _saveTasks();
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  Future<void> _saveTasks() async {
    try {
      final file = await _getLocalFile();
      final jsonList = _tasks.map((task) => task.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  void _toggleTask(String id) {
    setState(() {
      final index = _tasks.indexWhere((task) => task.id == id);
      if (index != -1) {
        _tasks[index].isCompleted = !_tasks[index].isCompleted;
      }
    });
    _saveTasks();
  }

  void _addTask(String title, String category) {
    if (title.isEmpty) return;
    setState(() {
      _tasks.add(TaskItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
      ));
    });
    _saveTasks();
  }

  void _deleteTask(String id) {
    setState(() {
      _tasks.removeWhere((task) => task.id == id);
    });
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final totalCount = _tasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    List<TaskItem> filteredTasks = _tasks.where((task) {
      if (_activeFilter == 'Active') return !task.isCompleted;
      if (_activeFilter == 'Completed') return task.isCompleted;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'BUSINESS TASKS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16.0),
              // Dynamic Premium Progress Card
              _buildProgressCard(completedCount, totalCount, progress),
              const SizedBox(height: 24.0),
              // Filter Chips Row
              _buildFilterSection(),
              const SizedBox(height: 16.0),
              // Task Header Section
              const Text(
                'MY TASKS',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12.0),
              // Dynamic task list
              Expanded(
                child: filteredTasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return _buildTaskTile(task);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskSheet,
        backgroundColor: const Color(0xFFD30814),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28.0),
      ),
    );
  }

  Widget _buildProgressCard(int completed, int total, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F1F24),
            const Color(0xFF0F0F12),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20.0,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  total > 0
                      ? '$completed of $total tasks completed'
                      : 'No tasks added yet',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8.0,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
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
                width: 60.0,
                height: 60.0,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5.5,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Row(
      children: ['All', 'Active', 'Completed'].map((filter) {
        final isActive = _activeFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(
              filter,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white70,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            selected: isActive,
            selectedColor: const Color(0xFFFFD700),
            backgroundColor: const Color(0xFF1F1F24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: isActive ? const Color(0xFFFFD700) : const Color(0xFF2C2C2E),
                width: 1.0,
              ),
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _activeFilter = filter;
                });
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    Color categoryColor = const Color(0xFF00F2FE);
    switch (task.category) {
      case 'Marketing':
        categoryColor = const Color(0xFFE285FF);
        break;
      case 'Learning':
        categoryColor = const Color(0xFF38EF7D);
        break;
      case 'Personal':
        categoryColor = const Color(0xFFF2994A);
        break;
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFFD30814).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFD30814), size: 28.0),
      ),
      onDismissed: (_) {
        _deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFFFD700),
              onPressed: () {
                setState(() {
                  _tasks.add(task);
                });
                _saveTasks();
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.0),
          color: const Color(0xFF141416),
          border: Border.all(
            color: task.isCompleted
                ? Colors.white.withOpacity(0.03)
                : const Color(0xFF2C2C2E),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleTask(task.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24.0,
                height: 24.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted ? const Color(0xFFFFD700) : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted ? const Color(0xFFFFD700) : const Color(0xFF8E8E93),
                    width: 2.0,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 16.0)
                    : null,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: task.isCompleted ? const Color(0xFF636366) : Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      task.category.toUpperCase(),
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, color: Colors.white24, size: 64.0),
          const SizedBox(height: 16.0),
          const Text(
            'All Clean!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'Add some tasks to start your execution journey.',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet() {
    _taskController.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F11),
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24.0,
                left: 16.0,
                right: 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'NEW TASK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _taskController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter task description...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Wrap(
                    spacing: 8.0,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFFD700),
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                            width: 1.0,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () {
                      final title = _taskController.text.trim();
                      if (title.isNotEmpty) {
                        _addTask(title, _selectedCategory);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD30814),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                    child: const Text(
                      'ADD TASK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
