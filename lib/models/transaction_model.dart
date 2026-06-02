// Transaction type enum - untuk menentukan flow
enum TransactionType { sale, purchase }

// Transaction status enum
enum TransactionStatus { pending, paid, cancelled, refunded }

class Transaction {
  final int? id;
  final String invoiceNumber;
  final DateTime transactionDate;
  final double totalAmount;
  final double discount; // Diskon nominal (Rp)
  final double discountPercent; // Diskon persen (%)
  final double finalAmount;
  final String paymentMethod;
  final int? outletId;
  final String? outletName;
  final String? outletAddress;
  final int? userId;
  final String? userName;
  final TransactionStatus status;
  final String? voidReason;
  final DateTime? voidDate;
  final int? voidBy;
  final String? customerName;
  final String? notes;
  final int? originalTransactionId;
  final String? originalInvoiceNumber;
  final List<TransactionItem> items;
  final List<AppliedDiscount> appliedDiscounts;

  // New fields for formal invoice
  final DateTime? shipmentDate; // Tgl. Pengiriman
  final String? supplierName; // Nama Supplier (untuk purchase)
  final String? supplierAddress; // Alamat Supplier
  final String? supplierPhone; // Telepon Supplier
  final String? outletPhone; // Telepon Outlet/Pelanggan
  final double taxAmount; // Total Pajak
  final double taxRate; // Rate pajak (dalam %)
  final double otherFees; // Biaya lain-lain
  final String? senderName; // Nama pengirim
  final int? salesId; // ID Sales
  final String? salesName; // Nama Sales
  final String? salesPhone; // Telepon Sales

  Transaction({
    this.id,
    required this.invoiceNumber,
    required this.transactionDate,
    required this.totalAmount,
    this.discount = 0,
    this.discountPercent = 0,
    required this.finalAmount,
    required this.paymentMethod,
    this.outletId,
    this.outletName,
    this.outletAddress,
    this.userId,
    this.userName,
    this.status = TransactionStatus.paid,
    this.voidReason,
    this.voidDate,
    this.voidBy,
    this.customerName,
    this.notes,
    this.originalTransactionId,
    this.originalInvoiceNumber,
    this.items = const [],
    this.appliedDiscounts = const [],
    this.shipmentDate,
    this.supplierName,
    this.supplierAddress,
    this.supplierPhone,
    this.outletPhone,
    this.taxAmount = 0,
    this.taxRate = 0,
    this.otherFees = 0,
    this.senderName,
    this.salesId,
    this.salesName,
    this.salesPhone,
  });

  // Determine transaction type based on outletId
  TransactionType get transactionType => outletId != null ? TransactionType.sale : TransactionType.purchase;

  // Get party name (outlet for sale, supplier for purchase)
  String get partyName => transactionType == TransactionType.sale ? (outletName ?? '-') : (supplierName ?? '-');

  // Get party address (outlet for sale, supplier for purchase)
  String get partyAddress => transactionType == TransactionType.sale ? (outletAddress ?? '-') : (supplierAddress ?? '-');

  // Calculate subtotal before tax
  double get subtotalBeforeTax => totalAmount;

  // Calculate total with tax
  double get totalWithTax => subtotalBeforeTax + taxAmount;

  // Calculate grand total (before payment)
  double get grandTotal => totalWithTax - discount + otherFees;

  // Check if is sale or purchase
  bool get isSale => transactionType == TransactionType.sale;
  bool get isPurchase => transactionType == TransactionType.purchase;

