import 'package:flutter/material.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_instructions_screen.dart';
import 'assessment_result_screen.dart';
import 'assessment_login_screen.dart';

/// Ported from app/frontend/user/index.html — step 2 of the flow
/// (Login -> Access Code -> Question Set). A candidate who already
/// completed the assessment is sent to the result screen, UNLESS an admin
/// has approved a retest.
class AssessmentAccessCodeScreen extends StatefulWidget {
  const AssessmentAccessCodeScreen({super.key});

  @override
  State<AssessmentAccessCodeScreen> createState() => _AssessmentAccessCodeScreenState();
}

class _AssessmentAccessCodeScreenState extends State<AssessmentAccessCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _checking = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAlreadyCompleted();
  }

  Future<void> _checkAlreadyCompleted() async {
    final user = await AssessmentSession.getUser();
    final token = await AssessmentSession.getToken();
    if (token != null && user?['hasCompletedAssessment'] == true) {
      final res = await AssessmentService.instance.getMyRetest(token);
      if (!mounted) return;
      final retest = res.data['retest'] as Map<String, dynamic>?;
      final approved = res.ok && retest?['status'] == 'approved';
      if (!approved) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentResultScreen()));
        return;
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Access code is required.');
      return;
    }
    setState(() => _submitting = true);
    final token = await AssessmentSession.getToken();
    final res = await AssessmentService.instance.selectCode(code, token!);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.ok) {
      setState(() => _error = (res.data['message'] as String?) ?? 'Invalid code.');
      return;
    }
    await AssessmentSession.setCode(res.data['codeId'] as String, res.data['code'] as String? ?? code);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssessmentInstructionsScreen()));
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
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return AssessmentScaffold(
      title: 'Access Code',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('Welcome', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Enter your access code to get started', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              AssessmentTextField(
                controller: _codeCtrl,
                label: 'Access Code',
                hint: 'e.g. TBT2024',
                errorText: _error,
                maxLength: 20,
                onChanged: (v) {
                  final upper = v.toUpperCase();
                  if (upper != v) {
                    _codeCtrl.value = _codeCtrl.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              AssessmentPrimaryButton(label: 'Continue', onPressed: _submit, loading: _submitting),
              const SizedBox(height: 12),
              Center(
                child: TextButton(onPressed: _logout, child: const Text('Not you? Logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
