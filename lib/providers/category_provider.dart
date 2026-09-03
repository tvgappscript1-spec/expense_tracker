import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';

/// Quan ly danh muc 2 cap (doc tu DB, cache trong bo nho).
class CategoryProvider extends ChangeNotifier {
  CategoryProvider({DatabaseHelper? database})
      : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  List<CategoryModel> _all = <CategoryModel>[];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _all = await _db.getAllCategories();
      _errorMessage = null;
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Không tải được danh mục.';
      debugPrint('CategoryProvider.load: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // TRA CUU
  // ==========================================================================

  /// Tra ve danh muc theo id. Luon co gia tri (fallback neu khong tim thay).
  CategoryModel byId(int id) {
    for (final CategoryModel c in _all) {
      if (c.id == id) return c;
    }
    return _fallback;
  }

  /// Nhan hien thi day du: "Cha • Con" neu la con, chi "Cha" neu la cha.
  String displayName(int id) {
    final CategoryModel c = byId(id);
    if (c.parentId == null) return c.name;
    final CategoryModel parent = byId(c.parentId!);
    return '${parent.name} • ${c.name}';
  }

  static const CategoryModel _fallback = CategoryModel(
    id: 0,
    name: 'Khác',
    iconCodePoint: 0xe16c, // Icons.more_horiz_rounded
    colorValue: 0xFF78909C,
    type: TransactionType.expense,
  );

  /// Danh sach cha kem con, cho UI chon danh muc.
  List<CategoryGroup> groups(TransactionType type) {
    final List<CategoryModel> parents = _all
        .where((CategoryModel c) => c.type == type && c.isParent)
        .toList()
      ..sort((CategoryModel a, CategoryModel b) =>
          a.sortOrder.compareTo(b.sortOrder));

    return parents.map((CategoryModel parent) {
      final List<CategoryModel> children = _all
          .where((CategoryModel c) => c.parentId == parent.id)
          .toList()
        ..sort((CategoryModel a, CategoryModel b) =>
            a.sortOrder.compareTo(b.sortOrder));
      return CategoryGroup(parent: parent, children: children);
    }).toList();
  }

  /// Danh muc mac dinh khi mo form (con dau tien cua cha dau tien, hoac cha).
  int? defaultCategoryId(TransactionType type) {
    final List<CategoryGroup> g = groups(type);
    if (g.isEmpty) return null;
    final CategoryGroup first = g.first;
    if (first.hasChildren) return first.children.first.id;
    return first.parent.id;
  }

  // ==========================================================================
  // CRUD
  // ==========================================================================

  Future<void> addCategory(CategoryModel category) async {
    try {
      await _db.insertCategory(category);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _db.updateCategory(category);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _db.deleteCategory(id);
      await load();
    } on LocalDatabaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }
}
