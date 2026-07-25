// lib/cm/models/cm_checkbook.dart

import '../../utils/date_utils.dart';

class CmCheckbook {
  final int? id;
  final int bankAccountId;
  final String? bankAccountCode;
  final String? bankAccountName;
  final String checkbookCode;
  final String startCheckNo;
  final String endCheckNo;
  final String? nextCheckNo;
  final DateTime? receivedDate;
  final String status; // Active | Used | Cancelled
  final String? note;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmCheckbook({
    this.id,
    required this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    required this.checkbookCode,
    required this.startCheckNo,
    required this.endCheckNo,
    this.nextCheckNo,
    this.receivedDate,
    this.status = 'Active',
    this.note,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory CmCheckbook.fromJson(Map<String, dynamic> j) => CmCheckbook(
    id:              j['id'],
    bankAccountId:   j['bank_account_id'] ?? 0,
    bankAccountCode: j['bank_account_code'],
    bankAccountName: j['bank_account_name'],
    checkbookCode:   j['checkbook_code'] ?? '',
    startCheckNo:    j['start_check_no'] ?? '',
    endCheckNo:      j['end_check_no'] ?? '',
    nextCheckNo:     j['next_check_no'],
    receivedDate:    parseLocalDateNullable(j['received_date']),
    status:    j['status'] ?? 'Active',
    note:      j['note'],
    createdBy: j['created_by'],
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'bank_account_id': bankAccountId,
    'checkbook_code':  checkbookCode,
    'start_check_no':  startCheckNo,
    'end_check_no':    endCheckNo,
    'next_check_no':   nextCheckNo,
    'received_date':   receivedDate != null ? formatLocalDate(receivedDate!) : null,
    'status':          status,
    'note':            note,
  };

  String get displayName => '$checkbookCode ($startCheckNo–$endCheckNo)';
}

const Map<String, String> cmCheckbookStatusOptions = {
  'Active':    'ใช้งาน',
  'Used':      'ใช้หมดแล้ว',
  'Cancelled': 'ยกเลิก',
};

// ── Print Config ──────────────────────────────────────────────────────────────

class CmCheckPrintConfig {
  final int? id;
  final int bankAccountId;
  final String? bankAccountCode;
  final String? bankAccountName;
  final String configName;
  final double paperWidthMm;
  final double paperHeightMm;
  final double? dateX;
  final double? dateY;
  final String dateFormat;
  final double? payeeX;
  final double? payeeY;
  final double? amountNumX;
  final double? amountNumY;
  final double? amountTextX;
  final double? amountTextY;
  final bool hasStub;
  final double? stubWidthMm;
  final bool isDefault;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmCheckPrintConfig({
    this.id,
    required this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    required this.configName,
    this.paperWidthMm = 210,
    this.paperHeightMm = 99,
    this.dateX,
    this.dateY,
    this.dateFormat = 'dd/MM/yyyy',
    this.payeeX,
    this.payeeY,
    this.amountNumX,
    this.amountNumY,
    this.amountTextX,
    this.amountTextY,
    this.hasStub = false,
    this.stubWidthMm,
    this.isDefault = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory CmCheckPrintConfig.fromJson(Map<String, dynamic> j) {
    double? _d(String k) => j[k] != null ? double.tryParse(j[k].toString()) : null;
    return CmCheckPrintConfig(
      id:              j['id'],
      bankAccountId:   j['bank_account_id'] ?? 0,
      bankAccountCode: j['bank_account_code'],
      bankAccountName: j['bank_account_name'],
      configName:      j['config_name'] ?? '',
      paperWidthMm:    double.tryParse(j['paper_width_mm']?.toString()  ?? '') ?? 210,
      paperHeightMm:   double.tryParse(j['paper_height_mm']?.toString() ?? '') ?? 99,
      dateX:       _d('date_x'),
      dateY:       _d('date_y'),
      dateFormat:  j['date_format'] ?? 'dd/MM/yyyy',
      payeeX:      _d('payee_x'),
      payeeY:      _d('payee_y'),
      amountNumX:  _d('amount_num_x'),
      amountNumY:  _d('amount_num_y'),
      amountTextX: _d('amount_text_x'),
      amountTextY: _d('amount_text_y'),
      hasStub:     j['has_stub'] ?? false,
      stubWidthMm: _d('stub_width_mm'),
      isDefault:   j['is_default'] ?? false,
      createdBy:   j['created_by'],
      createdAt:   j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      updatedAt:   j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'bank_account_id': bankAccountId,
    'config_name':     configName,
    'paper_width_mm':  paperWidthMm,
    'paper_height_mm': paperHeightMm,
    'date_x':          dateX,
    'date_y':          dateY,
    'date_format':     dateFormat,
    'payee_x':         payeeX,
    'payee_y':         payeeY,
    'amount_num_x':    amountNumX,
    'amount_num_y':    amountNumY,
    'amount_text_x':   amountTextX,
    'amount_text_y':   amountTextY,
    'has_stub':        hasStub,
    'stub_width_mm':   stubWidthMm,
    'is_default':      isDefault,
  };
}
