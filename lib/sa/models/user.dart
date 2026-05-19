// models/user.dart
class User {
  final int id;
  final String userName;
  final String? password;
  final String? firstName;
  final String? lastName;
  final String userType;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? email;
  bool isMember;

  bool get isDeveloper => userType == 'developer';
  bool get isAdmin => userType == 'administrator' || userType == 'developer';

  static int typeRank(String type) {
    switch (type) {
      case 'developer': return 4;
      case 'administrator': return 3;
      case 'user': return 2;
      case 'guest': return 1;
      default: return 0;
    }
  }

  // คืน list ประเภทผู้ใช้ที่ currentType สามารถมองเห็น/จัดการได้ (ตัวเองและต่ำกว่า)
  static List<String> allowedTypesFor(String currentType) {
    final rank = typeRank(currentType);
    return ['developer', 'administrator', 'user', 'guest']
        .where((t) => typeRank(t) <= rank)
        .toList();
  }

  User({
    required this.id,
    required this.userName,
    this.password,
    required this.firstName,
    required this.lastName,
    this.userType = 'User',
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.email,
    this.isMember = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      userName: json['user_name'],
      password: json['password'],
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
      userType: json['user_type'] ?? json['userType'],
      status: json['status'] ?? json['status'] ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      email: json['email'],
      isMember: json['is_member'] ?? false,
    );
  }

  // Add this method for storing in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'user_type': userType,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'email': email,
      'is_member': isMember,
    };
  }

  User copyWith({
    int? id,
    String? userName,
    String? password,
    String? firstName,
    String? lastName,
    String? userType, // <-- เพิ่ม userType ใน copyWith
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? email,
  }) {
    return User(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      userType: userType ?? this.userType, // <-- ใช้ค่าใหม่หรือค่าเดิม
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: email ?? this.email,
    );
  }
}
