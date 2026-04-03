import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/transaction_point.dart';
import '../state/app_state.dart';

class TransactionPointScreen extends StatefulWidget {
  const TransactionPointScreen({super.key});

  @override
  State<TransactionPointScreen> createState() => _TransactionPointScreenState();
}

class _TransactionPointScreenState extends State<TransactionPointScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<TransactionPoint> _points = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<TransactionPoint> get _filtered {
    if (_searchQuery.isEmpty) return _points;
    final q = _searchQuery.toLowerCase();
    return _points.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPoints();
    AppState.instance.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    AppState.instance.dataVersion.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
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

    Future<void> onSave() async {
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

        AppState.instance.refresh();

        if (mounted) {
          Navigator.pop(context);
          _loadPoints();
        }
      }
    }

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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSave(),
            autofocus: true,
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
            onPressed: onSave,
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
              AppState.instance.refresh();
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
    final filtered = _filtered;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tìm kiếm điểm giao dịch',
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
                            Icon(Icons.location_off,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Không tìm thấy "$_searchQuery"'
                                  : 'Chưa có điểm giao dịch nào',
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
                                backgroundColor: Colors.orange[100],
                                child: Icon(Icons.location_on,
                                    color: Colors.orange[700]),
                              ),
                              title: Text(p.name),
                              subtitle: Text('ID: ${p.id}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showAddEditDialog(point: p),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deletePoint(p),
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
          label: const Text('Thêm điểm GD'),
        ),
      ),
    );
  }
}
