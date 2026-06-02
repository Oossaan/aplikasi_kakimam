import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/outlet_model.dart';
import '../models/supplier_model.dart';
import '../models/sales_model.dart';
import '../models/payment_detail_model.dart';
import '../models/stock_model.dart';
import '../services/database_service.dart';
import '../services/stock_service.dart';

class POSController extends ChangeNotifier {
  final List<CartItem> _cart = [];
  double _discount = 0;
  String _paymentMethod = 'Cash';
  Outlet? _selectedOutlet;
  Supplier? _selectedSupplier;
  Sales? _selectedSales;
  String _currentUserName = '';

  // Multi payment support
  final List<PaymentDetail> _payments = [];
  String _paymentMode = 'LUNAS'; // 'LUNAS' or 'TEMPO'
  DateTime? _dueDate;

  // Loading state
  bool _isLoading = false;
  String? _error;

  // Purchase mode (vs sales mode) for toggle
  bool _isPurchaseMode = false;

  List<CartItem> get cart => _cart;
  double get discount => _discount;
  String get paymentMethod => _paymentMethod;
  Outlet? get selectedOutlet => _selectedOutlet;
  Supplier? get selectedSupplier => _selectedSupplier;
  Sales? get selectedSales => _selectedSales;
  String get currentUserName => _currentUserName;
  List<PaymentDetail> get payments => _payments;
  String get paymentMode => _paymentMode;
  DateTime? get dueDate => _dueDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPurchaseMode => _isPurchaseMode;

  double get subtotal => _cart.fold(0, (sum, item) => sum + item.subtotal);

  // Subtotal sebelum diskon item (Σ harga*qty, tanpa memperhitungkan itemDiscountAmount)
  double get subtotalBeforeItemDiscount =>
      _cart.fold(0, (sum, item) => sum + item.itemSubtotal);

  // diskon per item (amount) yang sudah tersimpan di cart
  double get itemDiscountTotal =>
      _cart.fold(0, (sum, item) => sum + item.itemDiscountAmount);

  // Diskon keseluruhan:
  // - persen dihitung dari subtotalBeforeItemDiscount
  // - nominal diskonnya dipotong dari subtotal setelah diskon item
  double get discountAmount => subtotalBeforeItemDiscount * (_discount / 100);
  double get total => subtotal - discountAmount;

  int get itemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  // Calculate total paid from multi payment
  double get totalPaid => _payments.fold(0, (sum, p) => sum + p.amount);
  double get remainingPayment => total - totalPaid;
  bool get isFullyPaid => totalPaid >= total;
  bool get canAddPayment => _paymentMode == 'LUNAS' && remainingPayment > 0;

  void setOutlet(Outlet? outlet) {
    _selectedOutlet = outlet;
    if (outlet != null) {
      debugPrint(
          'Outlet: ${outlet.name}, Credit Limit: ${outlet.creditLimit}, Used: ${outlet.currentCredit}');
    }
    notifyListeners();
  }

  void setSupplier(Supplier? supplier) {
    _selectedSupplier = supplier;
    if (supplier != null) {
      debugPrint('Supplier: ${supplier.name}');
    }
    notifyListeners();
  }

  void setSales(Sales? sales) {
    _selectedSales = sales;
    if (sales != null) {
      debugPrint('Sales: ${sales.name}');
    }
    notifyListeners();
  }

  void setCurrentUser(String userName) {
    _currentUserName = userName;
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    if (mode == 'TEMPO') {
      _dueDate = DateTime.now().add(const Duration(days: 30));
    }
    notifyListeners();
  }

  void setDueDate(DateTime? date) {
    _dueDate = date;
    notifyListeners();
  }

  void setPurchaseMode(bool isPurchase) {
    _isPurchaseMode = isPurchase;
    _cart.clear(); // Clear cart when switching modes to reset prices
    _payments.clear();
    notifyListeners();
  }

  void addPayment(PaymentType type, double amount,
      {String? referenceNo, String? cardLastFour}) {
    if (amount <= 0 || amount > remainingPayment) return;

    _payments.add(PaymentDetail(
      transactionId: 0,
      paymentType: type.code,
      amount: amount,
      referenceNo: referenceNo,
      cardLastFour: cardLastFour,
    ));
    notifyListeners();
  }

  void removePayment(int index) {
    if (index >= 0 && index < _payments.length) {
      _payments.removeAt(index);
      notifyListeners();
    }
  }

  void clearPayments() {
    _payments.clear();
    notifyListeners();
  }

