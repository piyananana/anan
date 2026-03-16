// models/business_type.dart
class BusinessType {
  final int? id;
  final String businessTypeCode;
  final String businessTypeNameThai;
  final String businessTypeNameEng;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  BusinessType({
    this.id,
    required this.businessTypeCode,
    required this.businessTypeNameThai,
    required this.businessTypeNameEng,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory BusinessType.fromJson(Map<String, dynamic> json) {
    return BusinessType(
      id: json['id'],
      businessTypeCode: json['business_type_code'],
      businessTypeNameThai: json['business_type_name_thai'],
      businessTypeNameEng: json['business_type_name_eng'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_type_code': businessTypeCode,
      'business_type_name_thai': businessTypeNameThai,
      'business_type_name_eng': businessTypeNameEng,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}
