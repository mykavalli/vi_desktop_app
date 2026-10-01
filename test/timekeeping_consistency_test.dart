// ignore_for_file: avoid_print
//
// REGRESSION TEST: Đảm bảo "Chấm công tổng hợp" và "Chấm công chi tiết"
// luôn khớp số liệu với nhau.
//
// Quy ước nghiệp vụ (đã chốt):
// - Mỗi lượt chấm TX/PX tại một điểm giao dịch = 1 công.
//   Cùng một ngày có thể chấm nhiều điểm giao dịch => nhiều công.
// - NP/KP tính theo ngày (một ngày chỉ tính 1 lần).
// - Bản ghi trùng hoàn toàn (cùng ngày + điểm + trạng thái) chỉ tính 1 lần.
//
// Cách chạy:
//   flutter test test/timekeeping_consistency_test.dart --reporter expanded

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vi_desktop_app/database/database_helper.dart';
import 'package:vi_desktop_app/models/timekeeping.dart';
import 'package:vi_desktop_app/utils/timekeeping_counts.dart';

late Directory _dbDir;

// ==================== SEED HELPERS ====================

Future<void> _resetData() async {
  final db = await DatabaseHelper.instance.database;
  await db.delete('timekeeping');
  await db.delete('personnel');
  await db.delete('transaction_points');
  await db.delete('job_positions');
}

Future<void> _addPersonnel(
  int id,
  String name, {
  String role = 'TX',
  bool isActive = true,
  bool isWorking = true,
}) async {
  final db = await DatabaseHelper.instance.database;
  await db.insert('personnel', {
    'id': id,
    'name': name,
    'basic_salary': 0.0,
    'role': role,
    'is_active': isActive ? 1 : 0,
    'is_working': isWorking ? 1 : 0,
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
  });
}

Future<void> _addTp(int id, String name) async {
  final db = await DatabaseHelper.instance.database;
  await db.insert('transaction_points', {
    'id': id,
    'name': name,
    'is_active': 1,
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
  });
}

Future<void> _addJobPosition(int id, String name) async {
  final db = await DatabaseHelper.instance.database;
  await db.insert('job_positions', {
    'id': id,
    'name': name,
    'salary': 0.0,
    'is_active': 1,
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
  });
}

Future<void> _addTk(
  int personnelId,
  int tpId,
  DateTime date,
  String status, {
  int jobPositionId = 1,
}) async {
  await DatabaseHelper.instance.insertTimekeeping(Timekeeping(
    personnelId: personnelId,
    date: date,
    transactionPointId: tpId,
    jobPositionId: jobPositionId,
    createdAt: DateTime(2026, 1, 1),
    dayStatus: status,
  ));
}

// ==================== INVARIANT: 2 MÀN HÌNH PHẢI KHỚP ====================

