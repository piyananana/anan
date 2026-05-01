// lib/ar/models/ar_gl_account_setup.dart

class ArGlAccountSetup {
  final int?    id;
  final String  docCode;
  // จาก JOIN sa_module_document
  final String? sysDocType;
  final String? docNameThai;
  final bool?   docIsActive;

  // Invoice / DN / CN
  final int?    arAccountId;        final String? arAccountCode;        final String? arAccountName;
  final int?    revenueAccountId;   final String? revenueAccountCode;   final String? revenueAccountName;
  final int?    vatOutputAccountId; final String? vatOutputAccountCode; final String? vatOutputAccountName;
  final int?    discountAccountId;  final String? discountAccountCode;  final String? discountAccountName;

  // Advance (doc_type '60') + Receipt offset
  final int?    advanceAccountId;   final String? advanceAccountCode;   final String? advanceAccountName;

  // Receipt
  final int?    cashAccountId;      final String? cashAccountCode;      final String? cashAccountName;
  // per-payment-type accounts (รับชำระด้วยวิธีต่างๆ)
  final int?    checkAccountId;           final String? checkAccountCode;           final String? checkAccountName;
  final int?    transferAccountId;        final String? transferAccountCode;        final String? transferAccountName;
  final int?    creditCardAccountId;      final String? creditCardAccountCode;      final String? creditCardAccountName;
  final int?    debitCardAccountId;       final String? debitCardAccountCode;       final String? debitCardAccountName;
  final int?    qrCodeAccountId;          final String? qrCodeAccountCode;          final String? qrCodeAccountName;
  final int?    mobileBankingAccountId;   final String? mobileBankingAccountCode;   final String? mobileBankingAccountName;
  final int?    billOfExchangeAccountId;  final String? billOfExchangeAccountCode;  final String? billOfExchangeAccountName;
  final int?    whtAccountId;       final String? whtAccountCode;       final String? whtAccountName;
  final int?    fxGainAccountId;    final String? fxGainAccountCode;    final String? fxGainAccountName;
  final int?    fxLossAccountId;    final String? fxLossAccountCode;    final String? fxLossAccountName;

  // VAT รอตัด (Deferred VAT Output)
  final int?    vatPendingOutputAccountId; final String? vatPendingOutputAccountCode; final String? vatPendingOutputAccountName;

  // GL Document สำหรับ Post
  final int?    glDocId;            final String? glDocCode;            final String? glDocName;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String?   createdBy;
  final String?   updatedBy;

