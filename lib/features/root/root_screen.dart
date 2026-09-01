import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/expense_provider.dart';
import '../budget/budget_setting_screen.dart';
import '../home/home_screen.dart';
import '../stats/stats_screen.dart';
import '../transaction/add_transaction_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  static const String routeName = '/';

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  static const List<String> _titles = <String>['Tổng quan', 'Thống kê'];

  Future<void> _openAddTransaction() async {
    final BudgetAlertLevel? alert = await Navigator.of(context).push<BudgetAlertLevel>(
      MaterialPageRoute<BudgetAlertLevel>(
        builder: (_) => const AddTransactionScreen(),
      ),
    );
    if (!mounted || alert == null) return;
    _showBudgetAlert(alert);
  }

  void _showBudgetAlert(BudgetAlertLevel level) {
    if (level == BudgetAlertLevel.none) return;

    final ExpenseProvider provider = context.read<ExpenseProvider>();

    if (level == BudgetAlertLevel.warning) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 5),
            content: Row(
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã dùng ${provider.budgetPercent}% hạn mức tháng. '
                    'Còn lại ${Formatters.money(provider.budgetRemaining)}.',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      return;
    }

    // Vuot 100% => dialog chan de nguoi dung buoc phai doc.
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.error_outline_rounded,
            color: AppTheme.expenseColor, size: 40),
        title: const Text('Vượt hạn mức chi tiêu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Tháng ${Formatters.monthYear.format(provider.selectedMonth)} '
              'đã chi ${Formatters.money(provider.totalExpense)} / '
              '${Formatters.money(provider.budgetLimit)}.',
            ),
            const SizedBox(height: 8),
            Text(
              'Vượt ${Formatters.money(provider.budgetOverspent)} '
              '(${provider.budgetPercent}% hạn mức).',
              style: const TextStyle(
                color: AppTheme.expenseColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamed(BudgetSettingScreen.routeName);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Chỉnh hạn mức'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: <Widget>[
          IconButton(
            tooltip: 'Đặt hạn mức chi tiêu',
            icon: const Icon(Icons.savings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(BudgetSettingScreen.routeName),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const <Widget>[HomeScreen(), StatsScreen()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransaction,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Thống kê',
          ),
        ],
      ),
    );
  }
}
