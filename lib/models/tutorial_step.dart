import 'package:flutter/material.dart';
import '../services/tutorial_controller.dart';

/// Tvar výřezu ve spotlight překryvu tutoriálu.
enum SpotlightShape {
  /// Zaoblený obdélník kolem zaměřeného widgetu.
  rect,

  /// Kruhový výřez (vhodné pro malá ikonová tlačítka).
  circle,

  /// Bez výřezu – celá obrazovka je jen ztlumená (úvodní/závěrečná karta).
  none,
}

/// Vrátí `GlobalKey` widgetu, který se má v daném kroku zvýraznit. Jde o
/// funkci (ne přímo klíč), protože klíč existuje až ve chvíli, kdy je
/// odpovídající obrazovka skutečně vytvořená – viz `TutorialTargetRegistry`.
typedef TargetKeyResolver = GlobalKey? Function();

/// Jeden krok spotlight tutoriálu.
class TutorialStep {
  final String title;
  final String body;
  final IconData icon;
  final SpotlightShape shape;

  /// Cíl zvýraznění v tomto kroku. `null` = krok bez výřezu (úvod/závěr).
  final TargetKeyResolver? targetKey;

  /// Odsazení přidané kolem změřeného obdélníku před vykreslením výřezu.
  final EdgeInsets holePadding;

  /// Spustí se jednou, těsně předtím, než se krok zobrazí – navigace,
  /// přepnutí záložky, otevření dialogu, scroll cíle do viditelné oblasti.
  final Future<void> Function(TutorialController controller)? preAction;

  /// Spustí se při opuštění kroku směrem dopředu – typicky zavření
  /// dialogu/obrazovky otevřené v `preAction`.
  final Future<void> Function(TutorialController controller)? postAction;

  const TutorialStep({
    required this.title,
    required this.body,
    required this.icon,
    this.shape = SpotlightShape.rect,
    this.targetKey,
    this.holePadding = const EdgeInsets.all(8),
    this.preAction,
    this.postAction,
  });
}
