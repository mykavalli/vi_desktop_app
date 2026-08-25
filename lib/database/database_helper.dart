import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/personnel.dart';
import '../models/job_position.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vi_desktop_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        password_hash TEXT NOT NULL,
        google_client_id TEXT,
        google_client_secret TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE personnel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        basic_salary REAL NOT NULL,
        cccd TEXT,
        role TEXT,
        is_active INTEGER DEFAULT 1,
        is_working INTEGER DEFAULT 1,
        driver_license TEXT,
        start_date TEXT,
        deposit REAL,
        seniority_salary REAL DEFAULT 0,
        additional_allowance REAL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE job_positions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        salary REAL NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE timekeeping (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        personnel_id INTEGER NOT NULL,
        date DATE NOT NULL,
        job_position_id INTEGER NOT NULL,
        transaction_point_id INTEGER NOT NULL,
        day_status TEXT NOT NULL DEFAULT 'work',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (personnel_id) REFERENCES personnel(id),
        FOREIGN KEY (job_position_id) REFERENCES job_positions(id),
        FOREIGN KEY (transaction_point_id) REFERENCES transaction_points(id)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add day_status column to existing timekeeping table
      try {
        await db.execute(
          "ALTER TABLE timekeeping ADD COLUMN day_status TEXT NOT NULL DEFAULT 'work'",
        );
      } catch (_) {
        // Column might already exist in some edge cases
      }
    }
    if (oldVersion < 3) {
      // Add new personnel columns
      final newCols = [
        "ALTER TABLE personnel ADD COLUMN is_working INTEGER DEFAULT 1",
        "ALTER TABLE personnel ADD COLUMN driver_license TEXT",
        "ALTER TABLE personnel ADD COLUMN start_date TEXT",
        "ALTER TABLE personnel ADD COLUMN deposit REAL",
      ];
      for (final sql in newCols) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column might already exist
        }
      }
    }
    if (oldVersion < 4) {
      // Add more personnel columns
      final newCols = [
        "ALTER TABLE personnel ADD COLUMN seniority_salary REAL DEFAULT 0",
        "ALTER TABLE personnel ADD COLUMN additional_allowance REAL DEFAULT 0",
      ];
      for (final sql in newCols) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column might already exist
        }
      }
    }
    if (oldVersion < 5) {
      // Add Google Drive credentials columns to users
      final newCols = [
        "ALTER TABLE users ADD COLUMN google_client_id TEXT",
        "ALTER TABLE users ADD COLUMN google_client_secret TEXT",
      ];
      for (final sql in newCols) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column might already exist
        }
      }
    }
    if (oldVersion < 6) {
      // Fix missing is_working and add cccd column
      final newCols = [
        "ALTER TABLE personnel ADD COLUMN is_working INTEGER DEFAULT 1",
        "ALTER TABLE personnel ADD COLUMN cccd TEXT",
      ];
      for (final sql in newCols) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column might already exist
        }
      }
    }
    if (oldVersion < 7) {
      // Add role to personnel, convert old timekeeping statuses
      try {
        await db.execute("ALTER TABLE personnel ADD COLUMN role TEXT");
      } catch (_) {}
      
      // Convert old statuses
      await db.execute("UPDATE timekeeping SET day_status = 'TX' WHERE day_status = 'work'");
      await db.execute("UPDATE timekeeping SET day_status = 'NP' WHERE day_status = 'phep'");
      await db.execute("UPDATE timekeeping SET day_status = 'KP' WHERE day_status = 'kphep'");
    }
    if (oldVersion < 8) {
      // Ensure role column exists if version 7 migration failed previously
      try {
        await db.execute("ALTER TABLE personnel ADD COLUMN role TEXT");
      } catch (_) {}
    }
    if (oldVersion < 9) {
      // Robust sanity check for all personnel columns
      final List<Map<String, dynamic>> columns = await db.rawQuery("PRAGMA table_info(personnel)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      final requiredColumns = {
        'cccd': "ALTER TABLE personnel ADD COLUMN cccd TEXT",
        'role': "ALTER TABLE personnel ADD COLUMN role TEXT",
        'is_working': "ALTER TABLE personnel ADD COLUMN is_working INTEGER DEFAULT 1",
        'driver_license': "ALTER TABLE personnel ADD COLUMN driver_license TEXT",
        'start_date': "ALTER TABLE personnel ADD COLUMN start_date TEXT",
        'deposit': "ALTER TABLE personnel ADD COLUMN deposit REAL",
        'seniority_salary': "ALTER TABLE personnel ADD COLUMN seniority_salary REAL DEFAULT 0",
        'additional_allowance': "ALTER TABLE personnel ADD COLUMN additional_allowance REAL DEFAULT 0",
      };

      for (var entry in requiredColumns.entries) {
        if (!columnNames.contains(entry.key)) {
          try {
            await db.execute(entry.value);
          } catch (e) {
            print("Error adding missing column ${entry.key}: $e");
          }
        }
      }
    }
  }

  // ==================== USER OPERATIONS ====================
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser() async {
    final db = await database;
    final maps = await db.query('users', limit: 1);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<int> updateUserPassword(String passwordHash) async {
    final db = await database;
    final user = await getUser();
    if (user == null) {
      return await insertUser(
        User(passwordHash: passwordHash, createdAt: DateTime.now()),
      );
    }
    return await db.update(
      'users',
      {'password_hash': passwordHash},
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> updateGoogleCredentials(String clientId, String clientSecret) async {
    final db = await database;
    final user = await getUser();
    if (user == null) {
      return await insertUser(
        User(
          passwordHash: '', // Will be handled properly when changing password
          googleClientId: clientId,
          googleClientSecret: clientSecret,
          createdAt: DateTime.now(),
        ),
      );
    }
    return await db.update(
      'users',
      {
        'google_client_id': clientId,
        'google_client_secret': clientSecret,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // ==================== PERSONNEL OPERATIONS ====================
  Future<int> insertPersonnel(Personnel personnel) async {
    final db = await database;
    return await db.insert('personnel', personnel.toMap());
  }

  /// [activeOnly] excludes soft-deleted records (is_active=0)
  /// [workingOnly] excludes resigned employees (is_working=0) — used for timekeeping dropdowns
  Future<List<Personnel>> getAllPersonnel({
    bool activeOnly = true,
    bool workingOnly = false,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (activeOnly && workingOnly) {
      where = 'is_active = ? AND is_working = ?';
      whereArgs = [1, 1];
    } else if (activeOnly) {
      where = 'is_active = ?';
      whereArgs = [1];
    } else if (workingOnly) {
      where = 'is_working = ?';
      whereArgs = [1];
    }

    final maps = await db.query(
      'personnel',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_working DESC, name ASC',
    );
    return maps.map((map) => Personnel.fromMap(map)).toList();
  }

  Future<Personnel?> getPersonnelById(int id) async {
    final db = await database;
    final maps = await db.query('personnel', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Personnel.fromMap(maps.first);
  }

  Future<int> updatePersonnel(Personnel personnel) async {
    final db = await database;
    return await db.update(
      'personnel',
      personnel.toMap(),
      where: 'id = ?',
      whereArgs: [personnel.id],
    );
  }

  Future<int> togglePersonnelWorkingStatus(int id, bool isWorking) async {
    final db = await database;
    return await db.update(
      'personnel',
      {'is_working': isWorking ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePersonnel(int id) async {
    final db = await database;
    return await db.update(
      'personnel',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== JOB POSITION OPERATIONS ====================
  Future<int> insertJobPosition(JobPosition position) async {
    final db = await database;
    return await db.insert('job_positions', position.toMap());
  }

  Future<List<JobPosition>> getAllJobPositions({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query(
      'job_positions',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return maps.map((map) => JobPosition.fromMap(map)).toList();
  }

  Future<JobPosition?> getJobPositionById(int id) async {
    final db = await database;
    final maps = await db.query(
      'job_positions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return JobPosition.fromMap(maps.first);
  }

  Future<int> updateJobPosition(JobPosition position) async {
    final db = await database;
    return await db.update(
      'job_positions',
      position.toMap(),
      where: 'id = ?',
      whereArgs: [position.id],
    );
  }

  Future<int> deleteJobPosition(int id) async {
    final db = await database;
    return await db.update(
      'job_positions',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== TRANSACTION POINT OPERATIONS ====================
  Future<int> insertTransactionPoint(TransactionPoint point) async {
    final db = await database;
    return await db.insert('transaction_points', point.toMap());
  }

  Future<List<TransactionPoint>> getAllTransactionPoints({
    bool activeOnly = true,
  }) async {
    final db = await database;
    final maps = await db.query(
      'transaction_points',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return maps.map((map) => TransactionPoint.fromMap(map)).toList();
  }

  Future<TransactionPoint?> getTransactionPointById(int id) async {
    final db = await database;
    final maps = await db.query(
      'transaction_points',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TransactionPoint.fromMap(maps.first);
  }

  Future<int> updateTransactionPoint(TransactionPoint point) async {
    final db = await database;
    return await db.update(
      'transaction_points',
      point.toMap(),
      where: 'id = ?',
      whereArgs: [point.id],
    );
  }

  Future<int> deleteTransactionPoint(int id) async {
    final db = await database;
    return await db.update(
      'transaction_points',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== TIMEKEEPING OPERATIONS ====================
  Future<int> insertTimekeeping(Timekeeping timekeeping) async {
    final db = await database;
    return await db.insert('timekeeping', timekeeping.toMap());
  }

  Future<void> insertMultipleTimekeeping(List<Timekeeping> timekeepings) async {
    final db = await database;
    final batch = db.batch();
    for (var tk in timekeepings) {
      batch.insert('timekeeping', tk.toMap());
    }
    await batch.commit();
  }

  Future<List<TimekeepingDetail>> getTimekeepingDetail({
    DateTime? startDate,
    DateTime? endDate,
    int? year,
    int? month,
    int? personnelId,
  }) async {
    final db = await database;
    String where;
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      final sStr = DateFormat('yyyy-MM-dd').format(startDate);
      final eStr = DateFormat('yyyy-MM-dd').format(endDate);
      where = "t.date >= ? AND t.date <= ?";
      whereArgs = [sStr, eStr];
    } else {
      where = "strftime('%Y', t.date) = ? AND strftime('%m', t.date) = ?";
      whereArgs = [
        (year ?? DateTime.now().year).toString(),
        (month ?? DateTime.now().month).toString().padLeft(2, '0'),
      ];
    }

    if (personnelId != null) {
      where += ' AND t.personnel_id = ?';
      whereArgs.add(personnelId);
    }

    final result = await db.rawQuery('''
      SELECT 
        t.id as timekeeping_id,
        t.personnel_id,
        COALESCE(p.name, 'N/A') as personnel_name,
        COALESCE(p.is_working, 1) as personnel_is_working,
        t.date,
        t.job_position_id,
        COALESCE(jp.name, 'N/A') as job_position_name,
        t.transaction_point_id,
        COALESCE(tp.name, 'N/A') as transaction_point_name,
        t.day_status
      FROM timekeeping t
      LEFT JOIN personnel p ON t.personnel_id = p.id
      LEFT JOIN job_positions jp ON t.job_position_id = jp.id
      LEFT JOIN transaction_points tp ON t.transaction_point_id = tp.id
      WHERE $where
      ORDER BY t.date ASC, COALESCE(p.name, '') ASC
    ''', whereArgs);

    return result.map((map) => TimekeepingDetail.fromMap(map)).toList();
  }

  Future<List<TimekeepingSummary>> getTimekeepingSummary({
    DateTime? startDate,
    DateTime? endDate,
    int? year,
    int? month,
    int? personnelId,
  }) async {
    final db = await database;

    String where;
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      final sStr = DateFormat('yyyy-MM-dd').format(startDate);
      final eStr = DateFormat('yyyy-MM-dd').format(endDate);
      where = "t.date >= ? AND t.date <= ?";
      whereArgs = [sStr, eStr];
    } else {
      where = "strftime('%Y', t.date) = ? AND strftime('%m', t.date) = ?";
      whereArgs = [
        (year ?? DateTime.now().year).toString(),
        (month ?? DateTime.now().month).toString().padLeft(2, '0'),
      ];
    }

    if (personnelId != null) {
      where += ' AND t.personnel_id = ?';
      whereArgs.add(personnelId);
    }

    final result = await db.rawQuery('''
      SELECT 
        t.personnel_id,
        COALESCE(p.name, 'N/A') as personnel_name,
        COALESCE(p.is_working, 1) as personnel_is_working,
        COALESCE(p.role, '') as personnel_role,
        COALESCE(tp.name, 'N/A') as transaction_point_name,
        t.date,
        t.day_status
      FROM timekeeping t
      LEFT JOIN personnel p ON t.personnel_id = p.id
      LEFT JOIN transaction_points tp ON t.transaction_point_id = tp.id
      WHERE $where
      ORDER BY COALESCE(p.name, '') ASC, COALESCE(tp.name, '') ASC
    ''', whereArgs);

    Map<int, Map<String, dynamic>> summaryMap = {};

    for (var row in result) {
      final pId = row['personnel_id'] as int;
      final personnelName = row['personnel_name'] as String;
      final personnelRole = row['personnel_role'] as String? ?? '';
      final isWorking = (row['personnel_is_working'] as int? ?? 1) == 1;
      final tpName = row['transaction_point_name'] as String? ?? 'N/A';
      final date = row['date'] as String? ?? '';
      final String dayStatus = row['day_status'] as String? ?? '';

      if (!summaryMap.containsKey(pId)) {
        summaryMap[pId] = {
          'personnel_id': pId,
          'personnel_name': personnelName,
          'personnel_role': personnelRole,
          'is_working': isWorking,
          'tx_dates_by_tp': <String, Set<String>>{},
          'px_dates': <String>{},
          'np_dates': <String>{},
          'kp_dates': <String>{},
          'all_working_dates': <String>{},
        };
      }

      final pMap = summaryMap[pId]!;

      if (dayStatus == 'TX') {
         final txDatesByTp = pMap['tx_dates_by_tp'] as Map<String, Set<String>>;
         if (!txDatesByTp.containsKey(tpName)) {
           txDatesByTp[tpName] = <String>{};
         }
         txDatesByTp[tpName]!.add(date);
         (pMap['all_working_dates'] as Set<String>).add(date);
      } else if (dayStatus == 'PX') {
         (pMap['px_dates'] as Set<String>).add(date);
         (pMap['all_working_dates'] as Set<String>).add(date);
      } else if (dayStatus == 'NP') {
         (pMap['np_dates'] as Set<String>).add(date);
      } else if (dayStatus == 'KP') {
         (pMap['kp_dates'] as Set<String>).add(date);
      }
    }

    return summaryMap.values.map((data) {
      final txDatesByTp = data['tx_dates_by_tp'] as Map<String, Set<String>>;
      final daysByTransactionPoint = txDatesByTp.map((key, value) => MapEntry(key, value.length));

      final totalPx = (data['px_dates'] as Set<String>).length;
      final totalDaysOff = (data['np_dates'] as Set<String>).length;
      final totalDaysUnauth = (data['kp_dates'] as Set<String>).length;
      final totalWorkingDays = (data['all_working_dates'] as Set<String>).length;

      return TimekeepingSummary(
        personnelId: data['personnel_id'],
        personnelName: data['personnel_name'],
        personnelRole: data['personnel_role'],
        isWorking: data['is_working'] as bool,
        totalWorkingDays: totalWorkingDays,
        totalPxDays: totalPx,
        totalDaysOff: totalDaysOff,
        totalDaysUnauth: totalDaysUnauth,
        txDaysByTransactionPoint: daysByTransactionPoint,
      );
    }).toList();
  }

  Future<List<Timekeeping>> getTimekeepingByDate({
    required int personnelId,
    required DateTime date,
  }) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'timekeeping',
      where: 'personnel_id = ? AND date = ?',
      whereArgs: [personnelId, dateStr],
    );
    return maps.map((map) => Timekeeping.fromMap(map)).toList();
  }

  Future<int> deleteTimekeeping(int id) async {
    final db = await database;
    return await db.delete('timekeeping', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTimekeepingByMonth({
    required int year,
    required int month,
    int? personnelId,
  }) async {
    final db = await database;
    String where = "strftime('%Y', date) = ? AND strftime('%m', date) = ?";
    List<dynamic> whereArgs = [
      year.toString(),
      month.toString().padLeft(2, '0'),
    ];

    if (personnelId != null) {
      where += ' AND personnel_id = ?';
      whereArgs.add(personnelId);
    }

    return await db.delete('timekeeping', where: where, whereArgs: whereArgs);
  }

  Future<int> deleteTimekeepingByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? personnelId,
  }) async {
    final db = await database;
    final sStr = DateFormat('yyyy-MM-dd').format(startDate);
    final eStr = DateFormat('yyyy-MM-dd').format(endDate);
    String where = "date >= ? AND date <= ?";
    List<dynamic> whereArgs = [sStr, eStr];

    if (personnelId != null) {
      where += ' AND personnel_id = ?';
      whereArgs.add(personnelId);
    }

    return await db.delete('timekeeping', where: where, whereArgs: whereArgs);
  }

  Future<int> deleteTimekeepingByDate(int personnelId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    return await db.delete(
      'timekeeping',
      where: 'personnel_id = ? AND date = ?',
      whereArgs: [personnelId, dateStr],
    );
  }

  Future<List<Timekeeping>> getTimekeepingByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final sStr = DateFormat('yyyy-MM-dd').format(startDate);
    final eStr = DateFormat('yyyy-MM-dd').format(endDate);
    final maps = await db.query(
      'timekeeping',
      where: "date >= ? AND date <= ?",
      whereArgs: [sStr, eStr],
    );
    return maps.map((map) => Timekeeping.fromMap(map)).toList();
  }

  Future<List<Timekeeping>> getTimekeepingByMonth({
    required int year,
    required int month,
  }) async {
    final db = await database;
    String where = "strftime('%Y', date) = ? AND strftime('%m', date) = ?";
    List<dynamic> whereArgs = [
      year.toString(),
      month.toString().padLeft(2, '0'),
    ];
    final maps = await db.query(
      'timekeeping',
      where: where,
      whereArgs: whereArgs,
    );
    return maps.map((map) => Timekeeping.fromMap(map)).toList();
  }

  Future close() async {
    final db = await database;
    db.close();
  }

  /// Đóng database connection và xóa singleton để có thể mở lại sau restore
  Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Lấy đường dẫn đầy đủ của file database hiện tại
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'vi_desktop_app.db');
  }

  /// Restore database từ file backup:
  /// 1. Đóng connection hiện tại
  /// 2. Copy file backup vào vị trí DB
  /// 3. Mở lại connection
  /// Trả về true nếu thành công
  Future<bool> restoreFromFile(String backupFilePath) async {
    try {
      await closeAndReset();

      final targetPath = await getDatabasePath();
      final backupFile = File(backupFilePath);

      if (!await backupFile.exists()) {
        throw Exception('File backup không tồn tại: $backupFilePath');
      }

      // Copy file backup vào vị trí database
      await backupFile.copy(targetPath);

      // Mở lại connection để verify
      _database = await _initDB('vi_desktop_app.db');

      return true;
    } catch (e) {
      print('Restore DB error: $e');
      // Cố gắng mở lại DB cũ nếu restore thất bại
      try {
        _database = await _initDB('vi_desktop_app.db');
      } catch (_) {}
      return false;
    }
  }
}
