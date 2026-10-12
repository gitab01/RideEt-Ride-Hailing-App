import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../bloc/auth_bloc.dart';
import '../../../core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otp = '';
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    // The challenge in the bloc carries the real expiry; fall back only if we were opened
    // without one (a cold restart on this route, which the back button does not do).
    final state = context.read<AuthBloc>().state;
    _startCountdown(state is AuthOtpSent ? state.expiresInSeconds : 300);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) => setState(() => _secondsLeft = seconds);

  void _verify() {
    if (_otp.length != 6) return;
    context.read<AuthBloc>().add(AuthOtpVerifyRequested(widget.phone, _otp));
  }

  void _resend() {
    context.read<AuthBloc>().add(AuthOtpSendRequested(widget.phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/home');
          } else if (state is AuthOtpSent) {
            _startCountdown(state.expiresInSeconds);
            _otp = '';
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor),
            );
          }
        },
        builder: (context, state) {
          final busy = state is AuthLoading;
          // The code is only ever exposed by the dev profile, where no SMS gateway exists.
          final devCode = state is AuthOtpSent ? state.devCode : null;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text('Enter the code',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('We sent a 6-digit code to ${widget.phone}',
                      style: TextStyle(color: Colors.grey.shade600)),
                  if (devCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dev mode: no SMS is sent. Use code $devCode.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 16),
                  Text(
                    _secondsLeft > 0
                        ? 'Code expires in ${_secondsLeft}s'
                        : 'This code has expired — send a new one',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: busy || _otp.length != 6 ? null : _verify,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Verify'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: busy ? null : _resend,
                      child: const Text("Didn't receive code? Resend"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
