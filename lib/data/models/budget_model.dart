/// Han muc chi tieu co dinh cho 1 thang cu the.
class BudgetModel {
  final int? id;
  final int year;
  final int month; // 1..12
  final double amount;

  const BudgetModel({
    this.id,
    required this.year,
    required this.month,
    required this.amount,
  });

  factory BudgetModel.empty(DateTime monthRef) => BudgetModel(
        year: monthRef.year,
        month: monthRef.month,
        amount: 0,
      );

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'year': year,
      'month': month,
      'amount': amount,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      year: (map['year'] as int?) ?? DateTime.now().year,
      month: (map['month'] as int?) ?? DateTime.now().month,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  BudgetModel copyWith({int? id, int? year, int? month, double? amount}) {
    return BudgetModel(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      amount: amount ?? this.amount,
    );
  }

  bool get isSet => amount > 0;

  @override
  String toString() => 'BudgetModel($month/$year: $amount)';
}
