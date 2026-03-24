class JobPosition {
  final int? id;
  final String name;
  final double salary;
  final bool isActive;
  final DateTime createdAt;

  JobPosition({
    this.id,
    required this.name,
    required this.salary,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'salary': salary,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory JobPosition.fromMap(Map<String, dynamic> map) {
    return JobPosition(
      id: map['id'],
      name: map['name'],
      salary: map['salary'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  JobPosition copyWith({
    int? id,
    String? name,
    double? salary,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return JobPosition(
      id: id ?? this.id,
      name: name ?? this.name,
      salary: salary ?? this.salary,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
