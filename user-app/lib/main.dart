import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Stripe
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  try {
    await Stripe.instance.applySettings();
  } catch (_) {
    // No real publishable key yet. The payment screen reports the failure when a rider
    // actually tries to charge a card, instead of the app dying on launch.
  }

  // Setup dependency injection
  await setupInjection();

  runApp(const RideEtUserApp());
}

class RideEtUserApp extends StatelessWidget {
  const RideEtUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: appBlocProviders,
      child: MaterialApp.router(
        title: 'RideEt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
