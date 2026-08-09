// lib/ap/models/ap_transaction.dart
import '../../utils/date_utils.dart';

// AP document types (sys_doc_type in sa_module_document, sys_module=12)
const int apDocTypePurchaseInvoice    = 10;
const int apDocTypeCreditNote         = 30; // CN จากผู้ขาย (ลดหนี้)
const int apDocTypeDebitNote          = 50; // DN (เพิ่มหนี้)
const int apDocTypeAdvancePayment     = 60; // จ่ายมัดจำ
const int apDocTypeAdvanceRefund      = 65; // รับมัดจำคืน
const int apDocTypeRemittanceAdvice   = 70; // RA ใบแจ้งชำระ
const int apDocTypePayment            = 80; // ชำระเงิน

const Map<int, String> apDocTypeNames = {
  apDocTypePurchaseInvoice:  'ใบแจ้งหนี้ (AP)',
  apDocTypeCreditNote:       'ใบลดหนี้จากผู้ขาย',
  apDocTypeDebitNote:        'ใบเพิ่มหนี้ (AP)',
  apDocTypeAdvancePayment:   'จ่ายเงินมัดจำ',
  apDocTypeAdvanceRefund:    'รับเงินมัดจำคืน',
  apDocTypeRemittanceAdvice: 'ใบแจ้งการชำระเงิน (RA)',
  apDocTypePayment:          'ชำระเงิน',
};

const List<String> vatTypeOptions = ['VAT7', 'VAT0', 'NOVAT'];
const Map<String, String> vatTypeLabels = {
  'VAT7': 'VAT 7%',
  'VAT0': 'VAT 0%',
  'NOVAT': 'ไม่มี VAT',
};

// ── Status labels (Draft / Submitted / Approved / Posted / Void) ────────────
// Submitted/Approved เกิดขึ้นเฉพาะเอกสารที่ผ่าน flow ขออนุมัติ (RA 70 หรือ Payment 80 ที่ไม่มีเลขที่อ้างอิง)
const Map<String, String> apTransactionStatusLabels = {
  'Draft':     'ร่าง',
  'Submitted': 'รออนุมัติ',
  'Approved':  'อนุมัติแล้ว',
  'Posted':    'Post แล้ว',
  'Void':      'ยกเลิก',
};

const Map<String, String> apTransactionStatusLabelsEn = {
  'Draft':     'Draft',
  'Submitted': 'On Approve',
  'Approved':  'Approved',
  'Posted':    'Posted',
  'Void':      'Void',
};

String apTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? apTransactionStatusLabelsEn[s] : apTransactionStatusLabels[s]) ?? s;

// ── Approval record (mirrors ApPaymentRunApproval) ──────────────────────────
class ApTransactionApproval {
  final int id;
  final int transactionId;
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected / Skipped
  final String? remarks;
  final DateTime? approvedAt;

  const ApTransactionApproval({
    required this.id,
    required this.transactionId,
    required this.approverUserId,
    required this.approverUserName,
    required this.sequenceNo,
    required this.status,
    this.remarks,
    this.approvedAt,
  });

  factory ApTransactionApproval.fromJson(Map<String, dynamic> json) =>
      ApTransactionApproval(
        id: json['id'] as int,
        transactionId: json['transaction_id'] as int,
        approverUserId: json['approver_user_id'] as int,
        approverUserName: json['approver_user_name'] ?? '',
        sequenceNo: json['sequence_no'] ?? 1,
        status: json['status'] ?? 'Pending',
        remarks: json['remarks'],
        approvedAt: json['approved_at'] != null
            ? DateTime.parse(json['approved_at'])
            : null,
      );
}

