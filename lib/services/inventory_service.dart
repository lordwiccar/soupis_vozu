import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/inventory.dart';
import 'wagon_registry_service.dart';

class InventoryService {
  static Database? _database;
  static const String _inventoryTable = 'inventories';
  static const String _wagonNumberTable = 'wagon_numbers';

  static Future<void> initDatabase() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'soupis_vozu.db');

    _database = await openDatabase(
      path,
      version: 3, // Zvýšit verzi pro migraci
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Vytvoření tabulky pro soupisy
    await db.execute('''
      CREATE TABLE $_inventoryTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        notes TEXT,
        location TEXT
      )
    ''');

    // Vytvoření tabulky pro čísla vozů
    await db.execute('''
      CREATE TABLE $_wagonNumberTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_id TEXT NOT NULL,
        number TEXT NOT NULL,
        formatted_number TEXT NOT NULL,
        is_valid INTEGER NOT NULL,
        order_number INTEGER NOT NULL,
        scanned_at TEXT NOT NULL,
        notes TEXT,
        weight REAL,
        brake_weight_g REAL,
        brake_weight_p REAL,
        handbrake INTEGER NOT NULL DEFAULT 0,
        handbrake_kn REAL,
        max_speed REAL,
        length REAL,
        FOREIGN KEY (inventory_id) REFERENCES $_inventoryTable (id)
      )
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Migrace pro existující databáze
    if (oldVersion < 2) {
      // Přidání nových sloupců
      await db.execute(
          'ALTER TABLE $_inventoryTable ADD COLUMN last_modified TEXT NOT NULL DEFAULT ""');
      await db.execute('ALTER TABLE $_inventoryTable ADD COLUMN location TEXT');

      // Aktualizace existujících záznamů
      await db.execute(
          'UPDATE $_inventoryTable SET last_modified = created_at WHERE last_modified = ""');
    }
    if (oldVersion < 3) {
      // Technické údaje o voze (hmotnost, brzdící váhy, ruční brzda, rychlost, délka)
      await db
          .execute('ALTER TABLE $_wagonNumberTable ADD COLUMN weight REAL');
      await db.execute(
          'ALTER TABLE $_wagonNumberTable ADD COLUMN brake_weight_g REAL');
      await db.execute(
          'ALTER TABLE $_wagonNumberTable ADD COLUMN brake_weight_p REAL');
      await db.execute(
          'ALTER TABLE $_wagonNumberTable ADD COLUMN handbrake INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE $_wagonNumberTable ADD COLUMN handbrake_kn REAL');
      await db.execute(
          'ALTER TABLE $_wagonNumberTable ADD COLUMN max_speed REAL');
      await db
          .execute('ALTER TABLE $_wagonNumberTable ADD COLUMN length REAL');
    }
  }

  // Vytvoření nového soupisu
  static Future<String> createInventory(String name,
      {String? notes, String? location}) async {
    await initDatabase();

    final inventoryId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    await _database!.insert(
      _inventoryTable,
      {
        'id': inventoryId,
        'name': name,
        'created_at': now.toIso8601String(),
        'last_modified': now.toIso8601String(),
        'notes': notes,
        'location': location,
      },
    );

    return inventoryId;
  }

  // Hromadné přidání čísel vozů do soupisu s transakcí
  static Future<void> addWagonNumbersBatch(
    String inventoryId,
    List<Map<String, dynamic>>
        wagonData, // [{number, formatted, isValid, order, notes}]
  ) async {
    await initDatabase();

    final insertedWagons = <Map<String, dynamic>>[];

    try {
      // Začátek transakce
      await _database!.transaction((txn) async {
        debugPrint('Začínám hromadný zápis ${wagonData.length} čísel vozů');

        // Získání existujících čísel pro kontrolu duplicít
        final existingWagons = await txn.query(
          _wagonNumberTable,
          where: 'inventory_id = ?',
          whereArgs: [inventoryId],
          columns: ['number'],
          orderBy: 'order_number DESC',
        );

        final existingNumbers =
            existingWagons.map((row) => row['number'] as String).toSet();
        final nextOrderNumber = existingWagons.length + 1;

        // Hromadný zápis pouze unikátních čísel
        int duplicatesSkipped = 0;
        int actualOrderNumber = nextOrderNumber;
        for (final wagon in wagonData) {
          final wagonNumber = wagon['number'] as String;

          // Kontrola duplicity
          if (existingNumbers.contains(wagonNumber)) {
            debugPrint('Duplicitní vůz přeskočen: $wagonNumber');
            duplicatesSkipped++;
            continue;
          }

          await txn.insert(
            _wagonNumberTable,
            {
              'inventory_id': inventoryId,
              'number': wagon['number'],
              'formatted_number': wagon['formatted'],
              'is_valid': wagon['isValid'] ? 1 : 0,
              'order_number':
                  actualOrderNumber, // Použijeme skutečné pořadové číslo
              'scanned_at': DateTime.now().toIso8601String(),
              'notes': wagon['notes'] ?? '',
              'weight': wagon['weight'],
              'brake_weight_g': wagon['brakeWeightG'],
              'brake_weight_p': wagon['brakeWeightP'],
              'handbrake': (wagon['handbrake'] as bool? ?? false) ? 1 : 0,
              'handbrake_kn': wagon['handbrakeForceKn'],
              'max_speed': wagon['maxSpeed'],
              'length': wagon['length'],
            },
          );

          insertedWagons.add(wagon);

          // Přidáme do existujících čísel, aby se neopakovala duplicita v rámci této transakce
          existingNumbers.add(wagonNumber);
          actualOrderNumber++; // Inkrementujeme skutečné pořadové číslo
        }

        if (duplicatesSkipped > 0) {
          debugPrint('Přeskočeno $duplicatesSkipped duplicitních čísel vozů');
        }
      });

      debugPrint('Hromadný zápis dokončen');

      // Aktualizace poslední změny soupisu
      await updateLastModified(inventoryId);

      // Okamžitý zápis nově přidaných vozů do trvalého registru (napříč
      // soupisy) – i bez jakýchkoli informací, aby byl vůz v databázi
      // vidět hned po naskenování, ne až po prvním ručním uložení info.
      for (final wagon in insertedWagons) {
        await WagonRegistryService.upsertFromWagon(
          number: wagon['number'] as String,
          formattedNumber: wagon['formatted'] as String,
          notes: (wagon['notes'] as String?) ?? '',
          weight: wagon['weight'] as double?,
          brakeWeightG: wagon['brakeWeightG'] as double?,
          brakeWeightP: wagon['brakeWeightP'] as double?,
          handbrake: wagon['handbrake'] as bool? ?? false,
          handbrakeForceKn: wagon['handbrakeForceKn'] as double?,
          maxSpeed: wagon['maxSpeed'] as double?,
          length: wagon['length'] as double?,
        );
      }

      // Kontrola uložení
      final savedWagons = await _database!.query(
        _wagonNumberTable,
        where: 'inventory_id = ?',
        whereArgs: [inventoryId],
      );

      debugPrint(
          'Celkem čísel v soupisu $inventoryId po transakci: ${savedWagons.length}');
    } catch (e) {
      debugPrint('Chyba při hromadném ukládání čísel vozů: $e');
      rethrow;
    }
  }

  // Přidání čísla vozu do soupisu (původní metoda pro jednotlivé záznamy)
  static Future<void> addWagonNumber(
    String inventoryId,
    String number,
    String formattedNumber,
    bool isValid,
    int order, {
    String? notes,
  }) async {
    await initDatabase();

    try {
      final result = await _database!.insert(
        _wagonNumberTable,
        {
          'inventory_id': inventoryId,
          'number': number,
          'formatted_number': formattedNumber,
          'is_valid': isValid ? 1 : 0,
          'order_number': order,
          'scanned_at': DateTime.now().toIso8601String(),
          'notes': notes,
        },
      );

      debugPrint(
          'Číslo vozu uloženo do databáze: $formattedNumber (ID: $result, pořadí: $order)');

      // Aktualizace poslední změny soupisu
      await updateLastModified(inventoryId);

      // Kontrola uložení
      final savedWagons = await _database!.query(
        _wagonNumberTable,
        where: 'inventory_id = ?',
        whereArgs: [inventoryId],
      );

      debugPrint('Celkem čísel v soupisu $inventoryId: ${savedWagons.length}');
    } catch (e) {
      debugPrint('Chyba při ukládání čísla vozu: $e');
      rethrow;
    }
  }

  // Získání všech soupisů
  static Future<List<Inventory>> getAllInventories() async {
    await initDatabase();

    try {
      final List<Map<String, dynamic>> inventories =
          await _database!.query(_inventoryTable);

      List<Inventory> result = [];
      for (final inventory in inventories) {
        final wagonNumbers =
            await getWagonNumbersForInventory(inventory['id'] as String);
        result.add(Inventory(
          id: inventory['id'] as String,
          name: inventory['name'] as String,
          createdAt: DateTime.parse(inventory['created_at'] as String),
          lastModified: DateTime.parse(inventory['last_modified'] as String),
          wagonNumbers: wagonNumbers,
          notes: inventory['notes'] as String?,
          location: inventory['location'] as String?,
        ));
      }

      return result;
    } catch (e) {
      debugPrint('Chyba při načítání soupisů: $e');
      return [];
    }
  }

  // Získání čísel vozů pro daný soupis
  static Future<List<WagonNumber>> getWagonNumbersForInventory(
      String inventoryId) async {
    await initDatabase();

    try {
      final List<Map<String, dynamic>> wagonNumbers = await _database!.query(
        _wagonNumberTable,
        where: 'inventory_id = ?',
        whereArgs: [inventoryId],
        orderBy: 'order_number ASC',
      );

      debugPrint(
          'Načteno ${wagonNumbers.length} čísel vozů pro soupis $inventoryId');

      final result = wagonNumbers.map((wagon) {
        debugPrint(
            'Načítám číslo: ${wagon['formatted_number']} (pořadí: ${wagon['order_number']})');
        return WagonNumber.fromMap(wagon);
      }).toList();

      debugPrint('Úspěšně zpracováno ${result.length} čísel vozů');
      return result;
    } catch (e) {
      debugPrint('Chyba při načítání čísel vozů: $e');
      return [];
    }
  }

  // Aktualizace existujícího čísla vozu – přijímá kompletní nový stav vozu,
  // aby se při zápisu nikdy omylem nepřepsalo pole, které se nemělo měnit.
  static Future<void> updateWagonNumber(
    String inventoryId,
    WagonNumber wagon, {
    int? newOrderNumber,
  }) async {
    await initDatabase();

    try {
      final updateData = <String, dynamic>{
        'formatted_number': wagon.formattedNumber,
        'notes': wagon.notes,
        'is_valid': wagon.isValid ? 1 : 0,
        'weight': wagon.weight,
        'brake_weight_g': wagon.brakeWeightG,
        'brake_weight_p': wagon.brakeWeightP,
        'handbrake': wagon.handbrake ? 1 : 0,
        'handbrake_kn': wagon.handbrakeForceKn,
        'max_speed': wagon.maxSpeed,
        'length': wagon.length,
      };

      // Přidat nové pořadové číslo pokud je poskytnuto
      if (newOrderNumber != null) {
        updateData['order_number'] = newOrderNumber;
      }

      final result = await _database!.update(
        _wagonNumberTable,
        updateData,
        where: 'inventory_id = ? AND number = ?',
        whereArgs: [inventoryId, wagon.number],
      );

      debugPrint(
          'Číslo vozu aktualizováno: ${wagon.formattedNumber} (affected rows: $result)');

      // Aktualizace poslední změny soupisu
      await updateLastModified(inventoryId);

      // Zápis do trvalého registru vozů (napříč soupisy) – vůz v registru
      // zůstává i po smazání všech informací, jen se aktualizuje na
      // "prázdný" stav.
      await WagonRegistryService.upsertFromWagon(
        number: wagon.number,
        formattedNumber: wagon.formattedNumber,
        notes: wagon.notes ?? '',
        weight: wagon.weight,
        brakeWeightG: wagon.brakeWeightG,
        brakeWeightP: wagon.brakeWeightP,
        handbrake: wagon.handbrake,
        handbrakeForceKn: wagon.handbrakeForceKn,
        maxSpeed: wagon.maxSpeed,
        length: wagon.length,
      );
    } catch (e) {
      debugPrint('Chyba při aktualizaci čísla vozu: $e');
      rethrow;
    }
  }

  // Aktualizace poslední změny soupisu
  static Future<void> updateLastModified(String inventoryId) async {
    await initDatabase();

    await _database!.update(
      _inventoryTable,
      {
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [inventoryId],
    );
  }

  // Aktualizace názvu soupisu
  static Future<void> updateInventoryName(
      String inventoryId, String newName) async {
    await initDatabase();

    await _database!.update(
      _inventoryTable,
      {
        'name': newName,
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [inventoryId],
    );
  }

  // Smazání konkrétního vozu ze soupisu
  static Future<void> deleteWagonNumber(
      String inventoryId, String wagonNumber) async {
    await initDatabase();

    await _database!.delete(
      _wagonNumberTable,
      where: 'inventory_id = ? AND number = ?',
      whereArgs: [inventoryId, wagonNumber],
    );
  }

  // Smazání soupisu
  static Future<void> deleteInventory(String inventoryId) async {
    await initDatabase();

    await _database!.delete(
      _wagonNumberTable,
      where: 'inventory_id = ?',
      whereArgs: [inventoryId],
    );

    await _database!.delete(
      _inventoryTable,
      where: 'id = ?',
      whereArgs: [inventoryId],
    );
  }

  // Uzavření databáze
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
