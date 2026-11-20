import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/appearance_service.dart';
import '../services/theme_service.dart';
import '../services/scan_settings_service.dart';
import '../services/tutorial_target_registry.dart';
import '../services/wagon_registry_service.dart';
import '../services/changelog_service.dart';
import 'contacts_screen.dart';
import 'wagon_database_screen.dart';
import '../widgets/adaptive/fold_info.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/scanned_wagon_row.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;
  final Future<void> Function()? onReplayTutorial;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
    this.onReplayTutorial,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _isDarkMode = false;
  late TabController _tabController;

  // Nastavení skenování
  ScanMode _scanMode = ScanMode.quick;
  AiProvider? _aiProvider;
  bool _hasApiKey = false;

  // Databáze vozů
  int _wagonRegistryCount = 0;

  // Vzhled výpisu vozů při skenování
  int _scanFontStep = 0;
  bool _highlightLast4 = false;

  final _databaseTileKey = GlobalKey();
  final _contactsTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadThemePreference();
    _loadScanSettings();
    _loadWagonRegistryCount();
    _loadAppearance();

    TutorialTargetRegistry.registerTabController(
        'settings.tabs', _tabController);
    TutorialTargetRegistry.register('settings.databaseTile', _databaseTileKey);
    TutorialTargetRegistry.register('settings.contactsTile', _contactsTileKey);
    TutorialTargetRegistry.registerAction(
        'settings.openDatabaseScreen', _openWagonDatabase);
    TutorialTargetRegistry.registerAction(
        'settings.openContactsScreen', _openContacts);
  }

  @override
  void dispose() {
    TutorialTargetRegistry.unregisterTabController('settings.tabs');
    TutorialTargetRegistry.unregister('settings.databaseTile');
    TutorialTargetRegistry.unregister('settings.contactsTile');
    TutorialTargetRegistry.unregisterAction('settings.openDatabaseScreen');
    TutorialTargetRegistry.unregisterAction('settings.openContactsScreen');
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openWagonDatabase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WagonDatabaseScreen()),
    );
    _loadWagonRegistryCount();
  }

  void _openContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
  }

  Future<void> _loadThemePreference() async {
    final themeMode = await ThemeService.getThemeMode();
    setState(() => _isDarkMode = themeMode == ThemeMode.dark);
  }

  Future<void> _loadScanSettings() async {
    final mode = await ScanSettingsService.getScanMode();
    final provider = await ScanSettingsService.getAiProvider();
    final key = await ScanSettingsService.getApiKey();
    if (mounted) {
      setState(() {
        _scanMode = mode;
        _aiProvider = provider;
        _hasApiKey = key != null && key.isNotEmpty;
      });
    }
  }

  Future<void> _loadAppearance() async {
    final step = await AppearanceService.getScanFontStep();
    final highlight = await AppearanceService.getHighlightLast4();
    if (mounted) {
      setState(() {
        _scanFontStep = step;
        _highlightLast4 = highlight;
      });
    }
  }

  Future<void> _loadWagonRegistryCount() async {
    final count = await WagonRegistryService.count();
    if (mounted) setState(() => _wagonRegistryCount = count);
  }

  // Ikony a popisky záložek – sdílené mezi TabBar (telefon) a
  // NavigationRail (rozevřený fold), ať jsou vždy v souladu.
  static const List<(IconData icon, String label)> _tabs = [
    (Icons.contacts_outlined, 'Adresář'),
    (Icons.document_scanner_outlined, 'Skenování'),
    (Icons.storage_outlined, 'Databáze'),
    (Icons.palette_outlined, 'Vzhled'),
    (Icons.info_outline, 'O aplikaci'),
  ];

  @override
  Widget build(BuildContext context) {
    final fold = FoldInfo.of(context);
    return fold.isUnfolded
        ? _buildUnfoldedLayout(context)
        : _buildPhoneLayout(context);
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NASTAVENÍ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.$1), text: t.$2))
              .toList(growable: false),
        ),
      ),
      body: Column(
        children: [
          ThemeService.amberStripe,
          Expanded(child: _buildTabBarView()),
        ],
      ),
    );
  }

  /// Na rozevřeném foldu nahradí horní TabBar postranní NavigationRail
  /// (Material vzor pro velké obrazovky). Obojí řídí stejný
  /// `_tabController`, takže tutoriál (`resolveTabController` +
  /// `animateTo`) funguje beze změny v obou layoutech.
  Widget _buildUnfoldedLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NASTAVENÍ')),
      body: Column(
        children: [
          ThemeService.amberStripe,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) => NavigationRail(
                    selectedIndex: _tabController.index,
                    onDestinationSelected: (index) =>
                        _tabController.animateTo(index),
                    labelType: NavigationRailLabelType.all,
                    destinations: _tabs
                        .map((t) => NavigationRailDestination(
                              icon: Icon(t.$1),
                              label: Text(t.$2),
                            ))
                        .toList(growable: false),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildTabBarView()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildContactsTab(),
        _buildScanTab(),
        _buildDatabaseTab(),
        _buildThemeTab(),
        _buildAboutTab(),
      ],
    );
  }

  // ─── ADRESÁŘ ────────────────────────────────────────────────────────────────

  Widget _buildContactsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          key: _contactsTileKey,
          icon: Icons.contacts_outlined,
          title: 'Správa kontaktů',
          subtitle:
              'Přidávejte, upravujte a mažte kontakty pro odesílání soupisů',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _openContacts,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.help_outline,
          title: 'Jak používat adresář',
          subtitle: 'Návod pro nastavení příjemců soupisů',
          onTap: _showCopyRecipientHelp,
        ),
      ],
    );
  }

  // ─── DATABÁZE VOZŮ ──────────────────────────────────────────────────────────

  Widget _buildDatabaseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          key: _databaseTileKey,
          icon: Icons.storage_outlined,
          title: 'Databáze vozů',
          subtitle: _wagonRegistryCount == 0
              ? 'Zatím žádné uložené vozy'
              : 'Uloženo vozů: $_wagonRegistryCount',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _openWagonDatabase,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.help_outline,
          title: 'Jak databáze funguje',
          subtitle: 'Automatické ukládání a předvyplňování informací o vozech',
          onTap: _showWagonDatabaseHelp,
        ),
      ],
    );
  }

  void _showWagonDatabaseHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Databáze vozů'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aplikace si u každého naskenovaného vozu pamatuje '
                  'poznámky a příznaky napříč všemi soupisy.'),
              const SizedBox(height: 12),
              const Text('• Když je vůz nalezen v databázi, jeho informace se '
                  'při skenování automaticky předvyplní.'),
              const SizedBox(height: 8),
              const Text('• Když v detailu vozu poznámky/příznaky smažete a '
                  'uložíte, smaže se i záznam v databázi.'),
              const SizedBox(height: 8),
              const Text('• Databázi lze v sekci "Databáze vozů" prohledávat, '
                  'ručně upravovat i exportovat/importovat jako .xlsx.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );
  }

  // ─── SKENOVÁNÍ ──────────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    final bool qualityMode = _scanMode == ScanMode.quality;
    final bool providerChosen = _aiProvider != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionLabel('REŽIM SKENOVÁNÍ'),
        RadioGroup<ScanMode>(
          groupValue: _scanMode,
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _scanMode = v);
            await ScanSettingsService.setScanMode(v);
          },
          child: Column(children: [
            _buildScanModeRadio(
              icon: Icons.flash_on_outlined,
              title: 'Rychlé',
              subtitle: 'Lokální ML Kit – funguje offline, bez API klíče',
              value: ScanMode.quick,
            ),
            _buildScanModeRadio(
              icon: Icons.psychology_outlined,
              title: 'Kvalitní (AI)',
              subtitle: 'Rozpoznávání pomocí AI – vyžaduje internet a API klíč',
              value: ScanMode.quality,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('AI MODEL', disabled: !qualityMode),
        Opacity(
          opacity: qualityMode ? 1.0 : 0.35,
          child: IgnorePointer(
            ignoring: !qualityMode,
            child: RadioGroup<AiProvider?>(
              groupValue: _aiProvider,
              onChanged: (v) async {
                setState(() => _aiProvider = v);
                await ScanSettingsService.setAiProvider(v);
              },
              child: Column(children: [
                _buildProviderRadio(
                  icon: Icons.auto_awesome_outlined,
                  title: 'GPT-4o  (OpenAI)',
                  subtitle: 'Vyžaduje OpenAI API klíč (sk-…)',
                  value: AiProvider.openai,
                ),
                _buildProviderRadio(
                  icon: Icons.smart_toy_outlined,
                  title: 'Claude Haiku  (Anthropic)',
                  subtitle: 'Vyžaduje Anthropic API klíč (sk-ant-…)',
                  value: AiProvider.claude,
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('API KLÍČ',
            disabled: !qualityMode || !providerChosen),
        _buildApiKeyTile(disabled: !qualityMode || !providerChosen),
      ],
    );
  }

  Widget _buildSectionLabel(String text, {bool disabled = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: Text(
          text,
          style: TextStyle(
            color: ThemeService.kRailAmber,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildScanModeRadio({
    required IconData icon,
    required String title,
    required String subtitle,
    required ScanMode value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: RadioListTile<ScanMode>(
        value: value,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        secondary: Icon(icon, color: ThemeService.kRailAmber),
        tileColor: isDark ? ThemeService.kRailCharcoal : Colors.white,
        activeColor: ThemeService.kRailAmber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProviderRadio({
    required IconData icon,
    required String title,
    required String subtitle,
    required AiProvider value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: RadioListTile<AiProvider?>(
        value: value,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        secondary: Icon(icon, color: ThemeService.kRailAmber),
        tileColor: isDark ? ThemeService.kRailCharcoal : Colors.white,
        activeColor: ThemeService.kRailAmber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildApiKeyTile({required bool disabled}) {
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: IgnorePointer(
        ignoring: disabled,
        child: _buildSettingsTile(
          icon: _hasApiKey ? Icons.lock : Icons.lock_open_outlined,
          title: 'API klíč',
          subtitle: _hasApiKey ? 'Klíč je nastaven' : 'Klíč není nastaven',
          trailing: _hasApiKey
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showApiKeyDialog,
        ),
      ),
    );
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    bool obscure = true;
    final providerName =
        _aiProvider == AiProvider.openai ? 'OpenAI' : 'Anthropic';
    final hintText = _aiProvider == AiProvider.openai ? 'sk-…' : 'sk-ant-…';

    // Předvyplnit existující klíč (zobrazí se zakrytý)
    ScanSettingsService.getApiKey().then((key) {
      if (key != null && key.isNotEmpty) controller.text = key;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$providerName API klíč'),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'API klíč',
              hintText: hintText,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            if (_hasApiKey)
              TextButton(
                onPressed: () async {
                  await ScanSettingsService.setApiKey(null);
                  if (mounted) setState(() => _hasApiKey = false);
                  if (context.mounted) Navigator.pop(context);
                },
                child:
                    const Text('Smazat', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  await ScanSettingsService.setApiKey(key);
                  if (mounted) setState(() => _hasApiKey = true);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Uložit'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── VZHLED ─────────────────────────────────────────────────────────────────

  Widget _buildThemeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionLabel('MOTIV'),
        _buildSettingsTile(
          icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
          title: 'Nastavení motivu',
          subtitle: _getThemeDisplayName(),
          onTap: _showThemeSelectionDialog,
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('VÝPIS VOZŮ PŘI SKENOVÁNÍ'),
        _buildScanFontCard(),
      ],
    );
  }

  /// Volba velikosti čísel ve výpisu vozů na obrazovce skenování, se živým
  /// náhledem řádků výpisu (stejný widget jako na obrazovce skenování).
  Widget _buildScanFontCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stepCount = AppearanceService.scanFontSizes.length;

    return Card(
      color: isDark ? ThemeService.kRailCharcoal : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.format_size, color: ThemeService.kRailAmber),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Velikost čísel vozů',
                          style: theme.textTheme.titleSmall),
                      Text('Výpis vozů na obrazovce skenování',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < stepCount; i++)
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: i < stepCount - 1 ? 6 : 0),
                      child: _buildFontStepButton(i, isDark),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Náhled – výpis na skenování je vždy tmavý, bez ohledu na motiv.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 2),
              decoration: BoxDecoration(
                color: ThemeService.kRailBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'NÁHLED',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ScannedWagonRow(
                    number: '335478431125',
                    isValid: true,
                    isComplete: true,
                    hasDefect: true,
                    fontStep: _scanFontStep,
                    highlightLast4: _highlightLast4,
                  ),
                  ScannedWagonRow(
                    number: '315453561070',
                    isValid: true,
                    isComplete: false,
                    hasDefect: false,
                    fontStep: _scanFontStep,
                    highlightLast4: _highlightLast4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Zvýraznit poslední čtyřčíslí',
                  style: theme.textTheme.bodyMedium),
              value: _highlightLast4,
              activeThumbColor: ThemeService.kRailAmber,
              onChanged: (v) async {
                setState(() => _highlightLast4 = v);
                await AppearanceService.setHighlightLast4(v);
              },
            ),
            Text(
              'Když se číslo na displej nevejde, zkrátí se zleva – poslední '
              'čtyřčíslí a stavové ikonky zůstanou vždy vidět.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontStepButton(int step, bool isDark) {
    final selected = step == _scanFontStep;
    final theme = Theme.of(context);
    final borderColor = selected
        ? ThemeService.kRailAmber
        : (isDark ? ThemeService.kRailSteel : Colors.black26);
    return Material(
      color: selected
          ? ThemeService.kRailAmber.withValues(alpha: 0.14)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          setState(() => _scanFontStep = step);
          await AppearanceService.setScanFontStep(step);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ukázka velikosti je ve fixní výšce, aby popisky všech
              // tlačítek zůstaly na jedné úrovni.
              SizedBox(
                height: 30,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '123',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: AppearanceService.scanFontSizes[step],
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppearanceService.scanFontLabels[step],
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: selected ? ThemeService.kRailAmber : null,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── O APLIKACI ─────────────────────────────────────────────────────────────

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          icon: Icons.cloud_sync_outlined,
          title: 'Synchronizovat nyní',
          subtitle: _syncing
              ? 'Probíhá synchronizace…'
              : 'Účet ${AuthService.currentUser?.email ?? ''} – data se '
                  'zálohují automaticky',
          onTap: _syncing ? () {} : _syncNow,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.logout,
          title: 'Odhlásit se',
          subtitle: 'Data zůstanou v cloudu, z tohoto zařízení se smažou',
          onTap: _signOut,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.delete_forever_outlined,
          title: 'Smazat účet a data',
          subtitle: 'Nevratně smaže účet i všechna data v cloudu a v zařízení',
          onTap: _deleteAccount,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'O aplikaci',
          subtitle: 'Soupis vozů – verze ${ChangelogService.currentVersion}',
          onTap: _showAboutDialog,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.history,
          title: 'Changelog',
          subtitle: 'Přehled změn v jednotlivých verzích aplikace',
          onTap: () => showChangelogDialog(context),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.link,
          title: 'Autor profil',
          subtitle: 'Navštivte LinkedIn profil autora',
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: _openLinkedIn,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Zásady ochrany osobních údajů',
          subtitle: 'Jaká data aplikace zpracovává a jak s nimi nakládá',
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: _openPrivacyPolicy,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.description_outlined,
          title: 'Licence open source knihoven',
          subtitle: 'Knihovny třetích stran použité v aplikaci a jejich licence',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Soupis vozů',
            applicationVersion: ChangelogService.currentVersion,
            applicationLegalese: '© 2026 White Whale Media',
          ),
        ),
        if (widget.onReplayTutorial != null) ...[
          const SizedBox(height: 8),
          _buildSettingsTile(
            icon: Icons.school_outlined,
            title: 'Znovu spustit tutoriál',
            subtitle: 'Projít znovu úvodní průvodce aplikací',
            onTap: () => widget.onReplayTutorial!(),
          ),
        ],
      ],
    );
  }

  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    String message;
    try {
      await CloudSyncService.syncAll(full: true);
      message = 'Data jsou synchronizovaná s cloudem';
    } catch (_) {
      message = 'Synchronizace se nezdařila – zkontrolujte připojení';
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odhlásit se?'),
        content: const Text(
            'Vaše data zůstanou uložená v cloudu a po dalším přihlášení se '
            'znovu stáhnou. Z tohoto zařízení se smažou.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušit')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Odhlásit')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Neodeslané změny (typicky bez signálu) by se odhlášením ztratily.
    if (!await CloudSyncService.waitForPendingWrites()) {
      if (!mounted) return;
      final force = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Neodeslané změny'),
          content: const Text(
              'Některé změny se zatím nepodařilo odeslat do cloudu (nejspíš '
              'chybí připojení). Pokud se odhlásíte teď, o tyto změny '
              'přijdete.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Zrušit')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Přesto odhlásit')),
          ],
        ),
      );
      if (force != true) return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await AuthService.signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat účet a data?'),
        content: const Text(
            'Nevratně se smažou všechny soupisy, databáze vozů, adresář '
            'i nastavení – v cloudu i v tomto zařízení – a váš účet '
            'v aplikaci. Pro potvrzení budete vyzváni k výběru Google účtu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušit')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Smazat')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (!await AuthService.deleteAccount()) return;
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Chyba při mazání účtu: $e');
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Účet se nepodařilo smazat – zkontrolujte připojení a zkuste '
              'to znovu.')));
    }
  }

  // ─── SDÍLENÉ WIDGETY ────────────────────────────────────────────────────────

  Widget _buildSettingsTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      key: key,
      child: ListTile(
        leading: Icon(icon, color: ThemeService.kRailAmber),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: trailing,
        tileColor: isDark ? ThemeService.kRailCharcoal : Colors.white,
        onTap: onTap,
      ),
    );
  }

  String _getThemeDisplayName() {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? 'Tmavý motiv' : 'Světlý motiv';
  }

  void _showCopyRecipientHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Příjemci v Kopii'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jak nastavit příjemce soupisů:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              const Text('1. V sekci "Adresář" přidejte nový kontakt.'),
              const SizedBox(height: 8),
              const Text(
                  'Před odesláním soupisu si vyberete kontakt z adresáře, na který se soupis odešle.'),
              const SizedBox(height: 16),
              const Text(
                  '2. Zaškrtněte políčko "Použít jako příjemce v kopii", pokud chcete sestavený soupis zasílat na kontakt vždy, společně s vybraným kontaktem.'),
              const SizedBox(height: 8),
              Text(
                '(Příklad: Vyberete kontakt sloužícího dispečera, v kopii je vedoucí útvaru nebo sdílený e-mail)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text(
                  'Kontakt označený jako příjemce v Kopii se již nebude nabízet pro výběr do pole "Komu".'),
              const SizedBox(height: 16),
              Text(
                'Poznámka: Jako "Příjemce v kopii" může být označen jen jeden kontakt.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nastavení motivu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Světlý motiv'),
              onTap: () {
                Navigator.pop(context);
                _changeTheme(ThemeMode.light);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Tmavý motiv'),
              onTap: () {
                Navigator.pop(context);
                _changeTheme(ThemeMode.dark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('Adaptace podle systému'),
              onTap: () {
                Navigator.pop(context);
                _changeTheme(ThemeMode.system);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
        ],
      ),
    );
  }

  void _changeTheme(ThemeMode themeMode) async {
    setState(() => _isDarkMode = themeMode == ThemeMode.dark);
    await ThemeService.setThemeMode(themeMode);
    widget.onThemeChanged(themeMode);
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O aplikaci'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Soupis vozů'),
            const SizedBox(height: 8),
            Text('Verze: ${ChangelogService.currentVersion}'),
            const SizedBox(height: 8),
            const Text('Aplikace pro vytváření soupisů železničních vozů.'),
            const SizedBox(height: 16),
            const Center(child: Text('© White Whale Media 2026')),
            const SizedBox(height: 16),
            Center(
              child: Image.asset('assets/wwm.png', height: 60),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLinkedIn() async {
    final url = Uri.parse('https://www.linkedin.com/in/daniel-macho-8ab0477a/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nelze otevřít odkaz na LinkedIn profil')),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final url =
        Uri.parse('https://lordwiccar.github.io/soupis_vozu/privacy.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nelze otevřít zásady ochrany osobních údajů')),
        );
      }
    }
  }
}
