import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/driver_auth_bloc.dart';
import 'features/trip/bloc/trip_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RideEtDriverApp());
}

class RideEtDriverApp extends StatelessWidget {
  const RideEtDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DriverAuthBloc>(create: (_) => DriverAuthBloc()),
        BlocProvider<TripBloc>(create: (_) => TripBloc()),
      ],
      child: MaterialApp.router(
        title: 'RideEt Driver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.driverTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
