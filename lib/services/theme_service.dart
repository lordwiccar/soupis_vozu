import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  // --- Industrial Railway Color Palette ---
  static const Color kRailBlack    = Color(0xFF12181E); // ocelově černá
  static const Color kRailCharcoal = Color(0xFF1C2730); // tmavý povrch
  static const Color kRailSteel    = Color(0xFF2C3A47); // střední ocel
  static const Color kRailAmber    = Color(0xFFF0A500); // jantarové návěstidlo
  static const Color kRailAmberDim = Color(0xFFD4900A); // ztlumená jantarová
  static const Color kRailCream    = Color(0xFFF0EAE2); // teplá bílá / beton
  static const Color kRailSlate    = Color(0xFF4A90B8); // ocelová modrá (info)
  static const Color kRailDeepDark = Color(0xFF0E1318); // nejhlubší tmavá

  static const Color kValidGreen = Color(0xFF4CAF50);
  static const Color kValidRed   = Color(0xFFE53935);

  static const Widget amberStripe =
      SizedBox(height: 3, child: ColoredBox(color: kRailAmber));

  static const String _themeKey = 'theme_mode';

  // Získání uloženého tématu
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    switch (themeIndex) {
      case 1:  return ThemeMode.dark;
      case 2:  return ThemeMode.system;
      default: return ThemeMode.light;
    }
  }

  // Uložení tématu
  static Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    final int themeIndex;
    switch (themeMode) {
      case ThemeMode.dark:   themeIndex = 1; break;
      case ThemeMode.system: themeIndex = 2; break;
      default:               themeIndex = 0;
    }
    await prefs.setInt(_themeKey, themeIndex);
  }

  // Získání názvu tématu pro zobrazení
  static String getThemeDisplayName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:  return 'Světlý motiv';
      case ThemeMode.dark:   return 'Tmavý motiv';
      case ThemeMode.system: return 'Adaptace podle systému';
    }
  }

  // --- Typography (Barlow Condensed pro nadpisy, Barlow pro text) ---
  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge:  GoogleFonts.barlowCondensed(fontSize: 32, fontWeight: FontWeight.w700, color: color),
      displayMedium: GoogleFonts.barlowCondensed(fontSize: 28, fontWeight: FontWeight.w700, color: color),
      displaySmall:  GoogleFonts.barlowCondensed(fontSize: 24, fontWeight: FontWeight.w600, color: color),
      headlineLarge: GoogleFonts.barlowCondensed(fontSize: 24, fontWeight: FontWeight.w700, color: color),
      headlineMedium:GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w700, color: color),
      headlineSmall: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w600, color: color),
      titleLarge:    GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.4),
      titleMedium:   GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w600, color: color),
      titleSmall:    GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      bodyLarge:     GoogleFonts.barlow(fontSize: 16, fontWeight: FontWeight.w400, color: color),
      bodyMedium:    GoogleFonts.barlow(fontSize: 14, fontWeight: FontWeight.w400, color: color),
      bodySmall:     GoogleFonts.barlow(fontSize: 12, fontWeight: FontWeight.w400, color: color.withValues(alpha: 0.7)),
      labelLarge:    GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8),
      labelMedium:   GoogleFonts.barlowCondensed(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      labelSmall:    GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.7), letterSpacing: 0.4),
    );
  }

  // --- Světlé téma ---
  static ThemeData getLightTheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: kRailBlack,
      brightness: Brightness.light,
    ).copyWith(
      primary:            kRailBlack,
      onPrimary:          kRailCream,
      primaryContainer:   kRailAmber,
      onPrimaryContainer: kRailBlack,
      secondary:          kRailAmber,
      onSecondary:        kRailBlack,
      tertiary:           kRailSlate,
      onTertiary:         Colors.white,
      surface:            Colors.white,
      onSurface:          kRailBlack,
      error:              const Color(0xFFB00020),
      onError:            Colors.white,
      inversePrimary:     kRailAmber,
      outline:            const Color(0xFF8A7E74),
      outlineVariant:     const Color(0xFFD4C8BE),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: kRailCream,
      textTheme: _buildTextTheme(kRailBlack),

      appBarTheme: AppBarTheme(
        backgroundColor: kRailBlack,
        foregroundColor: kRailAmber,
        elevation: 0,
        centerTitle: false,
        iconTheme:        const IconThemeData(color: kRailAmber),
        actionsIconTheme: const IconThemeData(color: kRailAmber),
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 22, fontWeight: FontWeight.w700,
          color: kRailAmber, letterSpacing: 0.8,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kRailAmber,
          foregroundColor: kRailBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kRailBlack,
          side: const BorderSide(color: kRailBlack, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kRailBlack,
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kRailAmber,
        foregroundColor: kRailBlack,
        elevation: 4,
      ),

      chipTheme: ChipThemeData(
        selectedColor: kRailAmber,
        backgroundColor: const Color(0xFFE8E0D8),
        side: const BorderSide(color: Color(0xFFD4C8BE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w600, color: kRailBlack,
        ),
        secondaryLabelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w600, color: kRailBlack,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF8A7E74)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: kRailAmber, width: 2),
        ),
        labelStyle: GoogleFonts.barlow(color: const Color(0xFF5A4E45)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      listTileTheme: const ListTileThemeData(tileColor: Colors.white),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFD4C8BE), thickness: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 20, fontWeight: FontWeight.w700, color: kRailBlack,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: kRailAmber,
        unselectedLabelColor: Colors.white54,
        indicatorColor: kRailAmber,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w500,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return kRailAmber;
          return null;
        }),
        checkColor: WidgetStateProperty.all(kRailBlack),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: kRailCharcoal,
        contentTextStyle: GoogleFonts.barlow(color: kRailCream, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kRailAmber,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: kRailAmber),
      ),
    );
  }

  // --- Tmavé téma ---
  static ThemeData getDarkTheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: kRailAmber,
      brightness: Brightness.dark,
    ).copyWith(
      primary:            kRailAmber,
      onPrimary:          kRailBlack,
      primaryContainer:   kRailAmberDim,
      onPrimaryContainer: kRailCream,
      secondary:          kRailSlate,
      onSecondary:        Colors.white,
      tertiary:           const Color(0xFF6DBF9E),
      onTertiary:         kRailBlack,
      surface:            kRailCharcoal,
      onSurface:          kRailCream,
      error:              const Color(0xFFFF6B6B),
      onError:            kRailBlack,
      inversePrimary:     kRailAmber,
      outline:            const Color(0xFF566570),
      outlineVariant:     const Color(0xFF2C3A47),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: kRailDeepDark,
      textTheme: _buildTextTheme(kRailCream),

      appBarTheme: AppBarTheme(
        backgroundColor: kRailCharcoal,
        foregroundColor: kRailAmber,
        elevation: 0,
        centerTitle: false,
        iconTheme:        const IconThemeData(color: kRailAmber),
        actionsIconTheme: const IconThemeData(color: kRailAmber),
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 22, fontWeight: FontWeight.w700,
          color: kRailAmber, letterSpacing: 0.8,
        ),
      ),

      cardTheme: CardThemeData(
        color: kRailCharcoal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF2C3A47), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kRailAmber,
          foregroundColor: kRailBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kRailCream,
          side: BorderSide(color: kRailCream.withValues(alpha: 0.4), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kRailAmber,
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kRailAmber,
        foregroundColor: kRailBlack,
        elevation: 4,
      ),

      chipTheme: ChipThemeData(
        selectedColor: kRailAmber,
        backgroundColor: const Color(0xFF2C3A47),
        side: const BorderSide(color: Color(0xFF3C4E5E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w600, color: kRailCream,
        ),
        secondaryLabelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w600, color: kRailBlack,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kRailCharcoal,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF566570)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: kRailAmber, width: 2),
        ),
        labelStyle: GoogleFonts.barlow(color: const Color(0xFFB8A898)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      listTileTheme: const ListTileThemeData(tileColor: kRailCharcoal),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C3A47), thickness: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: kRailCharcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 20, fontWeight: FontWeight.w700, color: kRailAmber,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: kRailAmber,
        unselectedLabelColor: Colors.white38,
        indicatorColor: kRailAmber,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.barlowCondensed(
          fontSize: 13, fontWeight: FontWeight.w500,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return kRailAmber;
          return null;
        }),
        checkColor: WidgetStateProperty.all(kRailBlack),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: kRailSteel,
        contentTextStyle: GoogleFonts.barlow(color: kRailCream, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kRailAmber,
      ),

      iconTheme: const IconThemeData(color: kRailAmber),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: kRailAmber),
      ),
    );
  }
}
