// lib/ar/models/ar_transaction.dart
import '../../../utils/date_utils.dart';

// AR document types (sys_doc_type in sa_module_document, sys_module=11)
const int arDocTypeInvoice = 10;
const int arDocTypeDebitNote = 30;
const int arDocTypeCreditNote = 50;
const int arDocTypeReceipt = 70;

const Map<int, String> arDocTypeNames = {
  arDocTypeInvoice: 'ใบแจ้งหนี้',
  arDocTypeDebitNote: 'ใบเพิ่มหนี้',
  arDocTypeCreditNote: 'ใบลดหนี้',
  arDocTypeReceipt: 'ใบรับชำระ',
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
  final int periodId;
  final int customerId;
  final String? customerCode;
  final String? customerNameTh;
  final int? arAccountId;
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
    this.periodId = 0,
    required this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.arAccountId,
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
      periodId: j['period_id'] as int? ?? 0,
      customerId: j['customer_id'] as int? ?? 0,
      customerCode: j['customer_code'],
      customerNameTh: j['customer_name_th'],
      arAccountId: j['ar_account_id'] as int?,
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
      refNo: j['ref_no'],
      refDocId: j['ref_doc_id'] as int?,
      refDocNo: j['ref_doc_no'],
      description: j['description'],
      status: j['status'] as String? ?? 'Draft',
      glEntryId: j['gl_entry_id'] as int?,
      docCode: j['doc_code'],
      docNameThai: j['doc_name_thai'],
      sysDocType: j['sys_doc_type'] as int?,
      isAutoNumbering: j['is_auto_numbering'] as bool?,
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
      createdBy: j['created_by']?.toString(),
      updatedBy: j['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        'due_date': dueDate != null ? formatLocalDate(dueDate!) : null,
        'period_id': periodId,
        'customer_id': customerId,
        'customer_code': customerCode,
        'customer_name_th': customerNameTh,
        'ar_account_id': arAccountId,
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
    );
  }
}

// ---- Apply (payment application) ----
class ArTransactionApply {
  final int id;
  final int transactionId;
  final int appliedToId;
  final double appliedAmountLc;
  final double appliedAmountFc;
  final DateTime? appliedDate;
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
      };
}

// ---- Full Transaction (header + details + applies) ----
class ArTransaction {
  final ArTransactionHeader header;
  final List<ArTransactionDetail> details;
  final List<ArTransactionApply> applies;

  const ArTransaction({
    required this.header,
    this.details = const [],
    this.applies = const [],
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
