class TransactionPoint {
  final int? id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  TransactionPoint({
    this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionPoint.fromMap(Map<String, dynamic> map) {
    return TransactionPoint(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  TransactionPoint copyWith({
    int? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TransactionPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
