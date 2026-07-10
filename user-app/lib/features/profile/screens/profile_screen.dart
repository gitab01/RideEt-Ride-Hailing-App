import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            const CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('User Name',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('user@rideet.com',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),

            // Menu items
            _MenuItem(icon: Icons.account_circle_outlined, label: 'Edit Profile', onTap: () {}),
            _MenuItem(icon: Icons.payment_outlined, label: 'Payment Methods', onTap: () => context.go('/payment')),
            _MenuItem(icon: Icons.history, label: 'Ride History', onTap: () => context.go('/history')),
            _MenuItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => context.go('/notifications')),
            _MenuItem(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),
            _MenuItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.logout,
              label: 'Sign Out',
              onTap: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
                context.go('/login');
              },
              color: AppTheme.errorColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon, required this.label, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.primaryColor),
        title: Text(label, style: TextStyle(color: color)),
        trailing: color == null
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
