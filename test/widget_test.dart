import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/app.dart';

void main() {
  testWidgets('App launches with title text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TechTonicApp()),
    );
    expect(find.text('tech-Tonic'), findsOneWidget);
  });
}
