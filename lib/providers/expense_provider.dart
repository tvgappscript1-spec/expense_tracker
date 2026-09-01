import 'package:flutter/foundation.dart';

import '../data/local/database_helper.dart';
import '../data/models/budget_model.dart';
import '../data/models/transaction_model.dart';

/// Muc do canh bao ngan sach sau khi them 1 giao dich.
enum BudgetAlertLevel {
  /// Chua co han muc, hoac van duoi 80%.
  none,

  /// Vua vuot moc 80% (chua vuot 100%).
  warning,

  /// Vua vuot moc 100%.
  exceeded,
}

/// Tong hop thu/chi cua 1 thang - dung cho bieu do cot xu huong.
class MonthlySummary {
  final DateTime month;
  final double income;
  final double expense;

  const MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get balance => income - expense;
}

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({DatabaseHelper? database})
      : _db = database ?? DatabaseHelper.instance {
    final DateTime now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  final DatabaseHelper _db;

  late DateTime _selectedMonth;
  List<TransactionModel> _transactions = <TransactionModel>[];
  BudgetModel? _budget;
  List<MonthlySummary> _trend = <MonthlySummary>[];

  bool _isLoading = false;
  String? _errorMessage;

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  DateTime get selectedMonth => _selectedMonth;
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<MonthlySummary> get trend => List.unmodifiable(_trend);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _transactions.isEmpty;

  double get totalIncome => _transactions
      .where((TransactionModel t) => t.type.isIncome)
      .fold<double>(0, (double sum, TransactionModel t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((TransactionModel t) => t.type.isExpense)
      .fold<double>(0, (double sum, TransactionModel t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  double get budgetLimit => _budget?.amount ?? 0;
  bool get hasBudget => budgetLimit > 0;

  /// Ty le da chi / han muc (0.0 -> co the > 1.0 khi vuot).
  double get budgetRatio {
    if (!hasBudget) return 0;
    return totalExpense / budgetLimit;
  }

  /// Ty le da lam tron cho thanh tien do (toi da 1.0).
  double get budgetProgress {
    final double r = budgetRatio;
    if (r.isNaN || r.isInfinite || r < 0) return 0;
    return r > 1 ? 1 : r;
  }

  int get budgetPercent => (budgetRatio * 100).round();

  double get budgetRemaining {
    final double remain = budgetLimit - totalExpense;
    return remain < 0 ? 0 : remain;
  }

  double get budgetOverspent {
    final double over = totalExpense - budgetLimit;
    return over < 0 ? 0 : over;
  }

  /// So tien trung binh con duoc chi moi ngay den het thang.
  double get dailyAllowance {
    if (!hasBudget) return 0;
    final DateTime now = DateTime.now();
    final bool isCurrentMonth =
        now.year == _selectedMonth.year && now.month == _selectedMonth.month;
    final int lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final int daysLeft = isCurrentMonth ? (lastDay - now.day + 1) : lastDay;
    if (daysLeft <= 0) return 0;
    return budgetRemaining / daysLeft;
  }

  /// Gom giao dich theo ngay, ngay moi nhat len truoc.
  Map<DateTime, List<TransactionModel>> get groupedByDay {
    final Map<DateTime, List<TransactionModel>> grouped =
        <DateTime, List<TransactionModel>>{};
    for (final TransactionModel t in _transactions) {
      grouped.putIfAbsent(t.dayKey, () => <TransactionModel>[]).add(t);
    }
    final List<DateTime> keys = grouped.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));
    return <DateTime, List<TransactionModel>>{
      for (final DateTime k in keys) k: grouped[k]!,
    };
  }

  /// Tong chi theo danh muc trong thang dang xem (cho bieu do tron).
  Map<String, double> get expenseByCategory {
    final Map<String, double> result = <String, double>{};
    for (final TransactionModel t in _transactions) {
      if (!t.type.isExpense) continue;
      result[t.categoryId] = (result[t.categoryId] ?? 0) + t.amount;
    }
    final List<MapEntry<String, double>> entries = result.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));
    return <String, double>{for (final MapEntry<String, double> e in entries) e.key: e.value};
  }

  // ==========================================================================
  // LOAD DU LIEU
  // ==========================================================================

  Future<void> init() => loadMonth(_selectedMonth);

  Future<void> loadMonth(DateTime month, {bool showLoading = true}) async {
    _selectedMonth = DateTime(month.year, month.month);
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final List<TransactionModel> items =
          await _db.getTransactionsByMonth(_selectedMonth.year, _selectedMonth.month);
      final BudgetModel? budget =
          await _db.getBudget(_selectedMonth.year, _selectedMonth.month);

      _transactions = items;
      _budget = budget;
      _errorMessage = null;
      await _loadTrend();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi khi tải dữ liệu.';
      debugPrint('loadMonth error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadMonth(_selectedMonth, showLoading: false);

  Future<void> goToPreviousMonth() =>
      loadMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  Future<void> goToNextMonth() =>
      loadMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  Future<void> goToMonth(DateTime month) => loadMonth(month);

  /// Nap 6 thang gan nhat (tinh ca thang dang xem) cho bieu do cot.
  Future<void> _loadTrend({int months = 6}) async {
    try {
      final DateTime start =
          DateTime(_selectedMonth.year, _selectedMonth.month - (months - 1), 1);
      final DateTime end =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final List<TransactionModel> items =
          await _db.getTransactionsInRange(start, end);

      final List<MonthlySummary> result = <MonthlySummary>[];
      for (int i = 0; i < months; i++) {
        final DateTime m = DateTime(start.year, start.month + i, 1);
        double income = 0;
        double expense = 0;
        for (final TransactionModel t in items) {
          if (t.date.year == m.year && t.date.month == m.month) {
            if (t.type.isIncome) {
              income += t.amount;
            } else {
              expense += t.amount;
            }
          }
        }
        result.add(MonthlySummary(month: m, income: income, expense: expense));
      }
      _trend = result;
    } catch (e) {
      debugPrint('loadTrend error: $e');
      _trend = <MonthlySummary>[];
    }
  }

  // ==========================================================================
  // CRUD GIAO DICH + CANH BAO NGAN SACH
  // ==========================================================================

  /// Them giao dich. Tra ve muc do canh bao ngan sach de UI hien thong bao.
  Future<BudgetAlertLevel> addTransaction(TransactionModel item) async {
    final double ratioBefore = budgetRatio;
    try {
      final int id = await _db.insertTransaction(item);
      final TransactionModel saved = item.copyWith(id: id);

      if (_belongsToSelectedMonth(saved.date)) {
        _transactions = <TransactionModel>[saved, ..._transactions]
          ..sort((TransactionModel a, TransactionModel b) =>
              b.date.compareTo(a.date));
      }
      await _loadTrend();
      _errorMessage = null;
      notifyListeners();

      return _evaluateAlert(ratioBefore, budgetRatio, saved);
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionModel item) async {
    try {
      await _db.updateTransaction(item);
      await refresh();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _db.deleteTransaction(id);
      _transactions = _transactions
          .where((TransactionModel t) => t.id != id)
          .toList(growable: false);
      await _loadTrend();
      notifyListeners();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Khoi phuc giao dich vua xoa (dung cho nut "Hoàn tác").
  Future<void> restoreTransaction(TransactionModel item) async {
    try {
      await _db.insertTransaction(item);
      await refresh();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  bool _belongsToSelectedMonth(DateTime date) =>
      date.year == _selectedMonth.year && date.month == _selectedMonth.month;

  /// Chi canh bao khi giao dich CHI vua lam VUOT MOC (80% hoac 100%),
  /// tranh spam thong bao o moi lan them giao dich.
  BudgetAlertLevel _evaluateAlert(
    double before,
    double after,
    TransactionModel item,
  ) {
    if (!hasBudget) return BudgetAlertLevel.none;
    if (!item.type.isExpense) return BudgetAlertLevel.none;
    if (!_belongsToSelectedMonth(item.date)) return BudgetAlertLevel.none;

    if (before < 1.0 && after >= 1.0) return BudgetAlertLevel.exceeded;
    if (after >= 1.0) return BudgetAlertLevel.exceeded;
    if (before < 0.8 && after >= 0.8) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.none;
  }

  // ==========================================================================
  // NGAN SACH
  // ==========================================================================

  Future<void> setBudget(double amount) async {
    try {
      final BudgetModel budget = BudgetModel(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        amount: amount,
      );
      await _db.upsertBudget(budget);
      _budget = budget;
      _errorMessage = null;
      notifyListeners();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearBudget() async {
    try {
      await _db.deleteBudget(_selectedMonth.year, _selectedMonth.month);
      _budget = null;
      notifyListeners();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
