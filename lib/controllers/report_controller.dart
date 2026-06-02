import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/return_model.dart';
import '../services/database_service.dart';
import '../services/transaction_service.dart';

class ReportController extends ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Filter state
  String? _filterSalesId;
  String? _filterCategoryId;
  String? _filterOutletId;

  // Returns from returns table
  List<Return> _returns = [];
  double _returnsAmount = 0;
  bool _isLoadingReturns = false;

  // Pagination
  static const int _defaultLimit = 1000;
  int _limit = _defaultLimit;
  int _offset = 0;
  bool _hasMore = true;

  // Cached computations (memoization)
  double _cachedTotalSales = 0;
  double _cachedTotalProfit = 0;
  double _cachedPendingProfit = 0;
  int _cachedPendingCount = 0;
  double _cachedGrossProfit = 0;
  double _cachedReturnsDeducted = 0;
  double _cachedTotalCost = 0;
  double _cachedProfitMargin = 0;
  double _cachedTotalReturns = 0;
  int _cachedReturnCount = 0;
  bool _cacheValid = false;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String? get filterSalesId => _filterSalesId;
  String? get filterCategoryId => _filterCategoryId;
  String? get filterOutletId => _filterOutletId;
  bool get hasMore => _hasMore;

  double get totalSales {
    _computeMetrics();
    return _cachedTotalSales;
  }
  double get averageTransaction =>
      _transactions.isEmpty ? 0 : totalSales / _transactions.length;
  Map<String, double> get salesByPaymentMethod {
    final Map<String, double> salesMap = {};
    for (var transaction in _transactions) {
      salesMap[transaction.paymentMethod] =
          (salesMap[transaction.paymentMethod] ?? 0) + transaction.finalAmount;
    }
    return salesMap;
  }

  // Profit calculation - only includes PAID transactions
  double get totalProfit {
    _computeMetrics();
    return _cachedTotalProfit;
  }

  // Pending profit - from PENDING transactions (not yet paid)
  double get pendingProfit {
    _computeMetrics();
    return _cachedPendingProfit;
  }

  // Count of pending transactions
  int get pendingTransactionCount {
    _computeMetrics();
    return _cachedPendingCount;
  }

  // Original profit before returns (for comparison)
  double get grossProfit {
    _computeMetrics();
    return _cachedGrossProfit;
  }

  // Total returns amount (deducted from sales)
  double get returnsDeducted {
    _computeMetrics();
    return _cachedReturnsDeducted;
  }

  double get totalCost {
    _computeMetrics();
    return _cachedTotalCost;
  }

  double get profitMargin {
    _computeMetrics();
    return _cachedProfitMargin;
  }

  // Return transactions calculation (negative amounts - REFUNDED status)
  double get totalReturns {
    _computeMetrics();
    return _cachedTotalReturns;
  }

  int get returnCount {
    _computeMetrics();
    return _cachedReturnCount;
  }

  Future<void> loadTransactions({bool refresh = false, bool loadMore = false}) async {
    if (loadMore && !_hasMore) return;

    _isLoading = true;
    _cacheValid = false;
    notifyListeners();

    try {
      if (refresh) {
        _offset = 0;
        _hasMore = true;
      }

      // Step 1: Query transactions with LIMIT/OFFSET
      final List<Map<String, dynamic>> transactionMaps = await DatabaseService.query(
        'transactions',
        where: 'transactionDate BETWEEN ? AND ? AND (transactionType IS NULL OR transactionType != ?)',
        whereArgs: [
          _startDate.toIso8601String(),
          _endDate.toIso8601String(),
          'purchase',
        ],
        orderBy: 'transactionDate DESC',
        limit: _limit,
        offset: _offset,
      );

      // Check if there's more data
      _hasMore = transactionMaps.length >= _limit;
      _offset += transactionMaps.length;

      if (transactionMaps.isEmpty) {
        _transactions = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Step 2: Collect all IDs for batch queries
      final transactionIds = transactionMaps.map((t) => t['id'] as int).toList();

      // Step 3: Batch query transactionItems for all transactions (N+1 fix)
      final allItemMaps = await DatabaseService.rawQuery(
        'SELECT * FROM transactionItems WHERE transactionId IN (${transactionIds.map((_) => '?').join(',')})',
        transactionIds,
      );

      // Group items by transactionId
      final Map<int, List<Map<String, dynamic>>> itemsByTransaction = {};
      for (var item in allItemMaps) {
        final tid = item['transactionId'] as int;
        itemsByTransaction.putIfAbsent(tid, () => []).add(item);
      }

      // Step 4: Collect all productIds for batch query
      final productIds = allItemMaps
          .map((item) => item['productId'])
          .whereType<int>()
          .toSet()
          .toList();

      // Step 5: Batch query products (for category filter and cost lookup)
      final Map<int, Map<String, dynamic>> productCache = {};
      if (productIds.isNotEmpty) {
        final productMaps = await DatabaseService.rawQuery(
          'SELECT * FROM products WHERE id IN (${productIds.map((_) => '?').join(',')})',
          productIds,
        );
        for (var product in productMaps) {
          productCache[product['id'] as int] = product;
        }
      }

      // Step 6: Collect all outletIds for batch query
      final outletIds = transactionMaps
          .map((t) => t['outletId'] as int?)
          .whereType<int>()
          .toSet()
          .toList();

      // Step 7: Batch query outlets
      final Map<int, String> outletNames = {};
      if (outletIds.isNotEmpty) {
        final outletMaps = await DatabaseService.rawQuery(
          'SELECT * FROM outlets WHERE id IN (${outletIds.map((_) => '?').join(',')})',
          outletIds,
        );
        for (var outlet in outletMaps) {
          outletNames[outlet['id'] as int] = outlet['name'] as String? ?? '';
        }
      }

      // Step 8: Build transaction objects
      _transactions = [];
      for (var transactionMap in transactionMaps) {
        final int transactionId = transactionMap['id'];
        final int? salesId = transactionMap['salesId'] as int?;

        // Filter by salesId if set
        if (_filterSalesId != null && salesId?.toString() != _filterSalesId) {
          continue;
        }

        final itemMaps = itemsByTransaction[transactionId] ?? [];

        final items = <TransactionItem>[];
        bool hasMatchingCategory = false;
        for (var itemMap in itemMaps) {
          final productId = itemMap['productId'] as int?;
          if (productId == null) continue;

          // Filter by categoryId if set - check via cached product
          if (_filterCategoryId != null) {
            final productData = productCache[productId];
            if (productData != null) {
              final productCategoryId = productData['categoryId']?.toString();
              if (productCategoryId != _filterCategoryId) {
                continue;
              }
              hasMatchingCategory = true;
            }
          }

          // Get cost from transactionItems or cached product
          double itemCost = (itemMap['cost'] as num?)?.toDouble() ?? 0;
          if (itemCost == 0 && productCache.containsKey(productId)) {
            itemCost = (productCache[productId]!['purchasePrice'] as num?)?.toDouble() ?? 0;
          }

          items.add(TransactionItem(
            productId: productId,
            productName: itemMap['productName'],
            price: (itemMap['price'] as num).toDouble(),
            quantity: itemMap['quantity'],
            subtotal: (itemMap['subtotal'] as num).toDouble(),
            cost: itemCost,
            isReturned: (itemMap['isReturned'] as int?) == 1,
            returnedQuantity: itemMap['returnedQuantity'] as int? ?? 0,
            returnReason: itemMap['returnReason'] as String?,
          ));
        }

        // Skip if category filter is set but no items matched
        if (_filterCategoryId != null && !hasMatchingCategory) {
          continue;
        }

        // Filter by outletId if set
        if (_filterOutletId != null && transactionMap['outletId']?.toString() != _filterOutletId) {
          continue;
        }

        // Get outlet name from cache
        String? outletName;
        if (transactionMap['outletId'] != null) {
          outletName = outletNames[transactionMap['outletId']];
        }

        // Determine status from payment_status field
        TransactionStatus transactionStatus = TransactionStatus.paid;
        final dbStatus = transactionMap['payment_status'] as String?;
        if (dbStatus == 'UNPAID' || dbStatus == 'PARTIAL') {
          transactionStatus = TransactionStatus.pending;
        } else if (dbStatus == 'CANCELLED') {
          transactionStatus = TransactionStatus.cancelled;
        } else if (dbStatus == 'REFUNDED') {
          transactionStatus = TransactionStatus.refunded;
        }

        // Check if transaction has partial returns (items returned but not fully refunded)
        bool hasPartialReturns = items.any((item) => item.returnedQuantity > 0);
        final finalStatus = (hasPartialReturns && transactionStatus == TransactionStatus.paid)
            ? TransactionStatus.refunded
            : transactionStatus;

        _transactions.add(Transaction(
          id: transactionMap['id'],
          invoiceNumber: transactionMap['invoiceNumber'],
          transactionDate: DateTime.parse(transactionMap['transactionDate']),
          totalAmount: transactionMap['totalAmount'],
          discount: transactionMap['discount'],
          finalAmount: transactionMap['finalAmount'],
          paymentMethod: transactionMap['paymentMethod'],
          outletId: transactionMap['outletId'],
          outletName: outletName,
          salesId: transactionMap['salesId'],
          status: finalStatus,
          items: items,
        ));
      }

      _invalidateCache();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void _invalidateCache() {
    _cacheValid = false;
  }

  void _computeMetrics() {
    if (_cacheValid) return;
    _cacheValid = true;

    double totalSales = 0;
    double totalProfit = 0;
    double pendingProfit = 0;
    int pendingCount = 0;
    double grossProfit = 0;
    double returnsDeducted = 0;
    double totalCost = 0;
    double totalReturns = 0;
    int returnCount = 0;

    for (var transaction in _transactions) {
      totalSales += transaction.finalAmount;
      totalCost += transaction.totalCost;
      returnsDeducted += transaction.totalReturnedAmount;

      if (transaction.status != TransactionStatus.pending &&
          transaction.status != TransactionStatus.cancelled) {
        if (transaction.totalReturnedAmount > 0) {
          totalProfit += transaction.effectiveProfit;
        } else {
          totalProfit += transaction.profit;
        }
      }

      if (transaction.status == TransactionStatus.pending) {
        pendingProfit += transaction.profit;
        pendingCount++;
      }

      grossProfit += transaction.profit;

      if (transaction.status == TransactionStatus.refunded) {
        totalReturns += transaction.finalAmount.abs();
        returnCount++;
      }
    }

    _cachedTotalSales = totalSales;
    _cachedTotalProfit = totalProfit;
    _cachedPendingProfit = pendingProfit;
    _cachedPendingCount = pendingCount;
    _cachedGrossProfit = grossProfit;
    _cachedReturnsDeducted = returnsDeducted;
    _cachedTotalCost = totalCost;
    _cachedTotalReturns = totalReturns;
    _cachedReturnCount = returnCount;
    _cachedProfitMargin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0;
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    loadTransactions(refresh: true);
    loadReturns();
  }

  void setFilters({String? salesId, String? categoryId, String? outletId}) {
    _filterSalesId = salesId;
    _filterCategoryId = categoryId;
    _filterOutletId = outletId;
    loadTransactions(refresh: true);
    loadReturns();
  }

  void clearFilters() {
    _filterSalesId = null;
    _filterCategoryId = null;
    _filterOutletId = null;
    loadTransactions(refresh: true);
    loadReturns();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await loadTransactions(loadMore: true);
  }

  int get totalTransactions => _transactions.length;

  // Returns getters
  List<Return> get returns => _returns;
  double get returnsAmount => _returnsAmount;
  bool get isLoadingReturns => _isLoadingReturns;

  // Load returns from returns table
  Future<void> loadReturns() async {
    _isLoadingReturns = true;
    notifyListeners();

    try {
      _returns = await TransactionService.getReturns(
        startDate: _startDate,
        endDate: _endDate,
      );

      // Calculate total returns amount and profit impact
      _returnsAmount = 0;
      for (var ret in _returns) {
        _returnsAmount += ret.subtotal;
      }
    } catch (e) {
      debugPrint('Error loading returns: $e');
    }

    _isLoadingReturns = false;
    notifyListeners();
  }

  // Net profit = transaction profit - returns amount
  double get netProfit {
    return totalProfit - _returnsAmount;
  }

  // Get returns by type
  List<Return> get outletReturns =>
      _returns.where((r) => r.returnType == ReturnType.outlet).toList();
  List<Return> get salesReturns =>
      _returns.where((r) => r.returnType == ReturnType.sales).toList();
  List<Return> get supplierReturns =>
      _returns.where((r) => r.returnType == ReturnType.supplier).toList();
}
