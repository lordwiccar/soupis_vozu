import 'package:flutter/material.dart';
import '../services/changelog_service.dart';
import '../services/theme_service.dart';

/// Dialog s přehledem changelogu appky. Sdílený mezi Nastavením (ruční
/// otevření) a automatickým zobrazením po aktualizaci appky.
Future<void> showChangelogDialog(BuildContext context) {
  return showDialog(
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
              for (final entry in changelogEntries) ...[
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
