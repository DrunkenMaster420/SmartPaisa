import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpaisaa/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartPaisaApp());

    // Wait for any async operations to complete
    await tester.pumpAndSettle();

    // Verify that the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
