import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart';
import '../models/inventory.dart';
import '../services/inventory_service.dart';
import '../services/contact_service.dart';
import '../services/uic_validator.dart';
import '../models/contact.dart';
import 'wagon_detail_screen.dart';
import 'scan_screen_fixed.dart';
import '../services/theme_service.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen>
    with WidgetsBindingObserver {
  List<Inventory> _inventories = [];
  bool _isReloading = false;
  Timer? _debounceTimer; // Ochrana proti opakovanému načítání
  bool _isLoadingData = false; // Oddělený stav pro skutečné načítání
  final Map<String, bool> _expandedState = {}; // Pamatování rozbalených ExpansionTile

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInventories();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel(); // Uklidíme timer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Debounce mechanismus pro zabránění opakovanému načítání
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadInventories();
        }
      });
    }
  }

  Future<void> _loadInventories() async {
    // Ochrana proti opakovanému načítání
    if (_isReloading) return;

    _isReloading = true;
    setState(() => _isLoadingData = true);

    try {
      final inventories = await InventoryService.getAllInventories();
      inventories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _inventories = inventories;
        _isLoadingData = false;
        _isReloading = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
        _isReloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při načítání soupisů: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyTableToClipboard(Inventory inventory) async {
    try {
      final table = await _createInventoryTableWithLocation(inventory);
      await Clipboard.setData(ClipboardData(text: table));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tabulka zkopírována do schránky'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při kopírování: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _getLocationName() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return '';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return '';
      }
      if (permission == LocationPermission.deniedForever) return '';

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> parts = [];
        if (place.locality?.isNotEmpty == true) {
          parts.add(place.locality!);
        } else if (place.subLocality?.isNotEmpty == true) {
          parts.add(place.subLocality!);
        } else if (place.subAdministrativeArea?.isNotEmpty == true) {
          parts.add(place.subAdministrativeArea!);
        }
        return parts.isNotEmpty ? parts.first : '';
      }
    } catch (e) {
      debugPrint('Poloha ignorována z důvodu chyby nebo zpoždění: $e');
      return '';
    }
    return '';
  }

  Future<String> _createInventoryTableWithLocation(Inventory inventory) async {
    final buffer = StringBuffer();
    for (int i = 0; i < inventory.wagonNumbers.length; i++) {
      final wagon = inventory.wagonNumbers[i];
      final order = (i + 1).toString().padLeft(3, ' ') + '.';
      final number = wagon.formattedNumber.padRight(15, ' ');
      // V tabulce zobrazit kompletní notes (příznak + poznámka)
      final notes = wagon.notes != null && wagon.notes!.isNotEmpty
          ? '[${wagon.notes!}]'
          : '';
      buffer.writeln('$order  $number  $notes');
    }

    buffer.writeln();
    buffer.writeln('Celkem vozů: ${inventory.wagonNumbers.length}');

    String locationText = '';
    if (inventory.location?.isNotEmpty == true) {
      locationText = ", ${inventory.location}";
    } else {
      final locationName = await _getLocationName();
      locationText = locationName.isNotEmpty ? ", $locationName" : '';
    }

    // Najdeme čas posledního naskenovaného vozu
    DateTime lastScanTime;
    if (inventory.wagonNumbers.isNotEmpty) {
      lastScanTime = inventory.wagonNumbers
          .map((wagon) => wagon.scannedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    } else {
      lastScanTime = inventory.lastModified; // Fallback na čas poslední změny
    }

    buffer.writeln(
        'Sepsáno: ${DateFormat('dd/MM, HH:mm').format(lastScanTime)}$locationText');
    buffer.writeln();

    return buffer.toString();
  }

  Future<String?> _showEditWagonDialog(WagonNumber wagon) async {
    final controller = TextEditingController(text: wagon.formattedNumber);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Úprava čísla vozu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadejte správné číslo vozu:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Číslo vozu',
                border: OutlineInputBorder(),
                hintText: 'XX XX XXXX XXX-X',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction((oldValue, newValue) {
                  String text = newValue.text;
                  String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length > 12) digits = digits.substring(0, 12);
                  String formatted = '';
                  if (digits.isNotEmpty) {
                    formatted = digits;
                    if (digits.length >= 2) {
                      formatted = digits.substring(0, 2);
                      if (digits.length >= 4) {
                        formatted += ' ${digits.substring(2, 4)}';
                        if (digits.length >= 8) {
                          formatted += ' ${digits.substring(4, 8)}';
                          if (digits.length >= 11) {
                            formatted += ' ${digits.substring(8, 11)}';
                            if (digits.length >= 12)
                              formatted += '-${digits.substring(11, 12)}';
                          } else {
                            formatted += digits.substring(8);
                          }
                        } else {
                          formatted += digits.substring(4);
                        }
                      } else {
                        formatted += digits.substring(2);
                      }
                    }
                  }
                  return TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit')),
          TextButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Zadejte číslo vozu'),
                    backgroundColor: Colors.red));
              } else {
                String digits =
                    controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length != 12 ||
                    !UicValidator.validateUicNumber(digits)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Číslo není platné UIC číslo'),
                      backgroundColor: Colors.red));
                } else {
                  Navigator.pop(context, controller.text);
                }
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTableDialog(Inventory inventory) async {
    final table = await _createInventoryTableWithLocation(inventory);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tabulka soupisu'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(table,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zavřít')),
          TextButton(
              onPressed: () => _copyTableToClipboard(inventory),
              child: const Text('Zkopírovat')),
        ],
      ),
    );
  }

  Future<void> _exportInventoryToEmail(Inventory inventory) async {
    // Použijeme jméno soupisu z databáze, bez dalšího dialogu
    final customName = inventory.name;

    try {
      final table = await _createInventoryTableWithLocation(inventory);
      final contacts = await ContactService.getAllContacts();
      // Do recipients dáváme POUZE kontakty, které nejsou označeny jako příjemci v Kopii
      final recipients = contacts
          .where((contact) => !contact.isCopyRecipient)
          .map((contact) => contact.email.trim())
          .toList();

      if (recipients.isEmpty &&
          !contacts.any((contact) => contact.isCopyRecipient)) {
        _showNoContactsDialog();
        return;
      }

      await _showRecipientDialog(recipients, customName, table, contacts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chyba při exportu: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showNoContactsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Žádné kontakty'),
        content: const Text(
            'V adresáři nemáte žádné kontakty. Nejprve přidejte kontakty v nastavení.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecipientDialog(List<String> recipients, String customName,
      String table, List<Contact> contacts) async {
    // Při otevření dialogu žádný kontakt není předem vybrán
    final selectedRecipients = <String>[];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Vyberte adresáty pro odeslání:'),
                const SizedBox(height: 16),
                if (contacts.isNotEmpty) ...[
                  const Text('Adresář:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...contacts
                      .map((contact) {
                        final cleanEmail = contact.email.trim();
                        final isNormalRecipient =
                            selectedRecipients.contains(cleanEmail);

                        // Kontakty označené jako příjemci v Kopii se nezobrazují jako normální příjemci
                        if (contact.isCopyRecipient) {
                          return const SizedBox.shrink();
                        }

                        return CheckboxListTile(
                          title: Text(contact.name),
                          subtitle: Text(cleanEmail),
                          value: isNormalRecipient,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true)
                                selectedRecipients.add(cleanEmail);
                              else
                                selectedRecipients.remove(cleanEmail);
                            });
                          },
                          activeColor: const Color(0xFFF0A500),
                        );
                      })
                      .where((widget) => widget is! SizedBox)
                      .toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (selectedRecipients.isNotEmpty) {
                  // Automaticky přidat kontakty označené jako "příjemci v Kopie"
                  final copyRecipients = contacts
                      .where((contact) => contact.isCopyRecipient)
                      .map((contact) => contact.email.trim())
                      .toList();

                  // Očištění adres od mezer
                  final to = selectedRecipients.join(',').replaceAll(' ', '');
                  final cc = copyRecipients.join(',').replaceAll(' ', '');
                  final subject = 'Soupis vlaku - "$customName"';
                  final body =
                      'Dobrý den,\n\nzasílám soupis vozů:\n\n$table\n\nS pozdravem';

                  // Vytvoříme přímý kanál do Kotlinu na STRANĚ FLUTTERU
                  const platform =
                      MethodChannel('com.example.soupis_vozu/email');

                  try {
                    // Posíláme data do Androidu
                    await platform.invokeMethod('sendEmail', {
                      'to': to,
                      'cc': cc, // Přidána podpora pro Kopie
                      'subject': subject,
                      'body': body,
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('E-mailový klient otevřen.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } on MissingPluginException catch (_) {
                    // Tato výjimka nastane, pokud není kód v MainActivity.kt aplikován
                    debugPrint(
                        'Kotlin kanál nenalezen - ujistěte se, že MainActivity.kt je aktuální a byl proveden čistý build.');
                    await _handleFallback(to, subject, table, cc: cc);
                  } catch (e) {
                    debugPrint('Nativní e-mail selhal jinou chybou: $e');
                    await _handleFallback(to, subject, table, cc: cc);
                  }
                }
              },
              child: const Text('Odeslat e-mail'),
            ),
          ],
        ),
      ),
    );
  }

  // Fallback metoda zapouzdřená do bezpečné funkce proti pádu
  Future<void> _handleFallback(String to, String subject, String table,
      {String? cc}) async {
    // Krátká pauza zajistí, že se hlavní vlákno nezablokuje po vyhozené chybě
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      try {
        final recipientsText = cc != null && cc.isNotEmpty
            ? 'Příjemci: $to\nKopie: $cc\n\n$subject\n\n$table'
            : 'Příjemci: $to\n\n$subject\n\n$table';

        await Share.share(
          recipientsText,
          subject: subject,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Odeslání přes e-mail selhalo, nabídnuto sdílení textu.'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        debugPrint('Fallback sdílení selhalo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-mail i sdílení selhalo. Zkuste to znovu.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteInventory(String inventoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat soupis'),
        content: const Text(
            'Opravdu chcete smazat tento soupis? Tuto akci nelze vrátit zpět.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušit')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Smazat')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await InventoryService.deleteInventory(inventoryId);
        _loadInventories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Chyba při mazání: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  String _formatDate(DateTime date) =>
      DateFormat('dd.MM.yyyy HH:mm').format(date);

  String _getInventorySummary(Inventory inventory) {
    final validCount = inventory.wagonNumbers.where((w) => w.isValid).length;
    final totalCount = inventory.wagonNumbers.length;
    return 'Platných: $validCount/$totalCount';
  }

  Future<void> _editInventoryName(
      String inventoryId, String currentName) async {
    if (!mounted) return;

    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upravit název soupisu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadejte nový název pro soupis:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Název soupisu',
                hintText: 'Např: Rychlík Praha - Brno',
                border: OutlineInputBorder(),
              ),
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
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                Navigator.pop(context, newName);
              } else if (newName.isNotEmpty) {
                Navigator.pop(context, null); // Žádná změna
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await InventoryService.updateInventoryName(inventoryId, result);

        if (mounted) {
          // Aktualizujeme pouze tento soupis bez překreslení celého seznamu
          setState(() {
            final index =
                _inventories.indexWhere((inv) => inv.id == inventoryId);
            if (index != -1) {
              final currentInventory = _inventories[index];
              final updatedInventory = Inventory(
                id: currentInventory.id,
                name: result, // Nový název
                createdAt: currentInventory.createdAt,
                lastModified: DateTime.now(),
                wagonNumbers: currentInventory.wagonNumbers,
                notes: currentInventory.notes,
                location: currentInventory.location,
              );
              _inventories[index] = updatedInventory;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Název soupisu byl úspěšně změněn'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba při změně názvu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateSingleInventory(String inventoryId) async {
    // Aktualizuje pouze jeden soupis bez překreslení celého seznamu
    try {
      final updatedWagons =
          await InventoryService.getWagonNumbersForInventory(inventoryId);
      if (mounted) {
        setState(() {
          // Najdeme index a aktualizujeme pouze vozy v tomto soupisu
          final index = _inventories.indexWhere((inv) => inv.id == inventoryId);
          if (index != -1) {
            // Vytvoříme novou instanci soupisu s aktualizovanými vozy
            final currentInventory = _inventories[index];
            final updatedInventory = Inventory(
              id: currentInventory.id,
              name: currentInventory.name,
              createdAt: currentInventory.createdAt,
              lastModified: DateTime.now(), // Aktualizujeme čas změny
              wagonNumbers: updatedWagons,
              notes: currentInventory.notes,
              location: currentInventory.location,
            );
            _inventories[index] = updatedInventory;
          }
        });
      }
    } catch (e) {
      debugPrint('Chyba při aktualizaci soupisu: $e');
    }
  }

  Future<void> _reorderWagons(
      String inventoryId, int oldIndex, int newIndex) async {
    if (!mounted) return;

    try {
      // Získání všech vozů ze soupisu
      final wagons =
          await InventoryService.getWagonNumbersForInventory(inventoryId);

      if (wagons.isEmpty) return;

      // Seřazení vozů podle aktuálního pořadí
      wagons.sort((a, b) => a.order.compareTo(b.order));

      // Přesun vozu v seznamu
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final wagon = wagons.removeAt(oldIndex);
      wagons.insert(newIndex, wagon);

      // Aktualizace pořadí v databázi
      for (int i = 0; i < wagons.length; i++) {
        final currentWagon = wagons[i];
        await InventoryService.updateWagonNumber(
          inventoryId,
          currentWagon.number,
          currentWagon.formattedNumber,
          currentWagon.notes ?? '',
          currentWagon.isValid,
          newOrderNumber: i + 1,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pořadí vozů bylo úspěšně změněno'),
            backgroundColor: Colors.green,
          ),
        );
        // Aktualizujeme pouze tento soupis bez překreslení celého seznamu
        _updateSingleInventory(inventoryId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při změně pořadí: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rotateWagonOrder(String inventoryId) async {
    // Kontrola, zda je karta otevřená, aby se nezavřela samovolně
    if (!mounted) return;

    try {
      // Získání všech vozů ze soupisu
      final wagons =
          await InventoryService.getWagonNumbersForInventory(inventoryId);

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

      // Otočení pořadí - prohodit celý seznam
      for (int i = 0; i < wagons.length; i++) {
        final wagon = wagons[i];
        // Vypočítat nové pořadové číslo - otočení celého seznamu
        int newOrder =
            wagons.length - i; // první bude poslední, druhý předposlední, atd.

        await InventoryService.updateWagonNumber(
          inventoryId,
          wagon.number,
          wagon.formattedNumber,
          wagon.notes ?? '',
          wagon.isValid,
          newOrderNumber: newOrder,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pořadí vozů bylo úspěšně otočeno'),
            backgroundColor: Colors.green,
          ),
        );
        // Aktualizujeme pouze tento soupis bez překreslení celého seznamu
        _updateSingleInventory(inventoryId);
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

  // Utility: Vrátí barvu pozadí na základě příznaku vozu
  Color? _getFlagBackgroundColor(String? notes) {
    if (notes == null || notes.isEmpty) return null;

    // Extrahujeme primární příznak (např. "K + R1 - poznámky" → "K")
    // Rozdělíme podle ' - ' a vezmeme část s příznaky
    final parts = notes.split(' - ');
    final flagsPart = parts[0].trim(); // "K" nebo "K + M" apod.

    // Hledáme první příznak v kombinaci
    final flagList = flagsPart.split(' + ');
    for (final flag in flagList) {
      final trimmedFlag = flag.trim();
      switch (trimmedFlag) {
        case 'K':
          return const Color(0xFFbde0fc); // Přesná modrá
        case 'M':
          return const Color(0xFFfcf5bd); // Přesná žlutá
        case '314':
          return const Color(0xFFbdfcf2); // Přesná tyrkysová
      }
    }
    return null;
  }

  // Utility: Extrahuje jen poznámky bez příznaku
  String _extractNotesOnly(String notes) {
    if (notes.isEmpty) return '';

    // Pokud notes obsahuje " - ", oddělíme příznak(y) a poznámky
    if (notes.contains(' - ')) {
      final parts = notes.split(' - ');
      return parts.length > 1 ? parts.sublist(1).join(' - ') : '';
    }

    // Pokud notes obsahuje jen příznak(y) bez poznámky (např. "K" nebo "K + M")
    // vrať prázdný string
    final knownFlags = ['K', 'M', '314', 'R1'];
    final trimmed = notes.trim();
    if (knownFlags.contains(trimmed)) return '';

    // Kontroluj kombinace příznaků (např. "K + M")
    final parts = trimmed.split(' + ');
    bool isOnlyFlags = true;
    for (final part in parts) {
      if (!knownFlags.contains(part.trim())) {
        isOnlyFlags = false;
        break;
      }
    }

    return isOnlyFlags ? '' : notes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOUPISY VOZŮ'),
        actions: [
          IconButton(
              onPressed: _loadInventories,
              icon: const Icon(Icons.refresh),
              tooltip: 'Obnovit'),
        ],
      ),
      body: Column(children: [
        ThemeService.amberStripe,
        Expanded(child: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _inventories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Zatím žádné soupisy',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _inventories.length,
                  itemBuilder: (context, index) {
                    final inventory = _inventories[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        initiallyExpanded: _expandedState[inventory.id] ?? false,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expandedState[inventory.id] = expanded;
                          });
                        },
                        tilePadding: const EdgeInsets.only(
                            left: 16, right: 8, top: 8, bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
                        title: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          inventory.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: () => _editInventoryName(
                                            inventory.id, inventory.name),
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 16, color: Color(0xFF4A90B8)),
                                        tooltip: 'Upravit název soupisu',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_getInventorySummary(inventory)),
                                  const SizedBox(height: 4),
                                  Text(_formatDate(inventory.lastModified)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                ScanScreenFixed(
                                                    inventoryId:
                                                        inventory.id)));
                                  },
                                  icon: const Icon(Icons.add_a_photo,
                                      color: Colors.green),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _deleteInventory(inventory.id),
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                        leading:
                            const CircleAvatar(child: Icon(Icons.list_alt)),
                        trailing: const SizedBox.shrink(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Seznam čísel vozů (${inventory.wagonNumbers.length}):',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                // Tlačítko pro otočení pořadí vozů
                                if (inventory.wagonNumbers.isNotEmpty)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _rotateWagonOrder(inventory.id),
                                      icon: const Icon(Icons.rotate_right,
                                          size: 16),
                                      label: const Text('Otočit pořadí vozů'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF4A90B8),
                                        side: const BorderSide(
                                            color: Color(0xFF4A90B8)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                // Seznam vozů s možností přesouvání
                                if (inventory.wagonNumbers.isNotEmpty)
                                  Container(
                                    height:
                                        300, // Omezená výška pro lepší přehlednost
                                    child: ReorderableListView.builder(
                                      itemCount: inventory.wagonNumbers.length,
                                      onReorder: (oldIndex, newIndex) {
                                        _reorderWagons(
                                            inventory.id, oldIndex, newIndex);
                                      },
                                      itemBuilder: (context, index) {
                                        final wagon =
                                            inventory.wagonNumbers[index];
                                        return Card(
                                          key: ValueKey(wagon.number),
                                          margin:
                                              const EdgeInsets.only(bottom: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          color: _getFlagBackgroundColor(wagon.notes),
                                          child: InkWell(
                                            onTap: () async {
                                              if (!wagon.isValid) {
                                                final editedNumber =
                                                    await _showEditWagonDialog(
                                                        wagon);
                                                if (editedNumber != null) {
                                                  await InventoryService
                                                      .updateWagonNumber(
                                                          inventory.id,
                                                          wagon.number,
                                                          editedNumber,
                                                          wagon.notes ?? '',
                                                          true);
                                                  _loadInventories();
                                                }
                                              } else {
                                                await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            WagonDetailScreen(
                                                                inventoryId:
                                                                    inventory
                                                                        .id,
                                                                wagon: wagon,
                                                                wagonIndex:
                                                                    wagon.order -
                                                                        1,
                                                                onUpdate: (f, n,
                                                                        s) =>
                                                                    _loadInventories())));
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              child: Row(
                                                children: [
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                            color: Colors
                                                                .grey[300]!),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.drag_handle,
                                                            size: 18,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            '${index + 1}.',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      wagon.formattedNumber,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: wagon.isValid
                                                            ? Colors.green
                                                            : Colors.red,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  if (wagon.notes != null &&
                                                      wagon.notes!.isNotEmpty &&
                                                      _extractNotesOnly(
                                                              wagon.notes!) !=
                                                          '') ...[
                                                    const SizedBox(width: 6),
                                                    Icon(
                                                      Icons.info,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                  ],
                                                  Icon(
                                                    wagon.isValid
                                                        ? Icons.check_circle
                                                        : Icons.error,
                                                    color: wagon.isValid
                                                        ? Colors.green
                                                        : Colors.red,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _showTableDialog(inventory),
                                        icon: const Icon(Icons.table_chart_outlined),
                                        label: const Text('ZOBRAZIT TABULKU'))),
                                const SizedBox(height: 8),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _copyTableToClipboard(inventory),
                                        icon: const Icon(Icons.copy_outlined),
                                        label: const Text('ZKOPÍROVAT TABULKU'))),
                                const SizedBox(height: 8),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _exportInventoryToEmail(inventory),
                                        icon: const Icon(Icons.email_outlined),
                                        label: const Text('EXPORTOVAT DO E-MAILU'))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/scan'),
        tooltip: 'Nový soupis',
        child: const Icon(Icons.add),
      ),
    );
  }
}
