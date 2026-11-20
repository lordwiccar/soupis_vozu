import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen_full.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen_fixed.dart';
import 'screens/inventory_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/contacts_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/theme_service.dart';
import 'services/tutorial_service.dart';
import 'services/tutorial_controller.dart';
import 'services/permissions_service.dart';
import 'services/changelog_service.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/changelog_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bez explicitních options – na Androidu se konfigurace načte
  // z google-services.json podle varianty buildu (release i debug balíček
  // jsou ve Firebase zaregistrované zvlášť).
  await Firebase.initializeApp();
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
  }

  /// Volá [_AuthGate], jakmile je uživatel přihlášený a data připravená.
  void _onSignedIn() {
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
      return;
    }

    if (!mounted) return;

    // Changelog — po aktualizaci appky (ne při úplně první instalaci, tu už
    // pokrývá tutoriál výše) zobrazíme při prvním spuštění přehled novinek.
    if (await ChangelogService.wasUpdated()) {
      if (!mounted) return;
      await showChangelogDialog(_navigatorKey.currentContext!);
      await ChangelogService.markCurrentVersionSeen();
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
        '/': (context) => _AuthGate(
              onSignedIn: _onSignedIn,
              onSynced: _loadThemeMode,
              homeBuilder: () => HomeScreenFull(
                onThemeChanged: updateThemeMode,
                currentTheme: _themeMode,
              ),
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

/// Povinné přihlášení: bez přihlášeného Google účtu ukáže přihlašovací
/// obrazovku. Po přihlášení stáhne data z cloudu – při prvním přihlášení
/// na zařízení s čekací obrazovkou, jinak na pozadí.
class _AuthGate extends StatefulWidget {
  final VoidCallback onSignedIn;
  final VoidCallback onSynced;
  final Widget Function() homeBuilder;

  const _AuthGate({
    required this.onSignedIn,
    required this.onSynced,
    required this.homeBuilder,
  });

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final StreamSubscription<User?> _subscription;
  User? _user = AuthService.currentUser;
  String? _syncedUid;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _subscription = AuthService.authStateChanges().listen(_onAuthChanged);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;
    setState(() => _user = user);
    if (user == null) {
      _syncedUid = null;
      return;
    }
    if (user.uid == _syncedUid) return;
    _syncedUid = user.uid;

    final initial = await CloudSyncService.needsInitialSync(user.uid);
    final sync = CloudSyncService.onSignedIn(user.uid).catchError((Object e) {
      // Bez signálu – appka pracuje s lokálními daty, synchronizace se
      // zopakuje při dalším startu.
      debugPrint('Synchronizace po přihlášení selhala: $e');
    });

    if (initial) {
      if (mounted) setState(() => _syncing = true);
      await sync;
      if (!mounted) return;
      setState(() => _syncing = false);
      widget.onSignedIn();
    } else {
      widget.onSignedIn();
      await sync;
      if (mounted) widget.onSynced();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const LoginScreen();
    if (_syncing) return const SyncingScreen();
    return widget.homeBuilder();
  }
}
