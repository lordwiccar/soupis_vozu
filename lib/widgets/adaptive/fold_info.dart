import 'dart:ui' show DisplayFeatureType;
import 'package:flutter/material.dart';
import '../../services/tutorial_target_registry.dart';

/// Práh šířky/výšky (logické px), od kterého považujeme okno za "rozevřený
/// fold", pokud OS nenahlásí konkrétní `DisplayFeature` (hinge). Šířka
/// odpovídá Material "expanded" třídě; výšková pojistka je tu proto, aby se
/// běžný Android tablet v portrétu (typicky 600–840dp široký) omylem
/// nepřepnul do fold layoutu jen kvůli šířce.
const double kFoldWidthBreakpoint = 840.0;
const double kFoldHeightBreakpoint = 600.0;

/// Popisuje, jestli aktuální okno odpovídá rozevřenému foldovacímu telefonu
/// (typu Galaxy Z Fold), a případně kde přesně je závěs.
@immutable
class FoldInfo {
  final bool isUnfolded;
  final Rect? hingeBounds;

  const FoldInfo({required this.isUnfolded, this.hingeBounds});

  static const FoldInfo phone = FoldInfo(isUnfolded: false);

  factory FoldInfo.fromMediaQuery(MediaQueryData mq) {
    // Bezpečnostní pojistka: pokud právě běží spotlight tutoriál, vždy
    // vynutíme telefonní layout – tutoriál řídí navigaci sám a předpokládá
    // jednu obrazovku najednou.
    if (TutorialTargetRegistry.tutorialActive) {
      return FoldInfo.phone;
    }

    // 1) Primární signál: skutečný svislý závěs/ohyb nahlášený OS.
    for (final feature in mq.displayFeatures) {
      final isHingeOrFold = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      final runsFullHeight = feature.bounds.height >= mq.size.height * 0.9;
      if (isHingeOrFold && runsFullHeight) {
        return FoldInfo(isUnfolded: true, hingeBounds: feature.bounds);
      }
    }

    // 2) Záložní odhad pro zařízení/emulátory, které displayFeatures
    //    nehlásí, i když je okno reálně široké.
    final wide = mq.size.width >= kFoldWidthBreakpoint;
    final tall = mq.size.height >= kFoldHeightBreakpoint;
    return FoldInfo(isUnfolded: wide && tall);
  }

  static FoldInfo of(BuildContext context) =>
      FoldInfo.fromMediaQuery(MediaQuery.of(context));
}
