class Wagon {
  final String id;
  final String uicNumber;
  final String? note;
  final DateTime createdAt;
  final bool isValid;

  Wagon({
    required this.id,
    required this.uicNumber,
    this.note,
    required this.createdAt,
    required this.isValid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uicNumber': uicNumber,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'isValid': isValid ? 1 : 0,
    };
  }

  factory Wagon.fromMap(Map<String, dynamic> map) {
    return Wagon(
      id: map['id'],
      uicNumber: map['uicNumber'],
      note: map['note'],
      createdAt: DateTime.parse(map['createdAt']),
      isValid: map['isValid'] == 1,
    );
  }
}

class Session {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Session({
    required this.id,
    required this.name,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }
}
