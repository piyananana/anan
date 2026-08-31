// lib/im/models/im_transaction.dart
import '../../utils/date_utils.dart';

// ── Status labels (Draft / Posted / Void) ────────────────────────────────────
const Map<String, String> imTransactionStatusLabels = {
  'Draft':  'ร่าง',
  'Posted': 'Post แล้ว',
  'Void':   'ยกเลิก',
};

const Map<String, String> imTransactionStatusLabelsEn = {
  'Draft':  'Draft',
  'Posted': 'Posted',
  'Void':   'Void',
};

String imTransactionStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? imTransactionStatusLabelsEn[s] : imTransactionStatusLabels[s]) ?? s;

const List<String> imCostingMethodsRequiringUnitCostOnIncrease = ['AVG', 'FIFO', 'SPECIFIC'];

// ── Header ─────────────────────────────────────────────────────────────────
class ImTransactionHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int periodId;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final int? toWarehouseId;
  final String? toWarehouseCode;
  final String? toWarehouseNameTh;
  final int? vendorId; // GRN ('10'/'11'/'12') เท่านั้น
  final String? vendorCode;
  final String? vendorNameTh;
  final int? linkedApTransactionId; // GRN Billing ('11'/'12' หลัง Post AP/GL) เท่านั้น — ใบตั้งหนี้ AP ที่ระบบสร้างให้อัตโนมัติ
  final int? customerId; // DLN ('30'/'31'/'32') เท่านั้น
  final String? customerCode;
  final String? customerNameTh;
  final int? linkedArTransactionId; // DLN Billing ('31'/'32' หลัง Post AR/GL) เท่านั้น — ใบแจ้งหนี้ AR ที่ระบบสร้างให้อัตโนมัติ
  final String? refNo;
  final int? refDocId;
  final String? refDocNo;
  final String? description;
  final String status;
  final int? glEntryId;
  final double totalQty;
  final double totalValueLc;
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
  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ImTransactionHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.periodId = 0,
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.toWarehouseId,
    this.toWarehouseCode,
    this.toWarehouseNameTh,
    this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
    this.linkedApTransactionId,
    this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.linkedArTransactionId,
    this.refNo,
    this.refDocId,
    this.refDocNo,
    this.description,
    this.status = 'Draft',
    this.glEntryId,
    this.totalQty = 0,
    this.totalValueLc = 0,
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

  factory ImTransactionHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ImTransactionHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      periodId: json['period_id'] ?? 0,
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      toWarehouseId: json['to_warehouse_id'],
      toWarehouseCode: json['to_warehouse_code'],
      toWarehouseNameTh: json['to_warehouse_name_th'],
      vendorId: json['vendor_id'],
      vendorCode: json['vendor_code'],
      vendorNameTh: json['vendor_name_th'],
      linkedApTransactionId: json['linked_ap_transaction_id'],
      customerId: json['customer_id'],
      customerCode: json['customer_code'],
      customerNameTh: json['customer_name_th'],
      linkedArTransactionId: json['linked_ar_transaction_id'],
      refNo: json['ref_no'],
      refDocId: json['ref_doc_id'],
      refDocNo: json['ref_doc_no'],
      description: json['description'],
      status: json['status'] ?? 'Draft',
      glEntryId: json['gl_entry_id'],
      totalQty: toDouble(json['total_qty']),
      totalValueLc: toDouble(json['total_value_lc']),
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
        'warehouse_id': warehouseId,
        if (toWarehouseId != null) 'to_warehouse_id': toWarehouseId,
        if (vendorId != null) 'vendor_id': vendorId,
        if (customerId != null) 'customer_id': customerId,
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

// ── Detail (count line) ──────────────────────────────────────────────────────
class ImTransactionDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? locationId;
  final String? locationCode;
  final int? toLocationId; // TRF (โอนสินค้า) เท่านั้น — ตำแหน่งจัดเก็บฝั่งปลายทาง
  final String? toLocationCode;
  final String? lotNo;
  final String? serialNo;
  final int? uomId;
  final String? uomCode;
  final double systemQty;
  final double countedQty;
  final double? qty; // variance — null until Posted (server computes from live balance at Post time)
  final double? unitCost;
  final double? billedUnitCost; // '12' (รับสินค้า รอตั้งหนี้) เท่านั้น — ต้นทุนจริงตามใบกำกับ อาจต่างจาก unitCost
  final double? unitPrice; // '31'/'32' (DLN + ตั้งหนี้ลูกหนี้) เท่านั้น — ราคาขายต่อหน่วย ใช้คำนวณรายได้ตอนสร้างใบแจ้งหนี้ AR
  final double? totalValueLc;
  final String? description;

  const ImTransactionDetail({
    this.id,
    this.headerId,
    this.lineNo = 1,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.locationId,
    this.locationCode,
    this.toLocationId,
    this.toLocationCode,
    this.lotNo,
    this.serialNo,
    this.uomId,
    this.uomCode,
    this.systemQty = 0,
    this.countedQty = 0,
    this.qty,
    this.unitCost,
    this.billedUnitCost,
    this.unitPrice,
    this.totalValueLc,
    this.description,
  });

  double get variance => countedQty - systemQty;

  factory ImTransactionDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    double? toDoubleN(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return ImTransactionDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 1,
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      locationId: json['location_id'],
      locationCode: json['location_code'],
      toLocationId: json['to_location_id'],
      toLocationCode: json['to_location_code'],
      lotNo: json['lot_no'],
      serialNo: json['serial_no'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      systemQty: toDouble(json['system_qty']),
      countedQty: toDouble(json['counted_qty']),
      qty: toDoubleN(json['qty']),
      unitCost: toDoubleN(json['unit_cost']),
      billedUnitCost: toDoubleN(json['billed_unit_cost']),
      unitPrice: toDoubleN(json['unit_price']),
      totalValueLc: toDoubleN(json['total_value_lc']),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'item_id': itemId,
        if (itemCode != null) 'item_code': itemCode,
        if (itemName != null) 'item_name': itemName,
        if (locationId != null) 'location_id': locationId,
        if (toLocationId != null) 'to_location_id': toLocationId,
        if (lotNo != null) 'lot_no': lotNo,
        if (serialNo != null) 'serial_no': serialNo,
        if (uomId != null) 'uom_id': uomId,
        'system_qty': systemQty,
        'counted_qty': countedQty,
        if (unitCost != null) 'unit_cost': unitCost,
        if (billedUnitCost != null) 'billed_unit_cost': billedUnitCost,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (description != null) 'description': description,
      };
}

// ── Wrapper ───────────────────────────────────────────────────────────────
class ImTransaction {
  final ImTransactionHeader header;
  final List<ImTransactionDetail> details;

  const ImTransaction({required this.header, this.details = const []});

  factory ImTransaction.fromJson(Map<String, dynamic> json) => ImTransaction(
        header: ImTransactionHeader.fromJson(json),
        details: (json['details'] as List<dynamic>? ?? [])
            .map((e) => ImTransactionDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
