// lib/im/models/im_stock_count.dart
import '../../utils/date_utils.dart';

// Draft (ตรวจสอบผังก่อนบันทึก) -> Posted (บันทึกใบตรวจนับ — ล็อครายการ, system_qty freeze) ->
// Approved (ตรวจผล+อนุมัติ) -> Closed (บันทึกปรับยอด — สร้าง+โพสต์ im_transaction AJS อัตโนมัติ)
// กิ่ง Void แยกจาก Draft/Posted ได้
const Map<String, String> imStockCountStatusLabels = {
  'Draft':    'ร่าง',
  'Posted':   'บันทึกใบตรวจนับแล้ว',
  'Approved': 'อนุมัติแล้ว',
  'Closed':   'ปิดแล้ว',
  'Void':     'ยกเลิก',
};

const Map<String, String> imStockCountStatusLabelsEn = {
  'Draft':    'Draft',
  'Posted':   'Posted',
  'Approved': 'Approved',
  'Closed':   'Closed',
  'Void':     'Void',
};

String imStockCountStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? imStockCountStatusLabelsEn[s] : imStockCountStatusLabels[s]) ?? s;

// ── Header ─────────────────────────────────────────────────────────────────
class ImStockCountHeader {
  final int id;
  final String countNo;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final DateTime countDate;
  final String? description;
  final String status;
  final int printCount;
  final int? imTransactionId;
  final String? imTransactionDocNo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? closedAt;
  final String? closedBy;

  const ImStockCountHeader({
    this.id = 0,
    this.countNo = '',
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    required this.countDate,
    this.description,
    this.status = 'Draft',
    this.printCount = 0,
    this.imTransactionId,
    this.imTransactionDocNo,
    this.createdAt, this.updatedAt, this.createdBy, this.updatedBy,
    this.approvedAt, this.approvedBy,
    this.closedAt, this.closedBy,
  });

  factory ImStockCountHeader.fromJson(Map<String, dynamic> json) => ImStockCountHeader(
        id: json['id'] ?? 0,
        countNo: json['count_no'] ?? '',
        warehouseId: json['warehouse_id'] ?? 0,
        warehouseCode: json['warehouse_code'],
        warehouseNameTh: json['warehouse_name_th'],
        warehouseNameEn: json['warehouse_name_en'],
        countDate: parseLocalDate(json['count_date']),
        description: json['description'],
        status: json['status'] ?? 'Draft',
        printCount: json['print_count'] ?? 0,
        imTransactionId: json['im_transaction_id'],
        imTransactionDocNo: json['im_transaction_doc_no'],
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
        createdBy: json['created_by'],
        updatedBy: json['updated_by'],
        approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
        approvedBy: json['approved_by'],
        closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'].toString()) : null,
        closedBy: json['closed_by'],
      );

  Map<String, dynamic> toJson() => {
        'warehouse_id': warehouseId,
        'count_date': formatLocalDate(countDate),
        if (description != null) 'description': description,
      };
}

// ── Detail (count line) ──────────────────────────────────────────────────────
class ImStockCountDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? locationId;
  final String? locationCode;
  final int? locationSortOrder;
  final String? lotNo;
  final String? serialNo;
  final int? uomId;
  final String? uomCode;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double? systemQty;
  final double? countedQty;
  final double? unitCost;
  final String? countedBy;
  final DateTime? countedAt;
  final String? remark;

  const ImStockCountDetail({
    this.id,
    this.headerId,
    this.lineNo = 1,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.locationId,
    this.locationCode,
    this.locationSortOrder,
    this.lotNo,
    this.serialNo,
    this.uomId,
    this.uomCode,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.systemQty,
    this.countedQty,
    this.unitCost,
    this.countedBy,
    this.countedAt,
    this.remark,
  });

  double get variance => (countedQty ?? 0) - (systemQty ?? 0);
  bool get isCounted => countedQty != null;

  factory ImStockCountDetail.fromJson(Map<String, dynamic> json) {
    double? toDoubleN(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return ImStockCountDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 1,
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      locationId: json['location_id'],
      locationCode: json['location_code'],
      locationSortOrder: json['location_sort_order'],
      lotNo: json['lot_no'],
      serialNo: json['serial_no'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      systemQty: toDoubleN(json['system_qty']),
      countedQty: toDoubleN(json['counted_qty']),
      unitCost: toDoubleN(json['unit_cost']),
      countedBy: json['counted_by'],
      countedAt: json['counted_at'] != null ? DateTime.tryParse(json['counted_at'].toString()) : null,
      remark: json['remark'],
    );
  }
}

