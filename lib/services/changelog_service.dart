import 'package:shared_preferences/shared_preferences.dart';

/// Historie verzí appky – zdroj pravdy pro zobrazované číslo verze
/// i pro dialog changelogu (Nastavení → O aplikaci a automatické zobrazení
/// po aktualizaci). Udržuje se ručně souběžně s CHANGELOG.md v kořeni
/// repozitáře.
const List<Map<String, dynamic>> changelogEntries = [
  {
    'version': '1.1.0',
    'date': '19. 9. 2026',
    'notes': [
      'Nový výpočet MZOB (Mezinárodní zpráva o brzdění vlaku) přímo ze '
          'soupisu vozů.',
      'Nový interaktivní tutoriál appky – provede skenováním vozu, '
          'soupisem i výpočtem MZOB. Jde kdykoliv znovu spustit tady '
          'v Nastavení.',
      'Přidáno rozšířené rozložení pro rozevřené foldovací telefony '
          '(např. Galaxy Z Fold) – širší displej teď appka využije '
          'dvoupanelovým nebo rozšířeným zobrazením. Na běžném telefonu '
          '(i na Foldu ve složeném stavu) beze změny.',
      'Oprava: na obrazovce skenování zůstával pod tlačítkem SKENOVAT '
          'tenký nevybarvený pruh.',
      'Po aktualizaci appky se teď při prvním spuštění automaticky '
          'zobrazí tento přehled novinek.',
    ],
  },
  {
    'version': '1.0.6',
    'date': '3. 9. 2026',
    'notes': [
      'Nově: pokud je při skenování naskenován vůz, který je v databázi '
          'vozů veden se závadou (má zapsaný příznak nebo poznámku), '
          'zobrazí se dialog s citací příznaku a poznámky a třemi '
          'možnostmi – "Závada trvá" (jen potvrdí a pokračuje ve '
          'skenování), "Závada odstraněna" (smaže příznak i poznámku ze '
          'soupisu i z trvalé databáze vozů) a "Upravit" (rovnou otevře '
          'editaci příznaku/poznámky, po uložení se uživatel vrátí zpět '
          'na obrazovku skenování).',
      'Nově: v seznamu naskenovaných vozů (spodní část obrazovky '
          'skenování) se u čísel, která mají v databázi vozů vedený '
          'příznak nebo poznámku, zobrazuje oranžový vykřičník.',
    ],
  },
  {
    'version': '1.0.5',
    'date': '15. 8. 2026',
    'notes': [
      'Oprava: ruční zadání čísla vozu (i oprava nerozpoznaného/neplatného '
          'čísla) teď správně kontroluje databázi vozů – dřív se u ručně '
          'zadaných čísel nenačetly uložené technické údaje ani hláška '
          'o nalezení v databázi.',
      'V Nastavení → O aplikaci přidán přehled changelogu.',
    ],
  },
  {
    'version': '1.0.4',
    'date': '12. 8. 2026',
    'notes': [
      'Oprava: sekce "Poslední soupisy" na hlavní obrazovce se u zařízení '
          's klasickou tlačítkovou navigací schovávala pod systémovou '
          'navigační lištu.',
    ],
  },
  {
    'version': '1.0.3',
    'date': '12. 8. 2026',
    'notes': [
      'Oprava: tlačítka ve spodní části obrazovky (skenování i detail '
          'vozu) se u zařízení s klasickou tlačítkovou navigací '
          'schovávala pod systémovou navigační lištu.',
    ],
  },
  {
    'version': '1.0.2',
    'date': '11. 8. 2026',
    'notes': [
      'Drobné doladění release procesu před prvním zveřejněním na Google '
          'Play.',
    ],
  },
  {
    'version': '1.0.1',
    'date': '11. 8. 2026',
    'notes': [
      'Odebráno nepoužité oprávnění k nahrávání zvuku.',
      'Zapnuta minifikace a zmenšení release buildu.',
    ],
  },
  {
    'version': '1.0.0',
    'date': null,
    'notes': ['První release verze.'],
  },
];

/// Sleduje, jestli už uživatel viděl changelog aktuální verze, a podle toho
/// rozhoduje, jestli se má po aktualizaci appky zobrazit automaticky.
class ChangelogService {
  ChangelogService._();

  static const _key = 'last_seen_changelog_version';

  static String get currentVersion =>
      changelogEntries.first['version'] as String;

  /// True, pokud appka byla od posledního spuštění aktualizována na novou
  /// verzi, a changelog by se tedy měl zobrazit automaticky. Na úplně
  /// čerstvé instalaci (bez zapamatované předchozí verze – tu už řeší
  /// úvodní tutoriál) vrací false a jen si tiše zapamatuje aktuální verzi
  /// jako výchozí stav pro příští srovnání.
  static Future<bool> wasUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString(_key);
    if (lastSeenVersion == null) {
      await prefs.setString(_key, currentVersion);
      return false;
    }
    return lastSeenVersion != currentVersion;
  }

  /// Zavolat až po skutečném zobrazení changelogu uživateli.
  static Future<void> markCurrentVersionSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, currentVersion);
  }
}
