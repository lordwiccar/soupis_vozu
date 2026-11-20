// Widgetové testy obrazovek a prvků, které jdou vykreslit bez Firebase,
// databáze a kamery.
//
// Celou appku (`SoupisVozuApp`) tu záměrně nespouštíme: hned při startu
// se ptá Firebase na přihlášeného uživatele, a to v testu bez skutečného
// Firebase projektu nejde. Testují se proto jednotlivé obrazovky a widgety
// samostatně.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupis_vozu/screens/login_screen.dart';
import 'package:soupis_vozu/services/uic_validator.dart';
import 'package:soupis_vozu/widgets/scanned_wagon_row.dart';

/// Platná čísla vozů (kontrolní číslice sedí).
const _validNumber = '335478431125';
const _validNumber2 = '315453561070';

/// Stejné číslo se špatnou kontrolní číslicí.
const _invalidNumber = '335478431127';

/// Obalí widget tak, jak se zobrazuje ve výpisu na skenování (tmavé pozadí,
/// šířka běžného telefonu).
Widget _inScanList(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

/// Barva textu čísla vozu v řádku výpisu (jako ARGB, ať jde porovnat
/// `Color` i `MaterialColor`). `Text.rich` zabalí náš span do dalšího
/// s výchozím stylem, proto hledáme span, který nese samotný text.
int? _numberColor(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.descendant(
      of: find.byType(WagonNumberText), matching: find.byType(RichText)));
  Color? color;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.style?.color != null) {
      color = span.style!.color;
      return false;
    }
    return true;
  });
  return color?.toARGB32();
}

void main() {
  test('ukázková čísla v testech mají správnou kontrolní číslici', () {
    expect(UicValidator.validateUicNumber(_validNumber), isTrue);
    expect(UicValidator.validateUicNumber(_validNumber2), isTrue);
    expect(UicValidator.validateUicNumber(_invalidNumber), isFalse);
  });

  group('Přihlašovací obrazovka', () {
    testWidgets('ukazuje název appky a tlačítko přihlášení', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.text('Soupis vozů'), findsOneWidget);
      expect(find.text('Přihlásit se přes Google'), findsOneWidget);
      // Dokud se nikdo nepokusil přihlásit, nesmí se ukazovat chyba.
      expect(find.textContaining('nezdařilo'), findsNothing);
    });
  });

  group('Řádek výpisu vozů na skenování', () {
    testWidgets('platný vůz: zelená ikona, bílé formátované číslo',
        (tester) async {
      await tester.pumpWidget(_inScanList(ScannedWagonRow(
        number: _validNumber,
        isValid: UicValidator.validateUicNumber(_validNumber),
        isComplete: true,
        hasDefect: false,
        fontStep: 0,
        highlightLast4: false,
        onEdit: () {},
      )));

      expect(find.text('33 54 7843 112-5'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(_numberColor(tester), Colors.white.toARGB32());
    });

    testWidgets('neplatný vůz: červená ikona chyby a červené číslo',
        (tester) async {
      await tester.pumpWidget(_inScanList(ScannedWagonRow(
        number: _invalidNumber,
        isValid: UicValidator.validateUicNumber(_invalidNumber),
        isComplete: false,
        hasDefect: false,
        fontStep: 0,
        highlightLast4: false,
        onEdit: () {},
      )));

      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(_numberColor(tester), Colors.red.toARGB32());
    });

    testWidgets('vůz se závadou ukazuje oranžový vykřičník', (tester) async {
      await tester.pumpWidget(_inScanList(ScannedWagonRow(
        number: _validNumber,
        isValid: true,
        isComplete: true,
        hasDefect: true,
        fontStep: 0,
        highlightLast4: false,
        onEdit: () {},
      )));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('dříve naskenovaný vůz je šedý, ne bílý', (tester) async {
      await tester.pumpWidget(_inScanList(ScannedWagonRow(
        number: _validNumber,
        isValid: true,
        isComplete: true,
        hasDefect: false,
        isPrevious: true,
        fontStep: 0,
        highlightLast4: false,
        onEdit: () {},
      )));

      final argb = _numberColor(tester);
      expect(argb, isNotNull);
      final color = Color(argb!);
      expect(argb, isNot(Colors.white.toARGB32()));
      // Šedá = všechny tři složky barvy zhruba stejné a zároveň dost světlá,
      // aby byla na tmavém pozadí čitelná.
      expect((color.r - color.g).abs(), lessThan(0.1));
      expect((color.r - color.b).abs(), lessThan(0.1));
      expect(color.computeLuminance(), greaterThan(0.2));
    });

    testWidgets('klepnutí na tužku otevře úpravu vozu', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_inScanList(ScannedWagonRow(
        number: _validNumber,
        isValid: true,
        isComplete: true,
        hasDefect: false,
        fontStep: 0,
        highlightLast4: false,
        onEdit: () => tapped++,
      )));

      await tester.tap(find.byIcon(Icons.edit_outlined));
      expect(tapped, 1);
    });

    testWidgets('v náhledu (bez onEdit) tužka není tlačítko', (tester) async {
      await tester.pumpWidget(_inScanList(const ScannedWagonRow(
        number: _validNumber,
        isValid: true,
        isComplete: true,
        hasDefect: false,
        fontStep: 0,
        highlightLast4: false,
      )));

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('každý stupeň velikosti se vejde na 360 dp bez přetečení',
        (tester) async {
      for (var step = 0; step < 4; step++) {
        await tester.pumpWidget(_inScanList(ScannedWagonRow(
          number: _validNumber,
          isValid: true,
          isComplete: true,
          hasDefect: true,
          fontStep: step,
          highlightLast4: true,
          onEdit: () {},
        )));
        // Přetečení řádku (žluto-černé pruhy) by Flutter v testu nahlásil
        // jako výjimku.
        expect(tester.takeException(), isNull, reason: 'stupeň $step');
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      }
    });
  });

  testWidgets('oddělovač dříve naskenovaných vozů má popisek',
      (tester) async {
    await tester.pumpWidget(_inScanList(const PreviousWagonsDivider()));
    expect(find.text('DŘÍVE NASKENOVANÉ  ·  NOVÉ'), findsOneWidget);
  });
}
