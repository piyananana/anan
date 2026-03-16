// models/ar_customer_group.dart
class ArCustomerGroup {
  final int? id;
  final String groupCode;
  final String groupNameThai;
  final String groupNameEng;
  final String? description;
  final int creditDays;
  final double creditLimit;
  final double discountPercent;
  final int? glAccountId;
  final String? glAccountCode;
  final String? glAccountNameThai;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  ArCustomerGroup({
    this.id,
    required this.groupCode,
    required this.groupNameThai,
    this.groupNameEng = '',
    this.description,
    this.creditDays = 30,
    this.creditLimit = 0,
    this.discountPercent = 0,
    this.glAccountId,
    this.glAccountCode,
    this.glAccountNameThai,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ArCustomerGroup.fromJson(Map<String, dynamic> json) {
    return ArCustomerGroup(
      id: json['id'],
      groupCode: json['group_code'] ?? '',
      groupNameThai: json['group_name_thai'] ?? '',
      groupNameEng: json['group_name_eng'] ?? '',
      description: json['description'],
      creditDays: json['credit_days'] ?? 30,
      creditLimit:
          double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0,
      discountPercent:
          double.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0,
      glAccountId: json['gl_account_id'],
      glAccountCode: json['gl_account_code']?.toString(),
      glAccountNameThai: json['gl_account_name_thai']?.toString(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_code': groupCode,
      'group_name_thai': groupNameThai,
      'group_name_eng': groupNameEng,
      'description': description,
      'credit_days': creditDays,
      'credit_limit': creditLimit,
      'discount_percent': discountPercent,
      'gl_account_id': glAccountId,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}
