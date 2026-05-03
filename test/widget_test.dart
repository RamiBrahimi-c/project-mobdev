import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_final/screens/login_page.dart';

void main() {
  testWidgets('Login page renders auth actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Signup'), findsOneWidget);
  });
}
