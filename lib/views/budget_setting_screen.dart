import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../providers/expense_provider.dart';

class BudgetSettingScreen extends StatefulWidget {
  const BudgetSettingScreen({super.key});

  static const String routeName = '/budget-setting';

  @override
  State<BudgetSettingScreen> createState() => _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<BudgetSettingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  bool _isSaving = false;

  static const List<double> _quickAmounts = <double>[
    3000000,
    5000000,
    8000000,
    10000000,
    15000000,
    20000000,
  ];

  @override
  void initState() {
    super.initState();
    final ExpenseProvider provider = context.read<ExpenseProvider>();
    if (provider.hasBudget) {
      _controller.text =
          Formatters.plainNumber.format(provider.budgetLimit.round());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final ExpenseProvider provider = context.read<ExpenseProvider>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      await provider.setBudget(Formatters.parseInput(_controller.text));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã lưu hạn mức chi tiêu.')),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          content: Text('Không lưu được hạn mức: $e'),
        ),
      );
    }
  }

  Future<void> _clear() async {
    final ExpenseProvider provider = context.read<ExpenseProvider>();
    await provider.clearBudget();
    if (!mounted) return;
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseProvider provider = context.watch<ExpenseProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hạn mức chi tiêu'),
        actions: <Widget>[
          if (provider.hasBudget)
            IconButton(
              tooltip: 'Xoá hạn mức',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clear,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppTheme.cardRadius,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded,
                        color: scheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hạn mức áp dụng cho tháng '
                        '${Formatters.monthYear.format(provider.selectedMonth)}. '
                        'App sẽ cảnh báo khi chi vượt 80% và 100% hạn mức.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: <ThousandsInputFormatter>[
                  ThousandsInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  labelText: 'Hạn mức mỗi tháng',
                  hintText: '0',
                  suffixText: '₫',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
                validator: (String? value) {
                  final double amount = Formatters.parseInput(value ?? '');
                  if (amount <= 0) return 'Nhập hạn mức lớn hơn 0';
                  if (amount > 999999999999) return 'Hạn mức quá lớn';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((double amount) {
                  return ActionChip(
                    label: Text(Formatters.moneyCompact(amount)),
                    onPressed: () {
                      _controller.text =
                          Formatters.plainNumber.format(amount.round());
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              if (provider.hasBudget) _CurrentStatus(provider: provider),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Lưu hạn mức'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentStatus extends StatelessWidget {
  const _CurrentStatus({required this.provider});

  final ExpenseProvider provider;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = AppTheme.budgetColor(provider.budgetRatio);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: AppTheme.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tình hình hiện tại',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: provider.budgetProgress,
              minHeight: 12,
              backgroundColor: scheme.outlineVariant.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Đã chi',
            value: Formatters.money(provider.totalExpense),
            color: AppTheme.expenseColor,
          ),
          _Row(
            label: 'Hạn mức',
            value: Formatters.money(provider.budgetLimit),
            color: scheme.onSurface,
          ),
          _Row(
            label: provider.budgetRatio >= 1 ? 'Vượt hạn mức' : 'Còn lại',
            value: Formatters.money(
              provider.budgetRatio >= 1
                  ? provider.budgetOverspent
                  : provider.budgetRemaining,
            ),
            color: color,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
