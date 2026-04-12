class Contact {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
  final bool isCopyRecipient;

  const Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.isCopyRecipient = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'is_copy_recipient': isCopyRecipient ? 1 : 0,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isCopyRecipient: (map['is_copy_recipient'] as int? ?? 0) == 1,
    );
  }
}
