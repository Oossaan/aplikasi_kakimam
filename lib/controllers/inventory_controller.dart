import 'dart:async';

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/stock_model.dart';
import '../models/return_model.dart';
import '../services/database_service.dart';
import '../services/stock_service.dart';
import '../services/transaction_service.dart';

class InventoryController extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Filter state - disimpan agar tidak hilang saat refresh
  String? _selectedCategory;
  String _stockFilter = 'all'; // all, low, out
  String _sortBy = 'name'; // name, stock, date
  bool _sortAsc = true;
  bool _showActiveOnly = true;

  // Stock movements
  List<StockMovement> _stockInMovements = [];
  List<StockMovement> _stockOutMovements = [];
  List<StockMovement> _stockHistory = [];
  bool _isLoadingMovements = false;

  // Caching
  final Map<int, Product> _productCache = {};

  // Pagination
  static const int _pageSize = 100;
  int _currentPage = 1;
  int _dbTotalCount = 0; // Total count dari DB untuk pagination info
  bool _hasMore = true;

  // Total stats (tanpa pagination - untuk dashboard)
  int _allProductsCount = 0;
  double _allInventoryValue = 0;
  int _allLowStockCount = 0;
  bool _isLoadingStats = false;

  // Debounce
  Timer? _debounceTimer;

  List<Product> get products =>
      _searchQuery.isEmpty ? _products : _filteredProducts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;

  // Pagination getters
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalPages => (_dbTotalCount / _pageSize).ceil();
  int get dbTotalCount => _dbTotalCount;

  // Stats getters (tanpa pagination - untuk dashboard/reports)
  int get totalProducts => _allProductsCount;
  double get totalInventoryValue => _allInventoryValue;
  int get lowStockProducts => _allLowStockCount;

  // Low stock and out of stock lists (loaded without pagination for reports)
  List<Product> _lowStockList = [];
  List<Product> _outOfStockList = [];
  List<Product> get lowStockList => _lowStockList;
  List<Product> get outOfStockList => _outOfStockList;

  // Filter getters
  String? get selectedCategory => _selectedCategory;
  String get stockFilter => _stockFilter;
  String get sortBy => _sortBy;
  bool get sortAsc => _sortAsc;
  bool get showActiveOnly => _showActiveOnly;

  // Set filter methods
  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setStockFilter(String filter) {
    _stockFilter = filter;
    notifyListeners();
  }

  void setSortBy(String sortField, {bool? ascending}) {
    _sortBy = sortField;
    if (ascending != null) _sortAsc = ascending;
    notifyListeners();
  }

  void setShowActiveOnly(bool value) {
    _showActiveOnly = value;
    notifyListeners();
  }

  void resetFilters() {
    _selectedCategory = null;
    _stockFilter = 'all';
    _sortBy = 'name';
    _sortAsc = true;
    _showActiveOnly = true;
    notifyListeners();
  }


  bool hasActiveFilters() {
    return _selectedCategory != null || _stockFilter != 'all' || _sortBy != 'name' || !_sortAsc || !_showActiveOnly;
  }
  // Get filtered products based on current filters
  List<Product> getFilteredProducts(List<Product> products) {
    return products.where((p) {
      // Active filter
      if (_showActiveOnly && !p.isActive) return false;
      // Category filter
      if (_selectedCategory != null && p.categoryName != _selectedCategory) return false;
      // Stock filter
      if (_stockFilter == 'low' && !p.isLowStock) return false;
      if (_stockFilter == 'out' && !p.isOutOfStock) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        int comparison;
        switch (_sortBy) {
          case 'stock':
            comparison = a.stock.compareTo(b.stock);
            break;
          case 'date':
            comparison = a.createdAt.compareTo(b.createdAt);
            break;
          default:
            comparison = a.name.compareTo(b.name);
        }
        return _sortAsc ? comparison : -comparison;
      });
  }

  // Search with debounce 300ms
  void searchProductsDebounced(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        loadProducts(refresh: true);
      } else {
        searchProductsDb(query);
      }
    });
  }

  // Server-side search using SQL LIKE (for large datasets)
  Future<void> searchProductsDb(String query) async {
    _searchQuery = query;
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService.database;

      String whereClause = 'name LIKE ? OR barcode LIKE ? OR category LIKE ?';
      if (_showActiveOnly) {
        whereClause += ' AND isActive = 1';
      }
      if (_selectedCategory != null) {
        whereClause += ' AND category = ?';
      }
      if (_stockFilter == 'low') {
        whereClause += ' AND stock <= minStock AND stock > 0';
      } else if (_stockFilter == 'out') {
        whereClause += ' AND stock <= 0';
      }

      final whereArgs = <String>[
        '%$query%',
        '%$query%',
        '%$query%',
      ];
      if (_selectedCategory != null) {
        whereArgs.add(_selectedCategory!);
      }

      final maps = await db.query(
        'products',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: _sortAsc ? '$_sortBy ASC' : '$_sortBy DESC',
        limit: _pageSize,
      );

      _products = maps.map((map) => Product.fromMap(map)).toList();
      _filteredProducts = _products;

      // Update cache
      for (var product in _products) {
        if (product.id != null) {
          _productCache[product.id!] = product;
        }
      }

      // Search always returns full result set (pagination resets)
      _hasMore = false; // No more for search results
      _currentPage = 0;
    } catch (e) {
      debugPrint('Error searching products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _productCache.clear();
    }

    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService.database;

      // Build WHERE clause with filters
      String whereClause = '';
      final whereArgs = <String>[];

      if (_showActiveOnly) {
        whereClause = 'isActive = 1';
      }
      if (_selectedCategory != null) {
        whereClause += whereClause.isNotEmpty ? ' AND category = ?' : 'category = ?';
        whereArgs.add(_selectedCategory!);
      }
      if (_stockFilter == 'low') {
        whereClause += whereClause.isNotEmpty ? ' AND stock <= minStock AND stock > 0' : 'stock <= minStock AND stock > 0';
      } else if (_stockFilter == 'out') {
        whereClause += whereClause.isNotEmpty ? ' AND stock <= 0' : 'stock <= 0';
      }

      // Get total count for pagination
      final countResult = await db.query(
        'products',
        columns: ['COUNT(*) as count'],
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      );
      _dbTotalCount = countResult.first['count'] as int;

      final offset = (_currentPage - 1) * _pageSize;
      final maps = await db.query(
        'products',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'name ASC',
        limit: _pageSize,
        offset: offset,
      );

      final newProducts = maps.map((map) => Product.fromMap(map)).toList();

      _products = newProducts;
      _hasMore = _currentPage < totalPages;

      // Update cache
      for (var product in newProducts) {
        if (product.id != null) {
          _productCache[product.id!] = product;
        }
      }

      _filteredProducts = _products;
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page > totalPages) return;
    _currentPage = page;
    _hasMore = _currentPage < totalPages;
    await loadProducts();
  }

  Future<void> loadMore() async {
    if (_isLoading) return;
    if (_currentPage >= totalPages) {
      _hasMore = false;
      return;
    }
    _currentPage++;
    await loadProducts();
  }

  Future<void> refresh() async {
    await loadProducts(refresh: true);
  }

  /// Load semua produk tanpa pagination (untuk export Excel)
  Future<List<Product>> loadAllProductsForExport() async {
    try {
      final db = await DatabaseService.database;
      final results = await db.query(
        'products',
        where: 'isActive = 1',
        orderBy: 'name ASC',
      );
      return results.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading all products for export: $e');
      return [];
    }
  }

  /// Load total stats tanpa pagination (untuk dashboard/reports)
  Future<void> loadTotalStats() async {
    if (_isLoadingStats) return;
    _isLoadingStats = true;

    try {
      final db = await DatabaseService.database;

      // Count total products
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE isActive = 1',
      );
      _allProductsCount = countResult.first['count'] as int;

      // Calculate total inventory value and low stock count
      final statsResult = await db.rawQuery(
        'SELECT '
        'SUM(stock * purchasePrice) as totalValue, '
        'SUM(CASE WHEN stock <= minStock AND stock > 0 THEN 1 ELSE 0 END) as lowStock '
        'FROM products WHERE isActive = 1',
      );

      if (statsResult.isNotEmpty) {
        _allInventoryValue = (statsResult.first['totalValue'] as num?)?.toDouble() ?? 0;
        _allLowStockCount = (statsResult.first['lowStock'] as int?) ?? 0;
      }

      // Load low stock products (no pagination)
      final lowStockMaps = await db.query(
        'products',
        where: 'isActive = 1 AND stock <= minStock AND stock > 0',
        orderBy: 'name ASC',
      );
      _lowStockList = lowStockMaps.map((map) => Product.fromMap(map)).toList();

      // Load out of stock products (no pagination)
      final outOfStockMaps = await db.query(
        'products',
        where: 'isActive = 1 AND stock <= 0',
        orderBy: 'name ASC',
      );
      _outOfStockList = outOfStockMaps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading total stats: $e');
    }

    _isLoadingStats = false;
    notifyListeners();
  }

  // Get product from cache (instant, no DB call)
  Product? getProductById(int id) {
    return _productCache[id];
  }

  // Invalidate cache for specific product
  void invalidateCache(int productId) {
    _productCache.remove(productId);
  }

  // Update cache after transaction
  void updateStockInCache(int productId, int newStock) {
    if (_productCache.containsKey(productId)) {
      final product = _productCache[productId]!;
      _productCache[productId] = product.copyWith(stock: newStock);
    }

    // Also update in list
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(stock: newStock);
    }

    // Update filtered
    final filteredIndex =
        _filteredProducts.indexWhere((p) => p.id == productId);
    if (filteredIndex != -1) {
      _filteredProducts[filteredIndex] =
          _filteredProducts[filteredIndex].copyWith(stock: newStock);
    }

    notifyListeners();
  }

  Future<bool> addProduct(Product product) async {
    try {
      final db = await DatabaseService.database;

      // Check if barcode already exists
      final existing = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [product.barcode],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        debugPrint('Error adding product: Barcode ${product.barcode} already exists');
        return false;
      }

      final id = await db.insert('products', product.toMap());

      // Update cache
      final newProduct = product.copyWith(id: id);
      _productCache[id] = newProduct;

      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error adding product: $e');
      return false;
    }
  }

  Future<bool> addProducts(List<Product> products) async {
    if (products.isEmpty) return true;

    try {
      final db = await DatabaseService.database;

      for (final product in products) {
        // Skip if barcode already exists
        final existing = await db.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [product.barcode],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        final id = await db.insert('products', product.toMap());
        final newProduct = product.copyWith(id: id);
        _productCache[id] = newProduct;
      }

      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error adding products: $e');
      return false;
    }
  }


  Future<bool> updateProduct(Product product) async {
    try {
      final db = await DatabaseService.database;
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Update cache
      if (product.id != null) {
        _productCache[product.id!] = product;
      }

      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final db = await DatabaseService.database;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);

      // Remove from cache
      _productCache.remove(id);

      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  Future<bool> recordStockIn(int productId, int quantity, {String notes = '', int? referenceId}) async {
    try {
      await StockService.addStock(
        productId: productId,
        quantity: quantity,
        notes: notes,
        referenceId: referenceId,
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock + quantity);
      }
      return true;
    } catch (e) {
      debugPrint('Error recording stock in: $e');
      return false;
    }
  }

  Future<bool> recordStockOut(int productId, int quantity, {String notes = '', int? referenceId}) async {
    try {
      await StockService.removeStock(
        productId: productId,
        quantity: quantity,
        notes: notes,
        referenceId: referenceId,
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock - quantity);
      }
      return true;
    } catch (e) {
      debugPrint('Error recording stock out: $e');
      return false;
    }
  }

  Future<List<StockMovement>> getRecentMovements({int limit = 20}) async {
    return await StockService.getMovements(limit: limit);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    if (_productCache.containsKey(0)) { // dummy key for barcode cache
      final cached = _productCache[0];
      if (cached?.barcode == barcode) return cached;
    }

    try {
      final db = await DatabaseService.database;
      final results = await db.query(
        'products',
        where: 'barcode = ? AND isActive = 1',
        whereArgs: [barcode],
      );
      if (results.isNotEmpty) {
        final product = Product.fromMap(results.first);
        _productCache[0] = product; // cache recent barcode
        return product;
      }
    } catch (e) {
      debugPrint('Error finding product by barcode: $e');
    }
    return null;
  }

  Future<bool> adjustStock(int productId, int adjustment, {String? notes}) async {
    try {
      final product = getProductById(productId) ??
          _products.firstWhere((p) => p.id == productId);
      final newStock = product.stock + adjustment;
      if (newStock < 0) return false;

      await StockService.adjustStock(
        productId: productId,
        newStock: newStock,
        notes: notes ?? 'Manual adjustment (+${adjustment > 0 ? '+' : ''}${adjustment.abs()})',
      );

      updateStockInCache(productId, newStock);
      return true;
    } catch (e) {
      debugPrint('Error adjusting stock: $e');
      return false;
    }
  }

  void searchProducts(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredProducts = _products;
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(lowerQuery) ||
            product.barcode.contains(query) ||
            product.category.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    notifyListeners();
  }

  // Stock movements getters
  List<StockMovement> get stockInMovements => _stockInMovements;
  List<StockMovement> get stockOutMovements => _stockOutMovements;
  List<StockMovement> get stockHistory => _stockHistory;
  bool get isLoadingMovements => _isLoadingMovements;

  // Grouped stock history (for invoice/supplier grouping)
  List<StockHistoryGroup> _stockInGroups = [];
  List<StockHistoryGroup> _stockOutGroups = [];
  List<StockHistoryGroup> get stockInGroups => _stockInGroups;
  List<StockHistoryGroup> get stockOutGroups => _stockOutGroups;

  // Load stock movements
  Future<void> loadStockMovements() async {
    _isLoadingMovements = true;
    notifyListeners();

    try {
      _stockInMovements = await StockService.getMovements(
        type: StockMovementType.stockIn,
        limit: 50,
      );

      _stockOutMovements = await StockService.getMovements(
        type: StockMovementType.stockOut,
        limit: 50,
      );

      _stockHistory = await StockService.getMovements(limit: 100);

      // Load grouped stock history
      _stockInGroups = await StockService.getStockHistoryGroupedBySupplier(limit: 50);
      _stockOutGroups = await StockService.getStockHistoryGroupedByTransaction(limit: 50);
    } catch (e) {
      debugPrint('Error loading stock movements: $e');
    }

    _isLoadingMovements = false;
    notifyListeners();
  }

  // Stock in operations
  Future<bool> restock({
    required int productId,
    required int quantity,
    String notes = '',
    int? referenceId,
  }) async {
    try {
      await StockService.addStock(
        productId: productId,
        quantity: quantity,
        notes: notes.isNotEmpty ? notes : 'Restock',
        referenceId: referenceId,
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock + quantity);
      }
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error restocking: $e');
      return false;
    }
  }

  Future<bool> receiveItems({
    required int productId,
    required int quantity,
    String notes = '',
    int? referenceId,
  }) async {
    try {
      await StockService.addStock(
        productId: productId,
        quantity: quantity,
        notes: notes.isNotEmpty ? notes : 'Receive Items from Supplier',
        referenceId: referenceId,
        referenceType: 'supplier',
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock + quantity);
      }
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error receiving items: $e');
      return false;
    }
  }

  // Batch receive items (multi-product stock in) - uses transaction for atomicity
  Future<Map<String, dynamic>> batchReceiveItems({
    required List<Map<String, dynamic>> items, // [{productId, quantity, notes}]
    required int supplierId,
    required String supplierName,
    int? userId,
  }) async {
    final results = <String, dynamic>{
      'success': <int>[],
      'failed': <int, String>{},
      'referenceNumber': 'FKT-${DateTime.now().millisecondsSinceEpoch}',
    };

    try {
      for (var item in items) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as int;
        final notes = item['notes'] as String? ?? 'Diterima dari $supplierName';

        final success = await receiveItems(
          productId: productId,
          quantity: quantity,
          notes: notes,
          referenceId: supplierId,
        );

        if (success) {
          (results['success'] as List<int>).add(productId);
        } else {
          (results['failed'] as Map<int, String>)[productId] = 'Failed to add stock';
        }
      }
      results['allSuccess'] = (results['failed'] as Map).isEmpty;
    } catch (e) {
      debugPrint('Error batch receiving items: $e');
      results['error'] = e.toString();
      results['allSuccess'] = false;
    }

    return results;
  }

