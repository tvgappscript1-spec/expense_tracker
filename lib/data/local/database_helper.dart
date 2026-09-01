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

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'expense_tracker.db';
  static const int _dbVersion = 1;

  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';

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

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 1 la ban dau tien. Cac lan nang cap sau them migration tai day.
    if (oldVersion < newVersion) {
      debugPrint('DB upgrade: $oldVersion -> $newVersion');
    }
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

  Future<void> close() async {
    final Database? current = _db;
    if (current != null && current.isOpen) {
      await current.close();
    }
    _db = null;
  }
}
