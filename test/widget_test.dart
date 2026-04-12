// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:soupis_vozu/main.dart';

void main() {
  testWidgets('Soupis vozů app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SoupisVozuApp());

    // Verify that the home screen is displayed
    expect(find.text('Soupis vozů'), findsOneWidget);
    expect(find.text('Vítejte v aplikaci pro soupis vozů'), findsOneWidget);
    expect(find.text('Skenujte čísla vozů pomocí kamery'), findsOneWidget);
    expect(find.text('Začít skenování'), findsOneWidget);
  });
}
