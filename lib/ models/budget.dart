import 'dart:convert';

class Budget {
  final String id;
  final String categoryId;
  final double limit;
  final double spent;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  Budget({
    required this.id,
    required this.categoryId,
    required this.limit,
    this.spent = 0.0,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  double get remainingAmount => limit - spent;
  double get percentageUsed => spent / limit * 100;
  bool get isOverBudget => spent > limit;
  bool get isNearLimit => percentageUsed >= 80;

  Budget copyWith({
    String? id,
    String? categoryId,
    double? limit,
    double? spent,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'limit': limit,
      'spent': spent,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] ?? '',
      categoryId: map['categoryId'] ?? '',
      limit: (map['limit'] ?? 0.0).toDouble(),
      spent: (map['spent'] ?? 0.0).toDouble(),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] ?? 0),
      isActive: map['isActive'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Budget.fromJson(String source) =>
      Budget.fromMap(json.decode(source));
}
