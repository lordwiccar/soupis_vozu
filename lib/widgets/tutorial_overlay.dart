import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class TutorialStep {
  final IconData icon;
  final String title;
  final String body;

  const TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const List<TutorialStep> kTutorialSteps = [
  // ── ÚVODNÍ OBRAZOVKA ─────────────────────────────────────────────────────
  TutorialStep(
    icon: Icons.waving_hand_outlined,
    title: 'Vítejte v aplikaci!',
    body: 'Provedeme vás základními funkcemi aplikace Soupis vozů. Průvodce můžete kdykoli přeskočit klepnutím na „Přeskočit".',
  ),
  TutorialStep(
    icon: Icons.document_scanner_outlined,
    title: 'Zahájení skenování',
    body: 'Tlačítkem ZAHÁJIT SKENOVÁNÍ spustíte kameru a začnete evidovat vozy. Ve spodním panelu najdete poslední soupisy a tlačítko pro přechod do jejich úplného seznamu.',
  ),

  // ── NASTAVENÍ ────────────────────────────────────────────────────────────
  TutorialStep(
    icon: Icons.contacts_outlined,
    title: 'Přidejte kontakty dispečerů',
    body: 'Toto je obrazovka Nastavení. Přidejte sem e-mailové kontakty dispečerů — na tyto adresy pak budete odesílat hotové soupisy jedním klepnutím.',
  ),
  TutorialStep(
    icon: Icons.dark_mode_outlined,
    title: 'Motiv aplikace',
    body: 'V nastavení si přepněte motiv dle svých potřeb. Tmavý motiv se hodí pro práci za šera nebo na přímém slunci.',
  ),

  // ── OBRAZOVKA SKENOVÁNÍ ──────────────────────────────────────────────────
  TutorialStep(
    icon: Icons.camera_alt_outlined,
    title: 'Skenování čísla vozu',
    body: 'Zamiřte kamerou na číslo vozu a stiskněte SKENOVAT. Aplikace číslo automaticky rozpozná. Pokud se to nepovede dvakrát za sebou, nabídne ruční zadání.',
  ),
  TutorialStep(
    icon: Icons.edit_note_outlined,
    title: 'Poznámky a nálepky',
    body: 'U každého vozu v seznamu klepněte na ikonu tužky. Otevře se detail vozu, kde přidáte poznámku nebo nálepku (M, K, R1, 314) označující stav vozu.',
  ),
  TutorialStep(
    icon: Icons.arrow_back_outlined,
    title: 'Ukončení skenování',
    body: 'Po naskenování celého vlaku klepněte na šipku zpět v záhlaví. Soupis se uloží automaticky a vrátíte se na úvodní obrazovku.',
  ),

  // ── SEZNAM SOUPISŮ ────────────────────────────────────────────────────────
  TutorialStep(
    icon: Icons.swap_vert_outlined,
    title: 'Správa soupisů',
    body: 'Toto je seznam všech vytvořených soupisů. Klepnutím na název zobrazíte detail — zde přetažením změníte pořadí vozů nebo přidáte vůz, který byl přeskočen.',
  ),
  TutorialStep(
    icon: Icons.send_outlined,
    title: 'Odeslání dispečerovi',
    body: 'Hotový soupis odešlete e-mailem klepnutím na tlačítko Odeslat. Aplikace vytvoří zprávu s kompletním soupisem — stačí vybrat kontakt a potvrdit odeslání. To je vše!',
  ),
];

class TutorialOverlay extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const TutorialOverlay({
    super.key,
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final s = kTutorialSteps[step];
    final isLast = step == kTutorialSteps.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? ThemeService.kRailCharcoal : Colors.white;
    final mutedColor = isDark
        ? ThemeService.kRailCream.withValues(alpha: 0.4)
        : ThemeService.kRailBlack.withValues(alpha: 0.38);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Ztlumené pozadí — blokuje interakci s aplikací
          GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.52)),
          ),

          // Karta dole
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pruh průběhu
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: LinearProgressIndicator(
                        value: (step + 1) / kTutorialSteps.length,
                        backgroundColor: isDark
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
                        children: [
                          // Ikona + nadpis + krok X/Y
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(s.icon,
                                  color: ThemeService.kRailAmber, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${step + 1} / ${kTutorialSteps.length}',
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Popis kroku
                          Text(
                            s.body,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),

                          const SizedBox(height: 18),

                          // Tlačítka
                          Row(
                            children: [
                              TextButton(
                                onPressed: onSkip,
                                style: TextButton.styleFrom(
                                    foregroundColor: mutedColor),
                                child: const Text('Přeskočit'),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: onNext,
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
            ),
          ),
        ],
      ),
    );
  }
}
