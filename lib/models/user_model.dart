class UserModel {
  final int? id;
  final String name;
  final String role; // 'admin' | 'cashier'
  final String pinCode;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.role,
    required this.pinCode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role,
      'pin_code': pinCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      role: map['role'] as String,
      pinCode: map['pin_code'] as String,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
