import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soupis_vozu/models/inventory.dart';
import 'package:soupis_vozu/services/inventory_service.dart';
import 'package:soupis_vozu/services/uic_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'wagon_detail_screen.dart';

class ScanScreenFixed extends StatefulWidget {
  final String? inventoryId;

  const ScanScreenFixed({super.key, this.inventoryId});

  @override
  State<ScanScreenFixed> createState() => _ScanScreenFixedState();
}

class _ScanScreenFixedState extends State<ScanScreenFixed> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  bool _isDisposing = false; // Klíčové pro Android 16
  bool _isFlashOn = false; // Stav blesku
  int _failedScanCount = 0; // Počet neúspěšných snímků za sebou
  List<String> _detectedNumbers = [];
  int _totalWagonCount = 0; // Celkový počet vozů v soupisu
  late final TextRecognizer _textRecognizer;
  final bool _isMobilePlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  String? _currentInventoryId;
  int _nextOrderNumber = 1;
  String? _currentLocation; // Uložená lokace pro soupis
  bool _inventoryNamed = false; // Zda byl soupis již pojmenován

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.torch);
      } else {
        await _cameraController!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      debugPrint('Chyba při přepínání blesku: $e');
      setState(() {
        _isFlashOn = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentInventoryId = widget.inventoryId;

    if (_isMobilePlatform) {
      // Vylepšený TextRecognizer s vyšší citlivostí
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _initializeCamera();
      _loadNextOrderNumber();
      _loadTotalWagonCount(); // Načteme celkový počet vozů v soupisu
      _getCurrentLocation(); // Získáme lokaci hned na začátku

      // Pokud nemáme existující soupis, zobrazíme dialog pro pojmenování
      if (_currentInventoryId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNameDialog();
        });
      } else {
        _inventoryNamed = true;
      }
    }
  }

  // METODA PRO ZÍSKÁNÍ AKTUÁLNÍ LOKACE
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // Použijeme nízkou přesnost a velmi krátký timeout
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

        // Hledáme pouze město/obec, ne ulice
        if (place.locality?.isNotEmpty == true) {
          parts.add(place.locality!);
        } else if (place.subLocality?.isNotEmpty == true) {
          parts.add(place.subLocality!);
        } else if (place.subAdministrativeArea?.isNotEmpty == true) {
          parts.add(place.subAdministrativeArea!);
        }

        if (mounted) {
          setState(() {
            _currentLocation = parts.isNotEmpty ? parts.first : '';
          });
        }
      }
    } catch (e) {
      debugPrint('Poloha ignorována z důvodu chyby nebo zpoždění: $e');
    }
  }

  Future<void> _loadTotalWagonCount() async {
    if (_currentInventoryId == null) return;

    try {
      final wagons = await InventoryService.getWagonNumbersForInventory(
          _currentInventoryId!);
      if (mounted) {
        setState(() {
          _totalWagonCount = wagons.length;
        });
      }
    } catch (e) {
      print('Chyba při načítání počtu vozů: $e');
    }
  }

  Future<void> _loadNextOrderNumber() async {
    if (_currentInventoryId != null) {
      try {
        final wagonNumbers = await InventoryService.getWagonNumbersForInventory(
            _currentInventoryId!);
        if (mounted) {
          setState(() {
            _nextOrderNumber = wagonNumbers.length + 1;
          });
        }
      } catch (e) {
        debugPrint('Chyba při načítání soupisu: $e');
      }
    }
  }

  // --- ZJEDNODUŠENÝ EXIT PROTOKOL ---
  Future<void> _handleExit() async {
    if (_isDisposing) return;

    // Okamžité nastavení příznaků
    _isDisposing = true;
    _isProcessing = true;

    try {
      // 1. Zapnutá kamera
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
        await _cameraController!.pausePreview();
      }

      // 2. Zapnutý ML Kit
      if (_isMobilePlatform) {
        _textRecognizer.close();
      }

      // 3. Vypneme blesk a nastavíme příznak kamery na null
      if (_isFlashOn && _cameraController != null) {
        try {
          await _cameraController!.setFlashMode(FlashMode.off);
        } catch (e) {
          debugPrint('Chyba při vypínání blesku: $e');
        }
      }
      _cameraController = null;
    } catch (e) {
      debugPrint("Chyba při čištění: $e");
    }

    // 5. Plná navigace na hlavní stránku
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      debugPrint('Naviguji zpět na hlavní stránku');
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  void dispose() {
    // Okamžité zastavení zpracování
    _isDisposing = true;
    _isProcessing = true;

    // Zjednodušené uvolnění - žádné dispose() volání
    if (_cameraController != null) {
      // Vypneme blesk pokud je zapnutý
      if (_isFlashOn) {
        try {
          _cameraController!.setFlashMode(FlashMode.off);
        } catch (e) {
          debugPrint('Chyba při vypínání blesku v dispose: $e');
        }
      }
      _cameraController = null;
    }

    // Bezpečné uvolnění synchronních zdrojů
    if (_isMobilePlatform) {
      try {
        _textRecognizer.close();
      } catch (e) {
        debugPrint('Chyba při zavírání ML Kit: $e');
      }
    }

    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showError('Nenalezena žádná kamera');
      return;
    }

    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showError('Vyžadováno oprávnění pro kameru');
      return;
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.veryHigh, // Vyšší rozlišení pro venkovní podmínky
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Chyba inicializace kamery: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || _isProcessing || _isDisposing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      if (_isDisposing) return;

      final inputImage = InputImage.fromFilePath(image.path);

      // Vylepšené zpracování pro venkovní podmínky
      debugPrint('=== ZPRACOVÁNÍ OBRAZU ===');
      debugPrint('Cesta k obrázku: ${image.path}');
      debugPrint('Velikost souboru: ${await File(image.path).length()} bytes');

      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      debugPrint('ML Kit detekoval text: "${recognizedText.text}"');
      debugPrint('Počet bloků textu: ${recognizedText.blocks.length}');

      // Detailní logování pro ladění
      for (final block in recognizedText.blocks) {
        debugPrint('Text blok: "${block.text}"');
        for (final line in block.lines) {
          debugPrint('  Řádka: "${line.text}"');
          for (final element in line.elements) {
            debugPrint('    Prvek: "${element.text}"');
          }
        }
      }
      debugPrint('=== KONEC ZPRACOVÁNÍ ===');

      final wagonNumbers = _extractWagonNumbers(recognizedText.text);

      if (wagonNumbers.isNotEmpty) {
        // Resetovat počet neúspěšných snímků při úspěšné detekci
        _failedScanCount = 0;

        // Rozdělíme čísla na validní a nevalidní
        final validNumbers = <String>[];
        final invalidNumbers = <String>[];

        for (final number in wagonNumbers) {
          if (UicValidator.validateUicNumber(number)) {
            validNumbers.add(number);
          } else {
            invalidNumbers.add(number);
          }
        }

        // Pokud máme více validních čísel, zobrazíme dialog pro výběr
        if (validNumbers.length > 1) {
          final selectedNumber = await _showWagonSelectionDialog(validNumbers);
          if (selectedNumber == null) {
            if (mounted) setState(() => _isProcessing = false);
            return;
          }
          // Přidáme pouze vybrané číslo
          await _addSelectedWagon(selectedNumber);
        } else if (validNumbers.length == 1) {
          // Přidáme jediné validní číslo
          await _addSelectedWagon(validNumbers.first);
        } else if (invalidNumbers.isNotEmpty) {
          // Žádná validní čísla, ale máme nevalidní - zobrazíme dialog pro opravu prvého
          final firstInvalid = invalidNumbers.first;
          if (mounted && !_isDisposing) {
            _showValidationResult(UicValidator.formatUicNumber(firstInvalid),
                false, firstInvalid, _nextOrderNumber);
          }
        } else {
          // Žádná čísla vůbec
          _showMessage('Nenalezena žádná čísla vozů');
        }
      } else {
        // Žádná čísla detekována - zvýšit počet neúspěšných snímků
        _failedScanCount++;
        _showMessage('Nenalezena žádná čísla vozů');

        // Pokud máme 2 neúspěšné snímky za sebou, nabídnout ruční zadání
        if (_failedScanCount >= 2) {
          final manualNumber = await _showManualInputDialog();
          if (manualNumber != null) {
            await _addSelectedWagon(manualNumber);
          }
          _failedScanCount = 0; // Resetovat počet
        }
      }
    } catch (e) {
      if (!_isDisposing) _showError('Chyba při zpracování: $e');
    } finally {
      if (mounted && !_isDisposing) {
        setState(() => _isProcessing = false);
      }
    }
  }

  List<String> _extractWagonNumbers(String text) {
    debugPrint('Extrahuji čísla z textu: "$text"');

    // UIC číslo: XX XX XXXX XXX-X (12 číslic)
    //   Skupina 1: 2 číslice (typ/stát)
    //   Skupina 2: 2 číslice (stát/typ)
    //   Skupina 3: XXXX XXX-X (8 číslic včetně kontrolní)

    // POKUS 1: Celý UIC formát na jednom řádku – "31 54 4854 269-8"
    final singleLineUIC = RegExp(
        r'(?<![0-9])([0-9]{2})\s+([0-9]{2})\s+([0-9]{4})\s+([0-9]{3})-([0-9])(?![0-9])');

    final singleMatch = singleLineUIC.firstMatch(text);
    if (singleMatch != null) {
      final number = singleMatch.group(1)! +
          singleMatch.group(2)! +
          singleMatch.group(3)! +
          singleMatch.group(4)! +
          singleMatch.group(5)!;
      debugPrint('UIC nalezeno v jednom řádku: $number');
      return [number];
    }

    // POKUS 2: UIC formát rozdělený do více řádků
    // Třetí skupina "XXXX XXX-X" může být na jiném řádku než skupiny 1 a 2.
    // Řádky se skupinami 1 a 2 mohou obsahovat i jiný text (např. "31 TEN", "54 CZ-ČDC").
    //
    // Strategie: najdeme třetí skupinu v textu, pak vyhledáme v textu PŘED ní
    // poslední dvě samostatné 2místné číselné skupiny – ty jsou skupiny 1 a 2.
    final thirdGroupPattern =
        RegExp(r'(?<![0-9])([0-9]{4})\s+([0-9]{3})-([0-9])(?![0-9])');

    // Samostatná 2místná číslovka: obklopena ne-číslicemi (mezerou, textem, koncem řádku…)
    final twoDigitPattern = RegExp(r'(?<![0-9])([0-9]{2})(?![0-9])');

    for (final thirdMatch in thirdGroupPattern.allMatches(text)) {
      final thirdDigits = thirdMatch.group(1)! +
          thirdMatch.group(2)! +
          thirdMatch.group(3)!;

      // Všechny standalone 2místné skupiny v textu před třetí skupinou (v pořadí výskytu)
      final textBefore = text.substring(0, thirdMatch.start);
      final groups = twoDigitPattern.allMatches(textBefore).toList();

      debugPrint(
          'Třetí skupina: $thirdDigits | 2místné skupiny před ní: ${groups.map((m) => m.group(1)).toList()}');

      if (groups.length >= 2) {
        // Bereme POSLEDNÍ dvě skupiny (nejblíže k třetí skupině = skupiny 1 a 2)
        final g1 = groups[groups.length - 2].group(1)!;
        final g2 = groups[groups.length - 1].group(1)!;
        final number = g1 + g2 + thirdDigits;

        debugPrint('Sestaveno UIC: $g1 + $g2 + $thirdDigits = $number');
        if (number.length == 12) {
          return [number];
        }
      }
    }

    debugPrint('Žádné UIC číslo nenalezeno');
    return [];
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pojmenování soupisu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Zadejte název pro nový soupis vozů:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Jméno soupisu',
                hintText: 'Např. Rychlík Praha - Brno',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Potvrdit'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Vytvoříme soupis hned při pojmenování
      _currentInventoryId = await InventoryService.createInventory(result,
          location: _currentLocation);
      _inventoryNamed = true;
      setState(() {});
    }

    return result;
  }

  Future<String?> _showManualInputDialog() async {
    if (!mounted || _isDisposing) return null;

    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ruční zadání čísla vozu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Číslo vozu se nepodařilo přečíst. Zadejte ho ručně:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Číslo vozu',
                hintText: 'Např. 818012345',
                border: OutlineInputBorder(),
              ),
              maxLength: 12,
              onChanged: (value) {
                // Automatické formátování při zadávání
                if (value.length >= 8) {
                  final formatted = UicValidator.formatUicNumber(value);
                  controller.text = formatted;
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: formatted.length),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                // Zkusíme validovat zadané číslo
                if (UicValidator.validateUicNumber(input)) {
                  Navigator.of(context).pop(input);
                } else {
                  // Zobrazíme varování, ale necháme uživatele pokračovat
                  Navigator.of(context).pop(input);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF591664),
              foregroundColor: Colors.white,
            ),
            child: const Text('Přidat'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showWagonSelectionDialog(List<String> validNumbers) async {
    if (!mounted || _isDisposing) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Výběr čísla vozu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detekováno více validních čísel vozů. Zvolte, které chcete přidat:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...validNumbers.map((number) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(number),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF591664),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text(
                      UicValidator.formatUicNumber(number),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSelectedWagon(String selectedNumber) async {
    if (_currentInventoryId == null) {
      _showMessage('Nejprve pojmenujte soupis');
      return;
    }

    final wagonData = [
      {
        'number': selectedNumber,
        'formatted': UicValidator.formatUicNumber(selectedNumber),
        'isValid': true,
        'order': _nextOrderNumber,
        'notes': null,
      }
    ];

    await InventoryService.addWagonNumbersBatch(
        _currentInventoryId!, wagonData);

    if (mounted && !_isDisposing) {
      setState(() {
        _detectedNumbers.add(selectedNumber);
        _totalWagonCount++; // Aktualizujeme celkový počet
        _nextOrderNumber++;
      });
      _showMessage(
          'Přidáno číslo vozu: ${UicValidator.formatUicNumber(selectedNumber)}');
    }
  }

  void _showDetectedNumbersDialog(List<String> numbers) {
    if (!mounted || _isDisposing) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nalezeno ${numbers.length} čísel vozů'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: numbers.length,
            itemBuilder: (context, index) {
              final number = numbers[index];
              final isValid = UicValidator.validateUicNumber(number);
              final formatted = UicValidator.formatUicNumber(number);
              return ListTile(
                leading: Icon(isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red),
                title: Text(formatted),
                subtitle:
                    Text(isValid ? 'Platné UIC číslo' : 'Neplatné UIC číslo'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
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

  Future<void> _openWagonDetail(String wagonNumber) async {
    if (_currentInventoryId == null) return;

    try {
      // Fetch the full wagon data from the database
      final wagons =
          await InventoryService.getWagonNumbersForInventory(_currentInventoryId!);
      final wagonData = wagons.firstWhere(
        (w) => w.number == wagonNumber.replaceAll(RegExp(r'[^0-9]'), ''),
        orElse: () => WagonNumber(
          number: wagonNumber.replaceAll(RegExp(r'[^0-9]'), ''),
          formattedNumber: wagonNumber,
          isValid: UicValidator.validateUicNumber(wagonNumber),
          notes: '',
          order: _nextOrderNumber,
          scannedAt: DateTime.now(),
        ),
      );

      final wagonIndex = wagons.indexOf(wagonData);

      if (!mounted) return;

      // Navigate to detail screen with callback
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WagonDetailScreen(
            inventoryId: _currentInventoryId!,
            wagon: wagonData,
            wagonIndex: wagonIndex >= 0 ? wagonIndex : 0,
            onUpdate: (newNumber, newNotes, newStatus) {
              // Update the wagon in the local list if needed
              debugPrint('Wagon updated: $newNumber, notes: $newNotes');
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError('Chyba při otevírání detailů vozu: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skenování vozů'),
        backgroundColor: const Color(0xFF591664),
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isDisposing ? null : () => _handleExit(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _isDisposing ? null : _toggleFlash,
            tooltip: _isFlashOn ? 'Vypnout blesk' : 'Zapnout blesk',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Náhled kamery – plná šířka, polovina výšky obrazovky, střed oříznut
              // CameraPreview interně rotuje senzorový obraz do portrait orientace.
              // OverflowBox dá preview jeho přirozené rozměry (šířka × šířka*AR),
              // ClipRect ořízne výšku na požadovanou hodnotu – bez deformace.
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        maxWidth: MediaQuery.of(context).size.width,
                        maxHeight: MediaQuery.of(context).size.width *
                            _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Zaměřte na číslo vozu a stiskněte tlačítko',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Seznam skenovaných vozů
              Expanded(
                child: Container(
                  color: Colors.black87,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Text(
                          'Vozy v soupisu ($_totalWagonCount) — v této relaci: ${_detectedNumbers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      Expanded(
                        child: _detectedNumbers.isEmpty
                            ? const Center(
                                child: Text(
                                  'Zatím žádné vozy',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _detectedNumbers.length,
                                itemBuilder: (context, index) {
                                  final actualIndex =
                                      _detectedNumbers.length - 1 - index;
                                  final number =
                                      _detectedNumbers[actualIndex];
                                  final isValid =
                                      UicValidator.validateUicNumber(
                                          number);
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isValid
                                              ? Icons.check_circle
                                              : Icons.error,
                                          color: isValid
                                              ? Colors.green
                                              : Colors.red,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            UicValidator.formatUicNumber(
                                                number),
                                            style: TextStyle(
                                              color: isValid
                                                  ? Colors.white
                                                  : Colors.red,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Color(0xFFE3ABED),
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: () =>
                                              _openWagonDetail(number),
                                          tooltip: 'Přidat poznámky a příznaky',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tlačítko skenovat
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || _isDisposing)
                        ? null
                        : _captureAndAnalyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3ABED),
                      foregroundColor: const Color(0xFF9C27B0),
                      disabledBackgroundColor:
                          const Color(0xFFE3ABED).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFF9C27B0), strokeWidth: 2))
                        : const Icon(Icons.camera),
                    label: Text(
                      _isProcessing ? 'Zpracovávám...' : 'Skenovat',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Indikátor zavírání (přes celou obrazovku)
          if (_isDisposing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Ukončuji skenování...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showValidationResult(
      String formattedNumber, bool isValid, String originalNumber, int order) {
    if (!mounted || _isDisposing) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isValid ? Icons.check_circle : Icons.error,
                color: isValid ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(isValid ? 'Validní vůz' : 'Nevalidní vůz'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Číslo: $formattedNumber'),
            Text('Pořadí: $order'),
            if (!isValid) ...[
              const SizedBox(height: 8),
              const Text('Toto číslo není platné podle UIC formátu.'),
              const Text('Chcete ho opravit ručně?'),
            ],
          ],
        ),
        actions: [
          if (!isValid) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditDialog(originalNumber, formattedNumber, order);
              },
              child: const Text('Opravit'),
            ),
          ],
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Pokračovat')),
        ],
      ),
    );
  }

  void _showEditDialog(
      String originalNumber, String formattedNumber, int order) {
    if (!mounted || _isDisposing) return;
    final controller = TextEditingController(text: formattedNumber);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opravit číslo vozu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadejte správné číslo vozu:'),
            const SizedBox(height: 16),
            TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Číslo vozu', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušit')),
          TextButton(
            onPressed: () async {
              final newNumber = controller.text.trim();
              if (newNumber.isNotEmpty) {
                final isValid = UicValidator.validateUicNumber(newNumber);
                final newFormatted = UicValidator.formatUicNumber(newNumber);

                // Přidáme opravené číslo jako nový záznam místo aktualizace
                final wagonData = [
                  {
                    'number': newNumber,
                    'formatted': newFormatted,
                    'isValid': isValid,
                    'order': order,
                    'notes': null,
                  }
                ];

                await InventoryService.addWagonNumbersBatch(
                    _currentInventoryId!, wagonData);

                if (mounted) {
                  Navigator.of(context).pop();
                  _showEditResult(newFormatted, isValid);

                  // Přidáme opravené číslo také do seznamu detekovaných čísel pro zobrazení v UI
                  setState(() {
                    _detectedNumbers.add(newNumber);
                    _totalWagonCount++; // Aktualizujeme celkový počet
                    _nextOrderNumber++;
                  });
                }
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  void _showEditResult(String formattedNumber, bool isValid) {
    if (!mounted || _isDisposing) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isValid ? Icons.check_circle : Icons.error,
                color: isValid ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(isValid ? 'Oprava úspěšná' : 'Stále nevalidní'),
          ],
        ),
        content: Text('Číslo bylo aktualizováno na: $formattedNumber'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'))
        ],
      ),
    );
  }
}
