import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

const _dialCodes = ['+251', '+291', '+254', '+255', '+256', '+249', '+234', '+27'];

/// Two steps, because the code only exists after the server has confirmed the number
/// belongs to an account.
enum _Stage { askPhone, askCode }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  _Stage _stage = _Stage.askPhone;
  String _dialCode = _dialCodes.first;
  String? _devCode;
  bool _busy = false;

  String get _fullPhone => '$_dialCode${_phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')}';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _show(String message, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppTheme.onlineColor : AppTheme.errorColor));
  }

  Future<void> _sendCode() async {
    if (_phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').length < 7) {
      _show('Enter the phone number on your account');
      return;
    }
    final challenge = await _call(
        () => ApiClient().dio.post('/auth/password-reset/send',
            data: {'phone': _fullPhone}),
        'Could not send a code');
    if (challenge == null) return;

    setState(() {
      _stage = _Stage.askCode;
      _devCode = challenge['devCode'] as String?;
    });
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      _show('Enter the code from the SMS');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      _show('The new password needs at least 8 characters');
      return;
    }
    final sent = await _call(
        () => ApiClient().dio.post('/auth/password-reset/confirm', data: {
              'phone': _fullPhone,
              'code': code,
              'newPassword': _passwordCtrl.text,
            }),
        'That code did not work');
    if (sent == null) return;

    if (!mounted) return;
    _show('Password updated. Sign in with the new one.', ok: true);
    context.pop();
  }

  /// Returns the response payload, or null after showing the server's own reason.
  Future<Map<String, dynamic>?> _call(
      Future<Response> Function() request, String fallback) async {
    setState(() => _busy = true);
    try {
      final res = await request();
      if (!mounted) return null;
      final data = res.data['data'];
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      if (!mounted) return null;
      _show(_errorOf(e, fallback));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _errorOf(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError) return 'Cannot reach the RideEt server';
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final askCode = _stage == _Stage.askCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                askCode
                    ? 'Enter the code we sent to $_fullPhone and choose a new password.'
                    : 'We send a one-time code to the phone number on your driver account.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              if (_devCode != null && askCode) ...[
                const SizedBox(height: 12),
                Text(
                  'Dev mode: no SMS is sent. Use code $_devCode.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24),
              if (!askCode)
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Registered Phone Number',
                    hintText: '911000001',
                    prefixIcon: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _dialCode,
                        items: _dialCodes
                            .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                            .toList(),
                        onChanged: (code) {
                          if (code != null) setState(() => _dialCode = code);
                        },
                      ),
                    ),
                  ),
                )
              else ...[
                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Code', prefixIcon: Icon(Icons.sms_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'New password', prefixIcon: Icon(Icons.lock_outline)),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _busy ? null : (askCode ? _confirm : _sendCode),
                child: _busy
                    ? const SizedBox(
                        height: 20, width: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(askCode ? 'Set new password' : 'Send code'),
              ),
              if (askCode) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _stage = _Stage.askPhone;
                            _devCode = null;
                            _codeCtrl.clear();
                          }),
                  child: const Text('Use a different number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
