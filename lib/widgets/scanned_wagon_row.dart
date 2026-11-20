import 'package:flutter/material.dart';

import '../services/appearance_service.dart';
import '../services/theme_service.dart';
import '../services/uic_validator.dart';

/// Jeden řádek výpisu vozů na obrazovce skenování. Používá ho jak obrazovka
/// skenování, tak náhled na kartě Vzhled v Nastavení, aby náhled vždy
/// přesně odpovídal skutečnému výpisu.
///
/// Výpis je vždy na tmavém pozadí ([ThemeService.kRailBlack]) bez ohledu
/// na zvolený motiv.
class ScannedWagonRow extends StatelessWidget {
  /// Číslo vozu bez formátování (12 číslic).
  final String number;
  final bool isValid;

  /// Má vůz v databázi vyplněné všechny sledované technické údaje?
  final bool isComplete;

  /// Je vůz v databázi veden se závadou (příznak/poznámka)?
  final bool hasDefect;

  /// Vůz naskenovaný v některé z dřívějších relací tohoto soupisu – zobrazí
  /// se tlumeně šedě, aby se odlišil od vozů nově naskenovaných.
  final bool isPrevious;

  /// Index do [AppearanceService.scanFontSizes].
  final int fontStep;
  final bool highlightLast4;

  /// Klepnutí na tužku. Když je `null` (náhled v nastavení), tužka se
  /// jen zobrazí.
  final VoidCallback? onEdit;
  final Key? editKey;

  const ScannedWagonRow({
    super.key,
    required this.number,
    required this.isValid,
    required this.isComplete,
    required this.hasDefect,
    required this.fontStep,
    required this.highlightLast4,
    this.isPrevious = false,
    this.onEdit,
    this.editKey,
  });

  // Barvy dříve naskenovaných vozů.
  static const Color _prevText = Color(0xFF8A949D);
  static const Color _prevTextInvalid = Color(0xFFB07A76);
  static const Color _prevIcon = Color(0xBF96A0A8);
  static const Color _prevIconInvalid = Color(0x80E53935);

  @override
  Widget build(BuildContext context) {
    final step = fontStep.clamp(0, AppearanceService.scanFontSizes.length - 1);
    final fontSize = AppearanceService.scanFontSizes[step];
    // Ikony rostou s textem jen napůl, aby nezabíraly místo číslu. Mají
    // pevnou šířku mimo `Expanded`, takže je delší číslo nikdy nevytlačí.
    final iconSize = 18 + (fontSize - 15) * 0.5;

    final Color textColor;
    final Color validityColor;
    if (isPrevious) {
      textColor = isValid ? _prevText : _prevTextInvalid;
      validityColor = isValid ? _prevIcon : _prevIconInvalid;
    } else {
      textColor = isValid ? Colors.white : Colors.red;
      validityColor = isValid ? Colors.green : Colors.red;
    }
    final double dimFactor = isPrevious ? 0.6 : 1.0;

    final editIcon = Icon(
      Icons.edit_outlined,
      color: ThemeService.kRailAmber.withValues(alpha: isPrevious ? 0.55 : 1),
      size: 18,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 6.0 + step),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: validityColor,
            size: iconSize,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: WagonNumberText(
              number: number,
              highlightLast4: highlightLast4,
              style: TextStyle(color: textColor, fontSize: fontSize),
            ),
          ),
          Tooltip(
            message: isComplete
                ? 'Databáze: technické údaje kompletní'
                : 'Databáze: technické údaje neúplné',
            child: Icon(
              isComplete ? Icons.circle : Icons.circle_outlined,
              size: 8,
              color: isComplete
                  ? Colors.greenAccent.withValues(alpha: 0.8 * dimFactor)
                  : Colors.white24,
            ),
          ),
          if (hasDefect) ...[
            Tooltip(
              message: 'Databáze: vůz veden se závadou (příznak/poznámka)',
              child: Icon(
                Icons.warning_amber_rounded,
                size: iconSize,
                color: Colors.orange.withValues(alpha: isPrevious ? 0.8 : 1),
              ),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 10),
          if (onEdit != null)
            IconButton(
              key: editKey,
              icon: editIcon,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onEdit,
              tooltip: 'Přidat poznámky a příznaky',
            )
          else
            SizedBox(width: 32, height: 32, child: Center(child: editIcon)),
        ],
      ),
    );
  }
}

