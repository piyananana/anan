// lib/cm/models/cm_transaction.dart
import '../../utils/date_utils.dart';

// CM document types (sys_doc_type in sa_module_document, sys_module='81')
const int cmDocTypeReceipt                = 10; // รายรับ (โดยตรง ไม่ผูกกับ AR)
const int cmDocTypeReceiptFromAr          = 15; // รายรับจาก AR — read-only, มาจาก cm_receipt
const int cmDocTypePayment                = 20; // รายจ่าย (โดยตรง ไม่ผูกกับ AP)
const int cmDocTypePaymentFromAp          = 25; // รายจ่ายจาก AP — read-only, มาจาก cm_payment
const int cmDocTypePettyCashReplenishment = 30; // เติมเงินสดย่อย (apply กับใบเบิก 40 ที่ Post แล้ว)
const int cmDocTypePettyCashVoucher       = 40; // เบิกเงินสดย่อย (มีรายการค่าใช้จ่าย ต้อง Post ก่อนเบิกคืนได้)
const int cmDocTypeInterBankTransfer      = 50; // โอนเงินระหว่างบัญชี
const int cmDocTypeBankCharge             = 70; // ค่าธรรมเนียมธนาคาร
const int cmDocTypeInterest               = 90; // ดอกเบี้ย (charge_type แยกรับ/จ่าย)

const Map<int, String> cmDocTypeNames = {
  cmDocTypeReceipt:                'รายรับ',
  cmDocTypeReceiptFromAr:          'รายรับจาก AR',
  cmDocTypePayment:                'รายจ่าย',
  cmDocTypePaymentFromAp:          'รายจ่ายจาก AP',
  cmDocTypePettyCashReplenishment: 'เติมเงินสดย่อย',
  cmDocTypePettyCashVoucher:       'เบิกเงินสดย่อย',
  cmDocTypeInterBankTransfer:      'โอนเงินระหว่างบัญชี',
  cmDocTypeBankCharge:             'ค่าธรรมเนียมธนาคาร',
  cmDocTypeInterest:               'ดอกเบี้ย',
};

// ประเภทเอกสารที่เป็น read-only (สร้างจาก AR/AP เท่านั้น ไม่มีปุ่มสร้าง/แก้ไขในหน้าจอนี้)
const Set<int> cmReadOnlyDocTypes = {cmDocTypeReceiptFromAr, cmDocTypePaymentFromAp};

const Map<String, String> cmChargeTypeLabels = {
  'BANK_CHARGE':      'ค่าธรรมเนียมธนาคาร',
  'INTEREST_INCOME':  'ดอกเบี้ยรับ',
  'INTEREST_EXPENSE': 'ดอกเบี้ยจ่าย',
};

const Map<String, String> cmTransactionStatusLabels = {
  'Draft':  'ร่าง',
  'Posted': 'Post แล้ว',
  'Void':   'ยกเลิก',
};
const Map<String, String> cmTransactionStatusLabelsEn = {
  'Draft':  'Draft',
  'Posted': 'Posted',
  'Void':   'Void',
};
String cmTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? cmTransactionStatusLabelsEn[s] : cmTransactionStatusLabels[s]) ?? s;

