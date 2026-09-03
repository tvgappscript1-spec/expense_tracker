import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import 'add_transaction_screen.dart';
import 'budget_setting_screen.dart';
import 'debt_screen.dart';
import 'expense_calendar_screen.dart';
import 'home_screen.dart';
import 'stats_screen.dart';
import 'widgets/theme_mode_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static const String routeName = '/';

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Tổng quan',
    'Lịch chi tiêu',
    'Sổ nợ',
    'Thống kê',
  ];

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    ExpenseCalendarScreen(),
    DebtScreen(),
    StatsScreen(),
  ];

  Future<void> _openAddTransaction() async {
    final BudgetAlertLevel? alert =
        await Navigator.of(context).push<BudgetAlertLevel>(
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
          Consumer<ThemeProvider>(
            builder: (BuildContext context, ThemeProvider theme, Widget? _) {
              return IconButton(
                tooltip: 'Giao diện: ${theme.label}',
                icon: Icon(theme.icon),
                onPressed: () => ThemeModeSheet.show(context),
              );
            },
          ),
          IconButton(
            tooltip: 'Đặt hạn mức chi tiêu',
            icon: const Icon(Icons.savings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(BudgetSettingScreen.routeName),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        shape: const CircleBorder(),
        elevation: 2,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      bottomNavigationBar: _MoneyLoverBottomBar(
        currentIndex: _index,
        onTap: (int i) => setState(() => _index = i),
      ),
    );
  }
}

/// Bottom bar kieu Money Lover: 4 muc chia 2 ben, chua notch cho FAB o giua.
class _MoneyLoverBottomBar extends StatelessWidget {
  const _MoneyLoverBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return BottomAppBar(
      height: 64,
      color: scheme.surface,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _BarItem(
            index: 0,
            currentIndex: currentIndex,
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
            label: 'Tổng quan',
            onTap: onTap,
          ),
          _BarItem(
            index: 1,
            currentIndex: currentIndex,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            label: 'Lịch',
            onTap: onTap,
          ),
          // Khoang trong danh cho FAB o giua.
          const SizedBox(width: 48),
          _BarItem(
            index: 2,
            currentIndex: currentIndex,
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Sổ nợ',
            onTap: onTap,
          ),
          _BarItem(
            index: 3,
            currentIndex: currentIndex,
            icon: Icons.pie_chart_outline_rounded,
            activeIcon: Icons.pie_chart_rounded,
            label: 'Thống kê',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool selected = index == currentIndex;
    final Color color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(selected ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
