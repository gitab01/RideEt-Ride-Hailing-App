import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/driver_auth_bloc.dart';
import 'driver_register_form.dart';
import '../../../core/theme/app_theme.dart';

/// The numbers RideEt drivers register with. Ethiopia first, then the neighbouring
/// markets the app is opened in.
const _dialCodes = ['+251', '+291', '+254', '+255', '+256', '+249', '+234', '+27'];

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _dialCode = _dialCodes.first;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _fullPhone => '$_dialCode${_phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')}';

  void _submit() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) {
      _show('Enter the phone number on your driver account');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _show('Enter your password');
      return;
    }
    context.read<DriverAuthBloc>()
        .add(DriverLoginRequested(_fullPhone, _passwordCtrl.text));
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor));
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<DriverAuthBloc>().state is DriverAuthLoading;

    return Scaffold(
      // A sign-in that lands on the wrong page is worse than no tab bar at all, so the
      // listener reads the tab the driver actually submitted from.
      body: BlocListener<DriverAuthBloc, DriverAuthState>(
        listener: (ctx, state) {
          if (state is DriverAuthenticated) {
            ctx.go(_tabs.index == 1 ? '/documents' : '/home');
          }
          if (state is DriverAuthError) {
            _show(state.message);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.directions_car,
                          color: AppTheme.accentColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text('RideEt Driver',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 28),
                TabBar(
                  controller: _tabs,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Login'),
                    Tab(text: 'Register'),
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _tabs,
                  builder: (context, _) => switch (_tabs.index) {
                    1 => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('New driver?',
                              style:
                                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Create an account, then upload your documents.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 20),
                          const DriverRegisterForm(),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _tabs.index = 0),
                              child: const Text('Back to login'),
                            ),
                          ),
                        ],
                      ),
                    _ => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Welcome back',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Sign in to start earning',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 28),
                          _PhoneField(
                            controller: _phoneCtrl,
                            dialCode: _dialCode,
                            onChanged: () => setState(() {}),
                            onDialCodeChanged: (code) => setState(() => _dialCode = code),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: busy ? null : _submit,
                            child: busy
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Log In'),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _tabs.index = 1),
                              child: const Text('Sign Up as a New Driver'),
                            ),
                          ),
                        ],
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String dialCode;
  final VoidCallback onChanged;
  final ValueChanged<String> onDialCodeChanged;

  const _PhoneField({
    required this.controller,
    required this.dialCode,
    required this.onChanged,
    required this.onDialCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: 'Registered Phone Number',
        hintText: '911000001',
        prefixIcon: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: dialCode,
            items: _dialCodes
                .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                .toList(),
            onChanged: (code) {
              if (code != null) onDialCodeChanged(code);
            },
          ),
        ),
      ),
    );
  }
}
