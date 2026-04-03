class Personnel {
  final int? id;
  final String name;
  final double basicSalary;
  final bool isActive;
  final bool isWorking;
  final String? driverLicense;
  final DateTime? startDate;
  final double? deposit;
  final DateTime createdAt;

  Personnel({
    this.id,
    required this.name,
    required this.basicSalary,
    this.isActive = true,
    this.isWorking = true,
    this.driverLicense,
    this.startDate,
    this.deposit,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'basic_salary': basicSalary,
      'is_active': isActive ? 1 : 0,
      'is_working': isWorking ? 1 : 0,
      'driver_license': driverLicense,
      'start_date': startDate?.toIso8601String(),
      'deposit': deposit,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Personnel.fromMap(Map<String, dynamic> map) {
    return Personnel(
      id: map['id'],
      name: map['name'],
      basicSalary: (map['basic_salary'] as num).toDouble(),
      isActive: map['is_active'] == 1,
      isWorking: map['is_working'] == 1,
      driverLicense: map['driver_license'] as String?,
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'] as String)
          : null,
      deposit: map['deposit'] != null
          ? (map['deposit'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Personnel copyWith({
    int? id,
    String? name,
    double? basicSalary,
    bool? isActive,
    bool? isWorking,
    String? driverLicense,
    DateTime? startDate,
    double? deposit,
    DateTime? createdAt,
  }) {
    return Personnel(
      id: id ?? this.id,
      name: name ?? this.name,
      basicSalary: basicSalary ?? this.basicSalary,
      isActive: isActive ?? this.isActive,
      isWorking: isWorking ?? this.isWorking,
      driverLicense: driverLicense ?? this.driverLicense,
      startDate: startDate ?? this.startDate,
      deposit: deposit ?? this.deposit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
