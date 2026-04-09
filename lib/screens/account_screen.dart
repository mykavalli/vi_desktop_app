import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive_api;
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import '../services/google_drive_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService.instance;
  final _db = DatabaseHelper.instance;
  final _driveService = GoogleDriveService.instance;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _googleClientIdController = TextEditingController();
  final _googleClientSecretController = TextEditingController();
  final _googleFormKey = GlobalKey<FormState>();

  final _oldPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isBackupLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGoogleCredentials();
  }

  Future<void> _loadGoogleCredentials() async {
    final user = await _db.getUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _googleClientIdController.text = user.googleClientId ?? '';
          _googleClientSecretController.text = user.googleClientSecret ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _googleClientIdController.dispose();
    _googleClientSecretController.dispose();
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

  Future<void> _saveGoogleCredentials() async {
    if (!_googleFormKey.currentState!.validate()) return;

    setState(() => _isGoogleLoading = true);

    final success = await _db.updateGoogleCredentials(
      _googleClientIdController.text,
      _googleClientSecretController.text,
    );

    if (mounted) {
      setState(() => _isGoogleLoading = false);
      if (success > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu cấu hình Google thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu cấu hình thất bại!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== SAO LƯU & KHÔI PHỤC ====================

  void _restartApp() {
    // Restart app trên Windows
    Process.start(Platform.resolvedExecutable, []).then((_) {
      exit(0);
    });
  }

  Future<void> _exportLocalBackup() async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn nơi lưu bản sao lưu',
        fileName: 'vi_desktop_backup_${DateTime.now().millisecondsSinceEpoch}.db',
        type: FileType.any,
      );

      if (outputFile == null) return;

      final dbPath = await _db.getDatabasePath();
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        await dbFile.copy(outputFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xuất dữ liệu thành công!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xuất dữ liệu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importLocalBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Chọn file database (.db) để khôi phục',
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;

      final backupPath = result.files.single.path!;
      
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận khôi phục'),
          content: const Text('Toàn bộ dữ liệu hiện tại sẽ bị thay thế. Bạn có chắc chắn muốn thực hiện?'),
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
              content: const Text('Ứng dụng cần khởi động lại để áp dụng dữ liệu mới.'),
              actions: [
                ElevatedButton(onPressed: () => _restartApp(), child: const Text('Đồng ý')),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Khôi phục thất bại!'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _listAndRestoreFromDrive() async {
    try {
      setState(() => _isBackupLoading = true);
      
      if (!_driveService.isAuthenticated) {
        await _driveService.authenticate();
      }

      final files = await _driveService.listBackups();
      
      if (mounted) {
        setState(() => _isBackupLoading = false);
        if (files.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy bản sao lưu nào trên Drive.')),
          );
          return;
        }

        // Show dialog list
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bản sao lưu trên Google Drive'),
            content: SizedBox(
              width: 400,
              height: 300,
              child: ListView.separated(
                itemCount: files.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final file = files[index];
                  final name = file.name ?? 'Unknown';
                  final date = file.createdTime != null 
                      ? file.createdTime!.toLocal().toString().split('.')[0]
                      : 'N/A';
                  final size = file.size != null 
                      ? '${(int.parse(file.size!) / 1024).toStringAsFixed(1)} KB'
                      : '';

                  return ListTile(
                    title: Text(name),
                    subtitle: Text('Ngày tạo: $date \nDung lượng: $size'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.settings_backup_restore, color: Colors.blue),
                    onTap: () {
                      Navigator.pop(ctx);
                      _restoreFromDrive(file);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi Drive: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreFromDrive(drive_api.File driveFile) async {
    if (driveFile.id == null || driveFile.name == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận khôi phục'),
        content: Text('Bạn có chắc chắn muốn khôi phục dữ liệu từ bản sao lưu "${driveFile.name}"?'),
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

    try {
      setState(() => _isBackupLoading = true);
      
      final tempFile = await _driveService.downloadBackup(driveFile.id!, driveFile.name!);
      final success = await _db.restoreFromFile(tempFile.path);

      if (mounted) {
        setState(() => _isBackupLoading = false);
        if (success) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Khôi phục thành công'),
              content: const Text('Dữ liệu đã được khôi phục từ Google Drive. Ứng dụng cần khởi động lại.'),
              actions: [
                ElevatedButton(onPressed: () => _restartApp(), child: const Text('Đồng ý')),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Khôi phục dữ liệu thất bại!'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi khôi phục: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBackupSection(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.settings_backup_restore,
          size: 80,
          color: Colors.green[600],
        ),
        const SizedBox(height: 24),
        Text(
          'Sao lưu & Khôi phục',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Quản lý dữ liệu hệ thống (Google Drive & Local)',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Google Drive',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isBackupLoading ? null : _listAndRestoreFromDrive,
                    icon: _isBackupLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.list_alt),
                    label: const Text('Danh sách bản sao lưu trên Drive'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storage, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Bản lưu cục bộ (Local)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                        onPressed: _isBackupLoading ? null : _exportLocalBackup,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Xuất file'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange),
                        onPressed: _isBackupLoading ? null : _importLocalBackup,
                        icon: const Icon(Icons.file_download),
                        label: const Text('Nhập file'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSection(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_reset,
          size: 80,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 24),
        Text(
          'Đổi mật khẩu',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Thay đổi mật khẩu đăng nhập hệ thống',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
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
                      _isOldPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isOldPasswordVisible = !_isOldPasswordVisible;
                      });
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
              const SizedBox(height: 16),
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
                      _isNewPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewPasswordVisible = !_isNewPasswordVisible;
                      });
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
              const SizedBox(height: 16),
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
                      _isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _changePassword,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Đang xử lý...' : 'Đổi mật khẩu'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSection(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.cloud_upload,
          size: 80,
          color: Colors.blue[600],
        ),
        const SizedBox(height: 24),
        Text(
          'Kết nối Google Drive',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Cấu hình Client ID để cho phép sao lưu dữ liệu tự động',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Form(
          key: _googleFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _googleClientIdController,
                decoration: const InputDecoration(
                  labelText: 'Google Client ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.api),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập Client ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _googleClientSecretController,
                decoration: const InputDecoration(
                  labelText: 'Google Client Secret (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isGoogleLoading ? null : _saveGoogleCredentials,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_done),
                  label: Text(
                      _isGoogleLoading ? 'Đang xử lý...' : 'Lưu cấu hình Google'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPasswordSection(context)),
                      const SizedBox(width: 32),
                      Container(width: 1, height: 600, color: Colors.grey[300]),
                      const SizedBox(width: 32),
                      Expanded(child: _buildGoogleSection(context)),
                      const SizedBox(width: 32),
                      Container(width: 1, height: 600, color: Colors.grey[300]),
                      const SizedBox(width: 32),
                      Expanded(child: _buildBackupSection(context)),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      _buildPasswordSection(context),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      _buildGoogleSection(context),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      _buildBackupSection(context),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
