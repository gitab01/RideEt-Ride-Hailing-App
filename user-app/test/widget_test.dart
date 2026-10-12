import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideet_user/features/auth/screens/onboarding_screen.dart';

void main() {
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
}
