import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../providers/expense_provider.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key});

  Future<void> _pickMonth(BuildContext context) async {
    final ExpenseProvider provider = context.read<ExpenseProvider>();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedMonth,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year + 5, 12),
      helpText: 'Chọn tháng cần xem',
      locale: const Locale('vi', 'VN'),
    );
    if (picked == null) return;
    await provider.goToMonth(DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseProvider provider = context.watch<ExpenseProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: 'Tháng trước',
          onPressed: provider.goToPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: () => _pickMonth(context),
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: Text(
              'Tháng ${Formatters.monthYear.format(provider.selectedMonth)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Tháng sau',
          onPressed: provider.goToNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
