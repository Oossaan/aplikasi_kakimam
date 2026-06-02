class Sales {
  final int? id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;
  final DateTime createdAt;

  Sales({
    this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Sales.fromMap(Map<String, dynamic> map) {
    return Sales(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isActive: (map['isActive'] as int?) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Sales copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Sales(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