/// So khớp số liệu màn chi tiết (tính từ danh sách detail) với màn tổng hợp.
Future<void> _expectScreensMatch({required int year, required int month}) async {
  final summaries = await DatabaseHelper.instance
      .getTimekeepingSummary(year: year, month: month);
  final details = await DatabaseHelper.instance
      .getTimekeepingDetail(year: year, month: month);
  final countsByPersonnel = countTimekeepingByPersonnel(details);

  for (final s in summaries) {
    final counts = countsByPersonnel[s.personnelId] ?? const TimekeepingCounts();
    expect(
      counts.workingDays,
      s.totalWorkingDays,
      reason: 'Số công của ${s.personnelName} phải khớp giữa 2 màn hình',
    );
    expect(counts.phepDays, s.totalDaysOff,
        reason: 'Nghỉ phép của ${s.personnelName} phải khớp');
    expect(counts.kphepDays, s.totalDaysUnauth,
        reason: 'Nghỉ không phép của ${s.personnelName} phải khớp');

    // Tổng công = tổng công TX theo điểm + tổng công PX
    final txTotal = s.txDaysByTransactionPoint.values
        .fold<int>(0, (sum, days) => sum + days);
    expect(s.totalWorkingDays, txTotal + s.totalPxDays,
        reason: 'Tổng công phải bằng tổng các cột TX + tổng PX');
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _dbDir = await Directory.systemTemp.createTemp('vi_tk_test_');
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(_dbDir.path);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.closeAndReset();
    try {
      await _dbDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await _resetData();
    await _addJobPosition(1, 'Tài xế');
  });

  group('A. Quy ước "mỗi điểm giao dịch = 1 công"', () {
    test('Case 0 – 1 điểm/ngày trong 30 ngày: 30 công', () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'BHX - HCM');
      for (var day = 1; day <= 30; day++) {
        await _addTk(1, 1, DateTime(2026, 4, day), DayStatus.tx);
      }

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 0: tổng hợp=${summary.totalWorkingDays} công | '
          'chi tiết=${counts[1]!.workingDays} công');

      expect(summary.totalWorkingDays, 30);
      expect(counts[1]!.workingDays, 30);
      await _expectScreensMatch(year: 2026, month: 4);
    });

    test('Case 1 – [LỖI CLIENT 30 vs 49] 19 ngày × 2 điểm + 11 ngày × 1 điểm',
        () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'BHX - HCM');
      await _addTp(2, 'Vị Thanh');

      for (var day = 1; day <= 19; day++) {
        await _addTk(1, 1, DateTime(2026, 4, day), DayStatus.tx);
        await _addTk(1, 2, DateTime(2026, 4, day), DayStatus.tx);
      }
      for (var day = 20; day <= 30; day++) {
        await _addTk(1, 1, DateTime(2026, 4, day), DayStatus.tx);
      }

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 1: 49 bản ghi (30 ngày, 19 ngày làm 2 điểm)');
      print('  - Tổng hợp: ${summary.totalWorkingDays} công');
      print('  - Chi tiết: ${counts[1]!.workingDays} công');
      print('  - TX theo điểm: ${summary.txDaysByTransactionPoint}');

      expect(details.length, 49);
      expect(summary.totalWorkingDays, 49); // mỗi điểm = 1 công
      expect(counts[1]!.workingDays, 49);
      expect(summary.txDaysByTransactionPoint['BHX - HCM'], 30);
      expect(summary.txDaysByTransactionPoint['Vị Thanh'], 19);
      await _expectScreensMatch(year: 2026, month: 4);
    });

    test('Case 2 – cùng ngày vừa TX vừa PX ở 2 điểm: 2 công', () async {
      await _addPersonnel(1, 'Trần Văn A');
      await _addTp(1, 'BHX - HCM');
      await _addTp(2, 'Vị Thanh');

      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.tx);
      await _addTk(1, 2, DateTime(2026, 4, 1), DayStatus.px);
      await _addTk(1, 1, DateTime(2026, 4, 2), DayStatus.tx);

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 2: tổng hợp=${summary.totalWorkingDays} công '
          '(PX=${summary.totalPxDays}) | chi tiết=${counts[1]!.workingDays}');

      expect(summary.totalWorkingDays, 3); // TX ngày 1 + PX ngày 1 + TX ngày 2
      expect(summary.totalPxDays, 1);
      expect(counts[1]!.workingDays, 3);
      await _expectScreensMatch(year: 2026, month: 4);
    });

    test('Case 3 – NP ở 2 điểm trong cùng ngày: chỉ tính 1 ngày nghỉ',
        () async {
      await _addPersonnel(1, 'Trần Văn B');
      await _addTp(1, 'BHX - HCM');
      await _addTp(2, 'Vị Thanh');

      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.np);
      await _addTk(1, 2, DateTime(2026, 4, 1), DayStatus.np);

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 3: tổng hợp nghỉ phép=${summary.totalDaysOff} | '
          'chi tiết nghỉ phép=${counts[1]!.phepDays}');

      expect(summary.totalDaysOff, 1);
      expect(counts[1]!.phepDays, 1);
      await _expectScreensMatch(year: 2026, month: 4);
    });
  });

  group('B. Dữ liệu bất thường (restore/backup, dữ liệu cũ)', () {
    test('Case 4 – bản ghi trùng hoàn toàn: chỉ tính 1 công', () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'BHX - HCM');

      await _addTk(1, 1, DateTime(2026, 4, 10), DayStatus.tx);
      await _addTk(1, 1, DateTime(2026, 4, 10), DayStatus.tx);

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 4: tổng hợp=${summary.totalWorkingDays} công | '
          'chi tiết=${counts[1]!.workingDays} công (2 bản ghi trùng)');

      expect(summary.totalWorkingDays, 1);
      expect(counts[1]!.workingDays, 1);
      await _expectScreensMatch(year: 2026, month: 4);
    });

    test('Case 5 – trạng thái cũ "work" (trước migration v7) không tính công',
        () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'BHX - HCM');

      final db = await DatabaseHelper.instance.database;
      await db.insert('timekeeping', {
        'personnel_id': 1,
        'date': '2026-04-01',
        'job_position_id': 1,
        'transaction_point_id': 1,
        'day_status': 'work',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      });

      final summaries = await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      );
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 5: tổng hợp=${summaries.single.totalWorkingDays} công | '
          'chi tiết=${counts[1]?.workingDays ?? 0} công (trạng thái lạ)');

      expect(summaries.length, 1);
      expect(summaries.single.totalWorkingDays, 0);
      expect(details.length, 1); // vẫn hiện để người dùng thấy và sửa
      expect(counts[1]?.workingDays ?? 0, 0);
    });
  });

  group('C. Các trường hợp biên khác', () {
    test('Case 6 – ranh giới tháng: không lẫn dữ liệu tháng khác', () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'BHX - HCM');

      await _addTk(1, 1, DateTime(2026, 3, 31), DayStatus.tx);
      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.tx);
      await _addTk(1, 1, DateTime(2026, 4, 2), DayStatus.tx);

      final april = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final march = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 3,
      ))
          .single;

      print('Case 6: tháng 4=${april.totalWorkingDays} công, '
          'tháng 3=${march.totalWorkingDays} công');

      expect(april.totalWorkingDays, 2);
      expect(march.totalWorkingDays, 1);
      await _expectScreensMatch(year: 2026, month: 4);
      await _expectScreensMatch(year: 2026, month: 3);
    });

    test('Case 7 – thiếu job_positions: chi tiết vẫn hiện đủ dữ liệu',
        () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'BHX - HCM');
      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.tx,
          jobPositionId: 99); // job position không tồn tại

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 7: tổng hợp=${summary.totalWorkingDays} công | '
          'chi tiết=${details.length} dòng');

      expect(summary.totalWorkingDays, 1);
      expect(details.length, 1); // không còn bị INNER JOIN làm rơi
      expect(counts[1]!.workingDays, 1);
      await _expectScreensMatch(year: 2026, month: 4);
    });

    test('Case 8 – nhiều nhân sự và lọc theo nhân sự', () async {
      await _addPersonnel(1, 'Trần Văn A');
      await _addPersonnel(2, 'Lê Thị B', role: 'PX');
      await _addTp(1, 'BHX - HCM');
      await _addTp(2, 'Vị Thanh');

      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.tx);
      await _addTk(1, 2, DateTime(2026, 4, 1), DayStatus.tx);
      await _addTk(2, 1, DateTime(2026, 4, 1), DayStatus.px);

      final all = await DatabaseHelper.instance
          .getTimekeepingSummary(year: 2026, month: 4);
      final onlyP1 = await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
        personnelId: 1,
      );
      final detailsP1 = await DatabaseHelper.instance.getTimekeepingDetail(
        year: 2026,
        month: 4,
        personnelId: 1,
      );
      final countsP1 = countTimekeepingByPersonnel(detailsP1);

      print('Case 8: tất cả=${all.map((s) => '${s.personnelName}:${s.totalWorkingDays}').toList()} | '
          'lọc p1=${onlyP1.single.totalWorkingDays} công | '
          'chi tiết p1=${countsP1[1]!.workingDays} công');

      expect(all.length, 2);
      expect(all.map((s) => s.totalWorkingDays).reduce((a, b) => a + b), 3);
      expect(onlyP1.single.totalWorkingDays, 2);
      expect(countsP1[1]!.workingDays, 2);
      await _expectScreensMatch(year: 2026, month: 4);
    });

    test('Case 10 – 2 điểm giao dịch trùng tên: tổng công vẫn đếm theo điểm',
        () async {
      await _addPersonnel(1, 'Nguyễn Hoàng Nhân');
      await _addTp(1, 'Trùng tên');
      await _addTp(2, 'Trùng tên');

      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.tx);
      await _addTk(1, 2, DateTime(2026, 4, 1), DayStatus.tx);

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);
      final counts = countTimekeepingByPersonnel(details);

      print('Case 10: tổng hợp=${summary.totalWorkingDays} công | '
          'chi tiết=${counts[1]!.workingDays} công | '
          'cột theo tên gộp=${summary.txDaysByTransactionPoint}');

      expect(summary.totalWorkingDays, 2);
      expect(counts[1]!.workingDays, 2);
      // Cột hiển thị theo tên bị gộp (hạn chế có từ trước) nhưng tổng vẫn đúng
      expect(summary.txDaysByTransactionPoint['Trùng tên'], 1);
    });

    test('Case 9 – nhân viên đã nghỉ vẫn lên cả 2 báo cáo', () async {
      await _addPersonnel(1, 'Nguyễn Văn Nghỉ', isWorking: false);
      await _addTp(1, 'BHX - HCM');
      await _addTk(1, 1, DateTime(2026, 4, 1), DayStatus.tx);

      final summary = (await DatabaseHelper.instance.getTimekeepingSummary(
        year: 2026,
        month: 4,
      ))
          .single;
      final details = await DatabaseHelper.instance
          .getTimekeepingDetail(year: 2026, month: 4);

      print('Case 9: đã nghỉ isWorking=${summary.isWorking} | '
          'tổng hợp=${summary.totalWorkingDays} công | '
          'chi tiết=${details.length} dòng');

      expect(summary.isWorking, false);
      expect(summary.totalWorkingDays, 1);
      expect(details.single.personnelIsWorking, false);
      await _expectScreensMatch(year: 2026, month: 4);
    });
  });

  group('D. Đơn vị đếm countTimekeepingByPersonnel', () {
    TimekeepingDetail detail({
      int personnelId = 1,
      int tpId = 1,
      required DateTime date,
      String status = DayStatus.tx,
    }) {
      return TimekeepingDetail(
        timekeepingId: 0,
        personnelId: personnelId,
        personnelName: 'Test',
        date: date,
        transactionPointId: tpId,
        transactionPointName: 'TP$tpId',
        dayStatus: status,
      );
    }

    test('cùng ngày khác điểm = nhiều công; trùng hoàn toàn = 1 công',
        () async {
      final counts = countTimekeepingByPersonnel([
        detail(date: DateTime(2026, 4, 1), tpId: 1, status: DayStatus.tx),
        detail(date: DateTime(2026, 4, 1), tpId: 2, status: DayStatus.tx),
        detail(date: DateTime(2026, 4, 1), tpId: 1, status: DayStatus.tx), // trùng
        detail(date: DateTime(2026, 4, 2), tpId: 1, status: DayStatus.px),
        detail(date: DateTime(2026, 4, 2), tpId: 1, status: DayStatus.tx), // khác status
        detail(date: DateTime(2026, 4, 3), tpId: 1, status: DayStatus.np),
        detail(date: DateTime(2026, 4, 3), tpId: 2, status: DayStatus.np),
      ]);

      print('Case D: working=${counts[1]!.workingDays}, '
          'phep=${counts[1]!.phepDays}');

      expect(counts[1]!.workingDays, 4); // (1,1,TX), (1,2,TX), (2,1,PX), (2,1,TX)
      expect(counts[1]!.phepDays, 1); // NP 2 điểm cùng ngày
      expect(counts[1]!.kphepDays, 0);
    });
  });
}
