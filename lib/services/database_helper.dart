import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/budget_model.dart';
import '../models/transaction_model.dart';

/// Loi cua tang du lieu - de UI hien thong bao than thien thay vi crash.
class LocalDatabaseException implements Exception {
  final String message;
  final Object? cause;

  const LocalDatabaseException(this.message, [this.cause]);

  @override
  String toString() => 'LocalDatabaseException: $message';
}

/// Tong thu/chi cua mot ngay - dung hien thi tren o lich.
class DailyTotal {
  final DateTime day;
  final double income;
  final double expense;

  const DailyTotal({
    required this.day,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
  bool get hasData => income > 0 || expense > 0;
}

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'expense_tracker.db';
  static const int _dbVersion = 2;

  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';
  static const String tableSettings = 'settings';

  /// Khoa cai dat da dung trong bang settings.
  static const String keyThemeMode = 'theme_mode';

  Database? _db;
  Completer<Database>? _opening;

  Future<Database> get database async {
    final Database? current = _db;
    if (current != null && current.isOpen) return current;

    // Chong mo DB nhieu lan song song (2 man hinh cung goi luc khoi dong).
    final Completer<Database>? pending = _opening;
    if (pending != null) return pending.future;

    final Completer<Database> completer = Completer<Database>();
    _opening = completer;
    try {
      final Database opened = await _open();
      _db = opened;
      completer.complete(opened);
      return opened;
    } catch (e, s) {
      completer.completeError(e, s);
      rethrow;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    try {
      final String dir = await getDatabasesPath();
      final String path = p.join(dir, _dbName);
      return await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
      );
    } catch (e) {
      throw LocalDatabaseException('Không mở được cơ sở dữ liệu cục bộ.', e);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();

    batch.execute('''
      CREATE TABLE $tableTransactions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL,
        amount      REAL    NOT NULL CHECK (amount >= 0),
        date        INTEGER NOT NULL,
        category_id TEXT    NOT NULL,
        type        INTEGER NOT NULL CHECK (type IN (0, 1)),
        note        TEXT    NOT NULL DEFAULT '',
        created_at  INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_transactions_date ON $tableTransactions (date DESC)
    ''');

    batch.execute('''
      CREATE INDEX idx_transactions_type ON $tableTransactions (type)
    ''');

    batch.execute('''
      CREATE TABLE $tableBudgets (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        year   INTEGER NOT NULL,
        month  INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
        amount REAL    NOT NULL CHECK (amount >= 0),
        UNIQUE (year, month) ON CONFLICT REPLACE
      )
    ''');

    batch.execute('''
      CREATE TABLE $tableSettings (
        setting_key   TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// ==========================================================================
  /// MIGRATION - GIU NGUYEN DU LIEU KHI CAI DE APK MOI
  /// ==========================================================================
  ///
  /// File .db nam trong /data/data/<applicationId>/databases/ — Android KHONG
  /// xoa thu muc nay khi cai de APK moi (chi xoa khi go app hoac Xoa du lieu).
  /// Vi vay du lieu tu dong duoc giu, mien la:
  ///   1. applicationId khong doi
  ///   2. APK moi ky bang DUNG keystore cua APK cu
  ///   3. Doi schema thi PHAI tang _dbVersion va viet migration o duoi
  ///
  /// QUY TAC VIET MIGRATION:
  /// - Moi lan doi cau truc bang: tang _dbVersion len 1 don vi.
  /// - Them mot khoi `if (oldVersion < N)` moi, KHONG sua khoi cu.
  /// - Chi dung ALTER TABLE ADD COLUMN / CREATE TABLE / CREATE INDEX.
  /// - TUYET DOI khong dung DROP TABLE hay DELETE tren bang co du lieu that.
  /// - Cot them moi phai co DEFAULT de ban ghi cu khong bi NULL.
  ///
  /// Cac khoi `if` chay tuan tu nen may dang o version 1 nhay thang len 4 van
  /// duoc nang dung thu tu 1->2->3->4.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Nâng cấp CSDL: v$oldVersion -> v$newVersion');

    try {
      // ---- v1 -> v2: them bang luu cai dat (che do Sang/Toi) ----
      // Chi CREATE TABLE, khong dung toi transactions/budgets nen du lieu chi
      // tieu cu duoc giu nguyen 100%.
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableSettings (
            setting_key   TEXT PRIMARY KEY,
            setting_value TEXT NOT NULL
          )
        ''');
      }

      // ---- MAU CHO LAN NANG CAP TIEP THEO (dang comment, mo khi can) ----
      //
      // if (oldVersion < 3) {
      //   await db.execute(
      //     'ALTER TABLE $tableTransactions ADD COLUMN payment_method '
      //     "TEXT NOT NULL DEFAULT 'cash'",
      //   );
      // }
    } catch (e) {
      // Migration hong nguy hiem hon la khong migration: nem loi ro rang de
      // phat hien ngay, thay vi de app chay tiep voi schema nua voi.
      throw LocalDatabaseException(
        'Nâng cấp cơ sở dữ liệu từ v$oldVersion lên v$newVersion thất bại.',
        e,
      );
    }
  }

