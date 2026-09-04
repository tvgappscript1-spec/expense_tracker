import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../providers/category_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/expense_provider.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  static const String routeName = '/backup';

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _service = BackupService();
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await _service.exportAndShare();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã tạo tệp sao lưu. Hãy lưu vào Drive hoặc gửi Zalo.'),
        ),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          content: Text(e.message),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final BackupPreview? preview = await _service.pickAndParse();
      if (preview == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      if (!mounted) return;
      final bool confirm = await _confirmRestore(preview);
      if (!confirm) {
        setState(() => _busy = false);
        return;
      }

      await _service.restore(preview);

      // Nap lai TAT CA provider de UI phan anh du lieu vua khoi phuc.
      if (!mounted) return;
      await context.read<CategoryProvider>().load();
      await context.read<ExpenseProvider>().init();
      await context.read<DebtProvider>().load();

      messenger.showSnackBar(
        const SnackBar(content: Text('Đã khôi phục dữ liệu thành công.')),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          duration: const Duration(seconds: 5),
          content: Text(e.message),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.expenseColor,
          content: Text('Lỗi khi khôi phục: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRestore(BackupPreview preview) async {
    final String when = preview.exportedAt == null
        ? 'không rõ'
        : Formatters.date(preview.exportedAt!);

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warningColor, size: 40),
            title: const Text('Khôi phục dữ liệu?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Tệp sao lưu ngày: $when'),
                const SizedBox(height: 8),
                Text('• ${preview.transactionCount} giao dịch'),
                Text('• ${preview.categoryCount} danh mục'),
                Text('• ${preview.debtCount} khoản nợ'),
                const SizedBox(height: 12),
                const Text(
                  'Toàn bộ dữ liệu hiện tại sẽ bị thay thế bằng dữ liệu trong '
                  'tệp này. Không thể hoàn tác.',
                  style: TextStyle(
                    color: AppTheme.expenseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppTheme.warningColor,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Khôi phục'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu & Khôi phục')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppTheme.cardRadius,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.cloud_off_rounded,
                      color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dữ liệu chỉ nằm trên máy này. Hãy sao lưu định kỳ và cất '
                      'tệp vào Google Drive hoặc gửi cho chính mình qua Zalo để '
                      'không mất khi đổi máy.',
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
            _ActionCard(
              icon: Icons.upload_file_rounded,
              iconColor: AppTheme.incomeColor,
              title: 'Sao lưu dữ liệu',
              description:
                  'Tạo một tệp chứa toàn bộ giao dịch, danh mục, ngân sách và '
                  'sổ nợ. Sau đó chọn nơi lưu (Drive, Zalo, email...).',
              buttonText: 'Tạo tệp sao lưu',
              onPressed: _busy ? null : _export,
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.download_rounded,
              iconColor: AppTheme.warningColor,
              title: 'Khôi phục dữ liệu',
              description:
                  'Chọn một tệp sao lưu đã tạo trước đó để nạp lại dữ liệu. '
                  'Thao tác này sẽ thay thế toàn bộ dữ liệu hiện tại.',
              buttonText: 'Chọn tệp để khôi phục',
              onPressed: _busy ? null : _import,
            ),
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mẹo: đặt lịch nhắc sao lưu mỗi cuối tháng để luôn có '
                        'bản mới nhất.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: AppTheme.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
