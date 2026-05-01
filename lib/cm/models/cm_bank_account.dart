// lib/cm/models/cm_bank_account.dart
class CmBankAccount {
  final int? id;
  final String accountCode;
  final String accountNameTh;
  final String? accountNameEn;
  final int? bankId;
  final String? bankCode;
  final String? bankNameTh;
  final String? bankShortName;
  final String? accountNumber;
  final String accountType; // SAVING / CURRENT / FIXED
  final int? glAccountId;
  final String? glAccountCode;
  final String? glAccountName;
  final bool isActive;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  CmBankAccount({
    this.id,
    required this.accountCode,
    required this.accountNameTh,
    this.accountNameEn,
    this.bankId,
    this.bankCode,
    this.bankNameTh,
    this.bankShortName,
    this.accountNumber,
    required this.accountType,
    this.glAccountId,
    this.glAccountCode,
    this.glAccountName,
    required this.isActive,
    this.remark,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory CmBankAccount.fromJson(Map<String, dynamic> json) => CmBankAccount(
        id: json['id'],
        accountCode: json['account_code'] ?? '',
        accountNameTh: json['account_name_th'] ?? '',
        accountNameEn: json['account_name_en'],
        bankId: json['bank_id'],
        bankCode: json['bank_code'],
        bankNameTh: json['bank_name_th'],
        bankShortName: json['bank_short_name'],
        accountNumber: json['account_number'],
        accountType: json['account_type'] ?? 'SAVING',
        glAccountId: json['gl_account_id'],
        glAccountCode: json['gl_account_code'],
        glAccountName: json['gl_account_name'],
        isActive: json['is_active'] ?? true,
        remark: json['remark'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        createdBy: json['created_by']?.toString(),
        updatedBy: json['updated_by']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_code': accountCode,
        'account_name_th': accountNameTh,
        'account_name_en': accountNameEn,
        'bank_id': bankId,
        'account_number': accountNumber,
        'account_type': accountType,
        'gl_account_id': glAccountId,
        'is_active': isActive,
        'remark': remark,
      };

  String get bankDisplay {
    if (bankShortName != null && bankShortName!.isNotEmpty) return bankShortName!;
    if (bankNameTh != null && bankNameTh!.isNotEmpty) return bankNameTh!;
    return bankCode ?? '';
  }

  String get displayName => '$accountCode — $accountNameTh';
}

const Map<String, String> cmAccountTypeOptions = {
  'SAVING': 'ออมทรัพย์ (Saving)',
  'CURRENT': 'กระแสรายวัน (Current)',
  'FIXED': 'ฝากประจำ (Fixed)',
};
