// Return type enum - MUST match stockMovement types for proper grouping
enum ReturnType {
  sales,      // Retur dari pembeli (STOCK IN +)
  supplier,   // Retur ke supplier (STOCK OUT -)
  outlet,     // Retur dari outlet (STOCK IN +)
  adjustment, // Adjustments (neutral)
}

extension ReturnTypeExtension on ReturnType {
  String get label {
    switch (this) {
      case ReturnType.outlet:
        return 'Outlet';
      case ReturnType.supplier:
        return 'Supplier';
      case ReturnType.sales:
        return 'Penjualan';
      case ReturnType.adjustment:
        return 'Penyesuaian';
    }
  }

  String get dbValue {
    switch (this) {
      case ReturnType.outlet:
        return 'OUTLET';
      case ReturnType.supplier:
        return 'SUPPLIER';
      case ReturnType.sales:
        return 'SALES';
      case ReturnType.adjustment:
        return 'ADJUSTMENT';
    }
  }

  bool get isStockIn {
    return this == ReturnType.sales || this == ReturnType.outlet;
  }
}

// Table name constant
class ReturnTable {
  static const String name = 'returns';
  
  // Column names
  static const String id = 'id';
  static const String productId = 'productId';
  static const String productName = 'productName';
  static const String quantity = 'quantity';
  static const String price = 'price';
  static const String cost = 'cost';
  static const String returnType = 'returnType';
  static const String referenceId = 'referenceId';
  static const String referenceNumber = 'referenceNumber';
  static const String notes = 'notes';
  static const String createdAt = 'createdAt';
  static const String createdBy = 'createdBy';
}

// Model for returns table (separate from transactions)
class Return {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double cost;
  final ReturnType returnType;
  final int? referenceId;
  final String? referenceNumber;
  final String? notes;
  final DateTime createdAt;
  final int? createdBy;

  Return({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.cost,
    required this.returnType,
    this.referenceId,
    this.referenceNumber,
    this.notes,
    DateTime? createdAt,
    this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  String get returnTypeLabel {
    switch (returnType) {
      case ReturnType.outlet:
        return 'Outlet';
      case ReturnType.supplier:
        return 'Supplier';
      case ReturnType.sales:
        return 'Penjualan';
      case ReturnType.adjustment:
        return 'Penyesuaian';
    }
  }

  double get subtotal => price * quantity;
  double get totalCost => cost * quantity;
  double get profit => subtotal - totalCost;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'cost': cost,
      'returnType': returnType.dbValue,
      'referenceId': referenceId,
      'referenceNumber': referenceNumber,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory Return.fromMap(Map<String, dynamic> map) {
    ReturnType type;
    switch (map['returnType'] as String?) {
      case 'OUTLET':
        type = ReturnType.outlet;
        break;
      case 'SUPPLIER':
        type = ReturnType.supplier;
        break;
      case 'SALES':
        type = ReturnType.sales;
        break;
      case 'ADJUSTMENT':
        type = ReturnType.adjustment;
        break;
      default:
        type = ReturnType.outlet;
    }

    return Return(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      returnType: type,
      referenceId: map['referenceId'] as int?,
      referenceNumber: map['referenceNumber'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      createdBy: map['createdBy'] as int?,
    );
  }

  Return copyWith({
    int? id,
    int? productId,
    String? productName,
    int? quantity,
    double? price,
    double? cost,
    ReturnType? returnType,
    int? referenceId,
    String? referenceNumber,
    String? notes,
    DateTime? createdAt,
    int? createdBy,
  }) {
    return Return(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      returnType: returnType ?? this.returnType,
      referenceId: referenceId ?? this.referenceId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