// ── Header ─────────────────────────────────────────────────────────────────
class ApTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final DateTime? dueDate;
  final int periodId;
  final int vendorId;
  final String? vendorCode;
  final String? vendorNameTh;
  final String? vendorNameEn;
  final String? vendorTaxId;
  final int? apAccountId;
  final int? currencyId;
  final String currencyCode;
  final double exchangeRate;
  // FC amounts
  final double subtotalFc;
  final double discountAmountFc;
  final double beforeVatFc;
  final double vatAmountFc;
  final double totalAmountFc;
  // LC amounts
  final double subtotalLc;
  final double discountAmountLc;
  final double beforeVatLc;
  final double vatAmountLc;
  final double totalAmountLc;
  final double paidAmountLc;
  final double balanceAmountLc;
  final double whtAmountLc;
  final double advanceAmountLc;
  // References
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
  // Branch
  final int? branchId;
  final String? branchCode;
  final String? branchNameThai;
  final String? branchNameEng;
  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ApTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.dueDate,
    this.periodId = 0,
    required this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
    this.vendorNameEn,
    this.vendorTaxId,
    this.apAccountId,
    this.currencyId,
    this.currencyCode = 'THB',
    this.exchangeRate = 1.0,
    this.subtotalFc = 0,
    this.discountAmountFc = 0,
    this.beforeVatFc = 0,
    this.vatAmountFc = 0,
    this.totalAmountFc = 0,
    this.subtotalLc = 0,
    this.discountAmountLc = 0,
    this.beforeVatLc = 0,
    this.vatAmountLc = 0,
    this.totalAmountLc = 0,
    this.paidAmountLc = 0,
    this.balanceAmountLc = 0,
    this.whtAmountLc = 0,
    this.advanceAmountLc = 0,
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
    this.branchId, this.branchCode, this.branchNameThai, this.branchNameEng,
    this.createdAt, this.updatedAt, this.createdBy, this.updatedBy,
  });

  factory ApTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ApTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      dueDate: parseLocalDateNullable(json['due_date']),
      periodId: json['period_id'] ?? 0,
      vendorId: json['vendor_id'] ?? 0,
      vendorCode: json['vendor_code'],
      vendorNameTh: json['vendor_name_th'],
      vendorNameEn: json['vendor_name_en'],
      vendorTaxId: json['vendor_tax_id'],
      apAccountId: json['ap_account_id'],
      currencyId: json['currency_id'],
      currencyCode: json['currency_code'] ?? 'THB',
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      subtotalFc: toDouble(json['subtotal_fc']),
      discountAmountFc: toDouble(json['discount_amount_fc']),
      beforeVatFc: toDouble(json['before_vat_fc']),
      vatAmountFc: toDouble(json['vat_amount_fc']),
      totalAmountFc: toDouble(json['total_amount_fc']),
      subtotalLc: toDouble(json['subtotal_lc']),
      discountAmountLc: toDouble(json['discount_amount_lc']),
      beforeVatLc: toDouble(json['before_vat_lc']),
      vatAmountLc: toDouble(json['vat_amount_lc']),
      totalAmountLc: toDouble(json['total_amount_lc']),
      paidAmountLc: toDouble(json['paid_amount_lc']),
      balanceAmountLc: toDouble(json['balance_amount_lc']),
      whtAmountLc: toDouble(json['wht_amount_lc']),
      advanceAmountLc: toDouble(json['advance_amount_lc']),
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
      branchNameEng: json['branch_name_eng'],
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
        if (dueDate != null) 'due_date': formatLocalDate(dueDate!),
        'vendor_id': vendorId,
        'vendor_code': vendorCode,
        'vendor_name_th': vendorNameTh,
        'vendor_tax_id': vendorTaxId,
        if (apAccountId != null) 'ap_account_id': apAccountId,
        if (currencyId != null) 'currency_id': currencyId,
        'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        'subtotal_fc': subtotalFc,
        'discount_amount_fc': discountAmountFc,
        'before_vat_fc': beforeVatFc,
        'vat_amount_fc': vatAmountFc,
        'total_amount_fc': totalAmountFc,
        'subtotal_lc': subtotalLc,
        'discount_amount_lc': discountAmountLc,
        'before_vat_lc': beforeVatLc,
        'vat_amount_lc': vatAmountLc,
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

