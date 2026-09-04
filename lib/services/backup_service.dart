import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_helper.dart';

/// Ket qua doc file backup, dung de hien so lieu cho nguoi dung xac nhan
/// truoc khi ghi de.
class BackupPreview {
  final Map<String, List<Map<String, dynamic>>> data;
  final int transactionCount;
  final int categoryCount;
  final int debtCount;
  final DateTime? exportedAt;
  final int schemaVersion;

  const BackupPreview({
    required this.data,
    required this.transactionCount,
    required this.categoryCount,
    required this.debtCount,
    required this.exportedAt,
    required this.schemaVersion,
  });
}

class BackupException implements Exception {
  final String message;
  final Object? cause;
  const BackupException(this.message, [this.cause]);
  @override
  String toString() => 'BackupException: $message';
}

class BackupService {
  BackupService({DatabaseHelper? database})
      : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Dinh danh file backup - dung de nhan biet dung file cua app nay.
  static const String _magic = 'expense_tracker_backup';
  static const int _formatVersion = 1;

  // ==========================================================================
  // XUAT
  // ==========================================================================

  /// Tao file backup .json va mo hop thoai chia se (Drive, Zalo, email...).
  /// Tra ve duong dan file da tao.
  Future<String> exportAndShare() async {
    try {
      final String jsonStr = await _buildBackupJson();

      final Directory dir = await getTemporaryDirectory();
      final String stamp = _timestamp(DateTime.now());
      final String path = '${dir.path}/sao_luu_chi_tieu_$stamp.json';
      final File file = File(path);
      await file.writeAsString(jsonStr, flush: true);

      await Share.shareXFiles(
        <XFile>[XFile(path, mimeType: 'application/json')],
        subject: 'Sao lưu Quản lý chi tiêu',
        text: 'Tệp sao lưu dữ liệu chi tiêu ngày ${_dateVi(DateTime.now())}',
      );

      return path;
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Không tạo được tệp sao lưu.', e);
    }
  }

  /// Chi ghi file vao thu muc tai ve, khong mo chia se (cho may khong co app
  /// nhan chia se). Tra ve duong dan.
  Future<String> exportToFile() async {
    try {
      final String jsonStr = await _buildBackupJson();
      Directory? dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();
      final String stamp = _timestamp(DateTime.now());
      final String path = '${dir.path}/sao_luu_chi_tieu_$stamp.json';
      await File(path).writeAsString(jsonStr, flush: true);
      return path;
    } catch (e) {
      throw BackupException('Không lưu được tệp sao lưu.', e);
    }
  }

  Future<String> _buildBackupJson() async {
    final Map<String, List<Map<String, dynamic>>> tables =
        await _db.exportAllTables();

    final Map<String, dynamic> payload = <String, dynamic>{
      'magic': _magic,
      'format_version': _formatVersion,
      'schema_version': _db.schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'Quan ly chi tieu',
      'tables': tables,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // ==========================================================================
  // NHAP
  // ==========================================================================

  /// Cho nguoi dung chon file backup, doc va kiem tra tinh hop le.
  /// Tra ve null neu nguoi dung huy chon.
  Future<BackupPreview?> pickAndParse() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
    } catch (e) {
      throw BackupException('Không mở được trình chọn tệp.', e);
    }

    if (picked == null || picked.files.isEmpty) return null;

    final String? path = picked.files.single.path;
    if (path == null) {
      throw const BackupException('Không đọc được đường dẫn tệp.');
    }

    return parseFile(File(path));
  }

  Future<BackupPreview> parseFile(File file) async {
    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      throw BackupException('Không đọc được nội dung tệp.', e);
    }

    Map<String, dynamic> map;
    try {
      final Object? decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupException('Tệp không đúng định dạng sao lưu.');
      }
      map = decoded;
    } catch (e) {
      if (e is BackupException) rethrow;
      throw const BackupException(
        'Tệp không phải là bản sao lưu hợp lệ (không đọc được JSON).',
      );
    }

    if (map['magic'] != _magic) {
      throw const BackupException(
        'Tệp này không phải bản sao lưu của ứng dụng Quản lý chi tiêu.',
      );
    }

    final int schemaVersion = (map['schema_version'] as int?) ?? 0;
    if (schemaVersion > _db.schemaVersion) {
      throw BackupException(
        'Tệp được tạo từ phiên bản app mới hơn (CSDL v$schemaVersion). '
        'Hãy cập nhật app lên bản mới nhất rồi thử lại.',
      );
    }

    final Object? rawTables = map['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const BackupException('Tệp sao lưu thiếu dữ liệu bảng.');
    }

    // Ep kieu ve dang chuan.
    final Map<String, List<Map<String, dynamic>>> tables =
        <String, List<Map<String, dynamic>>>{};
    for (final MapEntry<String, dynamic> entry in rawTables.entries) {
      final Object? rows = entry.value;
      if (rows is! List) continue;
      tables[entry.key] = rows
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> r) => Map<String, dynamic>.from(r))
          .toList();
    }

    DateTime? exportedAt;
    final Object? ts = map['exported_at'];
    if (ts is String) exportedAt = DateTime.tryParse(ts);

    return BackupPreview(
      data: tables,
      transactionCount: tables[DatabaseHelper.tableTransactions]?.length ?? 0,
      categoryCount: tables[DatabaseHelper.tableCategories]?.length ?? 0,
      debtCount: tables[DatabaseHelper.tableDebts]?.length ?? 0,
      exportedAt: exportedAt,
      schemaVersion: schemaVersion,
    );
  }

  /// Ghi de du lieu hien tai bang du lieu tu backup.
  Future<void> restore(BackupPreview preview) async {
    await _db.importAllTables(preview.data);
  }

  // ==========================================================================
  // TIEN ICH
  // ==========================================================================

  static String _timestamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }

  static String _dateVi(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
