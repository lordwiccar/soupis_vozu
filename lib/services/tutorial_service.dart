import 'package:shared_preferences/shared_preferences.dart';
import 'inventory_service.dart';
import 'uic_validator.dart';
import 'wagon_registry_service.dart';

class TutorialService {
  static const _key = 'onboarding_v1';

  static const List<String> demoWagonNumbers = [
    '315448542694',
    '318147520828',
    '835427015474',
  ];

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
    final id = await InventoryService.createInventory(
      'Ukázkový soupis',
      location: 'Praha hl. n.',
    );

    final wagons = demoWagonNumbers.asMap().entries.map((e) => {
      'number': e.value,
      'formatted': UicValidator.formatUicNumber(e.value),
      'isValid': UicValidator.validateUicNumber(e.value),
      'order': e.key + 1,
      'notes': null,
    }).toList();

    await InventoryService.addWagonNumbersBatch(id, wagons);
    return id;
  }

  /// Doplní ukázkovým vozům kompletní technické údaje, aby šlo v kroku o
  /// výpočtu MZOB reálně stisknout tlačítko a zobrazit skutečný výsledek.
  /// Volá se těsně před daným krokem, ne při vytvoření soupisu – uživatel
  /// tak nejdřív vidí prázdná pole u kroku "Technické údaje".
  static Future<void> enrichDemoWagonsForMzobDemo(String inventoryId) async {
    final wagons =
        await InventoryService.getWagonNumbersForInventory(inventoryId);

    for (final wagon in wagons) {
      await InventoryService.updateWagonNumber(
        inventoryId,
        wagon.copyWith(
          weight: 22.5,
          brakeWeightG: 20.0,
          brakeWeightP: 40.0,
          maxSpeedEmpty: 120,
          maxSpeedLoaded: 100,
          length: 14.04,
          axleCount: 4,
          nonMetallicBlocks: true,
        ),
      );
    }
  }

  /// Smaže demo soupis po dokončení (nebo přeskočení) průvodce, včetně
  /// záznamů demo vozů v trvalém registru vozů – ty tam mohly vzniknout
  /// jakoukoli úpravou vozu během tutoriálu (nálepka, poznámka, doplnění
  /// technických údajů pro MZOB), protože `InventoryService.updateWagonNumber`
  /// každou změnu automaticky zapisuje i do `WagonRegistryService`. Tři
  /// pevně daná demo UIC čísla nemohou v reálném světě patřit skutečnému
  /// vozu, takže je bezpečné jejich záznamy vždy smazat.
  static Future<void> deleteDemoInventory(String id) async {
    await InventoryService.deleteInventory(id);
    for (final number in demoWagonNumbers) {
      await WagonRegistryService.deleteEntry(number);
    }
  }
}
