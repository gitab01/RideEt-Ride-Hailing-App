import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideet_driver/features/auth/bloc/driver_auth_bloc.dart';
import 'package:rideet_driver/features/auth/screens/driver_login_screen.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(BlocProvider(
      create: (_) => DriverAuthBloc(),
      child: const MaterialApp(home: DriverLoginScreen()),
    ));
  }

  testWidgets('sign-in refuses a phone number that is too short to be an account',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pump();

    expect(find.text('Enter the phone number on your driver account'), findsOneWidget);
  });

  testWidgets('sign-in refuses a password the backend could not accept', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Registered Phone Number'), '9110000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pump();

    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('the password field stays masked until the eye toggles it', (tester) async {
    await pumpLogin(tester);

    final passwordField = find.descendant(
        of: find.widgetWithText(TextFormField, 'Password'),
        matching: find.byType(TextField));

    await tester.enterText(passwordField, 'hunter2x');
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
  });

  testWidgets('the Register tab shows the sign-up fields', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(Tab, 'Register'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create driver account'), findsOneWidget);
  });
}
