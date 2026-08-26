import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompactDateRangePicker extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime start, DateTime end) onDateRangeChanged;

  const CompactDateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  });

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
    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AutoApplyDateRangePickerDialog(
        initialStartDate: startDate,
        initialEndDate: endDate,
      ),
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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút tháng trước
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

          // Khung bấm mở lịch tự động áp dụng (Auto Apply)
          InkWell(
            onTap: () => _openCustomPicker(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.6),
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

          // Nút tháng sau
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

          // Menu chọn nhanh
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

/// Dialog chọn ngày Tự động Áp dụng (Auto Apply & Close on To Date Selection)
class _AutoApplyDateRangePickerDialog extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const _AutoApplyDateRangePickerDialog({
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  State<_AutoApplyDateRangePickerDialog> createState() => _AutoApplyDateRangePickerDialogState();
}

class _AutoApplyDateRangePickerDialogState extends State<_AutoApplyDateRangePickerDialog> {
  late DateTime _currentMonth;
  DateTime? _selectedStart;
  DateTime? _selectedEnd;
  DateTime? _hoverDate;
  bool _isSelectingEnd = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialStartDate.year, widget.initialStartDate.month, 1);
    _selectedStart = widget.initialStartDate;
    _selectedEnd = widget.initialEndDate;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _onDayTapped(DateTime day) {
    final tapped = DateTime(day.year, day.month, day.day);

    if (!_isSelectingEnd || _selectedStart == null) {
      // Bắt đầu chọn ngày bắt đầu (From)
      setState(() {
        _selectedStart = tapped;
        _selectedEnd = null;
        _isSelectingEnd = true;
      });
    } else {
      // Đang chờ chọn ngày kết thúc (To)
      if (tapped.isBefore(_selectedStart!)) {
        // Nếu chọn ngày nhỏ hơn ngày bắt đầu -> Đổi ngày bắt đầu thành ngày này
        setState(() {
          _selectedStart = tapped;
          _selectedEnd = null;
          _isSelectingEnd = true;
        });
      } else {
        // ĐÃ CÓ ĐỦ TỪ NGÀY VÀ ĐẾN NGÀY -> TỰ ĐỘNG ÁP DỤNG VÀ ĐÓNG POPUP!
        _selectedEnd = tapped;
        Navigator.of(context).pop(DateTimeRange(start: _selectedStart!, end: _selectedEnd!));
      }
    }
  }

  void _applyQuickPreset(DateTime start, DateTime end) {
    Navigator.of(context).pop(DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final monthYearStr = DateFormat('Tháng MM, yyyy').format(_currentMonth);

    // Tiêu đề hướng dẫn trạng thái chọn
    String statusGuide;
    if (_isSelectingEnd && _selectedStart != null) {
      statusGuide = 'Từ: ${df.format(_selectedStart!)} ➜ Nhấp chọn ngày kết thúc (Đến ngày)';
    } else if (_selectedStart != null && _selectedEnd != null) {
      statusGuide = 'Khoảng ngày: ${df.format(_selectedStart!)} - ${df.format(_selectedEnd!)}';
    } else {
      statusGuide = 'Nhấp chọn ngày bắt đầu (Từ ngày)';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Thanh điều hướng tháng & nút Đóng
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                  tooltip: 'Tháng trước',
                ),
                Expanded(
                  child: Text(
                    monthYearStr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                  tooltip: 'Tháng sau',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Đóng',
                ),
              ],
            ),

            // Thanh hướng dẫn trạng thái
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isSelectingEnd ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSelectingEnd ? Colors.blue.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSelectingEnd ? Icons.touch_app : Icons.info_outline,
                    size: 16,
                    color: _isSelectingEnd ? Colors.blue.shade700 : Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusGuide,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isSelectingEnd ? FontWeight.bold : FontWeight.w500,
                        color: _isSelectingEnd ? Colors.blue.shade900 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Hàng thứ trong tuần
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _WeekdayLabel('T2'),
                  _WeekdayLabel('T3'),
                  _WeekdayLabel('T4'),
                  _WeekdayLabel('T5'),
                  _WeekdayLabel('T6'),
                  _WeekdayLabel('T7'),
                  _WeekdayLabel('CN', isWeekend: true),
                ],
              ),
            ),

            const Divider(height: 1),
            const SizedBox(height: 6),

            // Lưới các ngày trong tháng
            _buildDaysGrid(),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Phím tắt chọn nhanh bên dưới
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickChip('Hôm nay', () {
                  final now = DateTime.now();
                  _applyQuickPreset(now, now);
                }),
                _buildQuickChip('Tháng này', () {
                  final now = DateTime.now();
                  _applyQuickPreset(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
                }),
                _buildQuickChip('Tháng trước', () {
                  final now = DateTime.now();
                  _applyQuickPreset(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0));
                }),
                _buildQuickChip('7 ngày qua', () {
                  final now = DateTime.now();
                  _applyQuickPreset(now.subtract(const Duration(days: 6)), now);
                }),
                _buildQuickChip('30 ngày qua', () {
                  final now = DateTime.now();
                  _applyQuickPreset(now.subtract(const Duration(days: 29)), now);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildDaysGrid() {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon, 7 = Sun

    final totalSlots = ((firstWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final effectiveEnd = _selectedEnd ?? (_isSelectingEnd ? _hoverDate : null);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 1.15,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, index) {
        final dayOffset = index - (firstWeekday - 1) + 1;
        if (dayOffset < 1 || dayOffset > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(year, month, dayOffset);
        final isToday = date.isAtSameMomentAs(today);

        final isStart = _selectedStart != null && date.isAtSameMomentAs(_selectedStart!);
        final isEnd = effectiveEnd != null && date.isAtSameMomentAs(effectiveEnd);
        final isInRange = _selectedStart != null &&
            effectiveEnd != null &&
            date.isAfter(_selectedStart!) &&
            date.isBefore(effectiveEnd);

        Color? textColor;
        FontWeight fontWeight = FontWeight.normal;
        BoxDecoration? cellDecoration;

        if (isStart || isEnd) {
          textColor = Colors.white;
          fontWeight = FontWeight.bold;
          cellDecoration = BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
          );
        } else if (isInRange) {
          textColor = Colors.blue.shade900;
          fontWeight = FontWeight.w600;
          cellDecoration = BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
          );
        } else if (isToday) {
          textColor = Colors.blue.shade700;
          fontWeight = FontWeight.bold;
          cellDecoration = BoxDecoration(
            border: Border.all(color: Colors.blue.shade400, width: 1.5),
            shape: BoxShape.circle,
          );
        } else {
          textColor = Colors.black87;
        }

        return MouseRegion(
          onEnter: (_) {
            if (_isSelectingEnd) {
              setState(() => _hoverDate = date);
            }
          },
          child: InkWell(
            onTap: () => _onDayTapped(date),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              alignment: Alignment.center,
              decoration: cellDecoration,
              child: Text(
                '$dayOffset',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  final bool isWeekend;

  const _WeekdayLabel(this.text, {this.isWeekend = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isWeekend ? Colors.red.shade400 : Colors.blueGrey.shade600,
        ),
      ),
    );
  }
}