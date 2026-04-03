/// Day status constants
class DayStatus {
  static const String work = 'work';       // Đi làm
  static const String phep = 'phep';       // Nghỉ phép (authorized)
  static const String kphep = 'kphep';     // Nghỉ không phép (unauthorized)
}

class Timekeeping {
  final int? id;
  final int personnelId;
  final DateTime date;
  final int jobPositionId;
  final int transactionPointId;
  final DateTime createdAt;
  final String dayStatus; // 'work', 'phep', 'kphep'

  Timekeeping({
    this.id,
    required this.personnelId,
    required this.date,
    required this.jobPositionId,
    required this.transactionPointId,
    required this.createdAt,
    this.dayStatus = DayStatus.work,
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
      jobPositionId: map['job_position_id'],
      transactionPointId: map['transaction_point_id'],
      createdAt: DateTime.parse(map['created_at']),
      dayStatus: map['day_status'] as String? ?? DayStatus.work,
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
  final int jobPositionId;
  final String jobPositionName;
  final int transactionPointId;
  final String transactionPointName;
  final String dayStatus;

  TimekeepingDetail({
    required this.timekeepingId,
    required this.personnelId,
    required this.personnelName,
    this.personnelIsWorking = true,
    required this.date,
    required this.jobPositionId,
    required this.jobPositionName,
    required this.transactionPointId,
    required this.transactionPointName,
    this.dayStatus = DayStatus.work,
  });

  factory TimekeepingDetail.fromMap(Map<String, dynamic> map) {
    return TimekeepingDetail(
      timekeepingId: map['timekeeping_id'],
      personnelId: map['personnel_id'],
      personnelName: map['personnel_name'],
      personnelIsWorking: (map['personnel_is_working'] as int? ?? 1) == 1,
      date: DateTime.parse(map['date']),
      jobPositionId: map['job_position_id'],
      jobPositionName: map['job_position_name'],
      transactionPointId: map['transaction_point_id'],
      transactionPointName: map['transaction_point_name'],
      dayStatus: map['day_status'] as String? ?? DayStatus.work,
    );
  }
}

class TimekeepingSummary {
  final int personnelId;
  final String personnelName;
  final bool isWorking;
  final int totalDays;       // work days only
  final int totalDaysOff;    // phep days
  final int totalDaysUnauth; // kphep days
  final Map<String, int> daysByTransactionPoint;
  final double totalSalary;

  TimekeepingSummary({
    required this.personnelId,
    required this.personnelName,
    this.isWorking = true,
    required this.totalDays,
    this.totalDaysOff = 0,
    this.totalDaysUnauth = 0,
    required this.daysByTransactionPoint,
    this.totalSalary = 0.0,
  });
}