// ── Detail ─────────────────────────────────────────────────────────────────
class ApTransactionDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final String? itemCode;
  final String? itemName;
  final String? description;
  final double quantity;
  final double unitPriceFc;
  final double discountPercent;
  final double discountAmountFc;
  final double subtotalFc;
  final String vatType;
  final double vatRate;
  final double vatAmountFc;
  final double totalAmountFc;
  final int? expenseAccountId;
  final String? expenseAccountCode;
  final String? expenseAccountName;
  final double subtotalLc;
  final double vatAmountLc;
  final double totalAmountLc;
  final bool isDeferredVat;

  ApTransactionDetail({
    this.id, this.headerId,
    this.lineNo = 1,
    this.itemCode,
    this.itemName,
    this.description,
    this.quantity = 1,
    this.unitPriceFc = 0,
    this.discountPercent = 0,
    this.discountAmountFc = 0,
    this.subtotalFc = 0,
    this.vatType = 'NOVAT',
    this.vatRate = 0,
    this.vatAmountFc = 0,
    this.totalAmountFc = 0,
    this.expenseAccountId,
    this.expenseAccountCode,
    this.expenseAccountName,
    this.subtotalLc = 0,
    this.vatAmountLc = 0,
    this.totalAmountLc = 0,
    this.isDeferredVat = false,
  });

  factory ApTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ApTransactionDetail(
      id: json['id'], headerId: json['header_id'],
      lineNo: json['line_no'] ?? 1,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      description: json['description'],
      quantity: toDouble(json['quantity']) == 0 ? 1 : toDouble(json['quantity']),
      unitPriceFc: toDouble(json['unit_price_fc']),
      discountPercent: toDouble(json['discount_percent']),
      discountAmountFc: toDouble(json['discount_amount_fc']),
      subtotalFc: toDouble(json['subtotal_fc']),
      vatType: json['vat_type'] ?? 'NOVAT',
      vatRate: toDouble(json['vat_rate']),
      vatAmountFc: toDouble(json['vat_amount_fc']),
      totalAmountFc: toDouble(json['total_amount_fc']),
      expenseAccountId: json['expense_account_id'],
      expenseAccountCode: json['expense_account_code'],
      expenseAccountName: json['expense_account_name'],
      subtotalLc: toDouble(json['subtotal_lc']),
      vatAmountLc: toDouble(json['vat_amount_lc']),
      totalAmountLc: toDouble(json['total_amount_lc']),
      isDeferredVat: json['is_deferred_vat'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (headerId != null) 'header_id': headerId,
        'line_no': lineNo,
        if (itemCode != null) 'item_code': itemCode,
        if (itemName != null) 'item_name': itemName,
        'description': description,
        'quantity': quantity,
        'unit_price_fc': unitPriceFc,
        'discount_percent': discountPercent,
        'discount_amount_fc': discountAmountFc,
        'subtotal_fc': subtotalFc,
        'vat_type': vatType,
        'vat_rate': vatRate,
        'vat_amount_fc': vatAmountFc,
        'total_amount_fc': totalAmountFc,
        if (expenseAccountId != null) 'expense_account_id': expenseAccountId,
        'subtotal_lc': subtotalLc,
        'vat_amount_lc': vatAmountLc,
        'total_amount_lc': totalAmountLc,
        'is_deferred_vat': isDeferredVat,
      };

  ApTransactionDetail copyWith({
    int? id, int? headerId, int? lineNo, String? description,
    double? quantity, double? unitPriceFc, double? discountPercent, double? discountAmountFc,
    double? subtotalFc, String? vatType, double? vatRate, double? vatAmountFc, double? totalAmountFc,
    int? expenseAccountId, String? expenseAccountCode, String? expenseAccountName,
    double? subtotalLc, double? vatAmountLc, double? totalAmountLc, bool? isDeferredVat,
  }) => ApTransactionDetail(
        id: id ?? this.id, headerId: headerId ?? this.headerId,
        lineNo: lineNo ?? this.lineNo, description: description ?? this.description,
        quantity: quantity ?? this.quantity, unitPriceFc: unitPriceFc ?? this.unitPriceFc,
        discountPercent: discountPercent ?? this.discountPercent,
        discountAmountFc: discountAmountFc ?? this.discountAmountFc,
        subtotalFc: subtotalFc ?? this.subtotalFc, vatType: vatType ?? this.vatType,
        vatRate: vatRate ?? this.vatRate, vatAmountFc: vatAmountFc ?? this.vatAmountFc,
        totalAmountFc: totalAmountFc ?? this.totalAmountFc,
        expenseAccountId: expenseAccountId ?? this.expenseAccountId,
        expenseAccountCode: expenseAccountCode ?? this.expenseAccountCode,
        expenseAccountName: expenseAccountName ?? this.expenseAccountName,
        subtotalLc: subtotalLc ?? this.subtotalLc,
        vatAmountLc: vatAmountLc ?? this.vatAmountLc, totalAmountLc: totalAmountLc ?? this.totalAmountLc,
        isDeferredVat: isDeferredVat ?? this.isDeferredVat,
      );
}

