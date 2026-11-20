import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupis_vozu/widgets/scanned_wagon_row.dart';

/// Text, který [WagonNumberText] skutečně vykreslil (včetně všech spanů).
String _renderedText(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.descendant(
      of: find.byType(WagonNumberText), matching: find.byType(RichText)));
  return rich.text.toPlainText();
}

Future<void> _pump(WidgetTester tester,
    {required double width,
    double fontSize = 20,
    bool highlight = false,
    double textScale = 1}) {
  return tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Center(
        child: SizedBox(
          width: width,
          child: WagonNumberText(
            number: '335478431127',
            highlightLast4: highlight,
            style: TextStyle(fontSize: fontSize),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('celé číslo, když se vejde', (tester) async {
    await _pump(tester, width: 1000);
    expect(_renderedText(tester), '33 54 7843 112-7');
  });

  testWidgets('zkracuje zleva po skupinách, konec zůstává', (tester) async {
    final seen = <String>{};
    for (var width = 1000.0; width >= 40; width -= 10) {
      await _pump(tester, width: width);
      final text = _renderedText(tester);
      seen.add(text);
      expect(text.endsWith('112-7') || text.startsWith('…'), isTrue);
    }
    expect(
        seen,
        containsAll(<String>[
          '33 54 7843 112-7',
          '…54 7843 112-7',
          '…7843 112-7',
          '…112-7',
        ]));
  });

  testWidgets('zvětšené systémové písmo vede ke zkrácení', (tester) async {
    await _pump(tester, width: 400, fontSize: 24);
    final normal = _renderedText(tester);
    await _pump(tester, width: 400, fontSize: 24, textScale: 1.5);
    final scaled = _renderedText(tester);
    expect(scaled.length, lessThan(normal.length));
    expect(scaled.startsWith('…'), isTrue);
  });

  testWidgets('zvýraznění tučně začíná na 4. číslici od konce',
      (tester) async {
    await _pump(tester, width: 1000, highlight: true);
    final rich = tester.widget<RichText>(find.descendant(
        of: find.byType(WagonNumberText), matching: find.byType(RichText)));
    // Text.rich zabalí náš span do dalšího – najdeme span s tučným písmem.
    String? bold;
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          span.style?.fontWeight == FontWeight.w700 &&
          span.text != null) {
        bold = span.text;
      }
      return true;
    });
    expect(bold, '112-7');
    expect(_renderedText(tester), '33 54 7843 112-7');
  });
}
