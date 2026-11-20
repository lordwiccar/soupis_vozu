import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_service.dart';

/// Synchronizace nastavení appky s cloudem – jeden dokument
/// `users/{uid}/settings/app`.
///
/// Synchronizují se nastavení, která patří uživateli (motiv, velikost čísel
/// ve výpisu skenování, režim skenování, AI model a API klíč, dokončený
/// tutoriál). Stav vázaný na konkrétní zařízení (udělená oprávnění, poslední
/// zobrazený changelog) se nesynchronizuje.
class SettingsSync {
  static const String docId = 'app';
  static const String _updatedAtKey = 'settings_updated_at';

  static const List<String> _intKeys = ['theme_mode', 'scan_list_font_step'];
  static const List<String> _stringKeys = ['scan_mode', 'ai_provider'];
  static const List<String> _boolKeys = [
    'onboarding_v1',
    'scan_list_highlight_last4',
  ];
  static const String _apiKeyKey = 'ai_api_key';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Volá se po každé změně nastavení – uloží čas změny a odešle nastavení
  /// do cloudu.
  static Future<void> markChanged() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_updatedAtKey, now.toIso8601String());
    final data = await getSyncData(docId);
    if (data != null) {
      CloudSyncService.pushDoc(CloudSyncService.settings, docId, data, now);
    }
  }

  static Future<Map<String, DateTime>> getSyncStamps() async {
    final prefs = await SharedPreferences.getInstance();
    // Nastavení z doby před synchronizací nemá čas změny – bere se jako
    // nejstarší možné, takže ho přepíše jakékoliv nastavení z cloudu.
    final stamp = DateTime.tryParse(prefs.getString(_updatedAtKey) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return {docId: stamp};
  }

  static Future<Map<String, dynamic>?> getSyncData(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in _intKeys) key: prefs.getInt(key),
      for (final key in _stringKeys) key: prefs.getString(key),
      for (final key in _boolKeys) key: prefs.getBool(key),
      _apiKeyKey: await _secure.read(key: _apiKeyKey),
    };
  }

  static Future<void> applyRemote(
      String id, Map<String, dynamic> data, DateTime updatedAt) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _intKeys) {
      final value = data[key];
      value is int ? await prefs.setInt(key, value) : await prefs.remove(key);
    }
    for (final key in _stringKeys) {
      final value = data[key];
      value is String
          ? await prefs.setString(key, value)
          : await prefs.remove(key);
    }
    for (final key in _boolKeys) {
      final value = data[key];
      value is bool ? await prefs.setBool(key, value) : await prefs.remove(key);
    }
    final apiKey = data[_apiKeyKey];
    if (apiKey is String && apiKey.isNotEmpty) {
      await _secure.write(key: _apiKeyKey, value: apiKey);
    } else {
      await _secure.delete(key: _apiKeyKey);
    }

    await prefs.setString(_updatedAtKey, updatedAt.toLocal().toIso8601String());
  }
}
