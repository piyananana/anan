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
// สถานะ "หลังอนุมัติ" — สถานะเหล่านี้ถูกตัดออกจาก dialog เลือกสถานะหลักแล้ว (เหลือแค่ ร่าง/อนุมัติแล้ว/ยกเลิก ที่
// เลือกกรองได้) ย้ายมาแสดงในคอลัมน์ "สถานะหลังอนุมัติ" แยกต่างหากแทน — คอลัมน์สถานะหลักจะยุบค่าพวกนี้กลับเป็น
// "Approved" เสมอ (ดู displayPrStatus/displayPoStatus) เพราะทั้งหมดล้วนเป็นสถานะที่มาหลัง Approved อยู่แล้ว
const _poAfterApprovalStatuses = ['PartiallyReceived', 'FullyReceived', 'Closed'];
const _prAfterApprovalStatuses = ['PartiallyConverted', 'FullyConverted', 'Closed'];

class PrPoStatusReportRow {
  final int? prId;
  final String? prDocNo;
  final DateTime? prDocDate;
  final String? prRequestedByName;
  final String? prApproverName;
  final DateTime? prDecidedAt; // วันที่ผู้อนุมัติคนล่าสุดตัดสินใจ (อนุมัติ/ปฏิเสธ) — จาก pr_transaction_approval
  final String? prStatus;
  final DateTime? prUpdatedAt;
  final List<PrPoStatusReportItem> prItems;

  final int? poId;
  final String? poDocNo;
  final DateTime? poDocDate;
  final DateTime? poApprovedAt;
  final String? poCreatedBy;
  final String? poApproverName;
  final String? poStatus;
  final DateTime? poUpdatedAt;
  final List<PrPoStatusReportItem> poItems;

  const PrPoStatusReportRow({
    this.prId, this.prDocNo, this.prDocDate, this.prRequestedByName, this.prApproverName, this.prDecidedAt, this.prStatus,
    this.prUpdatedAt, this.prItems = const [],
    this.poId, this.poDocNo, this.poDocDate, this.poApprovedAt, this.poCreatedBy, this.poApproverName, this.poStatus,
    this.poUpdatedAt, this.poItems = const [],
  });

  // สถานะที่ใช้แสดงในคอลัมน์สถานะหลัก (สถานะขอซื้อ/สถานะสั่งซื้อ) — ยุบสถานะหลังอนุมัติ (รับบางส่วน/รับครบ/แปลง
  // บางส่วน/แปลงครบ/ปิด) กลับเป็น "Approved" เสมอ เพราะรายละเอียดหลังอนุมัติย้ายไปอยู่คอลัมน์แยกแล้ว
  String? get displayPrStatus => _prAfterApprovalStatuses.contains(prStatus) ? 'Approved' : prStatus;
  String? get displayPoStatus => _poAfterApprovalStatuses.contains(poStatus) ? 'Approved' : poStatus;

  // สถานะหลังอนุมัติ (คอลัมน์ใหม่) — ถ้ามี PO ใช้สถานะของ PO เสมอ (แม้ PR จะโยงมาก็ตาม) เพราะ PO คือฝั่งที่
  // ติดตามความคืบหน้าการรับสินค้าจริง ถ้ายังไม่มี PO ใช้สถานะของ PR เอง (แปลงบางส่วน/แปลงครบ/ปิด)
  String? get afterApprovalStatus {
    if (poId != null) return _poAfterApprovalStatuses.contains(poStatus) ? poStatus : null;
    return _prAfterApprovalStatuses.contains(prStatus) ? prStatus : null;
  }

  // วันที่ของสถานะหลังอนุมัติ — ไม่มีคอลัมน์ timestamp เฉพาะต่อสถานะในตาราง จึงใช้ updated_at ของฝั่งที่เกี่ยวข้อง
  // เป็นตัวประมาณ (ทุกการเปลี่ยนสถานะของ PR/PO อัปเดตคอลัมน์นี้เสมอ)
  DateTime? get afterApprovalStatusDate {
    if (afterApprovalStatus == null) return null;
    return poId != null ? poUpdatedAt : prUpdatedAt;
  }

