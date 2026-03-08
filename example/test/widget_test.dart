import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_kit/liquid_kit.dart';

import 'package:liquid_kit_example/main.dart';

void main() {
  testWidgets('example app renders liquid kit shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LiquidKitExampleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LiquidGlassButton), findsNWidgets(2));
    expect(find.byType(LiquidGlassNavigationBar), findsOneWidget);
    expect(find.text('Liquid Glass'), findsOneWidget);
  });
}
