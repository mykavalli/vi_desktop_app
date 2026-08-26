import 'package:flutter/material.dart';
import 'personnel_screen.dart';
// removed job_position_screen
import 'transaction_point_screen.dart';
import 'timekeeping_screen.dart';
import 'timekeeping_detail_screen.dart';
import 'timekeeping_summary_screen.dart';
import 'account_screen.dart';
import 'login_screen.dart';
import 'guide_screen.dart';
import 'package:window_manager/window_manager.dart';
import '../services/update_service.dart';
import '../database/database_helper.dart';
import 'dart:io';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindow();
    _initServices();
  }

  Future<void> _initServices() async {
    // Tự động kiểm tra bản cập nhật mới trong nền
    _checkUpdateOnStartup();
  }

  Future<void> _checkUpdateOnStartup() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      final update = await UpdateService.instance.checkForUpdates();
      if (update != null && mounted) {
        UpdateService.instance.showUpdateDialog(context, update);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    windowManager.setPreventClose(false);
    super.dispose();
  }

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      _showExitDialog();
    }
  }

  Future<void> _showExitDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thoát'),
        content: const Text('Bạn có muốn tạo bản sao lưu dữ liệu vào máy trước khi thoát không?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await windowManager.setPreventClose(false);
              windowManager.removeListener(this);
              await windowManager.destroy();
              exit(0);
            },
            child: const Text('Không, thoát ngay'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _performBackupAndExit();
            },
            child: const Text('Có, sao lưu và thoát'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackupAndExit() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tạo bản sao lưu dữ liệu...'),
          ],
        ),
      ),
    );

    try {
      await DatabaseHelper.instance.createBackupFile();

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        // Show success briefly
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 48),
                SizedBox(height: 16),
                Text('Sao lưu dữ liệu thành công!'),
                Text('Ứng dụng đang đóng...'),
              ],
            ),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 1000));
        await windowManager.setPreventClose(false);
        windowManager.removeListener(this);
        await windowManager.destroy();
        exit(0);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi sao lưu: $e')),
        );
      }
      await Future.delayed(const Duration(seconds: 1));
      await windowManager.setPreventClose(false);
      windowManager.removeListener(this);
      await windowManager.destroy();
      exit(0);
    }
  }

  void _navigate(int index) {
    setState(() => _selectedIndex = index);
  }

  List<Widget> get _screens => [
    _DashboardView(onNavigate: _navigate),
    const PersonnelScreen(),
    const TransactionPointScreen(),
    const TimekeepingScreen(),
    const TimekeepingDetailScreen(),
    TimekeepingSummaryScreen(onNavigate: _navigate),
    const AccountScreen(),
    const GuideScreen(),
  ];

  final List<String> _titles = [
    'Trang chủ',
    'Quản lý Nhân sự',
    'Quản lý Điểm giao dịch',
    'Chấm công',
    'Chấm công chi tiết',
    'Chấm công tổng hợp',
    'Tài khoản',
    'Hướng dẫn sử dụng',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: PopupMenuButton<int>(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
            onSelected: (value) {
              if (value == 8) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              } else {
                setState(() {
                  _selectedIndex = value;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: ListTile(
                  leading: Icon(Icons.dashboard),
                  title: Text('Trang chủ'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Quản lý Nhân sự'),
                  textColor: _selectedIndex == 1 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 1 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Quản lý Điểm giao dịch'),
                  textColor: _selectedIndex == 2 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 2 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 3,
                child: ListTile(
                  leading: const Icon(Icons.edit_calendar),
                  title: const Text('Chấm công'),
                  textColor: _selectedIndex == 3 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 3 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 4,
                child: ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text('Chấm công chi tiết'),
                  textColor: _selectedIndex == 4 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 4 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 5,
                child: ListTile(
                  leading: const Icon(Icons.summarize),
                  title: const Text('Chấm công tổng hợp'),
                  textColor: _selectedIndex == 5 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 5 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 6,
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Tài khoản'),
                  textColor: _selectedIndex == 6 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 6 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 7,
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Hướng dẫn'),
                  textColor: _selectedIndex == 7 ? Theme.of(context).primaryColor : null,
                  iconColor: _selectedIndex == 7 ? Theme.of(context).primaryColor : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 8,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Đăng xuất'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final Function(int) onNavigate;

  const _DashboardView({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_center,
            size: 100,
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Vi Desktop App',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hệ thống quản lý chấm công',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _QuickActionCard(
                icon: Icons.people,
                title: 'Nhân sự',
                color: Colors.blue,
                onTap: () => onNavigate(1),
              ),
              _QuickActionCard(
                icon: Icons.location_on,
                title: 'Điểm GD',
                color: Colors.orange,
                onTap: () => onNavigate(2),
              ),
              _QuickActionCard(
                icon: Icons.edit_calendar,
                title: 'Chấm công',
                color: Colors.purple,
                onTap: () => onNavigate(3),
              ),
              _QuickActionCard(
                icon: Icons.list_alt,
                title: 'Chi tiết CC',
                color: Colors.teal,
                onTap: () => onNavigate(4),
              ),
              _QuickActionCard(
                icon: Icons.summarize,
                title: 'Tổng hợp CC',
                color: Colors.indigo,
                onTap: () => onNavigate(5),
              ),
              _QuickActionCard(
                icon: Icons.settings,
                title: 'Tài khoản',
                color: Colors.blueGrey,
                onTap: () => onNavigate(6),
              ),
              _QuickActionCard(
                icon: Icons.help_outline,
                title: 'Hướng dẫn',
                color: Colors.brown,
                onTap: () => onNavigate(7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          height: 120,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
