import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../models/return_model.dart';
import 'database_service.dart';

class TransactionService {
  static Future<List<Transaction>> getInvoices({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String sortBy = 'date_desc',
    String? searchQuery,
    int? limit,
    int? offset,
    String? paymentMethod,
  }) async {
    try {
      final db = await DatabaseService.database;

      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (startDate != null && endDate != null) {
        whereClause += ' AND transactionDate BETWEEN ? AND ?';
        whereArgs.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      }

      if (status != null && status != 'all') {
        whereClause += ' AND status = ?';
        whereArgs.add(status);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClause += ' AND (invoiceNumber LIKE ? OR customerName LIKE ?)';
        whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
      }

      // Filter by payment method (e.g., TEMPO for cicilan/tempo payments)
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        whereClause += ' AND paymentMethod = ?';
        whereArgs.add(paymentMethod);
      }

      String orderClause;
      switch (sortBy) {
        case 'date_asc':
          orderClause = 'transactionDate ASC';
          break;
        case 'total_desc':
          orderClause = 'finalAmount DESC';
          break;
        case 'total_asc':
          orderClause = 'finalAmount ASC';
          break;
        default:
          orderClause = 'transactionDate DESC';
      }

      final List<Map<String, dynamic>> transactionMaps = await db.query(
        'transactions',
        where: whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: orderClause,
        limit: limit,
        offset: offset,
      );

      List<Transaction> transactions = [];
      for (var transactionMap in transactionMaps) {
        String? outletName;
        String? outletAddress;
        String? outletPhone;
        if (transactionMap['outletId'] != null) {
          final outletResults = await db.query(
            'outlets',
            columns: ['name', 'address', 'phone'],
            where: 'id = ?',
            whereArgs: [transactionMap['outletId']],
          );
          if (outletResults.isNotEmpty) {
            outletName = outletResults.first['name'] as String?;
            outletAddress = outletResults.first['address'] as String?;
            outletPhone = outletResults.first['phone'] as String?;
          }
        }

        String? supplierName;
        String? supplierAddress;
        String? supplierPhone;
        if (transactionMap['supplierId'] != null) {
          final supplierResults = await db.query(
            'suppliers',
            columns: ['name', 'address', 'phone'],
            where: 'id = ?',
            whereArgs: [transactionMap['supplierId']],
          );
          if (supplierResults.isNotEmpty) {
            supplierName = supplierResults.first['name'] as String?;
            supplierAddress = supplierResults.first['address'] as String?;
            supplierPhone = supplierResults.first['phone'] as String?;
          }
        }

        String? userName;
        if (transactionMap['userId'] != null) {
          final userResults = await db.query(
            'users',
            columns: ['name'],
            where: 'id = ?',
            whereArgs: [transactionMap['userId']],
          );
          if (userResults.isNotEmpty) {
            userName = userResults.first['name'] as String?;
          }
        }

        String? salesName;
        String? salesPhone;
        if (transactionMap['salesId'] != null) {
          final salesResults = await db.query(
            'sales',
            columns: ['name', 'phone'],
            where: 'id = ?',
            whereArgs: [transactionMap['salesId']],
          );
          if (salesResults.isNotEmpty) {
            salesName = salesResults.first['name'] as String?;
            salesPhone = salesResults.first['phone'] as String?;
          }
        }

        final List<Map<String, dynamic>> itemMaps = await db.query(
          'transactionItems',
          where: 'transactionId = ?',
          whereArgs: [transactionMap['id']],
        );

        final items = itemMaps
            .map((itemMap) => TransactionItem.fromMap(itemMap))
            .toList();

        final discountResults = await db.query(
          'transactionDiscounts',
          where: 'transactionId = ?',
          whereArgs: [transactionMap['id']],
        );
        final appliedDiscounts =
            discountResults.map((d) => AppliedDiscount.fromMap(d)).toList();

        transactions.add(Transaction(
          id: transactionMap['id'] as int?,
          invoiceNumber: transactionMap['invoiceNumber'] as String,
          transactionDate: DateTime.parse(transactionMap['transactionDate'] as String),
          totalAmount: (transactionMap['totalAmount'] as num).toDouble(),
          discount: (transactionMap['discount'] as num?)?.toDouble() ?? 0,
          finalAmount: (transactionMap['finalAmount'] as num).toDouble(),
          paymentMethod: transactionMap['paymentMethod'] as String,
          outletId: transactionMap['outletId'] as int?,
          outletName: outletName ?? transactionMap['outletName'] as String?,
          outletAddress: outletAddress ?? transactionMap['outletAddress'] as String?,
          outletPhone: outletPhone ?? transactionMap['outletPhone'] as String?,
          userId: transactionMap['userId'] as int?,
          userName: userName,
          status: TransactionStatus.paid,
          customerName: transactionMap['customerName'] as String?,
          notes: transactionMap['notes'] as String?,
          supplierName: supplierName,
          supplierAddress: supplierAddress,
          supplierPhone: supplierPhone,
          salesName: salesName,
          salesPhone: salesPhone,
          items: items,
          appliedDiscounts: appliedDiscounts,
        ));
      }

      return transactions;
    } catch (e) {
      debugPrint('Error getting invoices: $e');
      return [];
    }
  }

  static Future<List<Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return getInvoices(startDate: startDate, endDate: endDate);
  }

  static Future<Transaction?> getInvoiceById(int id) async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> transactionMaps = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (transactionMaps.isNotEmpty) {
        final transactionMap = transactionMaps.first;

        String? outletName;
        String? outletAddress;
        String? outletPhone;
        if (transactionMap['outletId'] != null) {
          final outletResults = await db.query(
            'outlets',
            columns: ['name', 'address', 'phone'],
            where: 'id = ?',
            whereArgs: [transactionMap['outletId']],
          );
          if (outletResults.isNotEmpty) {
            outletName = outletResults.first['name'] as String?;
            outletAddress = outletResults.first['address'] as String?;
            outletPhone = outletResults.first['phone'] as String?;
          }
        }

        String? supplierName;
        String? supplierAddress;
        String? supplierPhone;
        if (transactionMap['supplierId'] != null) {
          final supplierResults = await db.query(
            'suppliers',
            columns: ['name', 'address', 'phone'],
            where: 'id = ?',
            whereArgs: [transactionMap['supplierId']],
          );
          if (supplierResults.isNotEmpty) {
            supplierName = supplierResults.first['name'] as String?;
            supplierAddress = supplierResults.first['address'] as String?;
            supplierPhone = supplierResults.first['phone'] as String?;
          }
        }

        String? userName;
        if (transactionMap['userId'] != null) {
          final userResults = await db.query(
            'users',
            columns: ['name'],
            where: 'id = ?',
            whereArgs: [transactionMap['userId']],
          );
          if (userResults.isNotEmpty) {
            userName = userResults.first['name'] as String?;
          }
        }

        String? salesName;
        String? salesPhone;
        if (transactionMap['salesId'] != null) {
          final salesResults = await db.query(
            'sales',
            columns: ['name', 'phone'],
            where: 'id = ?',
            whereArgs: [transactionMap['salesId']],
          );
          if (salesResults.isNotEmpty) {
            salesName = salesResults.first['name'] as String?;
            salesPhone = salesResults.first['phone'] as String?;
          }
        }

        final List<Map<String, dynamic>> itemMaps = await db.query(
          'transactionItems',
          where: 'transactionId = ?',
          whereArgs: [id],
        );

        final items = itemMaps
            .map((itemMap) => TransactionItem.fromMap(itemMap))
            .toList();

        final discountResults = await db.query(
          'transactionDiscounts',
          where: 'transactionId = ?',
          whereArgs: [id],
        );
        final appliedDiscounts =
            discountResults.map((d) => AppliedDiscount.fromMap(d)).toList();

        return Transaction(
          id: transactionMap['id'] as int?,
          invoiceNumber: transactionMap['invoiceNumber'] as String,
          transactionDate: DateTime.parse(transactionMap['transactionDate'] as String),
          totalAmount: (transactionMap['totalAmount'] as num).toDouble(),
          discount: (transactionMap['discount'] as num?)?.toDouble() ?? 0,
          finalAmount: (transactionMap['finalAmount'] as num).toDouble(),
          paymentMethod: transactionMap['paymentMethod'] as String,
          outletId: transactionMap['outletId'] as int?,
          outletName: outletName ?? transactionMap['outletName'] as String?,
          outletAddress: outletAddress ?? transactionMap['outletAddress'] as String?,
          outletPhone: outletPhone ?? transactionMap['outletPhone'] as String?,
          userId: transactionMap['userId'] as int?,
          userName: userName,
          status: TransactionStatus.paid,
          customerName: transactionMap['customerName'] as String?,
          notes: transactionMap['notes'] as String?,
          supplierName: supplierName,
          supplierAddress: supplierAddress,
          supplierPhone: supplierPhone,
          salesName: salesName,
          salesPhone: salesPhone,
          items: items,
          appliedDiscounts: appliedDiscounts,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invoice: $e');
      return null;
    }
  }

  static Future<void> voidTransaction(int id, String reason) async {
    try {
      final db = await DatabaseService.database;
      await db.update(
        'transactions',
        {
          'status': 'CANCELLED',
          'voidReason': reason,
          'voidDate': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error voiding transaction: $e');
    }
  }

static Future<void> refundTransaction(int id, String reason) async {
    try {
      final db = await DatabaseService.database;
      await db.update(
        'transactions',
        {
          'status': 'REFUNDED',
          'voidReason': reason,
          'voidDate': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error refunding transaction: $e');
    }
  }

  // Process return for specific item in a transaction
  static Future<bool> returnItem({
    required int transactionId,
    required int itemId,
    required int quantity,
    required String reason,
    required int productId,
    required int currentStock,
  }) async {
    try {
      final db = await DatabaseService.database;
      
      // Get the current item data
      final itemResults = await db.query(
        'transactionItems',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      
      if (itemResults.isEmpty) {
        debugPrint('Item not found');
        return false;
      }
      
      final item = itemResults.first;
      final originalQty = item['quantity'] as int;
      final alreadyReturned = item['returnedQuantity'] as int? ?? 0;
      final newReturnedQty = alreadyReturned + quantity;
      
      // Check if return quantity is valid
      if (newReturnedQty > originalQty) {
        debugPrint('Return quantity exceeds original quantity');
        return false;
      }
      
      // Update the item with return tracking
      await db.update(
        'transactionItems',
        {
          'isReturned': newReturnedQty > 0 ? 1 : 0,
          'returnedQuantity': newReturnedQty,
          'returnReason': reason,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );
      
      // Restore stock (add back to inventory)
      final newStock = currentStock + quantity;
      await db.update(
        'products',
        {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      // Record stock movement for the return
      await db.insert('stockMovements', {
        'productId': productId,
        'type': 'return',
        'quantity': quantity,
        'previousStock': currentStock,
        'newStock': newStock,
        'referenceId': transactionId,
        'referenceType': 'return',
        'notes': 'Retur barang: $reason',
        'createdAt': DateTime.now().toIso8601String(),
      });
      
// Return now tracked in transactionItems - no separate transaction needed
      // Invoice will show return info via returnedQuantity field
      
      debugPrint('Item return processed. Stock restored: +$quantity');
      return true;
    } catch (e) {
      debugPrint('Error processing item return: $e');
      return false;
    }
  }

// Create a return record in the separate returns table
  static Future<int> createReturn({
    required int productId,
    required String productName,
    required double price,
    required double cost,
    required int quantity,
    required ReturnType returnType,
    int? originalTransactionId,
    String? originalInvoiceNumber,
    String notes = '',
    int? createdBy,
  }) async {
    try {
      final db = await DatabaseService.database;

      // Insert into returns table (separate from transactions)
      final returnId = await db.insert('returns', {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'price': price,
        'cost': cost,
        'returnType': returnType.dbValue,
        'referenceId': originalTransactionId,
        'referenceNumber': originalInvoiceNumber,
        'notes': notes.isNotEmpty ? notes : 'Retur: $productName x $quantity',
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': createdBy,
      });

      debugPrint('Return saved to returns table. ID: $returnId');
      return returnId;
    } catch (e) {
      debugPrint('Error creating return: $e');
      return 0;
    }
  }

// Get all returns from the returns table - returns List<Return> objects
  static Future<List<Return>> getReturns({
    ReturnType? returnType,
    DateTime? startDate,
    DateTime? endDate,
    int? productId,
    int? referenceId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await DatabaseService.database;

      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (returnType != null) {
        String typeStr;
        switch (returnType) {
          case ReturnType.outlet:
            typeStr = 'OUTLET';
            break;
          case ReturnType.supplier:
            typeStr = 'SUPPLIER';
            break;
          case ReturnType.sales:
            typeStr = 'SALES';
            break;
          case ReturnType.adjustment:
            typeStr = 'ADJUSTMENT';
            break;
        }
        whereClause += ' AND returnType = ?';
        whereArgs.add(typeStr);
      }

      if (startDate != null && endDate != null) {
        whereClause += ' AND createdAt BETWEEN ? AND ?';
        whereArgs.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      }

      if (productId != null) {
        whereClause += ' AND productId = ?';
        whereArgs.add(productId);
      }

      if (referenceId != null) {
        whereClause += ' AND referenceId = ?';
        whereArgs.add(referenceId);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClause += ' AND (productName LIKE ? OR referenceNumber LIKE ?)';
        whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
      }

      final returnMaps = await db.query(
        'returns',
        where: whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );

      return returnMaps.map((map) => Return.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting returns: $e');
      return [];
    }
  }

  // Get returns summary by type
  static Future<Map<String, dynamic>> getReturnsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await DatabaseService.database;

      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (startDate != null && endDate != null) {
        whereClause += ' AND createdAt BETWEEN ? AND ?';
        whereArgs.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      }

      // Total returns count
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM returns WHERE $whereClause',
        whereArgs.isEmpty ? null : whereArgs,
      );
      final totalCount = countResult.first['count'] as int? ?? 0;

      // Total return amount (price * quantity)
      final amountResult = await db.rawQuery(
        'SELECT SUM(price * quantity) as total FROM returns WHERE $whereClause',
        whereArgs.isEmpty ? null : whereArgs,
      );
      final totalAmount = (amountResult.first['total'] as num?)?.toDouble() ?? 0;

      // Count by type
      final typeResult = await db.rawQuery(
        'SELECT returnType, COUNT(*) as count FROM returns WHERE $whereClause GROUP BY returnType',
        whereArgs.isEmpty ? null : whereArgs,
      );

      Map<String, int> countByType = {};
      for (var row in typeResult) {
        countByType[row['returnType'] as String] = row['count'] as int;
      }

      return {
        'totalCount': totalCount,
        'totalAmount': totalAmount,
        'countByType': countByType,
      };
    } catch (e) {
      debugPrint('Error getting returns summary: $e');
      return {
        'totalCount': 0,
        'totalAmount': 0.0,
        'countByType': <String, int>{},
      };
    }
  }

// Legacy method - Create a return transaction (kept for backward compatibility)
  static Future<int> createReturnTransaction({
    required int productId,
    required String productName,
    required double price,
    required double cost,
    required int quantity,
    int? originalTransactionId,
    String? originalInvoiceNumber,
    String notes = '',
  }) async {
    try {
      final db = await DatabaseService.database;
      final subtotal = price * quantity;

      // Build notes with original invoice reference if provided
      String returnNotes = notes.isNotEmpty ? notes : 'Retur: $productName x $quantity';
      if (originalInvoiceNumber != null) {
        returnNotes = 'Retur dari invoice $originalInvoiceNumber - $returnNotes';
      }

      // Only use columns that exist in the database schema
      final transactionId = await db.insert('transactions', {
        'invoiceNumber': 'RET-${DateTime.now().millisecondsSinceEpoch}',
        'transactionDate': DateTime.now().toIso8601String(),
        'totalAmount': subtotal,
        'discount': 0,
        'finalAmount': -subtotal,
        'paymentMethod': 'CASH',
        'status': 'REFUNDED',
        'customerName': 'Return',
        'notes': returnNotes,
        'originalTransactionId': originalTransactionId,
        'originalInvoiceNumber': originalInvoiceNumber,
        'voidReason': notes.isNotEmpty ? notes : 'Retur Penjualan',
        'voidDate': DateTime.now().toIso8601String(),
      });

      // Also insert the item into transactionItems so return invoice shows the items
      if (transactionId > 0) {
        await db.insert('transactionItems', {
          'transactionId': transactionId,
          'productId': productId,
          'productName': productName,
          'price': price,
          'quantity': -quantity,
          'subtotal': -subtotal,
          'cost': cost,
          'isReturned': 1,
          'returnedQuantity': quantity,
        });
      }

      return transactionId;
    } catch (e) {
      debugPrint('Error creating return transaction: $e');
      return 0;
    }
  }

// Get all returns associated with a transaction by searching notes field
  static Future<List<Transaction>> getReturnsForTransaction(int transactionId) async {
    try {
      final db = await DatabaseService.database;
      
      // First get the original invoice to find its invoice number
      final originalInvoice = await db.query(
        'transactions',
        columns: ['invoiceNumber'],
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      
      if (originalInvoice.isEmpty) {
        return [];
      }
      
      final originalInvoiceNumber = originalInvoice.first['invoiceNumber'] as String;
      
      // Then find returns by searching notes that contain the original invoice number
      final returnMaps = await db.query(
        'transactions',
        where: 'notes LIKE ? AND status = ?',
        whereArgs: ['%$originalInvoiceNumber%', 'REFUNDED'],
        orderBy: 'transactionDate DESC',
      );

      List<Transaction> returns = [];
      for (var returnMap in returnMaps) {
        final itemMaps = await db.query(
          'transactionItems',
          where: 'transactionId = ?',
          whereArgs: [returnMap['id']],
        );
        final items = itemMaps
            .map((itemMap) => TransactionItem.fromMap(itemMap))
            .toList();
        returns.add(Transaction.fromMap(returnMap, items));
      }
      return returns;
    } catch (e) {
      debugPrint('Error getting returns for transaction: $e');
      return [];
    }
  }

static Future<Map<String, dynamic>> getSalesSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions =
          await getInvoices(startDate: startDate, endDate: endDate);

      double totalSales = 0;
      double totalDiscount = 0;

      for (var t in transactions) {
        if (t.status == TransactionStatus.paid ||
            t.status == TransactionStatus.refunded) {
          totalSales += t.finalAmount;
        }
        if (t.status != TransactionStatus.cancelled) {
          totalDiscount += t.discount;
        }
      }

      Map<String, double> salesByMethod = {};
      int transactionCount = 0;

      for (var transaction in transactions) {
        if (transaction.status != TransactionStatus.cancelled) {
          transactionCount++;
          salesByMethod[transaction.paymentMethod] =
              (salesByMethod[transaction.paymentMethod] ?? 0) +
                  transaction.finalAmount;
        }
      }

      return {
        'totalTransactions': transactionCount,
        'totalSales': totalSales,
        'totalDiscount': totalDiscount,
        'averageTransaction':
            transactionCount > 0 ? totalSales / transactionCount : 0,
        'salesByMethod': salesByMethod,
      };
    } catch (e) {
      debugPrint('Error getting sales summary: $e');
      return {};
    }
  }

// Get return statistics for dashboard (with profit calculation)
  static Future<Map<String, dynamic>> getReturnSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await DatabaseService.database;
      
      // Build date filter
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];
      
      if (startDate != null && endDate != null) {
        whereClause += ' AND createdAt BETWEEN ? AND ?';
        whereArgs.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      }

      // Get all returns from the new returns table
      final returnMaps = await db.query(
        'returns',
        where: whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'createdAt DESC',
      );

      double totalReturnAmount = 0;  // Sales amount returned
      double totalReturnCost = 0;     // Cost of goods returned
      int returnCount = returnMaps.length;
      int itemsReturnedCount = 0;

      for (var r in returnMaps) {
        final price = (r['price'] as num?)?.toDouble() ?? 0;
        final cost = (r['cost'] as num?)?.toDouble() ?? 0;
        final quantity = (r['quantity'] as num?)?.toInt() ?? 0;
        
        totalReturnAmount += price * quantity;
        totalReturnCost += cost * quantity;
        itemsReturnedCount += quantity;
      }

      // Calculate profit impact (negative because returns reduce profit)
      double totalReturnProfit = totalReturnAmount - totalReturnCost;

      return {
        'totalReturns': returnCount,
        'totalReturnAmount': totalReturnAmount.abs(),
        'totalReturnCost': totalReturnCost.abs(),
        'totalReturnProfit': totalReturnProfit.abs(),  // Profit lost to returns
        'itemsReturnedCount': itemsReturnedCount,
      };
    } catch (e) {
      debugPrint('Error getting return summary: $e');
      return {
        'totalReturns': 0,
        'totalReturnAmount': 0.0,
        'totalReturnCost': 0.0,
        'totalReturnProfit': 0.0,
        'itemsReturnedCount': 0,
      };
    }
  }

  // Get returns for a specific transaction from the returns table
  static Future<List<Return>> getReturnsForTransactionRef(int transactionId) async {
    try {
      final db = await DatabaseService.database;

      final returnMaps = await db.query(
        'returns',
        where: 'referenceId = ?',
        whereArgs: [transactionId],
        orderBy: 'createdAt DESC',
      );

      return returnMaps.map((map) => Return.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting returns for transaction: $e');
      return [];
    }
  }

// Delete a return by ID
  static Future<bool> deleteReturn(int returnId) async {
    try {
      final db = await DatabaseService.database;

      await db.delete(
        'returns',
        where: 'id = ?',
        whereArgs: [returnId],
      );

      debugPrint('Return deleted: $returnId');
      return true;
    } catch (e) {
      debugPrint('Error deleting return: $e');
      return false;
    }
  }

  // Calculate net profit: sales profit - returns cost
  // This combines sales from transactions table with returns from returns table
  static Future<Map<String, dynamic>> getNetProfitSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get sales (from transactions table)
      final salesData = await getSalesSummary(startDate: startDate, endDate: endDate);
      double totalSales = (salesData['totalSales'] as num?)?.toDouble() ?? 0;

      // Get returns (from returns table)
      final returnData = await getReturnSummary(startDate: startDate, endDate: endDate);
      double totalReturnAmount = (returnData['totalReturnAmount'] as num?)?.toDouble() ?? 0;
      double totalReturnCost = (returnData['totalReturnCost'] as num?)?.toDouble() ?? 0;

      // Calculate profit
      // Sales profit = Sales - Cost (we use totalSales which already accounts for profit in transactions)
      // Returns reduce profit, and we also account for the cost of goods returned
      // Net profit = Sales - Returns - Cost of Returns
      double grossProfit = totalSales - totalReturnAmount;  // Net sales after returns
      double returnCostImpact = totalReturnCost;  // Additional cost from returns

      return {
        'totalSales': totalSales,
        'totalReturns': totalReturnAmount,
        'returnCost': totalReturnCost,
        'grossProfit': grossProfit,
        'netProfit': grossProfit - returnCostImpact,  // Final profit after accounting for return costs
      };
    } catch (e) {
      debugPrint('Error getting net profit summary: $e');
      return {
        'totalSales': 0.0,
        'totalReturns': 0.0,
        'returnCost': 0.0,
        'grossProfit': 0.0,
        'netProfit': 0.0,
      };
    }
  }

  // Unified profit calculation - uses CURRENT purchasePrice for accuracy
  // This is more accurate than stored cost which may be outdated
  static Future<Map<String, dynamic>> getUnifiedProfitSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await DatabaseService.database;

      // Build date filter
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (startDate != null && endDate != null) {
        whereClause += ' AND t.transactionDate BETWEEN ? AND ?';
        whereArgs.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      }

      // Get all PAID transactions with their items
      final transactionMaps = await db.rawQuery('''
        SELECT t.*, ti.productId, ti.quantity, ti.price, ti.cost as itemCost,
               p.purchasePrice as currentPurchasePrice
        FROM transactions t
        LEFT JOIN transactionItems ti ON t.id = ti.transactionId
        LEFT JOIN products p ON ti.productId = p.id
        WHERE $whereClause AND t.status = 'PAID'
        ORDER BY t.transactionDate DESC
      ''', whereArgs.isEmpty ? null : whereArgs);

      // Calculate totals
      double totalRevenue = 0;
      double totalCost = 0;
      double totalDiscount = 0;
      int transactionCount = 0;

      // Group by transaction to avoid double counting
      final Map<int, Map<String, dynamic>> transactionGroups = {};
      for (var row in transactionMaps) {
        final txnId = row['id'] as int;
        if (!transactionGroups.containsKey(txnId)) {
          transactionGroups[txnId] = {
            'transaction': row,
            'items': <Map<String, dynamic>>[],
          };
        }
        if (row['productId'] != null) {
          (transactionGroups[txnId]!['items'] as List).add(row);
        }
      }

      for (var group in transactionGroups.values) {
        final txn = group['transaction'] as Map<String, dynamic>;
        final items = group['items'] as List<Map<String, dynamic>>;

        final finalAmount = (txn['finalAmount'] as num?)?.toDouble() ?? 0;
        final discount = (txn['discount'] as num?)?.toDouble() ?? 0;

        // Revenue = finalAmount (already includes discounts)
        totalRevenue += finalAmount;
        totalDiscount += discount;
        transactionCount++;

        // Calculate cost using CURRENT purchasePrice (more accurate)
        for (var item in items) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final currentCost = (item['currentPurchasePrice'] as num?)?.toDouble() ?? 0;
          totalCost += currentCost * quantity;
        }
      }

      // Get returns from returns table
      String returnWhereClause = '1=1';
      List<dynamic> returnWhereArgs = [];

      if (startDate != null && endDate != null) {
        returnWhereClause += ' AND createdAt BETWEEN ? AND ?';
        returnWhereArgs.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      }

      final returnMaps = await db.query(
        'returns',
        where: returnWhereClause,
        whereArgs: returnWhereArgs.isEmpty ? null : returnWhereArgs,
      );

      double totalReturnAmount = 0;
      double totalReturnCost = 0;
      int returnCount = returnMaps.length;
      int itemsReturnedCount = 0;

      for (var r in returnMaps) {
        final price = (r['price'] as num?)?.toDouble() ?? 0;
        final cost = (r['cost'] as num?)?.toDouble() ?? 0;
        final quantity = (r['quantity'] as num?)?.toInt() ?? 0;

        totalReturnAmount += price * quantity;
        totalReturnCost += cost * quantity;
        itemsReturnedCount += quantity;
      }

      // Calculate profit metrics
      double grossProfit = totalRevenue - totalCost;
      double netProfitAfterReturns = grossProfit - totalReturnAmount;
      double returnCostImpact = totalReturnCost;
      double netProfit = netProfitAfterReturns - returnCostImpact;

      return {
        // Sales totals
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'totalDiscount': totalDiscount,
        'transactionCount': transactionCount,
        'averageTransaction': transactionCount > 0 ? totalRevenue / transactionCount : 0,

        // Return totals
        'returnCount': returnCount,
        'itemsReturnedCount': itemsReturnedCount,
        'totalReturnAmount': totalReturnAmount.abs(),
        'totalReturnCost': totalReturnCost.abs(),

        // Profit calculations
        'grossProfit': grossProfit,
        'grossProfitMargin': totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0,
        'netProfitAfterReturns': netProfitAfterReturns,
        'returnCostImpact': returnCostImpact.abs(),
        'netProfit': netProfit,
        'netProfitMargin': totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0,

        // Summary
        'netSales': totalRevenue - totalReturnAmount, // Net sales after returns
      };
    } catch (e) {
      debugPrint('Error getting unified profit summary: $e');
      return {
        'totalRevenue': 0.0,
        'totalCost': 0.0,
        'totalDiscount': 0.0,
        'transactionCount': 0,
        'averageTransaction': 0.0,
        'returnCount': 0,
        'itemsReturnedCount': 0,
        'totalReturnAmount': 0.0,
        'totalReturnCost': 0.0,
        'grossProfit': 0.0,
        'grossProfitMargin': 0.0,
        'netProfitAfterReturns': 0.0,
        'returnCostImpact': 0.0,
        'netProfit': 0.0,
        'netProfitMargin': 0.0,
        'netSales': 0.0,
      };
    }
  }
}