// ── Apply Row (for payment referencing invoices) ───────────────────────────
class ApTransactionApply {
  final int? id;
  final int? transactionId;
  final int appliedToId;
  final String? appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double appliedAmountLc;
  final double appliedAmountFc;
  final String applyType; // 'invoice', 'advance', 'ra_invoice'

  ApTransactionApply({
    this.id, this.transactionId,
    required this.appliedToId,
    this.appliedToDocNo,
    this.appliedToDocDate,
    this.appliedAmountLc = 0,
    this.appliedAmountFc = 0,
    this.applyType = 'invoice',
  });

  factory ApTransactionApply.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ApTransactionApply(
      id: json['id'], transactionId: json['transaction_id'],
      appliedToId: json['applied_to_id'] ?? 0,
      appliedToDocNo: json['applied_to_doc_no'],
      appliedToDocDate: parseLocalDateNullable(json['applied_to_doc_date']),
      appliedAmountLc: toDouble(json['applied_amount_lc']),
      appliedAmountFc: toDouble(json['applied_amount_fc']),
      applyType: json['apply_type'] ?? 'invoice',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'applied_to_id': appliedToId,
        'applied_amount_lc': appliedAmountLc,
        'applied_amount_fc': appliedAmountFc,
        'apply_type': applyType,
      };
}

// ── Payment Row ────────────────────────────────────────────────────────────
class ApTransactionPayment {
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

  ApTransactionPayment({
    this.id, this.headerId,
    this.lineNo = 1,
    this.paymentMethodId, this.paymentMethodCode, this.paymentMethodName,
    this.paymentMethodType = 'CASH',
    this.cmBankAccountId, this.glAccountId,
    this.amountLc = 0, this.amountFc = 0,
    this.refNo, this.paymentDate, this.remark,
    this.drawerBankName, this.drawerBankBranch, this.drawerAccountNo,
  });

