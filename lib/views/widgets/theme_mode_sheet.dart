import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// Bang chon che do giao dien truot len tu duoi man hinh.
class ThemeModeSheet extends StatelessWidget {
  const ThemeModeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const ThemeModeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeProvider theme = context.watch<ThemeProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Giao diện',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Lựa chọn được lưu lại, không mất khi tắt app.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          for (final ThemeMode mode in ThemeMode.values)
            _ModeTile(
              mode: mode,
              selected: theme.themeMode == mode,
              onTap: () async {
                await theme.setThemeMode(mode);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withOpacity(0.15)
              : scheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          ThemeProvider.iconOf(mode),
          size: 21,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        ThemeProvider.labelOf(mode),
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.primary : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        ThemeProvider.descriptionOf(mode),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : Icon(
              Icons.circle_outlined,
              color: scheme.outlineVariant,
            ),
      onTap: onTap,
    );
  }
}
