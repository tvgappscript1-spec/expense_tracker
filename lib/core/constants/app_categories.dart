import 'package:flutter/material.dart';

import '../../data/models/transaction_model.dart';

/// Danh muc giao dich.
///
/// LUU Y KY THUAT: chi luu `id` (String) xuong SQLite, KHONG luu codePoint cua
/// IconData. Neu luu codePoint roi dung IconData(codePoint) dong => Flutter se
/// bao loi tree-shake-icons khi build release.
class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final TransactionType type;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class AppCategories {
  AppCategories._();

  static const List<ExpenseCategory> expense = <ExpenseCategory>[
    ExpenseCategory(
      id: 'food',
      name: 'Ăn uống',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEF5350),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'transport',
      name: 'Di chuyển',
      icon: Icons.directions_bike_rounded,
      color: Color(0xFF42A5F5),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'shopping',
      name: 'Mua sắm',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFAB47BC),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'bills',
      name: 'Hóa đơn',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFFFA726),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'home',
      name: 'Nhà cửa',
      icon: Icons.home_rounded,
      color: Color(0xFF8D6E63),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'health',
      name: 'Sức khỏe',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF26A69A),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'education',
      name: 'Học tập',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF5C6BC0),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Giải trí',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFFEC407A),
      type: TransactionType.expense,
    ),
    ExpenseCategory(
      id: 'other_expense',
      name: 'Khác',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF78909C),
      type: TransactionType.expense,
    ),
  ];

  static const List<ExpenseCategory> income = <ExpenseCategory>[
    ExpenseCategory(
      id: 'salary',
      name: 'Lương',
      icon: Icons.payments_rounded,
      color: Color(0xFF66BB6A),
      type: TransactionType.income,
    ),
    ExpenseCategory(
      id: 'bonus',
      name: 'Thưởng',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFFFCA28),
      type: TransactionType.income,
    ),
    ExpenseCategory(
      id: 'investment',
      name: 'Đầu tư',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF29B6F6),
      type: TransactionType.income,
    ),
    ExpenseCategory(
      id: 'other_income',
      name: 'Khác',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF9CCC65),
      type: TransactionType.income,
    ),
  ];

  static const ExpenseCategory fallback = ExpenseCategory(
    id: 'other_expense',
    name: 'Khác',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF78909C),
    type: TransactionType.expense,
  );

  static List<ExpenseCategory> byType(TransactionType type) =>
      type.isExpense ? expense : income;

  static List<ExpenseCategory> get all => <ExpenseCategory>[...expense, ...income];

  /// Tra ve danh muc theo id, luon co gia tri (khong bao gio null).
  static ExpenseCategory byId(String id) {
    for (final ExpenseCategory c in all) {
      if (c.id == id) return c;
    }
    return fallback;
  }
}
