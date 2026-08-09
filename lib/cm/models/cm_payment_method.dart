// lib/cm/models/cm_payment_method.dart
class CmPaymentMethod {
  final int? id;
  final String methodCode;
  final String methodNameTh;
  final String? methodNameEn;
  final String methodType; // CASH / CHECK / TRANSFER / BILL_OF_EXCHANGE
  final int? glAccountId;
  final String? glAccountCode;
  final String? glAccountName;
  final int? cmBankAccountId;
  final String? bankAccountCode;
  final String? bankAccountNameTh;
  final String? bankAccountNumber;
  final String? bankNameTh;
  final String? bankShortName;
  final bool isActive;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  CmPaymentMethod({
    this.id,
    required this.methodCode,
    required this.methodNameTh,
    this.methodNameEn,
    required this.methodType,
    this.glAccountId,
    this.glAccountCode,
    this.glAccountName,
    this.cmBankAccountId,
    this.bankAccountCode,
    this.bankAccountNameTh,
    this.bankAccountNumber,
    this.bankNameTh,
    this.bankShortName,
    required this.isActive,
    this.remark,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory CmPaymentMethod.fromJson(Map<String, dynamic> json) => CmPaymentMethod(
        id: json['id'],
        methodCode: json['method_code'] ?? '',
        methodNameTh: json['method_name_th'] ?? '',
        methodNameEn: json['method_name_en'],
        methodType: json['method_type'] ?? 'CASH',
        glAccountId: json['gl_account_id'],
        glAccountCode: json['gl_account_code'],
        glAccountName: json['gl_account_name'],
        cmBankAccountId: json['cm_bank_account_id'],
        bankAccountCode: json['bank_account_code'],
        bankAccountNameTh: json['bank_account_name_th'],
        bankAccountNumber: json['bank_account_number'],
        bankNameTh: json['bank_name_th'],
        bankShortName: json['bank_short_name'],
        isActive: json['is_active'] ?? true,
        remark: json['remark'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        createdBy: json['created_by']?.toString(),
        updatedBy: json['updated_by']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method_code': methodCode,
        'method_name_th': methodNameTh,
        'method_name_en': methodNameEn,
        'method_type': methodType,
        'gl_account_id': glAccountId,
        'cm_bank_account_id': cmBankAccountId,
        'is_active': isActive,
        'remark': remark,
      };

  String get displayName => '$methodCode — $methodNameTh';
}

const Map<String, String> cmMethodTypeOptions = {
  'CASH':            'เงินสด (Cash)',
  'CHECK':           'เช็ค (Check)',
  'TRANSFER':        'โอนเงิน (Transfer)',
  'CREDIT_CARD':     'บัตรเครดิต (Credit Card)',
  'DEBIT_CARD':      'บัตรเดบิต (Debit Card)',
  'QR_CODE':         'QR Code / พร้อมเพย์ (PromptPay)',
  'MOBILE_BANKING':  'Mobile Banking / อินเทอร์เน็ตแบงกิ้ง',
  'BILL_OF_EXCHANGE':'ตั๋วแลกเงิน (Bill of Exchange)',
  'OTHER':           'อื่นๆ (Other)',
};

const Map<String, String> cmMethodTypeOptionsEng = {
  'CASH':            'Cash',
  'CHECK':           'Check',
  'TRANSFER':        'Transfer',
  'CREDIT_CARD':     'Credit Card',
  'DEBIT_CARD':      'Debit Card',
  'QR_CODE':         'QR Code / PromptPay',
  'MOBILE_BANKING':  'Mobile Banking / Internet Banking',
  'BILL_OF_EXCHANGE':'Bill of Exchange',
  'OTHER':           'Other',
};

String cmMethodTypeLabel(String t, bool isEnglish) =>
    (isEnglish ? cmMethodTypeOptionsEng[t] : cmMethodTypeOptions[t]) ?? t;

// ประเภทที่ต้องการข้อมูล bank account (สำหรับ filter dropdown)
const Set<String> cmMethodTypesNeedBankAccount = {
  'CHECK', 'TRANSFER', 'BILL_OF_EXCHANGE',
};

// ประเภทบัตรเครดิต/เดบิต
const Map<String, String> cmCardNetworkOptions = {
  'VISA':       'Visa',
  'MASTERCARD': 'MasterCard',
  'AMEX':       'American Express (AMEX)',
  'JCB':        'JCB',
  'UNIONPAY':   'UnionPay',
  'OTHER':      'อื่นๆ',
};

const Map<String, String> cmMethodTypeIcons = {
  'CASH':            '💵',
  'CHECK':           '📄',
  'TRANSFER':        '🏦',
  'CREDIT_CARD':     '💳',
  'DEBIT_CARD':      '💳',
  'QR_CODE':         '📱',
  'MOBILE_BANKING':  '📱',
  'BILL_OF_EXCHANGE':'📋',
  'OTHER':           '💰',
};