  factory Transaction.fromMap(
    Map<String, dynamic> map,
    List<TransactionItem> items, {
    String? outletName,
    String? outletAddress,
    String? outletPhone,
    String? supplierName,
    String? supplierAddress,
    String? supplierPhone,
    String? userName,
    List<AppliedDiscount>? appliedDiscounts,
  }) {
    TransactionStatus status = TransactionStatus.paid;
    switch (map['status'] as String?) {
      case 'PENDING':
      case 'UNPAID':
      case 'PARTIAL':
        status = TransactionStatus.pending;
        break;
      case 'CANCELLED':
        status = TransactionStatus.cancelled;
        break;
      case 'REFUNDED':
        status = TransactionStatus.refunded;
        break;
    }

    return Transaction(
      id: map['id'] as int?,
      invoiceNumber: map['invoiceNumber'] as String,
      transactionDate: DateTime.parse(map['transactionDate'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0,
      finalAmount: (map['finalAmount'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
      outletId: map['outletId'] as int?,
      outletName: outletName ?? map['outletName'] as String?,
      outletAddress: outletAddress ?? map['outletAddress'] as String?,
      outletPhone: outletPhone ?? map['outletPhone'] as String?,
      userId: map['userId'] as int?,
      userName: userName ?? map['userName'] as String?,
      status: status,
      voidReason: map['voidReason'] as String?,
      voidDate: map['voidDate'] != null
          ? DateTime.parse(map['voidDate'] as String)
          : null,
      voidBy: map['voidBy'] as int?,
      customerName: map['customerName'] as String?,
      notes: map['notes'] as String?,
      originalTransactionId: map['originalTransactionId'] as int?,
      originalInvoiceNumber: map['originalInvoiceNumber'] as String?,
      items: items,
      appliedDiscounts: appliedDiscounts ?? [],
      supplierName: supplierName ?? map['supplierName'] as String?,
      supplierAddress: supplierAddress ?? map['supplierAddress'] as String?,
      supplierPhone: supplierPhone ?? map['supplierPhone'] as String?,
      shipmentDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      salesId: map['salesId'] as int?,
      salesName: map['salesName'] as String?,
      salesPhone: map['salesPhone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    String statusStr;
    switch (status) {
      case TransactionStatus.pending:
        statusStr = 'PENDING';
        break;
      case TransactionStatus.cancelled:
        statusStr = 'CANCELLED';
        break;
      case TransactionStatus.refunded:
        statusStr = 'REFUNDED';
        break;
      default:
        statusStr = 'PAID';
    }

    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'transactionDate': transactionDate.toIso8601String(),
      'totalAmount': totalAmount,
      'discount': discount,
      'discountPercent': discountPercent,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'outletId': outletId,
      'userId': userId,
      'status': statusStr,
      'voidReason': voidReason,
      'voidDate': voidDate?.toIso8601String(),
      'voidBy': voidBy,
      'customerName': customerName,
      'notes': notes,
      'salesId': salesId,
      'salesName': salesName,
      'salesPhone': salesPhone,
    };
  }

  Transaction copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? transactionDate,
    double? totalAmount,
    double? discount,
    double? discountPercent,
    double? finalAmount,
    String? paymentMethod,
    int? outletId,
    String? outletName,
    int? userId,
    String? userName,
    TransactionStatus? status,
    String? voidReason,
    DateTime? voidDate,
    int? voidBy,
    String? customerName,
    String? notes,
    List<TransactionItem>? items,
    List<AppliedDiscount>? appliedDiscounts,
  }) {
    return Transaction(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      transactionDate: transactionDate ?? this.transactionDate,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      discountPercent: discountPercent ?? this.discountPercent,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      voidDate: voidDate ?? this.voidDate,
      voidBy: voidBy ?? this.voidBy,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      appliedDiscounts: appliedDiscounts ?? this.appliedDiscounts,
    );
  }

  bool get isCancelled => status == TransactionStatus.cancelled;
  bool get isRefunded => status == TransactionStatus.refunded;
  bool get canEdit {
    if (isCancelled || isRefunded) return false;
    final hoursDiff = DateTime.now().difference(transactionDate).inHours;
    return hoursDiff < 24;
  }

  String get statusLabel {
    switch (status) {
      case TransactionStatus.pending:
        return 'Menunggu';
      case TransactionStatus.paid:
        return 'Lunas';
      case TransactionStatus.cancelled:
        return 'Dibatalkan';
      case TransactionStatus.refunded:
        return 'Dikembalikan';
    }
  }

// Calculate total cost from items (using purchasePrice from database)
  double get totalCost {
    return items.fold(0, (sum, item) => sum + (item.cost * item.quantity));
  }

  // Calculate cost considering returns
  double get effectiveCost {
    return items.fold(0, (sum, item) => sum + (item.cost * item.effectiveQuantity));
  }
  
  // Calculate effective revenue (after returns)
  double get effectiveRevenue {
    return items.fold(0, (sum, item) => sum + item.effectiveSubtotal);
  }
  
// Calculate total return amount
  double get totalReturnedAmount {
    return items.fold(0, (sum, item) => sum + (item.price * item.returnedQuantity));
  }
  
  // Profit = Revenue - Cost
  double get profit => finalAmount - totalCost;
  
  // Effective profit considering returns
  double get effectiveProfit => effectiveRevenue - effectiveCost;
}

class TransactionItem {
  final int? id;
  final int productId;
  final String productName;
  final double price;
  final double? originalPrice;
  final bool isPriceModified;
  final int quantity;
  final String satuan; // Satuan (gram, pcs, kg, dll)
  final double subtotal;
  final int? discountId;
  final double itemDiscount;
  final double cost; // Purchase price untuk profit calculation

  // Return tracking fields
  final bool isReturned; // Apakah item ini sudah diretur
  final int returnedQuantity; // Jumlah yang sudah diretur
  final String? returnReason; // Alasan retur

  // Gold shop specific fields
  final double? berat; // Berat dalam gram (untuk toko emas)
  final double? hargaPerGram; // Harga per gram (untuk toko emas)

  // Satuan untuk item (pcs, gram, kg, dll)
  // NOTE: sekarang belum dimapping dari DB.
  // Supaya SAT tampil saat print invoice, kita mapping field `satuan` dari transactionItems.


  TransactionItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.price,
    this.originalPrice,
    this.isPriceModified = false,
    required this.quantity,
    this.satuan = 'pcs', // Default satuan
    required this.subtotal,
    this.discountId,
    this.itemDiscount = 0,
    this.cost = 0, // Default 0 jika tidak ada purchase price
    this.isReturned = false,
    this.returnedQuantity = 0,
    this.returnReason,
    this.berat,
    this.hargaPerGram,
  });

  // Get remaining quantity after return
  int get remainingQuantity => quantity - returnedQuantity;
  
// Get actual quantity (for profit calculation)
  double get effectiveQuantity => (quantity - returnedQuantity).toDouble();
  
  // Get effective subtotal after return
  double get effectiveSubtotal => subtotal - (price * returnedQuantity);
  
  // Check if fully returned
  bool get isFullyReturned => returnedQuantity >= quantity;

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      isPriceModified: (map['isPriceModified'] as int?) == 1,
      quantity: map['quantity'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountId: map['discountId'] as int?,
      itemDiscount: (map['itemDiscount'] as num?)?.toDouble() ?? 0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      isReturned: (map['isReturned'] as int?) == 1,
      returnedQuantity: map['returnedQuantity'] as int? ?? 0,
      returnReason: map['returnReason'] as String?,
      satuan: (map['satuan'] as String?) ?? (map['sat'] as String?) ?? 'pcs',
      berat: (map['berat'] as num?)?.toDouble(),
      hargaPerGram: (map['hargaPerGram'] as num?)?.toDouble(),

    );
  }

