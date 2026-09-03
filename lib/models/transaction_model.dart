/// Loai giao dich: chi tieu hoac thu nhap.
enum TransactionType { expense, income }

extension TransactionTypeX on TransactionType {
  bool get isExpense => this == TransactionType.expense;
  bool get isIncome => this == TransactionType.income;

  String get label => isExpense ? 'Chi' : 'Thu';

  static TransactionType fromIndex(int index) {
    if (index < 0 || index >= TransactionType.values.length) {
      return TransactionType.expense;
    }
    return TransactionType.values[index];
  }
}

class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  /// Id danh muc CON trong bang categories (danh muc 2 cap).
  final int categoryId;

  /// Ma danh muc cu dang chuoi (food/transport...) - chi de doc du lieu v1
  /// da luu truoc khi len danh muc 2 cap. Ban ghi moi de rong.
  final String legacyCategory;
  final TransactionType type;
  final String note;
  final DateTime createdAt;

  const TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.type,
    this.legacyCategory = '',
    this.note = '',
    required this.createdAt,
  });

  factory TransactionModel.create({
    required String title,
    required double amount,
    required DateTime date,
    required int categoryId,
    required TransactionType type,
    String note = '',
  }) {
    return TransactionModel(
      title: title,
      amount: amount,
      date: date,
      categoryId: categoryId,
      type: type,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  /// Chuyen sang Map de ghi vao SQLite.
  /// Ngay thang luu duoi dang milliseconds (INTEGER) de sort/filter nhanh.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'category_ref': categoryId,
      'category_id': legacyCategory,
      'type': type.index,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.fromMillisecondsSinceEpoch(
        (map['date'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      categoryId: (map['category_ref'] as int?) ?? 0,
      legacyCategory: (map['category_id'] as String?) ?? '',
      type: TransactionTypeX.fromIndex((map['type'] as int?) ?? 0),
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  TransactionModel copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    int? categoryId,
    String? legacyCategory,
    TransactionType? type,
    String? note,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      legacyCategory: legacyCategory ?? this.legacyCategory,
      type: type ?? this.type,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Ngay (bo gio phut giay) - dung de gom nhom theo ngay.
  DateTime get dayKey => DateTime(date.year, date.month, date.day);

  @override
  String toString() =>
      'TransactionModel(id: $id, title: $title, amount: $amount, type: ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          other.id == id &&
          other.title == title &&
          other.amount == amount &&
          other.date == date &&
          other.categoryId == categoryId &&
          other.type == type &&
          other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, title, amount, date, categoryId, type, note);
}