// ── Header ─────────────────────────────────────────────────────────────────
class CmTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int periodId;
  // Doc-type-conditional account fields
  final int? fromBankAccountId;
  final String? fromBankName;
  final String? fromAccountNumber;
  final int? toBankAccountId;
  final String? toBankName;
  final String? toAccountNumber;
  final int? bankAccountId;
  final String? bankName;
  final String? bankAccountNumber;
  final int? glAccountId;
  final String? chargeType; // BANK_CHARGE / INTEREST_INCOME / INTEREST_EXPENSE (doc type 70/90)
  final String? counterpartyName; // doc type 10/20
  final int? currencyId;
  final String currencyCode;
  final double exchangeRate;
  final double totalAmountFc;
  final double totalAmountLc;
  final double paidAmountLc;
  final double balanceAmountLc;
  final String? refNo;
  final int? refDocId;
  final String? refDocNo;
  final String? description;
  final String status;
  final int? glEntryId;
  // From join
  final String? docCode;
  final String? docNameThai;
  final String? docNameEng;
  final int? sysDocType;
  final bool? isAutoNumbering;
  // GL Dimensions
  final int? dim1Id; final String? dim1Name;
  final int? dim2Id; final String? dim2Name;
  final int? dim3Id; final String? dim3Name;
  final int? dim4Id; final String? dim4Name;
  final int? dim5Id; final String? dim5Name;
  final int? branchId;
  final String? branchCode;
  final String? branchNameThai;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const CmTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.periodId = 0,
    this.fromBankAccountId, this.fromBankName, this.fromAccountNumber,
    this.toBankAccountId, this.toBankName, this.toAccountNumber,
    this.bankAccountId, this.bankName, this.bankAccountNumber,
    this.glAccountId,
    this.chargeType,
    this.counterpartyName,
    this.currencyId,
    this.currencyCode = 'THB',
    this.exchangeRate = 1.0,
    this.totalAmountFc = 0,
    this.totalAmountLc = 0,
    this.paidAmountLc = 0,
    this.balanceAmountLc = 0,
    this.refNo,
    this.refDocId,
    this.refDocNo,
    this.description,
    this.status = 'Draft',
    this.glEntryId,
    this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.sysDocType,
    this.isAutoNumbering,
    this.dim1Id, this.dim1Name,
    this.dim2Id, this.dim2Name,
    this.dim3Id, this.dim3Name,
    this.dim4Id, this.dim4Name,
    this.dim5Id, this.dim5Name,
    this.branchId, this.branchCode, this.branchNameThai,
    this.createdAt, this.updatedAt, this.createdBy, this.updatedBy,
  });

  factory CmTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return CmTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      periodId: json['period_id'] ?? 0,
      fromBankAccountId: json['from_bank_account_id'],
      fromBankName: json['from_bank_name'],
      fromAccountNumber: json['from_account_number'],
      toBankAccountId: json['to_bank_account_id'],
      toBankName: json['to_bank_name'],
      toAccountNumber: json['to_account_number'],
      bankAccountId: json['bank_account_id'],
      bankName: json['bank_name'],
      bankAccountNumber: json['bank_account_number'],
      glAccountId: json['gl_account_id'],
      chargeType: json['charge_type'],
      counterpartyName: json['counterparty_name'],
      currencyId: json['currency_id'],
      currencyCode: json['currency_code'] ?? 'THB',
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      totalAmountFc: toDouble(json['total_amount_fc']),
      totalAmountLc: toDouble(json['total_amount_lc']),
      paidAmountLc: toDouble(json['paid_amount_lc']),
      balanceAmountLc: toDouble(json['balance_amount_lc']),
      refNo: json['ref_no'],
      refDocId: json['ref_doc_id'],
      refDocNo: json['ref_doc_no'],
      description: json['description'],
      status: json['status'] ?? 'Draft',
      glEntryId: json['gl_entry_id'],
      docCode: json['doc_code'],
      docNameThai: json['doc_name_thai'],
      docNameEng: json['doc_name_eng'],
      sysDocType: json['sys_doc_type'] != null ? int.tryParse(json['sys_doc_type'].toString()) : null,
      isAutoNumbering: json['is_auto_numbering'],
      dim1Id: json['dim1_id'], dim1Name: json['dim1_name'],
      dim2Id: json['dim2_id'], dim2Name: json['dim2_name'],
      dim3Id: json['dim3_id'], dim3Name: json['dim3_name'],
      dim4Id: json['dim4_id'], dim4Name: json['dim4_name'],
      dim5Id: json['dim5_id'], dim5Name: json['dim5_name'],
      branchId: json['branch_id'],
      branchCode: json['branch_code'],
      branchNameThai: json['branch_name_thai'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        if (fromBankAccountId != null) 'from_bank_account_id': fromBankAccountId,
        if (toBankAccountId != null) 'to_bank_account_id': toBankAccountId,
        if (bankAccountId != null) 'bank_account_id': bankAccountId,
        if (glAccountId != null) 'gl_account_id': glAccountId,
        if (chargeType != null) 'charge_type': chargeType,
        if (counterpartyName != null) 'counterparty_name': counterpartyName,
        if (currencyId != null) 'currency_id': currencyId,
        'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        'total_amount_fc': totalAmountFc,
        'total_amount_lc': totalAmountLc,
        if (refNo != null) 'ref_no': refNo,
        if (refDocId != null) 'ref_doc_id': refDocId,
        if (refDocNo != null) 'ref_doc_no': refDocNo,
        if (description != null) 'description': description,
        if (dim1Id != null) 'dim1_id': dim1Id,
        if (dim2Id != null) 'dim2_id': dim2Id,
        if (dim3Id != null) 'dim3_id': dim3Id,
        if (dim4Id != null) 'dim4_id': dim4Id,
        if (dim5Id != null) 'dim5_id': dim5Id,
        if (branchId != null) 'branch_id': branchId,
        if (createdBy != null) 'created_by': createdBy,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}

