import 'package:shared_preferences/shared_preferences.dart';

import 'settings_sync.dart';

/// Nastavení vzhledu výpisu vozů na obrazovce skenování (karta Vzhled
/// v Nastavení).
class AppearanceService {
  static const String scanFontStepKey = 'scan_list_font_step';
  static const String highlightLast4Key = 'scan_list_highlight_last4';

  /// Velikosti písma čísel vozů pro jednotlivé stupně. Největší stupeň je
  /// zvolený tak, aby se číslo i se všemi stavovými ikonami vešlo celé na
  /// displej široký 360 dp; na užších displejích (nebo při zvětšeném
  /// systémovém písmu) se číslo zkrátí zleva – viz `WagonNumberText`.
  static const List<double> scanFontSizes = [15, 18, 21, 24];
  static const List<String> scanFontLabels = [
    'Normální',
    'Větší',
    'Velká',
    'Největší',
  ];

  static Future<int> getScanFontStep() async {
    final prefs = await SharedPreferences.getInstance();
    final step = prefs.getInt(scanFontStepKey) ?? 0;
    return step.clamp(0, scanFontSizes.length - 1);
  }

  static Future<void> setScanFontStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        scanFontStepKey, step.clamp(0, scanFontSizes.length - 1));
    await SettingsSync.markChanged();
  }

  static Future<bool> getHighlightLast4() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(highlightLast4Key) ?? false;
  }

  static Future<void> setHighlightLast4(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(highlightLast4Key, value);
    await SettingsSync.markChanged();
  }
}
