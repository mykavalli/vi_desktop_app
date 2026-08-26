import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive_api;
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import '../services/google_drive_service.dart';
import '../services/update_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService.instance;
  final _db = DatabaseHelper.instance;
  final _driveService = GoogleDriveService.instance;
  final _updateService = UpdateService.instance;

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
  bool _isCheckingUpdate = false;
  bool _showAdvancedGoogleConfig = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadGoogleCredentials();
    // Tự động khôi phục phiên đăng nhập Google nếu đã lưu trước đó
    if (!_driveService.isAuthenticated) {
      await _driveService.restoreSession();
      if (mounted) setState(() {});
    }
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

  Future<void> _loginGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final success = await _driveService.authenticate();
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đăng nhập Google thành công! (${_driveService.currentUserEmail ?? ""})',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập Google thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOutGoogle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất Google'),
        content: const Text('Bạn có chắc muốn đăng xuất tài khoản Google khỏi ứng dụng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isGoogleLoading = true);
    await _driveService.signOut();
    if (mounted) {
      setState(() => _isGoogleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đăng xuất tài khoản Google.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveGoogleCredentials() async {
    if (!_googleFormKey.currentState!.validate()) return;

    setState(() => _isGoogleLoading = true);

    final success = await _db.updateGoogleCredentials(
      _googleClientIdController.text.trim(),
      _googleClientSecretController.text.trim(),
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

  Future<void> _backupToDriveNow() async {
    setState(() => _isBackupLoading = true);
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File('$dbPath/vi_desktop_app.db');

      if (!await dbFile.exists()) {
        throw Exception('Không tìm thấy file database!');
      }

      final res = await _driveService.uploadBackup(dbFile);
      if (mounted) {
        setState(() => _isBackupLoading = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sao lưu lên Google Drive thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sao lưu thất bại. Vui lòng kiểm tra kết nối Google!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi sao lưu Drive: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

  // ==================== SAO LƯU & KHÔI PHỤC ====================

  void _restartApp() {
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
      
      if (!mounted) return;
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

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bản sao lưu trên Google Drive'),
            content: SizedBox(
              width: 450,
              height: 320,
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
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Ngày tạo: $date\nDung lượng: $size'),
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

  // ==================== UI SECTIONS ====================

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

  Widget _buildGoogleSection(BuildContext context) {
    final isAuth = _driveService.isAuthenticated;
    final email = _driveService.currentUserEmail;

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
                Icon(Icons.cloud_sync, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tài khoản Google Drive',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Dùng để tự động sao lưu dữ liệu SQLite lên Google Drive',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Trạng thái kết nối Google
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAuth ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAuth ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAuth ? Icons.check_circle : Icons.account_circle_outlined,
                    color: isAuth ? Colors.green.shade700 : Colors.grey.shade600,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAuth ? 'Đã kết nối Google Drive' : 'Chưa đăng nhập Google',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAuth ? Colors.green.shade900 : Colors.grey.shade800,
                            fontSize: 14,
                          ),
                        ),
                        if (isAuth && email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                          )
                        else if (!isAuth)
                          Text(
                            'Đăng nhập để tự động lưu phiên và sao lưu dữ liệu',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Nút đăng nhập / đăng xuất
            if (!isAuth)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isGoogleLoading ? null : _loginGoogle,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_isGoogleLoading ? 'Đang mở trình duyệt...' : 'Đăng nhập với Google'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isBackupLoading ? null : _backupToDriveNow,
                      icon: _isBackupLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: const Text('Sao lưu ngay'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: _isGoogleLoading ? null : _signOutGoogle,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),

            const SizedBox(height: 14),

            // Mục tùy chọn nâng cao Google Client ID
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() => _showAdvancedGoogleConfig = !_showAdvancedGoogleConfig);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Icon(
                      _showAdvancedGoogleConfig ? Icons.arrow_drop_down : Icons.arrow_right,
                      color: Colors.grey.shade700,
                    ),
                    Text(
                      'Cấu hình Google Client ID (Nâng cao)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showAdvancedGoogleConfig) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '💡 Hệ thống đã tích hợp sẵn Client ID mặc định. Bạn không cần điền phần này trừ khi muốn dùng Project Google Cloud riêng của doanh nghiệp.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 10),
              Form(
                key: _googleFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _googleClientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Google Client ID (Để trống nếu dùng mặc định)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.api, size: 20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _googleClientSecretController,
                      decoration: const InputDecoration(
                        labelText: 'Google Client Secret (Tùy chọn)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.vpn_key, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGoogleLoading ? null : _saveGoogleCredentials,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Lưu Client ID riêng'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Mở trang Google Cloud Console để tạo Client ID',
                          onPressed: () {
                            launchUrl(
                              Uri.parse('https://console.cloud.google.com/apis/credentials'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
                Icon(Icons.settings_backup_restore, color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sao lưu & Khôi phục dữ liệu',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Quản lý dữ liệu hệ thống (Google Drive & File cục bộ)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Google Drive Backups
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_queue, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Google Drive Cloud Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isBackupLoading ? null : _listAndRestoreFromDrive,
                      icon: _isBackupLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.history),
                      label: const Text('Xem danh sách bản lưu trên Drive & Khôi phục'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Local Backups
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage, color: Colors.teal, size: 20),
                      SizedBox(width: 8),
                      Text('Bản lưu cục bộ (Máy tính)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                          onPressed: _isBackupLoading ? null : _exportLocalBackup,
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Xuất file (.db)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange),
                          onPressed: _isBackupLoading ? null : _importLocalBackup,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Khôi phục file'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                          'v${UpdateService.currentVersion}',
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
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh thông tin Update phía trên
                    _buildUpdateSection(context),
                    const SizedBox(height: 20),

                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPasswordSection(context)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildGoogleSection(context)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildBackupSection(context)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildPasswordSection(context),
                          const SizedBox(height: 20),
                          _buildGoogleSection(context),
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
