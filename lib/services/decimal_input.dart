import 'package:flutter/services.dart';

/// Povolí v textovém poli jen číslice a jeden desetinný oddělovač
/// (čárku nebo tečku) – používá se pro technické údaje o voze
/// (hmotnost, brzdící váhy, rychlost, délka).
class DecimalInputFormatter extends TextInputFormatter {
  static final RegExp _pattern = RegExp(r'^[0-9]*[.,]?[0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (!_pattern.hasMatch(newValue.text)) return oldValue;
    return newValue;
  }
}

/// Naparsuje desetinné číslo ze zadaného textu, čárka i tečka jsou
/// akceptovány jako oddělovač. Prázdný/neplatný text vrátí `null`.
double? parseDecimal(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

/// Naformátuje hodnotu pro zobrazení v poli – čárka jako desetinný
/// oddělovač, celá čísla bez zbytečné ",0".
String formatDecimal(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString().replaceAll('.', ',');
}
