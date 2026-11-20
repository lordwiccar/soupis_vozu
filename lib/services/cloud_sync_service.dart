import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service.dart';
import 'inventory_service.dart';
import 'settings_sync.dart';
import 'wagon_registry_service.dart';

/// Synchronizace lokálních dat (SQLite + nastavení) s Firestore pod účtem
/// přihlášeného uživatele.
///
/// Lokální databáze zůstává hlavním úložištěm – appka tak funguje i offline.
/// Každá lokální změna se hned zapíše i do Firestore ([pushDoc] /
/// [pushDeleted]); bez signálu ji Firestore SDK podrží ve frontě a odešle,
/// jakmile je zařízení online (i po restartu appky). Při přihlášení a při
/// startu appky se pak ze cloudu stáhnou změny z jiných zařízení
/// ([syncAll]).
///
/// Struktura ve Firestore: `users/{uid}/{kolekce}/{id}` s poli
/// - `data` – řádek lokální databáze (stejné sloupce jako v SQLite),
/// - `updatedAt` – čas poslední změny (UTC ISO 8601), rozhoduje o tom,
///   která verze vyhraje při slučování,
/// - `deleted` – záznam byl smazán (aby se smazání přeneslo na ostatní
///   zařízení a smazaný záznam se z nich neobnovil),
/// - `syncedAt` – čas zápisu na serveru, slouží jen pro stahování změn od
///   poslední synchronizace (nezávisí na hodinách zařízení).
class CloudSyncService {
  static const String wagons = 'wagons';
  static const String inventories = 'inventories';
  static const String contacts = 'contacts';
  static const String settings = 'settings';

