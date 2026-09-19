import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../services/inventory_service.dart';
import '../services/theme_service.dart';
import '../services/tutorial_target_registry.dart';
import '../models/inventory.dart';
import '../widgets/adaptive/fold_info.dart';

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

  final _scanButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInventories();
    TutorialTargetRegistry.register('home.scanButton', _scanButtonKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    TutorialTargetRegistry.unregister('home.scanButton');
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
      if (!mounted) return;
      setState(() => _inventories = inventories);
    } catch (e) {
      if (!mounted) return;
      setState(() => _inventories = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fold = FoldInfo.of(context);
    return fold.isUnfolded
        ? _buildUnfoldedLayout(context)
        : _buildPhoneLayout(context);
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // Horní dekorativní pruh (jantarová linka pod AppBarem)
          Container(
            height: 3,
            color: ThemeService.kRailAmber,
          ),
          Expanded(child: _buildHeroSection(context)),
          _buildRecentInventoriesPanel(context, maxItems: 2),
        ],
      ),
    );
  }

  /// Na rozevřeném foldu je vlevo hero sekce se skenováním a vpravo panel
  /// posledních soupisů vedle sebe – místo aby byl panel jen úzký pruh dole.
  Widget _buildUnfoldedLayout(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Container(
            height: 3,
            color: ThemeService.kRailAmber,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildHeroSection(context)),
                SizedBox(
                  width: 360,
                  child: _buildRecentInventoriesPanel(
                    context,
                    maxItems: 6,
                    sideBySide: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('SOUPIS VOZŮ'),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Nastavení',
        ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.18, 0.82, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: Lottie.asset(
            'assets/wagon.json',
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                              ? ThemeService.kRailCream.withValues(alpha: 0.55)
                              : ThemeService.kRailBlack.withValues(alpha: 0.5),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: _scanButtonKey,
                      onPressed: () => Navigator.pushNamed(context, '/scan'),
                      icon:
                          const Icon(Icons.document_scanner_outlined, size: 20),
                      label: const Text('ZAHÁJIT SKENOVÁNÍ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Panel posledních soupisů. Na telefonu (`sideBySide == false`) je to
  /// úzký pruh dole s přirozenou výškou obsahu, přesně jako dřív. Na
  /// rozevřeném foldu (`sideBySide == true`) vyplní celou výšku pravého
  /// panelu a seznam se místo přetečení scrolluje.
  Widget _buildRecentInventoriesPanel(
    BuildContext context, {
    required int maxItems,
    bool sideBySide = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newestInventories = _inventories.take(maxItems).toList();

    final list = newestInventories.isEmpty
        ? Text(
            'Zatím žádné soupisy',
            style: Theme.of(context).textTheme.bodySmall,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: newestInventories
                .map((inventory) => Padding(
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
                                ? ThemeService.kRailSteel
                                    .withValues(alpha: 0.35)
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
                                style: Theme.of(context).textTheme.titleSmall,
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
                    ))
                .toList(),
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: sideBySide ? MainAxisSize.max : MainAxisSize.min,
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
        sideBySide ? Expanded(child: SingleChildScrollView(child: list)) : list,
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/inventories'),
            icon: const Icon(Icons.list_alt, size: 18),
            label: const Text('VŠECHNY SOUPISY'),
          ),
        ),
      ],
    );

    // SafeArea zajistí, že obsah nezmizí pod systémovou navigační lištou
    // (relevantní hlavně u klasické tlačítkové navigace).
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? ThemeService.kRailCharcoal : Colors.white,
          border: Border(
            top: sideBySide
                ? BorderSide.none
                : BorderSide(
                    color: ThemeService.kRailAmber.withValues(alpha: 0.6),
                    width: 2,
                  ),
            left: sideBySide
                ? BorderSide(
                    color: ThemeService.kRailAmber.withValues(alpha: 0.6),
                    width: 2,
                  )
                : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );
  }
}