  const ArGlAccountSetup({
    this.id,
    required this.docCode,
    this.sysDocType,
    this.docNameThai,
    this.docIsActive,
    this.arAccountId,        this.arAccountCode,        this.arAccountName,
    this.revenueAccountId,   this.revenueAccountCode,   this.revenueAccountName,
    this.vatOutputAccountId, this.vatOutputAccountCode, this.vatOutputAccountName,
    this.discountAccountId,  this.discountAccountCode,  this.discountAccountName,
    this.advanceAccountId,   this.advanceAccountCode,   this.advanceAccountName,
    this.cashAccountId,      this.cashAccountCode,      this.cashAccountName,
    this.checkAccountId,          this.checkAccountCode,          this.checkAccountName,
    this.transferAccountId,       this.transferAccountCode,       this.transferAccountName,
    this.creditCardAccountId,     this.creditCardAccountCode,     this.creditCardAccountName,
    this.debitCardAccountId,      this.debitCardAccountCode,      this.debitCardAccountName,
    this.qrCodeAccountId,         this.qrCodeAccountCode,         this.qrCodeAccountName,
    this.mobileBankingAccountId,  this.mobileBankingAccountCode,  this.mobileBankingAccountName,
    this.billOfExchangeAccountId, this.billOfExchangeAccountCode, this.billOfExchangeAccountName,
    this.whtAccountId,       this.whtAccountCode,       this.whtAccountName,
    this.fxGainAccountId,    this.fxGainAccountCode,    this.fxGainAccountName,
    this.fxLossAccountId,    this.fxLossAccountCode,    this.fxLossAccountName,
    this.vatPendingOutputAccountId, this.vatPendingOutputAccountCode, this.vatPendingOutputAccountName,
    this.glDocId,            this.glDocCode,            this.glDocName,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ArGlAccountSetup.fromJson(Map<String, dynamic> j) {
    return ArGlAccountSetup(
      id:                  j['id'] as int?,
      docCode:             j['doc_code'] as String? ?? '',
      sysDocType:          j['sys_doc_type'] as String?,
      docNameThai:         j['doc_name_thai'] as String?,
      docIsActive:         j['doc_is_active'] as bool?,
      arAccountId:         j['ar_account_id'] as int?,        arAccountCode:        j['ar_account_code'] as String?,        arAccountName:        j['ar_account_name'] as String?,
      revenueAccountId:    j['revenue_account_id'] as int?,   revenueAccountCode:   j['revenue_account_code'] as String?,   revenueAccountName:   j['revenue_account_name'] as String?,
      vatOutputAccountId:  j['vat_output_account_id'] as int?,vatOutputAccountCode: j['vat_output_account_code'] as String?,vatOutputAccountName: j['vat_output_account_name'] as String?,
      discountAccountId:   j['discount_account_id'] as int?,  discountAccountCode:  j['discount_account_code'] as String?,  discountAccountName:  j['discount_account_name'] as String?,
      advanceAccountId:    j['advance_account_id'] as int?,   advanceAccountCode:   j['advance_account_code'] as String?,   advanceAccountName:   j['advance_account_name'] as String?,
      cashAccountId:       j['cash_account_id'] as int?,      cashAccountCode:      j['cash_account_code'] as String?,      cashAccountName:      j['cash_account_name'] as String?,
      checkAccountId:          j['check_account_id'] as int?,           checkAccountCode:          j['check_account_code'] as String?,           checkAccountName:          j['check_account_name'] as String?,
      transferAccountId:       j['transfer_account_id'] as int?,        transferAccountCode:       j['transfer_account_code'] as String?,        transferAccountName:       j['transfer_account_name'] as String?,
      creditCardAccountId:     j['credit_card_account_id'] as int?,     creditCardAccountCode:     j['credit_card_account_code'] as String?,     creditCardAccountName:     j['credit_card_account_name'] as String?,
      debitCardAccountId:      j['debit_card_account_id'] as int?,      debitCardAccountCode:      j['debit_card_account_code'] as String?,      debitCardAccountName:      j['debit_card_account_name'] as String?,
      qrCodeAccountId:         j['qr_code_account_id'] as int?,         qrCodeAccountCode:         j['qr_code_account_code'] as String?,         qrCodeAccountName:         j['qr_code_account_name'] as String?,
      mobileBankingAccountId:  j['mobile_banking_account_id'] as int?,  mobileBankingAccountCode:  j['mobile_banking_account_code'] as String?,  mobileBankingAccountName:  j['mobile_banking_account_name'] as String?,
      billOfExchangeAccountId: j['bill_of_exchange_account_id'] as int?, billOfExchangeAccountCode: j['bill_of_exchange_account_code'] as String?, billOfExchangeAccountName: j['bill_of_exchange_account_name'] as String?,
      whtAccountId:        j['wht_account_id'] as int?,       whtAccountCode:       j['wht_account_code'] as String?,       whtAccountName:       j['wht_account_name'] as String?,
      fxGainAccountId:     j['fx_gain_account_id'] as int?,   fxGainAccountCode:    j['fx_gain_account_code'] as String?,   fxGainAccountName:    j['fx_gain_account_name'] as String?,
      fxLossAccountId:     j['fx_loss_account_id'] as int?,   fxLossAccountCode:    j['fx_loss_account_code'] as String?,   fxLossAccountName:    j['fx_loss_account_name'] as String?,
      vatPendingOutputAccountId:   j['vat_pending_output_account_id'] as int?,   vatPendingOutputAccountCode: j['vat_pending_output_account_code'] as String?,   vatPendingOutputAccountName: j['vat_pending_output_account_name'] as String?,
      glDocId:             j['gl_doc_id'] as int?,            glDocCode:            j['gl_doc_code'] as String?,            glDocName:            j['gl_doc_name'] as String?,
      createdAt:           j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      updatedAt:           j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
      createdBy:           j['created_by']?.toString(),
      updatedBy:           j['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ar_account_id':         arAccountId,
    'revenue_account_id':    revenueAccountId,
    'vat_output_account_id': vatOutputAccountId,
    'discount_account_id':   discountAccountId,
    'advance_account_id':    advanceAccountId,
    'cash_account_id':       cashAccountId,
    'check_account_id':           checkAccountId,
    'transfer_account_id':        transferAccountId,
    'credit_card_account_id':     creditCardAccountId,
    'debit_card_account_id':      debitCardAccountId,
    'qr_code_account_id':         qrCodeAccountId,
    'mobile_banking_account_id':  mobileBankingAccountId,
    'bill_of_exchange_account_id': billOfExchangeAccountId,
    'wht_account_id':        whtAccountId,
    'fx_gain_account_id':              fxGainAccountId,
    'fx_loss_account_id':              fxLossAccountId,
    'vat_pending_output_account_id':   vatPendingOutputAccountId,
    'gl_doc_id':                       glDocId,
  };

  /// คืน true ถ้ามีการตั้งค่า GL อย่างน้อย 1 บัญชี
  bool get isConfigured => id != null;

  /// label ชื่อ sys_doc_type
  String get sysDocTypeName {
    switch (sysDocType) {
      case '10': return 'ตั้งยอดลูกหนี้ (BL)';
      case '30': return 'เพิ่มยอดลูกหนี้ (DN)';
      case '50': return 'ลดยอดลูกหนี้ (CN)';
      case '60': return 'รับมัดจำ (ADV)';
      case '70': return 'รับชำระ (RC)';
      default:   return sysDocType ?? '—';
    }
  }
}
