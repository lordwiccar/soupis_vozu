import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/scan_settings_service.dart';
import '../services/wagon_registry_service.dart';
import 'contacts_screen.dart';
import 'wagon_database_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadThemePreference();
    _loadScanSettings();
    _loadWagonRegistryCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _loadWagonRegistryCount() async {
    final count = await WagonRegistryService.count();
    if (mounted) setState(() => _wagonRegistryCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NASTAVENÍ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.contacts_outlined), text: 'Adresář'),
            Tab(icon: Icon(Icons.document_scanner_outlined), text: 'Skenování'),
            Tab(icon: Icon(Icons.storage_outlined), text: 'Databáze'),
            Tab(icon: Icon(Icons.palette_outlined), text: 'Motiv'),
            Tab(icon: Icon(Icons.info_outline), text: 'O aplikaci'),
          ],
        ),
      ),
      body: Column(
        children: [
          ThemeService.amberStripe,
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContactsTab(),
                _buildScanTab(),
                _buildDatabaseTab(),
                _buildThemeTab(),
                _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ADRESÁŘ ────────────────────────────────────────────────────────────────

  Widget _buildContactsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          icon: Icons.contacts_outlined,
          title: 'Správa kontaktů',
          subtitle:
              'Přidávejte, upravujte a mažte kontakty pro odesílání soupisů',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          ),
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
          icon: Icons.storage_outlined,
          title: 'Databáze vozů',
          subtitle: _wagonRegistryCount == 0
              ? 'Zatím žádné uložené vozy'
              : 'Uloženo vozů: $_wagonRegistryCount',
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WagonDatabaseScreen()),
            );
            _loadWagonRegistryCount();
          },
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
              const Text(
                  'Aplikace si u každého naskenovaného vozu pamatuje '
                  'poznámky a příznaky napříč všemi soupisy.'),
              const SizedBox(height: 12),
              const Text(
                  '• Když je vůz nalezen v databázi, jeho informace se '
                  'při skenování automaticky předvyplní.'),
              const SizedBox(height: 8),
              const Text(
                  '• Když v detailu vozu poznámky/příznaky smažete a '
                  'uložíte, smaže se i záznam v databázi.'),
              const SizedBox(height: 8),
              const Text(
                  '• Databázi lze v sekci "Databáze vozů" prohledávat, '
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
              subtitle:
                  'Rozpoznávání pomocí AI – vyžaduje internet a API klíč',
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
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        secondary: Icon(icon, color: ThemeService.kRailAmber),
        tileColor: isDark ? ThemeService.kRailCharcoal : Colors.white,
        activeColor: ThemeService.kRailAmber,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        secondary: Icon(icon, color: ThemeService.kRailAmber),
        tileColor: isDark ? ThemeService.kRailCharcoal : Colors.white,
        activeColor: ThemeService.kRailAmber,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              ? const Icon(Icons.check_circle,
                  color: Colors.green, size: 20)
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
    final hintText =
        _aiProvider == AiProvider.openai ? 'sk-…' : 'sk-ant-…';

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
                icon: Icon(
                    obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () =>
                    setDialogState(() => obscure = !obscure),
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
                child: const Text('Smazat',
                    style: TextStyle(color: Colors.red)),
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

  // ─── MOTIV ──────────────────────────────────────────────────────────────────

  Widget _buildThemeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
          title: 'Nastavení motivu',
          subtitle: _getThemeDisplayName(),
          onTap: _showThemeSelectionDialog,
        ),
      ],
    );
  }

  // ─── O APLIKACI ─────────────────────────────────────────────────────────────

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'O aplikaci',
          subtitle: 'Soupis vozů – verze 1.0.5',
          onTap: _showAboutDialog,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.history,
          title: 'Changelog',
          subtitle: 'Přehled změn v jednotlivých verzích aplikace',
          onTap: _showChangelogDialog,
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
      ],
    );
  }

  // ─── SDÍLENÉ WIDGETY ────────────────────────────────────────────────────────

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: ThemeService.kRailAmber),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: trailing,
        tileColor:
            isDark ? ThemeService.kRailCharcoal : Colors.white,
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
            const Text('Verze: 1.0.5'),
            const SizedBox(height: 8),
            const Text(
                'Aplikace pro vytváření soupisů železničních vozů.'),
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

  /// Historie verzí zobrazená v dialogu changelogu – udržuje se ručně
  /// souběžně s CHANGELOG.md v kořeni repozitáře.
  static const List<Map<String, dynamic>> _changelogEntries = [
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

  void _showChangelogDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changelog'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in _changelogEntries) ...[
                  Text(
                    entry['date'] != null
                        ? 'Verze ${entry['version']} (${entry['date']})'
                        : 'Verze ${entry['version']}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: ThemeService.kRailAmber),
                  ),
                  const SizedBox(height: 6),
                  for (final note in entry['notes'] as List<String>)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text('•  $note'),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLinkedIn() async {
    final url =
        Uri.parse('https://www.linkedin.com/in/daniel-macho-8ab0477a/');
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
