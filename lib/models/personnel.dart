class Personnel {
  final int? id;
  final String name;
  final double basicSalary;
  final bool isActive;
  final DateTime createdAt;

  Personnel({
    this.id,
    required this.name,
    required this.basicSalary,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'basic_salary': basicSalary,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Personnel.fromMap(Map<String, dynamic> map) {
    return Personnel(
      id: map['id'],
      name: map['name'],
      basicSalary: map['basic_salary'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Personnel copyWith({
    int? id,
    String? name,
    double? basicSalary,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Personnel(
      id: id ?? this.id,
      name: name ?? this.name,
      basicSalary: basicSalary ?? this.basicSalary,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
