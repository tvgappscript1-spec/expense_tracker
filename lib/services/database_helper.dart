import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import 'seed/category_seed.dart';

/// Loi cua tang du lieu - de UI hien thong bao than thien thay vi crash.
class LocalDatabaseException implements Exception {
  final String message;
  final Object? cause;

  const LocalDatabaseException(this.message, [this.cause]);

  @override
  String toString() => 'LocalDatabaseException: $message';
}

/// Thong ke so tien theo danh muc (dung cho bieu do tron phan cap).
class CategoryStat {
  final int categoryId;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  double total;
  final List<CategoryStat> children;

  CategoryStat({
    required this.categoryId,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.total,
    required this.children,
  });

  // LUU Y: khong dat getter tra ve IconData/Color o day. Tang du lieu (DB)
  // khong phu thuoc thu vien giao dien. Tang UI tu chuyen iconCodePoint ->
  // IconData va colorValue -> Color qua extension CategoryStatUi (o file
  // stats_screen.dart).
  bool get hasChildren => children.isNotEmpty;
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
  static const int _dbVersion = 3;

  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';
  static const String tableSettings = 'settings';
  static const String tableCategories = 'categories';
  static const String tableDebts = 'debts';

  /// Khoa cai dat da dung trong bang settings.
  static const String keyThemeMode = 'theme_mode';
  static const String keyBalanceHidden = 'balance_hidden';
  static const String keyCategoriesSeeded = 'categories_seeded';

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
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT    NOT NULL,
        amount       REAL    NOT NULL CHECK (amount >= 0),
        date         INTEGER NOT NULL,
        category_id  TEXT    NOT NULL DEFAULT '',
        category_ref INTEGER NOT NULL DEFAULT 0,
        type         INTEGER NOT NULL CHECK (type IN (0, 1)),
        note         TEXT    NOT NULL DEFAULT '',
        created_at   INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_transactions_date ON $tableTransactions (date DESC)
    ''');

    batch.execute('''
      CREATE INDEX idx_transactions_type ON $tableTransactions (type)
    ''');

    batch.execute('''
      CREATE INDEX idx_transactions_catref ON $tableTransactions (category_ref)
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

    batch.execute('''
      CREATE TABLE $tableCategories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        icon_code  INTEGER NOT NULL,
        color_value INTEGER NOT NULL,
        type       INTEGER NOT NULL CHECK (type IN (0, 1)),
        parent_id  INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_system  INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES $tableCategories (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_categories_parent ON $tableCategories (parent_id)
    ''');

    batch.execute('''
      CREATE TABLE $tableDebts (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        person                TEXT    NOT NULL,
        amount                REAL    NOT NULL CHECK (amount >= 0),
        type                  INTEGER NOT NULL CHECK (type IN (0, 1)),
        date                  INTEGER NOT NULL,
        due_date              INTEGER,
        note                  TEXT    NOT NULL DEFAULT '',
        is_settled            INTEGER NOT NULL DEFAULT 0,
        settled_at            INTEGER,
        settle_transaction_id INTEGER,
        created_at            INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);

    // Seed danh muc mac dinh ngay khi tao DB moi.
    await _seedCategories(db);
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

      // ---- v2 -> v3: danh muc 2 cap + so no ----
      // Buoc nay phuc tap nhat: tao 2 bang moi, seed danh muc, them cot
      // category_ref vao transactions roi ANH XA du lieu chi tieu cu (dang
      // category_id chuoi 'food'/'transport') sang id danh muc moi.
      // Toan bo boc trong transaction cua chinh migration nen an toan.
      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableCategories (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT    NOT NULL,
            icon_code  INTEGER NOT NULL,
            color_value INTEGER NOT NULL,
            type       INTEGER NOT NULL CHECK (type IN (0, 1)),
            parent_id  INTEGER,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_system  INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (parent_id) REFERENCES $tableCategories (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_categories_parent '
          'ON $tableCategories (parent_id)',
        );

        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableDebts (
            id                    INTEGER PRIMARY KEY AUTOINCREMENT,
            person                TEXT    NOT NULL,
            amount                REAL    NOT NULL CHECK (amount >= 0),
            type                  INTEGER NOT NULL CHECK (type IN (0, 1)),
            date                  INTEGER NOT NULL,
            due_date              INTEGER,
            note                  TEXT    NOT NULL DEFAULT '',
            is_settled            INTEGER NOT NULL DEFAULT 0,
            settled_at            INTEGER,
            settle_transaction_id INTEGER,
            created_at            INTEGER NOT NULL
          )
        ''');

