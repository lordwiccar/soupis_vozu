import 'dart:io';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/inventory.dart';
import '../models/wagon_registry_entry.dart';
import 'decimal_input.dart';
import 'uic_validator.dart';

/// Trvalý registr vozů, nezávislý na jednotlivých soupisech.
///
/// Jakmile se vůz jednou do registru zapíše, zůstává v něm i poté, co
/// uživatel všechny informace (poznámky, příznaky, technické údaje) smaže
/// – [upsertFromWagon] řádek jen aktualizuje na "prázdný" stav, nikdy ho
/// nemaže. Smazat záznam lze pouze ručně přes [deleteEntry] (z obrazovky
/// databáze vozů). Zda má záznam nějaké skutečné info, zjistíte přes
/// [WagonRegistryEntry.hasInfo].
class WagonRegistryService {
  static Database? _database;
  static const String _table = 'wagon_registry';

  static Future<void> initDatabase() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'wagon_registry.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        number TEXT PRIMARY KEY,
        formatted_number TEXT NOT NULL,
        notes TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        weight REAL,
        brake_weight_g REAL,
        brake_weight_p REAL,
        handbrake INTEGER NOT NULL DEFAULT 0,
        handbrake_kn REAL,
        max_speed REAL,
        length REAL
      )
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $_table ADD COLUMN weight REAL');
      await db.execute('ALTER TABLE $_table ADD COLUMN brake_weight_g REAL');
      await db.execute('ALTER TABLE $_table ADD COLUMN brake_weight_p REAL');
      await db.execute(
          'ALTER TABLE $_table ADD COLUMN handbrake INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $_table ADD COLUMN handbrake_kn REAL');
      await db.execute('ALTER TABLE $_table ADD COLUMN max_speed REAL');
      await db.execute('ALTER TABLE $_table ADD COLUMN length REAL');
    }
  }

  /// Vrátí kompletní záznam pro dané číslo vozu, nebo `null`, pokud vůz
  /// v registru není.
  static Future<WagonRegistryEntry?> getEntry(String number) async {
    await initDatabase();

    final rows = await _database!.query(
      _table,
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return WagonRegistryEntry.fromMap(rows.first);
  }

  /// Zapíše aktuální stav informací o voze do registru. Vůz v registru
  /// zůstává, i když jsou všechna pole prázdná – řádek se jen aktualizuje
  /// na "prázdný" stav, nikdy se automaticky nemaže (viz [deleteEntry]).
  static Future<void> upsertFromWagon({
    required String number,
    required String formattedNumber,
    required String notes,
    double? weight,
    double? brakeWeightG,
    double? brakeWeightP,
    bool handbrake = false,
    double? handbrakeForceKn,
    double? maxSpeed,
    double? length,
  }) async {
    await initDatabase();

    try {
      await _database!.insert(
        _table,
        {
          'number': number,
          'formatted_number': formattedNumber,
          'notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
          'weight': weight,
          'brake_weight_g': brakeWeightG,
          'brake_weight_p': brakeWeightP,
          'handbrake': handbrake ? 1 : 0,
          'handbrake_kn': handbrake ? handbrakeForceKn : null,
          'max_speed': maxSpeed,
          'length': length,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Chyba při ukládání vozu do registru: $e');
      rethrow;
    }
  }

  /// Ruční smazání záznamu (z obrazovky databáze vozů).
  static Future<void> deleteEntry(String number) async {
    await initDatabase();
    await _database!.delete(
      _table,
      where: 'number = ?',
      whereArgs: [number],
    );
  }

  static Future<List<WagonRegistryEntry>> getAll() async {
    await initDatabase();

    final rows = await _database!.query(_table, orderBy: 'updated_at DESC');
    return rows.map((row) => WagonRegistryEntry.fromMap(row)).toList();
  }

  static Future<int> count() async {
    await initDatabase();
    final result =
        await _database!.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─── EXPORT / IMPORT (.xlsx) ────────────────────────────────────────────

  static const String _sheetName = 'Databáze vozů';
  static const List<String> _header = [
    'Číslo vozu',
    'Příznaky',
    'Poznámka',
    'Hmotnost vozu (t)',
    'Brzdící váha G (t)',
    'Brzdící váha P (t)',
    'Ruční brzda',
    'Ruční brzda (kN)',
    'Rychlost (km/h)',
    'Délka (m)',
    'Aktualizováno',
  ];

  /// Vygeneruje .xlsx soubor se všemi záznamy registru a vrátí ho jako
  /// dočasný soubor připravený ke sdílení.
  static Future<File> exportToXlsx() async {
    final entries = await getAll();

    final workbook = xlsx.Excel.createExcel();
    final sheet = workbook[_sheetName];
    for (final defaultSheet in List<String>.from(workbook.sheets.keys)) {
      if (defaultSheet != _sheetName) workbook.delete(defaultSheet);
    }

    sheet.appendRow(_header.map((h) => xlsx.TextCellValue(h)).toList());

    for (final entry in entries) {
      final parsed = WagonNumber.parseNotes(entry.notes);
      sheet.appendRow([
        xlsx.TextCellValue(entry.formattedNumber),
        xlsx.TextCellValue(parsed.flags.join(', ')),
        xlsx.TextCellValue(parsed.text),
        xlsx.TextCellValue(formatDecimal(entry.weight)),
        xlsx.TextCellValue(formatDecimal(entry.brakeWeightG)),
        xlsx.TextCellValue(formatDecimal(entry.brakeWeightP)),
        xlsx.TextCellValue(entry.handbrake ? 'ano' : 'ne'),
        xlsx.TextCellValue(formatDecimal(entry.handbrakeForceKn)),
        xlsx.TextCellValue(formatDecimal(entry.maxSpeed)),
        xlsx.TextCellValue(formatDecimal(entry.length)),
        xlsx.TextCellValue(entry.updatedAt.toIso8601String()),
      ]);
    }

    final bytes = workbook.save();
    if (bytes == null) {
      throw Exception('Nepodařilo se vygenerovat .xlsx soubor');
    }

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(dir.path, 'databaze_vozu_$timestamp.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Naimportuje záznamy z .xlsx souboru. Vozy, které v registru už
  /// existují, se ponechají beze změny – doplní se jen dosud neznámé.
  static Future<WagonImportResult> importFromXlsx(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final workbook = xlsx.Excel.decodeBytes(bytes);

    if (workbook.tables.isEmpty) {
      return const WagonImportResult(
          added: 0, skippedExisting: 0, invalidRows: 0);
    }

    final sheet = workbook.tables[workbook.tables.keys.first]!;

    int added = 0;
    int skippedExisting = 0;
    int invalidRows = 0;

    for (var i = 0; i < sheet.rows.length; i++) {
      if (i == 0) continue; // hlavička

      final row = sheet.rows[i];
      final numberCell = row.isNotEmpty ? _cellText(row[0]) : '';
      final flagsCell = row.length > 1 ? _cellText(row[1]) : '';
      final textCell = row.length > 2 ? _cellText(row[2]) : '';
      final weightCell = row.length > 3 ? _cellText(row[3]) : '';
      final brakeGCell = row.length > 4 ? _cellText(row[4]) : '';
      final brakePCell = row.length > 5 ? _cellText(row[5]) : '';
      final handbrakeCell = row.length > 6 ? _cellText(row[6]) : '';
      final handbrakeKnCell = row.length > 7 ? _cellText(row[7]) : '';
      final speedCell = row.length > 8 ? _cellText(row[8]) : '';
      final lengthCell = row.length > 9 ? _cellText(row[9]) : '';

      final digits = numberCell.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length != 12) {
        if (numberCell.trim().isNotEmpty) invalidRows++;
        continue;
      }

      final flags = flagsCell
          .split(',')
          .map((f) => f.trim())
          .where((f) => WagonNumber.allFlags.contains(f))
          .toList();
      final notes = WagonNumber.composeNotes(flags, textCell.trim());

      final weight = parseDecimal(weightCell);
      final brakeWeightG = parseDecimal(brakeGCell);
      final brakeWeightP = parseDecimal(brakePCell);
      final handbrake = handbrakeCell.trim().toLowerCase() == 'ano';
      final handbrakeForceKn = parseDecimal(handbrakeKnCell);
      final maxSpeed = parseDecimal(speedCell);
      final length = parseDecimal(lengthCell);

      final hasInfo = notes.trim().isNotEmpty ||
          weight != null ||
          brakeWeightG != null ||
          brakeWeightP != null ||
          handbrake ||
          maxSpeed != null ||
          length != null;
      if (!hasInfo) continue;

      // "Ponechat existující" se vztahuje jen na vozy, které už mají
      // skutečné info – "prázdný" záznam v registru import klidně doplní.
      final existing = await getEntry(digits);
      if (existing != null && existing.hasInfo) {
        skippedExisting++;
        continue;
      }

      await upsertFromWagon(
        number: digits,
        formattedNumber: UicValidator.formatUicNumber(digits),
        notes: notes,
        weight: weight,
        brakeWeightG: brakeWeightG,
        brakeWeightP: brakeWeightP,
        handbrake: handbrake,
        handbrakeForceKn: handbrakeForceKn,
        maxSpeed: maxSpeed,
        length: length,
      );
      added++;
    }

    return WagonImportResult(
      added: added,
      skippedExisting: skippedExisting,
      invalidRows: invalidRows,
    );
  }

  static String _cellText(xlsx.Data? cell) => cell?.value?.toString() ?? '';

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
