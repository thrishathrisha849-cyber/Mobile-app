import 'package:flutter/material.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_otp_screen.dart';

/// Ported from app/frontend/user/register.html — self-collects the access
/// code (validated via the public /user/validate-code) rather than
/// depending on the access-code page being visited first.
class AssessmentRegisterScreen extends StatefulWidget {
  const AssessmentRegisterScreen({super.key});

  @override
  State<AssessmentRegisterScreen> createState() => _AssessmentRegisterScreenState();
}

class _AssessmentRegisterScreenState extends State<AssessmentRegisterScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _codeError;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

  Future<void> _submit() async {
    setState(() {
      _codeError = _codeCtrl.text.trim().isEmpty ? 'Access code is required.' : null;
      _nameError = _nameCtrl.text.trim().isEmpty ? 'Name is required.' : null;
      _emailError = _isValidEmail(_emailCtrl.text.trim()) ? null : 'Valid email required.';
      _passwordError = _passwordCtrl.text.length < 6 ? 'Password must be at least 6 characters.' : null;
    });
    if ([_codeError, _nameError, _emailError, _passwordError].any((e) => e != null)) return;

    setState(() => _submitting = true);
    final code = _codeCtrl.text.trim();
    final codeRes = await AssessmentService.instance.validateCode(code);
    if (!mounted) return;
    if (!codeRes.ok) {
      setState(() {
        _submitting = false;
        _codeError = (codeRes.data['message'] as String?) ?? 'Invalid access code.';
      });
      return;
    }
    final res = await AssessmentService.instance.register(
      codeId: codeRes.data['codeId'] as String,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.ok) {
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Registration failed.', isError: true);
      return;
    }
    await AssessmentSession.setPendingEmail(_emailCtrl.text.trim());
    if (!mounted) return;
    showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Registered! Check your email for the OTP.');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentOtpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AssessmentScaffold(
      title: 'Create Account',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Register to take your psychometric assessment'),
              const SizedBox(height: 20),
              AssessmentTextField(
                controller: _codeCtrl,
                label: 'Access Code',
                hint: 'e.g. TBT2024',
                errorText: _codeError,
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
              const SizedBox(height: 14),
              AssessmentTextField(controller: _nameCtrl, label: 'Full Name', errorText: _nameError),
              const SizedBox(height: 14),
              AssessmentTextField(
                controller: _emailCtrl,
                label: 'Email Address',
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const SizedBox(height: 14),
              AssessmentTextField(
                controller: _passwordCtrl,
                label: 'Password (min 6 characters)',
                obscure: _obscure,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 20),
              AssessmentPrimaryButton(label: 'Register', onPressed: _submit, loading: _submitting),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Already registered? Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
