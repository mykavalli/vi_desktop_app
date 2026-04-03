import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/personnel.dart';
import '../models/job_position.dart';
import '../models/transaction_point.dart';
import '../models/timekeeping.dart';

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        password_hash TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE personnel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        basic_salary REAL NOT NULL,
        is_active INTEGER DEFAULT 1,
        is_working INTEGER DEFAULT 1,
        driver_license TEXT,
        start_date TEXT,
        deposit REAL,
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
    required int year,
    required int month,
    int? personnelId,
  }) async {
    final db = await database;
    String where = "strftime('%Y', t.date) = ? AND strftime('%m', t.date) = ?";
    List<dynamic> whereArgs = [
      year.toString(),
      month.toString().padLeft(2, '0'),
    ];

    if (personnelId != null) {
      where += ' AND t.personnel_id = ?';
      whereArgs.add(personnelId);
    }

    final result = await db.rawQuery('''
      SELECT 
        t.id as timekeeping_id,
        t.personnel_id,
        p.name as personnel_name,
        p.is_working as personnel_is_working,
        t.date,
        t.job_position_id,
        jp.name as job_position_name,
        t.transaction_point_id,
        tp.name as transaction_point_name,
        t.day_status
      FROM timekeeping t
      INNER JOIN personnel p ON t.personnel_id = p.id
      INNER JOIN job_positions jp ON t.job_position_id = jp.id
      INNER JOIN transaction_points tp ON t.transaction_point_id = tp.id
      WHERE $where
      ORDER BY t.date ASC, p.name ASC
    ''', whereArgs);

    return result.map((map) => TimekeepingDetail.fromMap(map)).toList();
  }

  Future<List<TimekeepingSummary>> getTimekeepingSummary({
    required int year,
    required int month,
    int? personnelId,
  }) async {
    final db = await database;

    String where = "strftime('%Y', t.date) = ? AND strftime('%m', t.date) = ?";
    List<dynamic> whereArgs = [
      year.toString(),
      month.toString().padLeft(2, '0'),
    ];

    if (personnelId != null) {
      where += ' AND t.personnel_id = ?';
      whereArgs.add(personnelId);
    }

    final result = await db.rawQuery('''
      SELECT 
        t.personnel_id,
        t.job_position_id,
        p.name as personnel_name,
        p.is_working as personnel_is_working,
        p.basic_salary as basic_salary,
        jp.salary as position_salary,
        jp.name as position_name,
        tp.name as transaction_point_name,
        t.date,
        t.day_status
      FROM timekeeping t
      INNER JOIN personnel p ON t.personnel_id = p.id
      INNER JOIN transaction_points tp ON t.transaction_point_id = tp.id
      INNER JOIN job_positions jp ON t.job_position_id = jp.id
      WHERE $where
      ORDER BY p.name ASC, tp.name ASC
    ''', whereArgs);

    Map<int, Map<String, dynamic>> summaryMap = {};

    for (var row in result) {
      final pId = row['personnel_id'] as int;
      final jobPositionId = row['job_position_id'] as int;
      final personnelName = row['personnel_name'] as String;
      final basicSalary = (row['basic_salary'] as num).toDouble();
      final positionSalary = (row['position_salary'] as num).toDouble();
      final tpName = row['transaction_point_name'] as String;
      final date = row['date'] as String;
      final dayStatus = row['day_status'] as String? ?? DayStatus.work;
      final isWorking = (row['personnel_is_working'] as int? ?? 1) == 1;

      if (!summaryMap.containsKey(pId)) {
        summaryMap[pId] = {
          'personnel_id': pId,
          'personnel_name': personnelName,
          'basic_salary': basicSalary,
          'is_working': isWorking,
          // Map<jobPositionId, {salary, uniqueDates: Set<String>}>
          'positions': <int, Map<String, dynamic>>{},
          // Map<tpName, Set<date>> — for display column per transaction point
          'unique_work_dates_by_tp': <String, Set<String>>{},
          'phep_dates': <String>{},
          'kphep_dates': <String>{},
        };
      }

      final pMap = summaryMap[pId]!;

      if (dayStatus == DayStatus.work) {
        // Track per-position unique work dates (for correct salary calc)
        final positions = pMap['positions'] as Map<int, Map<String, dynamic>>;
        if (!positions.containsKey(jobPositionId)) {
          positions[jobPositionId] = {
            'salary': positionSalary,
            'dates': <String>{},
          };
        }
        (positions[jobPositionId]!['dates'] as Set<String>).add(date);

        // Track per-transaction-point unique work dates (for display columns)
        final workDatesByTp =
            pMap['unique_work_dates_by_tp'] as Map<String, Set<String>>;
        if (!workDatesByTp.containsKey(tpName)) {
          workDatesByTp[tpName] = <String>{};
        }
        workDatesByTp[tpName]!.add(date);
      } else if (dayStatus == DayStatus.phep) {
        (pMap['phep_dates'] as Set<String>).add(date);
      } else if (dayStatus == DayStatus.kphep) {
        (pMap['kphep_dates'] as Set<String>).add(date);
      }
    }

    return summaryMap.values.map((data) {
      final workDatesByTp =
          data['unique_work_dates_by_tp'] as Map<String, Set<String>>;
      final daysByTransactionPoint =
          workDatesByTp.map((key, value) => MapEntry(key, value.length));

      final totalDays = daysByTransactionPoint.values.fold(0, (a, b) => a + b);
      final totalDaysOff = (data['phep_dates'] as Set<String>).length;
      final totalDaysUnauth = (data['kphep_dates'] as Set<String>).length;

      final double basicSalary = data['basic_salary'] as double;

      // Correct salary: basicSalary + Σ(position.salary × uniqueWorkDays per position)
      // This avoids double-counting the same day across multiple transaction points
      final positions = data['positions'] as Map<int, Map<String, dynamic>>;
      double totalPositionSalary = 0.0;
      for (var posEntry in positions.values) {
        final salary = (posEntry['salary'] as num).toDouble();
        final days = (posEntry['dates'] as Set<String>).length;
        totalPositionSalary += salary * days;
      }

      final double totalSalary = basicSalary + totalPositionSalary;

      return TimekeepingSummary(
        personnelId: data['personnel_id'],
        personnelName: data['personnel_name'],
        isWorking: data['is_working'] as bool,
        totalDays: totalDays,
        totalDaysOff: totalDaysOff,
        totalDaysUnauth: totalDaysUnauth,
        daysByTransactionPoint: daysByTransactionPoint,
        totalSalary: totalSalary,
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

  Future<int> deleteTimekeepingByDate(int personnelId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    return await db.delete(
      'timekeeping',
      where: 'personnel_id = ? AND date = ?',
      whereArgs: [personnelId, dateStr],
    );
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
}
