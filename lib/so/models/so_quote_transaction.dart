// lib/so/models/so_quote_transaction.dart — ใบเสนอราคา (Sale Quote, sys_module='41', อยู่ใต้โหนด SO)
// มิเรอร์ po_pr_transaction.dart ทุกประการ (vendor->customer) — ต่างจาก PR ตรงที่มี validUntilDate ระดับหัวเอกสาร
// (ไม่ใช่ per-line neededByDate ของ PR เพราะวันหมดอายุใบเสนอราคาเป็นค่าเดียวต่อทั้งใบตามธรรมชาติ)
import '../../utils/date_utils.dart';

const Map<String, String> quoteTransactionStatusLabelsTh = {
  'Draft': 'ร่าง',
  'Submitted': 'รออนุมัติ',
  'Approved': 'อนุมัติแล้ว',
  'Rejected': 'ถูกปฏิเสธ',
  'PartiallyConverted': 'แปลงเป็น SO บางส่วน',
  'FullyConverted': 'แปลงเป็น SO ครบแล้ว',
  'Closed': 'ปิดแล้ว',
  'Void': 'ยกเลิก',
};

const Map<String, String> quoteTransactionStatusLabelsEn = {
  'Draft': 'Draft',
  'Submitted': 'Submitted',
  'Approved': 'Approved',
  'Rejected': 'Rejected',
  'PartiallyConverted': 'Partially Converted',
  'FullyConverted': 'Fully Converted',
  'Closed': 'Closed',
  'Void': 'Void',
};

String quoteTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? quoteTransactionStatusLabelsEn[s] : quoteTransactionStatusLabelsTh[s]) ?? s;

// มิเรอร์ PrTransactionApproval ทุกประการ
class QuoteTransactionApproval {
  final int id;
  final int headerId;
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected / Skipped
  final String? remarks;

  const QuoteTransactionApproval({
    required this.id,
    required this.headerId,
    required this.approverUserId,
    required this.approverUserName,
    required this.sequenceNo,
    required this.status,
    this.remarks,
  });

  factory QuoteTransactionApproval.fromJson(Map<String, dynamic> json) => QuoteTransactionApproval(
        id: json['id'] ?? 0,
        headerId: json['header_id'] ?? 0,
        approverUserId: json['approver_user_id'] ?? 0,
        approverUserName: json['approver_user_name'] ?? '',
        sequenceNo: json['sequence_no'] ?? 1,
        status: json['status'] ?? 'Pending',
        remarks: json['remarks'],
      );
}

class QuoteTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int? preparedBy;
  final String? preparedByName;
  final int? customerId;
  final String? customerCode;
  final String? customerNameTh;
  final int? warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final int? currencyId;
  final String? currencyCode;
  final double exchangeRate;
  final DateTime? validUntilDate;
  final String status;
  final String approvalMode;
  final double totalQty;
  final double totalValueLc;
  final String? description;
  final int? branchId;
  final String? branchCode;
  final String? branchNameThai;
  // From join
  final String? docCode;
  final String? docNameThai;
  final String? docNameEng;
  final bool? isAutoNumbering;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final List<QuoteTransactionDetail> details;
  final List<QuoteTransactionApproval> approvals;

  const QuoteTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.preparedBy,
    this.preparedByName,
    this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.currencyId,
    this.currencyCode,
    this.exchangeRate = 1,
    this.validUntilDate,
    this.status = 'Draft',
    this.approvalMode = 'ALL',
    this.totalQty = 0,
    this.totalValueLc = 0,
    this.description,
    this.branchId,
    this.branchCode,
    this.branchNameThai,
    this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.isAutoNumbering,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.details = const [],
    this.approvals = const [],
  });

  factory QuoteTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return QuoteTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      preparedBy: json['prepared_by'],
      preparedByName: json['prepared_by_name'],
      customerId: json['customer_id'],
      customerCode: json['customer_code'] ?? json['c_customer_code'],
      customerNameTh: json['customer_name_th'] ?? json['c_customer_name_th'],
      warehouseId: json['warehouse_id'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      currencyId: json['currency_id'],
      currencyCode: json['currency_code'],
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      validUntilDate: json['valid_until_date'] != null ? parseLocalDate(json['valid_until_date']) : null,
      status: json['status'] ?? 'Draft',
      approvalMode: json['approval_mode'] ?? 'ALL',
      totalQty: toDouble(json['total_qty']),
      totalValueLc: toDouble(json['total_value_lc']),
      description: json['description'],
      branchId: json['branch_id'],
      branchCode: json['branch_code'],
      branchNameThai: json['branch_name_thai'],
      docCode: json['doc_code'] ?? json['d_doc_code'],
      docNameThai: json['doc_name_thai'],
      docNameEng: json['doc_name_eng'],
      isAutoNumbering: json['is_auto_numbering'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      details: (json['details'] as List<dynamic>? ?? []).map((e) => QuoteTransactionDetail.fromJson(e as Map<String, dynamic>)).toList(),
      approvals: (json['approvals'] as List<dynamic>? ?? []).map((e) => QuoteTransactionApproval.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        if (customerId != null) 'customer_id': customerId,
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (currencyId != null) 'currency_id': currencyId,
        if (currencyCode != null) 'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        if (validUntilDate != null) 'valid_until_date': formatLocalDate(validUntilDate!),
        if (description != null) 'description': description,
        if (branchId != null) 'branch_id': branchId,
        if (createdBy != null) 'created_by': createdBy,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}

class QuoteTransactionDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? uomId;
  final String? uomCode;
  final double qtyQuoted;
  final double unitPriceFc;
  final double totalValueLc;
  final double qtyConverted; // computed server-side — จำนวนที่แปลงเป็น SO แล้ว (ref_quote_detail_id, SO ไม่ Void)
  final String? description;

  double get qtyRemaining => qtyQuoted - qtyConverted;

  const QuoteTransactionDetail({
    this.id,
    this.headerId,
    required this.lineNo,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.uomId,
    this.uomCode,
    this.qtyQuoted = 0,
    this.unitPriceFc = 0,
    this.totalValueLc = 0,
    this.qtyConverted = 0,
    this.description,
  });

  factory QuoteTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return QuoteTransactionDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 0,
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      qtyQuoted: toDouble(json['qty_quoted']),
      unitPriceFc: toDouble(json['unit_price_fc']),
      totalValueLc: toDouble(json['total_value_lc']),
      qtyConverted: toDouble(json['qty_converted']),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'item_id': itemId,
        if (itemCode != null) 'item_code': itemCode,
        if (itemName != null) 'item_name': itemName,
        if (uomId != null) 'uom_id': uomId,
        'qty_quoted': qtyQuoted,
        'unit_price_fc': unitPriceFc,
        if (description != null) 'description': description,
      };
}
