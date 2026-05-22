import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ScanMode { quick, quality }

enum AiProvider { openai, claude }

class ScanSettingsService {
  static const _modeKey = 'scan_mode';
  static const _providerKey = 'ai_provider';
  static const _apiKeyKey = 'ai_api_key';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<ScanMode> getScanMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modeKey) == 'quality'
        ? ScanMode.quality
        : ScanMode.quick;
  }

  static Future<void> setScanMode(ScanMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _modeKey, mode == ScanMode.quality ? 'quality' : 'quick');
  }

  static Future<AiProvider?> getAiProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_providerKey);
    if (value == 'openai') return AiProvider.openai;
    if (value == 'claude') return AiProvider.claude;
    return null;
  }

  static Future<void> setAiProvider(AiProvider? provider) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == null) {
      await prefs.remove(_providerKey);
    } else {
      await prefs.setString(
          _providerKey, provider == AiProvider.openai ? 'openai' : 'claude');
    }
  }

  static Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  static Future<void> setApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _apiKeyKey);
    } else {
      await _storage.write(key: _apiKeyKey, value: key);
    }
  }
}
