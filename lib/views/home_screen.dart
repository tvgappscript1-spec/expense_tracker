import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';
import '../providers/expense_provider.dart';
import 'add_transaction_screen.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/month_selector.dart';
import 'widgets/summary_card.dart';
import 'widgets/transaction_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _editTransaction(
    BuildContext context,
    TransactionModel item,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddTransactionScreen(editing: item),
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    TransactionModel item,
  ) async {
    final ExpenseProvider provider = context.read<ExpenseProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int? id = item.id;
    if (id == null) return;

    try {
      await provider.deleteTransaction(id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Đã xoá "${item.title}"'),
            action: SnackBarAction(
              label: 'Hoàn tác',
              onPressed: () => provider.restoreTransaction(item),
            ),
          ),
        );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          content: Text('Không xoá được giao dịch: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseProvider provider = context.watch<ExpenseProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (provider.isLoading && provider.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<DateTime, List<TransactionModel>> grouped = provider.groupedByDay;
    final List<DateTime> days = grouped.keys.toList(growable: false);

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                const MonthSelector(),
                const SizedBox(height: 8),
                SummaryCard(
                  income: provider.totalIncome,
                  expense: provider.totalExpense,
                  balance: provider.balance,
                ),
                const SizedBox(height: 12),
                const BudgetProgressCard(),
                if (provider.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: provider.errorMessage!),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Text(
                      'Giao dịch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${provider.transactions.length})',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ]),
            ),
          ),
          if (days.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final DateTime day = days[index];
                    final List<TransactionModel> items = grouped[day]!;
                    return _DaySection(
                      day: day,
                      items: items,
                      onEdit: (TransactionModel t) =>
                          _editTransaction(context, t),
                      onDelete: (TransactionModel t) =>
                          _deleteTransaction(context, t),
                    );
                  },
                  childCount: days.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime day;
  final List<TransactionModel> items;
  final void Function(TransactionModel) onEdit;
  final void Function(TransactionModel) onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    double dayTotal = 0;
    for (final TransactionModel t in items) {
      dayTotal += t.type.isExpense ? -t.amount : t.amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Formatters.dayHeader(day),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                Formatters.money(dayTotal),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: dayTotal < 0
                      ? AppTheme.expenseColor
                      : AppTheme.incomeColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.35),
            borderRadius: AppTheme.cardRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                TransactionTile(
                  item: items[i],
                  onTap: () => onEdit(items[i]),
                  onDelete: () => onDelete(items[i]),
                ),
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: scheme.outlineVariant.withOpacity(0.4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: scheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Tháng này chưa có giao dịch nào',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn "Thêm" để nhập tay hoặc quét hoá đơn bằng camera.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => context.read<ExpenseProvider>().refresh(),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
