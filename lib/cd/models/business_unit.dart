// lib/cd/models/business_unit.dart

const Map<String, String> branchOptions = {
  'B00': 'สำนักงานใหญ่',
  'B01': 'สาขา 1',
  'B02': 'สาขา 2',
  'B03': 'สาขา 3',
  'B04': 'สาขา 4',
};

class BusinessUnit {
  final int id;
  final String buCode;
  final String buNameThai;
  final String buNameEng;
  final int? parentId; // สำหรับผังองค์กรแบบ Tree
  final bool
      isControlBU; // TRUE: ที่ใช้ลงรายการได้, FALSE: บัญชีรวม/บัญชีแม่
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int lockedByUserId;
  final String lockedByUserName;

  BusinessUnit({
    required this.id,
    required this.buCode,
    required this.buNameThai,
    required this.buNameEng,
    this.parentId,
    required this.isControlBU,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.lockedByUserId = 0,
    this.lockedByUserName = '',
  });

  // สร้าง BusinessUnit object จาก JSON (มาจาก Backend)
  factory BusinessUnit.fromJson(Map<String, dynamic> json) {
    return BusinessUnit(
      id: json['id'] as int,
      buCode: json['bu_code'] as String,
      buNameThai: json['bu_name_thai'] as String,
      buNameEng: json['bu_name_eng'] as String,
      parentId: json['parent_id'] as int?,
      isControlBU: json['is_control_bu'] as bool,
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      lockedByUserId: json['locked_by_user_id'] ?? '',
      lockedByUserName: json['locked_by_user_name'] ?? '',
    );
  }

  // แปลง BusinessUnit object เป็น JSON สำหรับส่งไปยัง Backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bu_code': buCode,
      'bu_name_thai': buNameThai,
      'bu_name_eng': buNameEng,
      'parent_id': parentId,
      'is_control_bu': isControlBU,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'locked_by_user_id': lockedByUserId,
      'locked_by_user_name': lockedByUserName,
    };
  }
}
