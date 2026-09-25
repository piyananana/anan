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

const _poDoneStatuses = ['Approved', 'PartiallyReceived', 'FullyReceived', 'Closed'];

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
  final DateTime? poApprovedAt;
  final String? poCreatedBy;
  final String? poApproverName;
  final String? poStatus;
  final List<PrPoStatusReportItem> poItems;

  const PrPoStatusReportRow({
    this.prId, this.prDocNo, this.prDocDate, this.prRequestedByName, this.prApproverName, this.prStatus,
    this.prItems = const [],
    this.poId, this.poDocNo, this.poDocDate, this.poApprovedAt, this.poCreatedBy, this.poApproverName, this.poStatus,
    this.poItems = const [],
  });

  // ระยะเวลา(วัน): เริ่มจากวันที่ PR ถ้ามี PR ไม่งั้นวันที่ PO — สิ้นสุดที่วันที่อนุมัติ PO ถ้า PO อนุมัติแล้ว
  // (หรือสถานะถัดจากอนุมัติ) ไม่งั้นใช้วันปัจจุบัน (ยังไม่จบ) — ไม่คำนวณเลยถ้า PR ถูก Void/Rejected(ไม่มี PO)
  // หรือ PO ถูก Void เพราะถือเป็นทางตัน ไม่มีความหมายที่จะนับระยะเวลาต่อ
  int? get durationDays {
    if (prStatus == 'Void') return null;
    if (prStatus == 'Rejected' && poId == null) return null;
    if (poId != null && poStatus == 'Void') return null;

    final anchorDate = prId != null ? prDocDate : poDocDate;
    if (anchorDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime endDate;
    if (poId != null && _poDoneStatuses.contains(poStatus)) {
      endDate = poApprovedAt ?? today;
    } else {
      endDate = today;
    }
    return endDate.difference(anchorDate).inDays;
  }

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
      poApprovedAt: parseLocalDateNullable(json['po_approved_at']),
      poCreatedBy: json['po_created_by'],
      poApproverName: json['po_approver_name'],
      poStatus: json['po_status'],
      poItems: (json['po_items'] as List<dynamic>? ?? []).map((e) => PrPoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
