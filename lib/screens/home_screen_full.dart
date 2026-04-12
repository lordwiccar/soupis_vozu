import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../services/inventory_service.dart';
import '../models/inventory.dart';

class HomeScreenFull extends StatefulWidget {
  const HomeScreenFull({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;

  @override
  State<HomeScreenFull> createState() => _HomeScreenFullState();
}

class _HomeScreenFullState extends State<HomeScreenFull>
    with WidgetsBindingObserver {
  List<Inventory> _inventories = [];
  bool _isResumed = false;
  Timer? _debounceTimer; // Debounce pro zabránění častým voláním

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInventories();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel(); // Uklidíme timer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isResumed) {
      // Aplikace se vrátila do popředí, aktualizujeme data
      _debouncedLoadInventories();
      _isResumed = true;
      // Reset flagu po krátké době
      Future.delayed(const Duration(milliseconds: 500), () {
        _isResumed = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Vždy obnovíme data při návratu na tuto obrazovku
    // Tím zajistíme aktuálnost dat i po smazání soupisů
    print('🔄 didChangeDependencies voláno - vynucená aktualizace soupisů');
    _debouncedLoadInventories();
  }

  // Debounce mechanismus pro zabránění příliš častým voláním
  void _debouncedLoadInventories() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadInventories();
      }
    });
  }

  Future<void> _loadInventories() async {
    if (!mounted) return;

    print('🔄 Obnovuji seznam soupisů v home_screen_full.dart');

    try {
      final inventories = await InventoryService.getAllInventories();
      // Seřazení soupisů sestupně (nejnovější nahoře)
      inventories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('📊 Načteno ${inventories.length} soupisů');

      setState(() {
        _inventories = inventories;
      });
    } catch (e) {
      print('❌ Chyba při načítání soupisů: $e');
      setState(() {
        _inventories = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Soupisy jsou již seřazené sestupně, vezmeme první 2
    final newestInventories = _inventories.take(2).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soupis vozů'),
        backgroundColor: const Color(0xFF591664),
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Nastavení',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Hlavní obsah
          Expanded(
            child: Center(
              child: Flex(
                direction: Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/wagon.json',
                    width: 200, // Zde si můžeš upravit šířku animace
                    height: 200, // Zde si můžeš upravit výšku animace
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Vítejte v aplikaci pro soupis vozů',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Skenujte čísla vozů a vytvářejte soupisy',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/scan');
                    },
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Zahájit skenování'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF591664),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zkratka s posledními soupisy
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF091620)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Poslední soupisy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE3ABED)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (newestInventories.isEmpty)
                  const Text(
                    'Zatím žádné soupisy',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9E9E9E),
                    ),
                  )
                else
                  ...newestInventories.map((inventory) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            // Přejdi na seznam soupisů
                            Navigator.pushNamed(context, '/inventories');
                          },
                          child: Container(
                            width: double.infinity, // Roztáhne na celou šířku
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF0D2130)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[600]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inventory.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vytvořeno: ${DateFormat.yMd().add_Hm().format(inventory.createdAt)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Počet vozů: ${inventory.wagonNumbers.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 12),
                // Tlačítko pro celý výpis
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/inventories');
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Všechny soupisy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3ABED),
                      foregroundColor: const Color(0xFF9C27B0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
