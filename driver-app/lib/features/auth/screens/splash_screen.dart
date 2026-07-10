import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/driver_auth_bloc.dart';
import '../../../core/theme/app_theme.dart';

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});
  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.read<DriverAuthBloc>().add(DriverAuthCheckRequested());
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverAuthBloc, DriverAuthState>(
      listener: (ctx, state) {
        if (state is DriverAuthenticated) ctx.go('/home');
        if (state is DriverUnauthenticated) ctx.go('/login');
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.directions_car, color: AppTheme.primaryColor, size: 56),
                ),
                const SizedBox(height: 24),
                const Text('RideEt Driver',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Drive. Earn. Thrive.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
