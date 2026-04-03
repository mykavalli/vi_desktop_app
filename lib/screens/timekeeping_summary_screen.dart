import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';
import '../utils/currency_format.dart';
import '../state/app_state.dart';

class TimekeepingSummaryScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const TimekeepingSummaryScreen({super.key, this.onNavigate});

  @override
  State<TimekeepingSummaryScreen> createState() =>
      _TimekeepingSummaryScreenState();
}

class _TimekeepingSummaryScreenState extends State<TimekeepingSummaryScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedPersonnelId;

  List<Personnel> _personnelList = [];
  List<TransactionPoint> _transactionPoints = [];
  List<TimekeepingSummary> _summaries = [];
  bool _isLoading = true;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _horizontalScrollController = ScrollController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _personnelList = await _db.getAllPersonnel();
    _transactionPoints = await _db.getAllTransactionPoints();
    await _loadSummary();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSummary() async {
    _summaries = await _db.getTimekeepingSummary(
      year: _selectedYear,
      month: _selectedMonth,
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

    final headers = ['STT', 'Tên nhân sự', 'Tổng ngày', 'Nghỉ Phép', 'Nghỉ K Phép'];
    for (var tp in _transactionPoints) {
      headers.add(tp.name);
    }
    headers.add('Tổng tiền lương');

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
      sheet.setColumnWidth(i, i == 1 ? 25.0 : 15.0);
    }

    int grandTotalDays = 0;
    int grandTotalOff = 0;
    int grandTotalUnauth = 0;
    double grandTotalSalary = 0.0;
    Map<String, int> grandTotalTpDays = {};

    final list = _filteredSummaries;
    for (int i = 0; i < list.length; i++) {
      final summary = list[i];
      final rowIndex = i + 1;
      grandTotalDays += summary.totalDays;
      grandTotalOff += summary.totalDaysOff;
      grandTotalUnauth += summary.totalDaysUnauth;
      grandTotalSalary += summary.totalSalary;

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = xls.TextCellValue('${i + 1}')
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
        ..value = xls.TextCellValue(summary.personnelName)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalDays)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalDaysOff)
        ..cellStyle = bodyStyle;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
        ..value = xls.IntCellValue(summary.totalDaysUnauth)
        ..cellStyle = bodyStyle;

      for (int j = 0; j < _transactionPoints.length; j++) {
        final tpName = _transactionPoints[j].name;
        final days = summary.daysByTransactionPoint[tpName] ?? 0;
        grandTotalTpDays[tpName] = (grandTotalTpDays[tpName] ?? 0) + days;
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: j + 5, rowIndex: rowIndex))
          ..value = xls.IntCellValue(days)
          ..cellStyle = bodyStyle;
      }

      sheet.cell(xls.CellIndex.indexByColumnRow(
              columnIndex: _transactionPoints.length + 5, rowIndex: rowIndex))
        ..value = xls.TextCellValue(
            CurrencyFormat.formatNumberOnly(summary.totalSalary))
        ..cellStyle = bodyStyle;
    }

    // Totals row
    final totalsRowIndex = list.length + 1;
    _setExcelCell(sheet, 0, totalsRowIndex, xls.TextCellValue(''), headerStyle);
    _setExcelCell(sheet, 1, totalsRowIndex, xls.TextCellValue('Tổng cộng'), headerStyle);
    _setExcelCell(sheet, 2, totalsRowIndex, xls.IntCellValue(grandTotalDays), headerStyle);
    _setExcelCell(sheet, 3, totalsRowIndex, xls.IntCellValue(grandTotalOff), headerStyle);
    _setExcelCell(sheet, 4, totalsRowIndex, xls.IntCellValue(grandTotalUnauth), headerStyle);

    for (int j = 0; j < _transactionPoints.length; j++) {
      final tpName = _transactionPoints[j].name;
      _setExcelCell(sheet, j + 5, totalsRowIndex,
          xls.IntCellValue(grandTotalTpDays[tpName] ?? 0), headerStyle);
    }
    _setExcelCell(
        sheet,
        _transactionPoints.length + 5,
        totalsRowIndex,
        xls.TextCellValue(CurrencyFormat.formatNumberOnly(grandTotalSalary)),
        headerStyle);

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel',
      fileName:
          'Cham_cong_tong_hop_Thang${_selectedMonth}_$_selectedYear.xlsx',
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
        // 'start' opens the file with its default associated application
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

    int grandTotalDays = 0;
    int grandTotalOff = 0;
    int grandTotalUnauth = 0;
    double grandTotalSalary = 0.0;
    Map<String, int> grandTotalTpDays = {};

    for (var summary in filtered) {
      grandTotalDays += summary.totalDays;
      grandTotalOff += summary.totalDaysOff;
      grandTotalUnauth += summary.totalDaysUnauth;
      grandTotalSalary += summary.totalSalary;
      for (var tp in _transactionPoints) {
        grandTotalTpDays[tp.name] = (grandTotalTpDays[tp.name] ?? 0) +
            (summary.daysByTransactionPoint[tp.name] ?? 0);
      }
    }

    return Scaffold(
      body: Column(
        children: [
          // ── Filter toolbar (always left-aligned) ──────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: _selectedMonth,
                    items: List.generate(12, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Tháng ${i + 1}'),
                    )),
                    onChanged: (v) => setState(() => _selectedMonth = v!),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _selectedYear,
                    items: List.generate(10, (i) {
                      final y = DateTime.now().year - 5 + i;
                      return DropdownMenuItem(value: y, child: Text('Năm $y'));
                    }),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int?>(
                      value: _selectedPersonnelId,
                      decoration: const InputDecoration(
                        labelText: 'Nhân sự',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Tất cả')),
                        ..._personnelList.map((p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedPersonnelId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search by name
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Tìm tên nhân viên',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await _loadSummary();
                      setState(() => _isLoading = false);
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Tìm kiếm'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _summaries.isEmpty ? null : _exportToExcel,
                    icon: const Icon(Icons.download),
                    label: const Text('Xuất Excel'),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.summarize_outlined,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Không có dữ liệu chấm công',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                border: TableBorder.all(
                                    color: Colors.grey.shade300),
                                headingRowColor:
                                    MaterialStateProperty.all(Colors.blue[50]),
                                columns: [
                                  const DataColumn(label: Text('STT')),
                                  const DataColumn(label: Text('Tên nhân sự')),
                                  const DataColumn(
                                    label: Text('Tổng ngày'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Nghỉ Phép',
                                        style: TextStyle(
                                            color: Colors.blue.shade700)),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Nghỉ K Phép',
                                        style: TextStyle(
                                            color: Colors.orange.shade700)),
                                    numeric: true,
                                  ),
                                  ..._transactionPoints.map((tp) =>
                                      DataColumn(
                                          label: Text(tp.name), numeric: true)),
                                  const DataColumn(
                                    label: Text('Tổng tiền lương'),
                                    numeric: true,
                                  ),
                                ],
                                rows: [
                                  ...List.generate(filtered.length, (index) {
                                    final summary = filtered[index];
                                    return DataRow(
                                      cells: [
                                        DataCell(Text('${index + 1}')),
                                        // Clickable name → navigate to Personnel tab
                                        DataCell(
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: InkWell(
                                              onTap: widget.onNavigate != null
                                                  ? () => widget.onNavigate!(1)
                                                  : null,
                                              child: Text(
                                                summary.personnelName,
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Theme.of(context)
                                                          .primaryColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                            Text('${summary.totalDays}')),
                                        DataCell(Text(
                                          '${summary.totalDaysOff}',
                                          style: TextStyle(
                                            color: summary.totalDaysOff > 0
                                                ? Colors.blue.shade700
                                                : null,
                                          ),
                                        )),
                                        DataCell(Text(
                                          '${summary.totalDaysUnauth}',
                                          style: TextStyle(
                                            color:
                                                summary.totalDaysUnauth > 0
                                                    ? Colors.orange.shade700
                                                    : null,
                                          ),
                                        )),
                                        ..._transactionPoints.map((tp) =>
                                            DataCell(Text(
                                              '${summary.daysByTransactionPoint[tp.name] ?? 0}',
                                            ))),
                                        DataCell(Text(
                                          CurrencyFormat.formatVN(
                                              summary.totalSalary),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green),
                                        )),
                                      ],
                                    );
                                  }),
                                  // Grand totals row
                                  if (filtered.isNotEmpty)
                                    DataRow(
                                      color: MaterialStateProperty.all(
                                          Colors.amber.shade100),
                                      cells: [
                                        const DataCell(Text('')),
                                        const DataCell(Text('Tổng cộng',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                        DataCell(Text(
                                            grandTotalDays.toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))),
                                        DataCell(Text(
                                            grandTotalOff.toString(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700))),
                                        DataCell(Text(
                                            grandTotalUnauth.toString(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Colors.orange.shade700))),
                                        ..._transactionPoints.map((tp) =>
                                            DataCell(Text(
                                              '${grandTotalTpDays[tp.name] ?? 0}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ))),
                                        DataCell(Text(
                                          CurrencyFormat.formatVN(
                                              grandTotalSalary),
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
        ],
      ),
    );
  }
}