        // Them cot category_ref (co DEFAULT 0 nen ban ghi cu khong bi NULL).
        await db.execute(
          'ALTER TABLE $tableTransactions '
          'ADD COLUMN category_ref INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_catref '
          'ON $tableTransactions (category_ref)',
        );

        // Seed danh muc chuan (dung chung ham voi onCreate).
        await _seedCategories(db);

        // Anh xa du lieu cu: moi giao dich v1 co category_id chuoi -> tim
        // danh muc con moi phu hop, gan vao category_ref.
        await _migrateLegacyCategories(db);
      }


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
  // SEEDING DANH MUC
  // ==========================================================================

  /// Ghi bo danh muc mac dinh vao DB. Chay trong 1 transaction de neu loi
  /// giua chung thi rollback sach, khong de lai danh muc nua voi.
  Future<void> _seedCategories(DatabaseExecutor db) async {
    Future<void> seedList(
      List<SeedCategory> list,
      TransactionType type,
    ) async {
      for (int i = 0; i < list.length; i++) {
        final SeedCategory parent = list[i];
        final int parentId = await db.insert(tableCategories, <String, dynamic>{
          'name': parent.name,
          'icon_code': parent.icon.codePoint,
          'color_value': parent.color.value,
          'type': type.index,
          'parent_id': null,
          'sort_order': i,
          'is_system': 1,
        });

        for (int j = 0; j < parent.children.length; j++) {
          final SeedChild child = parent.children[j];
          await db.insert(tableCategories, <String, dynamic>{
            'name': child.name,
            'icon_code': child.icon.codePoint,
            'color_value': parent.color.value, // con thua mau cha
            'type': type.index,
            'parent_id': parentId,
            'sort_order': j,
            'is_system': 1,
          });
        }
      }
    }

    await seedList(CategorySeed.expense, TransactionType.expense);
    await seedList(CategorySeed.income, TransactionType.income);
  }

  /// Anh xa category_id chuoi cua du lieu v1 sang category_ref moi.
  ///
  /// Bo danh muc cu (food/transport...) khong con ton tai o dang hang so, nen
  /// ta khop theo TEN danh muc cha tuong duong. Khong khop duoc thi gan vao
  /// danh muc "Khac" cung loai. Khong bao gio de mat giao dich.
  Future<void> _migrateLegacyCategories(DatabaseExecutor db) async {
    // Ban do ma cu -> ten danh muc cha trong bo seed moi.
    const Map<String, String> legacyToName = <String, String>{
      'food': 'Ăn uống',
      'transport': 'Di chuyển',
      'shopping': 'Mua sắm',
      'bills': 'Hóa đơn',
      'home': 'Nhà cửa',
      'health': 'Sức khỏe',
      'education': 'Học tập',
      'entertainment': 'Giải trí',
      'other_expense': 'Khác',
      'salary': 'Lương',
      'bonus': 'Thưởng',
      'investment': 'Đầu tư',
      'other_income': 'Thu khác',
    };

    // Lay id danh muc theo (ten, type) de tra cuu nhanh.
    Future<int?> findCategoryId(String name, TransactionType type) async {
      final List<Map<String, dynamic>> rows = await db.query(
        tableCategories,
        columns: <String>['id'],
        where: 'name = ? AND type = ? AND parent_id IS NULL',
        whereArgs: <Object?>[name, type.index],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['id'] as int?;
    }

    final int? otherExpenseId = await findCategoryId('Khác', TransactionType.expense);
    final int? otherIncomeId = await findCategoryId('Thu khác', TransactionType.income);

    // Duyet tung ma cu, cap nhat hang loat cac giao dich mang ma do.
    final List<Map<String, dynamic>> distinct = await db.rawQuery(
      'SELECT DISTINCT category_id, type FROM $tableTransactions '
      'WHERE category_ref = 0',
    );

    for (final Map<String, dynamic> row in distinct) {
      final String legacy = (row['category_id'] as String?) ?? '';
      final TransactionType type =
          TransactionTypeX.fromIndex((row['type'] as int?) ?? 0);
      if (legacy.isEmpty) continue;

      int? targetId;
      final String? name = legacyToName[legacy];
      if (name != null) {
        targetId = await findCategoryId(name, type);
      }
      targetId ??= type.isExpense ? otherExpenseId : otherIncomeId;
      if (targetId == null) continue;

      await db.update(
        tableTransactions,
        <String, dynamic>{'category_ref': targetId},
        where: 'category_id = ? AND type = ? AND category_ref = 0',
        whereArgs: <Object?>[legacy, type.index],
      );
    }
  }

  // ==========================================================================
  // CATEGORIES - CRUD
  // ==========================================================================

  Future<List<CategoryModel>> getCategories(TransactionType type) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        tableCategories,
        where: 'type = ?',
        whereArgs: <Object?>[type.index],
        orderBy: 'parent_id IS NOT NULL, sort_order ASC, id ASC',
      );
      return rows.map(CategoryModel.fromMap).toList(growable: false);
    } catch (e) {
      throw LocalDatabaseException('Không đọc được danh mục.', e);
    }
  }

  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        tableCategories,
        orderBy: 'type ASC, parent_id IS NOT NULL, sort_order ASC',
      );
      return rows.map(CategoryModel.fromMap).toList(growable: false);
    } catch (e) {
      throw LocalDatabaseException('Không đọc được danh mục.', e);
    }
  }

  Future<int> insertCategory(CategoryModel category) async {
    try {
      final Database db = await database;
      return await db.insert(tableCategories, category.toMap());
    } catch (e) {
      throw LocalDatabaseException('Không thêm được danh mục.', e);
    }
  }

  Future<int> updateCategory(CategoryModel category) async {
    if (category.id == null) {
      throw const LocalDatabaseException('Danh mục chưa có ID để cập nhật.');
    }
    try {
      final Database db = await database;
      return await db.update(
        tableCategories,
        category.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[category.id],
      );
    } catch (e) {
      throw LocalDatabaseException('Không cập nhật được danh mục.', e);
    }
  }

  /// Xoa danh muc. Con cua no bi xoa theo (ON DELETE CASCADE). Giao dich dang
  /// tro toi se duoc chuyen ve danh muc "Khac" cung loai de khong mat.
  Future<int> deleteCategory(int id) async {
    try {
      final Database db = await database;
      return await db.transaction<int>((Transaction txn) async {
        final List<Map<String, dynamic>> rows = await txn.query(
          tableCategories,
          columns: <String>['type'],
          where: 'id = ?',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (rows.isEmpty) return 0;
        final TransactionType type =
            TransactionTypeX.fromIndex((rows.first['type'] as int?) ?? 0);

        // Tim id cac danh muc con de gom ca chung vao danh sach can chuyen.
        final List<Map<String, dynamic>> children = await txn.query(
          tableCategories,
          columns: <String>['id'],
          where: 'parent_id = ?',
          whereArgs: <Object?>[id],
        );
        final List<int> affectedIds = <int>[
          id,
          for (final Map<String, dynamic> c in children) c['id'] as int,
        ];

        // Tim danh muc "Khac"/"Thu khac" de chuyen giao dich mo coi sang.
        final String fallbackName = type.isExpense ? 'Khác' : 'Thu khác';
        final List<Map<String, dynamic>> fb = await txn.query(
          tableCategories,
          columns: <String>['id'],
          where: 'name = ? AND type = ? AND parent_id IS NULL',
          whereArgs: <Object?>[fallbackName, type.index],
          limit: 1,
        );
        final int? fallbackId = fb.isEmpty ? null : fb.first['id'] as int?;

        if (fallbackId != null && !affectedIds.contains(fallbackId)) {
          final String placeholders =
              List<String>.filled(affectedIds.length, '?').join(', ');
          await txn.update(
            tableTransactions,
            <String, dynamic>{'category_ref': fallbackId},
            where: 'category_ref IN ($placeholders)',
            whereArgs: affectedIds,
          );
        }

        return txn.delete(
          tableCategories,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      });
    } catch (e) {
      throw LocalDatabaseException('Không xoá được danh mục.', e);
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

  /// Tong chi gom theo DANH MUC CHA, kem chi tiet tung con - cho bieu do tron
  /// phan cap (bam cha xo ra con).
  ///
  /// Giao dich gan vao danh muc con; ta JOIN len cha de gom. Giao dich gan
  /// thang vao 1 danh muc cha (khong co con) thi cha lam dai dien luon.
  Future<List<CategoryStat>> statsByParentCategory(
    TransactionType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final Database db = await database;
      // c  = danh muc cua giao dich (thuong la con)
      // pc = danh muc cha (neu c la con); neu c da la cha thi pc = c
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        '''
        SELECT
          COALESCE(pc.id, c.id)               AS parent_id,
          COALESCE(pc.name, c.name)           AS parent_name,
          COALESCE(pc.icon_code, c.icon_code) AS parent_icon,
          COALESCE(pc.color_value, c.color_value) AS parent_color,
          c.id                                AS child_id,
          c.name                              AS child_name,
          c.icon_code                         AS child_icon,
          c.parent_id                         AS child_parent,
          COALESCE(SUM(t.amount), 0)          AS total
        FROM $tableTransactions t
        JOIN $tableCategories c  ON t.category_ref = c.id
        LEFT JOIN $tableCategories pc ON c.parent_id = pc.id
        WHERE t.type = ? AND t.date >= ? AND t.date < ?
        GROUP BY c.id
        ''',
        <Object?>[
          type.index,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
      );

      // Gom cac dong con vao dung cha.
      final Map<int, CategoryStat> parents = <int, CategoryStat>{};

      for (final Map<String, dynamic> row in rows) {
        final int parentId = (row['parent_id'] as int?) ?? 0;
        final double total = (row['total'] as num?)?.toDouble() ?? 0;
        if (total <= 0) continue;

        final CategoryStat parent = parents.putIfAbsent(
          parentId,
          () => CategoryStat(
            categoryId: parentId,
            name: (row['parent_name'] as String?) ?? 'Khác',
            iconCodePoint: (row['parent_icon'] as int?) ??
                0xf624 /* Icons.category_rounded */,
            colorValue: (row['parent_color'] as int?) ?? 0xFF78909C,
            total: 0,
            children: <CategoryStat>[],
          ),
        );

        parent.total += total;

        // Chi them dong con neu no thuc su la con (co parent).
        final bool isChild = row['child_parent'] != null;
        if (isChild) {
          parent.children.add(
            CategoryStat(
              categoryId: (row['child_id'] as int?) ?? 0,
              name: (row['child_name'] as String?) ?? '',
              iconCodePoint: (row['child_icon'] as int?) ??
                  0xf624 /* Icons.category_rounded */,
              colorValue: parent.colorValue,
              total: total,
              children: const <CategoryStat>[],
            ),
          );
        }
      }

      final List<CategoryStat> result = parents.values.toList()
        ..sort((CategoryStat a, CategoryStat b) => b.total.compareTo(a.total));
      for (final CategoryStat p in result) {
        p.children.sort((CategoryStat a, CategoryStat b) =>
            b.total.compareTo(a.total));
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
  // DEBTS - SO NO / CHO VAY
  // ==========================================================================

  Future<List<DebtModel>> getDebts({bool? settled}) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        tableDebts,
        where: settled == null ? null : 'is_settled = ?',
        whereArgs: settled == null ? null : <Object?>[settled ? 1 : 0],
        orderBy: 'is_settled ASC, '
            'CASE WHEN due_date IS NULL THEN 1 ELSE 0 END, '
            'due_date ASC, date DESC',
      );
      return rows.map(DebtModel.fromMap).toList(growable: false);
    } catch (e) {
      throw LocalDatabaseException('Không đọc được sổ nợ.', e);
    }
  }

  Future<int> insertDebt(DebtModel debt) async {
    try {
      final Database db = await database;
      return await db.insert(tableDebts, debt.toMap());
    } catch (e) {
      throw LocalDatabaseException('Không lưu được khoản nợ.', e);
    }
  }

  Future<int> updateDebt(DebtModel debt) async {
    if (debt.id == null) {
      throw const LocalDatabaseException('Khoản nợ chưa có ID để cập nhật.');
    }
    try {
      final Database db = await database;
      return await db.update(
        tableDebts,
        debt.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[debt.id],
      );
    } catch (e) {
      throw LocalDatabaseException('Không cập nhật được khoản nợ.', e);
    }
  }

  /// Xoa khoan no. Neu no da tat toan va co sinh giao dich thi xoa luon giao
  /// dich do de so du khong bi lech.
  Future<int> deleteDebt(int id) async {
    try {
      final Database db = await database;
      return await db.transaction<int>((Transaction txn) async {
        final List<Map<String, dynamic>> rows = await txn.query(
          tableDebts,
          columns: <String>['settle_transaction_id'],
          where: 'id = ?',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final int? txId = rows.first['settle_transaction_id'] as int?;
          if (txId != null) {
            await txn.delete(
              tableTransactions,
              where: 'id = ?',
              whereArgs: <Object?>[txId],
            );
          }
        }
        return txn.delete(tableDebts, where: 'id = ?', whereArgs: <Object?>[id]);
      });
    } catch (e) {
      throw LocalDatabaseException('Không xoá được khoản nợ.', e);
    }
  }

  /// Tat toan mot khoan no:
  /// - Vay (borrow) -> tra tien ra  => sinh 1 giao dich CHI.
  /// - Cho vay (lend) -> thu tien ve => sinh 1 giao dich THU.
  ///
  /// Ca 2 thao tac (sinh giao dich + danh dau da tra) nam trong 1 transaction
  /// nen khong bao gio xay ra canh da tru tien ma no van "chua tra".
  Future<void> settleDebt(
    DebtModel debt, {
    required int categoryRef,
    DateTime? settledAt,
  }) async {
    if (debt.id == null) {
      throw const LocalDatabaseException('Khoản nợ chưa có ID.');
    }
    if (debt.isSettled) return;

    final DateTime when = settledAt ?? DateTime.now();
    final TransactionType txType =
        debt.type.isBorrow ? TransactionType.expense : TransactionType.income;
    final String title = debt.type.isBorrow
        ? 'Trả nợ ${debt.person}'
        : 'Thu nợ ${debt.person}';

    try {
      final Database db = await database;
      await db.transaction<void>((Transaction txn) async {
        final int txId = await txn.insert(tableTransactions, <String, dynamic>{
          'title': title,
          'amount': debt.amount,
          'date': when.millisecondsSinceEpoch,
          'category_id': '',
          'category_ref': categoryRef,
          'type': txType.index,
          'note': debt.note,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        await txn.update(
          tableDebts,
          <String, dynamic>{
            'is_settled': 1,
            'settled_at': when.millisecondsSinceEpoch,
            'settle_transaction_id': txId,
          },
          where: 'id = ?',
          whereArgs: <Object?>[debt.id],
        );
      });
    } catch (e) {
      throw LocalDatabaseException('Không tất toán được khoản nợ.', e);
    }
  }

  /// Huy tat toan: xoa giao dich da sinh, dua no ve trang thai chua tra.
  Future<void> unsettleDebt(DebtModel debt) async {
    if (debt.id == null || !debt.isSettled) return;
    try {
      final Database db = await database;
      await db.transaction<void>((Transaction txn) async {
        final int? txId = debt.settleTransactionId;
        if (txId != null) {
          await txn.delete(
            tableTransactions,
            where: 'id = ?',
            whereArgs: <Object?>[txId],
          );
        }
        await txn.update(
          tableDebts,
          <String, dynamic>{
            'is_settled': 0,
            'settled_at': null,
            'settle_transaction_id': null,
          },
          where: 'id = ?',
          whereArgs: <Object?>[debt.id],
        );
      });
    } catch (e) {
      throw LocalDatabaseException('Không huỷ tất toán được.', e);
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
