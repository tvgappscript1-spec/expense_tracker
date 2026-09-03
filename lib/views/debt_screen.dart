import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/expense_provider.dart';
import 'widgets/category_selector_widget.dart';

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DebtProvider provider = context.watch<DebtProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (provider.isLoading && provider.debts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<DebtModel> unsettled = provider.unsettled;
    final List<DebtModel> settled = provider.settled;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: <Widget>[
            _SummaryRow(
              borrowing: provider.totalBorrowing,
              lending: provider.totalLending,
            ),
            const SizedBox(height: 20),
            if (unsettled.isEmpty && settled.isEmpty)
              const _EmptyDebt()
            else ...<Widget>[
              if (unsettled.isNotEmpty) ...<Widget>[
                _GroupHeader(title: 'Chưa tất toán (${unsettled.length})'),
                ...unsettled.map((DebtModel d) => _DebtCard(debt: d)),
              ],
              if (settled.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _GroupHeader(title: 'Đã tất toán (${settled.length})'),
                ...settled.map((DebtModel d) => _DebtCard(debt: d)),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'debt_fab',
        onPressed: () => _openAddDebt(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm khoản nợ'),
      ),
    );
  }

  Future<void> _openAddDebt(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddDebtSheet(),
    );
  }
}

// ============================================================================
// TONG QUAN
// ============================================================================

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.borrowing, required this.lending});

  final double borrowing;
  final double lending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryBox(
            label: 'Đang nợ',
            hint: 'Mình vay người khác',
            value: borrowing,
            color: AppTheme.expenseColor,
            icon: Icons.call_received_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryBox(
            label: 'Cho nợ',
            hint: 'Người khác nợ mình',
            value: lending,
            color: AppTheme.incomeColor,
            icon: Icons.call_made_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.hint,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String hint;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ============================================================================
// THE 1 KHOAN NO
// ============================================================================

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt});

  final DebtModel debt;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isBorrow = debt.type.isBorrow;
    final Color color = isBorrow ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: AppTheme.cardRadius,
        border: debt.isOverdue
            ? Border.all(color: AppTheme.expenseColor, width: 1.4)
            : null,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBorrow
                      ? Icons.call_received_rounded
                      : Icons.call_made_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      debt.person,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${debt.type.label} · ${Formatters.date(debt.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (debt.dueDate != null)
                      Text(
                        'Hạn: ${Formatters.date(debt.dueDate!)}'
                        '${debt.isOverdue ? ' · Quá hạn' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: debt.isOverdue
                              ? AppTheme.expenseColor
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    Formatters.money(debt.amount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (debt.isSettled)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Đã trả',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.incomeColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (debt.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                debt.note,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: debt.isSettled
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                        ),
                        onPressed: () => _unsettle(context),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Hoàn tác'),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          backgroundColor: color,
                        ),
                        onPressed: () => _settle(context),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(isBorrow ? 'Trả nợ' : 'Đã thu'),
                      ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Xoá',
                onPressed: () => _delete(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _settle(BuildContext context) async {
    final DebtProvider debtProvider = context.read<DebtProvider>();
    final ExpenseProvider expenseProvider = context.read<ExpenseProvider>();
    final CategoryProvider categoryProvider = context.read<CategoryProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // Tat toan sinh giao dich Thu/Chi -> can chon danh muc cho giao dich do.
    final TransactionType txType =
        debt.type.isBorrow ? TransactionType.expense : TransactionType.income;

    final int? categoryId = await CategorySelector.pick(
      context,
      type: txType,
    );
    if (categoryId == null) return;

    try {
      await debtProvider.settle(debt, categoryRef: categoryId);
      await expenseProvider.refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            debt.type.isBorrow
                ? 'Đã trả nợ ${debt.person}, ghi nhận khoản chi.'
                : 'Đã thu nợ ${debt.person}, ghi nhận khoản thu.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          content: Text('Không tất toán được: $e'),
        ),
      );
    }
  }

  Future<void> _unsettle(BuildContext context) async {
    final DebtProvider debtProvider = context.read<DebtProvider>();
    final ExpenseProvider expenseProvider = context.read<ExpenseProvider>();
    await debtProvider.unsettle(debt);
    await expenseProvider.refresh();
  }

  Future<void> _delete(BuildContext context) async {
    final DebtProvider debtProvider = context.read<DebtProvider>();
    final ExpenseProvider expenseProvider = context.read<ExpenseProvider>();
    final int? id = debt.id;
    if (id == null) return;

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Xoá khoản nợ?'),
            content: Text(
              debt.isSettled
                  ? 'Khoản này đã tất toán. Xoá sẽ gỡ luôn giao dịch Thu/Chi đã sinh.'
                  : '"${debt.person}" · ${Formatters.money(debt.amount)}',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppTheme.expenseColor,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Xoá'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;
    await debtProvider.deleteDebt(id);
    await expenseProvider.refresh();
  }
}

class _EmptyDebt extends StatelessWidget {
  const _EmptyDebt();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 50, 32, 40),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: scheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Chưa có khoản vay nợ nào',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn "Thêm khoản nợ" để theo dõi tiền đi vay hoặc cho vay.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FORM THEM KHOAN NO
// ============================================================================

class _AddDebtSheet extends StatefulWidget {
  const _AddDebtSheet();

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DebtType _type = DebtType.borrow;
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDue}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDue ? (_dueDate ?? now) : _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: isDue ? 'Chọn hạn trả' : 'Chọn ngày vay',
    );
    if (picked == null) return;
    setState(() {
      if (isDue) {
        _dueDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final DebtProvider provider = context.read<DebtProvider>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final DebtModel debt = DebtModel.create(
        person: _personController.text.trim(),
        amount: Formatters.parseInput(_amountController.text),
        type: _type,
        date: _date,
        dueDate: _dueDate,
        note: _noteController.text.trim(),
      );
      await provider.addDebt(debt);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          content: Text('Không lưu được: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Thêm khoản nợ',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<DebtType>(
              segments: const <ButtonSegment<DebtType>>[
                ButtonSegment<DebtType>(
                  value: DebtType.borrow,
                  label: Text('Đi vay'),
                  icon: Icon(Icons.call_received_rounded),
                ),
                ButtonSegment<DebtType>(
                  value: DebtType.lend,
                  label: Text('Cho vay'),
                  icon: Icon(Icons.call_made_rounded),
                ),
              ],
              selected: <DebtType>{_type},
              onSelectionChanged: (Set<DebtType> value) =>
                  setState(() => _type = value.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _personController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _type.isBorrow ? 'Vay của ai' : 'Cho ai vay',
                hintText: 'VD: Anh Minh',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Nhập tên người' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: <ThousandsInputFormatter>[
                ThousandsInputFormatter(),
              ],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                labelText: 'Số tiền',
                hintText: '0',
                suffixText: '₫',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (String? v) {
                final double amount = Formatters.parseInput(v ?? '');
                if (amount <= 0) return 'Nhập số tiền lớn hơn 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isDue: false),
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ngày vay',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      child: Text(Formatters.date(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isDue: true),
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Hạn trả',
                        prefixIcon: const Icon(Icons.event_available_rounded),
                        suffixIcon: _dueDate == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () =>
                                    setState(() => _dueDate = null),
                              ),
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'Không'
                            : Formatters.date(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
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
              label: const Text('Lưu khoản nợ'),
            ),
          ],
        ),
      ),
    );
  }
}
