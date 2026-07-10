import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/driver_auth_bloc.dart';
import '../../../core/theme/app_theme.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<DriverAuthBloc>().add(
        DriverLoginRequested(_emailCtrl.text.trim(), _passwordCtrl.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<DriverAuthBloc, DriverAuthState>(
        listener: (ctx, state) {
          if (state is DriverAuthenticated) ctx.go('/home');
          if (state is DriverAuthError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor));
          }
        },
        builder: (ctx, state) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.directions_car, color: AppTheme.accentColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Text('RideEt Driver',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 48),
                  const Text('Welcome back, Driver',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  Text('Sign in to start earning', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Password too short' : null,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: state is DriverAuthLoading ? null : _submit,
                    child: state is DriverAuthLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => ctx.go('/register'),
                      child: const Text.rich(TextSpan(children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(text: 'Register',
                            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ])),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