  Map<String, dynamic> toMap(int transactionId) {
    return {
      'id': id,
      'transactionId': transactionId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'originalPrice': originalPrice,
      'isPriceModified': isPriceModified ? 1 : 0,
      'quantity': quantity,
      'subtotal': subtotal,
      'discountId': discountId,
      'itemDiscount': itemDiscount,
      'cost': cost,
      'isReturned': isReturned ? 1 : 0,
      'returnedQuantity': returnedQuantity,
      'returnReason': returnReason,
      'berat': berat,
      'hargaPerGram': hargaPerGram,
    };
  }
  
  TransactionItem copyWith({
    int? id,
    int? productId,
    String? productName,
    double? price,
    double? originalPrice,
    bool? isPriceModified,
    int? quantity,
    double? subtotal,
    int? discountId,
    double? itemDiscount,
    double? cost,
    bool? isReturned,
    int? returnedQuantity,
    String? returnReason,
    double? berat,
    double? hargaPerGram,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      isPriceModified: isPriceModified ?? this.isPriceModified,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      discountId: discountId ?? this.discountId,
      itemDiscount: itemDiscount ?? this.itemDiscount,
      cost: cost ?? this.cost,
      isReturned: isReturned ?? this.isReturned,
      returnedQuantity: returnedQuantity ?? this.returnedQuantity,
      returnReason: returnReason ?? this.returnReason,
      berat: berat ?? this.berat,
      hargaPerGram: hargaPerGram ?? this.hargaPerGram,
    );
  }
}

class AppliedDiscount {
  final int? id;
  final int transactionId;
  final int? discountId;
  final String discountName;
  final String discountType;
  final double discountValue;
  final double discountAmount;

  AppliedDiscount({
    this.id,
    required this.transactionId,
    this.discountId,
    required this.discountName,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
  });

  factory AppliedDiscount.fromMap(Map<String, dynamic> map) {
    return AppliedDiscount(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as int,
      discountId: map['discountId'] as int?,
      discountName: map['discountName'] as String,
      discountType: map['discountType'] as String,
      discountValue: (map['discountValue'] as num).toDouble(),
      discountAmount: (map['discountAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'discountId': discountId,
      'discountName': discountName,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
    };
  }
}
