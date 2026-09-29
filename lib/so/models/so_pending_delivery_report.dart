// lib/so/models/so_pending_delivery_report.dart — แถวรายงานการสั่งขายและสินค้าค้างส่ง (บรรทัด SO ที่ยังส่งสินค้า
// ไม่ครบ) มิเรอร์ po_pending_receipt_report.dart ทุกประการ (vendor->customer)
import '../../utils/date_utils.dart';

class SoPendingDeliveryReportRow {
  final int soId;
  final String soDocNo;
  final DateTime? soDocDate;
  final DateTime? dueDate;
  final double exchangeRate;
  final int soDetailId;
  final int? itemId;
  final String? itemCode;
  final String? itemName;
  final double qtyOrdered;
  final double unitPriceFc;
  final double qtyDelivered;
  final double qtyOutstanding;
  final String? customerCode;
  final String? customerNameTh;
  final String? customerNameEn;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;

  const SoPendingDeliveryReportRow({
    required this.soId,
    required this.soDocNo,
    this.soDocDate,
    this.dueDate,
    required this.exchangeRate,
    required this.soDetailId,
    this.itemId,
    this.itemCode,
    this.itemName,
    required this.qtyOrdered,
    required this.unitPriceFc,
    required this.qtyDelivered,
    required this.qtyOutstanding,
    this.customerCode,
    this.customerNameTh,
    this.customerNameEn,
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

  factory SoPendingDeliveryReportRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return SoPendingDeliveryReportRow(
      soId: json['so_id'],
      soDocNo: json['so_doc_no'] ?? '',
      soDocDate: parseLocalDateNullable(json['so_doc_date']),
      dueDate: parseLocalDateNullable(json['due_date']),
      exchangeRate: toDouble(json['exchange_rate']) == 0 ? 1 : toDouble(json['exchange_rate']),
      soDetailId: json['so_detail_id'],
      itemId: json['item_id'],
      itemCode: json['item_code'],
      itemName: json['item_name'],
      qtyOrdered: toDouble(json['qty_ordered']),
      unitPriceFc: toDouble(json['unit_price_fc']),
      qtyDelivered: toDouble(json['qty_delivered']),
      qtyOutstanding: toDouble(json['qty_outstanding']),
      customerCode: json['customer_code'],
      customerNameTh: json['customer_name_th'],
      customerNameEn: json['customer_name_en'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
    );
  }
}
