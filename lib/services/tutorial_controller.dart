import 'package:flutter/material.dart';
import '../models/tutorial_step.dart';
import 'tutorial_service.dart';
import 'tutorial_steps.dart';
import 'tutorial_target_registry.dart';

/// Řídí průběh spotlight tutoriálu: aktuální krok, navigaci mezi
/// obrazovkami skrze [preAction]/[postAction] jednotlivých kroků, a měření
/// zvýrazněného widgetu pro `SpotlightOverlay`.
class TutorialController extends ChangeNotifier {
  TutorialController(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  bool active = false;
  int stepIndex = 0;
  String? demoInventoryId;
  Rect? currentRect;

  List<TutorialStep> get steps => kTutorialSteps;
  TutorialStep get current => steps[stepIndex];
  bool get isLastStep => stepIndex == steps.length - 1;

  Future<void> start() async {
    // Ať už se tutoriál spouští při prvním spuštění appky, nebo znovu z
    // Nastavení, vždy začíná od domovské obrazovky.
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
    demoInventoryId = await TutorialService.createDemoInventory();
    active = true;
    TutorialTargetRegistry.tutorialActive = true;
    stepIndex = 0;
    notifyListeners();
    await _enterStep(0);
  }

  Future<void> next() async {
    await current.postAction?.call(this);
    if (isLastStep) {
      await finish();
      return;
    }
    stepIndex++;
    await _enterStep(stepIndex);
  }

  Future<void> skip() => finish();

  Future<void> finish() async {
    await TutorialService.markComplete();
    if (demoInventoryId != null) {
      await TutorialService.deleteDemoInventory(demoInventoryId!);
      demoInventoryId = null;
    }
    active = false;
    TutorialTargetRegistry.tutorialActive = false;
    currentRect = null;
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
    notifyListeners();
  }

  Future<void> _enterStep(int index) async {
    currentRect = null;
    notifyListeners();
    await steps[index].preAction?.call(this);
    await _settleAndMeasure();
  }

  Future<void> _settleAndMeasure() async {
    // Cíl kroku se nemusí objevit hned – např. po přechodu na obrazovku
    // skenování ještě chvíli běží inicializace kamery, než se tlačítko
    // SKENOVAT vůbec vykreslí. Proto místo jednorázového čekání zkoušíme
    // widget najít a změřit opakovaně, dokud se neobjeví (nebo nevypršel
    // časový limit).
    Rect? rect;
    final targetKey = current.targetKey;

    if (targetKey == null) {
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      for (var attempt = 0; attempt < 20; attempt++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!active) return;

        final key = targetKey();
        final ctx = key?.currentContext;
        if (key != null && ctx != null) {
          // Pokud je cíl uvnitř scrollovatelného seznamu (např. tlačítko
          // ve rozbaleném soupisu), posuneme ho nejdřív do viditelné
          // oblasti – jinak by se zaměřilo místo mimo obrazovku.
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 200),
            alignment: 0.5,
          );
          await WidgetsBinding.instance.endOfFrame;
          rect = measure(key);
          if (rect != null && rect.width > 0 && rect.height > 0) break;
        }
      }
    }

    if (!active) return;
    currentRect = rect;
    notifyListeners();
  }

  /// Znovu změří aktuální cíl (např. po úpravě dat pod ním) a překreslí
  /// překryv, aniž by se posouval krok.
  Future<void> remeasure() => _settleAndMeasure();

  static Rect? measure(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  /// Zavolá zaregistrovanou akci (viz [TutorialTargetRegistry]) a nic
  /// nedělá, pokud daná obrazovka/akce aktuálně není registrovaná.
  void runAction(String id) => TutorialTargetRegistry.resolveAction(id)?.call();

  Future<void> pushNamed(String route) async {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
  }
}
