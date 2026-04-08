class Personnel {
  final int? id;
  final String name;
  final String? cccd;
  final String? role; // "TX" or "PX"
  final bool isActive;
  final bool isWorking;
  final String? driverLicense;
  final DateTime? startDate;
  final double? deposit;
  final DateTime createdAt;

  Personnel({
    this.id,
    required this.name,
    this.cccd,
    this.role,
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
      'cccd': cccd,
      'role': role,
      'basic_salary': 0.0, // Keep in schema backwards compatibility if SQLite hasn't dropped it (as we don't drop columns)
      'is_active': isActive ? 1 : 0,
      'is_working': isWorking ? 1 : 0,
      'driver_license': driverLicense,
      'start_date': startDate?.toIso8601String(),
      'deposit': deposit,
      'seniority_salary': 0.0,
      'additional_allowance': 0.0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Personnel.fromMap(Map<String, dynamic> map) {
    return Personnel(
      id: map['id'],
      name: map['name'] ?? 'Không tên',
      cccd: map['cccd']?.toString(),
      role: map['role']?.toString(),
      isActive: map['is_active'] == 1,
      isWorking: map['is_working'] == 1 || map['is_working'] == null,
      driverLicense: map['driver_license'] as String?,
      startDate: map['start_date'] != null && map['start_date'].toString().isNotEmpty
          ? DateTime.tryParse(map['start_date'] as String)
          : null,
      deposit: map['deposit'] != null
          ? (map['deposit'] as num).toDouble()
          : null,
      createdAt: map['created_at'] != null && map['created_at'].toString().isNotEmpty 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Personnel copyWith({
    int? id,
    String? name,
    String? cccd,
    String? role,
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
      cccd: cccd ?? this.cccd,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isWorking: isWorking ?? this.isWorking,
      driverLicense: driverLicense ?? this.driverLicense,
      startDate: startDate ?? this.startDate,
      deposit: deposit ?? this.deposit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
