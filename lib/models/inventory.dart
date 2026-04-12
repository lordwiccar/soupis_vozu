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
  final String number;
  final String formattedNumber;
  final bool isValid;
  final int order;
  final DateTime scannedAt;
  final String? notes;

  const WagonNumber({
    required this.number,
    required this.formattedNumber,
    required this.isValid,
    required this.order,
    required this.scannedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'formattedNumber': formattedNumber,
      'isValid': isValid,
      'order': order,
      'scannedAt': scannedAt.toIso8601String(),
      'notes': notes,
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
    );
  }
}
