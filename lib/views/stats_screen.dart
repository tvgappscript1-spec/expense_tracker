import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../providers/expense_provider.dart';
import '../services/database_helper.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _touchedIndex = -1;

  /// Id danh muc cha dang duoc xo ra xem con (null = chua xo cai nao).
  int? _expandedParentId;

  @override
  Widget build(BuildContext context) {
    final ExpenseProvider provider = context.watch<ExpenseProvider>();
    final List<CategoryStat> stats = provider.expenseStats;

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
          if (stats.isEmpty)
            const _EmptyChart(message: 'Chưa có khoản chi nào trong tháng này.')
          else
            _CategoryPieSection(
              stats: stats,
              total: provider.totalExpense,
              touchedIndex: _touchedIndex,
              expandedParentId: _expandedParentId,
              onTouch: (int index) => setState(() => _touchedIndex = index),
              onToggleExpand: (int parentId) => setState(() {
                _expandedParentId =
                    _expandedParentId == parentId ? null : parentId;
              }),
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
// BIEU DO TRON PHAN CAP (bam cha -> xo con)
// ============================================================================

class _CategoryPieSection extends StatelessWidget {
  const _CategoryPieSection({
    required this.stats,
    required this.total,
    required this.touchedIndex,
    required this.expandedParentId,
    required this.onTouch,
    required this.onToggleExpand,
  });

  final List<CategoryStat> stats;
  final double total;
  final int touchedIndex;
  final int? expandedParentId;
  final void Function(int) onTouch;
  final void Function(int) onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

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
                        onTouch(response.touchedSection!.touchedSectionIndex);
                      },
                    ),
                    sections: List<PieChartSectionData>.generate(
                      stats.length,
                      (int i) {
                        final CategoryStat stat = stats[i];
                        final double percent =
                            total <= 0 ? 0 : (stat.total / total) * 100;
                        final bool touched = i == touchedIndex;
                        return PieChartSectionData(
                          value: stat.total,
                          color: stat.color,
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
          // Danh sach cha; bam cha co con -> xo ra danh sach con ben duoi.
          Column(
            children: List<Widget>.generate(stats.length, (int i) {
              final CategoryStat parent = stats[i];
              final double percent =
                  total <= 0 ? 0 : (parent.total / total) * 100;
              final bool expanded = expandedParentId == parent.categoryId;

              return Column(
                children: <Widget>[
                  InkWell(
                    onTap: parent.hasChildren
                        ? () => onToggleExpand(parent.categoryId)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: parent.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(parent.icon, size: 17, color: parent.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              parent.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
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
                            Formatters.money(parent.total),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (parent.hasChildren)
                            Icon(
                              expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            )
                          else
                            const SizedBox(width: 20),
                        ],
                      ),
                    ),
                  ),
                  if (expanded)
                    ...parent.children.map((CategoryStat child) {
                      final double childPercent = parent.total <= 0
                          ? 0
                          : (child.total / parent.total) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 34,
                          top: 2,
                          bottom: 2,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(child.icon, size: 15, color: parent.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                child.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${childPercent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              Formatters.money(child.total),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withOpacity(0.3),
                  ),
                ],
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
