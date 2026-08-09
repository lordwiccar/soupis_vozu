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
  final double? brakeWeightG; // Brzdící váha (P) (t)
  final double? brakeWeightP; // Brzdící váha (L) (t)
  final bool handbrake; // Ruční brzda (ano/ne)
  final double? handbrakeForceKn; // Hodnota ruční brzdy (kN)
  final double? maxSpeedEmpty; // Rychlost prázdný (km/h)
  final double? maxSpeedLoaded; // Rychlost ložený (km/h)
  final double? length; // Délka (m)
  final int? axleCount; // Počet náprav
  final bool nonMetallicBlocks; // Nekovové špalíky (ano/ne)

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
    this.maxSpeedEmpty,
    this.maxSpeedLoaded,
    this.length,
    this.axleCount,
    this.nonMetallicBlocks = false,
  });

  /// Má tento záznam nějaké skutečné informace (poznámky/příznaky nebo
  /// technické údaje), nebo je to jen "prázdný" vůz v registru?
  bool get hasInfo =>
      notes.trim().isNotEmpty ||
      weight != null ||
      brakeWeightG != null ||
      brakeWeightP != null ||
      handbrake ||
      maxSpeedEmpty != null ||
      maxSpeedLoaded != null ||
      length != null ||
      axleCount != null ||
      nonMetallicBlocks;

  /// Má vůz v databázi vyplněné všechny sledované technické údaje?
  /// Výjimkou je "Ruční brzda" – řada vozů ji fyzicky nemá, takže se
  /// nevyžaduje, aby byla zapnutá; pokud zapnutá je, vyžaduje se u ní
  /// i hodnota brzdné síly.
  bool get hasCompleteInfo =>
      weight != null &&
      brakeWeightG != null &&
      brakeWeightP != null &&
      maxSpeedEmpty != null &&
      maxSpeedLoaded != null &&
      length != null &&
      axleCount != null &&
      (!handbrake || handbrakeForceKn != null);

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
      'max_speed_empty': maxSpeedEmpty,
      'max_speed_loaded': maxSpeedLoaded,
      'length': length,
      'axle_count': axleCount,
      'non_metallic_blocks': nonMetallicBlocks ? 1 : 0,
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
      maxSpeedEmpty: (map['max_speed_empty'] as num?)?.toDouble(),
      maxSpeedLoaded: (map['max_speed_loaded'] as num?)?.toDouble(),
      length: (map['length'] as num?)?.toDouble(),
      axleCount: map['axle_count'] as int?,
      nonMetallicBlocks: (map['non_metallic_blocks'] as int?) == 1,
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
