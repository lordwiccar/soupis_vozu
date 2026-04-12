import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory.dart';
import '../services/inventory_service.dart';
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
  final List<String> _statuses = ['M', 'K', 'R1', '314'];
  final Map<String, String> _statusDescriptions = {
    'M': 'Zkontrolovat',
    'K': 'Nenakládat / Po vyložení k opravě',
    'R1': 'Brzda neupotřebitelná',
    '314': 'Ještě použitelný',
  };

  // Funkce pro přidání příznaku R1
  void _addR1Flag() {
    setState(() {
      if (_selectedStatus.contains('R1')) {
        setState(() {
          // Odstranění R1 a případného + ze začátku
          _selectedStatus =
              _selectedStatus.replaceAll('R1', '').replaceAll('+', '').trim();
        });
      } else {
        setState(() {
          // Přidání +R1 k existujícímu příznaku
          if (_selectedStatus.trim().isNotEmpty) {
            _selectedStatus = '$_selectedStatus + R1';
          } else {
            _selectedStatus = 'R1';
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.wagon.notes ?? '';

    // Parsování příznaků z existujících poznámek
    if (widget.wagon.notes?.isNotEmpty == true) {
      final notes = widget.wagon.notes!;

      // Rozdělení na příznaky a poznámky podle ' - '
      final parts = notes.split(' - ');
      final flagsPart = parts[0]; // Část s příznaky (např. "K + M")
      final notesPart = parts.length > 1 ? parts.sublist(1).join(' - ') : ''; // Zbylá poznámka

      // Validace, že flagsPart obsahuje jen známé příznaky
      final validFlags = <String>[];
      for (final flag in _statuses) {
        if (flagsPart.contains(flag)) {
          validFlags.add(flag);
        }
      }

      if (validFlags.isNotEmpty) {
        // Příznaky jsou přítomny - nastav je v pořádí jak se vyskytují
        _selectedStatus = validFlags.join(' + ');
        _notesController.text = notesPart;
      } else {
        // Žádné známé příznaky - vše je poznámka
        _selectedStatus = '';
        _notesController.text = notes;
      }
    } else {
      _selectedStatus = ''; // Výchozí žádný příznak
      _notesController.text = '';
    }
  }

  // Výběr více příznaků najednou
  Future<void> _showMultipleFlagsDialog() async {
    final selectedFlags = <String>{};

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Výběr nálepky'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Vyberte nálepku (můžete vybrat více):'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses.map((flag) {
                  final isSelected = selectedFlags.contains(flag);
                  return FilterChip(
                    label: Text(flag),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        selectedFlags.add(flag);
                      } else {
                        selectedFlags.remove(flag);
                      }
                    },
                    backgroundColor:
                        isSelected ? Colors.blue : Colors.grey[300],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Zrušit'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, selectedFlags.toList());
                    },
                    child: const Text('Potvrdit'),
                  ),
                ],
              ),
            ],
          ),
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
          widget.wagon.number,
          result,
          widget.wagon.notes ?? '',
          UicValidator.validateUicNumber(result),
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
    // Správné vytvoření notes s příznaky a poznámkami
    late String newNotes;
    if (_selectedStatus.isNotEmpty) {
      if (_notesController.text.isNotEmpty) {
        newNotes = '${_selectedStatus} - ${_notesController.text}';
      } else {
        newNotes = _selectedStatus;
      }
    } else {
      newNotes = _notesController.text;
    }

    try {
      // Aktualizace existujícího záznamu
      await InventoryService.updateWagonNumber(
        widget.inventoryId,
        widget.wagon.number,
        widget.wagon.formattedNumber,
        newNotes,
        widget.wagon.isValid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Číslo vozu aktualizováno'),
            backgroundColor: Colors.green,
          ),
        );
        // Zavolat onUpdate callback pro aktualizaci seznamu
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
        // Zavolat onUpdate callback pro aktualizaci seznamu
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Číslo vozu ${widget.wagonIndex + 1}'),
        backgroundColor: const Color(0xFF4DA167),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actionsIconTheme: const IconThemeData(
          color: Colors.white,
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
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
                                  ? Colors.green
                                  : Colors.red,
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
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _editWagonNumber,
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
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
                                backgroundColor: Colors.blue,
                                labelStyle: const TextStyle(
                                  color: Colors.white,
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
                                        // Přidání příznaku
                                        if (_selectedStatus.trim().isEmpty) {
                                          _selectedStatus = status;
                                        } else if (!_selectedStatus
                                            .contains(status)) {
                                          _selectedStatus =
                                              '$_selectedStatus + $status';
                                        }
                                      } else {
                                        // Odebrání příznaku
                                        if (_selectedStatus == status) {
                                          _selectedStatus = '';
                                        } else {
                                          // Odstraníme příznak z kombinace
                                          final parts =
                                              _selectedStatus.split(' + ');
                                          parts.remove(status);
                                          _selectedStatus = parts.join(' + ');
                                        }
                                      }
                                    });
                                  },
                                  backgroundColor: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300],
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
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
                      backgroundColor:
                          widget.wagon.isValid ? Colors.green : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Uložit změny'),
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
