import 'dart:convert';

enum DiscountType { percentage, nominal }

class Discount {
  final int? id;
  final String name;
  final String description;
  final DiscountType type;
  final double value;
  final double minPurchase;
  final double? maxDiscount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<int>? applicableProducts;
  final List<int>? applicableCategories;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed properties
  final DateTime? expiredAt;

  Discount({
    this.id,
    required this.name,
    this.description = '',
    required this.type,
    required this.value,
    this.minPurchase = 0,
    this.maxDiscount,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.applicableProducts,
    this.applicableCategories,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        expiredAt = endDate.isBefore(DateTime.now()) ? endDate : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type == DiscountType.percentage ? 'percentage' : 'nominal',
      'value': value,
      'minPurchase': minPurchase,
      'maxDiscount': maxDiscount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'applicableProducts':
          applicableProducts != null ? jsonEncode(applicableProducts) : null,
      'applicableCategories': applicableCategories != null
          ? jsonEncode(applicableCategories)
          : null,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Discount.fromMap(Map<String, dynamic> map) {
    List<int>? parseJsonList(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return null;
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.cast<int>();
      } catch (e) {
        return null;
      }
    }

    return Discount(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      type: map['type'] == 'percentage'
          ? DiscountType.percentage
          : DiscountType.nominal,
      value: (map['value'] as num).toDouble(),
      minPurchase: (map['minPurchase'] as num?)?.toDouble() ?? 0,
      maxDiscount: (map['maxDiscount'] as num?)?.toDouble(),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      isActive: (map['isActive'] as int?) == 1,
      applicableProducts: parseJsonList(map['applicableProducts'] as String?),
      applicableCategories:
          parseJsonList(map['applicableCategories'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Discount copyWith({
    int? id,
    String? name,
    String? description,
    DiscountType? type,
    double? value,
    double? minPurchase,
    double? maxDiscount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<int>? applicableProducts,
    List<int>? applicableCategories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      minPurchase: minPurchase ?? this.minPurchase,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      applicableProducts: applicableProducts ?? this.applicableProducts,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if discount is valid for a given purchase amount
  bool isValidFor(double purchaseAmount) {
    final now = DateTime.now();
    return isActive &&
        now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1))) &&
        purchaseAmount >= minPurchase;
  }

  // Calculate discount amount
  double calculateDiscount(double amount) {
    if (!isValidFor(amount)) return 0;

    double discount;
    if (type == DiscountType.percentage) {
      discount = amount * (value / 100);
    } else {
      discount = value;
    }

    // Apply max discount cap if set
    if (maxDiscount != null && discount > maxDiscount!) {
      discount = maxDiscount!;
    }

    return discount;
  }

  // Get formatted value
  String get formattedValue {
    if (type == DiscountType.percentage) {
      return '${value.toStringAsFixed(0)}%';
    } else {
      return 'Rp ${value.toStringAsFixed(0)}';
    }
  }

  @override
  String toString() => '$name ($formattedValue)';
}

// Model for transaction discount
class TransactionDiscount {
  final int? id;
  final int transactionId;
  final int? discountId;
  final String discountName;
  final DiscountType discountType;
  final double discountValue;
  final double discountAmount;

  TransactionDiscount({
    this.id,
    required this.transactionId,
    this.discountId,
    required this.discountName,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'discountId': discountId,
      'discountName': discountName,
      'discountType':
          discountType == DiscountType.percentage ? 'percentage' : 'nominal',
      'discountValue': discountValue,
      'discountAmount': discountAmount,
    };
  }

  factory TransactionDiscount.fromMap(Map<String, dynamic> map) {
    return TransactionDiscount(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as int,
      discountId: map['discountId'] as int?,
      discountName: map['discountName'] as String,
      discountType: map['discountType'] == 'percentage'
          ? DiscountType.percentage
          : DiscountType.nominal,
      discountValue: (map['discountValue'] as num).toDouble(),
      discountAmount: (map['discountAmount'] as num).toDouble(),
    );
  }

  String get formattedValue {
    if (discountType == DiscountType.percentage) {
      return '${discountValue.toStringAsFixed(0)}%';
    } else {
      return 'Rp ${discountValue.toStringAsFixed(0)}';
    }
  }
}
