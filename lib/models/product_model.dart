class Product {
  final int? id;
  final String barcode;
  final String name;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final int? categoryId;
  final int? supplierId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Gold shop specific fields
  final double? berat; // Berat dalam gram (untuk toko emas)
  final double? hargaPerGram; // Harga per gram (untuk toko emas)

  // Optional: for joined data display
  final String? categoryName;
  final String? supplierName;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    this.stock = 0,
    this.minStock = 10,
    this.categoryId,
    this.supplierId,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.berat,
    this.hargaPerGram,
    this.categoryName,
    this.supplierName,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category': category,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'stock': stock,
      'minStock': minStock,
      'categoryId': categoryId,
      'supplierId': supplierId,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'berat': berat,
      'hargaPerGram': hargaPerGram,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String? ?? '',
      name: map['name'] as String,
      category: map['category'] as String,
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      stock: map['stock'] as int? ?? 0,
      minStock: map['minStock'] as int? ?? 10,
      categoryId: map['categoryId'] as int?,
      supplierId: map['supplierId'] as int?,
      isActive: (map['isActive'] as int?) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      berat: (map['berat'] as num?)?.toDouble(),
      hargaPerGram: (map['hargaPerGram'] as num?)?.toDouble(),
      categoryName: map['categoryName'] as String?,
      supplierName: map['supplierName'] as String?,
    );
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    int? stock,
    int? minStock,
    int? categoryId,
    int? supplierId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? berat,
    double? hargaPerGram,
    String? categoryName,
    String? supplierName,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      berat: berat ?? this.berat,
      hargaPerGram: hargaPerGram ?? this.hargaPerGram,
      categoryName: categoryName ?? this.categoryName,
      supplierName: supplierName ?? this.supplierName,
    );
  }

  bool get isLowStock => stock <= minStock;
  bool get isOutOfStock => stock <= 0;

  @override
  String toString() => name;
}
