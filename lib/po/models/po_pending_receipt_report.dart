// lib/po/models/po_pending_receipt_report.dart — แถวรายงานจัดซื้อสินค้าค้างรับ (บรรทัด PO ที่ยังรับสินค้าไม่ครบ)
import '../../utils/date_utils.dart';

class PoPendingReceiptReportRow {
  final int poId;
  final String poDocNo;
  final DateTime? poDocDate;
  final DateTime? dueDate;
  final double exchangeRate;
  final int poDetailId;
  final int? itemId;
  final String? itemCode;
  final String? itemName;
  final double qtyOrdered;
  final double unitPriceFc;
  final double qtyReceived;
  final double qtyOutstanding;
  final String? vendorCode;
  final String? vendorNameTh;
  final String? vendorNameEn;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;

  const PoPendingReceiptReportRow({
    required this.poId,
    required this.poDocNo,
    this.poDocDate,
    this.dueDate,
    required this.exchangeRate,
    required this.poDetailId,
    this.itemId,
    this.itemCode,
    this.itemName,
    required this.qtyOrdered,
    required this.unitPriceFc,
    required this.qtyReceived,
    required this.qtyOutstanding,
    this.vendorCode,
    this.vendorNameTh,
    this.vendorNameEn,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
  });

  double get totalAmountLc => qtyOutstanding * unitPriceFc * exchangeRate;

  // จำนวนวัน: บวก = เกินกำหนดมาแล้วกี่วัน, ลบ = ยังเหลืออีกกี่วันถึงจะครบกำหนด, null = ไม่มีวันครบกำหนด
  int? get daysOverdue {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(dueDate!).inDays;
  }

  factory PoPendingReceiptReportRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return PoPendingReceiptReportRow(
      poId: json['po_id'],
      poDocNo: json['po_doc_no'] ?? '',
      poDocDate: parseLocalDateNullable(json['po_doc_date']),
      dueDate: parseLocalDateNullable(json['due_date']),
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      poDetailId: json['po_detail_id'],
      itemId: json['item_id'],
      itemCode: json['item_code'],
      itemName: json['item_name'],
      qtyOrdered: toDouble(json['qty_ordered']),
      unitPriceFc: toDouble(json['unit_price_fc']),
      qtyReceived: toDouble(json['qty_received']),
      qtyOutstanding: toDouble(json['qty_outstanding']),
      vendorCode: json['vendor_code'],
      vendorNameTh: json['vendor_name_th'],
      vendorNameEn: json['vendor_name_en'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
    );
  }
}
