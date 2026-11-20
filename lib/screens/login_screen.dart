import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/theme_service.dart';

/// Povinné přihlášení Google účtem – bez něj appka nepustí dál. Data se
/// pod účtem ukládají do cloudu a synchronizují mezi zařízeními.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
      // Po úspěšném přihlášení obrazovku nahradí appka sama (sleduje stav
      // přihlášení).
    } on FirebaseAuthException catch (e) {
      _error = 'Přihlášení se nezdařilo (${e.code}).';
    } catch (e) {
      _error = 'Přihlášení se nezdařilo. Zkontrolujte připojení k internetu.';
      debugPrint('Chyba přihlášení: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/splash.png', height: 120),
                  const SizedBox(height: 24),
                  Text('Soupis vozů',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    'Přihlaste se Google účtem. Soupisy, databáze vozů, '
                    'adresář i nastavení se pod ním zálohují do cloudu '
                    'a jsou dostupné na všech vašich zařízeních.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: ThemeService.kRailAmber,
                        foregroundColor: ThemeService.kRailBlack,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Přihlásit se přes Google'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zobrazí se při prvním přihlášení na zařízení, než se stáhnou data
/// z cloudu.
class SyncingScreen extends StatelessWidget {
  const SyncingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Načítám vaše data z cloudu…'),
          ],
        ),
      ),
    );
  }
}
