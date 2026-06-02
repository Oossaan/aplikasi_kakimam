class User {
  final int? id;
  final String username;
  final String password;
  final String name;
  final String role;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.name,
    this.role = 'cashier',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'name': name,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      name: map['name'],
      role: map['role'] ?? 'cashier',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
