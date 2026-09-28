// lib/po/models/po_closable_row.dart — แถวใบสั่งซื้อที่ปิดได้ (Approved/PartiallyReceived/FullyReceived) สำหรับ
// หน้าจอปิดใบสั่งซื้อทีละหลายใบ — อ่านอย่างเดียว การปิดจริงเรียก PoTransactionService.closeTransaction ทีละใบ
import '../../utils/date_utils.dart';

class PoClosableRow {
  final int poId;
  final String poDocNo;
  final DateTime? poDocDate;
  final DateTime? dueDate;
  final String status;
  final String? vendorCode;
  final String? vendorNameTh;
  final String? vendorNameEn;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double totalValueLc;
  final double qtyOrdered;
  final double qtyReceived;
  bool selected;

  PoClosableRow({
    required this.poId,
    required this.poDocNo,
    this.poDocDate,
    this.dueDate,
    required this.status,
    this.vendorCode,
    this.vendorNameTh,
    this.vendorNameEn,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    required this.totalValueLc,
    required this.qtyOrdered,
    required this.qtyReceived,
    this.selected = true,
  });

  double get receivedPct => qtyOrdered <= 0 ? 0 : (qtyReceived / qtyOrdered) * 100;

  factory PoClosableRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return PoClosableRow(
      poId: json['po_id'],
      poDocNo: json['po_doc_no'] ?? '',
      poDocDate: parseLocalDateNullable(json['po_doc_date']),
      dueDate: parseLocalDateNullable(json['due_date']),
      status: json['status'] ?? '',
      vendorCode: json['vendor_code'],
      vendorNameTh: json['vendor_name_th'],
      vendorNameEn: json['vendor_name_en'],
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      totalValueLc: toDouble(json['total_value_lc']),
      qtyOrdered: toDouble(json['qty_ordered']),
      qtyReceived: toDouble(json['qty_received']),
    );
  }
}
