// lib/ar/models/ar_transaction.dart
import '../../../utils/date_utils.dart';

// AR document types (sys_doc_type in sa_module_document, sys_module=11)
const int arDocTypeInvoice            = 10;
const int arDocTypeDebitNote          = 30;
const int arDocTypeDebitNoteWithBill  = 35;
const int arDocTypeCreditNote         = 50;
const int arDocTypeCreditNoteWithBill = 55;
const int arDocTypeAdvanceReceipt     = 60;
const int arDocTypeAdvanceRefund      = 65;
const int arDocTypeBillCollection     = 70;
const int arDocTypeReceipt            = 80;

const Map<int, String> arDocTypeNames = {
  arDocTypeInvoice:            'ใบแจ้งหนี้',
  arDocTypeDebitNote:          'ใบเพิ่มหนี้',
  arDocTypeDebitNoteWithBill:  'ใบเพิ่มหนี้ (ระบุใบแจ้งหนี้)',
  arDocTypeCreditNote:         'ใบลดหนี้',
  arDocTypeCreditNoteWithBill: 'ใบลดหนี้ (ระบุใบแจ้งหนี้)',
  arDocTypeAdvanceReceipt:     'รับเงินมัดจำ',
  arDocTypeAdvanceRefund:      'คืนเงินมัดจำ',
  arDocTypeBillCollection:     'ใบวางบิล',
  arDocTypeReceipt:            'ใบรับชำระ',
};

const List<String> vatTypeOptions = ['VAT7', 'VAT0', 'NOVAT'];
const Map<String, String> vatTypeLabels = {
  'VAT7': 'VAT 7%',
  'VAT0': 'VAT 0%',
  'NOVAT': 'ไม่มี VAT',
};

