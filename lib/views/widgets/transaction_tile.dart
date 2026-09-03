import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final TransactionModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final CategoryProvider categoryProvider = context.watch<CategoryProvider>();
    final CategoryModel category = categoryProvider.byId(item.categoryId);
    final String categoryLabel = categoryProvider.displayName(item.categoryId);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isExpense = item.type.isExpense;

    return Dismissible(
      key: ValueKey<String>('tx_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.expenseColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (DismissDirection direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Text('Xoá giao dịch?'),
                content: Text(
                  '"${item.title}" · ${Formatters.money(item.amount)}',
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
      },
      onDismissed: (DismissDirection direction) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title.isEmpty ? categoryLabel : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.note.isEmpty
                            ? categoryLabel
                            : '$categoryLabel · ${item.note}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.signedMoney(item.amount, isExpense: isExpense),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isExpense
                        ? AppTheme.expenseColor
                        : AppTheme.incomeColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
