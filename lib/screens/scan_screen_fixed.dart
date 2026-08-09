import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/theme_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soupis_vozu/models/inventory.dart';
import 'package:soupis_vozu/models/wagon_registry_entry.dart';
import 'package:soupis_vozu/services/inventory_service.dart';
import 'package:soupis_vozu/services/uic_validator.dart';
import 'package:soupis_vozu/services/scan_settings_service.dart';
import 'package:soupis_vozu/services/ai_ocr_service.dart';
import 'package:soupis_vozu/services/wagon_registry_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'wagon_detail_screen.dart';

class ScanScreenFixed extends StatefulWidget {
  final String? inventoryId;
  final List<String>? initialWagonNumbers;

  const ScanScreenFixed({super.key, this.inventoryId, this.initialWagonNumbers});

  @override
  State<ScanScreenFixed> createState() => _ScanScreenFixedState();
}

class _UicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 12 ? digits.substring(0, 12) : digits;

    // Formát: XX XX XXXX XXX-X
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4 || i == 8) buffer.write(' ');
      if (i == 11) buffer.write('-');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ScanScreenFixedState extends State<ScanScreenFixed> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  bool _isDisposing = false; // Klíčové pro Android 16
  bool _isFlashOn = false; // Stav blesku
  int _failedScanCount = 0; // Počet neúspěšných snímků za sebou
  final List<String> _detectedNumbers = [];
  int _totalWagonCount = 0; // Celkový počet vozů v soupisu
  // Zda má daný vůz (klíč = číslo bez formátování) v databázi vyplněné
  // všechny sledované technické údaje – řídí malou ikonku u čísla v seznamu.
  final Map<String, bool> _wagonComplete = {};
  late final TextRecognizer _textRecognizer;
  final bool _isMobilePlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  String? _currentInventoryId;
  int _nextOrderNumber = 1;
  String? _currentLocation;
  String? _statusMessage;
  Color _statusColor = Colors.green;
  Timer? _statusTimer;

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

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

    if (widget.initialWagonNumbers != null) {
      _detectedNumbers.addAll(widget.initialWagonNumbers!);
    }

    if (_isMobilePlatform) {
      // Vylepšený TextRecognizer s vyšší citlivostí
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _initializeCamera();
      _loadWagonStats();
      _getCurrentLocation();

      if (_currentInventoryId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNameDialog();
        });
      }
    }
  }

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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
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

  Future<void> _loadWagonStats() async {
    if (_currentInventoryId == null) return;
    try {
      final wagons = await InventoryService.getWagonNumbersForInventory(
          _currentInventoryId!);
      if (mounted) {
        setState(() {
          _totalWagonCount = wagons.length;
          _nextOrderNumber = wagons.length + 1;
          for (final wagon in wagons) {
            _wagonComplete[wagon.number] = wagon.hasCompleteInfo;
          }
        });
      }
    } catch (e) {
      debugPrint('Chyba při načítání soupisu: $e');
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
    _statusTimer?.cancel();

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

      final scanMode = await ScanSettingsService.getScanMode();
      final wagonNumbers = scanMode == ScanMode.quality
          ? await _extractViaAi(image.path)
          : await _extractViaMlKit(image.path);

      await _processWagonNumbers(wagonNumbers);
    } catch (e) {
      if (!_isDisposing) _showError('Chyba při zpracování: $e');
    } finally {
      if (mounted && !_isDisposing) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<List<String>> _extractViaMlKit(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    debugPrint('=== ML KIT ZPRACOVÁNÍ ===');
    debugPrint('Cesta: $imagePath');
    debugPrint('Velikost: ${await File(imagePath).length()} bytes');

    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    debugPrint('Detekovaný text: "${recognizedText.text}"');
    debugPrint('Bloků: ${recognizedText.blocks.length}');
    for (final block in recognizedText.blocks) {
      debugPrint('Blok: "${block.text}"');
      for (final line in block.lines) {
        debugPrint('  Řádka: "${line.text}"');
        for (final element in line.elements) {
          debugPrint('    Prvek: "${element.text}"');
        }
      }
    }
    debugPrint('=== KONEC ===');

    return _extractWagonNumbers(recognizedText.text);
  }

  Future<List<String>> _extractViaAi(String imagePath) async {
    final provider = await ScanSettingsService.getAiProvider();
    final apiKey = await ScanSettingsService.getApiKey();

    if (provider == null || apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'Nakonfigurujte AI skenování v Nastavení → Skenování');
    }

    return AiOcrService.extractWagonNumbers(imagePath, provider, apiKey);
  }

  Future<void> _processWagonNumbers(List<String> wagonNumbers) async {
    if (wagonNumbers.isNotEmpty) {
      _failedScanCount = 0;

      final validNumbers = <String>[];
      final invalidNumbers = <String>[];
      for (final number in wagonNumbers) {
        if (UicValidator.validateUicNumber(number)) {
          validNumbers.add(number);
        } else {
          invalidNumbers.add(number);
        }
      }

      if (validNumbers.length > 1) {
        final selectedNumber = await _showWagonSelectionDialog(validNumbers);
        if (selectedNumber == null) {
          if (mounted) setState(() => _isProcessing = false);
          return;
        }
        await _addSelectedWagon(selectedNumber);
      } else if (validNumbers.length == 1) {
        await _addSelectedWagon(validNumbers.first);
      } else if (invalidNumbers.isNotEmpty) {
        final firstInvalid = invalidNumbers.first;
        if (mounted && !_isDisposing) {
          _showValidationResult(UicValidator.formatUicNumber(firstInvalid),
              false, firstInvalid, _nextOrderNumber);
        }
      } else {
        _showOverlay('Nenalezena žádná čísla vozů', ThemeService.kRailAmber);
      }
    } else {
      _failedScanCount++;
      _showOverlay('Nenalezena žádná čísla vozů', ThemeService.kRailAmber);

      if (_failedScanCount >= 2) {
        _failedScanCount = 0;
        await _attemptShortNumberScan();
      }
    }
  }

  /// Třetí pokus o naskenování – po dvou neúspěšných pokusech o přečtení
  /// celého 12místného čísla zkusí ML Kit rozpoznat už jen konec čísla
  /// (poslední trojčíslí a kontrolní číslici, formát "XXX-X") a najde
  /// odpovídající vůz v databázi. Podle počtu shod:
  ///  - 1 shoda   → dotaz na potvrzení konkrétního čísla,
  ///  - 2+ shody  → výběr ze seznamu nalezených čísel (s možností žádné),
  ///  - 0 shod, nebo se konec čísla nepodaří přečíst → rovnou ruční zadání.
  Future<void> _attemptShortNumberScan() async {
    if (_cameraController == null || _isDisposing || !_isMobilePlatform) {
      await _fallbackToManualInput();
      return;
    }

    _showOverlay(
        'Zkouším rozpoznat poslední čtyři znaky čísla…', ThemeService.kRailAmber);

    try {
      final image = await _cameraController!.takePicture();
      if (_isDisposing) return;

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final candidates = _extractShortWagonNumbers(recognizedText.text);

      if (candidates.isEmpty) {
        await _fallbackToManualInput();
        return;
      }

      final matches = await WagonRegistryService.findBySuffix(candidates.first);

      if (matches.isEmpty) {
        await _fallbackToManualInput();
        return;
      }

      String? selectedNumber;
      if (matches.length == 1) {
        final confirmed =
            await _showShortMatchConfirmDialog(matches.first.formattedNumber);
        selectedNumber = confirmed == true ? matches.first.number : null;
      } else {
        selectedNumber = await _showShortMatchSelectionDialog(matches);
      }

      if (selectedNumber != null) {
        await _addSelectedWagon(selectedNumber);
      } else {
        await _fallbackToManualInput();
      }
    } catch (e) {
      debugPrint('Chyba při krátkém pokusu o skenování: $e');
      await _fallbackToManualInput();
    }
  }

  Future<void> _fallbackToManualInput() async {
    final manualNumber = await _showManualInputDialog();
    if (manualNumber != null) {
      await _addSelectedWagon(manualNumber);
    }
  }

  /// Rozpozná jen konec UIC čísla – poslední trojčíslí a kontrolní číslici,
  /// formát "XXX-X". Používá se ve třetím pokusu o skenování, kdy je
  /// fotografie zaměřená jen na konec čísla vozu.
  List<String> _extractShortWagonNumbers(String text) {
    debugPrint('Extrahuji konec čísla z textu: "$text"');

    const kc = r'[\-–— ]';
    final pattern = RegExp(r'(?<![0-9])([0-9]{3})' + kc + r'([0-9])(?![0-9])');

    final results = <String>[];
    for (final match in pattern.allMatches(text)) {
      final candidate = match.group(1)! + match.group(2)!;
      if (!results.contains(candidate)) results.add(candidate);
    }

    debugPrint('Nalezené konce čísel: $results');
    return results;
  }

  List<String> _extractWagonNumbers(String text) {
    debugPrint('Extrahuji čísla z textu: "$text"');

    // UIC číslo: 12 číslic, formát XX XX XXXX XXX-X
    // KČ = kontrolní číslice (poslední), předchází jí pomlčka nebo mezera.

    // Pomlčka před KČ – rozpoznáváme i unicode varianty a prosté mezery.
    const kc = r'[\-–— ]';

    // POKUS 1: Standardní formát jedním řádkem – "31 54 4854 269-8"
    // Povoleny unicode pomlčky i mezera před KČ.
    final p1 = RegExp(
        r'(?<![0-9])([0-9]{2})\s+([0-9]{2})\s+([0-9]{4})\s+([0-9]{3})' +
            kc +
            r'([0-9])(?![0-9])');
    final m1 = p1.firstMatch(text);
    if (m1 != null) {
      final num = m1.group(1)! + m1.group(2)! + m1.group(3)! + m1.group(4)! + m1.group(5)!;
      debugPrint('UIC P1: $num');
      return [num];
    }

    // POKUS 2: OCR rozdělil 4-místnou skupinu na dvě 2-místné – "31 54 48 54 269-8"
    final p2 = RegExp(
        r'(?<![0-9])([0-9]{2})\s+([0-9]{2})\s+([0-9]{2})\s+([0-9]{2})\s+([0-9]{3})' +
            kc +
            r'([0-9])(?![0-9])');
    final m2 = p2.firstMatch(text);
    if (m2 != null) {
      final num = m2.group(1)! + m2.group(2)! + m2.group(3)! + m2.group(4)! + m2.group(5)! + m2.group(6)!;
      debugPrint('UIC P2 (split XXXX): $num');
      return [num];
    }

    // POKUS 3: Stripping řádků – odstraníme vše kromě číslic a hledáme přesně 12.
    // Zachytí jakékoli oddělovače: tečky, lomítka, žádný oddělovač, pomlčku jako mezeru…
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final digits = line.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 12) {
        debugPrint('UIC P3 (strip line): $digits  ←  "$line"');
        return [digits];
      }
    }

    // POKUS 4: Flexibilní oddělovače v bloku textu (max 3 ne-číslice na hranici, bez \n).
    // XXXX varianta i split-XXXX varianta.
    final p4a = RegExp(
        r'(?<![0-9])([0-9]{2})[^0-9\n]{0,3}([0-9]{2})[^0-9\n]{0,3}([0-9]{4})[^0-9\n]{0,3}([0-9]{3})[^0-9\n]{0,2}([0-9])(?![0-9])');
    final m4a = p4a.firstMatch(text);
    if (m4a != null) {
      final num = m4a.group(1)! + m4a.group(2)! + m4a.group(3)! + m4a.group(4)! + m4a.group(5)!;
      debugPrint('UIC P4a (flex XXXX): $num');
      return [num];
    }

    final p4b = RegExp(
        r'(?<![0-9])([0-9]{2})[^0-9\n]{0,3}([0-9]{2})[^0-9\n]{0,3}([0-9]{2})[^0-9\n]{0,3}([0-9]{2})[^0-9\n]{0,3}([0-9]{3})[^0-9\n]{0,2}([0-9])(?![0-9])');
    final m4b = p4b.firstMatch(text);
    if (m4b != null) {
      final num = m4b.group(1)! + m4b.group(2)! + m4b.group(3)! + m4b.group(4)! + m4b.group(5)! + m4b.group(6)!;
      debugPrint('UIC P4b (flex split): $num');
      return [num];
    }

    // POKUS 5: Multi-line – třetí skupina "XXXX XXX-X" na jiném řádku.
    // Povoleny unicode pomlčky i mezera před KČ.
    final thirdGroupPattern =
        RegExp(r'(?<![0-9])([0-9]{4})\s+([0-9]{3})' + kc + r'([0-9])(?![0-9])');
    final twoDigitPattern = RegExp(r'(?<![0-9])([0-9]{2})(?![0-9])');

    for (final thirdMatch in thirdGroupPattern.allMatches(text)) {
      final thirdDigits =
          thirdMatch.group(1)! + thirdMatch.group(2)! + thirdMatch.group(3)!;
      final textBefore = text.substring(0, thirdMatch.start);
      final groups = twoDigitPattern.allMatches(textBefore).toList();

      debugPrint(
          'P5 třetí skupina: $thirdDigits | 2místné skupiny: ${groups.map((m) => m.group(1)).toList()}');

      if (groups.length >= 2) {
        final g1 = groups[groups.length - 2].group(1)!;
        final g2 = groups[groups.length - 1].group(1)!;
        final number = g1 + g2 + thirdDigits;
        if (number.length == 12) {
          debugPrint('UIC P5 (multi-line): $number');
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
      setState(() {});
    }

    return result;
  }

  Future<String?> _showManualInputDialog() async {
    if (!mounted || _isDisposing) return null;

    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
          final digitCount = digits.length;
          final isComplete = digitCount == 12;
          final isValid = isComplete && UicValidator.validateUicNumber(digits);

          final Color borderColor;
          if (isComplete) {
            borderColor = isValid ? Colors.green : Colors.red;
          } else {
            borderColor = Colors.grey;
          }

          return AlertDialog(
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
                  inputFormatters: [_UicInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Číslo vozu',
                    hintText: 'XX XX XXXX XXX-X',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isComplete
                            ? borderColor
                            : Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    counterText: '$digitCount / 12',
                    counterStyle: TextStyle(
                      color: isComplete
                          ? (isValid ? Colors.green : Colors.red)
                          : null,
                    ),
                  ),
                  onChanged: (value) => setDialogState(() {}),
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
                    Navigator.of(context).pop(input);
                  }
                },
                child: const Text('PŘIDAT'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Potvrzovací dotaz po třetím, "krátkém" pokusu o skenování – v databázi
  /// byl podle konce čísla nalezen jediný odpovídající vůz.
  Future<bool?> _showShortMatchConfirmDialog(String formattedNumber) async {
    if (!mounted || _isDisposing) return null;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nalezeno v databázi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podle konce čísla byl v databázi vozů nalezen tento vůz:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              formattedNumber,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Je to opravdu tento vůz?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zadat ručně'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ano, správně'),
          ),
        ],
      ),
    );
  }

  /// Výběr po třetím, "krátkém" pokusu o skenování – konci čísla odpovídá
  /// v databázi více vozů, nechá uživatele vybrat ten správný (nebo žádný).
  Future<String?> _showShortMatchSelectionDialog(
      List<WagonRegistryEntry> matches) async {
    if (!mounted || _isDisposing) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nalezeno více shod'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podle konce čísla bylo v databázi nalezeno více vozů. Vyberte, který je správně:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...matches.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(entry.number),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text(
                      entry.formattedNumber,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Žádné z nich – zadat ručně'),
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

  /// Sestaví data pro zápis vozu do soupisu a rovnou zkontroluje trvalý
  /// registr vozů – pokud už je vůz v registru znám, jeho poznámky a
  /// příznaky se automaticky předvyplní.
  Future<Map<String, dynamic>> _buildWagonData(
    String number,
    String formatted,
    bool isValid,
    int order,
  ) async {
    final registryEntry = await WagonRegistryService.getEntry(number);
    return {
      'number': number,
      'formatted': formatted,
      'isValid': isValid,
      'order': order,
      'notes': registryEntry?.notes,
      'weight': registryEntry?.weight,
      'brakeWeightG': registryEntry?.brakeWeightG,
      'brakeWeightP': registryEntry?.brakeWeightP,
      'handbrake': registryEntry?.handbrake ?? false,
      'handbrakeForceKn': registryEntry?.handbrakeForceKn,
      'maxSpeedEmpty': registryEntry?.maxSpeedEmpty,
      'maxSpeedLoaded': registryEntry?.maxSpeedLoaded,
      'length': registryEntry?.length,
      'axleCount': registryEntry?.axleCount,
      'nonMetallicBlocks': registryEntry?.nonMetallicBlocks ?? false,
    };
  }

  /// Má vůz z [_buildWagonData] nějaké skutečné info (ne jen "prázdný"
  /// záznam v registru)? Používá se jen pro rozhodnutí, zda uživateli
  /// zobrazit hlášku o automatickém předvyplnění.
  bool _wagonDataHasInfo(Map<String, dynamic> data) {
    final notes = data['notes'] as String?;
    return (notes?.trim().isNotEmpty ?? false) ||
        data['weight'] != null ||
        data['brakeWeightG'] != null ||
        data['brakeWeightP'] != null ||
        (data['handbrake'] as bool? ?? false) ||
        data['maxSpeedEmpty'] != null ||
        data['maxSpeedLoaded'] != null ||
        data['length'] != null ||
        data['axleCount'] != null ||
        (data['nonMetallicBlocks'] as bool? ?? false);
  }

  /// Má vůz z [_buildWagonData] vyplněné úplně všechny sledované technické
  /// údaje? Stejná pravidla jako [WagonNumber.hasCompleteInfo] (výjimka:
  /// ruční brzda nemusí být přítomná).
  bool _isWagonDataComplete(Map<String, dynamic> data) {
    final handbrake = data['handbrake'] as bool? ?? false;
    return data['weight'] != null &&
        data['brakeWeightG'] != null &&
        data['brakeWeightP'] != null &&
        data['maxSpeedEmpty'] != null &&
        data['maxSpeedLoaded'] != null &&
        data['length'] != null &&
        data['axleCount'] != null &&
        (!handbrake || data['handbrakeForceKn'] != null);
  }

  Future<void> _addSelectedWagon(String selectedNumber) async {
    if (_currentInventoryId == null) {
      _showMessage('Nejprve pojmenujte soupis');
      return;
    }

    final formatted = UicValidator.formatUicNumber(selectedNumber);
    final wagonData = await _buildWagonData(
        selectedNumber, formatted, true, _nextOrderNumber);

    await InventoryService.addWagonNumbersBatch(
        _currentInventoryId!, [wagonData]);

    if (mounted && !_isDisposing) {
      setState(() {
        _detectedNumbers.add(selectedNumber);
        _totalWagonCount++; // Aktualizujeme celkový počet
        _nextOrderNumber++;
        _wagonComplete[selectedNumber] = _isWagonDataComplete(wagonData);
      });
      final foundInRegistry = _wagonDataHasInfo(wagonData);
      _showMessage(foundInRegistry
          ? 'Přidáno číslo vozu: $formatted • nalezeno v databázi, informace načteny'
          : 'Přidáno číslo vozu: $formatted');
    }
  }

  void _showOverlay(String message, Color color) {
    if (!mounted) return;
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
    _statusTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = null);
    });
  }

  void _showError(String message) => _showOverlay(message, Colors.red);
  void _showMessage(String message) => _showOverlay(message, Colors.green);

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

      // Po návratu z detailu obnovíme příznak "kompletní údaje" pro tento
      // vůz – v detailu se mohla technická data změnit (nebo vůz smazat).
      await _refreshWagonCompleteness(wagonData.number);
    } catch (e) {
      if (mounted) {
        _showError('Chyba při otevírání detailů vozu: $e');
      }
    }
  }

  /// Znovu načte, zda má daný vůz v aktuálním soupisu vyplněné všechny
  /// sledované technické údaje, a promítne to do [_wagonComplete].
  Future<void> _refreshWagonCompleteness(String number) async {
    if (_currentInventoryId == null || !mounted) return;
    try {
      final wagons = await InventoryService.getWagonNumbersForInventory(
          _currentInventoryId!);
      WagonNumber? wagon;
      for (final w in wagons) {
        if (w.number == number) {
          wagon = w;
          break;
        }
      }
      if (mounted) {
        setState(() {
          if (wagon != null) {
            _wagonComplete[number] = wagon.hasCompleteInfo;
          } else {
            _wagonComplete.remove(number);
          }
        });
      }
    } catch (e) {
      debugPrint('Chyba při obnovování stavu vozu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ThemeService.kRailAmber),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SKENOVÁNÍ VOZŮ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isDisposing ? null : () => _handleExit(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off_outlined),
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
                    if (_statusMessage != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
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
                  color: ThemeService.kRailBlack,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              color: ThemeService.kRailAmber,
                              margin: const EdgeInsets.only(right: 8),
                            ),
                            Text(
                              'VOZY V SOUPISU ($_totalWagonCount)  ·  RELACE: ${_detectedNumbers.length}',
                              style: TextStyle(
                                color: ThemeService.kRailAmber,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                          color: ThemeService.kRailAmber.withValues(alpha: 0.3),
                          height: 1),
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
                                  final isComplete =
                                      _wagonComplete[number] ?? false;
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
                                        Tooltip(
                                          message: isComplete
                                              ? 'Databáze: technické údaje kompletní'
                                              : 'Databáze: technické údaje neúplné',
                                          child: Icon(
                                            isComplete
                                                ? Icons.circle
                                                : Icons.circle_outlined,
                                            size: 8,
                                            color: isComplete
                                                ? Colors.greenAccent
                                                    .withValues(alpha: 0.8)
                                                : Colors.white24,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: ThemeService.kRailAmber,
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
                color: ThemeService.kRailBlack,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || _isDisposing)
                        ? null
                        : _captureAndAnalyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeService.kRailAmber,
                      foregroundColor: ThemeService.kRailBlack,
                      disabledBackgroundColor:
                          ThemeService.kRailAmber.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: _isProcessing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: ThemeService.kRailBlack, strokeWidth: 2))
                        : const Icon(Icons.document_scanner_outlined),
                    label: Text(
                      _isProcessing ? 'ZPRACOVÁVÁM...' : 'SKENOVAT',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final digits =
              controller.text.replaceAll(RegExp(r'[^0-9]'), '');
          final digitCount = digits.length;
          final isComplete = digitCount == 12;
          final isValid =
              isComplete && UicValidator.validateUicNumber(digits);

          final Color borderColor;
          if (isComplete) {
            borderColor = isValid ? Colors.green : Colors.red;
          } else {
            borderColor = Colors.grey;
          }

          return AlertDialog(
        title: const Text('Opravit číslo vozu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadejte správné číslo vozu:'),
            const SizedBox(height: 16),
            TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [_UicInputFormatter()],
                onChanged: (value) => setDialogState(() {}),
                decoration: InputDecoration(
                  labelText: 'Číslo vozu',
                  hintText: 'XX XX XXXX XXX-X',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isComplete
                          ? borderColor
                          : Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  counterText: '$digitCount / 12',
                  counterStyle: TextStyle(
                    color: isComplete
                        ? (isValid ? Colors.green : Colors.red)
                        : null,
                  ),
                )),
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
                final nav = Navigator.of(context);

                // Přidáme opravené číslo jako nový záznam místo aktualizace
                final wagonData = await _buildWagonData(
                    newNumber, newFormatted, isValid, order);

                await InventoryService.addWagonNumbersBatch(
                    _currentInventoryId!, [wagonData]);

                if (mounted) {
                  nav.pop();
                  _showEditResult(newFormatted, isValid);

                  // Přidáme opravené číslo také do seznamu detekovaných čísel pro zobrazení v UI
                  setState(() {
                    _detectedNumbers.add(newNumber);
                    _totalWagonCount++; // Aktualizujeme celkový počet
                    _nextOrderNumber++;
                    _wagonComplete[newNumber] = _isWagonDataComplete(wagonData);
                  });
                }
              }
            },
            child: const Text('Uložit'),
          ),
        ],
          );
        },
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
