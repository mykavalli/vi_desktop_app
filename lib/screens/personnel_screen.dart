import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/personnel.dart';

class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({super.key});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Personnel> _personnel = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
    final nameController = TextEditingController(text: personnel?.name ?? '');
    final salaryController = TextEditingController(
      text: personnel?.basicSalary.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

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
            onPressed: () async {
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

                if (mounted) {
                  Navigator.pop(context);
                  _loadPersonnel();
                }
              }
            },
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _personnel.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có nhân sự nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _personnel.length,
              itemBuilder: (context, index) {
                final p = _personnel[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
                    title: Text(p.name),
                    subtitle: Text(
                      'Lương cơ bản: ${_formatCurrency(p.basicSalary)} VNĐ',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddEditDialog(personnel: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePersonnel(p),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm nhân sự'),
      ),
    );
  }
}
