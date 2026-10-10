import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient().dio.get('/auth/me');
      setState(() {
        _me = Map<String, dynamic>.from(res.data['data'] as Map);
        _loading = false;
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Could not load your profile';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _ProfileHeader(me: _me, error: _error, onRetry: _load),
            const SizedBox(height: 24),
            _MenuItem(
              icon: Icons.history,
              label: 'Ride History',
              onTap: () => context.go('/history'),
            ),
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => context.go('/notifications'),
            ),
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

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? me;
  final String? error;
  final VoidCallback onRetry;

  const _ProfileHeader({required this.me, required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    if (me == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(error ?? 'Profile unavailable')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final name = me!['fullName'] ?? '';
    final picture = me!['profilePictureUrl'] as String?;

    return Column(
      children: [
        picture == null || picture.isEmpty
            ? const CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.person, color: Colors.white, size: 48),
              )
            : CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(picture),
              ),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(me!['email'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          '${me!['phone'] ?? ''} • ${(me!['role'] ?? 'PASSENGER').toString().toLowerCase()}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
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
