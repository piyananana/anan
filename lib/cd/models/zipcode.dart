// enum Mode {
//   none,
//   add,
//   edit,
//   view,
// }

// Models
class Zipcode {
  final int? id;
  final String subDistrict;
  final String district;
  final String province;
  final String zipcode;
  final bool isLocked;
  final int? lockedByUserId;
  final String? createdByUserId;
  final String? updatedByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String lockedByUserName;

  Zipcode({
    this.id,
    required this.subDistrict,
    required this.district,
    required this.province,
    required this.zipcode,
    this.isLocked = false,
    this.lockedByUserId,
    this.createdByUserId,
    this.updatedByUserId,
    this.createdAt,
    this.updatedAt,
    this.lockedByUserName = '',
  });

  factory Zipcode.fromJson(Map<String, dynamic> json) {
    return Zipcode(
      id: json['id'],
      subDistrict: json['sub_district'],
      district: json['district'],
      province: json['province'],
      zipcode: json['zipcode'],
      isLocked: json['is_locked'] ?? false,
      lockedByUserId: json['locked_by_user_id'],
      createdByUserId: json['created_by_user_id'],
      updatedByUserId: json['updated_by_user_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      lockedByUserName: json['locked_by_user_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_district': subDistrict,
      'district': district,
      'province': province,
      'zipcode': zipcode,
      'is_locked': isLocked,
      'locked_by_user_id': lockedByUserId,
      'created_by_user_id': createdByUserId,
      'updated_by_user_id': updatedByUserId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'locked_by_user_name': lockedByUserName,
    };
  }
}

