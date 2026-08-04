/// Záznam v trvalém registru vozů (napříč všemi soupisy).
///
/// Vůz v registru zůstává i poté, co uživatel veškeré informace (poznámky,
/// příznaky, technické údaje) smaže – řádek se pak jen aktualizuje na
/// "prázdný" stav, nemaže se. Smazat záznam lze pouze ručně (viz
/// WagonRegistryService.deleteEntry).
class WagonRegistryEntry {
  final String number; // 12 číslic, bez formátování
  final String formattedNumber; // "XX XX XXXX XXX-X"
  final String notes; // stejný formát jako WagonNumber.notes
  final DateTime updatedAt;

  // Technické údaje o voze – stejný význam jako u WagonNumber.
  final double? weight; // Hmotnost vozu (t)
  final double? brakeWeightG; // Brzdící váha G (t)
  final double? brakeWeightP; // Brzdící váha P (t)
  final bool handbrake; // Ruční brzda (ano/ne)
  final double? handbrakeForceKn; // Hodnota ruční brzdy (kN)
  final double? maxSpeed; // Rychlost (km/h)
  final double? length; // Délka (m)

  const WagonRegistryEntry({
    required this.number,
    required this.formattedNumber,
    required this.notes,
    required this.updatedAt,
    this.weight,
    this.brakeWeightG,
    this.brakeWeightP,
    this.handbrake = false,
    this.handbrakeForceKn,
    this.maxSpeed,
    this.length,
  });

  /// Má tento záznam nějaké skutečné informace (poznámky/příznaky nebo
  /// technické údaje), nebo je to jen "prázdný" vůz v registru?
  bool get hasInfo =>
      notes.trim().isNotEmpty ||
      weight != null ||
      brakeWeightG != null ||
      brakeWeightP != null ||
      handbrake ||
      maxSpeed != null ||
      length != null;

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'formatted_number': formattedNumber,
      'notes': notes,
      'updated_at': updatedAt.toIso8601String(),
      'weight': weight,
      'brake_weight_g': brakeWeightG,
      'brake_weight_p': brakeWeightP,
      'handbrake': handbrake ? 1 : 0,
      'handbrake_kn': handbrakeForceKn,
      'max_speed': maxSpeed,
      'length': length,
    };
  }

  factory WagonRegistryEntry.fromMap(Map<String, dynamic> map) {
    return WagonRegistryEntry(
      number: map['number'] as String,
      formattedNumber: map['formatted_number'] as String,
      notes: map['notes'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      weight: (map['weight'] as num?)?.toDouble(),
      brakeWeightG: (map['brake_weight_g'] as num?)?.toDouble(),
      brakeWeightP: (map['brake_weight_p'] as num?)?.toDouble(),
      handbrake: (map['handbrake'] as int?) == 1,
      handbrakeForceKn: (map['handbrake_kn'] as num?)?.toDouble(),
      maxSpeed: (map['max_speed'] as num?)?.toDouble(),
      length: (map['length'] as num?)?.toDouble(),
    );
  }
}

/// Souhrn výsledku importu registru ze souboru.
class WagonImportResult {
  final int added;
  final int skippedExisting;
  final int invalidRows;

  const WagonImportResult({
    required this.added,
    required this.skippedExisting,
    required this.invalidRows,
  });
}