  /// Ha cap (cai APK cu hon len APK moi hon). Mac dinh sqflite se nem loi va
  /// lam crash app. Ta chan lai de app van chay duoc voi schema cu.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Cảnh báo: hạ cấp CSDL v$oldVersion -> v$newVersion, giữ nguyên dữ liệu.');
  }

  // ==========================================================================
  // TRANSACTIONS - CRUD
  // ==========================================================================

  Future<int> insertTransaction(TransactionModel item) async {
    try {
      final Database db = await database;
      return await db.insert(
        tableTransactions,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException('Không lưu được giao dịch.', e);
    }
  }

  Future<int> updateTransaction(TransactionModel item) async {
    if (item.id == null) {
      throw const LocalDatabaseException('Giao dịch chưa có ID để cập nhật.');
    }
    try {
      final Database db = await database;
      return await db.update(
        tableTransactions,
        item.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[item.id],
      );
    } catch (e) {
      throw LocalDatabaseException('Không cập nhật được giao dịch.', e);
    }
  }

  Future<int> deleteTransaction(int id) async {
    try {
      final Database db = await database;
      return await db.delete(
        tableTransactions,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    } catch (e) {
      throw LocalDatabaseException('Không xoá được giao dịch.', e);
    }
  }

  Future<List<TransactionModel>> getTransactionsInRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        tableTransactions,
        where: 'date >= ? AND date < ?',
        whereArgs: <Object?>[
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'date DESC, id DESC',
      );
      return rows.map(TransactionModel.fromMap).toList(growable: false);
    } catch (e) {
      throw LocalDatabaseException('Không đọc được danh sách giao dịch.', e);
    }
  }

  Future<List<TransactionModel>> getTransactionsByMonth(
    int year,
    int month,
  ) async {
    final DateTime start = DateTime(year, month, 1);
    final DateTime end = DateTime(year, month + 1, 1);
    return getTransactionsInRange(start, end);
  }

  /// Tong so tien theo loai (0 = chi, 1 = thu) trong khoang thoi gian.
  Future<double> sumByType(
    TransactionType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM $tableTransactions '
        'WHERE type = ? AND date >= ? AND date < ?',
        <Object?>[
          type.index,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
      );
      if (rows.isEmpty) return 0;
      return (rows.first['total'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      throw LocalDatabaseException('Không tính được tổng thu/chi.', e);
    }
  }

  /// Tong chi theo tung danh muc (dung ve bieu do tron).
  Future<Map<String, double>> sumGroupByCategory(
    TransactionType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        'SELECT category_id, COALESCE(SUM(amount), 0) AS total '
        'FROM $tableTransactions '
        'WHERE type = ? AND date >= ? AND date < ? '
        'GROUP BY category_id ORDER BY total DESC',
        <Object?>[
          type.index,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
      );
      final Map<String, double> result = <String, double>{};
      for (final Map<String, dynamic> row in rows) {
        final String categoryId = (row['category_id'] as String?) ?? 'other';
        result[categoryId] = (row['total'] as num?)?.toDouble() ?? 0;
      }
      return result;
    } catch (e) {
      throw LocalDatabaseException('Không thống kê được theo danh mục.', e);
    }
  }

  /// Tong THU va CHI cua TUNG NGAY trong thang - dung ve so tien tren o lich.
  ///
  /// Gom nhom ngay bang SQLite date function thay vi keo het ban ghi ve Dart:
  /// `date` luu millis nen phai chia 1000 -> 'unixepoch' -> 'localtime'.
  Future<List<DailyTotal>> getDailyTotals(int year, int month) async {
    try {
      final Database db = await database;
      final DateTime start = DateTime(year, month, 1);
      final DateTime end = DateTime(year, month + 1, 1);

      final List<Map<String, dynamic>> rows = await db.rawQuery(
        "SELECT date(date / 1000, 'unixepoch', 'localtime') AS day, "
        'type, '
        'COALESCE(SUM(amount), 0) AS total '
        'FROM $tableTransactions '
        'WHERE date >= ? AND date < ? '
        'GROUP BY day, type',
        <Object?>[
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
      );

      final Map<String, double> incomeMap = <String, double>{};
      final Map<String, double> expenseMap = <String, double>{};

      for (final Map<String, dynamic> row in rows) {
        final String? day = row['day'] as String?;
        if (day == null) continue;
        final double total = (row['total'] as num?)?.toDouble() ?? 0;
        final int type = (row['type'] as int?) ?? 0;
        if (type == TransactionType.income.index) {
          incomeMap[day] = total;
        } else {
          expenseMap[day] = total;
        }
      }

      final Set<String> allDays = <String>{...incomeMap.keys, ...expenseMap.keys};
      final List<DailyTotal> result = <DailyTotal>[];

      for (final String day in allDays) {
        final DateTime? parsed = DateTime.tryParse(day);
        if (parsed == null) continue;
        result.add(
          DailyTotal(
            day: DateTime(parsed.year, parsed.month, parsed.day),
            income: incomeMap[day] ?? 0,
            expense: expenseMap[day] ?? 0,
          ),
        );
      }

      result.sort((DailyTotal a, DailyTotal b) => a.day.compareTo(b.day));
      return result;
    } catch (e) {
      throw LocalDatabaseException('Không tính được tổng chi theo ngày.', e);
    }
  }

  // ==========================================================================
  // BUDGETS
  // ==========================================================================

  Future<BudgetModel?> getBudget(int year, int month) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        tableBudgets,
        where: 'year = ? AND month = ?',
        whereArgs: <Object?>[year, month],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return BudgetModel.fromMap(rows.first);
    } catch (e) {
      throw LocalDatabaseException('Không đọc được hạn mức ngân sách.', e);
    }
  }

  /// Them moi hoac ghi de han muc cua thang (nho UNIQUE ... ON CONFLICT REPLACE).
  Future<int> upsertBudget(BudgetModel budget) async {
    try {
      final Database db = await database;
      return await db.insert(
        tableBudgets,
        <String, dynamic>{
          'year': budget.year,
          'month': budget.month,
          'amount': budget.amount,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException('Không lưu được hạn mức ngân sách.', e);
    }
  }

  Future<int> deleteBudget(int year, int month) async {
    try {
      final Database db = await database;
      return await db.delete(
        tableBudgets,
        where: 'year = ? AND month = ?',
        whereArgs: <Object?>[year, month],
      );
    } catch (e) {
      throw LocalDatabaseException('Không xoá được hạn mức ngân sách.', e);
    }
  }

  // ==========================================================================
  // SETTINGS (cai dat chung: che do Sang/Toi...)
  // ==========================================================================

  /// Doc mot cai dat. Tra ve null neu chua tung luu.
  /// Khong nem loi ra ngoai: cai dat hong khong duoc lam chet app, chi can
  /// quay ve gia tri mac dinh.
  Future<String?> getSetting(String key) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        tableSettings,
        columns: <String>['setting_value'],
        where: 'setting_key = ?',
        whereArgs: <Object?>[key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['setting_value'] as String?;
    } catch (e) {
      debugPrint('getSetting("$key") lỗi: $e');
      return null;
    }
  }

  /// Ghi de mot cai dat.
  Future<bool> setSetting(String key, String value) async {
    try {
      final Database db = await database;
      await db.insert(
        tableSettings,
        <String, dynamic>{'setting_key': key, 'setting_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('setSetting("$key") lỗi: $e');
      return false;
    }
  }

  Future<void> close() async {
    final Database? current = _db;
    if (current != null && current.isOpen) {
      await current.close();
    }
    _db = null;
  }
}
