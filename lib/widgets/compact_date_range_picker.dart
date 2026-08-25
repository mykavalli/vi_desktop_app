import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompactDateRangePicker extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime start, DateTime end) onDateRangeChanged;

  const CompactDateRangePicker({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  }) : super(key: key);

  void _previousMonth() {
    final prevMonth = DateTime(startDate.year, startDate.month - 1, 1);
    final lastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0);
    onDateRangeChanged(prevMonth, lastDay);
  }

  void _nextMonth() {
    final nextMonth = DateTime(startDate.year, startDate.month + 1, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0);
    onDateRangeChanged(nextMonth, lastDay);
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    onDateRangeChanged(firstDay, lastDay);
  }

  void _applyLastMonth() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month - 1, 1);
    final lastDay = DateTime(now.year, now.month, 0);
    onDateRangeChanged(firstDay, lastDay);
  }

  Future<void> _openCustomPicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      onDateRangeChanged(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateText = '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous Month button
          Tooltip(
            message: 'Tháng trước',
            child: InkWell(
              onTap: _previousMonth,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(Icons.chevron_left, size: 20, color: Colors.black87),
              ),
            ),
          ),
          
          // Main Date Range selector (Clicking opens calendar dialog & auto applies!)
          InkWell(
            onTap: () => _openCustomPicker(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Colors.blue),
                ],
              ),
            ),
          ),

          // Next Month button
          Tooltip(
            message: 'Tháng sau',
            child: InkWell(
              onTap: _nextMonth,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(Icons.chevron_right, size: 20, color: Colors.black87),
              ),
            ),
          ),

          const SizedBox(width: 4),
          const SizedBox(
            height: 20,
            child: VerticalDivider(width: 1, color: Colors.grey),
          ),
          const SizedBox(width: 4),
          
          // Quick preset menu (Visually prominent button: ⚡ Chọn nhanh ▾)
          PopupMenuButton<String>(
            tooltip: 'Chọn nhanh thời gian',
            offset: const Offset(0, 36),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 4),
                  Text(
                    'Chọn nhanh',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.amber.shade900),
                ],
              ),
            ),
            onSelected: (value) {
              final now = DateTime.now();
              if (value == 'this_month') {
                _applyThisMonth();
              } else if (value == 'last_month') {
                _applyLastMonth();
              } else if (value == 'last_7_days') {
                onDateRangeChanged(now.subtract(const Duration(days: 6)), now);
              } else if (value == 'last_30_days') {
                onDateRangeChanged(now.subtract(const Duration(days: 29)), now);
              } else if (value == 'custom') {
                _openCustomPicker(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'this_month',
                child: Row(
                  children: [
                    Icon(Icons.today, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Tháng này', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'last_month',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Tháng trước', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'last_7_days',
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text('7 ngày qua', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'last_30_days',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 16, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('30 ngày qua', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'custom',
                child: Row(
                  children: [
                    Icon(Icons.edit_calendar, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Mở Lịch chọn ngày...', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
