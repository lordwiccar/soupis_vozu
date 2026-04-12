import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../services/inventory_service.dart';
import '../services/theme_service.dart';
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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInventories();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isResumed) {
      _debouncedLoadInventories();
      _isResumed = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        _isResumed = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _debouncedLoadInventories();
  }

  void _debouncedLoadInventories() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadInventories();
    });
  }

  Future<void> _loadInventories() async {
    if (!mounted) return;
    try {
      final inventories = await InventoryService.getAllInventories();
      inventories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _inventories = inventories);
    } catch (e) {
      setState(() => _inventories = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newestInventories = _inventories.take(2).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOUPIS VOZŮ'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
          ),
        ],
      ),
      body: Column(
        children: [
          // Horní dekorativní pruh (jantarová linka pod AppBarem)
          Container(
            height: 3,
            color: ThemeService.kRailAmber,
          ),

          // Hlavní obsah
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/wagon.json',
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'VÍTEJTE V APLIKACI\nPRO SOUPIS VOZŮ',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Skenujte čísla vozů a vytvářejte soupisy',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? ThemeService.kRailCream.withValues(alpha:0.55)
                            : ThemeService.kRailBlack.withValues(alpha:0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/scan'),
                        icon: const Icon(Icons.document_scanner_outlined, size: 20),
                        label: const Text('ZAHÁJIT SKENOVÁNÍ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sekce posledních soupisů
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? ThemeService.kRailCharcoal : Colors.white,
              border: Border(
                top: BorderSide(
                  color: ThemeService.kRailAmber.withValues(alpha:0.6),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: ThemeService.kRailAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'POSLEDNÍ SOUPISY',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (newestInventories.isEmpty)
                  Text(
                    'Zatím žádné soupisy',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ...newestInventories.map((inventory) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () =>
                              Navigator.pushNamed(context, '/inventories'),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ThemeService.kRailSteel.withValues(alpha:0.35)
                                  : ThemeService.kRailCream,
                              borderRadius: BorderRadius.circular(4),
                              border: Border(
                                left: BorderSide(
                                  color: ThemeService.kRailAmber,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inventory.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Vytvořeno: ${DateFormat.yMd().add_Hm().format(inventory.createdAt)}  ·  Vozů: ${inventory.wagonNumbers.length}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/inventories'),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('VŠECHNY SOUPISY'),
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
