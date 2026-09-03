/// Loai khoan no.
enum DebtType {
  /// Minh di vay nguoi khac (tien vao tui minh, sau tra ra => CHI).
  borrow,

  /// Minh cho nguoi khac vay (tien ra khoi tui, sau thu ve => THU).
  lend,
}

extension DebtTypeX on DebtType {
  bool get isBorrow => this == DebtType.borrow;
  bool get isLend => this == DebtType.lend;

  String get label => isBorrow ? 'Đi vay' : 'Cho vay';

  static DebtType fromIndex(int index) {
    if (index < 0 || index >= DebtType.values.length) return DebtType.borrow;
    return DebtType.values[index];
  }
}

class DebtModel {
  final int? id;

  /// Ten nguoi vay/cho vay.
  final String person;
  final double amount;
  final DebtType type;
  final DateTime date;

  /// Han tra (khong bat buoc).
  final DateTime? dueDate;
  final String note;
  final bool isSettled;

  /// Ngay tat toan (null neu chua tra).
  final DateTime? settledAt;

  /// Id giao dich Thu/Chi duoc sinh ra khi tat toan (de xoa keo theo neu can).
  final int? settleTransactionId;

  final DateTime createdAt;

  const DebtModel({
    this.id,
    required this.person,
    required this.amount,
    required this.type,
    required this.date,
    this.dueDate,
    this.note = '',
    this.isSettled = false,
    this.settledAt,
    this.settleTransactionId,
    required this.createdAt,
  });

  factory DebtModel.create({
    required String person,
    required double amount,
    required DebtType type,
    required DateTime date,
    DateTime? dueDate,
    String note = '',
  }) {
    return DebtModel(
      person: person,
      amount: amount,
      type: type,
      date: date,
      dueDate: dueDate,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'person': person,
      'amount': amount,
      'type': type.index,
      'date': date.millisecondsSinceEpoch,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'note': note,
      'is_settled': isSettled ? 1 : 0,
      'settled_at': settledAt?.millisecondsSinceEpoch,
      'settle_transaction_id': settleTransactionId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    DateTime? fromMillis(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

    return DebtModel(
      id: map['id'] as int?,
      person: (map['person'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: DebtTypeX.fromIndex((map['type'] as int?) ?? 0),
      date: fromMillis(map['date']) ?? DateTime.now(),
      dueDate: fromMillis(map['due_date']),
      note: (map['note'] as String?) ?? '',
      isSettled: ((map['is_settled'] as int?) ?? 0) == 1,
      settledAt: fromMillis(map['settled_at']),
      settleTransactionId: map['settle_transaction_id'] as int?,
      createdAt: fromMillis(map['created_at']) ?? DateTime.now(),
    );
  }

  DebtModel copyWith({
    int? id,
    String? person,
    double? amount,
    DebtType? type,
    DateTime? date,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? note,
    bool? isSettled,
    DateTime? settledAt,
    bool clearSettledAt = false,
    int? settleTransactionId,
    bool clearSettleTransactionId = false,
    DateTime? createdAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      person: person ?? this.person,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      settledAt: clearSettledAt ? null : (settledAt ?? this.settledAt),
      settleTransactionId: clearSettleTransactionId
          ? null
          : (settleTransactionId ?? this.settleTransactionId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isOverdue =>
      !isSettled &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ));

  @override
  String toString() =>
      'DebtModel(id: $id, $person, ${type.name}, $amount, settled: $isSettled)';
}
