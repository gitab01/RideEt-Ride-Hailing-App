import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/driver_login_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/driver_home_screen.dart';
import '../../features/trip/screens/trip_screen.dart';
import '../../features/earnings/screens/earnings_screen.dart';
import '../../features/profile/screens/driver_profile_screen.dart';
import '../../features/documents/screens/documents_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const DriverSplashScreen()),
      GoRoute(path: '/login',  builder: (_, __) => const DriverLoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
      ShellRoute(
        builder: (_, __, child) => DriverShell(child: child),
        routes: [
          GoRoute(path: '/home',     builder: (_, __) => const DriverHomeScreen()),
          GoRoute(path: '/earnings', builder: (_, __) => const EarningsScreen()),
          GoRoute(path: '/profile',  builder: (_, __) => const DriverProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/trip/:rideId',
        builder: (_, state) => TripScreen(rideId: state.pathParameters['rideId']!),
      ),
    ],
  );
}

class DriverShell extends StatefulWidget {
  final Widget child;
  const DriverShell({super.key, required this.child});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) {
          setState(() => _idx = i);
          switch (i) {
            case 0: context.go('/home'); break;
            case 1: context.go('/earnings'); break;
            case 2: context.go('/profile'); break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.attach_money), selectedIcon: Icon(Icons.monetization_on), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
