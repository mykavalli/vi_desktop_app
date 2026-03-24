import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';
import '../utils/currency_format.dart';

class TimekeepingSummaryScreen extends StatefulWidget {
  const TimekeepingSummaryScreen({super.key});

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
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
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

  Future<void> _exportToExcel() async {
    final excel = xls.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Cham cong tong hop');
    final sheet = excel['Cham cong tong hop'];

    final headers = ['STT', 'Tên nhân sự', 'Tổng ngày'];
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
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = xls.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(i, i == 1 ? 25.0 : 15.0);
    }

    int grandTotalDays = 0;
    double grandTotalSalary = 0.0;
    Map<String, int> grandTotalTpDays = {};

    for (int i = 0; i < _summaries.length; i++) {
      final summary = _summaries[i];
      final rowIndex = i + 1;

      grandTotalDays += summary.totalDays;
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

      for (int j = 0; j < _transactionPoints.length; j++) {
        final tpName = _transactionPoints[j].name;
        final days = summary.daysByTransactionPoint[tpName] ?? 0;
        grandTotalTpDays[tpName] = (grandTotalTpDays[tpName] ?? 0) + days;
        
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: j + 3, rowIndex: rowIndex))
          ..value = xls.IntCellValue(days)
          ..cellStyle = bodyStyle;
      }

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: _transactionPoints.length + 3, rowIndex: rowIndex))
        ..value = xls.TextCellValue(CurrencyFormat.formatNumberOnly(summary.totalSalary))
        ..cellStyle = bodyStyle;
    }

    // Add Totals row
    final totalsRowIndex = _summaries.length + 1;
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalsRowIndex))
      ..value = xls.TextCellValue('')
      ..cellStyle = headerStyle;

    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalsRowIndex))
      ..value = xls.TextCellValue('Tổng cộng')
      ..cellStyle = headerStyle;

    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalsRowIndex))
      ..value = xls.IntCellValue(grandTotalDays)
      ..cellStyle = headerStyle;

    for (int j = 0; j < _transactionPoints.length; j++) {
      final tpName = _transactionPoints[j].name;
      final totalDaysTp = grandTotalTpDays[tpName] ?? 0;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: j + 3, rowIndex: totalsRowIndex))
        ..value = xls.IntCellValue(totalDaysTp)
        ..cellStyle = headerStyle;
    }

    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: _transactionPoints.length + 3, rowIndex: totalsRowIndex))
      ..value = xls.TextCellValue(CurrencyFormat.formatNumberOnly(grandTotalSalary))
      ..cellStyle = headerStyle;

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel',
      fileName: 'Cham_cong_tong_hop_Thang${_selectedMonth}_$_selectedYear.xlsx',
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
            const SnackBar(
              content: Text('Xuất file Excel thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int grandTotalDays = 0;
    double grandTotalSalary = 0.0;
    Map<String, int> grandTotalTpDays = {};

    for(var summary in _summaries) {
      grandTotalDays += summary.totalDays;
      grandTotalSalary += summary.totalSalary;
      for (var tp in _transactionPoints) {
        grandTotalTpDays[tp.name] = (grandTotalTpDays[tp.name] ?? 0) + (summary.daysByTransactionPoint[tp.name] ?? 0);
      }
    }

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text('Tháng ${index + 1}'),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(10, (index) {
                    final year = DateTime.now().year - 5 + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text('Năm $year'),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value!;
                    });
                  },
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    value: _selectedPersonnelId,
                    decoration: const InputDecoration(
                      labelText: 'Nhân sự',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      ..._personnelList.map((p) {
                        return DropdownMenuItem(value: p.id, child: Text(p.name));
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPersonnelId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    await _loadSummary();
                    setState(() => _isLoading = false);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm kiếm'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _summaries.isEmpty ? null : _exportToExcel,
                  icon: const Icon(Icons.download),
                  label: const Text('Xuất Excel'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _summaries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.summarize_outlined,
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
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columns: [
                            const DataColumn(label: Text('STT')),
                            const DataColumn(label: Text('Tên nhân sự')),
                            const DataColumn(
                              label: Text('Tổng ngày'),
                              numeric: true,
                            ),
                            ..._transactionPoints.map(
                              (tp) => DataColumn(
                                label: Text(tp.name),
                                numeric: true,
                              ),
                            ),
                            const DataColumn(
                              label: Text('Tổng tiền lương'),
                              numeric: true,
                            ),
                          ],
                          rows: [
                            ...List.generate(_summaries.length, (index) {
                              final summary = _summaries[index];
                              return DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(Text(summary.personnelName)),
                                  DataCell(Text('${summary.totalDays}')),
                                  ..._transactionPoints.map(
                                    (tp) => DataCell(
                                      Text(
                                        '${summary.daysByTransactionPoint[tp.name] ?? 0}',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      CurrencyFormat.formatVN(summary.totalSalary),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            if (_summaries.isNotEmpty)
                              DataRow(
                                color: MaterialStateProperty.all(Colors.amber.shade100),
                                cells: [
                                  const DataCell(Text('')),
                                  const DataCell(Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(grandTotalDays.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ..._transactionPoints.map(
                                    (tp) => DataCell(
                                      Text(
                                        '${grandTotalTpDays[tp.name] ?? 0}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      CurrencyFormat.formatVN(grandTotalSalary),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                  ),
                                ]
                              )
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
