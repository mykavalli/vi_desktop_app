import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/personnel.dart';
import '../state/app_state.dart';

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
    final personnel = await _db.getAllPersonnel();
    setState(() {
      _personnel = personnel;
      _isLoading = false;
    });
  }

  void _showAddEditDialog({Personnel? personnel}) {
    final nameController =
        TextEditingController(text: personnel?.name ?? '');
    final salaryController = TextEditingController(
      text: personnel?.basicSalary.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final nameFocus = FocusNode();
    final salaryFocus = FocusNode();

    Future<void> onSave() async {
      if (formKey.currentState!.validate()) {
        final newPersonnel = Personnel(
          id: personnel?.id,
          name: nameController.text,
          basicSalary: double.parse(salaryController.text),
          createdAt: personnel?.createdAt ?? DateTime.now(),
        );

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
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(personnel == null ? 'Thêm nhân sự' : 'Sửa nhân sự'),
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
                  labelText: 'Tên nhân sự',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên';
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
                  labelText: 'Mức lương cơ bản',
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
            child: Text(personnel == null ? 'Thêm' : 'Lưu'),
          ),
        ],
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

  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                  child: Text(p.name[0].toUpperCase())),
                              title: Text(p.name),
                              subtitle: Text(
                                'Lương cơ bản: ${_formatCurrency(p.basicSalary)} VNĐ',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showAddEditDialog(personnel: p),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deletePersonnel(p),
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