  static const String _uidKey = 'sync_uid';
  static const String _lastPullPrefix = 'sync_last_pull_';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>? _collection(String name) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection(name);
  }

  // ─── ODESÍLÁNÍ ZMĚN ─────────────────────────────────────────────────────

  /// Zapíše aktuální stav záznamu do cloudu. Na potvrzení ze serveru se
  /// nečeká – offline by to blokovalo UI; zápis drží ve frontě Firestore SDK.
  static void pushDoc(String collection, String id, Map<String, dynamic> data,
      DateTime updatedAt) {
    final col = _collection(collection);
    if (col == null) return;
    col.doc(id).set({
      'data': data,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deleted': false,
      'syncedAt': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('Chyba při zápisu $collection/$id do cloudu: $e');
    });
  }

  /// Označí záznam v cloudu jako smazaný.
  static void pushDeleted(String collection, String id) {
    final col = _collection(collection);
    if (col == null) return;
    col.doc(id).set({
      'data': null,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'deleted': true,
      'syncedAt': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('Chyba při mazání $collection/$id v cloudu: $e');
    });
  }

  // ─── PŘIHLÁŠENÍ / ODHLÁŠENÍ ─────────────────────────────────────────────

  /// Potřebuje tento účet na tomto zařízení úvodní (úplnou) synchronizaci?
  /// Typicky první přihlášení – appka pak před zobrazením dat počká na
  /// stažení dat z cloudu.
  static Future<bool> needsInitialSync(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uidKey) != uid ||
        prefs.getString('$_lastPullPrefix$wagons') == null;
  }

  /// Volá se po přihlášení (i po startu appky s již přihlášeným účtem).
  /// Pokud se přihlásil jiný účet, než jehož data jsou v zařízení, lokální
  /// data se nejdřív smažou – každý účet vidí jen svoje. Při prvním
  /// přihlášení po instalaci této verze (žádný předchozí účet) se naopak
  /// stávající lokální data sloučí s cloudem a nahrají se do něj.
  static Future<void> onSignedIn(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUid = prefs.getString(_uidKey);
    if (previousUid != null && previousUid != uid) {
      await clearLocalData();
    }
    await prefs.setString(_uidKey, uid);
    await syncAll();
  }

  /// Počká, až se všechny čekající změny odešlou na server. Vrací `false`,
  /// pokud se to nepodaří včas (typicky bez signálu).
  static Future<bool> waitForPendingWrites(
      {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await _db.waitForPendingWrites().timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Nevratně smaže všechna data přihlášeného uživatele z cloudu (smazání
  /// účtu – vyžaduje Google Play).
  static Future<void> deleteCloudData() async {
    for (final name in [wagons, inventories, contacts, settings]) {
      final col = _collection(name);
      if (col == null) return;
      final snapshot = await col.get(const GetOptions(source: Source.server));
      // Firestore dovoluje max. 500 operací v jedné dávce.
      for (var i = 0; i < snapshot.docs.length; i += 500) {
        final batch = _db.batch();
        for (final doc in snapshot.docs.skip(i).take(500)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
  }

  /// Smaže lokální data a stav synchronizace (po odhlášení nebo při změně
  /// účtu). Data přihlášeného účtu zůstávají v cloudu.
  static Future<void> clearLocalData() async {
    await WagonRegistryService.clearAll();
    await InventoryService.clearAll();
    await ContactService.clearAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    for (final name in [wagons, inventories, contacts, settings]) {
      await prefs.remove('$_lastPullPrefix$name');
    }
  }

  // ─── STAHOVÁNÍ A SLUČOVÁNÍ ──────────────────────────────────────────────

  static Future<void>? _running;

  /// Stáhne změny ze cloudu a sloučí je s lokálními daty. Při [full] (nebo
  /// pokud kolekce ještě nebyla synchronizována) se projdou všechny
  /// záznamy a do cloudu se nahrají i lokální záznamy, které v něm chybí.
  /// Jinak se stahují jen záznamy změněné od poslední synchronizace.
  static Future<void> syncAll({bool full = false}) {
    return _running ??= _syncAll(full).whenComplete(() => _running = null);
  }

  static Future<void> _syncAll(bool full) async {
    try {
      await _syncCollection(
        name: wagons,
        full: full,
        localStamps: WagonRegistryService.getSyncStamps,
        localDoc: WagonRegistryService.getSyncData,
        applyRemote: WagonRegistryService.applyRemote,
        deleteLocal: WagonRegistryService.deleteLocal,
      );
      await _syncCollection(
        name: inventories,
        full: full,
        localStamps: InventoryService.getSyncStamps,
        localDoc: InventoryService.getSyncData,
        applyRemote: InventoryService.applyRemote,
        deleteLocal: InventoryService.deleteLocal,
      );
      await _syncCollection(
        name: contacts,
        full: full,
        localStamps: ContactService.getSyncStamps,
        localDoc: ContactService.getSyncData,
        applyRemote: ContactService.applyRemote,
        deleteLocal: ContactService.deleteLocal,
      );
      await _syncCollection(
        name: settings,
        full: full,
        localStamps: SettingsSync.getSyncStamps,
        localDoc: SettingsSync.getSyncData,
        applyRemote: SettingsSync.applyRemote,
        deleteLocal: (_) async {},
      );
    } catch (e) {
      // Typicky bez signálu – synchronizace proběhne při dalším startu.
      debugPrint('Synchronizace s cloudem selhala: $e');
      rethrow;
    }
  }

  static Future<void> _syncCollection({
    required String name,
    required bool full,
    required Future<Map<String, DateTime>> Function() localStamps,
    required Future<Map<String, dynamic>?> Function(String id) localDoc,
    required Future<void> Function(
            String id, Map<String, dynamic> data, DateTime updatedAt)
        applyRemote,
    required Future<void> Function(String id) deleteLocal,
  }) async {
    final col = _collection(name);
    if (col == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPullKey = '$_lastPullPrefix$name';
    final lastPullMs = prefs.getInt(lastPullKey);
    final incremental = !full && lastPullMs != null;

    final query = incremental
        ? col.where('syncedAt',
            isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastPullMs))
        : col;
    final snapshot = await query.get(const GetOptions(source: Source.server));

    final local = await localStamps();
    final remoteIds = <String>{};
    var maxSyncedMs = lastPullMs ?? 0;

    for (final doc in snapshot.docs) {
      final remote = doc.data();
      remoteIds.add(doc.id);

      final syncedAt = remote['syncedAt'];
      if (syncedAt is Timestamp &&
          syncedAt.millisecondsSinceEpoch > maxSyncedMs) {
        maxSyncedMs = syncedAt.millisecondsSinceEpoch;
      }

      final remoteUpdated =
          DateTime.tryParse(remote['updatedAt'] as String? ?? '');
      if (remoteUpdated == null) continue;
      final localUpdated = local[doc.id];

      if (localUpdated != null && localUpdated.isAfter(remoteUpdated)) {
        // Lokální verze je novější (např. změna z doby před přihlášením).
        await _pushLocal(name, doc.id, localDoc, localUpdated);
      } else if (remote['deleted'] == true) {
        if (localUpdated != null) await deleteLocal(doc.id);
      } else if (localUpdated == null || remoteUpdated.isAfter(localUpdated)) {
        final data = remote['data'];
        if (data is Map) {
          await applyRemote(
              doc.id, Map<String, dynamic>.from(data), remoteUpdated);
        }
      }
    }

    if (!incremental) {
      // Lokální záznamy, které v cloudu vůbec nejsou, se do něj nahrají.
      for (final entry in local.entries) {
        if (!remoteIds.contains(entry.key)) {
          await _pushLocal(name, entry.key, localDoc, entry.value);
        }
      }
    }

    await prefs.setInt(lastPullKey, maxSyncedMs);
  }

  static Future<void> _pushLocal(
    String name,
    String id,
    Future<Map<String, dynamic>?> Function(String id) localDoc,
    DateTime updatedAt,
  ) async {
    final data = await localDoc(id);
    if (data != null) pushDoc(name, id, data, updatedAt);
  }
}