  factory ApTransactionPayment.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ApTransactionPayment(
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

// ── WHT Row ────────────────────────────────────────────────────────────────
class ApTransactionWht {
  final int? id;
  final int? headerId;
  final int? whtTypeId;
  final String? whtType;
  final String? incomeType;
  final double whtRate;
  final double baseAmountLc;
  final double whtAmountLc;
  final String? description;

  ApTransactionWht({
    this.id, this.headerId,
    this.whtTypeId, this.whtType, this.incomeType,
    this.whtRate = 0,
    this.baseAmountLc = 0, this.whtAmountLc = 0,
    this.description,
  });

  factory ApTransactionWht.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ApTransactionWht(
      id: json['id'], headerId: json['header_id'],
      whtTypeId: json['wht_type_id'],
      whtType: json['wht_type'],
      incomeType: json['income_type'],
      whtRate: toDouble(json['wht_rate']),
      baseAmountLc: toDouble(json['base_amount_lc']),
      whtAmountLc: toDouble(json['wht_amount_lc']),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'wht_type_id': whtTypeId,
        'wht_type': whtType,
        'income_type': incomeType,
        'wht_rate': whtRate,
        'base_amount_lc': baseAmountLc,
        'wht_amount_lc': whtAmountLc,
        'description': description,
      };

  ApTransactionWht copyWith({
    int? id, int? headerId, int? whtTypeId, String? whtType, String? incomeType,
    double? whtRate, double? baseAmountLc, double? whtAmountLc, String? description,
  }) => ApTransactionWht(
        id: id ?? this.id, headerId: headerId ?? this.headerId,
        whtTypeId: whtTypeId ?? this.whtTypeId,
        whtType: whtType ?? this.whtType,
        incomeType: incomeType ?? this.incomeType,
        whtRate: whtRate ?? this.whtRate,
        baseAmountLc: baseAmountLc ?? this.baseAmountLc,
        whtAmountLc: whtAmountLc ?? this.whtAmountLc,
        description: description ?? this.description,
      );
}

// ── Full Transaction (header + details + applies + payments + whts) ────────
class ApTransaction {
  final ApTransactionHeader header;
  final List<ApTransactionDetail> details;
  final List<ApTransactionApply> applies;
  final List<ApTransactionPayment> payments;
  final List<ApTransactionWht> whts;
  final List<ApTransactionApproval> approvals;

  ApTransaction({
    required this.header,
    this.details = const [],
    this.applies = const [],
    this.payments = const [],
    this.whts = const [],
    this.approvals = const [],
  });

  factory ApTransaction.fromJson(Map<String, dynamic> json) => ApTransaction(
        header: ApTransactionHeader.fromJson(json),
        details: (json['details'] as List<dynamic>? ?? [])
            .map((e) => ApTransactionDetail.fromJson(e)).toList(),
        applies: (json['applies'] as List<dynamic>? ?? [])
            .map((e) => ApTransactionApply.fromJson(e)).toList(),
        payments: (json['payments'] as List<dynamic>? ?? [])
            .map((e) => ApTransactionPayment.fromJson(e)).toList(),
        whts: (json['whts'] as List<dynamic>? ?? [])
            .map((e) => ApTransactionWht.fromJson(e)).toList(),
        approvals: (json['approvals'] as List<dynamic>? ?? [])
            .map((e) => ApTransactionApproval.fromJson(e)).toList(),
      );
}

// ── Open Invoice (for payment selection) ──────────────────────────────────
class ApOpenInvoice {
  final int id;
  final String docNo;
  final DateTime? docDate;
  final DateTime? dueDate;
  final double totalAmountLc;
  final double balanceAmountLc;
  final double totalAmountFc;
  final double vatAmountFc;
  final double vatAmountLc;
  final String currencyCode;
  final double exchangeRate;
  final String? docCode;
  final int? sysDocType;

  ApOpenInvoice({
    required this.id, required this.docNo,
    this.docDate, this.dueDate,
    this.totalAmountLc = 0, this.balanceAmountLc = 0,
    this.totalAmountFc = 0, this.vatAmountFc = 0, this.vatAmountLc = 0,
    this.currencyCode = 'THB', this.exchangeRate = 1,
    this.docCode, this.sysDocType,
  });

  factory ApOpenInvoice.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ApOpenInvoice(
      id: json['id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      docDate: parseLocalDateNullable(json['doc_date']),
      dueDate: parseLocalDateNullable(json['due_date']),
      totalAmountLc: toDouble(json['total_amount_lc']),
      balanceAmountLc: toDouble(json['balance_amount_lc']),
      totalAmountFc: toDouble(json['total_amount_fc']),
      vatAmountFc: toDouble(json['vat_amount_fc']),
      vatAmountLc: toDouble(json['vat_amount_lc']),
      currencyCode: json['currency_code'] ?? 'THB',
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      docCode: json['doc_code'],
      sysDocType: json['sys_doc_type'] != null ? int.tryParse(json['sys_doc_type'].toString()) : null,
    );
  }
}
