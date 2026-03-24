import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../models/timekeeping.dart';

class TimekeepingDetailScreen extends StatefulWidget {
  const TimekeepingDetailScreen({super.key});

  @override
  State<TimekeepingDetailScreen> createState() =>
      _TimekeepingDetailScreenState();
}

class _TimekeepingDetailScreenState extends State<TimekeepingDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedPersonnelId;

  List<Personnel> _personnelList = [];
  List<TimekeepingDetail> _details = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _personnelList = await _db.getAllPersonnel();
    await _loadDetails();

    setState(() => _isLoading = false);
  }

  Future<void> _loadDetails() async {
    _details = await _db.getTimekeepingDetail(
      year: _selectedYear,
      month: _selectedMonth,
      personnelId: _selectedPersonnelId,
    );
  }

  Map<DateTime, List<TimekeepingDetail>> _groupByDate() {
    Map<DateTime, List<TimekeepingDetail>> grouped = {};
    for (var detail in _details) {
      final dateKey = DateTime(
        detail.date.year,
        detail.date.month,
        detail.date.day,
      );
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(detail);
    }
    return grouped;
  }

  Map<int, Map<DateTime, List<TimekeepingDetail>>> _groupByPersonnel() {
    Map<int, Map<DateTime, List<TimekeepingDetail>>> grouped = {};
    for (var detail in _details) {
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

  @override
  Widget build(BuildContext context) {
    final groupedByPersonnel = _groupByPersonnel();

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
                    await _loadDetails();
                    setState(() => _isLoading = false);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm kiếm'),
                ),
              ],
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
                      final personnelId = groupedByPersonnel.keys.elementAt(
                        index,
                      );
                      final dateMap = groupedByPersonnel[personnelId]!;
                      final personnelName = _details
                          .firstWhere((d) => d.personnelId == personnelId)
                          .personnelName;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(
                            personnelName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${dateMap.length} ngày công'),
                          children: dateMap.entries.map((entry) {
                            final date = entry.key;
                            final records = entry.value;
                            final weekday = _getWeekdayName(date.weekday);

                            return ListTile(
                              title: Text(
                                '$weekday, ${DateFormat('dd/MM/yyyy').format(date)}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: records.map((r) {
                                  return Text(
                                    '${r.jobPositionName} - ${r.transactionPointName}',
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }).toList(),
                              ),
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
