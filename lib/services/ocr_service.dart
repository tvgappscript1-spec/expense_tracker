import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Ket qua boc tach tu hoa don.
class ScannedReceipt {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final String rawText;

  const ScannedReceipt({
    this.amount,
    this.date,
    this.merchant,
    this.rawText = '',
  });

  bool get hasAnyData => amount != null || date != null || merchant != null;

  bool get isEmpty => rawText.trim().isEmpty;

  @override
  String toString() =>
      'ScannedReceipt(amount: $amount, date: $date, merchant: $merchant)';
}

class OcrException implements Exception {
  final String message;
  final Object? cause;

  const OcrException(this.message, [this.cause]);

  @override
  String toString() => 'OcrException: $message';
}

enum ImageSourceType { camera, gallery }

class OcrService {
  OcrService({TextRecognizer? recognizer, ImagePicker? picker})
      : _recognizer =
            recognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
        _picker = picker ?? ImagePicker();

  final TextRecognizer _recognizer;
  final ImagePicker _picker;

  // ==========================================================================
  // 1. LAY ANH + CHAY OCR
  // ==========================================================================

  /// Tra ve null neu nguoi dung huy chon anh.
  Future<ScannedReceipt?> scanReceipt(ImageSourceType source) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == ImageSourceType.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2200,
      );
    } on PlatformException catch (e) {
      throw OcrException(
        'Không truy cập được camera/thư viện ảnh. '
        'Hãy kiểm tra quyền trong Cài đặt.',
        e,
      );
    } catch (e) {
      throw OcrException('Không mở được camera hoặc thư viện ảnh.', e);
    }

    if (file == null) return null;
    return processImageFile(File(file.path));
  }

  /// Chay OCR tren 1 file anh co san.
  Future<ScannedReceipt> processImageFile(File imageFile) async {
    if (!await imageFile.exists()) {
      throw const OcrException('Không tìm thấy tệp ảnh vừa chọn.');
    }

    RecognizedText recognized;
    try {
      final InputImage input = InputImage.fromFile(imageFile);
      recognized = await _recognizer.processImage(input);
    } catch (e) {
      throw OcrException(
        'Không nhận dạng được chữ trong ảnh. Hãy chụp lại rõ nét hơn.',
        e,
      );
    }

    final String rawText = recognized.text;
    if (rawText.trim().isEmpty) {
      return const ScannedReceipt(rawText: '');
    }

    final List<String> lines = _splitLines(rawText);

    return ScannedReceipt(
      amount: extractAmount(lines),
      date: extractDate(rawText),
      merchant: extractMerchant(lines),
      rawText: rawText,
    );
  }

  Future<void> dispose() async {
    try {
      await _recognizer.close();
    } catch (e) {
      debugPrint('Đóng TextRecognizer lỗi: $e');
    }
  }

  // ==========================================================================
  // 2. TIEN XU LY VAN BAN
  // ==========================================================================

  static List<String> _splitLines(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Bo dau tieng Viet + chuyen thuong => so khop tu khoa on dinh hon.
  static String normalize(String input) {
    String s = input.toLowerCase();
    const Map<String, String> map = <String, String>{
      'àáạảãâầấậẩẫăằắặẳẵ': 'a',
      'èéẹẻẽêềếệểễ': 'e',
      'ìíịỉĩ': 'i',
      'òóọỏõôồốộổỗơờớợởỡ': 'o',
      'ùúụủũưừứựửữ': 'u',
      'ỳýỵỷỹ': 'y',
      'đ': 'd',
    };
    map.forEach((String chars, String replacement) {
      for (int i = 0; i < chars.length; i++) {
        s = s.replaceAll(chars[i], replacement);
      }
    });
    return s;
  }

  // ==========================================================================
  // 3. BOC TACH SO TIEN
  // ==========================================================================

  /// Tu khoa cho biet dong do chua TONG TIEN can lay.
  static const List<String> totalKeywords = <String>[
    'tong cong',
    'tong tien',
    'tong thanh toan',
    'thanh tien',
    'tien thanh toan',
    'khach tra',
    'phai tra',
    'grand total',
    'total',
    'amount due',
    'tong',
  ];

  /// Tu khoa cho biet day KHONG phai tien (SDT, ma so thue, so hoa don...).
  static const List<String> noiseKeywords = <String>[
    'dien thoai',
    'hotline',
    'tel',
    'phone',
    'sdt',
    'mst',
    'ma so thue',
    'so tai khoan',
    'stk',
    'hoa don so',
    'so hd',
    'ma hd',
    'ma giao dich',
    'ma tra cuu',
    'seri',
    'serial',
    'ban so',
    'ngay in',
  ];

  /// So tien: uu tien dang co dau ngan cach hang nghin (1.234.567 / 1,234,567),
  /// sau do la so nguyen dai >= 4 chu so.
  static final RegExp amountPattern = RegExp(
    r'\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?'
    r'|\d{4,}(?:[.,]\d{1,2})?'
    r'|\d{1,3}(?:[.,]\d{1,2})?',
  );

  /// Ky hieu tien te => cong diem uu tien cho dong chua chung.
  static final RegExp currencyMark =
      RegExp(r'(đ|d\b|vnd|vnđ|\$|usd)', caseSensitive: false);

  /// THUAT TOAN:
  /// B1. Uu tien dong co tu khoa "tong cong / thanh tien / total"
  ///     -> lay so tien LON NHAT trong cac dong do.
  /// B2. Neu khong co, quet toan bo dong (bo dong nhieu: SDT, MST...)
  ///     -> lay so tien lon nhat >= 1000.
  /// B3. Neu van khong co -> lay so lon nhat bat ky.
  static double? extractAmount(List<String> lines) {
    if (lines.isEmpty) return null;

    final List<double> priority = <double>[];
    final List<double> normal = <double>[];
    final List<double> fallback = <double>[];

    for (final String line in lines) {
      final String flat = normalize(line);

      if (noiseKeywords.any((String k) => flat.contains(k))) continue;
      if (_looksLikeDateLine(line)) continue;

      final bool isTotalLine =
          totalKeywords.any((String k) => flat.contains(k));

      for (final Match match in amountPattern.allMatches(_mergeSpacedDigits(line))) {
        final double? value = parseAmountToken(match.group(0) ?? '');
        if (value == null || value <= 0) continue;

        fallback.add(value);
        if (value < 1000) continue; // tien VND thuc te hiem khi < 1.000

        if (isTotalLine) {
          priority.add(value);
        } else if (currencyMark.hasMatch(line) || value >= 1000) {
          normal.add(value);
        }
      }
    }

    if (priority.isNotEmpty) return priority.reduce((a, b) => a > b ? a : b);
    if (normal.isNotEmpty) return normal.reduce((a, b) => a > b ? a : b);
    if (fallback.isNotEmpty) return fallback.reduce((a, b) => a > b ? a : b);
    return null;
  }

  /// Gop "1 234 567" -> "1.234.567" (OCR hay doc dau cham thanh khoang trang).
  static String _mergeSpacedDigits(String line) {
    String s = line;
    for (int i = 0; i < 3; i++) {
      s = s.replaceAllMapped(
        RegExp(r'(\d)\s(\d{3})(?!\d)'),
        (Match m) => '${m[1]}.${m[2]}',
      );
    }
    return s;
  }

  /// Chuyen chuoi so cua hoa don ve double.
  /// - "250.000"     -> 250000  (nhom 3 chu so = ngan cach hang nghin)
  /// - "1.234.567"   -> 1234567
  /// - "1,234,567.89"-> 1234567.89
  /// - "0912345678"  -> null (so dai khong ngan cach => SDT/ma so)
  static double? parseAmountToken(String token) {
    final String t = token.trim();
    if (t.isEmpty) return null;

    final String digitsOnly = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;

    final bool hasSeparator = t.contains('.') || t.contains(',');

    // Chuoi so dai lien tuc, khong ngan cach => rat co the la SDT / MST / seri.
    if (!hasSeparator && digitsOnly.length >= 9) return null;

    if (!hasSeparator) return double.tryParse(digitsOnly);

    final int lastDot = t.lastIndexOf('.');
    final int lastComma = t.lastIndexOf(',');
    final int lastSep = lastDot > lastComma ? lastDot : lastComma;
    final String tail = t.substring(lastSep + 1);

    // Duoi 3 chu so sau dau ngan cach cuoi => do la phan thap phan.
    if (tail.length == 1 || tail.length == 2) {
      final String head =
          t.substring(0, lastSep).replaceAll(RegExp(r'[^0-9]'), '');
      if (head.isEmpty) return null;
      return double.tryParse('$head.$tail');
    }

    // Con lai: tat ca dau cham/phay deu la ngan cach hang nghin.
    return double.tryParse(digitsOnly);
  }

  // ==========================================================================
  // 4. BOC TACH NGAY THANG
  // ==========================================================================

  static final RegExp _dmyPattern =
      RegExp(r'(\d{1,2})\s*[\/\-.]\s*(\d{1,2})\s*[\/\-.]\s*(\d{2,4})');

  static final RegExp _ymdPattern =
      RegExp(r'(\d{4})\s*[\/\-.]\s*(\d{1,2})\s*[\/\-.]\s*(\d{1,2})');

  static final RegExp _vietnamesePattern = RegExp(
    r'ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})\s*nam\s*(\d{4})',
    caseSensitive: false,
  );

  static bool _looksLikeDateLine(String line) {
    return _dmyPattern.hasMatch(line) || _ymdPattern.hasMatch(line);
  }

  /// Tim ngay tren hoa don. Uu tien dd/MM/yyyy vi hoa don VN dung dang nay.
  static DateTime? extractDate(String rawText) {
    final String flat = normalize(rawText);

    final Match? vn = _vietnamesePattern.firstMatch(flat);
    if (vn != null) {
      final DateTime? d = _safeDate(
        int.tryParse(vn.group(3) ?? ''),
        int.tryParse(vn.group(2) ?? ''),
        int.tryParse(vn.group(1) ?? ''),
      );
      if (d != null) return d;
    }

    for (final Match m in _dmyPattern.allMatches(rawText)) {
      int? day = int.tryParse(m.group(1) ?? '');
      int? month = int.tryParse(m.group(2) ?? '');
      int? year = int.tryParse(m.group(3) ?? '');
      if (year != null && year < 100) year += 2000;

      // Neu phan tu dau > 12 chac chan la ngay; neu ca hai <= 12 giu dd/MM.
      if (day != null && month != null && day <= 12 && month > 12) {
        final int tmp = day;
        day = month;
        month = tmp;
      }

      final DateTime? d = _safeDate(year, month, day);
      if (d != null) return d;
    }

    for (final Match m in _ymdPattern.allMatches(rawText)) {
      final DateTime? d = _safeDate(
        int.tryParse(m.group(1) ?? ''),
        int.tryParse(m.group(2) ?? ''),
        int.tryParse(m.group(3) ?? ''),
      );
      if (d != null) return d;
    }

    return null;
  }

  static DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;

    final DateTime candidate = DateTime(year, month, day);
    // Chan ngay ao kieu 31/02 (DateTime tu day sang thang sau).
    if (candidate.day != day || candidate.month != month) return null;
    // Chan ngay tuong lai qua xa (OCR doc nham).
    if (candidate.isAfter(DateTime.now().add(const Duration(days: 2)))) {
      return null;
    }
    return candidate;
  }

  // ==========================================================================
  // 5. BOC TACH TEN DON VI BAN
  // ==========================================================================

  static const List<String> _merchantStopWords = <String>[
    'hoa don',
    'invoice',
    'receipt',
    'phieu',
    'bill',
    'dia chi',
    'address',
    'ngay',
    'date',
    'so luong',
    'don gia',
    'thanh tien',
    'tong',
    'cam on',
    'thank you',
    'website',
    'www',
    'http',
  ];

  /// Ten cua hang thuong nam o 1-5 dong dau, viet HOA, it chu so.
  static String? extractMerchant(List<String> lines) {
    if (lines.isEmpty) return null;

    String? best;
    double bestScore = -1;

    final int limit = lines.length < 6 ? lines.length : 6;
    for (int i = 0; i < limit; i++) {
      final String line = lines[i].trim();
      if (line.length < 3 || line.length > 45) continue;

      final String flat = normalize(line);
      if (_merchantStopWords.any((String k) => flat.contains(k))) continue;
      if (noiseKeywords.any((String k) => flat.contains(k))) continue;

      final int letters = RegExp(r'[a-zA-ZÀ-ỹ]').allMatches(line).length;
      final int digits = RegExp(r'\d').allMatches(line).length;
      if (letters < 3) continue;
      if (digits > letters * 0.4) continue;

      final int upper = RegExp(r'[A-ZÀ-Ỹ]').allMatches(line).length;
      final double upperRatio = letters == 0 ? 0 : upper / letters;

      // Diem = ty le chu HOA + thuong o dong cang tren cang tot.
      final double score = upperRatio + (limit - i) * 0.1;
      if (score > bestScore) {
        bestScore = score;
        best = line;
      }
    }

    return best;
  }
}