// ── Wrapper ───────────────────────────────────────────────────────────────
class ImStockCount {
  final ImStockCountHeader header;
  final List<ImStockCountDetail> details;

  const ImStockCount({required this.header, this.details = const []});

  factory ImStockCount.fromJson(Map<String, dynamic> json) => ImStockCount(
        header: ImStockCountHeader.fromJson(json),
        details: (json['details'] as List<dynamic>? ?? [])
            .map((e) => ImStockCountDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Check-results summary (screen 6 "ตรวจผล") ───────────────────────────────
class ImStockCountCheckResult {
  final int totalBins;
  final int nonEmptyBins;
  final int emptyBins;
  final int totalItems;
  final int itemsWithStock;
  final int itemsWithoutStock;
  final int itemsWithVariance;
  final double varianceValue;

  const ImStockCountCheckResult({
    required this.totalBins,
    required this.nonEmptyBins,
    required this.emptyBins,
    required this.totalItems,
    required this.itemsWithStock,
    required this.itemsWithoutStock,
    required this.itemsWithVariance,
    required this.varianceValue,
  });

  factory ImStockCountCheckResult.fromJson(Map<String, dynamic> json) => ImStockCountCheckResult(
        totalBins: json['total_bins'] ?? 0,
        nonEmptyBins: json['non_empty_bins'] ?? 0,
        emptyBins: json['empty_bins'] ?? 0,
        totalItems: json['total_items'] ?? 0,
        itemsWithStock: json['items_with_stock'] ?? 0,
        itemsWithoutStock: json['items_without_stock'] ?? 0,
        itemsWithVariance: json['items_with_variance'] ?? 0,
        varianceValue: double.tryParse(json['variance_value']?.toString() ?? '0') ?? 0,
      );
}

// ── Variance report row ─────────────────────────────────────────────────────
class ImStockCountVarianceRow {
  final int countId;
  final String countNo;
  final DateTime countDate;
  final String status;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final int itemId;
  final String? itemCode;
  final String? itemName;
  final int? locationId;
  final String? locationCode;
  final String? lotNo;
  final String? serialNo;
  final double systemQty;
  final double countedQty;
  final double varianceQty;
  final double unitCost;
  final double varianceValue;

  const ImStockCountVarianceRow({
    required this.countId,
    required this.countNo,
    required this.countDate,
    required this.status,
    this.warehouseCode,
    this.warehouseNameTh,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.locationId,
    this.locationCode,
    this.lotNo,
    this.serialNo,
    this.systemQty = 0,
    this.countedQty = 0,
    this.varianceQty = 0,
    this.unitCost = 0,
    this.varianceValue = 0,
  });

  factory ImStockCountVarianceRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ImStockCountVarianceRow(
      countId: json['count_id'] ?? 0,
      countNo: json['count_no'] ?? '',
      countDate: parseLocalDate(json['count_date']),
      status: json['status'] ?? '',
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      locationId: json['location_id'],
      locationCode: json['location_code'],
      lotNo: json['lot_no'],
      serialNo: json['serial_no'],
      systemQty: toDouble(json['system_qty']),
      countedQty: toDouble(json['counted_qty']),
      varianceQty: toDouble(json['variance_qty']),
      unitCost: toDouble(json['unit_cost']),
      varianceValue: toDouble(json['variance_value']),
    );
  }
}
