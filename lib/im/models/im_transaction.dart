// lib/im/models/im_transaction.dart
import '../../utils/date_utils.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../cd/models/cd_doc_salesperson.dart';
import '../../sa/models/sa_credit_approval.dart';

// ── Status labels (Draft / Posted / Void) ────────────────────────────────────
const Map<String, String> imTransactionStatusLabels = {
  'Draft':  'ร่าง',
  'Posted': 'Post แล้ว',
  'Received':  'รับแล้ว รอตั้งหนี้',
  'Delivered': 'ส่งแล้ว รอตั้งหนี้',
  'Void':   'ยกเลิก',
  'Deleted': 'ลบแล้ว',
};

const Map<String, String> imTransactionStatusLabelsEn = {
  'Draft':  'Draft',
  'Posted': 'Posted',
  'Received':  'Received',
  'Delivered': 'Delivered',
  'Void':   'Void',
  'Deleted': 'Deleted',
};

// สถานะที่เลือกกรองได้ในรายงาน IM (ตรงกับ IM_REPORT_STATUSES ฝั่ง backend)
const List<String> imReportStatuses = ['Draft', 'Posted', 'Received', 'Delivered', 'Void', 'Deleted'];

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
  final int? refImTransactionId; // '15'/'35' (คืนสินค้าผู้ขาย/รับคืนจากลูกค้า) เท่านั้น — เอกสาร GRN/DLN ต้นฉบับที่จะคืน
  final String? refImTransactionDocNo; // จาก join — เลขที่เอกสารต้นฉบับ ใช้แสดงผลเท่านั้น
  final String? refImTransactionStatus; // จาก join — สถานะเอกสารต้นฉบับ ('15' เตือนผลกระทบก่อน Post)
  final String? refImSysDocType;
  final int? refPoId; // '10'/'11'/'12' เท่านั้น — PO ที่ GRN นี้อ้างอิง (สะดวก/แสดงผล — การตรวจจริงอยู่ระดับบรรทัด)
  final String? refPoDocNo; // จาก join — เลขที่ PO ใช้แสดงผลเท่านั้น
  final int? refSoId; // '30'/'31'/'32' เท่านั้น — SO ที่ DLN นี้อ้างอิง (สะดวก/แสดงผล — การตรวจจริงอยู่ระดับบรรทัด)
  final String? refSoDocNo; // จาก join — เลขที่ SO ใช้แสดงผลเท่านั้น
  final String? customerPoNo; // '30'/'31'/'32' — เลขที่ใบสั่งซื้อของลูกค้า (ค่าเริ่มต้นจาก SO, แก้ได้)
  final DateTime? customerPoDate;
  final int? refMoId; // '90'/'95' เท่านั้น — ใบสั่งผลิต (MO) ที่ธุรกรรมนี้อ้างอิง (สะดวก/แสดงผล — การตรวจจริงอยู่ระดับบรรทัด)
  final String? refMoDocNo; // จาก join — เลขที่ MO ใช้แสดงผลเท่านั้น
  // สกุลเงินต่างประเทศ (ฝั่งรับจากผู้ขายเท่านั้น — GRN family '10'/'11'/'12'/'13' + คืนสินค้า/AP CN/DN '15'/'20'/'25')
  // unit_cost (LC) ยังคงใช้ตีมูลค่าสต็อก/โพสต์ GL เหมือนเดิมเสมอ — ฟิลด์นี้ควบคุมแค่การแสดงผล/กรอกข้อมูลเท่านั้น
  final int? currencyId;
  final String? currencyCode;
  final double exchangeRate;
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
    this.refImTransactionId,
    this.refImTransactionDocNo,
    this.refImTransactionStatus,
    this.refImSysDocType,
    this.refPoId,
    this.refPoDocNo,
    this.refSoId,
    this.refSoDocNo,
    this.customerPoNo,
    this.customerPoDate,
    this.refMoId,
    this.refMoDocNo,
    this.currencyId,
    this.currencyCode,
    this.exchangeRate = 1,
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
      refImTransactionId: json['ref_im_transaction_id'],
      refImTransactionDocNo: json['ref_im_transaction_doc_no'],
      refImTransactionStatus: json['ref_im_transaction_status'],
      refImSysDocType: json['ref_im_sys_doc_type']?.toString(),
      refPoId: json['ref_po_id'],
      refPoDocNo: json['ref_po_doc_no'],
      refSoId: json['ref_so_id'],
      refSoDocNo: json['ref_so_doc_no'],
      customerPoNo: json['customer_po_no'],
      customerPoDate: json['customer_po_date'] != null ? parseLocalDate(json['customer_po_date']) : null,
      refMoId: json['ref_mo_id'],
      refMoDocNo: json['ref_mo_doc_no'],
      currencyId: json['currency_id'],
      currencyCode: json['currency_code'],
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
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
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() : null,
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
        if (refImTransactionId != null) 'ref_im_transaction_id': refImTransactionId,
        if (refPoId != null) 'ref_po_id': refPoId,
        if (refSoId != null) 'ref_so_id': refSoId,
        if (customerPoNo != null) 'customer_po_no': customerPoNo,
        if (customerPoDate != null) 'customer_po_date': formatLocalDate(customerPoDate!),
        if (refMoId != null) 'ref_mo_id': refMoId,
        if (currencyId != null) 'currency_id': currencyId,
        if (currencyCode != null) 'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
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
  final double? unitCostFc; // ราคาที่ผู้ใช้กรอกจริงในสกุลเงินผู้ขาย (ถ้าไม่ใช่ THB) — unitCost (LC) = unitCostFc * exchangeRate
  final double? billedUnitCost; // '12' (รับสินค้า รอตั้งหนี้) เท่านั้น — ต้นทุนจริงตามใบกำกับ อาจต่างจาก unitCost
  final double? billedUnitCostFc; // เหมือน unitCostFc แต่สำหรับ billedUnitCost
  final double? unitPrice; // '31'/'32' (DLN + ตั้งหนี้ลูกหนี้) เท่านั้น — ราคาขายต่อหน่วย ใช้คำนวณรายได้ตอนสร้างใบแจ้งหนี้ AR
  final bool isFree; // ของแถม — ฝั่งรับ (GR family) ยกเว้นบังคับ unitCost>0, ฝั่งขาย (DL family) auto-zero+lock unitPrice
  final String? vatType; // ใช้เฉพาะประเภทเอกสารที่สร้าง/อ้างอิงใบกำกับ AP/AR อัตโนมัติ — vat_code อ้างอิง cd_vat_rate
  final double? vatRate; // snapshot อัตรา ณ ตอนเลือก (ไม่ผูกกับ cd_vat_rate อีกทีตอน Post เหมือน AR/AP เอง)
  final int? refImTransactionDetailId; // '15'/'35' เท่านั้น — บรรทัดต้นฉบับ (GRN/DLN) ที่บรรทัดนี้คืน ใช้ตรวจคงเหลือที่คืนได้
  final int? refPoDetailId; // '10'/'11'/'12' เท่านั้น — บรรทัด PO ต้นฉบับที่บรรทัดนี้รับตาม ใช้ตรวจคงเหลือที่รับได้
  final double qtyReceived; // จาก join — จำนวนที่รับไปแล้วของบรรทัด PO นี้ (จาก po_transaction_detail picker เท่านั้น ไม่ใช่ตัว GRN เอง)
  final int? refSoDetailId; // '30'/'31'/'32' เท่านั้น — บรรทัด SO ต้นฉบับที่บรรทัดนี้ส่งตาม ใช้ตรวจคงเหลือที่ส่งได้
  final int? refMoComponentDetailId; // '90' เท่านั้น — บรรทัดส่วนประกอบ MO ต้นฉบับที่บรรทัดนี้เบิกตาม ใช้ตรวจคงเหลือที่เบิกได้
  final int? refMoOutputDetailId; // '95' เท่านั้น — บรรทัดผลผลิต MO ต้นฉบับที่บรรทัดนี้รับตาม ใช้ตรวจคงเหลือที่รับได้
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
    this.unitCostFc,
    this.billedUnitCost,
    this.billedUnitCostFc,
    this.unitPrice,
    this.isFree = false,
    this.vatType,
    this.vatRate,
    this.refImTransactionDetailId,
    this.refPoDetailId,
    this.qtyReceived = 0,
    this.refSoDetailId,
    this.refMoComponentDetailId,
    this.refMoOutputDetailId,
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
      unitCostFc: toDoubleN(json['unit_cost_fc']),
      billedUnitCost: toDoubleN(json['billed_unit_cost']),
      billedUnitCostFc: toDoubleN(json['billed_unit_cost_fc']),
      unitPrice: toDoubleN(json['unit_price']),
      isFree: json['is_free'] ?? false,
      vatType: json['vat_type'],
      vatRate: toDoubleN(json['vat_rate']),
      refImTransactionDetailId: json['ref_im_transaction_detail_id'],
      refPoDetailId: json['ref_po_detail_id'],
      qtyReceived: toDouble(json['qty_received']),
      refSoDetailId: json['ref_so_detail_id'],
      refMoComponentDetailId: json['ref_mo_component_detail_id'],
      refMoOutputDetailId: json['ref_mo_output_detail_id'],
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
        if (unitCostFc != null) 'unit_cost_fc': unitCostFc,
        if (billedUnitCost != null) 'billed_unit_cost': billedUnitCost,
        if (billedUnitCostFc != null) 'billed_unit_cost_fc': billedUnitCostFc,
        if (unitPrice != null) 'unit_price': unitPrice,
        'is_free': isFree,
        if (vatType != null) 'vat_type': vatType,
        if (vatRate != null) 'vat_rate': vatRate,
        if (refImTransactionDetailId != null) 'ref_im_transaction_detail_id': refImTransactionDetailId,
        if (refPoDetailId != null) 'ref_po_detail_id': refPoDetailId,
        if (refSoDetailId != null) 'ref_so_detail_id': refSoDetailId,
        if (refMoComponentDetailId != null) 'ref_mo_component_detail_id': refMoComponentDetailId,
        if (refMoOutputDetailId != null) 'ref_mo_output_detail_id': refMoOutputDetailId,
        if (description != null) 'description': description,
      };
}

