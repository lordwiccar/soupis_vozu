import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_sync_service.dart';

/// Přihlášení Google účtem přes Firebase Authentication.
class AuthService {
  /// Webový OAuth klient Firebase projektu `databaze-vozu` – Google Sign-In
  /// pro něj vydá ID token, kterým se pak přihlásí Firebase Auth.
  static const String _serverClientId =
      '618095206925-drh154p53gh5uihvmmeufmaajdjg15sp.apps.googleusercontent.com';

  static Future<void>? _initialization;

  static Future<void> _ensureInitialized() {
    return _initialization ??=
        GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
  }

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static Stream<User?> authStateChanges() =>
      FirebaseAuth.instance.authStateChanges();

  /// Otevře výběr Google účtu a přihlásí ho do Firebase. Vrací `null`, pokud
  /// uživatel výběr zrušil.
  static Future<User?> signInWithGoogle() async {
    await _ensureInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return result.user;
  }

  /// Nevratně smaže účet: všechna data v cloudu, účet ve Firebase
  /// Authentication i lokální data v zařízení. Firebase smazání účtu
  /// povolí jen krátce po přihlášení, proto se uživatel nejdřív znovu
  /// ověří Google účtem. Vrací `false`, pokud ověření zrušil.
  static Future<bool> deleteAccount() async {
    await _ensureInitialized();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken));

    // Čekající zápisy by jinak po smazání data v cloudu znovu vytvořily.
    await FirebaseFirestore.instance.waitForPendingWrites();
    await CloudSyncService.deleteCloudData();
    await user.delete();
    await GoogleSignIn.instance.disconnect();
    await CloudSyncService.clearLocalData();
    return true;
  }

  /// Odhlásí uživatele a smaže lokální data (zůstávají v cloudu). Čekající
  /// změny je potřeba odeslat předem – viz
  /// [CloudSyncService.waitForPendingWrites].
  static Future<void> signOut() async {
    await _ensureInitialized();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
    await CloudSyncService.clearLocalData();
  }
}
