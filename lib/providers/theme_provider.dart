import 'package:flutter/material.dart';

import '../services/database_helper.dart';

/// Quan ly che do giao dien: Theo he thong / Sang / Toi.
///
/// Lua chon duoc luu xuong bang `settings` trong SQLite nen giu nguyen sau khi
/// tat mo app, va giu nguyen ca khi cai de APK moi.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({DatabaseHelper? database})
      : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  /// Nap lua chon da luu. Goi mot lan khi khoi dong app.
  Future<void> load() async {
    final String? saved = await _db.getSetting(DatabaseHelper.keyThemeMode);
    _themeMode = _decode(saved);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners(); // doi mau ngay, khong cho ghi DB xong moi doi
    await _db.setSetting(DatabaseHelper.keyThemeMode, _encode(mode));
  }

  /// Bat/tat nhanh giua Sang va Toi (bo qua che do theo he thong).
  Future<void> toggle(BuildContext context) async {
    final bool isDarkNow = isDark(context);
    await setThemeMode(isDarkNow ? ThemeMode.light : ThemeMode.dark);
  }

  /// Giao dien dang thuc su toi hay khong (tinh ca truong hop theo he thong).
  bool isDark(BuildContext context) {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  // ==========================================================================
  // NHAN HIEN THI
  // ==========================================================================

  String get label => labelOf(_themeMode);

  static String labelOf(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Theo hệ thống';
      case ThemeMode.light:
        return 'Luôn sáng';
      case ThemeMode.dark:
        return 'Luôn tối';
    }
  }

  static String descriptionOf(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Tự đổi theo cài đặt của điện thoại';
      case ThemeMode.light:
        return 'Nền sáng, chữ tối';
      case ThemeMode.dark:
        return 'Nền tối, dịu mắt khi dùng ban đêm';
    }
  }

  static IconData iconOf(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  IconData get icon => iconOf(_themeMode);

  // ==========================================================================
  // MA HOA / GIAI MA de luu xuong DB
  // ==========================================================================

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
