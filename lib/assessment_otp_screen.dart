import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'assessment_service.dart';
import 'assessment_session.dart';
import 'assessment_widgets.dart';
import 'assessment_access_code_screen.dart';

/// Ported from app/frontend/user/otp-register.html.
class AssessmentOtpScreen extends StatefulWidget {
  const AssessmentOtpScreen({super.key});

  @override
  State<AssessmentOtpScreen> createState() => _AssessmentOtpScreenState();
}

class _AssessmentOtpScreenState extends State<AssessmentOtpScreen> {
  final List<TextEditingController> _digitCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _email;
  bool _loadingEmail = true;
  bool _submitting = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final email = await AssessmentSession.getPendingEmail();
    if (!mounted) return;
    if (email == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _email = email;
      _loadingEmail = false;
    });
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _digitCtrls) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _digitCtrls.map((c) => c.text).join();

  Future<void> _submit() async {
    final otp = _otp;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      showAssessmentSnack(context, 'Enter all 6 digits.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final res = await AssessmentService.instance.verifyOtp(_email!, otp);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!res.ok) {
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Invalid OTP.', isError: true);
      return;
    }
    await AssessmentSession.setToken(res.data['token'] as String);
    await AssessmentSession.setUser(res.data['user'] as Map<String, dynamic>);
    await AssessmentSession.clearPendingEmail();
    // Verification logs the user in, but the Access Code step still gates
    // the assessment (Register -> Verify -> Access Code -> Question Set).
    await AssessmentSession.clearCode();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentAccessCodeScreen()));
  }

  Future<void> _resend() async {
    final res = await AssessmentService.instance.resendOtp(_email!);
    if (!mounted) return;
    if (!res.ok) {
      showAssessmentSnack(context, (res.data['message'] as String?) ?? 'Failed to resend.', isError: true);
      return;
    }
    showAssessmentSnack(context, 'New OTP sent!');
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEmail) {
      return const AssessmentScaffold(title: 'Verify Email', body: AssessmentLoading());
    }
    return AssessmentScaffold(
      title: 'Verify Your Email',
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.mark_email_read_rounded, size: 48, color: Color(0xFFE50914)),
              const SizedBox(height: 12),
              const Text('We sent a 6-digit code to'),
              const SizedBox(height: 4),
              Text(_email ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE50914))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 44,
                    height: 54,
                    child: TextField(
                      controller: _digitCtrls[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                        if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              AssessmentPrimaryButton(label: 'Verify OTP', onPressed: _submit, loading: _submitting),
              const SizedBox(height: 12),
              _resendSeconds > 0
                  ? Text('Resend in ${_resendSeconds}s')
                  : TextButton(onPressed: _resend, child: const Text('Resend OTP')),
            ],
          ),
        ),
      ),
    );
  }
}
