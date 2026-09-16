// lib/po/models/po_transaction.dart — ใบสั่งซื้อ (Purchase Order, sys_module='51')
import '../../utils/date_utils.dart';

const Map<String, String> poTransactionStatusLabelsTh = {
  'Draft': 'ร่าง',
  'Approved': 'อนุมัติแล้ว',
  'PartiallyReceived': 'รับสินค้าบางส่วน',
  'FullyReceived': 'รับสินค้าครบแล้ว',
  'Closed': 'ปิดแล้ว',
  'Void': 'ยกเลิก',
};

const Map<String, String> poTransactionStatusLabelsEn = {
  'Draft': 'Draft',
  'Approved': 'Approved',
  'PartiallyReceived': 'Partially Received',
  'FullyReceived': 'Fully Received',
  'Closed': 'Closed',
  'Void': 'Void',
};

String poTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? poTransactionStatusLabelsEn[s] : poTransactionStatusLabelsTh[s]) ?? s;

class PoTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int vendorId;
  final String? vendorCode;
  final String? vendorNameTh;
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
  // From join
  final String? docCode;
  final String? docNameThai;
  final String? docNameEng;
  final bool? isAutoNumbering;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final List<PoTransactionDetail> details;

  const PoTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    required this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
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
    this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.isAutoNumbering,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.details = const [],
  });

  factory PoTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return PoTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      vendorId: json['vendor_id'] ?? 0,
      vendorCode: json['vendor_code'] ?? json['v_vendor_code'],
      vendorNameTh: json['vendor_name_th'] ?? json['v_vendor_name_th'],
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
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      approvedBy: json['approved_by'],
      docCode: json['doc_code'] ?? json['d_doc_code'],
      docNameThai: json['doc_name_thai'],
      docNameEng: json['doc_name_eng'],
      isAutoNumbering: json['is_auto_numbering'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      details: (json['details'] as List<dynamic>? ?? []).map((e) => PoTransactionDetail.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        'vendor_id': vendorId,
        'warehouse_id': warehouseId,
        if (currencyId != null) 'currency_id': currencyId,
        if (currencyCode != null) 'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        if (dueDate != null) 'due_date': formatLocalDate(dueDate!),
        if (description != null) 'description': description,
        if (branchId != null) 'branch_id': branchId,
        if (createdBy != null) 'created_by': createdBy,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}

class PoTransactionDetail {
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
  final double qtyReceived; // computed server-side — จำนวนที่รับแล้วผ่าน GRN ที่ Posted/Received (ref_po_detail_id)
  final String? description;

  double get qtyRemaining => qtyOrdered - qtyReceived;

  const PoTransactionDetail({
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
    this.qtyReceived = 0,
    this.description,
  });

  factory PoTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return PoTransactionDetail(
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
      qtyReceived: toDouble(json['qty_received']),
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
        'unit_price_fc': unitPriceFc,
        if (description != null) 'description': description,
      };
}
