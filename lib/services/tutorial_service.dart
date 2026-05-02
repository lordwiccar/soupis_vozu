import 'package:shared_preferences/shared_preferences.dart';
import 'inventory_service.dart';
import 'uic_validator.dart';

class TutorialService {
  static const _key = 'onboarding_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key) ?? false);
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Vytvoří demo soupis se třemi vozy pro účely průvodce.
  /// Vrací ID vytvořeného soupisu.
  static Future<String> createDemoInventory() async {
    const demoNumbers = ['315448542694', '318147520828', '835427015474'];

    final id = await InventoryService.createInventory(
      'Ukázkový soupis',
      location: 'Praha hl. n.',
    );

    final wagons = demoNumbers.asMap().entries.map((e) => {
      'number': e.value,
      'formatted': UicValidator.formatUicNumber(e.value),
      'isValid': UicValidator.validateUicNumber(e.value),
      'order': e.key + 1,
      'notes': null,
    }).toList();

    await InventoryService.addWagonNumbersBatch(id, wagons);
    return id;
  }

  /// Smaže demo soupis po dokončení průvodce.
  static Future<void> deleteDemoInventory(String id) async {
    await InventoryService.deleteInventory(id);
  }
}