// ── Returnable doc/line (สำหรับ document picker ของ '15'/'35') ─────────────
// เอกสาร GRN/DLN ที่ Post แล้ว ให้เลือกเป็นต้นฉบับสำหรับคืนสินค้า — ดู fetchReturnableDocs ใน imTransactionController.js
class ImReturnableDoc {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status;
  final int? vendorId;
  final String? vendorCode;
  final String? vendorNameTh;
  final int? customerId;
  final String? customerCode;
  final String? customerNameTh;
  final String docCode;
  final String sysDocType;
  final String? currencyCode; // '15' คืนตามสกุลเงิน/อัตราแลกเปลี่ยนของใบรับสินค้าต้นฉบับ
  final double exchangeRate;

  const ImReturnableDoc({
    required this.id,
    required this.docNo,
    required this.docDate,
    required this.status,
    this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
    this.customerId,
    this.customerCode,
    this.customerNameTh,
    required this.docCode,
    required this.sysDocType,
    this.currencyCode,
    this.exchangeRate = 1,
  });

  factory ImReturnableDoc.fromJson(Map<String, dynamic> json) => ImReturnableDoc(
        id: json['id'],
        docNo: json['doc_no'] ?? '',
        docDate: parseLocalDate(json['doc_date']),
        status: json['status'] ?? '',
        vendorId: json['vendor_id'],
        vendorCode: json['vendor_code'],
        vendorNameTh: json['vendor_name_th'],
        customerId: json['customer_id'],
        customerCode: json['customer_code'],
        customerNameTh: json['customer_name_th'],
        docCode: json['doc_code'] ?? '',
        sysDocType: json['sys_doc_type']?.toString() ?? '',
        currencyCode: json['currency_code'],
        exchangeRate: (double.tryParse(json['exchange_rate']?.toString() ?? '') ?? 0) > 0
            ? double.parse(json['exchange_rate'].toString())
            : 1,
      );
}

