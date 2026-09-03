import 'package:flutter/foundation.dart';

import '../models/debt_model.dart';
import '../services/database_helper.dart';

class DebtProvider extends ChangeNotifier {
  DebtProvider({DatabaseHelper? database})
      : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  List<DebtModel> _debts = <DebtModel>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<DebtModel> get debts => List.unmodifiable(_debts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<DebtModel> get unsettled =>
      _debts.where((DebtModel d) => !d.isSettled).toList(growable: false);
  List<DebtModel> get settled =>
      _debts.where((DebtModel d) => d.isSettled).toList(growable: false);

  /// Tong minh dang no nguoi khac (di vay chua tra).
  double get totalBorrowing => _debts
      .where((DebtModel d) => !d.isSettled && d.type.isBorrow)
      .fold<double>(0, (double s, DebtModel d) => s + d.amount);

  /// Tong nguoi khac dang no minh (cho vay chua thu).
  double get totalLending => _debts
      .where((DebtModel d) => !d.isSettled && d.type.isLend)
      .fold<double>(0, (double s, DebtModel d) => s + d.amount);

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _debts = await _db.getDebts();
      _errorMessage = null;
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Không tải được sổ nợ.';
      debugPrint('DebtProvider.load: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDebt(DebtModel debt) async {
    try {
      await _db.insertDebt(debt);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDebt(DebtModel debt) async {
    try {
      await _db.updateDebt(debt);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDebt(int id) async {
    try {
      await _db.deleteDebt(id);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Tat toan: sinh giao dich Thu/Chi tuong ung.
  /// Tra ve true neu thanh cong (de UI biet ma reload danh sach giao dich).
  Future<bool> settle(DebtModel debt, {required int categoryRef}) async {
    try {
      await _db.settleDebt(debt, categoryRef: categoryRef);
      await load();
      return true;
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unsettle(DebtModel debt) async {
    try {
      await _db.unsettleDebt(debt);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }
}
