import 'package:flutter/material.dart';
import '../models/tutorial_step.dart';
import '../screens/scan_screen_fixed.dart';
import '../screens/inventory_list_screen.dart';
import 'tutorial_controller.dart';
import 'tutorial_service.dart';
import 'tutorial_target_registry.dart';

/// Kroky spotlight tutoriálu, v pořadí odpovídajícím hlavním funkcím
/// aplikace: skenování → editace vozu → nálepky → poznámky → technické
/// údaje → adresář dispečerů → odeslání dispečerovi → výpočet MZOB →
/// export/import databáze.
final List<TutorialStep> kTutorialSteps = [
  // 1 — úvod, bez výřezu
  const TutorialStep(
    icon: Icons.waving_hand_outlined,
    title: 'Vítejte v aplikaci!',
    body:
        'Provedeme vás hlavními funkcemi aplikace Soupis vozů na skutečné '
        'ukázce. Průvodce můžete kdykoli přeskočit tlačítkem „Přeskočit".',
    shape: SpotlightShape.none,
  ),

  // 2 — Home: zahájit skenování
  TutorialStep(
    icon: Icons.document_scanner_outlined,
    title: 'Zahájení skenování',
    body: 'Tlačítkem ZAHÁJIT SKENOVÁNÍ spustíte kameru a začnete evidovat '
        'vozy vlaku.',
    targetKey: () => TutorialTargetRegistry.resolveKey('home.scanButton'),
  ),

  // 3 — Scan: tlačítko SKENOVAT
  TutorialStep(
    icon: Icons.camera_alt_outlined,
    title: 'Skenování čísla vozu',
    body: 'Zamiřte kamerou na číslo vozu a stiskněte SKENOVAT — aplikace '
        'číslo automaticky rozpozná a přidá do soupisu. Pro ukázku jsme '
        'sem už předvyplnili tři vozy.',
    targetKey: () => TutorialTargetRegistry.resolveKey('scan.captureButton'),
    preAction: (c) async {
      c.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ScanScreenFixed(
            inventoryId: c.demoInventoryId,
            initialWagonNumbers: TutorialService.demoWagonNumbers,
          ),
        ),
        (_) => false,
      );
    },
  ),

  // 4 — Scan: seznam naskenovaných vozů
  TutorialStep(
    icon: Icons.list_alt_outlined,
    title: 'Seznam vozů v soupisu',
    body: 'Zde vidíte průběžně naskenovaná čísla vozů, včetně toho, zda '
        'jsou platná a zda má vůz v databázi vedenou závadu.',
    targetKey: () => TutorialTargetRegistry.resolveKey('scan.firstWagonRow'),
  ),

  // 5 — Scan: editace vozu (ikona tužky)
  TutorialStep(
    icon: Icons.edit_outlined,
    title: 'Editace vozu',
    body: 'Klepnutím na ikonu tužky u čísla vozu otevřete jeho detail — '
        'můžete opravit číslo, doplnit nálepky, poznámky i technické údaje.',
    shape: SpotlightShape.circle,
    targetKey: () => TutorialTargetRegistry.resolveKey('scan.firstEditIcon'),
  ),

  // 6 — WagonDetail: nálepky
  TutorialStep(
    icon: Icons.label_outline,
    title: 'Nálepky',
    body: 'Vozu můžete přiřadit nálepku označující jeho stav — např. M '
        '(zkontrolovat), K (nenakládat) nebo R1 (brzda neupotřebitelná).',
    targetKey: () => TutorialTargetRegistry.resolveKey('wagonDetail.flagsRow'),
    preAction: (c) async {
      c.runAction('scan.openWagonDetailForDemo');
    },
  ),

  // 7 — WagonDetail: poznámky
  const TutorialStep(
    icon: Icons.edit_note_outlined,
    title: 'Poznámky',
    body: 'Do poznámky doplníte libovolný text upřesňující stav nebo '
        'poškození vozu.',
    targetKey: _wagonDetailNotesField,
  ),

  // 8 — WagonDetail: technické údaje
  const TutorialStep(
    icon: Icons.settings_outlined,
    title: 'Technické údaje',
    body: 'Sem patří hmotnost, brzdící váhy (P) a (L), rychlosti, délka, '
        'počet náprav a ruční brzda vozu — tyto údaje aplikace využije '
        'později například pro výpočet MZOB.',
    targetKey: _wagonDetailTechnicalCard,
  ),

  // 9 — WagonDetail: uložit
  const TutorialStep(
    icon: Icons.save_outlined,
    title: 'Uložení změn',
    body: 'Tlačítkem ULOŽIT ZMĚNY se úpravy vozu uloží a vrátíte se zpět '
        'na skenování.',
    targetKey: _wagonDetailSaveButton,
    postAction: _popCurrentRoute,
  ),

  // 10 — Scan: ukončení skenování
  const TutorialStep(
    icon: Icons.arrow_back_outlined,
    title: 'Ukončení skenování',
    body: 'Po naskenování celého vlaku klepněte na šipku zpět. Soupis se '
        'uloží automaticky.',
    shape: SpotlightShape.circle,
    targetKey: _scanBackButton,
  ),

  // 11 — Settings: záložka Adresář
  TutorialStep(
    icon: Icons.contacts_outlined,
    title: 'Adresář dispečerů',
    body: 'V Nastavení → Adresář spravujete kontakty dispečerů, na které '
        'budete soupisy odesílat.',
    targetKey: () =>
        TutorialTargetRegistry.resolveKey('settings.contactsTile'),
    preAction: (c) async {
      await c.pushNamed('/settings');
    },
  ),

  // 12 — Contacts: dialog přidání kontaktu
  const TutorialStep(
    icon: Icons.person_add_alt_outlined,
    title: 'Přidání kontaktu',
    body: 'Zadáte jméno a e-mail dispečera. Zaškrtnutím „Použít jako '
        'příjemce v kopii" bude tento kontakt automaticky přidán do kopie '
        'při každém odeslání soupisu.',
    targetKey: _contactsAddDialog,
    preAction: _openContactsAddDialog,
    postAction: _popCurrentRoute,
  ),

  // 13 — InventoryList: ukázkový soupis
  TutorialStep(
    icon: Icons.inventory_2_outlined,
    title: 'Přehled soupisů',
    body: 'Toto je seznam všech vytvořených soupisů. Klepnutím na kartu '
        'soupis rozbalíte a uvidíte v něm všechny vozy i souhrnné akce.',
    targetKey: () => TutorialTargetRegistry.resolveKey('inventory.demoTile'),
    preAction: (c) async {
      c.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              InventoryListScreen(expandedInventoryId: c.demoInventoryId),
        ),
        (_) => false,
      );
    },
  ),

  // 14 — InventoryList: export do e-mailu
  const TutorialStep(
    icon: Icons.email_outlined,
    title: 'Odeslání dispečerovi',
    body: 'Tlačítkem EXPORTOVAT DO E-MAILU odešlete hotový soupis '
        'vybranému kontaktu z adresáře.',
    targetKey: _inventoryExportEmailButton,
  ),

  // 15 — InventoryList: dialog odeslání
  const TutorialStep(
    icon: Icons.send_outlined,
    title: 'Výběr adresáta',
    body: 'Vyberete adresáta a potvrdíte tlačítkem Odeslat e-mail — '
        'aplikace připraví e-mail s kompletním soupisem. (V tutoriálu se '
        'nic doopravdy neodešle.)',
    targetKey: _inventorySendEmailButton,
    preAction: _openDemoEmailDialog,
    postAction: _popCurrentRoute,
  ),

  // 16 — InventoryList: MZOB
  TutorialStep(
    icon: Icons.calculate_outlined,
    title: 'Výpočet MZOB',
    body: 'Tlačítkem SPOČÍTAT MZOB spočítáte podklady pro Mezinárodní '
        'zprávu o brzdění vlaku ze zadané hmotnosti nákladu a technických '
        'údajů vozů. Pro ukázku jsme technické údaje ukázkových vozů '
        'doplnili automaticky.',
    targetKey: () => TutorialTargetRegistry.resolveKey('inventory.mzobButton'),
    preAction: (c) async {
      if (c.demoInventoryId != null) {
        await TutorialService.enrichDemoWagonsForMzobDemo(c.demoInventoryId!);
      }
      c.runAction('inventory.reloadForTutorial');
    },
  ),

  // 17 — Settings: záložka Databáze
  TutorialStep(
    icon: Icons.storage_outlined,
    title: 'Databáze vozů',
    body: 'V Nastavení → Databáze najdete trvalý registr technických '
        'údajů všech dosud naskenovaných vozů.',
    targetKey: () =>
        TutorialTargetRegistry.resolveKey('settings.databaseTile'),
    preAction: (c) async {
      await c.pushNamed('/settings');
      await Future.delayed(const Duration(milliseconds: 350));
      TutorialTargetRegistry.resolveTabController('settings.tabs')
          ?.animateTo(2);
    },
  ),

  // 18 — WagonDatabase: export
  const TutorialStep(
    icon: Icons.upload_file_outlined,
    title: 'Export databáze',
    body: 'Databázi vozů můžete kdykoli vyexportovat jako soubor .xlsx, '
        'například pro zálohu nebo sdílení s kolegy.',
    targetKey: _wagonDatabaseExportButton,
    preAction: _openWagonDatabaseScreen,
  ),

  // 19 — WagonDatabase: import
  const TutorialStep(
    icon: Icons.download_outlined,
    title: 'Import databáze',
    body: 'A naopak — dříve vyexportovaný soubor .xlsx můžete kdykoli '
        'zpětně naimportovat.',
    targetKey: _wagonDatabaseImportButton,
  ),

  // 20 — závěr, bez výřezu
  const TutorialStep(
    icon: Icons.check_circle_outline,
    title: 'To je vše!',
    body: 'Tímto průvodce končí. Ukázkový soupis i ukázkové vozy teď '
        'smažeme — aplikaci si můžete začít používat naostro.',
    shape: SpotlightShape.none,
  ),
];

