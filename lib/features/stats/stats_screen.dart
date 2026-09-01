import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_categories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/expense_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final ExpenseProvider provider = context.watch<ExpenseProvider>();
    final Map<String, double> byCategory = provider.expenseByCategory;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: <Widget>[
          _SectionTitle(
            title: 'Cơ cấu chi tiêu',
            subtitle:
                'Tháng ${Formatters.monthYear.format(provider.selectedMonth)}',
          ),
          const SizedBox(height: 12),
          if (byCategory.isEmpty)
            const _EmptyChart(message: 'Chưa có khoản chi nào trong tháng này.')
          else
            _CategoryPieSection(
              data: byCategory,
              total: provider.totalExpense,
              touchedIndex: _touchedIndex,
              onTouch: (int index) => setState(() => _touchedIndex = index),
            ),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'Xu hướng thu chi',
            subtitle: '6 tháng gần nhất',
          ),
          const SizedBox(height: 12),
          if (provider.trend.isEmpty)
            const _EmptyChart(message: 'Chưa đủ dữ liệu để vẽ biểu đồ.')
          else
            _TrendBarSection(data: provider.trend),
        ],
      ),
    );
  }
}

// ============================================================================
// BIEU DO TRON
// ============================================================================

class _CategoryPieSection extends StatelessWidget {
  const _CategoryPieSection({
    required this.data,
    required this.total,
    required this.touchedIndex,
    required this.onTouch,
  });

  final Map<String, double> data;
  final double total;
  final int touchedIndex;
  final void Function(int) onTouch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<MapEntry<String, double>> entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: AppTheme.cardRadius,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 58,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback:
                          (FlTouchEvent event, PieTouchResponse? response) {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          onTouch(-1);
                          return;
                        }
                        onTouch(
                          response.touchedSection!.touchedSectionIndex,
                        );
                      },
                    ),
                    sections: List<PieChartSectionData>.generate(
                      entries.length,
                      (int i) {
                        final ExpenseCategory category =
                            AppCategories.byId(entries[i].key);
                        final double value = entries[i].value;
                        final double percent =
                            total <= 0 ? 0 : (value / total) * 100;
                        final bool touched = i == touchedIndex;

                        return PieChartSectionData(
                          value: value,
                          color: category.color,
                          radius: touched ? 62 : 52,
                          title: percent < 6
                              ? ''
                              : '${percent.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Tổng chi',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.moneyCompact(total),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: List<Widget>.generate(entries.length, (int i) {
              final ExpenseCategory category =
                  AppCategories.byId(entries[i].key);
              final double value = entries[i].value;
              final double percent = total <= 0 ? 0 : (value / total) * 100;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(category.icon, size: 16, color: category.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Formatters.money(value),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BIEU DO COT
// ============================================================================

class _TrendBarSection extends StatelessWidget {
  const _TrendBarSection({required this.data});

  final List<MonthlySummary> data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    double maxValue = 0;
    for (final MonthlySummary m in data) {
      if (m.income > maxValue) maxValue = m.income;
      if (m.expense > maxValue) maxValue = m.expense;
    }
    if (maxValue <= 0) maxValue = 1000000;
    final double maxY = maxValue * 1.25;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: AppTheme.cardRadius,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (
                      BarChartGroupData group,
                      int groupIndex,
                      BarChartRodData rod,
                      int rodIndex,
                    ) {
                      return BarTooltipItem(
                        '${rodIndex == 0 ? 'Thu' : 'Chi'}\n'
                        '${Formatters.money(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (double value) => FlLine(
                    color: scheme.outlineVariant.withOpacity(0.35),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: maxY / 4,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            Formatters.moneyCompact(value),
                            style: TextStyle(
                              fontSize: 9.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            Formatters.shortMonth.format(data[index].month),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  data.length,
                  (int i) => BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: data[i].income,
                        color: AppTheme.incomeColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: data[i].expense,
                        color: AppTheme.expenseColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _LegendDot(color: AppTheme.incomeColor, label: 'Thu'),
              SizedBox(width: 20),
              _LegendDot(color: AppTheme.expenseColor, label: 'Chi'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

// ============================================================================
// PHU TRO
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: AppTheme.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
