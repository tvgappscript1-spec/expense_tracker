import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/expense_provider.dart';
import '../budget_setting_screen.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ExpenseProvider provider = context.watch<ExpenseProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (!provider.hasBudget) {
      return _EmptyBudgetCard(scheme: scheme);
    }

    final double ratio = provider.budgetRatio;
    final Color color = AppTheme.budgetColor(ratio);
    final bool exceeded = ratio >= 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: scheme.surfaceContainerHighest.withOpacity(0.45),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                exceeded
                    ? Icons.error_rounded
                    : (ratio >= 0.8
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hạn mức tháng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${provider.budgetPercent}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sửa hạn mức',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tune_rounded, size: 18),
                onPressed: () => Navigator.of(context)
                    .pushNamed(BudgetSettingScreen.routeName),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: provider.budgetProgress),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: scheme.outlineVariant.withOpacity(0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${Formatters.money(provider.totalExpense)} / '
                '${Formatters.money(provider.budgetLimit)}',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              Text(
                exceeded
                    ? 'Vượt ${Formatters.money(provider.budgetOverspent)}'
                    : 'Còn ${Formatters.money(provider.budgetRemaining)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (!exceeded) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Trung bình còn được chi '
              '${Formatters.money(provider.dailyAllowance)}/ngày đến cuối tháng.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBudgetCard extends StatelessWidget {
  const _EmptyBudgetCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.savings_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa đặt hạn mức cho tháng này',
              style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushNamed(BudgetSettingScreen.routeName),
            child: const Text('Đặt ngay'),
          ),
        ],
      ),
    );
  }
}
