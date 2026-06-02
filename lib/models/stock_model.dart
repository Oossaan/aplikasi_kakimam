// Stock movement types
enum StockMovementType { stockIn, stockOut, adjustment, return_ }

class StockMovement {
  final int? id;
  final int productId;
  final StockMovementType type;
  final int quantity;
  final int previousStock;
  final int newStock;
  final int? referenceId;
  final String notes;
  final int? userId;
  final DateTime createdAt;

  // Optional joined fields
  final String? productName;
  final String? userName;
  final String? referenceType; // 'transaction', 'adjustment', etc.
  final String? invoiceNumber; // dari join ke transactions

  StockMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.referenceId,
    this.notes = '',
    this.userId,
    DateTime? createdAt,
    this.productName,
    this.userName,
    this.referenceType,
    this.invoiceNumber,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    String typeStr;
    switch (type) {
      case StockMovementType.stockIn:
        typeStr = 'in';
        break;
      case StockMovementType.stockOut:
        typeStr = 'out';
        break;
      case StockMovementType.adjustment:
        typeStr = 'adjustment';
        break;
      case StockMovementType.return_:
        typeStr = 'return';
        break;
    }

    return {
      'id': id,
      'productId': productId,
      'type': typeStr,
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'referenceId': referenceId,
      'notes': notes,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    StockMovementType type;
    switch (map['type'] as String) {
      case 'in':
        type = StockMovementType.stockIn;
        break;
      case 'out':
        type = StockMovementType.stockOut;
        break;
      case 'return':
        type = StockMovementType.return_;
        break;
      default:
        type = StockMovementType.adjustment;
    }

    return StockMovement(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      type: type,
      quantity: map['quantity'] as int,
      previousStock: map['previousStock'] as int,
      newStock: map['newStock'] as int,
      referenceId: map['referenceId'] as int?,
      notes: map['notes'] as String? ?? '',
      userId: map['userId'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      productName: map['productName'] as String?,
      userName: map['userName'] as String?,
      referenceType: map['referenceType'] as String?,
      invoiceNumber: map['invoiceNumber'] as String?,
    );
  }

  String get typeLabel {
    switch (type) {
      case StockMovementType.stockIn:
        return 'Masuk';
      case StockMovementType.stockOut:
        return 'Keluar';
      case StockMovementType.adjustment:
        return 'Penyesuaian';
      case StockMovementType.return_:
        return 'Retur';
    }
  }

  bool get isPositive =>
      type == StockMovementType.stockIn || type == StockMovementType.return_;
}

// ============================================================
// Grouping models for invoice/product stock history grouping
// ============================================================

/// Represents a product item aggregated within a stock history card
class StockHistoryProductItem {
  final int productId;
  final String productName;
  final int totalQuantity;
  final String? referenceType;

  StockHistoryProductItem({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    this.referenceType,
  });
}

/// Represents a grouped stock history card (by invoice or supplier reference)
class StockHistoryGroup {
  final int? referenceId;
  final String referenceLabel;
  final String referenceType; // 'transaction' or 'supplier'
  final DateTime createdAt;
  final List<StockHistoryProductItem> products;
  final int totalQuantity;

  StockHistoryGroup({
    this.referenceId,
    required this.referenceLabel,
    required this.referenceType,
    required this.createdAt,
    required this.products,
    required this.totalQuantity,
  });
}

// Audit log action types
enum AuditAction { create, update, delete, void_ }

class AuditLog {
  final int? id;
  final String tableName;
  final int recordId;
  final AuditAction action;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? changedBy;
  final String? reason;
  final DateTime createdAt;

  AuditLog({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.oldValues,
    this.newValues,
    this.changedBy,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    String actionStr;
    switch (action) {
      case AuditAction.create:
        actionStr = 'create';
        break;
      case AuditAction.update:
        actionStr = 'update';
        break;
      case AuditAction.delete:
        actionStr = 'delete';
        break;
      case AuditAction.void_:
        actionStr = 'void';
        break;
    }

    return {
      'id': id,
      'tableName': tableName,
      'recordId': recordId,
      'action': actionStr,
      'oldValues': oldValues != null ? _encodeJson(oldValues!) : null,
      'newValues': newValues != null ? _encodeJson(newValues!) : null,
      'changedBy': changedBy,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    AuditAction action;
    switch (map['action'] as String) {
      case 'create':
        action = AuditAction.create;
        break;
      case 'delete':
        action = AuditAction.delete;
        break;
      case 'void':
        action = AuditAction.void_;
        break;
      default:
        action = AuditAction.update;
    }

    return AuditLog(
      id: map['id'] as int?,
      tableName: map['tableName'] as String,
      recordId: map['recordId'] as int,
      action: action,
      oldValues: map['oldValues'] != null
          ? _decodeJson(map['oldValues'] as String)
          : null,
      newValues: map['newValues'] != null
          ? _decodeJson(map['newValues'] as String)
          : null,
      changedBy: map['changedBy'] as String?,
      reason: map['reason'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  static String _encodeJson(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  static Map<String, dynamic> _decodeJson(String data) {
    final Map<String, dynamic> result = {};
    if (data.isEmpty) return result;
    try {
      for (var item in data.split('|')) {
        final parts = item.split(':');
        if (parts.length == 2 && parts[0].isNotEmpty) {
          result[parts[0]] = parts[1];
        }
      }
    } catch (e) {
      // Return empty map on error
    }
    return result;
  }

  String get actionLabel {
    switch (action) {
      case AuditAction.create:
        return 'Dibuat';
      case AuditAction.update:
        return 'Diubah';
      case AuditAction.delete:
        return 'Dihapus';
      case AuditAction.void_:
        return 'Dibatalkan';
    }
  }

  @override
  String toString() => '$actionLabel on $tableName #$recordId';
}
