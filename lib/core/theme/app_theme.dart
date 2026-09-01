import 'package:flutter/material.dart';

/// Theme Material 3.
///
/// LUU Y: file nay co tinh KHONG dung `CardTheme` / `DialogTheme` trong
/// ThemeData vi 2 class nay bi doi ten (CardThemeData/DialogThemeData) o cac
/// ban Flutter moi => de vo build. Card/Dialog duoc style truc tiep tai cho.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF00695C);

  // Mau ngu nghia dung chung cho ca 2 che do sang/toi.
  static const Color incomeColor = Color(0xFF2E7D32);
  static const Color expenseColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFEF6C00);
  static const Color safeColor = Color(0xFF2E7D32);

  /// Bo goc bo dung chung cho card/dialog.
  static final BorderRadius cardRadius = BorderRadius.circular(20);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.5),
        space: 1,
        thickness: 1,
      ),
    );
  }

  /// Mau thanh tien do ngan sach theo % da dung.
  /// < 80%: xanh | 80% - 99%: cam | >= 100%: do
  static Color budgetColor(double ratio) {
    if (ratio >= 1.0) return expenseColor;
    if (ratio >= 0.8) return warningColor;
    return safeColor;
  }
}
