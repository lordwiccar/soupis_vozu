import 'package:flutter/material.dart';
import '../models/tutorial_step.dart';
import '../services/theme_service.dart';
import '../services/tutorial_controller.dart';

/// Spotlight/coach-mark překryv tutoriálu: ztlumí celou obrazovku a
/// "prosvítí" jen widget zvýrazněný aktuálním krokem (viz [TutorialStep]).
class SpotlightOverlay extends StatelessWidget {
  final TutorialController controller;

  const SpotlightOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final step = controller.current;
    final isLast = controller.isLastStep;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? ThemeService.kRailCharcoal : Colors.white;
    final mutedColor = isDark
        ? ThemeService.kRailCream.withValues(alpha: 0.4)
        : ThemeService.kRailBlack.withValues(alpha: 0.38);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Ztlumené pozadí s výřezem kolem zvýrazněného widgetu – blokuje
          // interakci s aplikací mimo cíl tutoriálu.
          Positioned.fill(
            child: IgnorePointer(
              child: _AnimatedHole(
                rect: controller.currentRect,
                shape: step.shape,
                padding: step.holePadding,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),

          _buildCard(context, step, isLast, cardBg, mutedColor),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, TutorialStep step, bool isLast,
      Color cardBg, Color mutedColor) {
    final screen = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    const margin = 12.0;
    // Odhad výšky vše kromě textu těla (progress bar, nadpis, mezery,
    // řádek s tlačítky) – slouží jen k výpočtu bezpečných mezí, skutečný
    // Column se stejně sám přizpůsobí obsahu.
    const chromeHeight = 132.0;
    // Rezerva na text těla kroku – karta se nikde neořezává ani
    // nescrolluje, výška je vždy daná skutečným obsahem (viz komentář u
    // Textu níž). Hodnota tu slouží jen k odhadu, kam kartu umístit, aby
    // se u našich (pevně daných, přiměřeně krátkých) textů kroků vešla
    // celá na obrazovku.
    const bodyBudget = 180.0;

    // Bez konkrétního cíle (úvod/závěr) se chováme, jako by cílem byl
    // neviditelný bod u spodního okraje – karta tak skončí zavěšená u
    // spodku obrazovky, stejně jako dřív.
    final rect = controller.currentRect ??
        Rect.fromLTWH(0, screen.height - safeArea.bottom, screen.width, 0);

    final spaceBelow = screen.height - rect.bottom - safeArea.bottom;
    final spaceAbove = rect.top - safeArea.top;

    // Preferované umístění: pod cílem, pokud je tam víc místa, jinak nad
    // ním. Pozice se navíc ořízne do bezpečného rozsahu níž, aby karta
    // nezačínala nad horním nebo pod dolním okrajem obrazovky ani když
    // je zvýrazněná oblast obrovská nebo leží mimo viditelnou část.
    double top = spaceBelow >= spaceAbove
        ? rect.bottom + margin
        : rect.top - margin - (chromeHeight + bodyBudget);

    final minTop = safeArea.top + margin;
    final maxTop =
        screen.height - safeArea.bottom - margin - (chromeHeight + bodyBudget);
    top = top.clamp(minTop, maxTop < minTop ? minTop : maxTop);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      left: 12,
      right: 12,
      top: top,
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: (controller.stepIndex + 1) / controller.steps.length,
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeService.kRailSteel
                        : const Color(0xFFEDE6DE),
                color: ThemeService.kRailAmber,
                minHeight: 3,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(step.icon, color: ThemeService.kRailAmber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${controller.stepIndex + 1} / ${controller.steps.length}',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Žádné scrollování ani ořezávání – karta je vždy tak
                  // vysoká, jak potřebuje skutečný text kroku.
                  Text(
                    step.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: controller.skip,
                        style:
                            TextButton.styleFrom(foregroundColor: mutedColor),
                        child: const Text('Přeskočit'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: controller.next,
                        child: Text(isLast ? 'Hotovo' : 'Další →'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Implicitně animuje přechod výřezu mezi kroky. Na rozdíl od
/// `TweenAnimationBuilder<Rect?>` zvládá i `null` (bez cíle = celá
/// obrazovka ztlumená), kde by `RectTween` s `end == null` spadl na
/// assertu.
class _AnimatedHole extends StatefulWidget {
  final Rect? rect;
  final SpotlightShape shape;
  final EdgeInsets padding;

  const _AnimatedHole({
    required this.rect,
    required this.shape,
    required this.padding,
  });

  @override
  State<_AnimatedHole> createState() => _AnimatedHoleState();
}

class _AnimatedHoleState extends State<_AnimatedHole>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    _to = widget.rect;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant _AnimatedHole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rect != widget.rect) {
      _from = _currentRect();
      _to = widget.rect;
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _currentRect() {
    if (_from == null || _to == null) return _to ?? _from;
    return Rect.lerp(_from, _to, _controller.value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _SpotlightPainter(
          holeRect: _currentRect(),
          shape: widget.shape,
          padding: widget.padding,
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? holeRect;
  final SpotlightShape shape;
  final EdgeInsets padding;

  _SpotlightPainter({
    required this.holeRect,
    required this.shape,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrimColor = Colors.black.withValues(alpha: 0.65);
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (holeRect == null || shape == SpotlightShape.none) {
      canvas.drawRect(screenRect, Paint()..color = scrimColor);
      return;
    }

    final padded = Rect.fromLTRB(
      holeRect!.left - padding.left,
      holeRect!.top - padding.top,
      holeRect!.right + padding.right,
      holeRect!.bottom + padding.bottom,
    );

    final screenPath = Path()..addRect(screenRect);
    final Path holePath;
    if (shape == SpotlightShape.circle) {
      holePath = Path()
        ..addOval(Rect.fromCircle(
          center: padded.center,
          radius: padded.shortestSide / 2,
        ));
    } else {
      holePath = Path()
        ..addRRect(RRect.fromRectAndRadius(padded, const Radius.circular(12)));
    }

    final combined =
        Path.combine(PathOperation.difference, screenPath, holePath);
    canvas.drawPath(combined, Paint()..color = scrimColor);
    canvas.drawPath(
      holePath,
      Paint()
        ..color = ThemeService.kRailAmber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.holeRect != holeRect ||
      oldDelegate.shape != shape ||
      oldDelegate.padding != padding;
}
