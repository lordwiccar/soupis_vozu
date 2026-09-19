import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen_full.dart';
import 'screens/scan_screen_fixed.dart';
import 'screens/inventory_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/contacts_screen.dart';
import 'services/theme_service.dart';
import 'services/tutorial_service.dart';
import 'services/tutorial_controller.dart';
import 'services/permissions_service.dart';
import 'widgets/spotlight_overlay.dart';

void main() {
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
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final TutorialController _tutorialController;

  @override
  void initState() {
    super.initState();
    _tutorialController = TutorialController(_navigatorKey)
      ..addListener(_onTutorialChanged);
    _loadThemeMode();
    _handleFirstLaunch();
  }

  @override
  void dispose() {
    _tutorialController.removeListener(_onTutorialChanged);
    _tutorialController.dispose();
    super.dispose();
  }

  void _onTutorialChanged() => setState(() {});

  Future<void> _loadThemeMode() async {
    final themeMode = await ThemeService.getThemeMode();
    if (mounted) setState(() => _themeMode = themeMode);
  }

  Future<void> _handleFirstLaunch() async {
    // Krátká prodleva aby se aplikace stihla vykreslit
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // Oprávnění — zeptáme se při úplně prvním spuštění
    if (await PermissionsService.shouldRequest()) {
      await PermissionsService.requestAll(_navigatorKey.currentContext!);
    }

    if (!mounted) return;

    // Tutorial — zobrazíme při úplně prvním spuštění
    if (await TutorialService.shouldShow()) {
      await _tutorialController.start();
    }
  }

  void updateThemeMode(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
    ThemeService.setThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
              onReplayTutorial: _tutorialController.start,
            ),
        '/contacts': (context) => const ContactsScreen(),
      },
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (!_tutorialController.active) return child!;
        return Stack(
          children: [
            child!,
            SpotlightOverlay(controller: _tutorialController),
          ],
        );
      },
    );
  }
}
