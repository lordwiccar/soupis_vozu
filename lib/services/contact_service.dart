import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/contact.dart';

class ContactService {
  static Database? _database;
  static const String _contactTable = 'contacts';

  static Future<void> initDatabase() async {
    if (_database != null) return;

    final path = await getContactsPath();
    _database = await openDatabase(
      path,
      version: 2, // Zvýšit verzi pro migraci
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
        created_at TEXT NOT NULL
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
        'is_copy_recipient': (isCopyRecipient ? 1 : 0).toString(),
        'created_at': now.toIso8601String(),
      },
    );

    return contactId;
  }

  static Future<void> updateContact(String id, String name, String email,
      {bool? isCopyRecipient}) async {
    await initDatabase();
    final updateData = {
      'name': name,
      'email': email,
    };

    if (isCopyRecipient != null) {
      updateData['is_copy_recipient'] = (isCopyRecipient ? 1 : 0).toString();
    }

    await _database!.update(
      _contactTable,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteContact(String id) async {
    await initDatabase();
    await _database!.delete(
      _contactTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
