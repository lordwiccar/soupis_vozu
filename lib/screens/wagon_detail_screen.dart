import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory.dart';
import '../services/decimal_input.dart';
import '../services/inventory_service.dart';
import '../services/theme_service.dart';
import '../services/uic_validator.dart';

class WagonDetailScreen extends StatefulWidget {
  final String inventoryId;
  final WagonNumber wagon;
  final int wagonIndex;
  final Function(String, String, String) onUpdate;

  const WagonDetailScreen({
    super.key,
    required this.inventoryId,
    required this.wagon,
    required this.wagonIndex,
    required this.onUpdate,
  });

  @override
  State<WagonDetailScreen> createState() => _WagonDetailScreenState();
}

class _WagonDetailScreenState extends State<WagonDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  String _selectedStatus = ''; // Výchozí žádný příznak
  final List<String> _statuses = WagonNumber.allFlags;
  final Map<String, String> _statusDescriptions = WagonNumber.flagDescriptions;

  // Technické údaje o voze
  final _weightController = TextEditingController();
  final _brakeWeightGController = TextEditingController();
  final _brakeWeightPController = TextEditingController();
  bool _handbrake = false;
  final _handbrakeForceController = TextEditingController();
  final _maxSpeedController = TextEditingController();
  final _lengthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Parsování příznaků z existujících poznámek
    final parsed = WagonNumber.parseNotes(widget.wagon.notes);
    _selectedStatus = parsed.flags.join(' + ');
    _notesController.text = parsed.text;

    _weightController.text = formatDecimal(widget.wagon.weight);
    _brakeWeightGController.text = formatDecimal(widget.wagon.brakeWeightG);
    _brakeWeightPController.text = formatDecimal(widget.wagon.brakeWeightP);
    _handbrake = widget.wagon.handbrake;
    _handbrakeForceController.text =
        formatDecimal(widget.wagon.handbrakeForceKn);
    _maxSpeedController.text = formatDecimal(widget.wagon.maxSpeed);
    _lengthController.text = formatDecimal(widget.wagon.length);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    _brakeWeightGController.dispose();
    _brakeWeightPController.dispose();
    _handbrakeForceController.dispose();
    _maxSpeedController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  Future<void> _editWagonNumber() async {
    final controller =
        TextEditingController(text: widget.wagon.formattedNumber);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upravit číslo vozu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadejte správné číslo vozu:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Číslo vozu',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              final newNumber = controller.text.trim();
              if (newNumber.isNotEmpty) {
                Navigator.pop(context, newNumber);
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );

    if (result != null && result != widget.wagon.formattedNumber) {
      try {
        await InventoryService.updateWagonNumber(
          widget.inventoryId,
          widget.wagon.copyWith(
            formattedNumber: result,
            isValid: UicValidator.validateUicNumber(result),
          ),
        );

        if (mounted) {
          widget.onUpdate(
              result, widget.wagon.notes ?? '', 'Upraveno číslo vozu');
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Číslo vozu bylo úspěšně upraveno'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba při úpravě čísla: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateWagon() async {
    final newNotes = WagonNumber.composeNotes(
      _selectedStatus.isEmpty ? [] : _selectedStatus.split(' + '),
      _notesController.text,
    );

    // Pozor: záměrně nepoužíváme copyWith – ten by (kvůli ?? sémantice)
    // nedokázal vynulovat pole, které uživatel v poli smazal. Zde vždy
    // zapisujeme přesně to, co formulář právě obsahuje.
    final updatedWagon = WagonNumber(
      number: widget.wagon.number,
      formattedNumber: widget.wagon.formattedNumber,
      isValid: widget.wagon.isValid,
      order: widget.wagon.order,
      scannedAt: widget.wagon.scannedAt,
      notes: newNotes,
      weight: parseDecimal(_weightController.text),
      brakeWeightG: parseDecimal(_brakeWeightGController.text),
      brakeWeightP: parseDecimal(_brakeWeightPController.text),
      handbrake: _handbrake,
      handbrakeForceKn:
          _handbrake ? parseDecimal(_handbrakeForceController.text) : null,
      maxSpeed: parseDecimal(_maxSpeedController.text),
      length: parseDecimal(_lengthController.text),
    );

    try {
      await InventoryService.updateWagonNumber(
        widget.inventoryId,
        updatedWagon,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Číslo vozu aktualizováno'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdate(
            widget.wagon.formattedNumber, newNotes, _selectedStatus);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při aktualizaci: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteWagonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odstranit vůz'),
        content: Text(
            'Opravdu chcete odstranit vůz ${widget.wagon.formattedNumber} ze soupisu? Tuto akci nelze vrátit zpět.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWagon();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Odstranit'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWagon() async {
    try {
      await InventoryService.deleteWagonNumber(
          widget.inventoryId, widget.wagon.number);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vůz byl úspěšně odstraněn'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdate(widget.wagon.formattedNumber, '', '');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při odstraňování vozu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ČÍSLO VOZU ${widget.wagonIndex + 1}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).viewInsets.bottom -
                kToolbarHeight -
                kBottomNavigationBarHeight,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Základní informace o čísle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.wagon.isValid
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: widget.wagon.isValid
                                  ? ThemeService.kValidGreen
                                  : ThemeService.kValidRed,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.wagon.formattedNumber,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: widget.wagon.isValid
                                                ? ThemeService.kValidGreen
                                                : ThemeService.kValidRed,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _editWagonNumber,
                                        icon: const Icon(Icons.edit_outlined,
                                            color: ThemeService.kRailSlate),
                                        tooltip: 'Upravit číslo vozu',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    widget.wagon.isValid
                                        ? 'Platné UIC číslo'
                                        : 'Neplatné UIC číslo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text(_selectedStatus),
                                selected: true,
                                onSelected: null, // Nelze změnit
                                backgroundColor: ThemeService.kRailAmber,
                                labelStyle: const TextStyle(
                                  color: ThemeService.kRailBlack,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Skenováno: ${DateFormat.yMd().add_Hm().format(widget.wagon.scannedAt)}',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Výběr příznaku
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nálepka:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _statuses.map((status) {
                            final isSelected = _selectedStatus.contains(status);
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  label: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: isSelected ? 13 : 14,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        if (_selectedStatus.trim().isEmpty) {
                                          _selectedStatus = status;
                                        } else if (!_selectedStatus
                                            .contains(status)) {
                                          _selectedStatus =
                                              '$_selectedStatus + $status';
                                        }
                                      } else {
                                        if (_selectedStatus == status) {
                                          _selectedStatus = '';
                                        } else {
                                          final parts =
                                              _selectedStatus.split(' + ');
                                          parts.remove(status);
                                          _selectedStatus = parts.join(' + ');
                                        }
                                      }
                                    });
                                  },
                                  backgroundColor: isSelected
                                      ? ThemeService.kRailAmber
                                      : null,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? ThemeService.kRailBlack
                                        : null,
                                    fontSize: isSelected ? 12 : 13,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 6),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusDescriptions[_selectedStatus] ?? '',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Pole pro poznámky
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Poznámky:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Poznámky',
                            hintText: 'Zadejte doplňující informace...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            suffixIcon: Icon(Icons.clear),
                          ),
                          maxLines: 3,
                          onTap: () {
                            // Vymazání při prvním kliknutí pokud obsahuje výchozí text
                            if (_notesController.text.isNotEmpty &&
                                _notesController.text == _selectedStatus) {
                              _notesController.clear();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Doplňující informace o stavu vozu, poškození atd.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Technické údaje o voze
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Technické údaje:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDecimalField(
                                controller: _weightController,
                                label: 'Hmotnost vozu',
                                suffix: 't',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDecimalField(
                                controller: _lengthController,
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
                                controller: _brakeWeightGController,
                                label: 'Brzdící váha G',
                                suffix: 't',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDecimalField(
                                controller: _brakeWeightPController,
                                label: 'Brzdící váha P',
                                suffix: 't',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDecimalField(
                          controller: _maxSpeedController,
                          label: 'Rychlost',
                          suffix: 'km/h',
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ruční brzda'),
                          value: _handbrake,
                          activeTrackColor: ThemeService.kRailAmber,
                          onChanged: (value) {
                            setState(() => _handbrake = value);
                          },
                        ),
                        if (_handbrake) ...[
                          const SizedBox(height: 4),
                          _buildDecimalField(
                            controller: _handbrakeForceController,
                            label: 'Hodnota ruční brzdy',
                            suffix: 'kN',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tlačítko pro odstranění vozu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteWagonDialog(),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Odstranit vůz ze soupisu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Hlavní tlačítka
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Zpět'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateWagon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.wagon.isValid
                          ? ThemeService.kRailAmber
                          : Colors.orange,
                      foregroundColor: ThemeService.kRailBlack,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text('ULOŽIT ZMĚNY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