  void addToCart(Product product, {int quantity = 1}) {

    if (product.id == null) return;
    final existingIndex =
        _cart.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      final currentItem = _cart[existingIndex];
      // If switching modes, update price to match new mode
      if (currentItem.fromPurchaseMode != _isPurchaseMode) {
        currentItem.customPrice = _isPurchaseMode
            ? product.purchasePrice
            : product.sellingPrice;
        currentItem.fromPurchaseMode = _isPurchaseMode;
        currentItem.isPriceModified = false;
      }
      // In purchase mode, no stock limit. In sales mode, check available stock
      if (_isPurchaseMode) {
        _cart[existingIndex].quantity += quantity;
      } else {
        final availableStock = product.stock - currentItem.quantity;
        final addQty = quantity > availableStock ? availableStock : quantity;
        if (addQty > 0) {
          _cart[existingIndex].quantity += addQty;
        }
      }
    } else {
      // In purchase mode, no stock check. In sales mode, require stock > 0
      if (_isPurchaseMode || product.stock > 0) {
        final addQty = _isPurchaseMode ? quantity : (quantity > product.stock ? product.stock : quantity);
        _cart.add(CartItem(
          product: product,
          quantity: addQty,
          customPrice: _isPurchaseMode ? product.purchasePrice : product.sellingPrice,
          fromPurchaseMode: _isPurchaseMode,
        ));
      }
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeFromCart(index);
      return;
    }
    // In purchase mode, no stock limit. In sales mode, check stock
    if (_isPurchaseMode || quantity <= _cart[index].product.stock) {
      _cart[index].quantity = quantity;
    }
    notifyListeners();
  }

  void updateItemPrice(int index, double newPrice, {int? transactionId}) {
    if (index >= 0 && index < _cart.length) {
      _cart[index].updatePrice(newPrice);
      notifyListeners();
    }
  }

  /// Sync product data di cart item setelah produk diupdate di database.
  /// Mengganti snapshot produk lama dengan data terbaru tanpa mengubah customPrice.
  void syncCartItemProduct(int index, Product updatedProduct) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    _cart[index] = CartItem(
      product: updatedProduct,
      quantity: item.quantity,
      customPrice: item.customPrice,
      isPriceModified: item.isPriceModified,
      fromPurchaseMode: item.fromPurchaseMode,
      itemDiscountAmount: item.itemDiscountAmount,
    );
    notifyListeners();
  }

  void updateItemDiscountAmount(int index, double amount) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].updateItemDiscountAmount(amount.clamp(0, double.infinity));
    notifyListeners();
  }

  /// Update item discount by percentage
  void updateItemDiscountByPercent(int index, double percent) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].updateItemDiscountByPercent(percent);
    notifyListeners();
  }

  /// Update item discount by nominal amount
  void updateItemDiscountByNominal(int index, double nominal) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].updateItemDiscountByNominal(nominal);
    notifyListeners();
  }

  Future<void> logPriceChange(
      {int? productId,
      required String productName,
      required double oldPrice,
      required double newPrice,
      int? transactionId}) async {
    if (oldPrice == newPrice || productId == null) return;
    try {
      final db = await DatabaseService.database;
      await db.insert('priceHistory', {
        'productId': productId,
        'productName': productName,
        'oldPrice': oldPrice,
        'newPrice': newPrice,
        'outletId': _selectedOutlet?.id,
        'transactionId': transactionId,
        'changedBy': _currentUserName,
        'changedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error logging price change: $e');
    }
  }

  void setDiscount(double discount) {
    _discount = discount;
    notifyListeners();
  }

  /// Set diskon keseluruhan dalam persen (%)
  void setDiscountByPercent(double percent) {
    if (percent < 0 || percent > 100) return;
    _discount = percent;
    notifyListeners();
  }

  /// Set diskon keseluruhan dalam nominal (Rp)
  void setDiscountByNominal(double nominal) {
    if (nominal < 0 || subtotalBeforeItemDiscount == 0) return;
    // Hitung persentase dari nominal
    _discount = (nominal / subtotalBeforeItemDiscount) * 100;
    _discount = _discount.clamp(0, 100);
    notifyListeners();
  }

  /// Get discount percent
  double get discountPercent => _discount;

  /// Get discount in percent that we can display
  /// This is the overall discount percentage
  double get displayDiscountPercent => _discount;

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  Future<String> processTransaction({Function? onSuccess}) async {
    if (_cart.isEmpty) return 'Error: Keranjang kosong';

    // Check based on mode
    if (_isPurchaseMode) {
      if (_selectedSupplier == null) return 'Error: Pilih supplier terlebih dahulu di bagian atas layar';
    } else {
      if (_selectedOutlet == null) return 'Error: Pilih outlet terlebih dahulu di bagian atas layar';
    }

    // Sales is required in both modes
    if (_selectedSales == null) return 'Error: Pilih sales terlebih dahulu di bagian atas layar';

    if (_paymentMode == 'LUNAS' && !isFullyPaid) {
      return 'Error: Pembayaran belum lengkap';
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseService.database;

      // Different invoice number prefix based on mode
      final invoicePrefix = _isPurchaseMode ? 'Beli' : 'INV';
      final invoiceNumber = '$invoicePrefix-${DateTime.now().millisecondsSinceEpoch}';
      final paymentStatus = _paymentMode == 'TEMPO' ? 'UNPAID' : 'PAID';

      // Log price changes
      for (var item in _cart) {
        if (item.isPriceModified && item.product.id != null) {
          await logPriceChange(
            productId: item.product.id,
            productName: item.product.name,
            oldPrice: item.product.sellingPrice,
            newPrice: item.customPrice,
          );
        }
      }

      // Insert main transaction
      final transactionId = await db.insert('transactions', {
        'invoiceNumber': invoiceNumber,
        'transactionDate': DateTime.now().toIso8601String(),
        'totalAmount': subtotal,
        'discount': discountAmount,
        'discountPercent': _discount,
        'finalAmount': total,
        'paymentMethod': _paymentMethod,
        'outletId': _isPurchaseMode ? null : _selectedOutlet?.id,
        'supplierId': _isPurchaseMode ? _selectedSupplier?.id : null,
        'salesId': _selectedSales?.id,
        'transactionType': _isPurchaseMode ? 'purchase' : 'sales',
        'payment_status': paymentStatus,
        'due_date': _dueDate?.toIso8601String(),
        'remaining_amount': _paymentMode == 'TEMPO' ? total : 0,
      });

      // Insert payment details
      for (var payment in _payments) {
        await db.insert('payment_details', {
          'transaction_id': transactionId,
          'payment_type': payment.paymentType,
          'amount': payment.amount,
          'reference_no': payment.referenceNo,
          'card_last_four': payment.cardLastFour,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Insert items and update stock
      for (var item in _cart) {
        if (item.product.id == null) continue;
        await db.insert('transactionItems', {
          'transactionId': transactionId,
          'productId': item.product.id,
          'productName': item.product.name,
          'price': item.effectivePrice,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
          'itemDiscount': item.itemDiscountAmount,
          'cost': item.product.purchasePrice,
        });


        // Record stock movement based on mode
        if (_isPurchaseMode) {
          // Purchase mode: stock IN from supplier
          await StockService.recordMovement(
            productId: item.product.id!,
            type: StockMovementType.stockIn,
            quantity: item.quantity,
            previousStock: item.product.stock,
            newStock: item.product.stock + item.quantity,
            referenceId: transactionId,
            referenceType: 'supplier',
            notes: 'Pembelian Supplier ${_selectedSupplier?.name ?? ""} - $invoiceNumber',
          );

          // Update product stock - increase
          await db.update(
            'products',
            {
              'stock': item.product.stock + item.quantity,
              'updatedAt': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [item.product.id],
          );
        } else {
          // Sales mode: stock OUT to outlet
          await StockService.recordMovement(
            productId: item.product.id!,
            type: StockMovementType.stockOut,
            quantity: item.quantity,
            previousStock: item.product.stock,
            newStock: item.product.stock - item.quantity,
            referenceId: transactionId,
            referenceType: 'transaction',
            notes: 'Penjualan POS - $invoiceNumber',
          );

          // Update product stock - decrease
          await db.update(
            'products',
            {
              'stock': item.product.stock - item.quantity,
              'updatedAt': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [item.product.id],
          );
        }
      }

      // Update outlet credit for tempo (only in sales mode)
      if (!_isPurchaseMode &&
          _paymentMode == 'TEMPO' &&
          _selectedOutlet != null &&
          _selectedOutlet!.id != null) {
        final newCredit = _selectedOutlet!.currentCredit + total;
        await db.update(
          'outlets',
          {'current_credit': newCredit},
          where: 'id = ?',
          whereArgs: [_selectedOutlet!.id],
        );
      }

      // If this is a purchase with tempo, also record it as supplier hutang
      if (_isPurchaseMode && _paymentMode == 'TEMPO' && _selectedSupplier != null && _selectedSupplier!.id != null) {
        try {
          await db.insert('supplierHutang', {
            'supplierId': _selectedSupplier!.id,
            'supplierName': _selectedSupplier!.name ?? '',
            'invoiceNumber': invoiceNumber,
            'totalAmount': total,
            'paidAmount': 0,
            'remainingAmount': total,
            'dueDate': _dueDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'status': 'UNPAID',
            'notes': '',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'createdBy': null,
          });
        } catch (e) {
          debugPrint('Error inserting supplierHutang: $e');
        }
      }

      clearCart();
      clearPayments();
      _discount = 0;
      _paymentMode = 'LUNAS';
      _dueDate = null;

      _isLoading = false;
      notifyListeners();

      // Refresh inventory
      onSuccess?.call();

      return invoiceNumber;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error processing transaction: $e');
      return 'Error: ${e.toString()}';
    }
  }

  void clearCart() {
    _cart.clear();

    _discount = 0;
    _paymentMethod = 'Cash';
    _payments.clear();
    _paymentMode = 'LUNAS';
    _dueDate = null;
    notifyListeners();
  }

  void clearDiscount() {
    _discount = 0;
    notifyListeners();
  }

  void applyDiscount(double percentage) {
    if (percentage >= 0 && percentage <= 100) {
      _discount = percentage;
      notifyListeners();
    }
  }
}