// บรรทัดของเอกสารต้นฉบับ พร้อมจำนวนคงเหลือที่คืนได้ (originalQty ลบผลรวมที่ถูกคืนไปแล้ว) — ดู fetchReturnableLines
class ImReturnableLine {
  final int id;
  final int lineNo;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? locationId;
  final String? locationCode;
  final String? lotNo;
  final String? serialNo;
  final int? uomId;
  final String? uomCode;
  final double originalQty;
  final double remainingQty;
  final double? unitCost;
  final double? unitPrice; // ราคาขายของบรรทัดใบส่งสินค้าต้นฉบับ ('35' ใช้เป็นราคาเริ่มต้นของใบลดหนี้)
  final String? vatType;
  final double? vatRate; // อัตรา VAT ณ ตอนขาย — ใบลดหนี้ควรกลับรายการด้วยอัตราเดียวกัน
  final double? returnPriceFc; // ราคาซื้อในสกุลเงินของใบรับสินค้าต้นฉบับ ('15' ใช้เป็นราคาเริ่มต้นของใบลดหนี้ AP)

  const ImReturnableLine({
    required this.id,
    required this.lineNo,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.locationId,
    this.locationCode,
    this.lotNo,
    this.serialNo,
    this.uomId,
    this.uomCode,
    required this.originalQty,
    required this.remainingQty,
    this.unitCost,
    this.unitPrice,
    this.vatType,
    this.vatRate,
    this.returnPriceFc,
  });

