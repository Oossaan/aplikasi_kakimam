import 'package:flutter/foundation.dart';
import '../models/stock_model.dart';
import 'database_service.dart';

class StockService {
  // Record stock movement
  static Future<int> recordMovement({
    required int productId,
    required StockMovementType type,
    required int quantity,
    required int previousStock,
    required int newStock,
    int? referenceId,
    String notes = '',
    int? userId,
    String? referenceType,
  }) async {
    // Ensure referenceType is always set using helper
    final effectiveReferenceType = referenceType ?? _inferReferenceType(notes, type);

    return await DatabaseService.insert('stockMovements', {
      'productId': productId,
      'type': type == StockMovementType.stockIn
          ? 'in'
          : type == StockMovementType.stockOut
              ? 'out'
              : type == StockMovementType.return_
                  ? 'return'
                  : 'adjustment',
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'referenceId': referenceId,
      'notes': notes,
      'userId': userId,
      'referenceType': effectiveReferenceType,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // Infer reference type from notes and movement type
  static String _inferReferenceType(String notes, StockMovementType type) {
    final lowerNotes = notes.toLowerCase();

    if (lowerNotes.contains('supplier') || lowerNotes.contains('diterima dari') || lowerNotes.contains('pembelian')) {
      return 'supplier';
    }
    if (lowerNotes.contains('penjualan') || lowerNotes.contains('pos') || lowerNotes.contains('transaksi')) {
      return 'transaction';
    }
    if (lowerNotes.contains('outlet')) {
      return 'outlet';
    }
    if (lowerNotes.contains('retur')) {
      return 'return';
    }
    if (lowerNotes.contains('adjustment') || lowerNotes.contains('penyesuaian')) {
      return 'adjustment';
    }
    if (lowerNotes.contains('good issue') || lowerNotes.contains('rusak') || lowerNotes.contains('hilang')) {
      return 'good_issue';
    }

    // Default based on movement type
    switch (type) {
      case StockMovementType.stockIn:
        return 'supplier';
      case StockMovementType.stockOut:
        return 'transaction';
      case StockMovementType.return_:
        return 'return';
      case StockMovementType.adjustment:
        return 'adjustment';
    }
  }

  // Infer source type from notes (for backward compatibility with existing data)
  static String inferSourceType(String notes, StockMovementType type) {
    return _inferReferenceType(notes, type);
  }

  // Get stock history for a product
  static Future<List<StockMovement>> getProductHistory(
    int productId, {
    int? limit,
  }) async {
    final results = await DatabaseService.query(
      'stockMovements',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return results.map((map) => StockMovement.fromMap(map)).toList();
  }

  // Get all stock movements with filters
  static Future<List<StockMovement>> getMovements({
    DateTime? startDate,
    DateTime? endDate,
    StockMovementType? type,
    int? productId,
    int? limit,
    int? offset,
  }) async {
    String where = '1=1';
    List<Object> whereArgs = [];

    if (startDate != null) {
      where += ' AND sm.createdAt >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where += ' AND sm.createdAt <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    if (type != null) {
      String typeStr;
      switch (type) {
        case StockMovementType.stockIn:
          typeStr = 'in';
          break;
        case StockMovementType.stockOut:
          typeStr = 'out';
          break;
        case StockMovementType.return_:
          typeStr = 'return';
          break;
        default:
          typeStr = 'adjustment';
      }
      where += ' AND sm.type = ?';
      whereArgs.add(typeStr);
    }
    if (productId != null) {
      where += ' AND sm.productId = ?';
      whereArgs.add(productId);
    }

    // Use JOIN to get product name
    final results = await DatabaseService.rawQuery('''
      SELECT sm.*, p.name as productName
      FROM stockMovements sm
      LEFT JOIN products p ON sm.productId = p.id
      WHERE $where
      ORDER BY sm.createdAt DESC
      ${limit != null ? 'LIMIT $limit' : ''}
      ${offset != null ? 'OFFSET $offset' : ''}
    ''', whereArgs.isEmpty ? null : whereArgs);

    return results.map((map) {
      return StockMovement(
        id: map['id'] as int?,
        productId: map['productId'] as int,
        type: _parseType(map['type'] as String?),
        quantity: map['quantity'] as int,
        previousStock: map['previousStock'] as int,
        newStock: map['newStock'] as int,
        referenceId: map['referenceId'] as int?,
        notes: map['notes'] as String? ?? '',
        userId: map['userId'] as int?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        productName: map['productName'] as String?,
        referenceType: map['referenceType'] as String?,
      );
    }).toList();
  }

  static StockMovementType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'in':
        return StockMovementType.stockIn;
      case 'out':
        return StockMovementType.stockOut;
      case 'return':
        return StockMovementType.return_;
      default:
        return StockMovementType.adjustment;
    }
  }

  // Add stock (purchase/stock in)
  static Future<void> addStock({
    required int productId,
    required int quantity,
    int? referenceId,
    String notes = '',
    int? userId,
    String? referenceType,
  }) async {
    final currentStock = await _getCurrentStock(productId);
    final newStock = currentStock + quantity;

    await DatabaseService.update(
      'products',
      {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Record movement with explicit referenceType
    await recordMovement(
      productId: productId,
      type: StockMovementType.stockIn,
      quantity: quantity,
      previousStock: currentStock,
      newStock: newStock,
      referenceId: referenceId,
      notes: notes,
      userId: userId,
      referenceType: referenceType,
    );
  }

  // Remove stock (sale/stock out)
  static Future<void> removeStock({
    required int productId,
    required int quantity,
    int? referenceId,
    String notes = '',
    int? userId,
    String? referenceType,
  }) async {
    final currentStock = await _getCurrentStock(productId);
    final newStock = currentStock - quantity;

    if (newStock < 0) {
      throw Exception(
          'Insufficient stock. Current: $currentStock, requested: $quantity');
    }

    await DatabaseService.update(
      'products',
      {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Record movement with explicit referenceType
    await recordMovement(
      productId: productId,
      type: StockMovementType.stockOut,
      quantity: quantity,
      previousStock: currentStock,
      newStock: newStock,
      referenceId: referenceId,
      notes: notes,
      userId: userId,
      referenceType: referenceType,
    );
  }

  // Adjust stock (manual adjustment)
  static Future<void> adjustStock({
    required int productId,
    required int newStock,
    String notes = '',
    int? userId,
  }) async {
    final currentStock = await _getCurrentStock(productId);
    final quantity = newStock - currentStock;

    await DatabaseService.update(
      'products',
      {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Record movement
    await recordMovement(
      productId: productId,
      type: StockMovementType.adjustment,
      quantity: quantity.abs(),
      previousStock: currentStock,
      newStock: newStock,
      notes: notes.isNotEmpty ? notes : 'Manual adjustment',
      userId: userId,
    );
  }

  // Restore stock (for void transaction)
  static Future<void> restoreStock({
    required int productId,
    required int quantity,
    int? referenceId,
    String notes = '',
    int? userId,
  }) async {
    final currentStock = await _getCurrentStock(productId);
    final newStock = currentStock + quantity;

    await DatabaseService.update(
      'products',
      {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Record movement
    await recordMovement(
      productId: productId,
      type: StockMovementType.return_,
      quantity: quantity,
      previousStock: currentStock,
      newStock: newStock,
      referenceId: referenceId,
      notes: notes.isNotEmpty ? notes : 'Stock restored from void transaction',
      userId: userId,
      referenceType: 'return',
    );
  }

  // Batch add stock for multiple products (used for multi-product stock in)
  static Future<Map<String, dynamic>> batchAddStock({
    required List<Map<String, dynamic>> items, // [{productId, quantity, notes, referenceId}]
    int? userId,
    String? referenceType,
  }) async {
    final results = <String, dynamic>{
      'success': <int>[],
      'failed': <int, String>{},
    };

    for (var item in items) {
      try {
        await addStock(
          productId: item['productId'] as int,
          quantity: item['quantity'] as int,
          notes: item['notes'] as String? ?? '',
          referenceId: item['referenceId'] as int?,
          userId: userId,
          referenceType: referenceType ?? item['referenceType'] as String? ?? 'supplier',
        );
        (results['success'] as List<int>).add(item['productId'] as int);
      } catch (e) {
        (results['failed'] as Map<int, String>)[item['productId'] as int] = e.toString();
      }
    }

    return results;
  }

  // Verify stock consistency - calculates expected stock from movements vs actual
  static Future<Map<String, dynamic>> verifyStockConsistency() async {
    try {
      final db = await DatabaseService.database;

      // Get all products with their current stock
      final products = await db.query('products', columns: ['id', 'name', 'stock']);

      final discrepancies = <Map<String, dynamic>>[];

      for (var product in products) {
        final productId = product['id'] as int;
        final actualStock = product['stock'] as int;

        // Calculate expected stock from movements
        final movements = await db.query(
          'stockMovements',
          where: 'productId = ?',
          whereArgs: [productId],
          orderBy: 'createdAt ASC',
        );

        int expectedStock = 0;
        for (var m in movements) {
          final type = m['type'] as String;
          final qty = m['quantity'] as int;

          switch (type) {
            case 'in':
            case 'return':
              expectedStock += qty;
              break;
            case 'out':
              expectedStock -= qty;
              break;
            case 'adjustment':
              // For adjustment, we use the newStock value from the movement
              final newStock = m['newStock'] as int;
              expectedStock = newStock;
              break;
          }
        }

        if (expectedStock != actualStock) {
          discrepancies.add({
            'productId': productId,
            'productName': product['name'],
            'actualStock': actualStock,
            'expectedStock': expectedStock,
            'difference': actualStock - expectedStock,
          });
        }
      }

      return {
        'isConsistent': discrepancies.isEmpty,
        'discrepancies': discrepancies,
        'totalProducts': products.length,
        'discrepancyCount': discrepancies.length,
      };
    } catch (e) {
      debugPrint('Error verifying stock consistency: $e');
      return {
        'isConsistent': false,
        'discrepancies': <Map<String, dynamic>>[],
        'totalProducts': 0,
        'discrepancyCount': 0,
        'error': e.toString(),
      };
    }
  }

  // Reconcile stock - fix discrepancies by updating actual stock to match movements
  static Future<Map<String, dynamic>> reconcileStock({
    bool dryRun = true,
  }) async {
    final verification = await verifyStockConsistency();

    if (verification['isConsistent'] == true) {
      return {
        'success': true,
        'message': 'Stock is already consistent',
        'fixesApplied': 0,
        'dryRun': dryRun,
      };
    }

    final discrepancies = verification['discrepancies'] as List<Map<String, dynamic>>;
    final fixesApplied = <Map<String, dynamic>>[];

    for (var disc in discrepancies) {
      final productId = disc['productId'] as int;
      final expectedStock = disc['expectedStock'] as int;

      if (!dryRun) {
        final db = await DatabaseService.database;
        await db.update(
          'products',
          {'stock': expectedStock, 'updatedAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      fixesApplied.add({
        'productId': productId,
        'productName': disc['productName'],
        'oldStock': disc['actualStock'],
        'newStock': expectedStock,
      });
    }

    return {
      'success': true,
      'message': dryRun
          ? 'Dry run complete - ${fixesApplied.length} products need correction'
          : 'Reconciliation complete - ${fixesApplied.length} products corrected',
      'fixesApplied': fixesApplied,
      'fixCount': fixesApplied.length,
      'dryRun': dryRun,
    };
  }

  static Future<int> _getCurrentStock(int productId) async {
    final results = await DatabaseService.query(
      'products',
      columns: ['stock'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (results.isEmpty) return 0;
return results.first['stock'] as int? ?? 0;
  }

  // Get stock movements by supplier ID (from supplier stock in history)
  static Future<List<StockMovement>> getMovementsBySupplierId(
    int supplierId, {
    int? limit,
  }) async {
    final results = await DatabaseService.rawQuery('''
      SELECT sm.*, p.name as productName, t.invoiceNumber as invoiceNumber
      FROM stockMovements sm
      LEFT JOIN products p ON sm.productId = p.id
      LEFT JOIN transactions t ON sm.referenceId = t.id
      WHERE (t.supplierId = ?) AND sm.type = 'in'
      ORDER BY sm.createdAt DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', [supplierId]);

    return results.map((map) {
      return StockMovement(
        id: map['id'] as int?,
        productId: map['productId'] as int,
        type: _parseType(map['type'] as String?),
        quantity: map['quantity'] as int,
        previousStock: map['previousStock'] as int,
        newStock: map['newStock'] as int,
        referenceId: map['referenceId'] as int?,
        notes: map['notes'] as String? ?? '',
        userId: map['userId'] as int?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        productName: map['productName'] as String?,
        referenceType: map['referenceType'] as String?,
        invoiceNumber: map['invoiceNumber'] as String?,
      );
    }).toList();
  }

  // Get stock movements by outlet ID (from outlet stock in history)
  static Future<List<StockMovement>> getMovementsByOutletId(
    int outletId, {
    int? limit,
  }) async {
    final results = await DatabaseService.rawQuery('''
      SELECT sm.*, p.name as productName, t.invoiceNumber as invoiceNumber
      FROM stockMovements sm
      LEFT JOIN products p ON sm.productId = p.id
      LEFT JOIN transactions t ON sm.referenceId = t.id
      WHERE (t.outletId = ?) AND sm.type = 'out'
      ORDER BY sm.createdAt DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', [outletId]);

    return results.map((map) {
      return StockMovement(
        id: map['id'] as int?,
        productId: map['productId'] as int,
        type: _parseType(map['type'] as String?),
        quantity: map['quantity'] as int,
        previousStock: map['previousStock'] as int,
        newStock: map['newStock'] as int,
        referenceId: map['referenceId'] as int?,
        notes: map['notes'] as String? ?? '',
        userId: map['userId'] as int?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        productName: map['productName'] as String?,
        referenceType: map['referenceType'] as String?,
        invoiceNumber: map['invoiceNumber'] as String?,
      );
    }).toList();
  }

  // Get products with low stock
  static Future<List<Map<String, dynamic>>> getLowStockProducts(
      {int? minStock}) async {
    String sql = '''
      SELECT p.*, c.name as categoryName
      FROM products p
      LEFT JOIN categories c ON p.categoryId = c.id
      WHERE p.isActive = 1 AND p.stock <= COALESCE(p.minStock, 10)
    ''';
    List<Object>? args;

    if (minStock != null) {
      sql += ' AND p.stock <= ?';
      args = [minStock];
    }

    sql += ' ORDER BY p.stock ASC, p.name ASC';

    return await DatabaseService.rawQuery(sql, args);
  }

  // ============================================================
  // Stock history grouped methods for inventory page
  // ============================================================

  /// Get stock OUT movements grouped by transaction (invoice)
  /// Used for "Mode Penjualan" (sales) in inventory page tab "Keluar"
  static Future<List<StockHistoryGroup>> getStockHistoryGroupedByTransaction({
    int? limit,
  }) async {
    // Get all stock OUT movements with referenceId (transaction id)
    final results = await DatabaseService.rawQuery('''
      SELECT sm.*, p.name as productName, t.invoiceNumber as transactionInvoice
      FROM stockMovements sm
      LEFT JOIN products p ON sm.productId = p.id
      LEFT JOIN transactions t ON sm.referenceId = t.id AND sm.referenceType = 'transaction'
      WHERE sm.type = 'out' AND sm.referenceType = 'transaction' AND sm.referenceId IS NOT NULL
      ORDER BY sm.createdAt DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''');

    // Group by referenceId (transactionId)
    final Map<int, StockHistoryGroup> groupMap = {};

    for (var map in results) {
      final refId = map['referenceId'] as int;
      final productName = map['productName'] as String? ?? 'Unknown';
      final quantity = map['quantity'] as int;
      final createdAt = DateTime.parse(map['createdAt'] as String);
      final invoiceNumber = map['transactionInvoice'] as String? ?? 'INV-$refId';
      final productId = map['productId'] as int;

      if (groupMap.containsKey(refId)) {
        // Add product to existing group
        final existing = groupMap[refId]!;
        final updatedProducts = List<StockHistoryProductItem>.from(existing.products);

        // Check if this product already exists in the group (aggregate)
        final existingProductIndex = updatedProducts.indexWhere((x) => x.productId == productId);
        if (existingProductIndex >= 0) {
          updatedProducts[existingProductIndex] = StockHistoryProductItem(
            productId: productId,
            productName: productName,
            totalQuantity: updatedProducts[existingProductIndex].totalQuantity + quantity,
            referenceType: 'transaction',
          );
        } else {
          updatedProducts.add(StockHistoryProductItem(
            productId: productId,
            productName: productName,
            totalQuantity: quantity,
            referenceType: 'transaction',
          ));
        }

        groupMap[refId] = StockHistoryGroup(
          referenceId: refId,
          referenceLabel: invoiceNumber,
          referenceType: 'transaction',
          createdAt: createdAt,
          products: updatedProducts,
          totalQuantity: existing.totalQuantity + quantity,
        );
      } else {
        // Create new group
        groupMap[refId] = StockHistoryGroup(
          referenceId: refId,
          referenceLabel: invoiceNumber,
          referenceType: 'transaction',
          createdAt: createdAt,
          products: [
            StockHistoryProductItem(
              productId: productId,
              productName: productName,
              totalQuantity: quantity,
              referenceType: 'transaction',
            ),
          ],
          totalQuantity: quantity,
        );
      }
    }

    return groupMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get stock IN movements grouped by supplier reference
  /// Used for "Mode Pembelian" (purchase) in inventory page tab "Masuk"
  static Future<List<StockHistoryGroup>> getStockHistoryGroupedBySupplier({
    int? limit,
  }) async {
    // Get all stock IN movements with referenceId (supplier id)
    final results = await DatabaseService.rawQuery('''
      SELECT sm.*, p.name as productName, s.name as supplierName
      FROM stockMovements sm
      LEFT JOIN products p ON sm.productId = p.id
      LEFT JOIN suppliers s ON sm.referenceId = s.id AND sm.referenceType = 'supplier'
      WHERE sm.type = 'in' AND sm.referenceType = 'supplier' AND sm.referenceId IS NOT NULL
      ORDER BY sm.createdAt DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''');

    // Group by referenceId (supplierId)
    final Map<int, StockHistoryGroup> groupMap = {};

    for (var map in results) {
      final refId = map['referenceId'] as int;
      final productName = map['productName'] as String? ?? 'Unknown';
      final quantity = map['quantity'] as int;
      final createdAt = DateTime.parse(map['createdAt'] as String);
      final supplierName = map['supplierName'] as String? ?? 'Supplier-$refId';
      final productId = map['productId'] as int;

      if (groupMap.containsKey(refId)) {
        // Add product to existing group
        final existing = groupMap[refId]!;
        final updatedProducts = List<StockHistoryProductItem>.from(existing.products);

        // Check if this product already exists in the group (aggregate)
        final existingProductIndex = updatedProducts.indexWhere((x) => x.productId == productId);
        if (existingProductIndex >= 0) {
          updatedProducts[existingProductIndex] = StockHistoryProductItem(
            productId: productId,
            productName: productName,
            totalQuantity: updatedProducts[existingProductIndex].totalQuantity + quantity,
            referenceType: 'supplier',
          );
        } else {
          updatedProducts.add(StockHistoryProductItem(
            productId: productId,
            productName: productName,
            totalQuantity: quantity,
            referenceType: 'supplier',
          ));
        }

        groupMap[refId] = StockHistoryGroup(
          referenceId: refId,
          referenceLabel: supplierName,
          referenceType: 'supplier',
          createdAt: createdAt,
          products: updatedProducts,
          totalQuantity: existing.totalQuantity + quantity,
        );
      } else {
        // Create new group
        groupMap[refId] = StockHistoryGroup(
          referenceId: refId,
          referenceLabel: supplierName,
          referenceType: 'supplier',
          createdAt: createdAt,
          products: [
            StockHistoryProductItem(
              productId: productId,
              productName: productName,
              totalQuantity: quantity,
              referenceType: 'supplier',
            ),
          ],
          totalQuantity: quantity,
        );
      }
    }

    return groupMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

class AuditService {
  // Record audit log
  static Future<int> logAction({
    required String tableName,
    required int recordId,
    required AuditAction action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? changedBy,
    String? reason,
  }) async {
    String actionStr;
    switch (action) {
      case AuditAction.create:
        actionStr = 'create';
        break;
      case AuditAction.delete:
        actionStr = 'delete';
        break;
      case AuditAction.void_:
        actionStr = 'void';
        break;
      default:
        actionStr = 'update';
    }

    return await DatabaseService.insert('auditLogs', {
      'tableName': tableName,
      'recordId': recordId,
      'action': actionStr,
      'oldValues': oldValues?.toString(),
      'newValues': newValues?.toString(),
      'changedBy': changedBy,
      'reason': reason,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // Get audit logs for a record
  static Future<List<AuditLog>> getRecordLogs(
      String tableName, int recordId) async {
    final results = await DatabaseService.query(
      'auditLogs',
      where: 'tableName = ? AND recordId = ?',
      whereArgs: [tableName, recordId],
      orderBy: 'createdAt DESC',
    );
    return results.map((map) => AuditLog.fromMap(map)).toList();
  }

  // Get all audit logs with filters
  static Future<List<AuditLog>> getLogs({
    String? tableName,
    AuditAction? action,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    String where = '1=1';
    List<Object> whereArgs = [];

    if (tableName != null) {
      where += ' AND tableName = ?';
      whereArgs.add(tableName);
    }
    if (action != null) {
      where += ' AND action = ?';
      switch (action) {
        case AuditAction.create:
          whereArgs.add('create');
          break;
        case AuditAction.delete:
          whereArgs.add('delete');
          break;
        case AuditAction.void_:
          whereArgs.add('void');
          break;
        default:
          whereArgs.add('update');
      }
    }
    if (startDate != null) {
      where += ' AND createdAt >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where += ' AND createdAt <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final results = await DatabaseService.query(
      'auditLogs',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((map) => AuditLog.fromMap(map)).toList();
  }
}