// ---- Header ----
class ArTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final DateTime? dueDate;
  final DateTime? billingDate;
  final DateTime? expectedPaymentDate;
  final int periodId;
  final int customerId;
  final String? customerCode;
  final String? customerNameTh;
  final int? arAccountId;
  final int? vatAccountId;   // from ar_gl_account_setup.vat_output_account_id
  final int? glDocId;        // from ar_gl_account_setup.gl_doc_id
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
  // WHT + Advance summary
  final double whtAmountLc;
  final double advanceAmountLc;
  // References
  final String? refNo;
  final int? refDocId;
  final String? refDocNo;
  final String? description;
  final String status; // Draft, Posted, Void
  final int? glEntryId;
  // From join
  final String? docCode;
  final String? docNameThai;
  final int? sysDocType;
  final bool? isAutoNumbering;
  // GL Dimensions (configurable dim1–dim5)
  final int? dim1Id; final String? dim1Name;
  final int? dim2Id; final String? dim2Name;
  final int? dim3Id; final String? dim3Name;
  final int? dim4Id; final String? dim4Name;
  final int? dim5Id; final String? dim5Name;
  // Branch (header level)
  final int? branchId;
  final String? branchCode;
  final String? branchNameThai;
  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ArTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.dueDate,
    this.billingDate,
    this.expectedPaymentDate,
    this.periodId = 0,
    required this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.arAccountId,
    this.vatAccountId,
    this.glDocId,
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
    this.sysDocType,
    this.isAutoNumbering,
    this.createdAt,
    this.updatedAt,
    this.dim1Id, this.dim1Name,
    this.dim2Id, this.dim2Name,
    this.dim3Id, this.dim3Name,
    this.dim4Id, this.dim4Name,
    this.dim5Id, this.dim5Name,
    this.branchId,
    this.branchCode,
    this.branchNameThai,
    this.createdBy,
    this.updatedBy,
  });

  factory ArTransactionHeader.fromJson(Map<String, dynamic> j) {
    return ArTransactionHeader(
      id: j['id'] as int? ?? 0,
      docId: j['doc_id'] as int? ?? 0,
      docNo: j['doc_no'] as String? ?? '',
      docDate: parseLocalDate(j['doc_date']),
      dueDate: parseLocalDateNullable(j['due_date']),
      billingDate: parseLocalDateNullable(j['billing_date']),
      expectedPaymentDate: parseLocalDateNullable(j['expected_payment_date']),
      periodId: j['period_id'] as int? ?? 0,
      customerId: j['customer_id'] as int? ?? 0,
      customerCode: j['customer_code'],
      customerNameTh: j['customer_name_th'],
      arAccountId: j['ar_account_id'] as int?,
      vatAccountId: j['vat_account_id'] as int?,
      glDocId: j['gl_doc_id'] as int?,
      currencyId: j['currency_id'] as int?,
      currencyCode: j['currency_code'] as String? ?? 'THB',
      exchangeRate: _toDouble(j['exchange_rate']) ?? 1.0,
      subtotalFc: _toDouble(j['subtotal_fc']) ?? 0,
      discountAmountFc: _toDouble(j['discount_amount_fc']) ?? 0,
      beforeVatFc: _toDouble(j['before_vat_fc']) ?? 0,
      vatAmountFc: _toDouble(j['vat_amount_fc']) ?? 0,
      totalAmountFc: _toDouble(j['total_amount_fc']) ?? 0,
      subtotalLc: _toDouble(j['subtotal_lc']) ?? 0,
      discountAmountLc: _toDouble(j['discount_amount_lc']) ?? 0,
      beforeVatLc: _toDouble(j['before_vat_lc']) ?? 0,
      vatAmountLc: _toDouble(j['vat_amount_lc']) ?? 0,
      totalAmountLc: _toDouble(j['total_amount_lc']) ?? 0,
      paidAmountLc: _toDouble(j['paid_amount_lc']) ?? 0,
      balanceAmountLc: _toDouble(j['balance_amount_lc']) ?? 0,
      whtAmountLc: _toDouble(j['wht_amount_lc']) ?? 0,
      advanceAmountLc: _toDouble(j['advance_amount_lc']) ?? 0,
      refNo: j['ref_no'],
      refDocId: j['ref_doc_id'] as int?,
      refDocNo: j['ref_doc_no'],
      description: j['description'],
      status: j['status'] as String? ?? 'Draft',
      glEntryId: j['gl_entry_id'] as int?,
      docCode: j['doc_code'],
      docNameThai: j['doc_name_thai'],
      sysDocType: j['sys_doc_type'] != null ? int.tryParse(j['sys_doc_type'].toString()) : null,
      isAutoNumbering: j['is_auto_numbering'] as bool?,
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
      createdBy: j['created_by']?.toString(),
      updatedBy: j['updated_by']?.toString(),
      dim1Id: j['dim1_id'] as int?, dim1Name: j['dim1_name'] as String?,
      dim2Id: j['dim2_id'] as int?, dim2Name: j['dim2_name'] as String?,
      dim3Id: j['dim3_id'] as int?, dim3Name: j['dim3_name'] as String?,
      dim4Id: j['dim4_id'] as int?, dim4Name: j['dim4_name'] as String?,
      dim5Id: j['dim5_id'] as int?, dim5Name: j['dim5_name'] as String?,
      branchId: j['branch_id'] as int?,
      branchCode: j['branch_code'] as String?,
      branchNameThai: j['branch_name_thai'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        'due_date': dueDate != null ? formatLocalDate(dueDate!) : null,
        'billing_date': billingDate != null ? formatLocalDate(billingDate!) : null,
        'expected_payment_date': expectedPaymentDate != null ? formatLocalDate(expectedPaymentDate!) : null,
        'period_id': periodId,
        'customer_id': customerId,
        'customer_code': customerCode,
        'customer_name_th': customerNameTh,
        'ar_account_id': arAccountId,
        'vat_account_id': vatAccountId,
        'gl_doc_id': glDocId,
        'currency_id': currencyId,
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
        'ref_no': refNo,
        'ref_doc_id': refDocId,
        'ref_doc_no': refDocNo,
        'description': description,
        'status': status,
        'dim1_id': dim1Id,
        'dim2_id': dim2Id,
        'dim3_id': dim3Id,
        'dim4_id': dim4Id,
        'dim5_id': dim5Id,
        'branch_id': branchId,
        'created_by': createdBy,
        'updated_by': updatedBy,
      };
}

// ---- Detail Line ----
class ArTransactionDetail {
  final int id;
  final int headerId;
  final int lineNo;
  final String? itemCode;
  final String? itemName;
  final String? description;
  final double quantity;
  final String? unitCode;
  final double unitPriceFc;
  final double discountPercent;
  final double discountAmountFc;
  final double subtotalFc;
  final String vatType;
  final double vatRate;
  final double vatAmountFc;
  final double totalAmountFc;
  final int? revenueAccountId;
  final double subtotalLc;
  final double vatAmountLc;
  final double totalAmountLc;
  final bool isDeferredVat;  // true = VAT รอตัด (บันทึก VAT ตอนรับชำระ ไม่ใช่ตอนตั้งหนี้)

  const ArTransactionDetail({
    this.id = 0,
    this.headerId = 0,
    this.lineNo = 1,
    this.itemCode,
    this.itemName,
    this.description,
    this.quantity = 1,
    this.unitCode,
    this.unitPriceFc = 0,
    this.discountPercent = 0,
    this.discountAmountFc = 0,
    this.subtotalFc = 0,
    this.vatType = 'VAT7',
    this.vatRate = 7,
    this.vatAmountFc = 0,
    this.totalAmountFc = 0,
    this.revenueAccountId,
    this.subtotalLc = 0,
    this.vatAmountLc = 0,
    this.totalAmountLc = 0,
    this.isDeferredVat = false,
  });

  factory ArTransactionDetail.fromJson(Map<String, dynamic> j) {
    return ArTransactionDetail(
      id: j['id'] as int? ?? 0,
      headerId: j['header_id'] as int? ?? 0,
      lineNo: j['line_no'] as int? ?? 1,
      itemCode: j['item_code'],
      itemName: j['item_name'],
      description: j['description'],
      quantity: _toDouble(j['quantity']) ?? 1,
      unitCode: j['unit_code'],
      unitPriceFc: _toDouble(j['unit_price_fc']) ?? 0,
      discountPercent: _toDouble(j['discount_percent']) ?? 0,
      discountAmountFc: _toDouble(j['discount_amount_fc']) ?? 0,
      subtotalFc: _toDouble(j['subtotal_fc']) ?? 0,
      vatType: j['vat_type'] as String? ?? 'VAT7',
      vatRate: _toDouble(j['vat_rate']) ?? 7,
      vatAmountFc: _toDouble(j['vat_amount_fc']) ?? 0,
      totalAmountFc: _toDouble(j['total_amount_fc']) ?? 0,
      revenueAccountId: j['revenue_account_id'] as int?,
      subtotalLc: _toDouble(j['subtotal_lc']) ?? 0,
      vatAmountLc: _toDouble(j['vat_amount_lc']) ?? 0,
      totalAmountLc: _toDouble(j['total_amount_lc']) ?? 0,
      isDeferredVat: j['is_deferred_vat'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'header_id': headerId,
        'line_no': lineNo,
        'item_code': itemCode,
        'item_name': itemName,
        'description': description,
        'quantity': quantity,
        'unit_code': unitCode,
        'unit_price_fc': unitPriceFc,
        'discount_percent': discountPercent,
        'discount_amount_fc': discountAmountFc,
        'subtotal_fc': subtotalFc,
        'vat_type': vatType,
        'vat_rate': vatRate,
        'vat_amount_fc': vatAmountFc,
        'total_amount_fc': totalAmountFc,
        'revenue_account_id': revenueAccountId,
        'subtotal_lc': subtotalLc,
        'vat_amount_lc': vatAmountLc,
        'total_amount_lc': totalAmountLc,
        'is_deferred_vat': isDeferredVat,
      };

  ArTransactionDetail copyWith({
    int? id,
    int? headerId,
    int? lineNo,
    String? itemCode,
    String? itemName,
    String? description,
    double? quantity,
    String? unitCode,
    double? unitPriceFc,
    double? discountPercent,
    double? discountAmountFc,
    double? subtotalFc,
    String? vatType,
    double? vatRate,
    double? vatAmountFc,
    double? totalAmountFc,
    int? revenueAccountId,
    double? subtotalLc,
    double? vatAmountLc,
    double? totalAmountLc,
    bool? isDeferredVat,
  }) {
    return ArTransactionDetail(
      id: id ?? this.id,
      headerId: headerId ?? this.headerId,
      lineNo: lineNo ?? this.lineNo,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitCode: unitCode ?? this.unitCode,
      unitPriceFc: unitPriceFc ?? this.unitPriceFc,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmountFc: discountAmountFc ?? this.discountAmountFc,
      subtotalFc: subtotalFc ?? this.subtotalFc,
      vatType: vatType ?? this.vatType,
      vatRate: vatRate ?? this.vatRate,
      vatAmountFc: vatAmountFc ?? this.vatAmountFc,
      totalAmountFc: totalAmountFc ?? this.totalAmountFc,
      revenueAccountId: revenueAccountId ?? this.revenueAccountId,
      subtotalLc: subtotalLc ?? this.subtotalLc,
      vatAmountLc: vatAmountLc ?? this.vatAmountLc,
      totalAmountLc: totalAmountLc ?? this.totalAmountLc,
      isDeferredVat: isDeferredVat ?? this.isDeferredVat,
    );
  }
}

// ---- WHT Line ----
class ArTransactionWht {
  final int    id;
  final int    headerId;
  final int    lineNo;
  final int?   whtTypeId;       // FK → cd_wht_type
  // Snapshot
  final String? whtCode;
  final String? whtName;
  final String? incomeType;
  final double  whtRate;
  final double  baseAmountLc;   // ฐานภาษี (LC)
  final double  whtAmountLc;    // จำนวนภาษีที่ถูกหัก (LC)

  const ArTransactionWht({
    this.id = 0,
    this.headerId = 0,
    this.lineNo = 1,
    this.whtTypeId,
    this.whtCode,
    this.whtName,
    this.incomeType,
    this.whtRate = 0,
    this.baseAmountLc = 0,
    this.whtAmountLc = 0,
  });

  factory ArTransactionWht.fromJson(Map<String, dynamic> j) {
    return ArTransactionWht(
      id:           j['id'] as int? ?? 0,
      headerId:     j['header_id'] as int? ?? 0,
      lineNo:       j['line_no'] as int? ?? 1,
      whtTypeId:    j['wht_type_id'] as int?,
      whtCode:      j['wht_code'] as String?,
      whtName:      j['wht_name'] as String?,
      incomeType:   j['income_type'] as String?,
      whtRate:      _toDouble(j['wht_rate']) ?? 0,
      baseAmountLc: _toDouble(j['base_amount_lc']) ?? 0,
      whtAmountLc:  _toDouble(j['wht_amount_lc']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'header_id':      headerId,
    'line_no':        lineNo,
    'wht_type_id':    whtTypeId,
    'wht_code':       whtCode,
    'wht_name':       whtName,
    'income_type':    incomeType,
    'wht_rate':       whtRate,
    'base_amount_lc': baseAmountLc,
    'wht_amount_lc':  whtAmountLc,
  };

  ArTransactionWht copyWith({
    int? id, int? headerId, int? lineNo,
    int? whtTypeId, String? whtCode, String? whtName, String? incomeType,
    double? whtRate, double? baseAmountLc, double? whtAmountLc,
  }) {
    return ArTransactionWht(
      id:           id ?? this.id,
      headerId:     headerId ?? this.headerId,
      lineNo:       lineNo ?? this.lineNo,
      whtTypeId:    whtTypeId ?? this.whtTypeId,
      whtCode:      whtCode ?? this.whtCode,
      whtName:      whtName ?? this.whtName,
      incomeType:   incomeType ?? this.incomeType,
      whtRate:      whtRate ?? this.whtRate,
      baseAmountLc: baseAmountLc ?? this.baseAmountLc,
      whtAmountLc:  whtAmountLc ?? this.whtAmountLc,
    );
  }
}

// ---- Apply (payment application / advance deduction) ----
class ArTransactionApply {
  final int id;
  final int transactionId;
  final int appliedToId;
  final double appliedAmountLc;
  final double appliedAmountFc;
  final DateTime? appliedDate;
  final String applyType; // 'invoice' | 'advance'
  // From join
  final String? appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double? appliedToTotal;

  const ArTransactionApply({
    this.id = 0,
    this.transactionId = 0,
    required this.appliedToId,
    this.appliedAmountLc = 0,
    this.appliedAmountFc = 0,
    this.appliedDate,
    this.applyType = 'invoice',
    this.appliedToDocNo,
    this.appliedToDocDate,
    this.appliedToTotal,
  });

  factory ArTransactionApply.fromJson(Map<String, dynamic> j) {
    return ArTransactionApply(
      id: j['id'] as int? ?? 0,
      transactionId: j['transaction_id'] as int? ?? 0,
      appliedToId: j['applied_to_id'] as int? ?? 0,
      appliedAmountLc: _toDouble(j['applied_amount_lc']) ?? 0,
      appliedAmountFc: _toDouble(j['applied_amount_fc']) ?? 0,
      appliedDate: parseLocalDateNullable(j['applied_date']),
      applyType: j['apply_type'] as String? ?? 'invoice',
      appliedToDocNo: j['applied_to_doc_no'],
      appliedToDocDate: parseLocalDateNullable(j['applied_to_doc_date']),
      appliedToTotal: _toDouble(j['applied_to_total']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transaction_id': transactionId,
        'applied_to_id': appliedToId,
        'applied_amount_lc': appliedAmountLc,
        'applied_amount_fc': appliedAmountFc,
        'apply_type': applyType,
      };
}

// ---- Payment row (วิธีรับชำระ สำหรับ Receipt / Advance Receipt) ----
class ArTransactionPayment {
  final int id;
  final int headerId;
  final int lineNo;
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String paymentMethodType;
  //  CASH / CHECK / TRANSFER / CREDIT_CARD / DEBIT_CARD /
  //  QR_CODE / MOBILE_BANKING / BILL_OF_EXCHANGE / OTHER
  final int? cmBankAccountId;
  final int? glAccountId;       // resolved GL account (snapshot)
  final double amountLc;
  final double amountFc;
  // ── ข้อมูลทั่วไป ──
  final String? refNo;          // เลขอ้างอิง / เลขที่เช็ค / เลขตั๋ว
  final DateTime? paymentDate;  // วันที่ชำระ / วันที่บนเช็ค / วันครบกำหนด
  final String? remark;
  // ── เช็ค / โอน / ตั๋ว ──
  final String? drawerBankName;     // ธนาคารผู้ออกเช็ค / ต้นทาง
  final String? drawerBankBranch;   // สาขา
  final String? drawerAccountNo;    // เลขที่บัญชี (เจ้าของเช็ค/ต้นทาง)
  // ── บัตรเครดิต / เดบิต ──
  final String? cardType;           // VISA/MASTERCARD/AMEX/JCB/UNIONPAY/OTHER
  final String? cardLast4;          // 4 หลักท้าย
  final String? approvalCode;       // รหัสอนุมัติ (Authorization Code)
  final String? terminalId;         // รหัสเครื่อง EDC
  final String? batchNo;            // เลขที่ Batch
  // ── from join ──
  final String? glAccountCode;
  final String? glAccountName;
  final String? bankAccountCode;
  final String? bankAccountNameTh;
  final String? bankNameTh;

  const ArTransactionPayment({
    this.id = 0,
    this.headerId = 0,
    this.lineNo = 1,
    this.paymentMethodId,
    this.paymentMethodCode,
    this.paymentMethodName,
    this.paymentMethodType = 'CASH',
    this.cmBankAccountId,
    this.glAccountId,
    this.amountLc = 0,
    this.amountFc = 0,
    this.refNo,
    this.paymentDate,
    this.remark,
    this.drawerBankName,
    this.drawerBankBranch,
    this.drawerAccountNo,
    this.cardType,
    this.cardLast4,
    this.approvalCode,
    this.terminalId,
    this.batchNo,
    this.glAccountCode,
    this.glAccountName,
    this.bankAccountCode,
    this.bankAccountNameTh,
    this.bankNameTh,
  });

  factory ArTransactionPayment.fromJson(Map<String, dynamic> j) {
    return ArTransactionPayment(
      id: j['id'] as int? ?? 0,
      headerId: j['header_id'] as int? ?? 0,
      lineNo: j['line_no'] as int? ?? 1,
      paymentMethodId: j['payment_method_id'] as int?,
      paymentMethodCode: j['payment_method_code'],
      paymentMethodName: j['payment_method_name'],
      paymentMethodType: j['payment_method_type'] as String? ?? 'CASH',
      cmBankAccountId: j['cm_bank_account_id'] as int?,
      glAccountId: j['gl_account_id'] as int?,
      amountLc: _toDouble(j['amount_lc']) ?? 0,
      amountFc: _toDouble(j['amount_fc']) ?? 0,
      refNo: j['ref_no'],
      paymentDate: j['payment_date'] != null ? DateTime.tryParse(j['payment_date'].toString()) : null,
      remark: j['remark'],
      drawerBankName: j['drawer_bank_name'],
      drawerBankBranch: j['drawer_bank_branch'],
      drawerAccountNo: j['drawer_account_no'],
      cardType: j['card_type'],
      cardLast4: j['card_last4'],
      approvalCode: j['approval_code'],
      terminalId: j['terminal_id'],
      batchNo: j['batch_no'],
      glAccountCode: j['gl_account_code'],
      glAccountName: j['gl_account_name'],
      bankAccountCode: j['bank_account_code'],
      bankAccountNameTh: j['bank_account_name_th'],
      bankNameTh: j['bank_name_th'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'header_id': headerId,
        'line_no': lineNo,
        'payment_method_id': paymentMethodId,
        'payment_method_code': paymentMethodCode,
        'payment_method_name': paymentMethodName,
        'payment_method_type': paymentMethodType,
        'cm_bank_account_id': cmBankAccountId,
        'gl_account_id': glAccountId,
        'amount_lc': amountLc,
        'amount_fc': amountFc,
        'ref_no': refNo,
        'payment_date': paymentDate?.toIso8601String().substring(0, 10),
        'remark': remark,
        'drawer_bank_name': drawerBankName,
        'drawer_bank_branch': drawerBankBranch,
        'drawer_account_no': drawerAccountNo,
        'card_type': cardType,
        'card_last4': cardLast4,
        'approval_code': approvalCode,
        'terminal_id': terminalId,
        'batch_no': batchNo,
      };
}

// ---- Full Transaction (header + details + applies + whts + payments) ----
class ArTransaction {
  final ArTransactionHeader header;
  final List<ArTransactionDetail> details;
  final List<ArTransactionApply> applies;
  final List<ArTransactionWht> whts;
  final List<ArTransactionPayment> payments;

  const ArTransaction({
    required this.header,
    this.details = const [],
    this.applies = const [],
    this.whts = const [],
    this.payments = const [],
  });

  factory ArTransaction.fromJson(Map<String, dynamic> j) {
    return ArTransaction(
      header: ArTransactionHeader.fromJson(j['header'] as Map<String, dynamic>),
      details: (j['details'] as List<dynamic>? ?? [])
          .map((d) => ArTransactionDetail.fromJson(d as Map<String, dynamic>))
          .toList(),
      applies: (j['applies'] as List<dynamic>? ?? [])
          .map((a) => ArTransactionApply.fromJson(a as Map<String, dynamic>))
          .toList(),
      whts: (j['whts'] as List<dynamic>? ?? [])
          .map((w) => ArTransactionWht.fromJson(w as Map<String, dynamic>))
          .toList(),
      payments: (j['payments'] as List<dynamic>? ?? [])
          .map((p) => ArTransactionPayment.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Helper to parse numeric values from JSON safely
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