/// Oddělovač mezi dříve naskenovanými vozy (nad ním) a vozy naskenovanými
/// v aktuální relaci (pod ním).
class PreviousWagonsDivider extends StatelessWidget {
  const PreviousWagonsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final lineColor = ThemeService.kRailAmber.withValues(alpha: 0.35);
    final textColor = ThemeService.kRailAmber.withValues(alpha: 0.8);
    const labelStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: lineColor)),
          const SizedBox(width: 6),
          Icon(Icons.arrow_upward, size: 12, color: textColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'DŘÍVE NASKENOVANÉ  ·  NOVÉ',
              style: labelStyle.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.arrow_downward, size: 12, color: textColor),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 1, color: lineColor)),
        ],
      ),
    );
  }
}

/// Číslo vozu ve výpisu. Vždy na jeden řádek; když se celé nevejde, zkrátí
/// se **zleva** po celých skupinách (`33 54 7843 112-7` → `…54 7843 112-7`
/// → `…7843 112-7` → `…112-7`), aby zůstalo vidět poslední čtyřčíslí,
/// podle kterého se vozy rozlišují. Volitelně je poslední čtyřčíslí tučně.
class WagonNumberText extends StatelessWidget {
  /// Číslo vozu bez formátování.
  final String number;
  final TextStyle style;
  final bool highlightLast4;

  const WagonNumberText({
    super.key,
    required this.number,
    required this.style,
    this.highlightLast4 = false,
  });

  static const String _ellipsis = '…';

  @override
  Widget build(BuildContext context) {
    // Tabulkové číslice – všechny číslice stejně široké, čísla pod sebou
    // lícují.
    final baseStyle = DefaultTextStyle.of(context).style.merge(style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final formatted = UicValidator.formatUicNumber(number);

    return LayoutBuilder(
      builder: (context, constraints) {
        final text = _fitFromStart(
            formatted, baseStyle, textScaler, constraints.maxWidth);
        return Text.rich(
          _buildSpan(text, baseStyle),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        );
      },
    );
  }

  /// Nejdelší varianta textu, která se vejde do [maxWidth]: nejdřív celé
  /// číslo, pak postupně bez úvodních skupin, a v úplné nouzi (nemělo by
  /// nastat) po jednotlivých znacích zleva.
  String _fitFromStart(String formatted, TextStyle baseStyle,
      TextScaler textScaler, double maxWidth) {
    if (!maxWidth.isFinite) return formatted;

    bool fits(String candidate) {
      final painter = TextPainter(
        text: _buildSpan(candidate, baseStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final ok = painter.width <= maxWidth;
      painter.dispose();
      return ok;
    }

    if (fits(formatted)) return formatted;

    final groups = formatted.split(' ');
    for (var k = 1; k < groups.length; k++) {
      final candidate = '$_ellipsis${groups.sublist(k).join(' ')}';
      if (fits(candidate)) return candidate;
    }

    var rest = groups.last;
    while (rest.length > 1) {
      rest = rest.substring(1);
      final candidate = '$_ellipsis$rest';
      if (fits(candidate)) return candidate;
    }
    return '$_ellipsis$rest';
  }

  /// Text čísla; s [highlightLast4] je část od čtvrté číslice od konce
  /// tučně.
  TextSpan _buildSpan(String text, TextStyle baseStyle) {
    if (!highlightLast4) return TextSpan(text: text, style: baseStyle);

    var digits = 0;
    var start = text.length;
    for (var i = text.length - 1; i >= 0; i--) {
      final c = text.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) {
        digits++;
        start = i;
        if (digits == 4) break;
      }
    }
    if (start <= 0) {
      return TextSpan(
          text: text, style: baseStyle.copyWith(fontWeight: FontWeight.w700));
    }
    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
