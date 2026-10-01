import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/timekeeping.dart';
import '../state/app_state.dart';
import '../utils/timekeeping_counts.dart';
import '../widgets/compact_date_range_picker.dart';

class TimekeepingDetailScreen extends StatefulWidget {
  const TimekeepingDetailScreen({super.key});

  @override
  State<TimekeepingDetailScreen> createState() =>
      _TimekeepingDetailScreenState();
}

class _TimekeepingDetailScreenState extends State<TimekeepingDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  int? _selectedPersonnelId;

  String _searchEmployeeQuery = '';
  final TextEditingController _searchEmployeeController = TextEditingController();

  List<Personnel> _personnelList = [];
  List<TimekeepingDetail> _details = [];
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _personnelList = await _db.getAllPersonnel(activeOnly: true, workingOnly: false);
    await _loadDetails();
    setState(() => _isLoading = false);
  }

  Future<void> _loadDetails() async {
    _details = await _db.getTimekeepingDetail(
      startDate: _startDate,
      endDate: _endDate,
      personnelId: _selectedPersonnelId,
    );
  }

  Map<int, Map<DateTime, List<TimekeepingDetail>>> _groupByPersonnel() {
    Map<int, Map<DateTime, List<TimekeepingDetail>>> grouped = {};
    for (var detail in _details) {
      if (_searchEmployeeQuery.isNotEmpty) {
        final q = _searchEmployeeQuery.toLowerCase();
        if (!detail.personnelName.toLowerCase().contains(q)) continue;
      }
      grouped.putIfAbsent(detail.personnelId, () => {});
      final dateKey = DateTime(
        detail.date.year,
        detail.date.month,
        detail.date.day,
      );
      grouped[detail.personnelId]!.putIfAbsent(dateKey, () => []);
      grouped[detail.personnelId]![dateKey]!.add(detail);
    }
    return grouped;
  }

  Widget _buildStatusChip(String dayStatus) {
    switch (dayStatus) {
      case DayStatus.tx:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Tài xế',
            style: TextStyle(
              color: Colors.blue.shade800,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case DayStatus.px:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.cyan.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Phụ xe',
            style: TextStyle(
              color: Colors.cyan.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case DayStatus.np:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Nghỉ Phép',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case DayStatus.kp:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Nghỉ K Phép',
            style: TextStyle(
              color: Colors.red.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Không xác định',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }

  String _dayStatusLabel(String status) {
    switch (status) {
      case DayStatus.tx:
        return 'Tài xế';
      case DayStatus.px:
        return 'Phụ xe';
      case DayStatus.np:
        return 'Nghỉ Phép';
      case DayStatus.kp:
        return 'Nghỉ K Phép';
      default:
        return 'Không xác định';
    }
  }

  String _formatDate(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  Future<void> _exportToExcel() async {
    final excel = xls.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Chi tiet cham cong');
    final sheet = excel['Chi tiet cham cong'];

    xls.CellStyle headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.blue,
      fontColorHex: xls.ExcelColor.white,
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );
    xls.CellStyle workStyle = xls.CellStyle(
      backgroundColorHex: xls.ExcelColor.fromHexString('#E3F2FD'), // light blue
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );
    xls.CellStyle phepStyle = xls.CellStyle(
      backgroundColorHex: xls.ExcelColor.fromHexString('#FFF3E0'), // light orange
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );
    xls.CellStyle kphepStyle = xls.CellStyle(
      backgroundColorHex: xls.ExcelColor.fromHexString('#FFEBEE'), // light red
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );
    xls.CellStyle subHeaderStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#E8EAF6'),
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );

    final headers = ['STT', 'Tên nhân viên', 'Ngày', 'Thứ', 'Trạng thái', 'Điểm GD'];
    final colWidths = [6.0, 25.0, 14.0, 10.0, 15.0, 20.0];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = xls.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(i, colWidths[i]);
    }

    final grouped = _groupByPersonnel();
    int rowIndex = 1;
    int stt = 1;

    grouped.forEach((personnelId, dateMap) {
      final firstDetail = _details.firstWhere((d) => d.personnelId == personnelId);
      final personnelName = firstDetail.personnelName;
      final isWorking = firstDetail.personnelIsWorking;

      // Personnel sub-header row
      final sttCell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      sttCell.value = xls.TextCellValue('');
      sttCell.cellStyle = subHeaderStyle;
      final nameCell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      nameCell.value = xls.TextCellValue(
          personnelName + (isWorking ? '' : ' [Đã nghỉ]'));
      nameCell.cellStyle = subHeaderStyle;
      for (int c = 2; c < 6; c++) {
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex))
          ..value = xls.TextCellValue('')
          ..cellStyle = subHeaderStyle;
      }
      rowIndex++;

      dateMap.forEach((date, records) {
        for (final r in records) {
          xls.CellStyle rowStyle;
          switch (r.dayStatus) {
            case DayStatus.np:
              rowStyle = phepStyle;
              break;
            case DayStatus.kp:
              rowStyle = kphepStyle;
              break;
            default:
              rowStyle = workStyle;
          }

          void setCell(int col, String val) {
            sheet.cell(xls.CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: rowIndex))
              ..value = xls.TextCellValue(val)
              ..cellStyle = rowStyle;
          }

          setCell(0, '$stt');
          setCell(1, r.personnelName);
          setCell(2, _formatDate(r.date));
          setCell(3, _getWeekdayName(r.date.weekday));
          setCell(4, _dayStatusLabel(r.dayStatus));
          setCell(5, (r.dayStatus == DayStatus.tx || r.dayStatus == DayStatus.px) ? r.transactionPointName : '');

          stt++;
          rowIndex++;
        }
      });
    });

    final sName = DateFormat('ddMM').format(_startDate);
    final eName = DateFormat('ddMM_yyyy').format(_endDate);

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel',
      fileName:
          'Chi_tiet_cham_cong_${sName}_den_${eName}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputPath != null) {
      final fileBytes = excel.save();
      if (fileBytes != null) {
        await File(outputPath).writeAsBytes(fileBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Xuất file Excel thành công!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Mở file',
                textColor: Colors.white,
                onPressed: () => _openFile(outputPath),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final groupedByPersonnel = _groupByPersonnel();
    final countsByPersonnel = countTimekeepingByPersonnel(_details);

    return Scaffold(
      body: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      await _loadDetails();
                      setState(() => _isLoading = false);
                    },
                  ),
                  const SizedBox(width: 16),
                  // Employee Search Text Field
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
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int?>(
                      value: _selectedPersonnelId,
                      decoration: const InputDecoration(
                        labelText: 'Nhân sự',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tất cả'),
                        ),
                        ..._personnelList.map((p) {
                          final isResigned = !p.isWorking;
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name + (isResigned ? ' [Đã nghỉ]' : ''),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isResigned
                                    ? Colors.grey.shade500
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) async {
                        setState(() {
                          _selectedPersonnelId = value;
                          _isLoading = true;
                        });
                        await _loadDetails();
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        await _loadDetails();
                        setState(() => _isLoading = false);
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Tìm kiếm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: _details.isEmpty ? null : _exportToExcel,
                      icon: const Icon(Icons.download),
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
                : _details.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có dữ liệu chấm công',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: groupedByPersonnel.length,
                        itemBuilder: (context, index) {
                          final personnelId =
                              groupedByPersonnel.keys.elementAt(index);
                          final dateMap = groupedByPersonnel[personnelId]!;
                          final firstDetail = _details
                              .firstWhere((d) => d.personnelId == personnelId);
                          final personnelName = firstDetail.personnelName;
                          final isResigned = !firstDetail.personnelIsWorking;

                          // Số công/số ngày nghỉ — dùng chung logic với màn tổng hợp
                          final counts = countsByPersonnel[personnelId] ??
                              const TimekeepingCounts();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: isResigned
                                    ? Colors.grey.shade300
                                    : Theme.of(context).primaryColor,
                                child: Text(
                                  personnelName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: isResigned
                                        ? Colors.grey.shade600
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    personnelName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isResigned
                                          ? Colors.grey.shade500
                                          : null,
                                    ),
                                  ),
                                  if (isResigned) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.grey.shade400),
                                      ),
                                      child: Text(
                                        'Đã nghỉ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Text('Số công: ${counts.workingDays}',
                                      style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 12)),
                                  if (counts.phepDays > 0) ...[
                                    const SizedBox(width: 8),
                                    Text('Nghỉ phép: ${counts.phepDays}',
                                        style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontSize: 12)),
                                  ],
                                  if (counts.kphepDays > 0) ...[
                                    const SizedBox(width: 8),
                                    Text('K phép: ${counts.kphepDays}',
                                        style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 12)),
                                  ],
                                ],
                              ),
                              children: dateMap.entries.map((entry) {
                                final date = entry.key;
                                final records = entry.value;
                                final weekday =
                                    _getWeekdayName(date.weekday);

                                return ListTile(
                                  title: Text(
                                    '$weekday, ${DateFormat('dd/MM/yyyy').format(date)}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: records.map((r) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            _buildStatusChip(r.dayStatus),
                                            if (r.dayStatus == DayStatus.tx || r.dayStatus == DayStatus.px) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                r.transactionPointName, // No longer need job position
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  isThreeLine: records.length > 1,
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return '';
    }
  }
}
