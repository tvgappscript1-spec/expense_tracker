import 'package:flutter/foundation.dart';

import '../services/database_helper.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';

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
  DateTime _selectedDay = DateTime.now();
  List<TransactionModel> _transactions = <TransactionModel>[];
  BudgetModel? _budget;
  List<MonthlySummary> _trend = <MonthlySummary>[];
  Map<DateTime, DailyTotal> _dailyTotals = <DateTime, DailyTotal>{};
  List<CategoryStat> _expenseStats = <CategoryStat>[];
  bool _balanceHidden = false;

  bool _isLoading = false;
  String? _errorMessage;

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  DateTime get selectedMonth => _selectedMonth;
  DateTime get selectedDay => _selectedDay;
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  // ==========================================================================
  // DU LIEU CHO MAN HINH LICH
  // ==========================================================================

  /// Chuan hoa ve 00:00 de lam khoa Map — table_calendar tra ve DateTime co
  /// gio phut khac nhau, so sanh truc tiep se khong khop.
  static DateTime dayKeyOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Tong thu/chi cua mot ngay bat ky. Khong co giao dich thi tra ve null.
  DailyTotal? totalOfDay(DateTime day) => _dailyTotals[dayKeyOf(day)];

  /// Danh sach giao dich cua ngay dang duoc chon tren lich.
  List<TransactionModel> get transactionsOfSelectedDay =>
      transactionsOfDay(_selectedDay);

  List<TransactionModel> transactionsOfDay(DateTime day) {
    final DateTime key = dayKeyOf(day);
    return _transactions
        .where((TransactionModel t) => t.dayKey == key)
        .toList(growable: false);
  }

  /// table_calendar goi ham nay cho tung o ngay de ve marker ben duoi.
  List<TransactionModel> eventsForDay(DateTime day) => transactionsOfDay(day);

  void selectDay(DateTime day) {
    final DateTime key = dayKeyOf(day);
    if (_selectedDay == key) return;
    _selectedDay = key;
    notifyListeners();
  }

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

  /// Thong ke chi theo danh muc cha (kem con) cho bieu do tron phan cap.
  /// Nap tu DB moi khi doi thang, cache tai day.
  List<CategoryStat> get expenseStats => List.unmodifiable(_expenseStats);

  bool get hasExpenseStats => _expenseStats.isNotEmpty;

  // ==========================================================================
  // LOAD DU LIEU
  // ==========================================================================

  Future<void> init() async {
    await loadBalanceHidden();
    await loadMonth(_selectedMonth);
  }

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
      await _loadDailyTotals();
      await _loadExpenseStats();
      _syncSelectedDay();
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

  /// Nap thong ke chi theo danh muc cha (phan cap) tu DB.
  Future<void> _loadExpenseStats() async {
    try {
      final DateTime start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final DateTime end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      _expenseStats = await _db.statsByParentCategory(
        TransactionType.expense,
        start,
        end,
      );
    } catch (e) {
      debugPrint('loadExpenseStats error: $e');
      _expenseStats = <CategoryStat>[];
    }
  }

  /// Nap tong thu/chi tung ngay trong thang dang xem (cho o lich).
  Future<void> _loadDailyTotals() async {
    try {
      final List<DailyTotal> totals =
          await _db.getDailyTotals(_selectedMonth.year, _selectedMonth.month);
      _dailyTotals = <DateTime, DailyTotal>{
        for (final DailyTotal t in totals) t.day: t,
      };
    } catch (e) {
      debugPrint('loadDailyTotals error: $e');
      _dailyTotals = <DateTime, DailyTotal>{};
    }
  }

  /// Khi doi sang thang khac, keo ngay dang chon ve trong thang do.
  /// Neu la thang hien tai thi chon dung hom nay, khong thi chon ngay 1.
  void _syncSelectedDay() {
    if (_selectedDay.year == _selectedMonth.year &&
        _selectedDay.month == _selectedMonth.month) {
      return;
    }
    final DateTime now = DateTime.now();
    if (now.year == _selectedMonth.year && now.month == _selectedMonth.month) {
      _selectedDay = DateTime(now.year, now.month, now.day);
    } else {
      _selectedDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    }
  }

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
      await _loadDailyTotals();
      await _loadExpenseStats();
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
      await _loadDailyTotals();
      await _loadExpenseStats();
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

  // ==========================================================================
  // AN / HIEN SO DU
  // ==========================================================================

  bool get balanceHidden => _balanceHidden;

  Future<void> loadBalanceHidden() async {
    final String? v = await _db.getSetting(DatabaseHelper.keyBalanceHidden);
    _balanceHidden = v == '1';
    notifyListeners();
  }

  Future<void> toggleBalanceHidden() async {
    _balanceHidden = !_balanceHidden;
    notifyListeners();
    await _db.setSetting(
      DatabaseHelper.keyBalanceHidden,
      _balanceHidden ? '1' : '0',
    );
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
