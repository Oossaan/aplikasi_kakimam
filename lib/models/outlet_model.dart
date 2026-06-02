class Outlet {
  final int? id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;
  final double creditLimit;
  final double currentCredit;
  final DateTime createdAt;

  Outlet({
    this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isActive = true,
    this.creditLimit = 0,
    this.currentCredit = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed: remaining credit limit
  double get availableCredit => creditLimit - currentCredit;
  bool get hasCredit => creditLimit > 0;
  bool get canUseCredit => hasCredit && currentCredit < creditLimit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'isActive': isActive ? 1 : 0,
      'credit_limit': creditLimit,
      'current_credit': currentCredit,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Outlet.fromMap(Map<String, dynamic> map) {
    return Outlet(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isActive: (map['isActive'] as int?) == 1,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
      currentCredit: (map['current_credit'] as num?)?.toDouble() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Outlet copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    bool? isActive,
    double? creditLimit,
    double? currentCredit,
    DateTime? createdAt,
  }) {
    return Outlet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      creditLimit: creditLimit ?? this.creditLimit,
      currentCredit: currentCredit ?? this.currentCredit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
