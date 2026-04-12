import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory.dart';
import '../services/theme_service.dart';
import 'scan_screen_fixed.dart';

class InventoryDetailScreen extends StatefulWidget {
  final Inventory inventory;

  const InventoryDetailScreen({super.key, required this.inventory});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late Inventory _inventory;

  @override
  void initState() {
    super.initState();
    _inventory = widget.inventory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_inventory.name.toUpperCase()),
      ),
      body: Column(
        children: [
          ThemeService.amberStripe,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info karta
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INFORMACE O SOUPISU',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text('Jméno: ${_inventory.name}'),
                          const SizedBox(height: 6),
                          Text(
                            'Vytvořeno: ${DateFormat.yMd().add_Hm().format(_inventory.createdAt)}',
                          ),
                          const SizedBox(height: 6),
                          Text('Počet vozů: ${_inventory.wagonNumbers.length}'),
                          if (_inventory.notes != null &&
                              _inventory.notes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Poznámky:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(_inventory.notes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Seznam vozů
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SEZNAM VOZŮ (${_inventory.wagonNumbers.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _inventory.wagonNumbers.length,
                                itemBuilder: (context, index) {
                                  final wagon =
                                      _inventory.wagonNumbers[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    child: ListTile(
                                      leading: Icon(
                                        wagon.isValid
                                            ? Icons.check_circle_outline
                                            : Icons.error_outline,
                                        color: wagon.isValid
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      title: Text(
                                        wagon.formattedNumber,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      subtitle: Text(
                                        wagon.isValid
                                            ? 'Platné UIC číslo'
                                            : 'Neplatné UIC číslo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: wagon.isValid
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      trailing: Text(
                                        wagon.notes ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'continue',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScanScreenFixed(inventoryId: _inventory.id),
              ),
            ),
            tooltip: 'Pokračovat ve skenování',
            child: const Icon(Icons.add_a_photo_outlined),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'delete',
            onPressed: () => Navigator.pop(context),
            tooltip: 'Zpět na seznam',
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
