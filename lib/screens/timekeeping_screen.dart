import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

