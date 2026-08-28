import 'package:flutter/material.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_access_code_screen.dart';
import 'assessment_login_screen.dart';

const List<Color> _catColors = [
  Color(0xFF006C49), Color(0xFF8B5CF6), Color(0xFFF59E0B), Color(0xFFEF4444),
  Color(0xFFEC4899), Color(0xFF0284C7), Color(0xFFF97316), Color(0xFF06B6D4),
];
Color _catColor(int i, int total) => total <= _catColors.length ? _catColors[i] : _catColors[i % _catColors.length];

/// Ported from app/frontend/user/result.html (bars only — no radar chart on
/// mobile, per the migration plan, to avoid adding a new charting
/// dependency to this app specifically).
class AssessmentResultScreen extends StatefulWidget {
  const AssessmentResultScreen({super.key});

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payload;
  bool _retestBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = await AssessmentSession.getToken();
    final res = await AssessmentService.instance.getResult(token!);
    if (!mounted) return;
    if (res.status == 404) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentAccessCodeScreen()));
      return;
    }
    if (!res.ok || res.data['data'] == null) {
      setState(() {
        _error = (res.data['message'] as String?) ?? "Couldn't load your results. Please check your connection.";
        _loading = false;
      });
      return;
    }
    setState(() {
      _payload = res.data;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final token = await AssessmentSession.getToken();
    if (token != null) await AssessmentService.instance.logout(token);
    await AssessmentSession.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AssessmentLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _requestRetest() async {
    setState(() => _retestBusy = true);
    final token = await AssessmentSession.getToken();
    final res = await AssessmentService.instance.requestRetest(token!);
    if (!mounted) return;
    setState(() => _retestBusy = false);
    if (!res.ok) {
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Could not send request.', isError: true);
      return;
    }
    showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Retest request sent for approval.');
    setState(() {
      _payload = {...?_payload, 'retest': {'status': 'pending', 'canRequest': false}};
    });
  }

  Future<void> _startRetest() async {
    final sessionId = await AssessmentSession.getSessionId();
    await AssessmentSession.clearSessionState();
    if (sessionId != null) await AssessmentSession.clearAutosave(sessionId);
    await AssessmentSession.clearAllAutosaves();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentAccessCodeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AssessmentScaffold(
      title: 'Your Results',
      actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      body: _loading
          ? const AssessmentLoading(message: 'Loading results...')
          : _error != null
              ? AssessmentErrorView(message: _error!, onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final r = Map<String, dynamic>.from(_payload!['data'] as Map);
    final categories = Map<String, dynamic>.from(r['categoryPercentages'] as Map? ?? {}).entries.toList();
    final dimensions = Map<String, dynamic>.from(r['dimensionPercentages'] as Map? ?? {}).entries.toList();
    final composites = <MapEntry<String, num>>[
      if (r['aptitudeScore'] != null) MapEntry('Aptitude', r['aptitudeScore'] as num),
      if (r['personalityScore'] != null) MapEntry('Personality', r['personalityScore'] as num),
      if (r['businessMindsetScore'] != null) MapEntry('Business Mindset', r['businessMindsetScore'] as num),
      if (r['financialAwarenessScore'] != null) MapEntry('Financial Awareness', r['financialAwarenessScore'] as num),
    ];
    final recommendations = (r['recommendations'] as List?)?.cast<Map>() ??
        ((r['recommendedBusiness'] as List?) ?? const []).map((b) => {'business': b, 'explanation': ''}).toList();
    final strong = (r['strongDimensions'] as List?)?.cast<String>() ?? const [];
    final weak = (r['weakDimensions'] as List?)?.cast<String>() ?? const [];
    final improvements = (r['improvementAreas'] as List?)?.cast<Map>() ?? const [];
    final history = (_payload!['history'] as List?)?.cast<Map>() ?? const [];
    final retest = _payload!['retest'] as Map?;
    final attemptNumber = _payload!['attemptNumber'];
    final userInfo = r['userId'] as Map?;
    final testLabel = (userInfo?['sharedUserID'] as Map?)?['label'] as String? ?? 'Your Assessment';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('✅ Assessment Completed Successfully', style: TextStyle(color: Color(0xFF006C49), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('$testLabel Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textColor)),
              if (attemptNumber != null) ...[
                const SizedBox(height: 6),
                Chip(label: Text('Attempt $attemptNumber'), backgroundColor: const Color(0xFF006C49).withValues(alpha: 0.12)),
              ],
              const SizedBox(height: 6),
              Text('${userInfo?['name'] ?? ''} — ${userInfo?['sharedCode'] ?? ''}', style: TextStyle(color: context.subTextColor)),
              const SizedBox(height: 16),
              _ScoreGauge(percentage: (r['percentage'] as num).toDouble()),
              const SizedBox(height: 8),
              Text('$testLabel Score', style: TextStyle(fontSize: 11, color: context.subTextColor)),
              Text('Total: ${r['totalMarks']} / ${r['maxScore']}', style: TextStyle(fontWeight: FontWeight.w600, color: context.textColor)),
              const SizedBox(height: 8),
              Chip(label: Text(r['level'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              if ((r['explanation'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(r['explanation'] as String, textAlign: TextAlign.center, style: TextStyle(color: context.subTextColor)),
              ],
              if (r['correctCount'] != null || r['wrongCount'] != null || r['skippedCount'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip('${r['correctCount'] ?? 0}', 'Correct', const Color(0xFF006C49)),
                    _StatChip('${r['wrongCount'] ?? 0}', 'Wrong', const Color(0xFFCB1417)),
                    _StatChip('${r['skippedCount'] ?? 0}', 'Skipped', context.subTextColor),
                  ],
                ),
              ],
            ],
          )),
          if (composites.isNotEmpty)
            _Card(child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: composites.map((c) => SizedBox(
                width: 140,
                child: Column(children: [
                  Text('${c.value}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF006C49))),
                  Text(c.key, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: context.subTextColor)),
                ]),
              )).toList(),
            )),
          if (categories.isNotEmpty)
            _Card(child: _BarSection(title: 'Category Breakdown', entries: categories)),
          if (dimensions.isNotEmpty)
            _Card(child: _BarSection(title: 'Dimension Breakdown', entries: dimensions)),
          if (strong.isNotEmpty || weak.isNotEmpty)
            _Card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (strong.isNotEmpty) ...[
                  const Text('Strong Dimensions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006C49))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: strong.map((d) => Chip(
                    label: Text(d, style: const TextStyle(color: Color(0xFF065F46))),
                    backgroundColor: const Color(0xFFD1FAE5),
                  )).toList()),
                  const SizedBox(height: 14),
                ],
                if (weak.isNotEmpty) ...[
                  const Text('Weak Dimensions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB1417))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: weak.map((d) => Chip(
                    label: Text(d, style: const TextStyle(color: Color(0xFF991B1B))),
                    backgroundColor: const Color(0xFFFEE2E2),
                  )).toList()),
                ],
              ],
            )),
          if (recommendations.isNotEmpty)
            _Card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top Business Recommendations', style: TextStyle(fontWeight: FontWeight.bold, color: context.textColor)),
                const SizedBox(height: 10),
                ...recommendations.map((rec) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006C49).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${rec['business']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006C49))),
                      if ((rec['explanation'] as String?)?.isNotEmpty == true)
                        Text(rec['explanation'] as String, style: TextStyle(fontSize: 12, color: context.subTextColor)),
                    ],
                  ),
                )),
              ],
            )),
          if (improvements.isNotEmpty)
            _Card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Areas to Strengthen', style: TextStyle(fontWeight: FontWeight.bold, color: context.textColor)),
                const SizedBox(height: 10),
                ...improvements.map((area) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${area['category']} (${area['score']}%)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                      Text('${area['suggestion']}', style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                    ],
                  ),
                )),
              ],
            )),
          if (history.length > 1)
            _Card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Previous Attempts', style: TextStyle(fontWeight: FontWeight.bold, color: context.textColor)),
                const SizedBox(height: 8),
                ...history.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('Attempt ${h['attemptNumber'] ?? 1}', style: TextStyle(color: context.textColor))),
                      Text('${h['percentage']}%', style: TextStyle(fontWeight: FontWeight.bold, color: context.textColor)),
                      const SizedBox(width: 8),
                      Text('${h['level'] ?? ''}', style: TextStyle(fontSize: 11, color: context.subTextColor)),
                    ],
                  ),
                )),
              ],
            )),
          if (retest != null && (retest['status'] == 'pending' || retest['status'] == 'approved' || retest['canRequest'] == true))
            _Card(child: Column(
              children: [
                Text('Need to Retake?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textColor)),
                const SizedBox(height: 4),
                Text('If you wish to retake this assessment, you can request approval from the administrator.',
                    textAlign: TextAlign.center, style: TextStyle(color: context.subTextColor, fontSize: 12)),
                const SizedBox(height: 10),
                if (retest['status'] == 'pending')
                  const Text('⏳ Waiting for admin approval.', style: TextStyle(fontWeight: FontWeight.w600)),
                if (retest['status'] == 'approved')
                  const Text('✅ Retest approved. You can start now.', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF006C49))),
                if (retest['status'] == 'rejected' && retest['canRequest'] == true)
                  Text('❌ Your previous retest request was rejected${retest['rejectionNote'] != null ? ': ${retest['rejectionNote']}' : '.'}',
                      textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFCB1417))),
                const SizedBox(height: 12),
                if (retest['status'] == 'approved')
                  AssessmentPrimaryButton(label: 'Start Retest', onPressed: _startRetest)
                else if (retest['canRequest'] == true)
                  AssessmentPrimaryButton(
                    label: retest['status'] == 'rejected' ? 'Request Again' : 'Request Retest',
                    loading: _retestBusy,
                    onPressed: _requestRetest,
                  ),
              ],
            )),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
      ),
      child: child,
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  final double percentage;
  const _ScoreGauge({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 10,
              backgroundColor: context.borderCol,
              color: const Color(0xFF006C49),
            ),
          ),
          Text('${percentage.round()}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textColor)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatChip(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: context.subTextColor)),
    ]);
  }
}

class _BarSection extends StatelessWidget {
  final String title;
  final List<MapEntry<String, dynamic>> entries;
  const _BarSection({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: context.textColor)),
        const SizedBox(height: 12),
        ...entries.asMap().entries.map((e) {
          final i = e.key;
          final name = e.value.key;
          final pct = (e.value.value as num).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: TextStyle(fontSize: 13, color: context.textColor)),
                    Text('${pct.round()}%', style: TextStyle(fontSize: 12, color: context.subTextColor)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: context.borderCol,
                    color: _catColor(i, entries.length),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
