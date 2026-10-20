// lib/so/models/so_transaction.dart — ใบสั่งขาย (Sale Order, sys_module='41') — มิเรอร์ po_transaction.dart ทุกประการ
// เพียงสลับ vendor->customer เท่านั้น ยังไม่มีขั้น "ใบเสนอราคา" (Sale Quote) นำหน้าเหมือน PR นำหน้า PO
import '../../utils/date_utils.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../cd/models/cd_doc_salesperson.dart';

const Map<String, String> soTransactionStatusLabelsTh = {
  'Draft': 'ร่าง',
  'Submitted': 'รออนุมัติ',
  'Rejected': 'ถูกปฏิเสธ',
  'Approved': 'อนุมัติแล้ว',
  'PartiallyDelivered': 'ส่งสินค้าบางส่วน',
  'FullyDelivered': 'ส่งสินค้าครบแล้ว',
  'Closed': 'ปิดแล้ว',
  'Void': 'ยกเลิก',
  'Deleted': 'ลบแล้ว',
};

const Map<String, String> soTransactionStatusLabelsEn = {
  'Draft': 'Draft',
  'Submitted': 'Submitted',
  'Rejected': 'Rejected',
  'Approved': 'Approved',
  'PartiallyDelivered': 'Partially Delivered',
  'FullyDelivered': 'Fully Delivered',
  'Closed': 'Closed',
  'Void': 'Void',
  'Deleted': 'Deleted',
};

String soTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? soTransactionStatusLabelsEn[s] : soTransactionStatusLabelsTh[s]) ?? s;

class SoTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int customerId;
  final String? customerCode;
  final String? customerNameTh;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final int? currencyId;
  final String? currencyCode;
  final double exchangeRate;
  final DateTime? dueDate;
  final String status;
  final double totalQty;
  final double totalValueLc;
  final String? description;
  final int? branchId;
  final String? branchCode;
  final String? branchNameThai;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? voidReason;
  // คิวผู้อนุมัติ (utils/docApproval.js) — ALL / ANY + ขั้นตอนแต่ละลำดับ
  final String? approvalMode;
  final List<DocApprovalStep> approvals;
  // ถอย / ยกเลิก / ลบ + ประวัติ (เฉพาะ fetchRow)
  final DocActions actions;
  final int? refQuoteId; // ใบเสนอราคา (Quote) ต้นทาง — สะดวก/แสดงผลเท่านั้น
  final String? refQuoteDocNo;
  // From join
  final String? docCode;
  final String? docNameThai;
  final String? docNameEng;
  final bool? isAutoNumbering;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final List<SoTransactionDetail> details;
  // พนักงานขาย + สัดส่วน (จำนวนเงินจากมูลค่ารวมสกุลท้องถิ่น)
  final List<DocSalesperson> salespersons;

  const SoTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    required this.customerId,
    this.customerCode,
    this.customerNameTh,
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.currencyId,
    this.currencyCode,
    this.exchangeRate = 1,
    this.dueDate,
    this.status = 'Draft',
    this.totalQty = 0,
    this.totalValueLc = 0,
    this.description,
    this.branchId,
    this.branchCode,
    this.branchNameThai,
    this.approvedAt,
    this.approvedBy,
    this.voidReason,
    this.approvalMode,
    this.approvals = const [],
    this.actions = const DocActions(),
    this.refQuoteId,
    this.refQuoteDocNo,
    this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.isAutoNumbering,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.details = const [],
    this.salespersons = const [],
  });

  factory SoTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return SoTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      customerId: json['customer_id'] ?? 0,
      customerCode: json['customer_code'] ?? json['c_customer_code'],
      customerNameTh: json['customer_name_th'] ?? json['c_customer_name_th'],
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      currencyId: json['currency_id'],
      currencyCode: json['currency_code'],
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      dueDate: json['due_date'] != null ? parseLocalDate(json['due_date']) : null,
      status: json['status'] ?? 'Draft',
      totalQty: toDouble(json['total_qty']),
      totalValueLc: toDouble(json['total_value_lc']),
      description: json['description'],
      branchId: json['branch_id'],
      branchCode: json['branch_code'],
      branchNameThai: json['branch_name_thai'],
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString())?.toLocal() : null,
      approvedBy: json['approved_by'],
      voidReason: json['void_reason'],
      approvalMode: json['approval_mode'],
      approvals: DocApprovalStep.listFromJson(json['approvals']),
      actions: DocActions.fromJson(json),
      refQuoteId: json['ref_quote_id'],
      refQuoteDocNo: json['ref_quote_doc_no'],
      docCode: json['doc_code'] ?? json['d_doc_code'],
      docNameThai: json['doc_name_thai'],
      docNameEng: json['doc_name_eng'],
      isAutoNumbering: json['is_auto_numbering'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      details: (json['details'] as List<dynamic>? ?? []).map((e) => SoTransactionDetail.fromJson(e as Map<String, dynamic>)).toList(),
      salespersons: DocSalesperson.listFromJson(json['salespersons']),
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        'customer_id': customerId,
        'warehouse_id': warehouseId,
        if (currencyId != null) 'currency_id': currencyId,
        if (currencyCode != null) 'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        if (dueDate != null) 'due_date': formatLocalDate(dueDate!),
        if (description != null) 'description': description,
        if (refQuoteId != null) 'ref_quote_id': refQuoteId,
        if (branchId != null) 'branch_id': branchId,
        if (createdBy != null) 'created_by': createdBy,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}

class SoTransactionDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? uomId;
  final String? uomCode;
  final double qtyOrdered;
  final double unitPriceFc;
  final double totalValueLc;
  final double qtyDelivered; // computed server-side — จำนวนที่ส่งแล้วผ่าน DLN ที่ Posted/Delivered (ref_so_detail_id)
  final int? refQuoteDetailId; // บรรทัดใบเสนอราคา (Quote) ต้นทาง ถ้าบรรทัดนี้แปลงมาจาก Quote
  final String? description;

  double get qtyRemaining => qtyOrdered - qtyDelivered;

  const SoTransactionDetail({
    this.id,
    this.headerId,
    required this.lineNo,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.uomId,
    this.uomCode,
    this.qtyOrdered = 0,
    this.unitPriceFc = 0,
    this.totalValueLc = 0,
    this.qtyDelivered = 0,
    this.refQuoteDetailId,
    this.description,
  });

  factory SoTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return SoTransactionDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 0,
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      qtyOrdered: toDouble(json['qty_ordered']),
      unitPriceFc: toDouble(json['unit_price_fc']),
      totalValueLc: toDouble(json['total_value_lc']),
      qtyDelivered: toDouble(json['qty_delivered']),
      refQuoteDetailId: json['ref_quote_detail_id'],
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
        'qty_ordered': qtyOrdered,
        if (refQuoteDetailId != null) 'ref_quote_detail_id': refQuoteDetailId,
        'unit_price_fc': unitPriceFc,
        if (description != null) 'description': description,
      };
}
