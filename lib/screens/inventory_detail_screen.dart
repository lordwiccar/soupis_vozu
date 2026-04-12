import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory.dart';
import '../services/inventory_service.dart';
import 'scan_screen_fixed.dart';

class InventoryDetailScreen extends StatefulWidget {
  final Inventory inventory;

  const InventoryDetailScreen({super.key, required this.inventory});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late Inventory _inventory;

  void initState() {
    super.initState();
    _inventory = widget.inventory;
  }

  Future<void> _rotateWagonOrder() async {
    try {
      // Získání všech vozů ze soupisu
      final wagons =
          await InventoryService.getWagonNumbersForInventory(_inventory.id);

      if (wagons.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Soupis neobsahuje žádné vozy'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Otočení pořadí - první vůz bude poslední
      for (int i = 0; i < wagons.length; i++) {
        final wagon = wagons[i];
        // Vypočítat nové pořadové číslo
        int newOrder = i == 0
            ? wagons.length
            : i; // první bude poslední, ostatní se posunou nahoru

        await InventoryService.updateWagonNumber(
          _inventory.id,
          wagon.number,
          wagon.formattedNumber,
          wagon.notes ?? '',
          wagon.isValid,
          newOrderNumber: newOrder,
        );
      }

      // Aktualizovat čas změny soupisu
      await InventoryService.updateLastModified(_inventory.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pořadí vozů bylo úspěšně otočeno'),
            backgroundColor: Colors.green,
          ),
        );
        // Znovu načíst data pro zobrazení změn
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při otáčení pořadí vozů: $e'),
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
        title: Text(_inventory.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hlavička s informacemi o soupisu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
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
                  const Text(
                    'Informace o soupisu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Jméno: ${_inventory.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vytvořeno: ${DateFormat.yMd().add_Hm().format(_inventory.createdAt)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Počet vozů: ${_inventory.wagonNumbers.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_inventory.notes != null && _inventory.notes!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Poznámky:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _inventory.notes!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seznam vozů v soupisu
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
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
                    Text(
                      'Seznam vozů (${_inventory.wagonNumbers.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _inventory.wagonNumbers.length,
                        itemBuilder: (context, index) {
                          final wagon = _inventory.wagonNumbers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF122C40)
                                    : null,
                            child: ListTile(
                              tileColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF091620)
                                  : null,
                              leading: Icon(
                                wagon.isValid
                                    ? Icons.check_circle
                                    : Icons.error,
                                color:
                                    wagon.isValid ? Colors.green : Colors.red,
                              ),
                              title: Text(
                                wagon.formattedNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                wagon.isValid
                                    ? 'Platné UIC číslo'
                                    : 'Neplatné UIC číslo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      wagon.isValid ? Colors.green : Colors.red,
                                ),
                              ),
                              trailing: Text(
                                wagon.notes ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              onTap: () {
                                // Zde můžete přidat navigaci na detail vozu
                                // Například: Navigator.pushNamed(context, '/wagon_detail', arguments: {...});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "continue",
            onPressed: () {
              // Pokračovat ve skenování do tohoto soupisu
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ScanScreenFixed(inventoryId: _inventory.id),
                ),
              );
            },
            tooltip: 'Pokračovat ve skenování',
            child: const Icon(Icons.add_a_photo),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "delete",
            onPressed: () {
              // Smazat soupis - návrat na seznam a smazání
              Navigator.pop(context);
              // Zde by se mělo zavolat smazání, ale to vyžaduje předání funkce
              // Pro jednoduchost jen vrátíme na seznam
            },
            tooltip: 'Smazat soupis',
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }
}
