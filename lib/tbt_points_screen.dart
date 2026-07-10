import 'package:flutter/material.dart';
import 'main.dart';
import 'tbt_points_service.dart';

const Color _kTbtRed = Color(0xFFD30814);
const Color _kTbtGold = Color(0xFFFFD97D);
const Color _kTbtGreen = Color(0xFF27AE60);

/// Native TBT Points page: a vertical educational learning path with curved
/// connectors and alternating left/right task nodes (locked/current/
/// completed), backed entirely by TbtPointsService — task list, thresholds,
/// and progress are never hardcoded sample data. Original TBT branding only.
class TbtPointsScreen extends StatefulWidget {
  const TbtPointsScreen({super.key});

  @override
  State<TbtPointsScreen> createState() => _TbtPointsScreenState();
}

class _TbtPointsScreenState extends State<TbtPointsScreen> {
  bool _loading = true;
  bool _hasError = false;
  TbtTaskPath _path = const TbtTaskPath(totalPoints: 0, dailyStreak: 0, currentLevel: 1, tasks: []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final path = await TbtPointsService.instance.fetchTaskPath();
      if (!mounted) return;
      setState(() {
        _path = path;
        _loading = false;
        _hasError = path.tasks.isEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  void _openTaskDetails(TbtTask task) {
    if (task.isLocked) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (sheetContext) => _TaskDetailsSheet(
        task: task,
        onCompleted: () {
          Navigator.pop(sheetContext);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = context.textColor;

    return Scaffold(
      body: GlassmorphicBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20.0),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'TBT POINTS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48.0),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: _kTbtRed,
                  child: _loading ? _buildLoading() : _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 220.0),
        Center(child: CircularProgressIndicator(color: _kTbtRed)),
      ],
    );
  }

  Widget _buildBody() {
    final textColor = context.textColor;
    final subTextColor = context.subTextColor;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 32.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24.0),
              Text(
                'Your Learning Path',
                style: TextStyle(color: textColor, fontSize: 15.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Complete each task in order to earn points and unlock the next.',
                style: TextStyle(color: subTextColor, fontSize: 12.0, height: 1.4),
              ),
              const SizedBox(height: 12.0),
              if (_hasError) _buildEmptyState() else _buildPath(_path.tasks),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final textColor = context.textColor;
    final subTextColor = context.subTextColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        children: [
          Icon(Icons.route_outlined, color: subTextColor, size: 40.0),
          const SizedBox(height: 12.0),
          Text(
            'No tasks available right now',
            style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Pull down to refresh, or check back later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 12.0),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 22.0),
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
                    Text(
                      'TOTAL TBT POINTS',
                      style: TextStyle(
                        color: context.subTextColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      _path.totalPoints.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 30.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: _kTbtGold, size: 15.0),
                        const SizedBox(width: 4.0),
                        Text(
                          '${_path.totalStars} Stars',
                          style: const TextStyle(color: _kTbtGold, fontSize: 12.0, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 56.0,
                height: 56.0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_kTbtGold, _kTbtRed]),
                ),
                child: Center(
                  child: Text(
                    'L${_path.currentLevel}',
                    style: const TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              const Icon(Icons.whatshot_rounded, color: Color(0xFFFF5E3A), size: 16.0),
              const SizedBox(width: 4.0),
              Text(
                '${_path.dailyStreak} Day Streak',
                style: const TextStyle(color: Color(0xFFFF5E3A), fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16.0),
              Icon(Icons.task_alt_rounded, color: context.subTextColor, size: 15.0),
              const SizedBox(width: 4.0),
              Text(
                '${_path.totalStars} / ${_path.tasks.length} Tasks Done',
                style: TextStyle(color: context.subTextColor, fontSize: 12.0, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 7.0,
                    color: context.isDark ? Colors.black26 : Colors.grey.shade200,
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * (_path.progressPercent / 100.0),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_kTbtGold, _kTbtRed]),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Text(
                '${_path.progressPercent}%',
                style: TextStyle(color: context.textColor, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPath(List<TbtTask> tasks) {
    if (tasks.isEmpty) return _buildEmptyState();

    const rowHeight = 176.0;
    const leftFrac = 0.24;
    const rightFrac = 0.76;
    final totalHeight = tasks.length * rowHeight;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TaskPathPainter(
                statuses: tasks.map((t) => t.status).toList(),
                rowHeight: rowHeight,
                leftFrac: leftFrac,
                rightFrac: rightFrac,
                isDark: context.isDark,
                borderColor: context.borderCol,
              ),
            ),
          ),
          ...List.generate(tasks.length, (i) {
            final task = tasks[i];
            final isLeftNode = i.isEven;
            return Positioned(
              top: i * rowHeight,
              left: 0,
              right: 0,
              height: rowHeight,
              child: _TaskNodeRow(
                task: task,
                isLeftNode: isLeftNode,
                nodeFrac: isLeftNode ? leftFrac : rightFrac,
                onTap: task.isLocked ? null : () => _openTaskDetails(task),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TaskPathPainter extends CustomPainter {
  final List<String> statuses; // per-task 'locked' | 'current' | 'completed'
  final double rowHeight;
  final double leftFrac;
  final double rightFrac;
  final bool isDark;
  final Color borderColor;

  _TaskPathPainter({
    required this.statuses,
    required this.rowHeight,
    required this.leftFrac,
    required this.rightFrac,
    required this.isDark,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (statuses.length < 2) return;
    final w = size.width;

    Offset centerFor(int i) {
      final frac = i.isEven ? leftFrac : rightFrac;
      return Offset(frac * w, i * rowHeight + rowHeight / 2);
    }

    for (var i = 1; i < statuses.length; i++) {
      final from = centerFor(i - 1);
      final to = centerFor(i);

      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(
          (from.dx + to.dx) / 2,
          (from.dy + to.dy) / 2,
          to.dx,
          to.dy,
        );

      // Segment is "reached" once the task it leads into isn't locked.
      final reached = statuses[i] != 'locked';
      final paint = Paint()
        ..color = reached ? _kTbtRed.withOpacity(0.85) : borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      _drawDashed(canvas, path, paint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 7.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = (dashLength).clamp(0.0, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TaskPathPainter oldDelegate) {
    return oldDelegate.statuses.join() != statuses.join() || oldDelegate.isDark != isDark;
  }
}

class _TaskNodeRow extends StatelessWidget {
  final TbtTask task;
  final bool isLeftNode;
  final double nodeFrac;
  final VoidCallback? onTap;

  const _TaskNodeRow({
    required this.task,
    required this.isLeftNode,
    required this.nodeFrac,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 'completed';
    final isCurrent = task.status == 'current';
    final isLocked = task.status == 'locked';

    final Gradient nodeGradient = isLocked
        ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600])
        : (isCompleted
            ? const LinearGradient(colors: [_kTbtGreen, Color(0xFF2E9B5E)])
            : const LinearGradient(colors: [_kTbtGold, _kTbtRed]));

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const nodeSize = 52.0;
      final nodeX = (nodeFrac * width).clamp(nodeSize / 2 + 8.0, width - nodeSize / 2 - 8.0);

      return Stack(
        children: [
          Positioned(
            left: nodeX - nodeSize / 2,
            top: (176.0 - nodeSize) / 2,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: nodeGradient,
                  border: Border.all(
                    color: isCurrent ? _kTbtRed : Colors.white,
                    width: isCurrent ? 3.0 : 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6.0, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: isLocked
                      ? const Icon(Icons.lock_rounded, color: Colors.white, size: 20.0)
                      : (isCompleted
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 24.0)
                          : Text(
                              '${task.order}',
                              style: const TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
                            )),
                ),
              ),
            ),
          ),
          Positioned(
            top: 18.0,
            bottom: 18.0,
            left: isLeftNode ? nodeX + nodeSize / 2 + 14.0 : 12.0,
            right: isLeftNode ? 12.0 : width - (nodeX - nodeSize / 2 - 14.0),
            child: GestureDetector(
              onTap: onTap,
              child: Opacity(
                opacity: isLocked ? 0.55 : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: isCurrent ? _kTbtRed : context.borderCol,
                      width: isCurrent ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        children: [
                          Icon(Icons.stars_rounded,
                              size: 12.0, color: isLocked ? context.subTextColor : _kTbtGold),
                          const SizedBox(width: 3.0),
                          Text(
                            '+${task.rewardPoints}',
                            style: TextStyle(
                              color: isLocked ? context.subTextColor : context.textColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isCompleted ? 'DONE' : (isCurrent ? 'START' : 'LOCKED'),
                            style: TextStyle(
                              color: isCompleted
                                  ? _kTbtGreen
                                  : (isCurrent ? _kTbtRed : context.subTextColor),
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
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
        ],
      );
    });
  }
}

class _TaskDetailsSheet extends StatefulWidget {
  final TbtTask task;
  final VoidCallback onCompleted;

  const _TaskDetailsSheet({required this.task, required this.onCompleted});

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  bool _submitting = false;

  Future<void> _complete() async {
    setState(() => _submitting = true);
    final ok = await TbtPointsService.instance
        .completeTask(taskId: widget.task.id, rewardPoints: widget.task.rewardPoints);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      widget.onCompleted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete this task. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final textColor = context.textColor;
    final subTextColor = context.subTextColor;
    final isCompleted = task.status == 'completed';
    final isCurrent = task.status == 'current';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: context.borderCol,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: (isCompleted ? _kTbtGreen : _kTbtRed).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      'TASK ${task.order}',
                      style: TextStyle(
                        color: isCompleted ? _kTbtGreen : _kTbtRed,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.stars_rounded, color: _kTbtGold, size: 16.0),
                  const SizedBox(width: 4.0),
                  Text(
                    '+${task.rewardPoints} pts',
                    style: TextStyle(color: textColor, fontSize: 13.0, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              Text(
                task.title,
                style: TextStyle(color: textColor, fontSize: 19.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10.0),
              Text(
                task.description,
                style: TextStyle(color: subTextColor, fontSize: 13.0, height: 1.45),
              ),
              if (task.requiredAction.isNotEmpty) ...[
                const SizedBox(height: 16.0),
                Text(
                  'REQUIRED ACTION',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  task.requiredAction,
                  style: TextStyle(color: textColor, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24.0),
              if (isCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  decoration: BoxDecoration(
                    color: _kTbtGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: _kTbtGreen, size: 18.0),
                      const SizedBox(width: 8.0),
                      Text(
                        task.completedAt != null
                            ? 'Completed on ${task.completedAt!.toLocal().toString().split(' ').first}'
                            : 'Completed',
                        style: const TextStyle(color: _kTbtGreen, fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else if (isCurrent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _complete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTbtRed,
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20.0,
                            height: 20.0,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Complete Task',
                            style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
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