  factory ImReturnableLine.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    double? toDoubleN(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return ImReturnableLine(
      id: json['id'],
      lineNo: json['line_no'] ?? 1,
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      locationId: json['location_id'],
      locationCode: json['location_code'],
      lotNo: json['lot_no'],
      serialNo: json['serial_no'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      originalQty: toDouble(json['original_qty']),
      remainingQty: toDouble(json['remaining_qty']),
      unitCost: toDoubleN(json['unit_cost']),
      unitPrice: toDoubleN(json['unit_price']),
      vatType: json['vat_type'],
      vatRate: toDoubleN(json['vat_rate']),
      returnPriceFc: toDoubleN(json['return_price_fc']),
    );
  }
}

// ── เหตุที่ถอย / ยกเลิก / ลบไม่ได้ (backend ส่ง code + ref + ข้อความภาษาไทย) ─────────
class ImDocBlock {
  final String code;
  final String? ref;
  final String message;

  const ImDocBlock({required this.code, this.ref, required this.message});

  static ImDocBlock? fromJson(dynamic json) => json is Map<String, dynamic>
      ? ImDocBlock(code: json['code'] ?? '', ref: json['ref'] as String?, message: json['message'] ?? '')
      : null;

  static const Map<String, String> _en = {
    'NOT_REVERSIBLE':      'Only posted documents can be reversed',
    'NOT_POSTED':          'Only posted documents can be voided (delete a draft instead)',
    'NOT_DRAFT':           'Posted documents cannot be deleted — reverse to draft first',
    'STOCK_COUNT':         'Created from a stock count sheet — use the stock count screen',
    'MO_CLOSED':           'The referenced manufacturing order is closed',
    'PERIOD_CLOSED':       'The accounting period of this document is closed',
    'RETURNED':            'A return document references this document',
    'CONSIGNMENT_SETTLED': 'Consignment stock in this document has been settled with the consignor',
    'STOCK_USED':          'Stock received by this document has already been issued',
    'INSUFFICIENT_STOCK':  'Current stock balance is not enough to reverse',
    'AP_LINKED':           'The AP invoice created from this document cannot be reversed or voided',
    'AR_LINKED':           'The AR invoice created from this document cannot be reversed or voided',
    'VOIDED':              'This document has been voided or deleted',
    'AP_BLOCKED':          'The AP invoice has been paid, applied, or is in a payment run / FX revaluation',
  };

  String text(bool isEnglish) =>
      isEnglish ? '${_en[code] ?? code}${ref != null ? ' ($ref)' : ''}' : message;
}

// ── Wrapper ───────────────────────────────────────────────────────────────
class ImTransaction {
  final ImTransactionHeader header;
  final List<ImTransactionDetail> details;
  final ImDocBlock? reverseBlock;
  final String? reverseTo; // Draft / Received / Delivered
  final ImDocBlock? voidBlock;
  final ImDocBlock? deleteBlock;
  final List<DocReverseLog> reverseHistory;
  // พนักงานขาย + สัดส่วน (เอกสารฝั่งขาย) — คัดลอกไปใบ AR ที่สร้างอัตโนมัติ
  final List<DocSalesperson> salespersons;
  // คำขออนุมัติเกินวงเงินเครดิต (เอกสารฝั่งขาย)
  final DocCreditState credit;

  const ImTransaction({
    required this.header, this.details = const [],
    this.reverseBlock, this.reverseTo, this.voidBlock, this.deleteBlock, this.reverseHistory = const [],
    this.salespersons = const [],
    this.credit = const DocCreditState(),
  });

  factory ImTransaction.fromJson(Map<String, dynamic> json) => ImTransaction(
        header: ImTransactionHeader.fromJson(json),
        details: (json['details'] as List<dynamic>? ?? [])
            .map((e) => ImTransactionDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
        reverseBlock: ImDocBlock.fromJson(json['reverse_block']),
        reverseTo: json['reverse_to'] as String?,
        voidBlock: ImDocBlock.fromJson(json['void_block']),
        deleteBlock: ImDocBlock.fromJson(json['delete_block']),
        reverseHistory: DocReverseLog.listFromJson(json['reverse_history']),
        salespersons: DocSalesperson.listFromJson(json['salespersons']),
        credit: DocCreditState.fromJson(json, json['credit_approvals']),
      );
}
