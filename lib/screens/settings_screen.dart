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
    final isDark = themeMode == ThemeMode.dark;
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        backgroundColor: const Color(0xFF591664),
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.contacts_outlined),
              text: 'Adresář',
            ),
            Tab(
              icon: Icon(Icons.palette_outlined),
              text: 'Motiv',
            ),
            Tab(
              icon: Icon(Icons.info_outline),
              text: 'O aplikaci',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildThemeTab(),
          _buildAboutTab(),
        ],
      ),
    );
  }

  Widget _buildContactsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.contacts_outlined,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.purple,
              ),
              title: const Text('Správa kontaktů'),
              subtitle: const Text(
                  'Přidávejte, upravujte a mažte kontakty pro odesílání soupisů'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ContactsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.help_outline,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.purple,
              ),
              title: const Text('Jak používat adresář'),
              subtitle: const Text('Návod pro nastavení příjemců soupisů'),
              onTap: () {
                _showCopyRecipientHelp();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.purple,
              ),
              title: const Text('Nastavení motivu'),
              subtitle: Text(_getThemeDisplayName()),
              onTap: () => _showThemeSelectionDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.info,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.purple,
              ),
              title: const Text('O aplikaci'),
              subtitle: const Text('Soupis vozů - verze 1.0.0'),
              onTap: () {
                _showAboutDialog();
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Autor profil'),
              subtitle: const Text('Navštivte LinkedIn profil autora'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse(
                    'https://www.linkedin.com/in/daniel-macho-8ab0477a/');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  // Handle error - show snackbar or dialog
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nelze otevřít odkaz na LinkedIn profil'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeDisplayName() {
    final themeMode = Theme.of(context).brightness;
    if (themeMode == Brightness.dark) {
      return 'Tmavý motiv';
    } else {
      return 'Světlý motiv';
    }
  }

  void _showCopyRecipientHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Příjemci v Kopii'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jak nastavit příjemce soupisů:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              const Text('1. V sekci "Adresář" přidejte nový kontakt.'),
              const SizedBox(height: 8),
              const Text(
                  'Před odesláním soupisu si vyberete kontakt z adresáře, na který se soupis odešle.'),
              const SizedBox(height: 16),
              const Text(
                  '2. Zaškrtněte políčko "Použít jako příjemce v kopii", pokud chcete sestavený soupis zasílat na kontakt vždy, společně s vybraným kontaktem.'),
              const SizedBox(height: 8),
              const Text(
                '(Příklad: Vyberete kontakt sloužícího dispečera, v kopii je vedoucí útvaru nebo sdílený e-mail)',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              const Text(
                  'Kontakt označený jako příjemce v Kopii se již nebude nabízet pro výběr do pole "Komu".'),
              const SizedBox(height: 24),
              Text(
                'Poznámka: Jako "Příjemce v kopii" může být označen je jeden kontakt.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
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
    setState(() {
      _isDarkMode = themeMode == ThemeMode.dark;
    });
    await ThemeService.setThemeMode(themeMode);

    // Zavolání callback pro aktualizaci hlavní aplikace
    widget.onThemeChanged(themeMode);
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O aplikaci'),
        // Zde bylo odstraněno slovo 'const'
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Původní texty, kterým jsem musel přidat vlastní 'const'
            const Text('Soupis vozů'),
            const SizedBox(height: 8),
            const Text('Verze: 1.0.0'),
            const SizedBox(height: 8),
            const Text('Aplikace pro vytváření soupisů železničních vozů.'),
            const SizedBox(height: 16),
            Center(
              child: const Text('© White Whale Media 2026'),
            ),
            // Přidání obrázku a jeho vycentrování
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                'assets/wwm.png', // Změň na cestu ke svému obrázku
                height: 60, // Volitelná úprava velikosti
              ),
            ),
            const SizedBox(height: 16), // Mezera mezi obrázkem a textem
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
}
