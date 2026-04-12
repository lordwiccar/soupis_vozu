import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen_full.dart';
import 'screens/scan_screen_fixed.dart';
import 'screens/inventory_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/contacts_screen.dart';
import 'services/theme_service.dart';

void main() {
  // Globální uzamčení orientace na vertikální
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SoupisVozuApp());
}

class SoupisVozuApp extends StatefulWidget {
  const SoupisVozuApp({super.key});

  @override
  State<SoupisVozuApp> createState() => _SoupisVozuAppState();
}

class _SoupisVozuAppState extends State<SoupisVozuApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final themeMode = await ThemeService.getThemeMode();
    setState(() {
      _themeMode = themeMode;
    });
  }

  void updateThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    ThemeService.setThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soupis vozů',
      theme: ThemeService.getLightTheme(),
      darkTheme: ThemeService.getDarkTheme(),
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreenFull(
              onThemeChanged: updateThemeMode,
              currentTheme: _themeMode,
            ),
        '/scan': (context) => const ScanScreenFixed(),
        '/inventories': (context) => const InventoryListScreen(),
        '/settings': (context) => SettingsScreen(
              onThemeChanged: updateThemeMode,
              currentTheme: _themeMode,
            ),
        '/contacts': (context) => const ContactsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
