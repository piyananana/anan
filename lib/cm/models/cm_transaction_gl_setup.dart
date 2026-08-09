// lib/cm/models/cm_transaction_gl_setup.dart
class CmTransactionGlSetup {
  final int?    id;
  final String  docCode;
  final String? sysDocType;
  final String? docNameThai;
  final String? docNameEng;
  final bool?   docIsActive;

  // รายรับ (10)
  final int? revenueAccountId; final String? revenueAccountCode; final String? revenueAccountName;
  // รายจ่าย (20) / ค่าธรรมเนียมธนาคาร-ดอกเบี้ยจ่าย (70/90)
  final int? expenseAccountId; final String? expenseAccountCode; final String? expenseAccountName;
  // เติมเงินสดย่อย (30) / เบิกเงินสดย่อย (40) — บัญชีพักเบิกเงินสดย่อย
  final int? pettyCashPayableAccountId; final String? pettyCashPayableAccountCode; final String? pettyCashPayableAccountName;
  // FX Gain / Loss
  final int? fxGainAccountId; final String? fxGainAccountCode; final String? fxGainAccountName;
  final int? fxLossAccountId; final String? fxLossAccountCode; final String? fxLossAccountName;

  // GL Document for posting
  final int? glDocId; final String? glDocCode; final String? glDocName;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String?   createdBy;
  final String?   updatedBy;

  const CmTransactionGlSetup({
    this.id,
    required this.docCode,
    this.sysDocType,
    this.docNameThai,
    this.docNameEng,
    this.docIsActive,
    this.revenueAccountId, this.revenueAccountCode, this.revenueAccountName,
    this.expenseAccountId, this.expenseAccountCode, this.expenseAccountName,
    this.pettyCashPayableAccountId, this.pettyCashPayableAccountCode, this.pettyCashPayableAccountName,
    this.fxGainAccountId, this.fxGainAccountCode, this.fxGainAccountName,
    this.fxLossAccountId, this.fxLossAccountCode, this.fxLossAccountName,
    this.glDocId, this.glDocCode, this.glDocName,
    this.createdAt, this.updatedAt, this.createdBy, this.updatedBy,
  });

  factory CmTransactionGlSetup.fromJson(Map<String, dynamic> j) => CmTransactionGlSetup(
    id:          j['id'] as int?,
    docCode:     j['doc_code'] as String? ?? '',
    sysDocType:  j['sys_doc_type'] as String?,
    docNameThai: j['doc_name_thai'] as String?,
    docNameEng:  j['doc_name_eng'] as String?,
    docIsActive: j['doc_is_active'] as bool?,
    revenueAccountId: j['revenue_account_id'] as int?, revenueAccountCode: j['revenue_account_code'] as String?, revenueAccountName: j['revenue_account_name'] as String?,
    expenseAccountId: j['expense_account_id'] as int?, expenseAccountCode: j['expense_account_code'] as String?, expenseAccountName: j['expense_account_name'] as String?,
    pettyCashPayableAccountId: j['petty_cash_payable_account_id'] as int?,
    pettyCashPayableAccountCode: j['petty_cash_payable_account_code'] as String?,
    pettyCashPayableAccountName: j['petty_cash_payable_account_name'] as String?,
    fxGainAccountId: j['fx_gain_account_id'] as int?, fxGainAccountCode: j['fx_gain_account_code'] as String?, fxGainAccountName: j['fx_gain_account_name'] as String?,
    fxLossAccountId: j['fx_loss_account_id'] as int?, fxLossAccountCode: j['fx_loss_account_code'] as String?, fxLossAccountName: j['fx_loss_account_name'] as String?,
    glDocId: j['gl_doc_id'] as int?, glDocCode: j['gl_doc_code'] as String?, glDocName: j['gl_doc_name'] as String?,
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
    updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
    createdBy: j['created_by']?.toString(),
    updatedBy: j['updated_by']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'revenue_account_id':            revenueAccountId,
    'expense_account_id':            expenseAccountId,
    'petty_cash_payable_account_id': pettyCashPayableAccountId,
    'fx_gain_account_id':            fxGainAccountId,
    'fx_loss_account_id':            fxLossAccountId,
    'gl_doc_id':                     glDocId,
  };

  bool get isConfigured => id != null;
}
