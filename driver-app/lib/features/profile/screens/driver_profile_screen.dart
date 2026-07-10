import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/bloc/driver_auth_bloc.dart';
import '../../../core/theme/app_theme.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Driver Name',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('driver@rideet.com',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            _MenuItem(icon: Icons.directions_car_outlined, label: 'Vehicle Info', onTap: () {}),
            _MenuItem(icon: Icons.description_outlined, label: 'Documents', onTap: () => context.go('/documents')),
            _MenuItem(icon: Icons.history, label: 'Trip History', onTap: () {}),
            _MenuItem(icon: Icons.support_agent, label: 'Support', onTap: () {}),
            _MenuItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.logout,
              label: 'Sign Out',
              onTap: () {
                context.read<DriverAuthBloc>().add(DriverLogoutRequested());
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

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.primaryColor),
        title: Text(label, style: TextStyle(color: color)),
        trailing: color == null ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