// ── Detail (expense line — doc type 40 only) ────────────────────────────────
class CmTransactionDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final String? description;
  final int? expenseAccountId;
  final String? expenseAccountCode;
  final String? expenseAccountName;
  final double amountLc;
  final double amountFc;

  CmTransactionDetail({
    this.id, this.headerId,
    this.lineNo = 1,
    this.description,
    this.expenseAccountId,
    this.expenseAccountCode,
    this.expenseAccountName,
    this.amountLc = 0,
    this.amountFc = 0,
  });

  factory CmTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return CmTransactionDetail(
      id: json['id'], headerId: json['header_id'],
      lineNo: json['line_no'] ?? 1,
      description: json['description'],
      expenseAccountId: json['expense_account_id'],
      expenseAccountCode: json['expense_account_code'],
      expenseAccountName: json['expense_account_name'],
      amountLc: toDouble(json['amount_lc']),
      amountFc: toDouble(json['amount_fc']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'description': description,
        if (expenseAccountId != null) 'expense_account_id': expenseAccountId,
        'amount_lc': amountLc,
        'amount_fc': amountFc,
      };
}

// ── Apply (doc type 30 applying against open doc type 40) ──────────────────
class CmTransactionApply {
  final int? id;
  final int? transactionId;
  final int appliedToId;
  final String? appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double appliedAmountLc;
  final double appliedAmountFc;

  CmTransactionApply({
    this.id, this.transactionId,
    required this.appliedToId,
    this.appliedToDocNo,
    this.appliedToDocDate,
    this.appliedAmountLc = 0,
    this.appliedAmountFc = 0,
  });

  factory CmTransactionApply.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return CmTransactionApply(
      id: json['id'], transactionId: json['transaction_id'],
      appliedToId: json['applied_to_id'] ?? 0,
      appliedToDocNo: json['applied_to_doc_no'],
      appliedToDocDate: parseLocalDateNullable(json['applied_to_doc_date']),
      appliedAmountLc: toDouble(json['applied_amount_lc']),
      appliedAmountFc: toDouble(json['applied_amount_fc']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'applied_to_id': appliedToId,
        'applied_amount_lc': appliedAmountLc,
        'applied_amount_fc': appliedAmountFc,
      };
}

// ── Payment row (bank/payment-method breakdown — doc type 10/20/30) ────────
class CmTransactionPayment {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String paymentMethodType;
  final int? cmBankAccountId;
  final int? glAccountId;
  final double amountLc;
  final double amountFc;
  final String? refNo;
  final DateTime? paymentDate;
  final String? remark;
  final String? drawerBankName;
  final String? drawerBankBranch;
  final String? drawerAccountNo;

  CmTransactionPayment({
    this.id, this.headerId,
    this.lineNo = 1,
    this.paymentMethodId, this.paymentMethodCode, this.paymentMethodName,
    this.paymentMethodType = 'CASH',
    this.cmBankAccountId, this.glAccountId,
    this.amountLc = 0, this.amountFc = 0,
    this.refNo, this.paymentDate, this.remark,
    this.drawerBankName, this.drawerBankBranch, this.drawerAccountNo,
  });

