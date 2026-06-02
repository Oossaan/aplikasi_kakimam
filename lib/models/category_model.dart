class Category {
  final int? id;
  final String name;
  final String description;
  final String color;
  final String icon;
  final int? parentId;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional: for tree display
  final List<Category>? children;
  final int? productCount;

  Category({
    this.id,
    required this.name,
    this.description = '',
    this.color = '#2196F3',
    this.icon = 'folder',
    this.parentId,
    this.sortOrder = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.children,
    this.productCount,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'parentId': parentId,
      'sortOrder': sortOrder,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      color: map['color'] as String? ?? '#2196F3',
      icon: map['icon'] as String? ?? 'folder',
      parentId: map['parentId'] as int?,
      sortOrder: map['sortOrder'] as int? ?? 0,
      isActive: (map['isActive'] as int?) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      productCount: map['productCount'] as int?,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    String? icon,
    int? parentId,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Category>? children,
    int? productCount,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      children: children ?? this.children,
      productCount: productCount ?? this.productCount,
    );
  }

  bool get hasChildren => children != null && children!.isNotEmpty;
  bool get isParent => parentId == null;

  @override
  String toString() => name;
}
