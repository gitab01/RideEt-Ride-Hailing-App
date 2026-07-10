import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otp = '';
  bool _loading = false;

  void _verify() async {
    if (_otp.length != 6) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    // TODO: call OTP verify API
    setState(() => _loading = false);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('Enter OTP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('We sent a 6-digit code to ${widget.phone}',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 40),
            PinCodeTextField(
              appContext: context,
              length: 6,
              onChanged: (val) => _otp = val,
              onCompleted: (val) {
                _otp = val;
                _verify();
              },
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 56,
                fieldWidth: 48,
                activeFillColor: Colors.white,
                selectedFillColor: Colors.white,
                inactiveFillColor: Colors.white,
                activeColor: AppTheme.primaryColor,
                selectedColor: AppTheme.primaryColor,
                inactiveColor: Colors.grey.shade300,
              ),
              enableActiveFill: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify'),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: resend OTP
                },
                child: const Text("Didn't receive code? Resend"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
