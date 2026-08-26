import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';
import '../state/app_state.dart';
import '../widgets/compact_date_range_picker.dart';

class TimekeepingScreen extends StatefulWidget {
  const TimekeepingScreen({super.key});

  @override
  State<TimekeepingScreen> createState() => _TimekeepingScreenState();
}

class _TimekeepingScreenState extends State<TimekeepingScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  String _searchEmployeeQuery = '';
  final TextEditingController _searchEmployeeController = TextEditingController();

  List<Personnel> _personnelList = [];
  List<TransactionPoint> _transactionPoints = [];

  // Mapping: PersonnelId -> TransactionPointId -> DateString (yyyy-MM-dd) -> Status
  Map<int, Map<int, Map<String, String>>> _dataMap = {};
  
  int? _selectedFilterTpId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    AppState.instance.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    AppState.instance.dataVersion.removeListener(_onDataChanged);
    _searchEmployeeController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    final personnel = await _db.getAllPersonnel(activeOnly: true, workingOnly: true);
    final points = await _db.getAllTransactionPoints();
    if (mounted) {
      setState(() {
        _personnelList = personnel;
        _transactionPoints = points;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _personnelList = await _db.getAllPersonnel(activeOnly: true, workingOnly: true);
    _transactionPoints = await _db.getAllTransactionPoints();

    await _loadTimekeepingData();

    setState(() => _isLoading = false);
  }

  Future<void> _loadTimekeepingData() async {
    final timekeepings = await _db.getTimekeepingByDateRange(
      startDate: _startDate,
      endDate: _endDate,
    );

    _dataMap.clear();

    for (var tk in timekeepings) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tk.date);
      _dataMap.putIfAbsent(tk.personnelId, () => {});
      _dataMap[tk.personnelId]!.putIfAbsent(tk.transactionPointId, () => {});
      _dataMap[tk.personnelId]![tk.transactionPointId]![dateKey] = tk.dayStatus;
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _db.deleteTimekeepingByDateRange(
        startDate: _startDate,
        endDate: _endDate,
      );

      List<Timekeeping> newRecords = [];
      final sStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final eStr = DateFormat('yyyy-MM-dd').format(_endDate);

      _dataMap.forEach((personnelId, tpMap) {
        tpMap.forEach((tpId, daysMap) {
          daysMap.forEach((dateKey, status) {
            if (dateKey.compareTo(sStr) >= 0 && dateKey.compareTo(eStr) <= 0) {
              newRecords.add(Timekeeping(
                personnelId: personnelId,
                date: DateTime.parse(dateKey),
                transactionPointId: tpId,
                createdAt: DateTime.now(),
                dayStatus: status,
              ));
            }
          });
        });
      });

      if (newRecords.isNotEmpty) {
        await _db.insertMultipleTimekeeping(newRecords);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu dữ liệu chấm công thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final days = _daysInRange;
      final personnelToExport = _filteredPersonnelList;

      if (personnelToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có dữ liệu nhân viên nào để xuất Excel.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final excel = xls.Excel.createExcel();
      final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Bang cham cong');
      final sheet = excel['Bang cham cong'];

      // CellStyles
      final headerStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.blue,
        fontColorHex: xls.ExcelColor.white,
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final bodyStyle = xls.CellStyle(
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final centerBodyStyle = xls.CellStyle(
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final txStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#BBDEFB'),
        fontColorHex: xls.ExcelColor.fromHexString('#0D47A1'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final pxStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#B2EBF2'),
        fontColorHex: xls.ExcelColor.fromHexString('#006064'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final npStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#FFE0B2'),
        fontColorHex: xls.ExcelColor.fromHexString('#E65100'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final kpStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#FFCDD2'),
        fontColorHex: xls.ExcelColor.fromHexString('#B71C1C'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      );

      final totalRowStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#EEEEEE'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Medium),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Medium),
      );

      final totalRowLeftStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#EEEEEE'),
        horizontalAlign: xls.HorizontalAlign.Left,
        verticalAlign: xls.VerticalAlign.Center,
        leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
        topBorder: xls.Border(borderStyle: xls.BorderStyle.Medium),
        bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Medium),
      );

      // Headers
      final headers = ['STT', 'Tên nhân viên', 'Vai trò', 'Điểm GD'];
      final colWidths = [6.0, 24.0, 14.0, 18.0];
      final weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

      for (var d in days) {
        final dayStr = DateFormat('dd/MM').format(d);
        final wStr = weekdayLabels[d.weekday - 1];
        headers.add('$dayStr\n$wStr');
        colWidths.add(7.0);
      }

      headers.addAll(['Tổng TX', 'Tổng PX', 'Tổng NP', 'Tổng KP', 'Tổng Ngày Công']);
      colWidths.addAll([10.0, 10.0, 10.0, 10.0, 15.0]);

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidth(i, colWidths[i]);
      }

      int rowIndex = 1;
      int stt = 1;

      int grandTotalTx = 0;
      int grandTotalPx = 0;
      int grandTotalNp = 0;
      int grandTotalKp = 0;
      int grandTotalWork = 0;
      Map<int, int> grandDailyTx = {};
      Map<int, int> grandDailyPx = {};
      Map<int, int> grandDailyNp = {};
      Map<int, int> grandDailyKp = {};

      for (var personnel in personnelToExport) {
        final pId = personnel.id!;
        final pName = personnel.name;
        final pRole = personnel.role == 'TX'
            ? 'Tài xế'
            : (personnel.role == 'PX' ? 'Phụ xe' : 'Chưa gán');

        List<TransactionPoint> pointsToDisplay = [];
        if (_selectedFilterTpId != null) {
          pointsToDisplay = _transactionPoints.where((tp) => tp.id == _selectedFilterTpId).toList();
        } else {
          final userTpMap = _dataMap[pId];
          if (userTpMap != null && userTpMap.isNotEmpty) {
            pointsToDisplay = _transactionPoints.where((tp) => userTpMap.containsKey(tp.id)).toList();
          }
          if (pointsToDisplay.isEmpty) {
            pointsToDisplay = _transactionPoints;
          }
        }

        if (pointsToDisplay.isEmpty) {
          pointsToDisplay = [TransactionPoint(id: 0, name: 'Mặc định', createdAt: DateTime.now())];
        }

        for (var tp in pointsToDisplay) {
          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            ..value = xls.TextCellValue('$stt')
            ..cellStyle = centerBodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            ..value = xls.TextCellValue(pName)
            ..cellStyle = bodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            ..value = xls.TextCellValue(pRole)
            ..cellStyle = centerBodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            ..value = xls.TextCellValue(tp.name)
            ..cellStyle = bodyStyle;

          int rowTx = 0;
          int rowPx = 0;
          int rowNp = 0;
          int rowKp = 0;

          for (int dIdx = 0; dIdx < days.length; dIdx++) {
            final day = days[dIdx];
            final dateKey = DateFormat('yyyy-MM-dd').format(day);
            final status = _dataMap[pId]?[tp.id]?[dateKey];

            final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4 + dIdx, rowIndex: rowIndex));

            if (status == DayStatus.tx) {
              cell.value = xls.TextCellValue('TX');
              cell.cellStyle = txStyle;
              rowTx++;
              grandDailyTx[dIdx] = (grandDailyTx[dIdx] ?? 0) + 1;
            } else if (status == DayStatus.px) {
              cell.value = xls.TextCellValue('PX');
              cell.cellStyle = pxStyle;
              rowPx++;
              grandDailyPx[dIdx] = (grandDailyPx[dIdx] ?? 0) + 1;
            } else if (status == DayStatus.np) {
              cell.value = xls.TextCellValue('NP');
              cell.cellStyle = npStyle;
              rowNp++;
              grandDailyNp[dIdx] = (grandDailyNp[dIdx] ?? 0) + 1;
            } else if (status == DayStatus.kp) {
              cell.value = xls.TextCellValue('KP');
              cell.cellStyle = kpStyle;
              rowKp++;
              grandDailyKp[dIdx] = (grandDailyKp[dIdx] ?? 0) + 1;
            } else {
              cell.value = xls.TextCellValue('');
              cell.cellStyle = centerBodyStyle;
            }
          }

          final rowTotalWork = rowTx + rowPx;

          grandTotalTx += rowTx;
          grandTotalPx += rowPx;
          grandTotalNp += rowNp;
          grandTotalKp += rowKp;
          grandTotalWork += rowTotalWork;

          int colIdx = 4 + days.length;
          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIndex))
            ..value = xls.IntCellValue(rowTx)
            ..cellStyle = centerBodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIndex))
            ..value = xls.IntCellValue(rowPx)
            ..cellStyle = centerBodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIndex))
            ..value = xls.IntCellValue(rowNp)
            ..cellStyle = centerBodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIndex))
            ..value = xls.IntCellValue(rowKp)
            ..cellStyle = centerBodyStyle;

          sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: colIdx++, rowIndex: rowIndex))
            ..value = xls.IntCellValue(rowTotalWork)
            ..cellStyle = centerBodyStyle;

          rowIndex++;
          stt++;
        }
      }

      // Grand Total Row
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = xls.TextCellValue('')
        ..cellStyle = totalRowStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
        ..value = xls.TextCellValue('TỔNG CỘNG')
        ..cellStyle = totalRowLeftStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
        ..value = xls.TextCellValue('')
        ..cellStyle = totalRowStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
        ..value = xls.TextCellValue('')
        ..cellStyle = totalRowStyle;

      for (int dIdx = 0; dIdx < days.length; dIdx++) {
        final totalDayWork = (grandDailyTx[dIdx] ?? 0) + (grandDailyPx[dIdx] ?? 0);
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4 + dIdx, rowIndex: rowIndex))
          ..value = xls.IntCellValue(totalDayWork)
          ..cellStyle = totalRowStyle;
      }

      int sumColIdx = 4 + days.length;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: sumColIdx++, rowIndex: rowIndex))
        ..value = xls.IntCellValue(grandTotalTx)
        ..cellStyle = totalRowStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: sumColIdx++, rowIndex: rowIndex))
        ..value = xls.IntCellValue(grandTotalPx)
        ..cellStyle = totalRowStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: sumColIdx++, rowIndex: rowIndex))
        ..value = xls.IntCellValue(grandTotalNp)
        ..cellStyle = totalRowStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: sumColIdx++, rowIndex: rowIndex))
        ..value = xls.IntCellValue(grandTotalKp)
        ..cellStyle = totalRowStyle;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: sumColIdx++, rowIndex: rowIndex))
        ..value = xls.IntCellValue(grandTotalWork)
        ..cellStyle = totalRowStyle;

      final fileBytes = excel.save();
      if (fileBytes == null) return;

      final fromDateStr = DateFormat('yyyyMMdd').format(_startDate);
      final toDateStr = DateFormat('yyyyMMdd').format(_endDate);
      String defaultFileName = 'bang_cham_cong_${fromDateStr}_$toDateStr.xlsx';

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn nơi lưu bảng chấm công',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.toLowerCase().endsWith('.xlsx')) {
          outputFile += '.xlsx';
        }
        final file = File(outputFile);
        await file.writeAsBytes(fileBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xuất file Excel thành công: $outputFile'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xuất file Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<DateTime> get _daysInRange {
    List<DateTime> days = [];
    DateTime current = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!current.isAfter(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  void _cycleStatus(int pId, int tpId, String dateKey) {
    setState(() {
      _dataMap.putIfAbsent(pId, () => {});
      _dataMap[pId]!.putIfAbsent(tpId, () => {});

      final current = _dataMap[pId]![tpId]![dateKey];
      if (current == null) {
        _dataMap[pId]![tpId]![dateKey] = DayStatus.tx;
      } else if (current == DayStatus.tx) {
        _dataMap[pId]![tpId]![dateKey] = DayStatus.px;
      } else if (current == DayStatus.px) {
        _dataMap[pId]![tpId]![dateKey] = DayStatus.np;
      } else if (current == DayStatus.np) {
        _dataMap[pId]![tpId]![dateKey] = DayStatus.kp;
      } else {
        _dataMap[pId]![tpId]!.remove(dateKey);
      }
    });
  }

  Widget _buildDayCell(int pId, int tpId, String dateKey) {
    final status = _dataMap[pId]?[tpId]?[dateKey];

    if (status == null) {
      return InkWell(
        onTap: () => _cycleStatus(pId, tpId, dateKey),
        borderRadius: BorderRadius.circular(4),
        child: const SizedBox(width: 32, height: 28),
      );
    }

    Color bgColor;
    Color textColor;
    String label;
    String tooltip;

    switch (status) {
      case DayStatus.tx:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'TX';
        tooltip = 'Tài xế';
        break;
      case DayStatus.px:
        bgColor = Colors.cyan.shade100;
        textColor = Colors.cyan.shade900;
        label = 'PX';
        tooltip = 'Phụ xe';
        break;
      case DayStatus.np:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        label = 'NP';
        tooltip = 'Nghỉ phép';
        break;
      case DayStatus.kp:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        label = 'KP';
        tooltip = 'Kh.Phép';
        break;
      default:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'TX';
        tooltip = 'Tài xế';
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _cycleStatus(pId, tpId, dateKey),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 24,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  List<Personnel> get _filteredPersonnelList {
    return _personnelList.where((p) {
      if (_searchEmployeeQuery.isNotEmpty) {
        final q = _searchEmployeeQuery.toLowerCase();
        if (!p.name.toLowerCase().contains(q)) return false;
      }
      if (_selectedFilterTpId != null) {
        final tpMap = _dataMap[p.id];
        if (tpMap == null || !tpMap.containsKey(_selectedFilterTpId!)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInRange;

    return Scaffold(
      body: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Single Compact Date Range Picker Input
                    CompactDateRangePicker(
                      startDate: _startDate,
                      endDate: _endDate,
                      onDateRangeChanged: (start, end) async {
                        setState(() {
                          _startDate = start;
                          _endDate = end;
                          _isLoading = true;
                        });
                        await _loadTimekeepingData();
                        setState(() => _isLoading = false);
                      },
                    ),
                    const SizedBox(width: 12),
                    // Employee Filter Input
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _searchEmployeeController,
                        decoration: InputDecoration(
                          labelText: 'Tìm tên NV...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixIcon: _searchEmployeeQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchEmployeeController.clear();
                                    setState(() => _searchEmployeeQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchEmployeeQuery = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: DropdownButton<int?>(
                        value: _selectedFilterTpId,
                        hint: const Text('Lọc theo điểm GD'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tất cả Điểm GD'),
                          ),
                          ..._transactionPoints.map((tp) => DropdownMenuItem<int?>(
                                value: tp.id,
                                child: Text(tp.name),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilterTpId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Legend
                    _StatusBadge(
                      color: Colors.blue.shade100,
                      textColor: Colors.blue.shade800,
                      label: 'TX',
                      tooltip: 'Tài xế',
                    ),
                    const SizedBox(width: 4),
                    _StatusBadge(
                      color: Colors.cyan.shade100,
                      textColor: Colors.cyan.shade900,
                      label: 'PX',
                      tooltip: 'Phụ xe',
                    ),
                    const SizedBox(width: 4),
                    _StatusBadge(
                      color: Colors.orange.shade100,
                      textColor: Colors.orange.shade900,
                      label: 'NP',
                      tooltip: 'Nghỉ Phép',
                    ),
                    const SizedBox(width: 4),
                    _StatusBadge(
                      color: Colors.red.shade100,
                      textColor: Colors.red.shade900,
                      label: 'KP',
                      tooltip: 'Nghỉ Không Phép',
                    ),
                    const SizedBox(width: 8),
                    Text('← Click để đổi trạng thái',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 16),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton.icon(
                        onPressed: _saveData,
                        icon: const Icon(Icons.save, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        label: const Text('Lưu toàn bộ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton.icon(
                        onPressed: _exportToExcel,
                        icon: const Icon(Icons.file_download, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        label: const Text('Xuất Excel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _personnelList.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có nhân sự nào đang làm việc.',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                    : _filteredPersonnelList.isEmpty
                        ? Center(
                            child: Text(
                              'Không tìm thấy nhân sự phù hợp.',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredPersonnelList.length,
                            itemBuilder: (context, index) {
                              final personnel = _filteredPersonnelList[index];
                              int totalDays = 0;
                              _dataMap[personnel.id!]?.forEach((_, map) {
                                totalDays += map.length;
                              });

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ExpansionTile(
                                  title: Text(
                                    personnel.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: personnel.role == 'TX' ? 'Tài xế' : (personnel.role == 'PX' ? 'Phụ xe' : 'Chưa gán vai trò'),
                                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                        ),
                                        TextSpan(
                                          text: '  •  $totalDays ngày công đã ghi',
                                          style: TextStyle(color: Colors.blue[600], fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ]
                                    )
                                  ),
                                  children: [
                                    if (_transactionPoints.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text('Chưa có điểm giao dịch nào.'),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            border: TableBorder.all(color: Colors.grey.shade300),
                                            columnSpacing: 4,
                                            dataRowMinHeight: 36,
                                            dataRowMaxHeight: 44,
                                            headingRowHeight: 36,
                                            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                                            columns: [
                                              const DataColumn(
                                                  label: Text('Điểm GD',
                                                      style: TextStyle(fontWeight: FontWeight.bold))),
                                              ...days.map((date) {
                                                final isWeekend = date.weekday == DateTime.sunday;
                                                return DataColumn(
                                                  label: Text(
                                                    '${date.day}/${date.month}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isWeekend ? Colors.red : null,
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                            rows: _transactionPoints.map((tp) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 100),
                                                      child: Text(tp.name, 
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)
                                                      )
                                                    )
                                                  ),
                                                  ...days.map((date) {
                                                    final dateKey = DateFormat('yyyy-MM-dd').format(date);
                                                    return DataCell(
                                                      _buildDayCell(personnel.id!, tp.id!, dateKey)
                                                    );
                                                  }),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final Color textColor;
  final String label;
  final String tooltip;

  const _StatusBadge({
    required this.color,
    required this.textColor,
    required this.label,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 28,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

