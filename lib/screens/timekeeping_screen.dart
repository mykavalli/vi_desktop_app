import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/job_position.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';

class TimekeepingRow {
  int personnelId;
  int jobPositionId;
  int transactionPointId;
  Set<int> daysChecked;

  TimekeepingRow({
    required this.personnelId,
    required this.jobPositionId,
    required this.transactionPointId,
    required this.daysChecked,
  });

  String get key => '${personnelId}_${jobPositionId}_${transactionPointId}';
}

class TimekeepingScreen extends StatefulWidget {
  const TimekeepingScreen({super.key});

  @override
  State<TimekeepingScreen> createState() => _TimekeepingScreenState();
}

class _TimekeepingScreenState extends State<TimekeepingScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Personnel> _personnelList = [];
  List<JobPosition> _jobPositions = [];
  List<TransactionPoint> _transactionPoints = [];

  List<TimekeepingRow> _rows = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _personnelList = await _db.getAllPersonnel();
    _jobPositions = await _db.getAllJobPositions();
    _transactionPoints = await _db.getAllTransactionPoints();

    await _loadTimekeepingData();

    setState(() => _isLoading = false);
  }

  Future<void> _loadTimekeepingData() async {
    final timekeepings = await _db.getTimekeepingByMonth(
      year: _selectedYear,
      month: _selectedMonth,
    );

    Map<String, TimekeepingRow> rowMap = {};
    for (var tk in timekeepings) {
      String key = '${tk.personnelId}_${tk.jobPositionId}_${tk.transactionPointId}';
      if (!rowMap.containsKey(key)) {
        rowMap[key] = TimekeepingRow(
          personnelId: tk.personnelId,
          jobPositionId: tk.jobPositionId,
          transactionPointId: tk.transactionPointId,
          daysChecked: {},
        );
      }
      rowMap[key]!.daysChecked.add(tk.date.day);
    }
    
    _rows = rowMap.values.toList();
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Delete all for this month
      await _db.deleteTimekeepingByMonth(year: _selectedYear, month: _selectedMonth);

      // 2. Insert checked ones
      List<Timekeeping> newRecords = [];
      for (var row in _rows) {
        for (var day in row.daysChecked) {
          newRecords.add(Timekeeping(
            personnelId: row.personnelId,
            date: DateTime(_selectedYear, _selectedMonth, day),
            jobPositionId: row.jobPositionId,
            transactionPointId: row.transactionPointId,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (newRecords.isNotEmpty) {
        await _db.insertMultipleTimekeeping(newRecords);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu dữ liệu chấm công thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddRowDialog() {
    Personnel? selectedPersonnel;
    JobPosition? selectedPosition;
    TransactionPoint? selectedPoint;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm dòng chấm công'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Personnel>(
                decoration: const InputDecoration(
                  labelText: 'Nhân sự',
                  border: OutlineInputBorder(),
                ),
                value: selectedPersonnel,
                items: _personnelList.map((p) {
                  return DropdownMenuItem(value: p, child: Text(p.name));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedPersonnel = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<JobPosition>(
                decoration: const InputDecoration(
                  labelText: 'Vị trí công việc',
                  border: OutlineInputBorder(),
                ),
                value: selectedPosition,
                items: _jobPositions.map((jp) {
                  return DropdownMenuItem(value: jp, child: Text(jp.name));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedPosition = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TransactionPoint>(
                decoration: const InputDecoration(
                  labelText: 'Điểm giao dịch',
                  border: OutlineInputBorder(),
                ),
                value: selectedPoint,
                items: _transactionPoints.map((tp) {
                  return DropdownMenuItem(value: tp, child: Text(tp.name));
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedPoint = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: (selectedPersonnel == null || selectedPosition == null || selectedPoint == null)
                  ? null
                  : () {
                      final key = '${selectedPersonnel!.id}_${selectedPosition!.id}_${selectedPoint!.id}';
                      if (!_rows.any((r) => r.key == key)) {
                        setState(() {
                          _rows.add(TimekeepingRow(
                            personnelId: selectedPersonnel!.id!,
                            jobPositionId: selectedPosition!.id!,
                            transactionPointId: selectedPoint!.id!,
                            daysChecked: {},
                          ));
                        });
                      }
                      Navigator.pop(context);
                    },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  String _getPersonnelName(int id) {
    return _personnelList.firstWhere((p) => p.id == id, orElse: () => Personnel(name: 'N/A', basicSalary: 0, createdAt: DateTime.now())).name;
  }

  String _getJobPositionName(int id) {
    return _jobPositions.firstWhere((j) => j.id == id, orElse: () => JobPosition(name: 'N/A', salary: 0, createdAt: DateTime.now())).name;
  }

  String _getTransactionPointName(int id) {
    return _transactionPoints.firstWhere((t) => t.id == id, orElse: () => TransactionPoint(name: 'N/A', createdAt: DateTime.now())).name;
  }

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

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
                  onChanged: (value) async {
                    setState(() {
                      _selectedMonth = value!;
                      _isLoading = true;
                    });
                    await _loadTimekeepingData();
                    setState(() => _isLoading = false);
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
                  onChanged: (value) async {
                    setState(() {
                      _selectedYear = value!;
                      _isLoading = true;
                    });
                    await _loadTimekeepingData();
                    setState(() => _isLoading = false);
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddRowDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm dòng'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _saveData,
                  icon: const Icon(Icons.save),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  label: const Text('Lưu lại'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có dữ liệu chấm công. Hãy thêm dòng mới.',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      )
                    : Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                          child: DataTable(
                            columnSpacing: 16,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 48,
                            headingRowHeight: 40,
                            headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                            columns: [
                              const DataColumn(label: Text('Nhân sự', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Vị trí', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Điểm GD', style: TextStyle(fontWeight: FontWeight.bold))),
                              ...List.generate(daysInMonth, (index) {
                                final day = index + 1;
                                final date = DateTime(_selectedYear, _selectedMonth, day);
                                final isWeekend = date.weekday == DateTime.sunday;
                                return DataColumn(
                                  label: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isWeekend ? Colors.red : null,
                                    ),
                                  ),
                                );
                              }),
                              const DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _rows.map((row) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(_getPersonnelName(row.personnelId))),
                                  DataCell(
                                    DropdownButton<int>(
                                      value: row.jobPositionId,
                                      underline: const SizedBox(),
                                      items: _jobPositions.map((jp) {
                                        return DropdownMenuItem(value: jp.id, child: Text(jp.name));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => row.jobPositionId = val);
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButton<int>(
                                      value: row.transactionPointId,
                                      underline: const SizedBox(),
                                      items: _transactionPoints.map((tp) {
                                        return DropdownMenuItem(value: tp.id, child: Text(tp.name));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => row.transactionPointId = val);
                                      },
                                    ),
                                  ),
                                  ...List.generate(daysInMonth, (index) {
                                    final day = index + 1;
                                    return DataCell(
                                      Checkbox(
                                        value: row.daysChecked.contains(day),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              row.daysChecked.add(day);
                                            } else {
                                              row.daysChecked.remove(day);
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _rows.remove(row);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
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