  factory CmTransactionPayment.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return CmTransactionPayment(
      id: json['id'], headerId: json['header_id'],
      lineNo: json['line_no'] ?? 1,
      paymentMethodId: json['payment_method_id'],
      paymentMethodCode: json['payment_method_code'],
      paymentMethodName: json['payment_method_name'],
      paymentMethodType: json['payment_method_type'] ?? 'CASH',
      cmBankAccountId: json['cm_bank_account_id'],
      glAccountId: json['gl_account_id'],
      amountLc: toDouble(json['amount_lc']),
      amountFc: toDouble(json['amount_fc']),
      refNo: json['ref_no'],
      paymentDate: parseLocalDateNullable(json['payment_date']),
      remark: json['remark'],
      drawerBankName: json['drawer_bank_name'],
      drawerBankBranch: json['drawer_bank_branch'],
      drawerAccountNo: json['drawer_account_no'],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
        'payment_method_code': paymentMethodCode,
        'payment_method_name': paymentMethodName,
        'payment_method_type': paymentMethodType,
        if (cmBankAccountId != null) 'cm_bank_account_id': cmBankAccountId,
        if (glAccountId != null) 'gl_account_id': glAccountId,
        'amount_lc': amountLc,
        'amount_fc': amountFc,
        'ref_no': refNo,
        if (paymentDate != null) 'payment_date': formatLocalDate(paymentDate!),
        'remark': remark,
        'drawer_bank_name': drawerBankName,
        'drawer_bank_branch': drawerBankBranch,
        'drawer_account_no': drawerAccountNo,
      };
}

// ── Full CM Transaction (header + detail + apply + payment) ────────────────
class CmTransaction {
  final CmTransactionHeader header;
  final List<CmTransactionDetail> details;
  final List<CmTransactionApply> applies;
  final List<CmTransactionPayment> payments;

  CmTransaction({
    required this.header,
    this.details = const [],
    this.applies = const [],
    this.payments = const [],
  });

  factory CmTransaction.fromJson(Map<String, dynamic> json) => CmTransaction(
        header: CmTransactionHeader.fromJson(json),
        details: (json['details'] as List<dynamic>? ?? [])
            .map((e) => CmTransactionDetail.fromJson(e)).toList(),
        applies: (json['applies'] as List<dynamic>? ?? [])
            .map((e) => CmTransactionApply.fromJson(e)).toList(),
        payments: (json['payments'] as List<dynamic>? ?? [])
            .map((e) => CmTransactionPayment.fromJson(e)).toList(),
      );
}

// ── Open voucher (doc type 40, Posted, balance>0) — for Replenishment(30) picker ──
class CmOpenVoucher {
  final int id;
  final String docNo;
  final DateTime? docDate;
  final double totalAmountLc;
  final double balanceAmountLc;
  final String currencyCode;
  final double exchangeRate;
  final String? description;

  CmOpenVoucher({
    required this.id, required this.docNo,
    this.docDate,
    this.totalAmountLc = 0, this.balanceAmountLc = 0,
    this.currencyCode = 'THB', this.exchangeRate = 1,
    this.description,
  });

  factory CmOpenVoucher.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return CmOpenVoucher(
      id: json['id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      docDate: parseLocalDateNullable(json['doc_date']),
      totalAmountLc: toDouble(json['total_amount_lc']),
      balanceAmountLc: toDouble(json['balance_amount_lc']),
      currencyCode: json['currency_code'] ?? 'THB',
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      description: json['description'],
    );
  }
}

// ── Read-only view row for doc type 15/25 (mirrors cm_receipt / cm_payment) ─
class CmLegacyMirrorRow {
  final int id;
  final DateTime? date;
  final String status;
  final double amountLc;
  final String currencyCode;
  final double exchangeRate;
  final String? docNo;
  final String? counterpartyName;
  final String? paymentMethodType;
  final String? checkNo;
  final DateTime? checkDate;
  final String? clearingNote;

  CmLegacyMirrorRow({
    required this.id,
    this.date,
    this.status = 'Pending',
    this.amountLc = 0,
    this.currencyCode = 'THB',
    this.exchangeRate = 1,
    this.docNo,
    this.counterpartyName,
    this.paymentMethodType,
    this.checkNo,
    this.checkDate,
    this.clearingNote,
  });

  factory CmLegacyMirrorRow.fromJson(Map<String, dynamic> json, {required bool isReceipt}) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return CmLegacyMirrorRow(
      id: json['id'] ?? 0,
      date: parseLocalDateNullable(isReceipt ? json['receipt_date'] : json['payment_date']),
      status: json['status'] ?? 'Pending',
      amountLc: toDouble(json['amount_lc']),
      currencyCode: json['currency_code'] ?? 'THB',
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      docNo: isReceipt ? json['ar_doc_no'] : json['ap_doc_no'],
      counterpartyName: isReceipt ? json['customer_name_th'] : json['payee_name_th'],
      paymentMethodType: json['payment_method_type'],
      checkNo: json['check_no'],
      checkDate: parseLocalDateNullable(json['check_date']),
      clearingNote: json['clearing_note'],
    );
  }
}
