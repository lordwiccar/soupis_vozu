import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/inventory.dart';
import '../models/wagon_registry_entry.dart';
import '../services/decimal_input.dart';
import '../services/theme_service.dart';
import '../services/wagon_registry_service.dart';

/// Prohledávatelný seznam trvalého registru vozů – dostupný z Nastavení.
/// Umožňuje ruční úpravu/smazání jednotlivých záznamů a export/import
/// celé databáze jako .xlsx.
class WagonDatabaseScreen extends StatefulWidget {
  const WagonDatabaseScreen({super.key});

  @override
  State<WagonDatabaseScreen> createState() => _WagonDatabaseScreenState();
}

class _WagonDatabaseScreenState extends State<WagonDatabaseScreen> {
  List<WagonRegistryEntry> _allEntries = [];
  List<WagonRegistryEntry> _filteredEntries = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await WagonRegistryService.getAll();
      if (!mounted) return;
      setState(() {
        _allEntries = entries;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allEntries = [];
        _filteredEntries = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredEntries = List.of(_allEntries);
      return;
    }
    _filteredEntries = _allEntries.where((entry) {
      return entry.formattedNumber.toLowerCase().contains(query) ||
          entry.notes.toLowerCase().contains(query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilter();
    });
  }

  String _technicalSummary(WagonRegistryEntry entry) {
    final parts = <String>[];
    if (entry.weight != null) parts.add('${formatDecimal(entry.weight)} t');
    if (entry.brakeWeightG != null) {
      parts.add('G ${formatDecimal(entry.brakeWeightG)} t');
    }
    if (entry.brakeWeightP != null) {
      parts.add('P ${formatDecimal(entry.brakeWeightP)} t');
    }
    if (entry.handbrake) {
      parts.add(entry.handbrakeForceKn != null
          ? 'RB ${formatDecimal(entry.handbrakeForceKn)} kN'
          : 'RB ano');
    }
    if (entry.maxSpeed != null) {
      parts.add('${formatDecimal(entry.maxSpeed)} km/h');
    }
    if (entry.length != null) parts.add('${formatDecimal(entry.length)} m');
    return parts.join(' • ');
  }

  Widget _buildDecimalField({
    required TextEditingController controller,
    required String label,
    required String suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _editEntry(WagonRegistryEntry entry) async {
    final parsed = WagonNumber.parseNotes(entry.notes);
    final selectedFlags = List<String>.of(parsed.flags);
    final textController = TextEditingController(text: parsed.text);
    final weightController =
        TextEditingController(text: formatDecimal(entry.weight));
    final brakeWeightGController =
        TextEditingController(text: formatDecimal(entry.brakeWeightG));
    final brakeWeightPController =
        TextEditingController(text: formatDecimal(entry.brakeWeightP));
    final maxSpeedController =
        TextEditingController(text: formatDecimal(entry.maxSpeed));
    final lengthController =
        TextEditingController(text: formatDecimal(entry.length));
    final handbrakeForceController =
        TextEditingController(text: formatDecimal(entry.handbrakeForceKn));
    bool handbrake = entry.handbrake;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry.formattedNumber),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nálepka:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: WagonNumber.allFlags.map((flag) {
                    final isSelected = selectedFlags.contains(flag);
                    return ChoiceChip(
                      label: Text(flag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedFlags.add(flag);
                          } else {
                            selectedFlags.remove(flag);
                          }
                        });
                      },
                      backgroundColor:
                          isSelected ? ThemeService.kRailAmber : null,
                      labelStyle: TextStyle(
                        color: isSelected ? ThemeService.kRailBlack : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámka',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Technické údaje:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDecimalField(
                        controller: weightController,
                        label: 'Hmotnost vozu',
                        suffix: 't',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDecimalField(
                        controller: lengthController,
                        label: 'Délka',
                        suffix: 'm',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDecimalField(
                        controller: brakeWeightGController,
                        label: 'Brzdící váha G',
                        suffix: 't',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDecimalField(
                        controller: brakeWeightPController,
                        label: 'Brzdící váha P',
                        suffix: 't',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDecimalField(
                  controller: maxSpeedController,
                  label: 'Rychlost',
                  suffix: 'km/h',
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ruční brzda'),
                  value: handbrake,
                  activeTrackColor: ThemeService.kRailAmber,
                  onChanged: (value) {
                    setDialogState(() => handbrake = value);
                  },
                ),
                if (handbrake) ...[
                  const SizedBox(height: 4),
                  _buildDecimalField(
                    controller: handbrakeForceController,
                    label: 'Hodnota ruční brzdy',
                    suffix: 'kN',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Uložit'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final newNotes =
        WagonNumber.composeNotes(selectedFlags, textController.text.trim());
    try {
      await WagonRegistryService.upsertFromWagon(
        number: entry.number,
        formattedNumber: entry.formattedNumber,
        notes: newNotes,
        weight: parseDecimal(weightController.text),
        brakeWeightG: parseDecimal(brakeWeightGController.text),
        brakeWeightP: parseDecimal(brakeWeightPController.text),
        handbrake: handbrake,
        handbrakeForceKn:
            handbrake ? parseDecimal(handbrakeForceController.text) : null,
        maxSpeed: parseDecimal(maxSpeedController.text),
        length: parseDecimal(lengthController.text),
      );
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při ukládání: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(WagonRegistryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat záznam'),
        content: Text(
            'Opravdu chcete smazat záznam pro vůz ${entry.formattedNumber}? Tuto akci nelze vrátit zpět.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušit')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Smazat')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await WagonRegistryService.deleteEntry(entry.number);
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při mazání: $e')),
        );
      }
    }
  }

  Future<void> _exportDatabase() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final file = await WagonRegistryService.exportToXlsx();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Databáze vozů – export',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při exportu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importDatabase() async {
    if (_isBusy) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _isBusy = true);
    try {
      final importResult = await WagonRegistryService.importFromXlsx(path);
      await _loadEntries();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import dokončen'),
            content: Text(
              'Přidáno nových vozů: ${importResult.added}\n'
              'Přeskočeno (už existují): ${importResult.skippedExisting}\n'
              'Neplatných řádků: ${importResult.invalidRows}',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při importu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DATABÁZE VOZŮ'),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _exportDatabase,
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Exportovat databázi (.xlsx)',
          ),
          IconButton(
            onPressed: _isBusy ? null : _importDatabase,
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Importovat databázi (.xlsx)',
          ),
        ],
      ),
      body: Column(
        children: [
          ThemeService.amberStripe,
          if (_isBusy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Hledat podle čísla vozu nebo poznámky...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storage_outlined,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Databáze je zatím prázdná',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : _filteredEntries.isEmpty
                        ? Center(
                            child: Text('Žádný vůz neodpovídá hledání',
                                style: TextStyle(color: Colors.grey[600])),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            itemCount: _filteredEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _filteredEntries[index];
                              final parsed =
                                  WagonNumber.parseNotes(entry.notes);
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    parsed.flags.isNotEmpty
                                        ? Icons.flag
                                        : entry.hasInfo
                                            ? Icons.info_outline
                                            : Icons.train_outlined,
                                    color: parsed.flags.isNotEmpty
                                        ? ThemeService.kRailAmber
                                        : Colors.grey,
                                  ),
                                  title: Text(entry.formattedNumber),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (entry.notes.isNotEmpty)
                                        Text(entry.notes),
                                      if (_technicalSummary(entry).isNotEmpty)
                                        Text(
                                          _technicalSummary(entry),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      if (!entry.hasInfo)
                                        Text(
                                          'Bez informací',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[500]),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat.yMd()
                                            .format(entry.updatedAt),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteEntry(entry),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _editEntry(entry),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
