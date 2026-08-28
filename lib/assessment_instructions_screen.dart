import 'package:flutter/material.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_screen.dart';
import 'assessment_access_code_screen.dart';
import 'assessment_login_screen.dart';

/// Ported from app/frontend/user/welcome.html. Requires the Access Code
/// step to be completed this login — mirrors api.requireCode() guarding the
/// original page.
class AssessmentInstructionsScreen extends StatefulWidget {
  const AssessmentInstructionsScreen({super.key});

  @override
  State<AssessmentInstructionsScreen> createState() => _AssessmentInstructionsScreenState();
}

class _AssessmentInstructionsScreenState extends State<AssessmentInstructionsScreen> {
  String _durationText = '30-minute time limit — complete in one sitting';
  bool _starting = false;
  bool _checkingGate = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _guardAndLoad();
  }

  Future<void> _guardAndLoad() async {
    final hasCode = await AssessmentSession.hasCode();
    if (!hasCode) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentAccessCodeScreen()));
      return;
    }
    _user = await AssessmentSession.getUser();
    final token = await AssessmentSession.getToken();
    if (token != null) {
      final res = await AssessmentService.instance.getSettings(token);
      dynamic minutes;
      final settingsData = res.data['data'];
      if (res.ok && settingsData is Map) minutes = settingsData['assessment_duration_minutes'];
      if (minutes != null) {
        _durationText = '$minutes-minute time limit — complete in one sitting';
      }
    }
    if (mounted) setState(() => _checkingGate = false);
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final token = await AssessmentSession.getToken();
    final res = await AssessmentService.instance.startSession(token!);
    if (!mounted) return;
    if (!res.ok && res.data['code'] == 'CODE_REQUIRED') {
      await AssessmentSession.clearCode();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentAccessCodeScreen()));
      return;
    }
    if (!res.ok && res.data['sessionId'] == null) {
      setState(() => _starting = false);
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Failed to start.', isError: true);
      return;
    }
    // A 409 "already in progress" response still carries the existing
    // session's id/expiry — resume it instead of leaving nothing to find.
    await AssessmentSession.setSession(res.data['sessionId'] as String, res.data['expiresAt'] as String);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssessmentScreen()));
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

  @override
  Widget build(BuildContext context) {
    if (_checkingGate) {
      return const AssessmentScaffold(title: 'Instructions', body: AssessmentLoading());
    }
    final name = _user?['name'] as String?;
    return AssessmentScaffold(
      title: 'Get Ready',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(child: Text('🎯', style: TextStyle(fontSize: 48))),
              const SizedBox(height: 12),
              Text(
                'Ready to Discover Your Potential?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                name != null ? 'Welcome, $name! Take a moment to understand your strengths.' : 'Welcome! Take a moment to understand your strengths.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Before you begin:', style: TextStyle(fontWeight: FontWeight.bold, color: context.textColor)),
                    const SizedBox(height: 8),
                    const _InstructionLine('✅', 'A short set of questions across several psychometric categories'),
                    _InstructionLine('⏱️', _durationText),
                    const _InstructionLine('🔒', 'One attempt only — answers cannot be changed after submission'),
                    const _InstructionLine('💡', 'Answer honestly — there are no right or wrong answers'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AssessmentPrimaryButton(label: 'Start Assessment', onPressed: _start, loading: _starting),
              const SizedBox(height: 12),
              AssessmentOutlineButton(label: 'Logout', onPressed: _logout),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  final String emoji;
  final String text;
  const _InstructionLine(this.emoji, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: context.textColor))),
        ],
      ),
    );
  }
}
