import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen_full.dart';
import 'screens/scan_screen_fixed.dart';
import 'screens/inventory_list_screen.dart';
import 'services/inventory_service.dart';
import 'screens/settings_screen.dart';
import 'screens/contacts_screen.dart';
import 'services/theme_service.dart';
import 'services/tutorial_service.dart';
import 'services/permissions_service.dart';
import 'widgets/tutorial_overlay.dart';

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
  bool _tutorialActive = false;
  int _tutorialStep = 0;
  String? _demoInventoryId;
  final _navigatorKey = GlobalKey<NavigatorState>();

  // Indexy kroků, které mají konkrétní navigaci
  static const _stepSettings  = 2; // přejít do nastavení
  static const _stepScan      = 4; // přejít na scan screen
  static const _stepInventory = 7; // přejít do seznamu soupisů

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _handleFirstLaunch();
  }

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
      _demoInventoryId = await TutorialService.createDemoInventory();
      if (mounted) setState(() => _tutorialActive = true);
    }
  }

  Future<void> _advanceTutorial() async {
    final nextStep = _tutorialStep + 1;

    if (nextStep >= kTutorialSteps.length) {
      await _finishTutorial();
      return;
    }

    // Navigace na správnou obrazovku před zobrazením kroku
    switch (nextStep) {
      case _stepSettings:
        _navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/settings', (_) => false);
        break;
      case _stepScan:
        List<String> numbers = [];
        if (_demoInventoryId != null) {
          final wagons = await InventoryService.getWagonNumbersForInventory(
              _demoInventoryId!);
          numbers = wagons.map((w) => w.number).toList();
        }
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ScanScreenFixed(
              inventoryId: _demoInventoryId,
              initialWagonNumbers: numbers,
            ),
          ),
          (_) => false,
        );
        break;
      case _stepInventory:
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => InventoryListScreen(
              expandedInventoryId: _demoInventoryId,
            ),
          ),
          (_) => false,
        );
        break;
    }

    setState(() => _tutorialStep = nextStep);
  }

  Future<void> _finishTutorial() async {
    await TutorialService.markComplete();

    // Smazat demo soupis
    if (_demoInventoryId != null) {
      await TutorialService.deleteDemoInventory(_demoInventoryId!);
      _demoInventoryId = null;
    }

    _navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/', (_) => false);

    if (mounted) {
      setState(() {
        _tutorialActive = false;
        _tutorialStep = 0;
      });
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
            ),
        '/contacts': (context) => const ContactsScreen(),
      },
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (!_tutorialActive) return child!;
        return Stack(
          children: [
            child!,
            TutorialOverlay(
              step: _tutorialStep,
              onNext: _advanceTutorial,
              onSkip: _finishTutorial,
            ),
          ],
        );
      },
    );
  }
}
