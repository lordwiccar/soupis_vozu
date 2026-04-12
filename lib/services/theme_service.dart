import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';

  // Získání uloženého tématu
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;

    switch (themeIndex) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      case 2:
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  // Uložení tématu
  static Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    int themeIndex;

    switch (themeMode) {
      case ThemeMode.light:
        themeIndex = 0;
        break;
      case ThemeMode.dark:
        themeIndex = 1;
        break;
      case ThemeMode.system:
        themeIndex = 2;
        break;
    }

    await prefs.setInt(_themeKey, themeIndex);
  }

  // Získání názvu tématu pro zobrazení
  static String getThemeDisplayName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Světlý motiv';
      case ThemeMode.dark:
        return 'Tmavý motiv';
      case ThemeMode.system:
        return 'Adaptace podle systému';
    }
  }

  // Vytvoření světlého tématu s fialovou paletou
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F1F0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
      ),
    );
  }

  // Vytvoření tmavého tématu s fialovou paletou
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D2130),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF591664),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade600,
          foregroundColor: Colors.white,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF122C40),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Color(0xFF122C40),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
    );
  }
}
