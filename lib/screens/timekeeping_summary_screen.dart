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

class TimekeepingSummaryScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const TimekeepingSummaryScreen({super.key, this.onNavigate});

  @override
  State<TimekeepingSummaryScreen> createState() =>
      _TimekeepingSummaryScreenState();
}

class _TimekeepingSummaryScreenState extends State<TimekeepingSummaryScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  int? _selectedPersonnelId;

  List<Personnel> _personnelList = [];
  List<TransactionPoint> _transactionPoints = [];
  List<TimekeepingSummary> _summaries = [];
  bool _isLoading = true;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    AppState.instance.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    AppState.instance.dataVersion.removeListener(_onDataChanged);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _personnelList = await _db.getAllPersonnel(activeOnly: true, workingOnly: false);
      _transactionPoints = await _db.getAllTransactionPoints();
      await _loadSummary();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu chấm công: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      print('Load summary error: $e\n$st');
    }
  }

  Future<void> _loadSummary() async {
    _summaries = await _db.getTimekeepingSummary(
      startDate: _startDate,
      endDate: _endDate,
      personnelId: _selectedPersonnelId,
    );
  }

  List<TimekeepingSummary> get _filteredSummaries {
    if (_searchQuery.isEmpty) return _summaries;
    final q = _searchQuery.toLowerCase();
    return _summaries
        .where((s) => s.personnelName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _exportToExcel() async {
    final excel = xls.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Cham cong tong hop');
    final sheet = excel['Cham cong tong hop'];

    final headers = ['STT', 'Tên nhân viên', 'Vai trò'];
    final colWidths = [6.0, 25.0, 15.0];
    
    for (var tp in _transactionPoints) {
      headers.add('TX\n${tp.name}');
      colWidths.add(15.0);
    }
    
    headers.addAll(['Tổng PX', 'Tổng ngày làm', 'Tổng nghỉ', 'N.Phép', 'K.Phép']);
    colWidths.addAll([12.0, 15.0, 12.0, 10.0, 10.0]);

    xls.CellStyle headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.blue,
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );
    xls.CellStyle bodyStyle = xls.CellStyle(
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = xls.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(i, colWidths[i]);
    }

    int grandTotalPxDays = 0;
    int grandTotalWorkingDays = 0;
    int grandTotalOff = 0;
    int grandTotalUnauth = 0;
    Map<String, int> grandTotalTxTpDays = {};

    final list = _filteredSummaries;
    for (int i = 0; i < list.length; i++) {
      final summary = list[i];
      final rowIndex = i + 1;
      
      grandTotalPxDays += summary.totalPxDays;
      grandTotalWorkingDays += summary.totalWorkingDays;
      grandTotalOff += summary.totalDaysOff;
      grandTotalUnauth += summary.totalDaysUnauth;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = xls.TextCellValue('${i + 1}')
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
        ..value = xls.TextCellValue(summary.personnelName)
        ..cellStyle = bodyStyle;
        
      String roleStr = summary.personnelRole == 'TX' ? 'Tài xế' : (summary.personnelRole == 'PX' ? 'Phụ xe' : '');
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
        ..value = xls.TextCellValue(roleStr)
        ..cellStyle = bodyStyle;

      for (int j = 0; j < _transactionPoints.length; j++) {
        final tpName = _transactionPoints[j].name;
        final days = summary.txDaysByTransactionPoint[tpName] ?? 0;
        grandTotalTxTpDays[tpName] = (grandTotalTxTpDays[tpName] ?? 0) + days;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: j + 3, rowIndex: rowIndex))
          ..value = xls.IntCellValue(days)
          ..cellStyle = bodyStyle;
      }

      int offset = _transactionPoints.length + 3;
      
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: offset, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalPxDays)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: offset + 1, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalWorkingDays)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: offset + 2, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalDaysOff + summary.totalDaysUnauth)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: offset + 3, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalDaysOff)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: offset + 4, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalDaysUnauth)
        ..cellStyle = bodyStyle;
    }

    // Totals row
    final totalsRowIndex = list.length + 1;
    _setExcelCell(sheet, 0, totalsRowIndex, xls.TextCellValue(''), headerStyle);
    _setExcelCell(sheet, 1, totalsRowIndex, xls.TextCellValue('Tổng cộng'), headerStyle);
    _setExcelCell(sheet, 2, totalsRowIndex, xls.TextCellValue(''), headerStyle);

    for (int j = 0; j < _transactionPoints.length; j++) {
      final tpName = _transactionPoints[j].name;
      _setExcelCell(sheet, j + 3, totalsRowIndex,
          xls.IntCellValue(grandTotalTxTpDays[tpName] ?? 0), headerStyle);
    }
    
    int totalsOffset = _transactionPoints.length + 3;
    _setExcelCell(sheet, totalsOffset, totalsRowIndex, xls.IntCellValue(grandTotalPxDays), headerStyle);
    _setExcelCell(sheet, totalsOffset + 1, totalsRowIndex, xls.IntCellValue(grandTotalWorkingDays), headerStyle);
    _setExcelCell(sheet, totalsOffset + 2, totalsRowIndex, xls.IntCellValue(grandTotalOff + grandTotalUnauth), headerStyle);
    _setExcelCell(sheet, totalsOffset + 3, totalsRowIndex, xls.IntCellValue(grandTotalOff), headerStyle);
    _setExcelCell(sheet, totalsOffset + 4, totalsRowIndex, xls.IntCellValue(grandTotalUnauth), headerStyle);

    final sName = DateFormat('ddMM').format(_startDate);
    final eName = DateFormat('ddMM_yyyy').format(_endDate);

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel',
      fileName:
          'Cham_cong_tong_hop_${sName}_den_${eName}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputPath != null) {
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(outputPath);
        await file.writeAsBytes(fileBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Xuất file Excel thành công!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Mở file',
                textColor: Colors.white,
                onPressed: () {
                  _openFile(outputPath);
                },
              ),
            ),
          );
        }
      }
    }
  }

  void _setExcelCell(xls.Sheet sheet, int col, int row,
      xls.CellValue value, xls.CellStyle style) {
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      ..value = value
      ..cellStyle = style;
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
    final filtered = _filteredSummaries;

    int grandTotalPxDays = 0;
    int grandTotalWorkingDays = 0;
    int grandTotalOff = 0;
    int grandTotalUnauth = 0;
    Map<String, int> grandTotalTxTpDays = {};

    for (var summary in filtered) {
      grandTotalPxDays += summary.totalPxDays;
      grandTotalWorkingDays += summary.totalWorkingDays;
      grandTotalOff += summary.totalDaysOff;
      grandTotalUnauth += summary.totalDaysUnauth;
      for (var tp in _transactionPoints) {
        grandTotalTxTpDays[tp.name] = (grandTotalTxTpDays[tp.name] ?? 0) +
            (summary.txDaysByTransactionPoint[tp.name] ?? 0);
      }
    }

    return Scaffold(
      body: Column(
        children: [
          // Filter toolbar
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
                        await _loadData();
                        setState(() => _isLoading = false);
                      },
                    ),
                    const SizedBox(width: 16),
                    // Personnel Filter Dropdown
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<int?>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        hint: const Text('Tất cả nhân sự'),
                        value: _selectedPersonnelId,
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Tất cả nhân sự')),
                          ..._personnelList.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) async {
                          setState(() {
                            _selectedPersonnelId = val;
                            _isLoading = true;
                          });
                          await _loadSummary();
                          setState(() => _isLoading = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Lọc'),
                    ),
                    const SizedBox(width: 16),
                    // Search Employee Text Field
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Tìm nhân viên...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed:
                          _filteredSummaries.isEmpty ? null : _exportToExcel,
                      icon: const Icon(Icons.download),
                      label: const Text('Xuất Excel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Không có dữ liệu trong khoảng thời gian này.',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                    : Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        notificationPredicate: (n) => n.depth == 1,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: DataTable(
                                  border: TableBorder.all(
                                      color: Colors.grey.shade300),
                                  headingRowColor: WidgetStateProperty.all(
                                      Colors.blue[50]),
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 48,
                                  columns: [
                                    const DataColumn(
                                        label: Text('Nhân sự',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    const DataColumn(
                                        label: Text('Vai trò',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    ..._transactionPoints.map((tp) => DataColumn(
                                        label: Text('TX\n${tp.name}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)))),
                                    const DataColumn(
                                        label: Text('Tổng PX',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey))),
                                    const DataColumn(
                                        label: Text('Tổng\nngày làm',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue))),
                                    const DataColumn(
                                        label: Text('Tổng\nnghỉ',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepOrange))),
                                    const DataColumn(
                                        label: Text('N.Phép',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange))),
                                    const DataColumn(
                                        label: Text('K.Phép',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red))),
                                  ],
                                  rows: [
                                    ...filtered.map((summary) {
                                      final cells = <DataCell>[];
                                      // 1. Tên
                                      cells.add(DataCell(Text(
                                        summary.personnelName,
                                        style: TextStyle(
                                          color: summary.isWorking
                                              ? Colors.black87
                                              : Colors.grey,
                                        ),
                                      )));

                                      // 2. Vai trò
                                      String roleStr = summary.personnelRole == 'TX' ? 'Tài xế' : (summary.personnelRole == 'PX' ? 'Phụ xe' : '');
                                      cells.add(DataCell(Text(roleStr)));

                                      // 3. Các cột TX theo điểm giao dịch
                                      for (var tp in _transactionPoints) {
                                        final days = summary.txDaysByTransactionPoint[tp.name] ?? 0;
                                        cells.add(DataCell(Text(days > 0 ? days.toString() : '-')));
                                      }

                                      // 4. Tổng PX
                                      cells.add(DataCell(Text(
                                          summary.totalPxDays > 0 ? summary.totalPxDays.toString() : '-',
                                          style: const TextStyle(fontWeight: FontWeight.bold))));

                                      // 5. Tổng ngày làm (TX+PX)
                                      cells.add(DataCell(Text(
                                          summary.totalWorkingDays > 0 ? summary.totalWorkingDays.toString() : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue))));

                                      // 6. Tổng nghỉ (có phép + không phép)
                                      final totalOff = summary.totalDaysOff + summary.totalDaysUnauth;
                                      cells.add(DataCell(Text(
                                        totalOff > 0 ? totalOff.toString() : '-',
                                        style: TextStyle(
                                            color: totalOff > 0
                                                ? Colors.deepOrange.shade800
                                                : Colors.grey),
                                      )));

                                      // 7. Nghỉ phép
                                      cells.add(DataCell(Text(
                                        summary.totalDaysOff > 0
                                            ? summary.totalDaysOff.toString()
                                            : '-',
                                        style: TextStyle(
                                            color: summary.totalDaysOff > 0
                                                ? Colors.orange.shade800
                                                : Colors.grey),
                                      )));

                                      // 8. Không phép
                                      cells.add(DataCell(Text(
                                        summary.totalDaysUnauth > 0
                                            ? summary.totalDaysUnauth.toString()
                                            : '-',
                                        style: TextStyle(
                                            color: summary.totalDaysUnauth > 0
                                                ? Colors.red.shade800
                                                : Colors.grey),
                                      )));

                                      return DataRow(cells: cells);
                                    }),

                                    // Tổng cộng Row
                                    DataRow(
                                      color: WidgetStateProperty.all(
                                          Colors.green.shade50),
                                      cells: [
                                        const DataCell(Text(
                                          'TỔNG CỘNG',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green),
                                        )),
                                        const DataCell(Text('')), // Cột vai trò
                                        ..._transactionPoints.map((tp) {
                                          final totalForTp = grandTotalTxTpDays[tp.name] ?? 0;
                                          return DataCell(Text(
                                            totalForTp > 0 ? totalForTp.toString() : '-',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green),
                                          ));
                                        }),
                                        DataCell(Text(
                                          grandTotalPxDays > 0 ? grandTotalPxDays.toString() : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey),
                                        )),
                                        DataCell(Text(
                                          grandTotalWorkingDays > 0 ? grandTotalWorkingDays.toString() : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        )),
                                        DataCell(Text(
                                          (grandTotalOff + grandTotalUnauth) > 0
                                              ? (grandTotalOff + grandTotalUnauth).toString()
                                              : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepOrange),
                                        )),
                                        DataCell(Text(
                                          grandTotalOff > 0 ? grandTotalOff.toString() : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange),
                                        )),
                                        DataCell(Text(
                                          grandTotalUnauth > 0 ? grandTotalUnauth.toString() : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red),
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
