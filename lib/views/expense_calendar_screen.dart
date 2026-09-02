import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';
import '../providers/expense_provider.dart';
import '../services/database_helper.dart';
import 'add_transaction_screen.dart';
import 'widgets/transaction_tile.dart';

class ExpenseCalendarScreen extends StatelessWidget {
  const ExpenseCalendarScreen({super.key});

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
    final List<TransactionModel> dayItems = provider.transactionsOfSelectedDay;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: AppTheme.cardRadius,
                ),
                child: _CalendarBody(provider: provider),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _DaySummaryHeader(
              day: provider.selectedDay,
              total: provider.totalOfDay(provider.selectedDay),
              count: dayItems.length,
            ),
          ),
          if (dayItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 30, 32, 60),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.event_available_outlined,
                      size: 44,
                      color: scheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ngày này chưa có giao dịch nào',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.35),
                    borderRadius: AppTheme.cardRadius,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < dayItems.length; i++) ...<Widget>[
                        TransactionTile(
                          item: dayItems[i],
                          onTap: () => _editTransaction(context, dayItems[i]),
                          onDelete: () =>
                              _deleteTransaction(context, dayItems[i]),
                        ),
                        if (i != dayItems.length - 1)
                          Divider(
                            height: 1,
                            indent: 64,
                            color: scheme.outlineVariant.withOpacity(0.4),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// LICH THANG
// ============================================================================

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.provider});

  final ExpenseProvider provider;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();

    return TableCalendar<TransactionModel>(
      locale: 'vi_VN',
      firstDay: DateTime(now.year - 5, 1, 1),
      lastDay: DateTime(now.year + 5, 12, 31),
      focusedDay: provider.selectedMonth,
      currentDay: DateTime(now.year, now.month, now.day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      rowHeight: 62,
      daysOfWeekHeight: 22,
      availableGestures: AvailableGestures.horizontalSwipe,
      eventLoader: provider.eventsForDay,

      selectedDayPredicate: (DateTime day) =>
          isSameDay(provider.selectedDay, day),

      onDaySelected: (DateTime selected, DateTime focused) {
        provider.selectDay(selected);
      },

      // Vuot trai/phai doi thang -> nap lai du lieu thang moi tu SQLite.
      onPageChanged: (DateTime focused) {
        provider.goToMonth(DateTime(focused.year, focused.month));
      },

      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        leftChevronIcon: Icon(Icons.chevron_left_rounded, color: scheme.primary),
        rightChevronIcon:
            Icon(Icons.chevron_right_rounded, color: scheme.primary),
      ),

      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        weekendStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.expenseColor.withOpacity(0.8),
        ),
      ),

      calendarStyle: const CalendarStyle(outsideDaysVisible: false),

      // Tu ve tung o de nhet duoc so tien ben duoi so ngay.
      calendarBuilders: CalendarBuilders<TransactionModel>(
        defaultBuilder: (BuildContext context, DateTime day, DateTime focused) =>
            _DayCell(day: day, total: provider.totalOfDay(day)),
        outsideBuilder: (BuildContext context, DateTime day, DateTime focused) =>
            const SizedBox.shrink(),
        todayBuilder: (BuildContext context, DateTime day, DateTime focused) =>
            _DayCell(
          day: day,
          total: provider.totalOfDay(day),
          isToday: true,
        ),
        selectedBuilder:
            (BuildContext context, DateTime day, DateTime focused) => _DayCell(
          day: day,
          total: provider.totalOfDay(day),
          isSelected: true,
        ),
      ),
    );
  }
}

/// Mot o ngay tren lich: so ngay o tren, tong tien o duoi.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.total,
    this.isToday = false,
    this.isSelected = false,
  });

  final DateTime day;
  final DailyTotal? total;
  final bool isToday;
  final bool isSelected;

  /// Rut gon tien cho vua o lich: 250000 -> "250k", 1250000 -> "1,2tr"
  static String _shorten(double value) {
    if (value >= 1000000) {
      final double m = value / 1000000;
      final String text = m >= 10
          ? m.toStringAsFixed(0)
          : m.toStringAsFixed(1).replaceAll('.', ',');
      return '${text}tr';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Color background = Colors.transparent;
    Color dayColor = scheme.onSurface;
    Border? border;

    if (isSelected) {
      background = scheme.primary;
      dayColor = scheme.onPrimary;
    } else if (isToday) {
      border = Border.all(color: scheme.primary, width: 1.4);
      dayColor = scheme.primary;
    }

    final DailyTotal? data = total;
    final bool hasExpense = data != null && data.expense > 0;
    final bool hasIncome = data != null && data.income > 0;

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isToday || isSelected
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: dayColor,
            ),
          ),
          if (hasExpense)
            Text(
              '-${_shorten(data.expense)}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: isSelected
                    ? scheme.onPrimary
                    : AppTheme.expenseColor,
              ),
            ),
          if (hasIncome)
            Text(
              '+${_shorten(data.income)}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: isSelected ? scheme.onPrimary : AppTheme.incomeColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// TIEU DE NGAY DANG CHON
// ============================================================================

class _DaySummaryHeader extends StatelessWidget {
  const _DaySummaryHeader({
    required this.day,
    required this.total,
    required this.count,
  });

  final DateTime day;
  final DailyTotal? total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DailyTotal? data = total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  Formatters.dayHeader(day),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count giao dịch',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (data != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (data.expense > 0)
                  Text(
                    '- ${Formatters.money(data.expense)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                if (data.income > 0)
                  Text(
                    '+ ${Formatters.money(data.income)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.incomeColor,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
