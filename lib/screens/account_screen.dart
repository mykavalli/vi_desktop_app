import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import '../services/update_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService.instance;
  final _db = DatabaseHelper.instance;
  final _updateService = UpdateService.instance;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isBackupLoading = false;
  bool _isCheckingUpdate = false;

  String _backupFolderPath = '';
  List<File> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _updateService.loadInstalledVersion();
    final folderPath = await _db.getBackupDirectoryPath();
    final files = await _db.listLocalBackupFiles();
    if (mounted) {
      setState(() {
        _backupFolderPath = folderPath;
        _backupFiles = files;
      });
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await _authService.changePassword(
      _oldPasswordController.text,
      _newPasswordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mật khẩu cũ không đúng!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== QUẢN LÝ THƯ MỤC & SAO LƯU ====================

  Future<void> _chooseBackupFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Chọn thư mục lưu file sao lưu',
        initialDirectory: _backupFolderPath.isNotEmpty ? _backupFolderPath : null,
      );

      if (selectedDirectory != null) {
        await _db.setBackupDirectoryPath(selectedDirectory);
        final files = await _db.listLocalBackupFiles();
        if (mounted) {
          setState(() {
            _backupFolderPath = selectedDirectory;
            _backupFiles = files;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã cập nhật thư mục sao lưu: $selectedDirectory'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn thư mục: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openBackupFolder() {
    if (_backupFolderPath.isNotEmpty) {
      Process.run('explorer.exe', [_backupFolderPath]);
    }
  }

  Future<void> _createBackupNow() async {
    setState(() => _isBackupLoading = true);
    try {
      final file = await _db.createBackupFile();
      final files = await _db.listLocalBackupFiles();

      if (mounted) {
        setState(() {
          _isBackupLoading = false;
          _backupFiles = files;
        });

        if (file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tạo bản sao lưu mới thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể tạo file sao lưu. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo sao lưu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportCustomBackup() async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn nơi lưu bản sao lưu',
        fileName: 'vi_desktop_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db',
        type: FileType.any,
      );

      if (outputFile == null) return;

      final dbPath = await _db.getDatabasePath();
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        await dbFile.copy(outputFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xuất file sao lưu thành công!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xuất file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importCustomBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Chọn file database (.db) để khôi phục',
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;

      final backupPath = result.files.single.path!;
      await _restoreDatabase(backupPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreDatabase(String backupPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận khôi phục dữ liệu'),
        content: const Text('Toàn bộ dữ liệu hiện tại sẽ bị thay thế bằng bản sao lưu này. Bạn có chắc chắn muốn tiếp tục?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Khôi phục', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isBackupLoading = true);
    
    final success = await _db.restoreFromFile(backupPath);
    
    if (mounted) {
      setState(() => _isBackupLoading = false);
      if (success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Khôi phục thành công'),
            content: const Text('Dữ liệu đã được khôi phục. Ứng dụng sẽ tự khởi động lại để áp dụng dữ liệu mới.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Process.start(Platform.resolvedExecutable, []).then((_) => exit(0));
                },
                child: const Text('Đồng ý'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khôi phục dữ liệu thất bại!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản sao lưu'),
        content: Text('Bạn có chắc muốn xóa file "${file.uri.pathSegments.last}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final success = await _db.deleteLocalBackup(file.path);
    if (success) {
      final files = await _db.listLocalBackupFiles();
      if (mounted) {
        setState(() => _backupFiles = files);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bản sao lưu.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  // ==================== CẬP NHẬT ỨNG DỤNG ====================

  Future<void> _checkAppUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final update = await _updateService.checkForUpdates();
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        if (update != null) {
          if (!mounted) return;
          await _updateService.showUpdateDialog(context, update);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bạn đang sử dụng phiên bản mới nhất (v${UpdateService.currentVersion})!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kiểm tra cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== GIAO DIỆN ====================

  Widget _buildUpdateSection(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.system_update_alt, color: Colors.indigo.shade700, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Cập nhật ứng dụng',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'v${_updateService.currentAppVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kiểm tra và tự động cài đặt bản vá mới nhất từ Git repository',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _isCheckingUpdate ? null : _checkAppUpdate,
              icon: _isCheckingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_isCheckingUpdate ? 'Đang kiểm tra...' : 'Kiểm tra cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_reset, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Đổi mật khẩu đăng nhập',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Thay đổi mật khẩu tài khoản quản trị hệ thống',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _oldPasswordController,
                    focusNode: _oldPasswordFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_newPasswordFocus),
                    obscureText: !_isOldPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu cũ',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isOldPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _isOldPasswordVisible = !_isOldPasswordVisible);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu cũ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newPasswordController,
                    focusNode: _newPasswordFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_confirmPasswordFocus),
                    obscureText: !_isNewPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _isNewPasswordVisible = !_isNewPasswordVisible);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu mới';
                      }
                      if (value.length < 4) {
                        return 'Mật khẩu phải có ít nhất 4 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _changePassword(),
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu mới';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _changePassword,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Đang xử lý...' : 'Cập nhật mật khẩu'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_zip, color: Colors.teal.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sao lưu & Khôi phục dữ liệu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tự động lưu và quản lý các bản sao lưu SQLite trên máy tính của bạn',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mục Thư mục sao lưu
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Thư mục lưu trữ tự động:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _chooseBackupFolder,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Đổi thư mục', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Mở thư mục trong Explorer',
                        onPressed: _openBackupFolder,
                        icon: const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _backupFolderPath.isNotEmpty ? _backupFolderPath : 'Đang tải...',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Các nút thao tác
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isBackupLoading ? null : _createBackupNow,
                    icon: _isBackupLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: const Text('Sao lưu ngay vào thư mục'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _isBackupLoading ? null : _exportCustomBackup,
                    icon: const Icon(Icons.file_upload, size: 18),
                    label: const Text('Xuất file riêng'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isBackupLoading ? null : _importCustomBackup,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Khôi phục file'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Danh sách các bản sao lưu gần đây
            Row(
              children: [
                const Icon(Icons.history, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Các bản sao lưu trong thư mục (${_backupFiles.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: _backupFiles.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có bản sao lưu nào. Bấm "Sao lưu ngay" để tạo bản lưu đầu tiên.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _backupFiles.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _backupFiles[index];
                        final name = file.uri.pathSegments.last;
                        final stat = file.statSync();
                        final backupTime = DatabaseHelper.getBackupFileTimestamp(file);
                        final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(backupTime);
                        final sizeKb = (stat.size / 1024).toStringAsFixed(1);

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.storage, color: Colors.teal),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('Thời gian: $dateStr • Dung lượng: $sizeKb KB', style: const TextStyle(fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                onPressed: _isBackupLoading ? null : () => _restoreDatabase(file.path),
                                icon: const Icon(Icons.settings_backup_restore, size: 16),
                                label: const Text('Khôi phục', style: TextStyle(fontSize: 12)),
                              ),
                              IconButton(
                                tooltip: 'Xóa bản lưu này',
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: _isBackupLoading ? null : () => _deleteBackup(file),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 960;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUpdateSection(context),
                    const SizedBox(height: 20),

                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildPasswordSection(context)),
                          const SizedBox(width: 20),
                          Expanded(flex: 3, child: _buildBackupSection(context)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildPasswordSection(context),
                          const SizedBox(height: 20),
                          _buildBackupSection(context),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}