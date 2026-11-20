import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/contact.dart';
import 'cloud_sync_service.dart';

class ContactService {
  static Database? _database;
  static const String _contactTable = 'contacts';

  static Future<void> initDatabase() async {
    if (_database != null) return;

    final path = await getContactsPath();
    _database = await openDatabase(
      path,
      version: 3, // Zvýšit verzi pro migraci
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<String> getContactsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/contacts.db';
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_contactTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        is_copy_recipient INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Migrace pro existující databáze
    if (oldVersion < 2) {
      // Přidání nového sloupce is_copy_recipient
      await db.execute(
          'ALTER TABLE $_contactTable ADD COLUMN is_copy_recipient INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Čas poslední změny pro synchronizaci s cloudem
      await db.execute(
          'ALTER TABLE $_contactTable ADD COLUMN updated_at TEXT NOT NULL DEFAULT ""');
      await db.execute(
          'UPDATE $_contactTable SET updated_at = created_at WHERE updated_at = ""');
    }
  }

  static Future<List<Contact>> getAllContacts() async {
    await initDatabase();
    final List<Map<String, dynamic>> maps =
        await _database!.query(_contactTable);
    return List.generate(maps.length, (i) {
      return Contact.fromMap(maps[i]);
    });
  }

  static Future<String> createContact(String name, String email,
      {bool isCopyRecipient = false}) async {
    await initDatabase();
    final contactId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    await _database!.insert(
      _contactTable,
      {
        'id': contactId,
        'name': name,
        'email': email,
        'is_copy_recipient': isCopyRecipient ? 1 : 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
    await _pushContact(contactId);

    return contactId;
  }

  static Future<void> updateContact(String id, String name, String email,
      {bool? isCopyRecipient}) async {
    await initDatabase();
    final updateData = <String, Object>{
      'name': name,
      'email': email,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (isCopyRecipient != null) {
      updateData['is_copy_recipient'] = isCopyRecipient ? 1 : 0;
    }

    await _database!.update(
      _contactTable,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _pushContact(id);
  }

  static Future<void> deleteContact(String id) async {
    await deleteLocal(id);
    CloudSyncService.pushDeleted(CloudSyncService.contacts, id);
  }

  // ─── SYNCHRONIZACE S CLOUDEM (viz CloudSyncService) ─────────────────────

  static Future<void> _pushContact(String id) async {
    final data = await getSyncData(id);
    if (data == null) return;
    CloudSyncService.pushDoc(CloudSyncService.contacts, id, data,
        DateTime.parse(data['updated_at'] as String));
  }

  /// Čas poslední změny každého kontaktu podle ID.
  static Future<Map<String, DateTime>> getSyncStamps() async {
    await initDatabase();
    final rows =
        await _database!.query(_contactTable, columns: ['id', 'updated_at']);
    return {
      for (final row in rows)
        row['id'] as String: DateTime.parse(row['updated_at'] as String),
    };
  }

  static Future<Map<String, dynamic>?> getSyncData(String id) async {
    await initDatabase();
    final rows = await _database!.query(
      _contactTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Zapíše kontakt stažený z cloudu (bez odeslání zpět).
  static Future<void> applyRemote(
      String id, Map<String, dynamic> data, DateTime updatedAt) async {
    await initDatabase();
    await _database!.insert(
      _contactTable,
      {
        'id': id,
        'name': data['name'],
        'email': data['email'],
        'is_copy_recipient': data['is_copy_recipient'] ?? 0,
        'created_at': data['created_at'],
        'updated_at': updatedAt.toLocal().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Smaže kontakt jen lokálně (smazání přišlo z cloudu).
  static Future<void> deleteLocal(String id) async {
    await initDatabase();
    await _database!.delete(
      _contactTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Smaže všechny lokální kontakty (odhlášení / změna účtu).
  static Future<void> clearAll() async {
    await initDatabase();
    await _database!.delete(_contactTable);
  }
}
