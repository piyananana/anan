// lib/pr/models/pr_transaction.dart — ใบขอซื้อ (Purchase Requisition, sys_module='51', อยู่ใต้โหนด PO)
import '../../utils/date_utils.dart';

const Map<String, String> prTransactionStatusLabelsTh = {
  'Draft': 'ร่าง',
  'Submitted': 'รออนุมัติ',
  'Approved': 'อนุมัติแล้ว',
  'Rejected': 'ถูกปฏิเสธ',
  'PartiallyConverted': 'แปลงเป็น PO บางส่วน',
  'FullyConverted': 'แปลงเป็น PO ครบแล้ว',
  'Closed': 'ปิดแล้ว',
  'Void': 'ยกเลิก',
};

const Map<String, String> prTransactionStatusLabelsEn = {
  'Draft': 'Draft',
  'Submitted': 'Submitted',
  'Approved': 'Approved',
  'Rejected': 'Rejected',
  'PartiallyConverted': 'Partially Converted',
  'FullyConverted': 'Fully Converted',
  'Closed': 'Closed',
  'Void': 'Void',
};

String prTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? prTransactionStatusLabelsEn[s] : prTransactionStatusLabelsTh[s]) ?? s;

// มิเรอร์ ApPaymentRunApproval (lib/ap/models/ap_payment_run.dart) ทุกประการ
class PrTransactionApproval {
  final int id;
  final int headerId;
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected / Skipped
  final String? remarks;

  const PrTransactionApproval({
    required this.id,
    required this.headerId,
    required this.approverUserId,
    required this.approverUserName,
    required this.sequenceNo,
    required this.status,
    this.remarks,
  });

  factory PrTransactionApproval.fromJson(Map<String, dynamic> json) => PrTransactionApproval(
        id: json['id'] ?? 0,
        headerId: json['header_id'] ?? 0,
        approverUserId: json['approver_user_id'] ?? 0,
        approverUserName: json['approver_user_name'] ?? '',
        sequenceNo: json['sequence_no'] ?? 1,
        status: json['status'] ?? 'Pending',
        remarks: json['remarks'],
      );
}

class PrTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int? requestedBy;
  final String? requestedByName;
  final int? vendorId;
  final String? vendorCode;
  final String? vendorNameTh;
  final int? warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final int? currencyId;
  final String? currencyCode;
  final double exchangeRate;
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
  final List<PrTransactionDetail> details;
  final List<PrTransactionApproval> approvals;

  const PrTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.requestedBy,
    this.requestedByName,
    this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
    this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.currencyId,
    this.currencyCode,
    this.exchangeRate = 1,
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

  factory PrTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return PrTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      requestedBy: json['requested_by'],
      requestedByName: json['requested_by_name'],
      vendorId: json['vendor_id'],
      vendorCode: json['vendor_code'] ?? json['v_vendor_code'],
      vendorNameTh: json['vendor_name_th'] ?? json['v_vendor_name_th'],
      warehouseId: json['warehouse_id'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      currencyId: json['currency_id'],
      currencyCode: json['currency_code'],
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
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
      details: (json['details'] as List<dynamic>? ?? []).map((e) => PrTransactionDetail.fromJson(e as Map<String, dynamic>)).toList(),
      approvals: (json['approvals'] as List<dynamic>? ?? []).map((e) => PrTransactionApproval.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        if (vendorId != null) 'vendor_id': vendorId,
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (currencyId != null) 'currency_id': currencyId,
        if (currencyCode != null) 'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        if (description != null) 'description': description,
        if (branchId != null) 'branch_id': branchId,
        if (createdBy != null) 'created_by': createdBy,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}

class PrTransactionDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? uomId;
  final String? uomCode;
  final double qtyRequested;
  final DateTime? neededByDate;
  final double estimatedUnitCost;
  final double totalValueLc;
  final double qtyConverted; // computed server-side — จำนวนที่แปลงเป็น PO แล้ว (ref_pr_detail_id, PO ไม่ Void)
  final String? description;

  double get qtyRemaining => qtyRequested - qtyConverted;

  const PrTransactionDetail({
    this.id,
    this.headerId,
    required this.lineNo,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.uomId,
    this.uomCode,
    this.qtyRequested = 0,
    this.neededByDate,
    this.estimatedUnitCost = 0,
    this.totalValueLc = 0,
    this.qtyConverted = 0,
    this.description,
  });

  factory PrTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return PrTransactionDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 0,
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      qtyRequested: toDouble(json['qty_requested']),
      neededByDate: json['needed_by_date'] != null ? parseLocalDate(json['needed_by_date']) : null,
      estimatedUnitCost: toDouble(json['estimated_unit_cost']),
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
        'qty_requested': qtyRequested,
        if (neededByDate != null) 'needed_by_date': formatLocalDate(neededByDate!),
        'estimated_unit_cost': estimatedUnitCost,
        if (description != null) 'description': description,
      };
}
