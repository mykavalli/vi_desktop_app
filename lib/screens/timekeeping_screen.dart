import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';
import '../state/app_state.dart';

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
  List<TransactionPoint> _transactionPoints = [];

  // Mapping: PersonnelId -> TransactionPointId -> Day -> Status
  Map<int, Map<int, Map<int, String>>> _dataMap = {};
  
  int? _selectedFilterTpId; // New filter state

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
    final timekeepings = await _db.getTimekeepingByMonth(
      year: _selectedYear,
      month: _selectedMonth,
    );

    _dataMap.clear();

    for (var tk in timekeepings) {
      _dataMap.putIfAbsent(tk.personnelId, () => {});
      _dataMap[tk.personnelId]!.putIfAbsent(tk.transactionPointId, () => {});
      _dataMap[tk.personnelId]![tk.transactionPointId]![tk.date.day] = tk.dayStatus;
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    // Add artificial delay to give user feedback of major save operation
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await _db.deleteTimekeepingByMonth(
        year: _selectedYear,
        month: _selectedMonth,
      );

      List<Timekeeping> newRecords = [];
      _dataMap.forEach((personnelId, tpMap) {
        tpMap.forEach((tpId, daysMap) {
          daysMap.forEach((day, status) {
            newRecords.add(Timekeeping(
              personnelId: personnelId,
              date: DateTime(_selectedYear, _selectedMonth, day),
              transactionPointId: tpId,
              createdAt: DateTime.now(),
              dayStatus: status,
            ));
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

  /// Cycle: (empty) → TX → PX → NP → KP → (empty)
  void _cycleStatus(int pId, int tpId, int day) {
    setState(() {
      _dataMap.putIfAbsent(pId, () => {});
      _dataMap[pId]!.putIfAbsent(tpId, () => {});

      final current = _dataMap[pId]![tpId]![day];
      if (current == null) {
        _dataMap[pId]![tpId]![day] = DayStatus.tx;
      } else if (current == DayStatus.tx) {
        _dataMap[pId]![tpId]![day] = DayStatus.px;
      } else if (current == DayStatus.px) {
        _dataMap[pId]![tpId]![day] = DayStatus.np;
      } else if (current == DayStatus.np) {
        _dataMap[pId]![tpId]![day] = DayStatus.kp;
      } else {
        _dataMap[pId]![tpId]!.remove(day);
      }
    });
  }

  Widget _buildDayCell(int pId, int tpId, int day) {
    final status = _dataMap[pId]?[tpId]?[day];

    if (status == null) {
      return InkWell(
        onTap: () => _cycleStatus(pId, tpId, day),
        borderRadius: BorderRadius.circular(4),
        child: const SizedBox(width: 36, height: 32),
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
        onTap: () => _cycleStatus(pId, tpId, day),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
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
                const SizedBox(width: 16),
                DropdownButton<int?>(
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
                const SizedBox(width: 16),
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
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saveData,
                  icon: const Icon(Icons.save),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  label: const Text('Lưu toàn bộ'),
                ),
              ],
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
                    : ListView.builder(
                        itemCount: () {
                          if (_selectedFilterTpId == null) return _personnelList.length;
                          return _personnelList.where((p) {
                            final tpMap = _dataMap[p.id];
                            return tpMap != null && tpMap.containsKey(_selectedFilterTpId!);
                          }).length;
                        }(),
                        itemBuilder: (context, index) {
                          final filtered = _selectedFilterTpId == null
                              ? _personnelList
                              : _personnelList.where((p) {
                                  final tpMap = _dataMap[p.id];
                                  return tpMap != null && tpMap.containsKey(_selectedFilterTpId!);
                                }).toList();
                          final personnel = filtered[index];
                          // Calculate if there's any active data to optionally expand automatically or show subtitle
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
                                        columnSpacing: 8,
                                        dataRowMinHeight: 40,
                                        dataRowMaxHeight: 48,
                                        headingRowHeight: 40,
                                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                                        columns: [
                                          const DataColumn(
                                              label: Text('Điểm GD',
                                                  style: TextStyle(fontWeight: FontWeight.bold))),
                                          ...List.generate(daysInMonth, (dIndex) {
                                            final day = dIndex + 1;
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
                                        ],
                                        rows: _transactionPoints.map((tp) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Container(
                                                  width: 120, // fixed width for transaction point name
                                                  child: Text(tp.name, 
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w500)
                                                  )
                                                )
                                              ),
                                              ...List.generate(daysInMonth, (dIndex) {
                                                final day = dIndex + 1;
                                                return DataCell(
                                                  _buildDayCell(personnel.id!, tp.id!, day)
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
        width: 32,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
