// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:apkjoy/main.dart';

void main() {
  testWidgets('App loads and displays title', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ApkJoyApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Verify that the app title is displayed.
    expect(find.text('ApkJoy'), findsOneWidget);

    // Verify that the search bar is displayed.
    expect(find.byIcon(Icons.search), findsOneWidget);

  });
}
