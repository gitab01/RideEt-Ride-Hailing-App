import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideet_user/features/auth/bloc/auth_bloc.dart';
import 'package:rideet_user/features/auth/screens/login_screen.dart';
import 'package:rideet_user/features/auth/screens/onboarding_screen.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(BlocProvider(
      create: (_) => AuthBloc(),
      child: const MaterialApp(home: LoginScreen()),
    ));
  }

  Future<void> snackbar(WidgetTester tester, String message) async {
    await tester.pump();
    expect(find.text(message), findsOneWidget);
  }

  testWidgets('onboarding pages through the three steps before offering the CTA',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Set Your Destination'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Match with a Driver'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Arrive Safely'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Already have an account? Login'), findsOneWidget);
  });

  testWidgets('the country code defaults to Ethiopia, as the sign-in sheet shows it',
      (tester) async {
    await pumpLogin(tester);

    expect(find.text('+251'), findsOneWidget);
    expect(find.text('OTP via SMS'), findsOneWidget);
  });

  testWidgets('an OTP request refuses a number too short to dial', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Phone number'), '911');
    await tester.tap(find.widgetWithText(ElevatedButton, 'OTP via SMS'));
    await snackbar(tester, 'Enter your phone number without the country code');
  });

  testWidgets('password sign-in refuses an address the backend cannot look up',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Continue with email and password'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'no-at-sign');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await snackbar(tester, 'Enter a valid email');
  });

  testWidgets('password sign-in refuses a password shorter than the server accepts',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Continue with email and password'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await snackbar(tester, 'Password too short');
  });
}
