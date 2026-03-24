import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/transaction_point.dart';

class TransactionPointScreen extends StatefulWidget {
  const TransactionPointScreen({super.key});

  @override
  State<TransactionPointScreen> createState() => _TransactionPointScreenState();
}

class _TransactionPointScreenState extends State<TransactionPointScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<TransactionPoint> _points = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    final points = await _db.getAllTransactionPoints();
    setState(() {
      _points = points;
      _isLoading = false;
    });
  }

  void _showAddEditDialog({TransactionPoint? point}) {
    final nameController = TextEditingController(text: point?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          point == null ? 'Thêm điểm giao dịch' : 'Sửa điểm giao dịch',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên điểm giao dịch',
              border: OutlineInputBorder(),
              hintText: 'VD: Bến xe Miền Đông',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập tên điểm giao dịch';
              }
              return null;
            },
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
                final newPoint = TransactionPoint(
                  id: point?.id,
                  name: nameController.text,
                  createdAt: point?.createdAt ?? DateTime.now(),
                );

                if (point == null) {
                  await _db.insertTransactionPoint(newPoint);
                } else {
                  await _db.updateTransactionPoint(newPoint);
                }

                if (mounted) {
                  Navigator.pop(context);
                  _loadPoints();
                }
              }
            },
            child: Text(point == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    );
  }

  void _deletePoint(TransactionPoint point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${point.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _db.deleteTransactionPoint(point.id!);
              if (mounted) {
                Navigator.pop(context);
                _loadPoints();
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _points.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có điểm giao dịch nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _points.length,
              itemBuilder: (context, index) {
                final p = _points[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: Icon(Icons.location_on, color: Colors.orange[700]),
                    ),
                    title: Text(p.name),
                    subtitle: Text('ID: ${p.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddEditDialog(point: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePoint(p),
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
        label: const Text('Thêm điểm GD'),
      ),
    );
  }
}
