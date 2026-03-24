class Timekeeping {
  final int? id;
  final int personnelId;
  final DateTime date;
  final int jobPositionId;
  final int transactionPointId;
  final DateTime createdAt;

  Timekeeping({
    this.id,
    required this.personnelId,
    required this.date,
    required this.jobPositionId,
    required this.transactionPointId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personnel_id': personnelId,
      'date': date.toIso8601String().split('T')[0],
      'job_position_id': jobPositionId,
      'transaction_point_id': transactionPointId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Timekeeping.fromMap(Map<String, dynamic> map) {
    return Timekeeping(
      id: map['id'],
      personnelId: map['personnel_id'],
      date: DateTime.parse(map['date']),
      jobPositionId: map['job_position_id'],
      transactionPointId: map['transaction_point_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Timekeeping copyWith({
    int? id,
    int? personnelId,
    DateTime? date,
    int? jobPositionId,
    int? transactionPointId,
    DateTime? createdAt,
  }) {
    return Timekeeping(
      id: id ?? this.id,
      personnelId: personnelId ?? this.personnelId,
      date: date ?? this.date,
      jobPositionId: jobPositionId ?? this.jobPositionId,
      transactionPointId: transactionPointId ?? this.transactionPointId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TimekeepingDetail {
  final int timekeepingId;
  final int personnelId;
  final String personnelName;
  final DateTime date;
  final int jobPositionId;
  final String jobPositionName;
  final int transactionPointId;
  final String transactionPointName;

  TimekeepingDetail({
    required this.timekeepingId,
    required this.personnelId,
    required this.personnelName,
    required this.date,
    required this.jobPositionId,
    required this.jobPositionName,
    required this.transactionPointId,
    required this.transactionPointName,
  });

  factory TimekeepingDetail.fromMap(Map<String, dynamic> map) {
    return TimekeepingDetail(
      timekeepingId: map['timekeeping_id'],
      personnelId: map['personnel_id'],
      personnelName: map['personnel_name'],
      date: DateTime.parse(map['date']),
      jobPositionId: map['job_position_id'],
      jobPositionName: map['job_position_name'],
      transactionPointId: map['transaction_point_id'],
      transactionPointName: map['transaction_point_name'],
    );
  }
}

class TimekeepingSummary {
  final int personnelId;
  final String personnelName;
  final int totalDays;
  final Map<String, int> daysByTransactionPoint;
  final double totalSalary;

  TimekeepingSummary({
    required this.personnelId,
    required this.personnelName,
    required this.totalDays,
    required this.daysByTransactionPoint,
    this.totalSalary = 0.0,
  });
}
