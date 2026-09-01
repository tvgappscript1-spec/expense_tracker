import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat compact = NumberFormat.compactCurrency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 1,
  );

  static final NumberFormat plainNumber = NumberFormat.decimalPattern('vi_VN');

  static final DateFormat dayMonthYear = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final DateFormat dayFull = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN');
  static final DateFormat monthYear = DateFormat('MM/yyyy', 'vi_VN');
  static final DateFormat shortMonth = DateFormat('MM/yy', 'vi_VN');

  static String money(double value) => currency.format(value);

  static String moneyCompact(double value) => compact.format(value);

  static String signedMoney(double value, {required bool isExpense}) =>
      '${isExpense ? '-' : '+'} ${currency.format(value.abs())}';

  static String date(DateTime value) => dayMonthYear.format(value);

  static String dayHeader(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(value.year, value.month, value.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return 'Hôm nay · ${dayMonthYear.format(value)}';
    if (diff == 1) return 'Hôm qua · ${dayMonthYear.format(value)}';
    return dayFull.format(value);
  }

  /// Chuyen chuoi nguoi dung go ("1.500.000" / "1,500,000") ve double.
  static double parseInput(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }
}

/// Tu dong chen dau cham ngan cach hang nghin khi nguoi dung go so tien.
class ThousandsInputFormatter extends TextInputFormatter {
  ThousandsInputFormatter({this.maxDigits = 15});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    // Bo cac so 0 vo nghia o dau (giu lai 1 chu so neu tat ca la 0).
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final String formatted = Formatters.plainNumber.format(int.parse(digits));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
