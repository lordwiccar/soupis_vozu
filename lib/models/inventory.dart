class Inventory {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime lastModified; // Nové pole pro poslední změnu
  final List<WagonNumber> wagonNumbers;
  final String? notes;
  final String? location; // Nové pole pro lokaci

  const Inventory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastModified,
    required this.wagonNumbers,
    this.notes,
    this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'wagonNumbers': wagonNumbers.map((wagon) => wagon.toMap()).toList(),
      'notes': notes,
      'location': location,
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastModified: DateTime.parse(map['last_modified'] as String),
      wagonNumbers: [], // Will be loaded separately
      notes: map['notes'] as String?,
      location: map['location'] as String?,
    );
  }
}

class WagonNumber {
  static const String flagM   = 'M';
  static const String flagK   = 'K';
  static const String flagR1  = 'R1';
  static const String flag314 = '314';
  static const List<String> allFlags = [flagM, flagK, flagR1, flag314];
  static const Map<String, String> flagDescriptions = {
    flagM:   'Zkontrolovat',
    flagK:   'Nenakládat / Po vyložení k opravě',
    flagR1:  'Brzda neupotřebitelná',
    flag314: 'Ještě použitelný',
  };

  final String number;
  final String formattedNumber;
  final bool isValid;
  final int order;
  final DateTime scannedAt;
  final String? notes;

  // Technické údaje o voze – volitelné, doplňují notes/příznaky.
  final double? weight; // Hmotnost vozu (t)
  final double? brakeWeightG; // Brzdící váha (P) (t)
  final double? brakeWeightP; // Brzdící váha (L) (t)
  final bool handbrake; // Ruční brzda (ano/ne)
  final double? handbrakeForceKn; // Hodnota ruční brzdy (kN), jen když handbrake == true
  final double? maxSpeedEmpty; // Rychlost prázdný (km/h)
  final double? maxSpeedLoaded; // Rychlost ložený (km/h)
  final double? length; // Délka (m)
  final int? axleCount; // Počet náprav
  final bool nonMetallicBlocks; // Nekovové špalíky (ano/ne)

  const WagonNumber({
    required this.number,
    required this.formattedNumber,
    required this.isValid,
    required this.order,
    required this.scannedAt,
    this.notes,
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

  /// Má vůz uložené nějaké informace (poznámky/příznaky nebo technické
  /// údaje)? Používá se pro rozhodnutí, zda má vůz záznam v trvalém
  /// registru vozů.
  bool get hasInfo =>
      (notes?.trim().isNotEmpty ?? false) ||
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

  WagonNumber copyWith({
    String? number,
    String? formattedNumber,
    bool? isValid,
    int? order,
    DateTime? scannedAt,
    String? notes,
    double? weight,
    double? brakeWeightG,
    double? brakeWeightP,
    bool? handbrake,
    double? handbrakeForceKn,
    double? maxSpeedEmpty,
    double? maxSpeedLoaded,
    double? length,
    int? axleCount,
    bool? nonMetallicBlocks,
  }) {
    return WagonNumber(
      number: number ?? this.number,
      formattedNumber: formattedNumber ?? this.formattedNumber,
      isValid: isValid ?? this.isValid,
      order: order ?? this.order,
      scannedAt: scannedAt ?? this.scannedAt,
      notes: notes ?? this.notes,
      weight: weight ?? this.weight,
      brakeWeightG: brakeWeightG ?? this.brakeWeightG,
      brakeWeightP: brakeWeightP ?? this.brakeWeightP,
      handbrake: handbrake ?? this.handbrake,
      handbrakeForceKn: handbrakeForceKn ?? this.handbrakeForceKn,
      maxSpeedEmpty: maxSpeedEmpty ?? this.maxSpeedEmpty,
      maxSpeedLoaded: maxSpeedLoaded ?? this.maxSpeedLoaded,
      length: length ?? this.length,
      axleCount: axleCount ?? this.axleCount,
      nonMetallicBlocks: nonMetallicBlocks ?? this.nonMetallicBlocks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'formattedNumber': formattedNumber,
      'isValid': isValid,
      'order': order,
      'scannedAt': scannedAt.toIso8601String(),
      'notes': notes,
      'weight': weight,
      'brakeWeightG': brakeWeightG,
      'brakeWeightP': brakeWeightP,
      'handbrake': handbrake,
      'handbrakeForceKn': handbrakeForceKn,
      'maxSpeedEmpty': maxSpeedEmpty,
      'maxSpeedLoaded': maxSpeedLoaded,
      'length': length,
      'axleCount': axleCount,
      'nonMetallicBlocks': nonMetallicBlocks,
    };
  }

  factory WagonNumber.fromMap(Map<String, dynamic> map) {
    return WagonNumber(
      number: map['number'] as String,
      formattedNumber: map['formatted_number'] as String,
      isValid: (map['is_valid'] as int) == 1,
      order: map['order_number'] as int,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
      notes: map['notes'] as String?,
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

  /// Rozloží uložený string poznámek (např. "M + K - text poznámky") na
  /// seznam příznaků a volný text. Pokud text neobsahuje žádný známý
  /// příznak, považuje se celý za volný text.
  static ({List<String> flags, String text}) parseNotes(String? notes) {
    if (notes == null || notes.isEmpty) {
      return (flags: <String>[], text: '');
    }

    final parts = notes.split(' - ');
    final flagsPart = parts[0];
    final textPart = parts.length > 1 ? parts.sublist(1).join(' - ') : '';

    final validFlags = <String>[];
    for (final flag in allFlags) {
      if (flagsPart.contains(flag)) {
        validFlags.add(flag);
      }
    }

    if (validFlags.isNotEmpty) {
      return (flags: validFlags, text: textPart);
    }
    return (flags: <String>[], text: notes);
  }

  /// Sestaví jeden string poznámek ze seznamu příznaků a volného textu,
  /// ve stejném formátu, jaký očekává [parseNotes].
  static String composeNotes(List<String> flags, String text) {
    final flagStr = flags.join(' + ');
    if (flagStr.isEmpty) return text;
    if (text.isEmpty) return flagStr;
    return '$flagStr - $text';
  }
}
