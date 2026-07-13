// lib/gl/models/coa.dart

class GlAccountDimRule {
  final String typeCode;
  final bool isRequired;
  const GlAccountDimRule({required this.typeCode, required this.isRequired});

  factory GlAccountDimRule.fromJson(Map<String, dynamic> j) =>
      GlAccountDimRule(
        typeCode: j['type_code'] as String,
        isRequired: j['is_required'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'type_code': typeCode, 'is_required': isRequired};
}

// Enum เพื่อบอกสถานะของ Node ใน TreeView
enum AccountMode {
  addRoot,
  addChild,
  edit,
  view,
  none,
}

const Map<String, String> accountTypeOptions = {
  'ASSET': 'สินทรัพย์',
  'LIABILITY': 'หนี้สิน',
  'EQUITY': 'ส่วนของเจ้าของ',
  'REVENUE': 'รายได้',
  'EXPENSE': 'ค่าใช้จ่าย',
};

class Account {
  final int id;
  final String accountCode;
  final String accountNameThai;
  final String accountNameEng;
  final int? parentId; // สำหรับผังบัญชีแบบ Tree
  final String
      accountType; // เช่น 'ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'
  final String normalBalance; // 'DR' หรือ 'CR'
  final bool
      isNormalAccount; // TRUE: บัญชีที่ลงรายการได้, FALSE: บัญชีรวม/บัญชีแม่
  final bool
      isControlAccount; // TRUE: บันทึกได้เฉพาะจากโมดูลอื่น (AR/AP/Inventory) ห้ามลงตรงใน GL
  final String currencyCode; // สกุลเงินหลักของบัญชี (อ้างอิงจาก cd_currency)
  final bool branchRequired;
  final bool isActive;
  final List<GlAccountDimRule> dimRules;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int lockedByUserId;
  final String lockedByUserName;

  Account({
    required this.id,
    required this.accountCode,
    required this.accountNameThai,
    required this.accountNameEng,
    this.parentId,
    required this.accountType,
    required this.normalBalance,
    required this.isNormalAccount,
    this.isControlAccount = false,
    required this.currencyCode,
    required this.branchRequired,
    required this.isActive,
    this.dimRules = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.lockedByUserId = 0,
    this.lockedByUserName = '',
  });

  // สร้าง Account object จาก JSON (มาจาก Backend)
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      accountCode: json['account_code'] as String,
      accountNameThai: json['account_name_thai'] as String,
      accountNameEng: json['account_name_eng'] as String,
      parentId: json['parent_id'] as int?,
      accountType: json['account_type'] as String,
      normalBalance: json['normal_balance'] as String,
      isNormalAccount: json['is_normal_account'] as bool,
      isControlAccount: json['is_control_account'] as bool? ?? false,
      currencyCode: json['currency_code'] as String,
      branchRequired: json['branch_required'] as bool? ?? false,
      isActive: json['is_active'] as bool,
      dimRules: (json['dim_rules'] as List?)
              ?.map((r) => GlAccountDimRule.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      lockedByUserId: json['locked_by_user_id'] ?? 0,
      lockedByUserName: json['locked_by_user_name'] ?? '',
    );
  }

  // แปลง Account object เป็น JSON สำหรับส่งไปยัง Backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_code': accountCode,
      'account_name_thai': accountNameThai,
      'account_name_eng': accountNameEng,
      'parent_id': parentId,
      'account_type': accountType,
      'normal_balance': normalBalance,
      'is_normal_account': isNormalAccount,
      'is_control_account': isControlAccount,
      'currency_code': currencyCode,
      'branch_required': branchRequired,
      'is_active': isActive,
      'dim_rules': dimRules.map((r) => r.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'locked_by_user_id': lockedByUserId,
      'locked_by_user_name': lockedByUserName,
    };
  }
}