Future<bool> purchaseReturn({
    required int productId,
    required int quantity,
    String notes = '',
    int? referenceId,
  }) async {
    try {
      // Retur ke supplier = barang dikirim ke supplier, STOK BERKURANG
      await StockService.removeStock(
        productId: productId,
        quantity: quantity,
        notes: notes.isNotEmpty ? notes : 'Retur ke Supplier',
        referenceId: referenceId,
        referenceType: 'return',
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock - quantity);
      }
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error recording purchase return: $e');
      return false;
    }
  }

// Outlet return - barang dikembalikan dari outlet, STOK BERTAMBAH + affect profit
    Future<bool> outletReturn({
      required int productId,
      required int quantity,
      String notes = '',
      int? referenceId,
      String? originalInvoiceNumber,
      int? originalTransactionId,
    }) async {
      try {
        final product = getProductById(productId);
        if (product == null) return false;

        // 1. Retur dari outlet = barang dikembalikan ke inventory, STOK BERTAMBAH
        await StockService.addStock(
          productId: productId,
          quantity: quantity,
          notes: notes.isNotEmpty ? notes : 'Retur dari Outlet',
          referenceId: referenceId,
          referenceType: 'return',
        );

        // 2. Save to returns table (NOT creating RET invoice in transactions table)
        await TransactionService.createReturn(
          productId: productId,
          productName: product.name,
          price: product.sellingPrice,
          cost: product.purchasePrice,
          quantity: quantity,
          returnType: ReturnType.outlet,
          originalTransactionId: originalTransactionId,
          originalInvoiceNumber: originalInvoiceNumber,
          notes: notes.isNotEmpty ? notes : 'Retur dari Outlet',
        );

      // Update cache
      updateStockInCache(productId, product.stock + quantity);
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error recording outlet return: $e');
      return false;
    }
  }

  // Stock out operations
  Future<bool> goodIssue({
    required int productId,
    required int quantity,
    String notes = '',
    int? referenceId,
  }) async {
    try {
      await StockService.removeStock(
        productId: productId,
        quantity: quantity,
        notes: notes.isNotEmpty ? notes : 'Good Issue - barang rusak/hilang',
        referenceId: referenceId,
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock - quantity);
      }
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error recording good issue: $e');
      return false;
    }
  }

  Future<bool> sales({
    required int productId,
    required int quantity,
    String notes = '',
    int? referenceId,
  }) async {
    try {
      await StockService.removeStock(
        productId: productId,
        quantity: quantity,
        notes: notes.isNotEmpty ? notes : 'Penjualan',
        referenceId: referenceId,
      );
      final product = getProductById(productId);
      if (product != null) {
        updateStockInCache(productId, product.stock - quantity);
      }
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error recording sales: $e');
      return false;
    }
  }

Future<bool> salesReturn({
    required int productId,
    required int quantity,
    String notes = '',
    int? referenceId,
  }) async {
    try {
      final product = getProductById(productId);
      if (product == null) return false;

      // 1. Retur penjualan = barang dikembalikan dari pembeli, STOK BERTAMBAH
      await StockService.addStock(
        productId: productId,
        quantity: quantity,
        notes: notes.isNotEmpty ? notes : 'Retur Penjualan dari Pembeli',
        referenceId: referenceId,
        referenceType: 'return',
      );

      // 2. Save to returns table (NOT creating RET invoice in transactions table)
      await TransactionService.createReturn(
        productId: productId,
        productName: product.name,
        price: product.sellingPrice,
        cost: product.purchasePrice,
        quantity: quantity,
        returnType: ReturnType.sales,
        notes: notes.isNotEmpty ? notes : 'Retur Penjualan dari Pembeli',
      );

      // Update cache
      updateStockInCache(productId, product.stock + quantity);
      await loadStockMovements();
      return true;
    } catch (e) {
      debugPrint('Error recording sales return: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

