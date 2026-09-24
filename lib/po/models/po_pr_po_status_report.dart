// lib/po/models/po_pr_po_status_report.dart — แถวรายงานติดตามสถานะใบขอซื้อ(PR)/ใบสั่งซื้อ(PO) คู่กัน
import '../../utils/date_utils.dart';
class PrPoStatusReportItem {
  final String? itemCode;
  final String? itemName;
  final double qty;
  final double price;

  const PrPoStatusReportItem({this.itemCode, this.itemName, required this.qty, required this.price});

  factory PrPoStatusReportItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return PrPoStatusReportItem(
      itemCode: json['item_code'],
      itemName: json['item_name'],
      qty: toDouble(json['qty']),
      price: toDouble(json['price']),
    );
  }
}

class PrPoStatusReportRow {
  final int? prId;
  final String? prDocNo;
  final DateTime? prDocDate;
  final String? prRequestedByName;
  final String? prApproverName;
  final String? prStatus;
  final List<PrPoStatusReportItem> prItems;

  final int? poId;
  final String? poDocNo;
  final DateTime? poDocDate;
  final String? poCreatedBy;
  final String? poApproverName;
  final String? poStatus;
  final List<PrPoStatusReportItem> poItems;

  const PrPoStatusReportRow({
    this.prId, this.prDocNo, this.prDocDate, this.prRequestedByName, this.prApproverName, this.prStatus,
    this.prItems = const [],
    this.poId, this.poDocNo, this.poDocDate, this.poCreatedBy, this.poApproverName, this.poStatus,
    this.poItems = const [],
  });

  factory PrPoStatusReportRow.fromJson(Map<String, dynamic> json) {
    return PrPoStatusReportRow(
      prId: json['pr_id'],
      prDocNo: json['pr_doc_no'],
      prDocDate: parseLocalDateNullable(json['pr_doc_date']),
      prRequestedByName: json['pr_requested_by_name'],
      prApproverName: json['pr_approver_name'],
      prStatus: json['pr_status'],
      prItems: (json['pr_items'] as List<dynamic>? ?? []).map((e) => PrPoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
      poId: json['po_id'],
      poDocNo: json['po_doc_no'],
      poDocDate: parseLocalDateNullable(json['po_doc_date']),
      poCreatedBy: json['po_created_by'],
      poApproverName: json['po_approver_name'],
      poStatus: json['po_status'],
      poItems: (json['po_items'] as List<dynamic>? ?? []).map((e) => PrPoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
