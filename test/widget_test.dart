// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:piction_ai_ry/main.dart';

void main() {
  testWidgets('Piction.ia.ry app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PictionApp());

    // Verify that the app loads and shows the home screen
    expect(find.text('Piction.ia.ry'), findsOneWidget);
    expect(find.text('Créer une partie'), findsOneWidget);
    expect(find.text('Rejoindre une partie'), findsOneWidget);
  });
}
