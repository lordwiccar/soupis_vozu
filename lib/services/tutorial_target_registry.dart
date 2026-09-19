import 'package:flutter/material.dart';

/// Statický registr, přes který si obrazovky bez přímé závislosti na
/// tutoriálu "publikují" své `GlobalKey`, `TabController` a skryté akce
/// (soukromé metody otevírající dialogy), aby je `TutorialController` mohl
/// zvenčí najít a použít pro zvýraznění / navigaci mezi kroky.
///
/// Obrazovky se registrují v `initState()` a odregistrují v `dispose()` –
/// mimo běh tutoriálu jde jen o pár řádků navíc bez dalšího efektu.
class TutorialTargetRegistry {
  TutorialTargetRegistry._();

  static final Map<String, GlobalKey> _keys = {};
  static final Map<String, TabController> _tabControllers = {};
  static final Map<String, VoidCallback> _actions = {};

  /// True po dobu běhu spotlight tutoriálu. Obrazovky s fold-layoutem podle
  /// toho vynucují telefonní (jednopanelové) zobrazení, protože tutoriál
  /// řídí navigaci sám a předpokládá vždy jen jednu obrazovku najednou.
  static bool tutorialActive = false;

  static void register(String id, GlobalKey key) => _keys[id] = key;
  static void unregister(String id) => _keys.remove(id);
  static GlobalKey? resolveKey(String id) => _keys[id];

  static void registerTabController(String id, TabController controller) =>
      _tabControllers[id] = controller;
  static void unregisterTabController(String id) => _tabControllers.remove(id);
  static TabController? resolveTabController(String id) => _tabControllers[id];

  static void registerAction(String id, VoidCallback action) =>
      _actions[id] = action;
  static void unregisterAction(String id) => _actions.remove(id);
  static VoidCallback? resolveAction(String id) => _actions[id];
}
