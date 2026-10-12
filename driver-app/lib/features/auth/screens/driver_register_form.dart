import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/driver_auth_bloc.dart';

/// New-driver sign-up. The login screen hosts this as its second tab and owns the
/// navigation once [DriverAuthBloc] reports success.
class DriverRegisterForm extends StatefulWidget {
  const DriverRegisterForm({super.key});

  @override
  State<DriverRegisterForm> createState() => _DriverRegisterFormState();
}

class _DriverRegisterFormState extends State<DriverRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl, _passwordCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<DriverAuthBloc>().add(DriverRegisterRequested({
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'password': _passwordCtrl.text,
    }));
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<DriverAuthBloc>().state is DriverAuthLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+251911000001',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) => v == null || !RegExp(r'^\+[0-9]{9,15}$').hasMatch(v.trim())
                ? 'Use the international format, e.g. +251911000001'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => v == null || v.length < 8 ? 'Min 8 characters' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: busy ? null : _submit,
            child: busy
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create driver account'),
          ),
        ],
      ),
    );
  }
}
