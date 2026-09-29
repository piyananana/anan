// lib/so/models/so_closable_row.dart — แถวใบสั่งขายที่ปิดได้ (Approved/PartiallyDelivered/FullyDelivered) สำหรับ
// หน้าจอปิดใบสั่งขายทีละหลายใบ — อ่านอย่างเดียว การปิดจริงเรียก SoTransactionService.closeTransaction ทีละใบ
// มิเรอร์ po_closable_row.dart ทุกประการ (vendor->customer)
import '../../utils/date_utils.dart';

class SoClosableRow {
  final int soId;
  final String soDocNo;
  final DateTime? soDocDate;
  final DateTime? dueDate;
  final String status;
  final String? customerCode;
  final String? customerNameTh;
  final String? customerNameEn;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double totalValueLc;
  final double qtyOrdered;
  final double qtyDelivered;
  bool selected;

  SoClosableRow({
    required this.soId,
    required this.soDocNo,
    this.soDocDate,
    this.dueDate,
    required this.status,
    this.customerCode,
    this.customerNameTh,
    this.customerNameEn,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    required this.totalValueLc,
    required this.qtyOrdered,
    required this.qtyDelivered,
    this.selected = true,
  });

  double get deliveredPct => qtyOrdered <= 0 ? 0 : (qtyDelivered / qtyOrdered) * 100;

  factory SoClosableRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return SoClosableRow(
      soId: json['so_id'],
      soDocNo: json['so_doc_no'] ?? '',
      soDocDate: parseLocalDateNullable(json['so_doc_date']),
      dueDate: parseLocalDateNullable(json['due_date']),
      status: json['status'] ?? '',
      customerCode: json['customer_code'],
      customerNameTh: json['customer_name_th'],
      customerNameEn: json['customer_name_en'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      totalValueLc: toDouble(json['total_value_lc']),
      qtyOrdered: toDouble(json['qty_ordered']),
      qtyDelivered: toDouble(json['qty_delivered']),
    );
  }
}
