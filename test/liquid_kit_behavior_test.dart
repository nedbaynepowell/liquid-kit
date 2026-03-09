import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_kit/liquid_kit.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('adaptive mode falls back to Material NavigationBar',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidGlassNavigationBar(
            mode: LiquidGlassMode.adaptive,
            currentIndex: 0,
            onTabChanged: (_) {},
            tabs: const [
              LiquidGlassTab(icon: Icons.home_rounded, label: 'Home'),
              LiquidGlassTab(icon: Icons.person_rounded, label: 'Profile'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
