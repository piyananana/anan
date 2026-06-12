class ApGlAccountSetup {
  final int?    id;
  final String  docCode;
  final String? sysDocType;
  final String? docNameThai;
  final bool?   docIsActive;

  // PI / CN / DN
  final int?    apAccountId;          final String? apAccountCode;          final String? apAccountName;
  final int?    expenseAccountId;     final String? expenseAccountCode;     final String? expenseAccountName;
  final int?    vatInputAccountId;    final String? vatInputAccountCode;    final String? vatInputAccountName;
  final int?    discountAccountId;    final String? discountAccountCode;    final String? discountAccountName;

  // Advance Payment
  final int?    advanceAccountId;     final String? advanceAccountCode;     final String? advanceAccountName;

  // WHT Payable
  final int?    whtPayableAccountId;  final String? whtPayableAccountCode;  final String? whtPayableAccountName;

  // Payment (cash / check / transfer / ...)
  final int?    cashAccountId;        final String? cashAccountCode;        final String? cashAccountName;
  final int?    checkAccountId;       final String? checkAccountCode;       final String? checkAccountName;
  final int?    transferAccountId;    final String? transferAccountCode;    final String? transferAccountName;

  // FX Gain / Loss
  final int?    fxGainAccountId;      final String? fxGainAccountCode;      final String? fxGainAccountName;
  final int?    fxLossAccountId;      final String? fxLossAccountCode;      final String? fxLossAccountName;

  // Deferred VAT Input (VAT รอตัดบัญชี)
  final int?    vatPendingInputAccountId; final String? vatPendingInputAccountCode; final String? vatPendingInputAccountName;

  // GL Document for posting
  final int?    glDocId;              final String? glDocCode;              final String? glDocName;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String?   createdBy;
  final String?   updatedBy;

  const ApGlAccountSetup({
    this.id,
    required this.docCode,
    this.sysDocType,
    this.docNameThai,
    this.docIsActive,
    this.apAccountId,          this.apAccountCode,          this.apAccountName,
    this.expenseAccountId,     this.expenseAccountCode,     this.expenseAccountName,
    this.vatInputAccountId,    this.vatInputAccountCode,    this.vatInputAccountName,
    this.discountAccountId,    this.discountAccountCode,    this.discountAccountName,
    this.advanceAccountId,     this.advanceAccountCode,     this.advanceAccountName,
    this.whtPayableAccountId,  this.whtPayableAccountCode,  this.whtPayableAccountName,
    this.cashAccountId,        this.cashAccountCode,        this.cashAccountName,
    this.checkAccountId,       this.checkAccountCode,       this.checkAccountName,
    this.transferAccountId,    this.transferAccountCode,    this.transferAccountName,
    this.fxGainAccountId,      this.fxGainAccountCode,      this.fxGainAccountName,
    this.fxLossAccountId,      this.fxLossAccountCode,      this.fxLossAccountName,
    this.vatPendingInputAccountId, this.vatPendingInputAccountCode, this.vatPendingInputAccountName,
    this.glDocId,              this.glDocCode,              this.glDocName,
    this.createdAt, this.updatedAt, this.createdBy, this.updatedBy,
  });

  factory ApGlAccountSetup.fromJson(Map<String, dynamic> j) => ApGlAccountSetup(
    id:                j['id'] as int?,
    docCode:           j['doc_code'] as String? ?? '',
    sysDocType:        j['sys_doc_type'] as String?,
    docNameThai:       j['doc_name_thai'] as String?,
    docIsActive:       j['doc_is_active'] as bool?,
    apAccountId:          j['ap_account_id'] as int?,         apAccountCode:         j['ap_account_code'] as String?,         apAccountName:         j['ap_account_name'] as String?,
    expenseAccountId:     j['expense_account_id'] as int?,    expenseAccountCode:    j['expense_account_code'] as String?,    expenseAccountName:    j['expense_account_name'] as String?,
    vatInputAccountId:    j['vat_input_account_id'] as int?,  vatInputAccountCode:   j['vat_input_account_code'] as String?,  vatInputAccountName:   j['vat_input_account_name'] as String?,
    discountAccountId:    j['discount_account_id'] as int?,   discountAccountCode:   j['discount_account_code'] as String?,   discountAccountName:   j['discount_account_name'] as String?,
    advanceAccountId:     j['advance_account_id'] as int?,    advanceAccountCode:    j['advance_account_code'] as String?,    advanceAccountName:    j['advance_account_name'] as String?,
    whtPayableAccountId:  j['wht_payable_account_id'] as int?,whtPayableAccountCode: j['wht_payable_account_code'] as String?,whtPayableAccountName: j['wht_payable_account_name'] as String?,
    cashAccountId:        j['cash_account_id'] as int?,       cashAccountCode:       j['cash_account_code'] as String?,       cashAccountName:       j['cash_account_name'] as String?,
    checkAccountId:       j['check_account_id'] as int?,      checkAccountCode:      j['check_account_code'] as String?,      checkAccountName:      j['check_account_name'] as String?,
    transferAccountId:    j['transfer_account_id'] as int?,   transferAccountCode:   j['transfer_account_code'] as String?,   transferAccountName:   j['transfer_account_name'] as String?,
    fxGainAccountId:      j['fx_gain_account_id'] as int?,    fxGainAccountCode:     j['fx_gain_account_code'] as String?,    fxGainAccountName:     j['fx_gain_account_name'] as String?,
    fxLossAccountId:      j['fx_loss_account_id'] as int?,    fxLossAccountCode:     j['fx_loss_account_code'] as String?,    fxLossAccountName:     j['fx_loss_account_name'] as String?,
    vatPendingInputAccountId:  j['vat_pending_input_account_id'] as int?,  vatPendingInputAccountCode: j['vat_pending_input_account_code'] as String?,  vatPendingInputAccountName: j['vat_pending_input_account_name'] as String?,
    glDocId:              j['gl_doc_id'] as int?,              glDocCode:             j['gl_doc_code'] as String?,             glDocName:             j['gl_doc_name'] as String?,
    createdAt:            j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
    updatedAt:            j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
    createdBy:            j['created_by']?.toString(),
    updatedBy:            j['updated_by']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'ap_account_id':               apAccountId,
    'expense_account_id':          expenseAccountId,
    'vat_input_account_id':        vatInputAccountId,
    'discount_account_id':         discountAccountId,
    'advance_account_id':          advanceAccountId,
    'wht_payable_account_id':      whtPayableAccountId,
    'cash_account_id':             cashAccountId,
    'check_account_id':            checkAccountId,
    'transfer_account_id':         transferAccountId,
    'fx_gain_account_id':          fxGainAccountId,
    'fx_loss_account_id':          fxLossAccountId,
    'vat_pending_input_account_id': vatPendingInputAccountId,
    'gl_doc_id':                   glDocId,
  };

  bool get isConfigured => id != null;
}
