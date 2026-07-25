// lib/cm/models/cm_petty_cash.dart

import '../../utils/date_utils.dart';

class CmPettyCashVoucher {
  final int id;
  final String voucherNo;
  final DateTime voucherDate;
  final int? pettyCashAccountId;
  final String? pettyCashAccountCode;
  final String? pettyCashAccountName;
  final String? payeeName;
  final String? description;
  final int? expenseGlAccountId;
  final String? expenseGlAccountCode;
  final String? expenseGlAccountName;
  final double amount;
  final String status;
  final int? replenishmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmPettyCashVoucher({
    required this.id,
    required this.voucherNo,
    required this.voucherDate,
    this.pettyCashAccountId,
    this.pettyCashAccountCode,
    this.pettyCashAccountName,
    this.payeeName,
    this.description,
    this.expenseGlAccountId,
    this.expenseGlAccountCode,
    this.expenseGlAccountName,
    required this.amount,
    required this.status,
    this.replenishmentId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft       => status == 'Draft';
  bool get isApproved    => status == 'Approved';
  bool get isReplenished => status == 'Replenished';
  bool get isVoided      => status == 'Voided';

  factory CmPettyCashVoucher.fromJson(Map<String, dynamic> j) => CmPettyCashVoucher(
    id:                    j['id'] as int,
    voucherNo:             j['voucher_no'] as String,
    voucherDate:           parseLocalDate(j['voucher_date']),
    pettyCashAccountId:    j['petty_cash_account_id'] as int?,
    pettyCashAccountCode:  j['petty_cash_account_code'] as String?,
    pettyCashAccountName:  j['petty_cash_account_name'] as String?,
    payeeName:             j['payee_name'] as String?,
    description:           j['description'] as String?,
    expenseGlAccountId:    j['expense_gl_account_id'] as int?,
    expenseGlAccountCode:  j['expense_gl_account_code'] as String?,
    expenseGlAccountName:  j['expense_gl_account_name'] as String?,
    amount:                double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
    status:                j['status'] as String? ?? 'Draft',
    replenishmentId:       j['replenishment_id'] as int?,
    createdAt:             j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt:             j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
  );
}

const Map<String, String> cmPcvStatusOptions = {
  'Draft':       'ร่าง',
  'Approved':    'อนุมัติ',
  'Replenished': 'เบิกจ่ายแล้ว',
  'Voided':      'ยกเลิก',
};

// ---------------------------------------------------------------------------

class CmPettyCashReplenishment {
  final int id;
  final String replenishmentNo;
  final DateTime replenishmentDate;
  final int? pettyCashAccountId;
  final String? pettyCashAccountCode;
  final String? pettyCashAccountName;
  final int? sourceBankAccountId;
  final String? sourceBankAccountCode;
  final String? sourceBankAccountName;
  final String? sourceBankShortName;
  final double totalAmount;
  final String? description;
  final String status;
  final int? glEntryId;
  final int? glDocId;
  final String? glDocNo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmPettyCashReplenishment({
    required this.id,
    required this.replenishmentNo,
    required this.replenishmentDate,
    this.pettyCashAccountId,
    this.pettyCashAccountCode,
    this.pettyCashAccountName,
    this.sourceBankAccountId,
    this.sourceBankAccountCode,
    this.sourceBankAccountName,
    this.sourceBankShortName,
    required this.totalAmount,
    this.description,
    required this.status,
    this.glEntryId,
    this.glDocId,
    this.glDocNo,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft  => status == 'Draft';
  bool get isPosted => status == 'Posted';
  bool get isVoided => status == 'Voided';

  Map<String, dynamic> toCreateJson() => {
    'replenishment_date':     formatLocalDate(replenishmentDate),
    'petty_cash_account_id':  pettyCashAccountId,
    'source_bank_account_id': sourceBankAccountId,
    'total_amount':            totalAmount,
    'description':             description,
    'gl_doc_id':               glDocId,
  };

  Map<String, dynamic> toUpdateJson() => {
    'replenishment_date':     formatLocalDate(replenishmentDate),
    'source_bank_account_id': sourceBankAccountId,
    'total_amount':            totalAmount,
    'description':             description,
    'gl_doc_id':               glDocId,
  };

  factory CmPettyCashReplenishment.fromJson(Map<String, dynamic> j) =>
      CmPettyCashReplenishment(
    id:                   j['id'] as int,
    replenishmentNo:      j['replenishment_no'] as String,
    replenishmentDate:    parseLocalDate(j['replenishment_date']),
    pettyCashAccountId:   j['petty_cash_account_id'] as int?,
    pettyCashAccountCode: j['petty_cash_account_code'] as String?,
    pettyCashAccountName: j['petty_cash_account_name'] as String?,
    sourceBankAccountId:  j['source_bank_account_id'] as int?,
    sourceBankAccountCode: j['source_bank_account_code'] as String?,
    sourceBankAccountName: j['source_bank_account_name'] as String?,
    sourceBankShortName:  j['source_bank_short_name'] as String?,
    totalAmount:          double.tryParse(j['total_amount']?.toString() ?? '0') ?? 0,
    description:          j['description'] as String?,
    status:               j['status'] as String? ?? 'Draft',
    glEntryId:            j['gl_entry_id'] as int?,
    glDocId:              j['gl_doc_id'] as int?,
    glDocNo:              j['gl_doc_no'] as String?,
    createdAt:            j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt:            j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
  );
}

const Map<String, String> cmRplStatusOptions = {
  'Draft':  'ร่าง',
  'Posted': 'บันทึก GL แล้ว',
  'Voided': 'ยกเลิก',
};