  // วันที่อนุมัติ/ปฏิเสธ ที่จะแสดงในรายงาน — ถ้ามี PO และ PO อนุมัติแล้ว(หรือสถานะถัดจากอนุมัติ) ใช้วันที่อนุมัติ PO
  // ถ้ายังไม่มี PO ใช้วันที่ PR เองถูกอนุมัติ/ปฏิเสธ (ถ้ามี) — นอกเหนือจากนี้ไม่แสดง (ยังไม่ถึงจุดตัดสินใจ)
  DateTime? get approvalOrRejectionDate {
    if (poId != null) {
      return _poDoneStatuses.contains(poStatus) ? poApprovedAt : null;
    }
    if (prStatus == 'Approved' || prStatus == 'Rejected') return prDecidedAt;
    return null;
  }

  // ระยะเวลา(วัน): เริ่มจากวันที่ PR ถ้ามี PR ไม่งั้นวันที่ PO — สิ้นสุดที่วันที่อนุมัติ PO ถ้า PO อนุมัติแล้ว
  // (หรือสถานะถัดจากอนุมัติ) ไม่งั้นใช้วันปัจจุบัน (ยังไม่จบ) — ไม่คำนวณเลยถ้า PR ถูก Void/Rejected/Closed
  // (ไม่มี PO) หรือ PO ถูก Void เพราะถือเป็นทางตัน ไม่มีความหมายที่จะนับระยะเวลาต่อ
  int? get durationDays {
    if (prStatus == 'Void') return null;
    if (poId == null && (prStatus == 'Rejected' || prStatus == 'Closed')) return null;
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

  // ขอซื้อถึงสถานะล่าสุด(วัน): เหมือน durationDays แต่ถ้ามีสถานะหลังอนุมัติแล้ว (รับบางส่วน/รับครบ/แปลงบางส่วน/
  // แปลงครบ/ปิด) ใช้วันที่ของสถานะนั้นเป็นวันสิ้นสุดแทน แสดงความคืบหน้าทั้งหมดจนถึงปัจจุบัน ไม่ใช่แค่ถึงจุดอนุมัติ
  // — ยกเว้น PR/PO ที่ถูก Void (ทางตันเสมอ) หรือ PR ที่ถูก Rejected โดยยังไม่มี PO (ไม่เคยเดินหน้าต่อ)
  int? get durationToLatestStatusDays {
    if (prStatus == 'Void') return null;
    if (poId == null && prStatus == 'Rejected') return null;
    if (poId != null && poStatus == 'Void') return null;

    final anchorDate = prId != null ? prDocDate : poDocDate;
    if (anchorDate == null) return null;

    final afterDate = afterApprovalStatusDate;
    if (afterDate != null) return afterDate.difference(anchorDate).inDays;
    return durationDays;
  }

  factory PrPoStatusReportRow.fromJson(Map<String, dynamic> json) {
    return PrPoStatusReportRow(
      prId: json['pr_id'],
      prDocNo: json['pr_doc_no'],
      prDocDate: parseLocalDateNullable(json['pr_doc_date']),
      prRequestedByName: json['pr_requested_by_name'],
      prApproverName: json['pr_approver_name'],
      prDecidedAt: parseLocalDateNullable(json['pr_decided_at']),
      prStatus: json['pr_status'],
      prUpdatedAt: parseLocalDateNullable(json['pr_updated_at']),
      prItems: (json['pr_items'] as List<dynamic>? ?? []).map((e) => PrPoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
      poId: json['po_id'],
      poDocNo: json['po_doc_no'],
      poDocDate: parseLocalDateNullable(json['po_doc_date']),
      poApprovedAt: parseLocalDateNullable(json['po_approved_at']),
      poCreatedBy: json['po_created_by'],
      poApproverName: json['po_approver_name'],
      poStatus: json['po_status'],
      poUpdatedAt: parseLocalDateNullable(json['po_updated_at']),
      poItems: (json['po_items'] as List<dynamic>? ?? []).map((e) => PrPoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