GlobalKey? _contactsAddDialog() =>
    TutorialTargetRegistry.resolveKey('contacts.addDialogContent');
GlobalKey? _wagonDetailNotesField() =>
    TutorialTargetRegistry.resolveKey('wagonDetail.notesField');
GlobalKey? _wagonDetailTechnicalCard() =>
    TutorialTargetRegistry.resolveKey('wagonDetail.technicalCard');
GlobalKey? _wagonDetailSaveButton() =>
    TutorialTargetRegistry.resolveKey('wagonDetail.saveButton');
GlobalKey? _scanBackButton() =>
    TutorialTargetRegistry.resolveKey('scan.backButton');
GlobalKey? _inventoryExportEmailButton() =>
    TutorialTargetRegistry.resolveKey('inventory.exportEmailButton');
GlobalKey? _inventorySendEmailButton() =>
    TutorialTargetRegistry.resolveKey('inventory.sendEmailButton');
GlobalKey? _wagonDatabaseExportButton() =>
    TutorialTargetRegistry.resolveKey('wagonDatabase.exportButton');
GlobalKey? _wagonDatabaseImportButton() =>
    TutorialTargetRegistry.resolveKey('wagonDatabase.importButton');

Future<void> _popCurrentRoute(TutorialController c) async {
  c.navigatorKey.currentState?.pop();
}

Future<void> _openContactsAddDialog(TutorialController c) async {
  c.runAction('settings.openContactsScreen');
  await Future.delayed(const Duration(milliseconds: 350));
  c.runAction('contacts.openAddDialog');
}

Future<void> _openDemoEmailDialog(TutorialController c) async {
  c.runAction('inventory.openEmailDialogForDemo');
}

Future<void> _openWagonDatabaseScreen(TutorialController c) async {
  c.runAction('settings.openDatabaseScreen');
}
