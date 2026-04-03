import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/job_position.dart';
import '../state/app_state.dart';

class JobPositionScreen extends StatefulWidget {
  const JobPositionScreen({super.key});

  @override
  State<JobPositionScreen> createState() => _JobPositionScreenState();
}

class _JobPositionScreenState extends State<JobPositionScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<JobPosition> _positions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<JobPosition> get _filtered {
    if (_searchQuery.isEmpty) return _positions;
    final q = _searchQuery.toLowerCase();
    return _positions.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPositions();
    AppState.instance.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    AppState.instance.dataVersion.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    setState(() => _isLoading = true);
    final positions = await _db.getAllJobPositions();
    setState(() {
      _positions = positions;
      _isLoading = false;
    });
  }

  void _showAddEditDialog({JobPosition? position}) {
    final nameController =
        TextEditingController(text: position?.name ?? '');
    final salaryController = TextEditingController(
      text: position?.salary.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final nameFocus = FocusNode();
    final salaryFocus = FocusNode();

    Future<void> onSave() async {
      if (formKey.currentState!.validate()) {
        final newPosition = JobPosition(
          id: position?.id,
          name: nameController.text,
          salary: double.parse(salaryController.text),
          createdAt: position?.createdAt ?? DateTime.now(),
        );

        if (position == null) {
          await _db.insertJobPosition(newPosition);
        } else {
          await _db.updateJobPosition(newPosition);
        }

        AppState.instance.refresh();

        if (mounted) {
          Navigator.pop(context);
          _loadPositions();
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(position == null ? 'Thêm vị trí' : 'Sửa vị trí'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                focusNode: nameFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(salaryFocus),
                decoration: const InputDecoration(
                  labelText: 'Tên vị trí công việc',
                  border: OutlineInputBorder(),
                  hintText: 'VD: Tài xế, Phụ xe',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên vị trí';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: salaryController,
                focusNode: salaryFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSave(),
                decoration: const InputDecoration(
                  labelText: 'Mức lương',
                  border: OutlineInputBorder(),
                  suffixText: 'VNĐ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mức lương';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Mức lương không hợp lệ';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: onSave,
            child: Text(position == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    );
  }

  void _deletePosition(JobPosition position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${position.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _db.deleteJobPosition(position.id!);
              AppState.instance.refresh();
              if (mounted) {
                Navigator.pop(context);
                _loadPositions();
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  IconData _getPositionIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('tài xế') || lowerName.contains('lái xe')) {
      return Icons.drive_eta;
    } else if (lowerName.contains('phụ xe')) {
      return Icons.airline_seat_recline_normal;
    }
    return Icons.work;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tìm kiếm vị trí công việc',
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
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.work_outline,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Không tìm thấy "$_searchQuery"'
                                  : 'Chưa có vị trí công việc nào',
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green[100],
                                child: Icon(_getPositionIcon(p.name),
                                    color: Colors.green[700]),
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                  'Lương: ${_formatCurrency(p.salary)} VNĐ'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showAddEditDialog(position: p),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deletePosition(p),
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
          label: const Text('Thêm vị trí'),
        ),
      ),
    );
  }
}
