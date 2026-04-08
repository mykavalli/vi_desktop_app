import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../state/app_state.dart';
import '../utils/currency_format.dart';

class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({super.key});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Personnel> _personnel = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Personnel> get _filtered {
    if (_searchQuery.isEmpty) return _personnel;
    final q = _searchQuery.toLowerCase();
    return _personnel.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPersonnel();
    AppState.instance.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    AppState.instance.dataVersion.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    _loadPersonnel();
  }

  Future<void> _loadPersonnel() async {
    setState(() => _isLoading = true);
    try {
      final personnel = await _db.getAllPersonnel(activeOnly: true, workingOnly: false);
      if (mounted) {
        setState(() {
          _personnel = personnel;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu nhân viên: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      print('Load personnel error: $e\n$st');
    }
  }

  void _showAddEditDialog({Personnel? personnel}) {
    final nameController = TextEditingController(text: personnel?.name ?? '');
    final cccdController = TextEditingController(
      text: personnel?.cccd ?? '',
    );
    final driverLicenseController =
        TextEditingController(text: personnel?.driverLicense ?? '');
    final depositController = TextEditingController(
      text: personnel != null && personnel.deposit != null ? CurrencyFormat.formatNumberOnly(personnel.deposit!) : '',
    );
    DateTime? selectedStartDate = personnel?.startDate;
    String? selectedRole = personnel?.role;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(personnel == null ? 'Thêm nhân sự' : 'Sửa nhân sự'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tên nhân sự (required)
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên nhân sự *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tên';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Vai trò (Tài xế / Phụ xe) (not required)
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Vai trò (không bắt buộc)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Không chọn')),
                        DropdownMenuItem(value: 'TX', child: Text('Tài xế')),
                        DropdownMenuItem(value: 'PX', child: Text('Phụ xe')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedRole = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    // Căn cước công dân (not required)
                    TextFormField(
                      controller: cccdController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Số CCCD (không bắt buộc)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    // Ngày vào làm (not required) — date picker
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            helpText: 'Chọn ngày vào làm',
                          );
                          if (picked != null) {
                            setDialogState(() => selectedStartDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 20, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedStartDate != null
                                      ? 'Ngày vào làm: ${_formatDate(selectedStartDate!)}'
                                      : 'Ngày vào làm (không bắt buộc)',
                                  style: TextStyle(
                                    color: selectedStartDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              if (selectedStartDate != null)
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(
                                        () => selectedStartDate = null),
                                    child: const Icon(Icons.clear,
                                        size: 18, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Bằng lái xe (not required)
                    TextFormField(
                      controller: driverLicenseController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Bằng lái xe (không bắt buộc)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.drive_eta),
                        hintText: 'VD: B1, B2, C...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Tiền thế chân (not required)
                    TextFormField(
                      controller: depositController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Tiền thế chân (không bắt buộc)',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                        prefixIcon: Icon(Icons.security),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final newPersonnel = Personnel(
                      id: personnel?.id,
                      name: nameController.text.trim(),
                      cccd: cccdController.text.trim().isEmpty ? null : cccdController.text.trim(),
                      role: selectedRole,
                      isWorking: personnel?.isWorking ?? true,
                      driverLicense: driverLicenseController.text.trim().isEmpty
                          ? null
                          : driverLicenseController.text.trim(),
                      startDate: selectedStartDate,
                      deposit: depositController.text.trim().isEmpty
                          ? null
                          : CurrencyInputFormatter.parse(depositController.text),
                      createdAt: personnel?.createdAt ?? DateTime.now(),
                    );

                  try {
                    if (personnel == null) {
                      await _db.insertPersonnel(newPersonnel);
                    } else {
                      await _db.updatePersonnel(newPersonnel);
                    }

                    AppState.instance.refresh();

                    if (mounted) {
                      Navigator.pop(context);
                      _loadPersonnel();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving: $e')),
                      );
                    }
                  }
                }
              },
              child: Text(personnel == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePersonnel(Personnel personnel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${personnel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _db.deletePersonnel(personnel.id!);
              AppState.instance.refresh();
              if (mounted) {
                Navigator.pop(context);
                _loadPersonnel();
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWorkingStatus(Personnel p) async {
    await _db.togglePersonnelWorkingStatus(p.id!, !p.isWorking);
    AppState.instance.refresh();
    _loadPersonnel();
  }

  String _formatCurrency(double amount) {
    return CurrencyFormat.formatNumberOnly(amount);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _exportToExcel() async {
    final excel = xls.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Danh sach nhan vien');
    final sheet = excel['Danh sach nhan vien'];

    // Header style
    xls.CellStyle headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#1565C0'),
      fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    // Body style — working
    xls.CellStyle bodyStyle = xls.CellStyle(
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );

    // Body style — resigned
    xls.CellStyle resignedStyle = xls.CellStyle(
      fontColorHex: xls.ExcelColor.fromHexString('#9E9E9E'),
      backgroundColorHex: xls.ExcelColor.fromHexString('#F5F5F5'),
      leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );

    final headers = [
      'STT',
      'Họ tên nhân viên',
      'Trạng thái',
      'Vai trò',
      'CCCD',
      'Ngày vào làm',
      'Bằng lái xe',
      'Tiền thế chân (VNĐ)',
      'Ngày tạo',
    ];

    final colWidths = [6.0, 28.0, 15.0, 12.0, 22.0, 16.0, 15.0, 22.0, 16.0];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = xls.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(i, colWidths[i]);
    }

    final list = _filtered;
    for (int i = 0; i < list.length; i++) {
      final p = list[i];
      final rowIndex = i + 1;
      final style = p.isWorking ? bodyStyle : resignedStyle;

      void setCell(int col, xls.CellValue val) {
        sheet.cell(xls.CellIndex.indexByColumnRow(
            columnIndex: col, rowIndex: rowIndex))
          ..value = val
          ..cellStyle = style;
      }

      setCell(0, xls.TextCellValue('${i + 1}'));
      setCell(1, xls.TextCellValue(p.name));
      setCell(2, xls.TextCellValue(p.isWorking ? 'Đang làm việc' : 'Đã nghỉ việc'));
      setCell(3, xls.TextCellValue(p.role == 'TX' ? 'Tài xế' : (p.role == 'PX' ? 'Phụ xe' : '')));
      setCell(4, xls.TextCellValue(p.cccd ?? ''));
      setCell(
          5,
          xls.TextCellValue(
              p.startDate != null ? _formatDate(p.startDate!) : ''));
      setCell(6, xls.TextCellValue(p.driverLicense ?? ''));
      setCell(
          7,
          xls.TextCellValue(
              p.deposit != null ? _formatCurrency(p.deposit!) : ''));
      setCell(8, xls.TextCellValue(_formatDate(p.createdAt)));
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu danh sách nhân viên',
      fileName: 'Danh_sach_nhan_vien.xlsx',
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
    final filtered = _filtered;
    return Scaffold(
      body: Column(
        children: [
          // Toolbar: search + export
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Tìm kiếm nhân viên',
                      hintText: 'Nhập tên...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: IconButton(
                                icon: const Icon(Icons.clear, size: 18),
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
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: _personnel.isEmpty ? null : _exportToExcel,
                    icon: const Icon(Icons.download),
                    label: const Text('Xuất Excel'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Không tìm thấy "$_searchQuery"'
                                  : 'Chưa có nhân sự nào',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final isResigned = !p.isWorking;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isResigned
                                    ? Colors.grey.shade300
                                    : Theme.of(context).primaryColor,
                                child: Text(
                                  p.name[0].toUpperCase(),
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
                                    p.name,
                                    style: TextStyle(
                                      color: isResigned
                                          ? Colors.grey.shade500
                                          : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isResigned)
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
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                                  subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (p.role != null && p.role!.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 4, right: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            p.role == 'TX' ? 'Tài xế' : 'Phụ xe',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      if (p.cccd != null && p.cccd!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            'CCCD: ${p.cccd}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: isResigned
                                                    ? Colors.grey.shade400
                                                    : Colors.blueGrey),
                                          ),
                                        ),
                                    ],
                                  ),
                                    Row(
                                      children: [
                                        if (p.startDate != null) ...[
                                          Icon(Icons.calendar_today,
                                              size: 12,
                                              color: Colors.grey.shade500),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Vào làm: ${_formatDate(p.startDate!)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                      ],
                                      if (p.driverLicense != null &&
                                          p.driverLicense!.isNotEmpty) ...[
                                        Icon(Icons.drive_eta,
                                            size: 12,
                                            color: Colors.grey.shade500),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Bằng: ${p.driverLicense}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      if (p.deposit != null) ...[
                                        Icon(Icons.security,
                                            size: 12,
                                            color: Colors.grey.shade500),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Thế chân: ${_formatCurrency(p.deposit!)} VNĐ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Quick-switch working status
                                  Tooltip(
                                    message: isResigned
                                        ? 'Đánh dấu đang làm việc'
                                        : 'Đánh dấu đã nghỉ việc',
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _toggleWorkingStatus(p),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isResigned
                                                ? Colors.grey.shade100
                                                : Colors.green.shade50,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isResigned
                                                  ? Colors.grey.shade400
                                                  : Colors.green.shade400,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isResigned
                                                    ? Icons.work_off
                                                    : Icons.work,
                                                size: 14,
                                                color: isResigned
                                                    ? Colors.grey.shade600
                                                    : Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isResigned
                                                    ? 'Đã nghỉ'
                                                    : 'Đang làm',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isResigned
                                                      ? Colors.grey.shade600
                                                      : Colors.green.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showAddEditDialog(personnel: p),
                                      tooltip: 'Sửa',
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deletePersonnel(p),
                                      tooltip: 'Xóa',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm nhân sự'),
        ),
      ),
    );
  }
}
