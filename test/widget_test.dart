import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tech_tonic/app.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TechTonicApp()),
    );
    // The app should render a MaterialApp — the canvas will show
    // a loading indicator while shaders compile.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
