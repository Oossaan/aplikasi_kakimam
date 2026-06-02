class Supplier {
  final int? id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactPerson: map['contactPerson'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isActive: (map['isActive'] as int?) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => name;
}

// Model for product-supplier relation
class ProductSupplier {
  final int? id;
  final int productId;
  final int supplierId;
  final double supplierPrice;
  final bool isPrimary;
  final DateTime? lastUpdated;

  // Optional joined fields
  final String? supplierName;

  ProductSupplier({
    this.id,
    required this.productId,
    required this.supplierId,
    this.supplierPrice = 0,
    this.isPrimary = false,
    this.lastUpdated,
    this.supplierName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'supplierId': supplierId,
      'supplierPrice': supplierPrice,
      'isPrimary': isPrimary ? 1 : 0,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory ProductSupplier.fromMap(Map<String, dynamic> map) {
    return ProductSupplier(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      supplierId: map['supplierId'] as int,
      supplierPrice: (map['supplierPrice'] as num?)?.toDouble() ?? 0,
      isPrimary: (map['isPrimary'] as int?) == 1,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'] as String)
          : null,
      supplierName: map['supplierName'] as String?,
    );
  }
}
