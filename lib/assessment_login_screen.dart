import 'package:flutter/material.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_register_screen.dart';
import 'assessment_access_code_screen.dart';
import 'assessment_result_screen.dart';

/// Entry point of the Business Assessment flow (mirrors the web port's
/// LoginPage / the original app/frontend/index.html): Login -> Access Code
/// -> Question Set. An already-authenticated candidate is bounced past this
/// screen only after the cached token is confirmed valid server-side.
class AssessmentLoginScreen extends StatefulWidget {
  const AssessmentLoginScreen({super.key});

  @override
  State<AssessmentLoginScreen> createState() => _AssessmentLoginScreenState();
}

class _AssessmentLoginScreenState extends State<AssessmentLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _checkingSession = true;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final token = await AssessmentSession.getToken();
    if (token == null) {
      if (mounted) setState(() => _checkingSession = false);
      return;
    }
    final res = await AssessmentService.instance.getSettings(token);
    if (!mounted) return;
    if (res.ok) {
      final user = await AssessmentSession.getUser();
      if (!mounted) return;
      _goToNextScreen(user);
      return;
    }
    await AssessmentSession.clearSession();
    if (!mounted) return;
    setState(() => _checkingSession = false);
  }

  void _goToNextScreen(Map<String, dynamic>? user) {
    final completed = user?['hasCompletedAssessment'] == true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => completed ? const AssessmentResultScreen() : const AssessmentAccessCodeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

  Future<void> _submit() async {
    setState(() {
      _emailError = _isValidEmail(_emailCtrl.text.trim()) ? null : 'Valid email required.';
      _passwordError = _passwordCtrl.text.trim().isEmpty ? 'Password required.' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    final res = await AssessmentService.instance.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.ok) {
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Login failed.', isError: true);
      return;
    }
    await AssessmentSession.setToken(res.data['token'] as String);
    final user = res.data['user'] as Map<String, dynamic>;
    await AssessmentSession.setUser(user);
    // Every login starts a fresh Access Code step (the server also resets
    // the gate), so clear any stale code state before routing there.
    await AssessmentSession.clearCode();
    if (!mounted) return;
    _goToNextScreen(user);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return AssessmentScaffold(
      title: 'Business Assessment',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.psychology_alt_rounded, size: 56, color: Color(0xFFE50914)),
              const SizedBox(height: 12),
              Text(
                'Sign In',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color),
              ),
              const SizedBox(height: 4),
              const Text('Certified Psychometric Assessment', textAlign: TextAlign.center),
              const SizedBox(height: 28),
              AssessmentTextField(
                controller: _emailCtrl,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const SizedBox(height: 14),
              AssessmentTextField(
                controller: _passwordCtrl,
                label: 'Password',
                obscure: _obscure,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 20),
              AssessmentPrimaryButton(label: 'Sign In', onPressed: _submit, loading: _submitting),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AssessmentRegisterScreen()),
                  ),
                  child: const Text("Don't have an account? Register"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
