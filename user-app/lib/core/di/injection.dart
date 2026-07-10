import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/booking/bloc/booking_bloc.dart';
import '../../features/home/bloc/home_bloc.dart';

// Simple provider list — swap with get_it if the app grows
final List<BlocProvider> appBlocProviders = [
  BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
  BlocProvider<BookingBloc>(create: (_) => BookingBloc()),
  BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
];

Future<void> setupInjection() async {
  // Initialize any singletons or async setup here
}
