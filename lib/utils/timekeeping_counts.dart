import '../models/timekeeping.dart';

/// Kết quả đếm công/nghỉ cho một nhân sự.
///
/// Quy ước nghiệp vụ (đã chốt với khách hàng):
/// - Mỗi lượt chấm TX/PX tại một điểm giao dịch = 1 công.
///   Cùng một ngày có thể chấm nhiều điểm giao dịch => nhiều công.
/// - NP/KP tính theo ngày: một ngày chỉ tính 1 lần dù chấm nhiều điểm.
/// - Bản ghi trùng hoàn toàn (cùng ngày + điểm + trạng thái) chỉ tính 1 lần.
class TimekeepingCounts {
  final int workingDays; // số công TX + PX
  final int phepDays; // số ngày nghỉ phép (NP)
  final int kphepDays; // số ngày nghỉ không phép (KP)

  const TimekeepingCounts({
    this.workingDays = 0,
    this.phepDays = 0,
    this.kphepDays = 0,
  });
}

/// Đếm công/nghỉ theo từng nhân sự từ danh sách chi tiết chấm công.
///
/// Đây là nguồn sự thật duy nhất cho màn "Chấm công chi tiết"; kết quả
/// phải khớp với `DatabaseHelper.getTimekeepingSummary` trên cùng dữ liệu.
Map<int, TimekeepingCounts> countTimekeepingByPersonnel(
  Iterable<TimekeepingDetail> details,
) {
  final workingKeys = <int, Set<String>>{};
  final phepDates = <int, Set<String>>{};
  final kphepDates = <int, Set<String>>{};

  for (final d in details) {
    final dateKey = '${d.date.year}-${d.date.month}-${d.date.day}';
    if (d.dayStatus == DayStatus.tx || d.dayStatus == DayStatus.px) {
      // Mỗi (ngày, điểm giao dịch, trạng thái) = 1 công
      (workingKeys[d.personnelId] ??= <String>{})
          .add('$dateKey|${d.transactionPointId}|${d.dayStatus}');
    } else if (d.dayStatus == DayStatus.np) {
      (phepDates[d.personnelId] ??= <String>{}).add(dateKey);
    } else if (d.dayStatus == DayStatus.kp) {
      (kphepDates[d.personnelId] ??= <String>{}).add(dateKey);
    }
  }

  final ids = <int>{
    ...workingKeys.keys,
    ...phepDates.keys,
    ...kphepDates.keys,
  };

  return {
    for (final id in ids)
      id: TimekeepingCounts(
        workingDays: workingKeys[id]?.length ?? 0,
        phepDays: phepDates[id]?.length ?? 0,
        kphepDays: kphepDates[id]?.length ?? 0,
      ),
  };
}
