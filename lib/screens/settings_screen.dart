import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import 'contacts_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadThemePreference();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NASTAVENÍ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.contacts_outlined), text: 'Adresář'),
            Tab(icon: Icon(Icons.palette_outlined),  text: 'Motiv'),
            Tab(icon: Icon(Icons.info_outline),       text: 'O aplikaci'),
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
                _buildThemeTab(),
                _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          icon: Icons.contacts_outlined,
          title: 'Správa kontaktů',
          subtitle: 'Přidávejte, upravujte a mažte kontakty pro odesílání soupisů',
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

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'O aplikaci',
          subtitle: 'Soupis vozů – verze 1.0.0',
          onTap: _showAboutDialog,
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.link,
          title: 'Autor profil',
          subtitle: 'Navštivte LinkedIn profil autora',
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: _openLinkedIn,
        ),
      ],
    );
  }

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
        leading: Icon(
          icon,
          color: ThemeService.kRailAmber,
        ),
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
              const Text('Před odesláním soupisu si vyberete kontakt z adresáře, na který se soupis odešle.'),
              const SizedBox(height: 16),
              const Text('2. Zaškrtněte políčko "Použít jako příjemce v kopii", pokud chcete sestavený soupis zasílat na kontakt vždy, společně s vybraným kontaktem.'),
              const SizedBox(height: 8),
              Text(
                '(Příklad: Vyberete kontakt sloužícího dispečera, v kopii je vedoucí útvaru nebo sdílený e-mail)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text('Kontakt označený jako příjemce v Kopii se již nebude nabízet pro výběr do pole "Komu".'),
              const SizedBox(height: 16),
              Text(
                'Poznámka: Jako "Příjemce v kopii" může být označen jen jeden kontakt.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
              onTap: () { Navigator.pop(context); _changeTheme(ThemeMode.light); },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Tmavý motiv'),
              onTap: () { Navigator.pop(context); _changeTheme(ThemeMode.dark); },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('Adaptace podle systému'),
              onTap: () { Navigator.pop(context); _changeTheme(ThemeMode.system); },
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
            const Text('Verze: 1.0.0'),
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
          const SnackBar(content: Text('Nelze otevřít odkaz na LinkedIn profil')),
        );
      }
    }
  }
}
