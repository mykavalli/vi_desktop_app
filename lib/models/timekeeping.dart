/// Day status constants
class DayStatus {
  static const String tx = 'TX';       // Tài xế
  static const String px = 'PX';       // Phụ xe
  static const String np = 'NP';       // Nghỉ phép
  static const String kp = 'KP';       // Nghỉ không phép
}

class Timekeeping {
  final int? id;
  final int personnelId;
  final DateTime date;
  final int jobPositionId; // Kept for schema backwards compatibility
  final int transactionPointId;
  final DateTime createdAt;
  final String dayStatus; // 'TX', 'PX', 'NP', 'KP'

  Timekeeping({
    this.id,
    required this.personnelId,
    required this.date,
    this.jobPositionId = 1, // Defaulting to 1 as it's no longer managed by user
    required this.transactionPointId,
    required this.createdAt,
    this.dayStatus = DayStatus.tx,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personnel_id': personnelId,
      'date': date.toIso8601String().split('T')[0],
      'job_position_id': jobPositionId,
      'transaction_point_id': transactionPointId,
      'created_at': createdAt.toIso8601String(),
      'day_status': dayStatus,
    };
  }

  factory Timekeeping.fromMap(Map<String, dynamic> map) {
    return Timekeeping(
      id: map['id'],
      personnelId: map['personnel_id'],
      date: DateTime.parse(map['date']),
      jobPositionId: map['job_position_id'] ?? 1,
      transactionPointId: map['transaction_point_id'],
      createdAt: DateTime.parse(map['created_at']),
      dayStatus: map['day_status'] as String? ?? DayStatus.tx,
    );
  }

  Timekeeping copyWith({
    int? id,
    int? personnelId,
    DateTime? date,
    int? jobPositionId,
    int? transactionPointId,
    DateTime? createdAt,
    String? dayStatus,
  }) {
    return Timekeeping(
      id: id ?? this.id,
      personnelId: personnelId ?? this.personnelId,
      date: date ?? this.date,
      jobPositionId: jobPositionId ?? this.jobPositionId,
      transactionPointId: transactionPointId ?? this.transactionPointId,
      createdAt: createdAt ?? this.createdAt,
      dayStatus: dayStatus ?? this.dayStatus,
    );
  }
}

class TimekeepingDetail {
  final int timekeepingId;
  final int personnelId;
  final String personnelName;
  final bool personnelIsWorking;
  final DateTime date;
  final int transactionPointId;
  final String transactionPointName;
  final String dayStatus;

  TimekeepingDetail({
    required this.timekeepingId,
    required this.personnelId,
    required this.personnelName,
    this.personnelIsWorking = true,
    required this.date,
    required this.transactionPointId,
    required this.transactionPointName,
    this.dayStatus = DayStatus.tx,
  });

  factory TimekeepingDetail.fromMap(Map<String, dynamic> map) {
    return TimekeepingDetail(
      timekeepingId: map['timekeeping_id'],
      personnelId: map['personnel_id'],
      personnelName: map['personnel_name'],
      personnelIsWorking: (map['personnel_is_working'] as int? ?? 1) == 1,
      date: DateTime.parse(map['date']),
      transactionPointId: map['transaction_point_id'],
      transactionPointName: map['transaction_point_name'],
      dayStatus: map['day_status'] as String? ?? DayStatus.tx,
    );
  }
}

class TimekeepingSummary {
  final int personnelId;
  final String personnelName;
  final String personnelRole;
  final bool isWorking;
  final int totalWorkingDays; // Số công TX + PX (mỗi điểm giao dịch/ngày = 1 công)
  final int totalPxDays; // Số công PX (mỗi điểm giao dịch/ngày = 1 công)
  final int totalDaysOff; // Số ngày NP (theo ngày)
  final int totalDaysUnauth; // Số ngày KP (theo ngày)
  final Map<String, int> txDaysByTransactionPoint; // Số công TX theo điểm giao dịch

  TimekeepingSummary({
    required this.personnelId,
    required this.personnelName,
    required this.personnelRole,
    this.isWorking = true,
    required this.totalWorkingDays,
    required this.totalPxDays,
    this.totalDaysOff = 0,
    this.totalDaysUnauth = 0,
    required this.txDaysByTransactionPoint,
  });
}
