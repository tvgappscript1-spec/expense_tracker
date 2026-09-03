import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';

/// Man hinh chon danh muc 2 cap kieu Money Lover.
///
/// Mo bang `CategorySelector.pick(context, type)`, tra ve id danh muc con
/// (hoac cha neu cha khong co con) ma nguoi dung chon, hoac null neu huy.
class CategorySelector extends StatefulWidget {
  const CategorySelector({
    super.key,
    required this.type,
    this.selectedId,
  });

  final TransactionType type;
  final int? selectedId;

  static Future<int?> pick(
    BuildContext context, {
    required TransactionType type,
    int? selectedId,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => CategorySelector(type: type, selectedId: selectedId),
      ),
    );
  }

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _expandedParents = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.type.isExpense ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn danh mục'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Chi tiền'),
            Tab(text: 'Thu tiền'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _CategoryList(
            type: TransactionType.expense,
            selectedId: widget.selectedId,
            expandedParents: _expandedParents,
            onToggleExpand: _toggleExpand,
          ),
          _CategoryList(
            type: TransactionType.income,
            selectedId: widget.selectedId,
            expandedParents: _expandedParents,
            onToggleExpand: _toggleExpand,
          ),
        ],
      ),
    );
  }

  void _toggleExpand(int parentId) {
    setState(() {
      if (_expandedParents.contains(parentId)) {
        _expandedParents.remove(parentId);
      } else {
        _expandedParents.add(parentId);
      }
    });
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.type,
    required this.selectedId,
    required this.expandedParents,
    required this.onToggleExpand,
  });

  final TransactionType type;
  final int? selectedId;
  final Set<int> expandedParents;
  final void Function(int) onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final CategoryProvider provider = context.watch<CategoryProvider>();
    final List<CategoryGroup> groups = provider.groups(type);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (groups.isEmpty) {
      return Center(
        child: Text(
          'Chưa có danh mục nào',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) {
        final CategoryGroup group = groups[index];
        final CategoryModel parent = group.parent;
        final bool expanded = expandedParents.contains(parent.id);
        final bool parentSelected = parent.id == selectedId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              leading: _CategoryAvatar(
                icon: parent.icon,
                color: parent.color,
                selected: parentSelected,
              ),
              title: Text(
                parent.name,
                style: TextStyle(
                  fontWeight:
                      parentSelected ? FontWeight.w800 : FontWeight.w600,
                  color: parentSelected ? parent.color : scheme.onSurface,
                ),
              ),
              trailing: group.hasChildren
                  ? IconButton(
                      icon: Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      onPressed: () => onToggleExpand(parent.id!),
                    )
                  : (parentSelected
                      ? Icon(Icons.check_circle_rounded, color: parent.color)
                      : null),
              onTap: () {
                // Cha khong co con -> chon thang cha.
                // Cha co con -> bam la xo/thu danh sach con.
                if (group.hasChildren) {
                  onToggleExpand(parent.id!);
                } else {
                  Navigator.of(context).pop(parent.id);
                }
              },
            ),
            if (expanded)
              ...group.children.map((CategoryModel child) {
                final bool childSelected = child.id == selectedId;
                return Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: ListTile(
                    leading: _CategoryAvatar(
                      icon: child.icon,
                      color: child.color,
                      selected: childSelected,
                      small: true,
                    ),
                    title: Text(
                      child.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: childSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color:
                            childSelected ? child.color : scheme.onSurface,
                      ),
                    ),
                    trailing: childSelected
                        ? Icon(Icons.check_circle_rounded, color: child.color)
                        : null,
                    onTap: () => Navigator.of(context).pop(child.id),
                  ),
                );
              }),
            Divider(
              height: 1,
              indent: 72,
              color: scheme.outlineVariant.withOpacity(0.4),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.icon,
    required this.color,
    required this.selected,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final double size = small ? 36 : 44;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(selected ? 0.9 : 0.16),
        shape: BoxShape.circle,
        border: selected ? Border.all(color: color, width: 2) : null,
      ),
      child: Icon(
        icon,
        size: small ? 18 : 22,
        color: selected ? Colors.white : color,
      ),
    );
  }
}
