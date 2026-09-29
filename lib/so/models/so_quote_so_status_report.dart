// lib/so/models/so_quote_so_status_report.dart — แถวรายงานติดตามสถานะใบเสนอราคา(Quote)/ใบสั่งขาย(SO) คู่กัน
// มิเรอร์ po_pr_po_status_report.dart ทุกประการ (PR->Quote, PO->SO)
import '../../utils/date_utils.dart';

class QuoteSoStatusReportItem {
  final String? itemCode;
  final String? itemName;
  final double qty;
  final double price;

  const QuoteSoStatusReportItem({this.itemCode, this.itemName, required this.qty, required this.price});

  factory QuoteSoStatusReportItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return QuoteSoStatusReportItem(
      itemCode: json['item_code'],
      itemName: json['item_name'],
      qty: toDouble(json['qty']),
      price: toDouble(json['price']),
    );
  }
}

const _soDoneStatuses = ['Approved', 'PartiallyDelivered', 'FullyDelivered', 'Closed'];
// สถานะ "หลังอนุมัติ" — สถานะเหล่านี้ถูกตัดออกจาก dialog เลือกสถานะหลักแล้ว (เหลือแค่ ร่าง/อนุมัติแล้ว/ยกเลิก ที่
// เลือกกรองได้) ย้ายมาแสดงในคอลัมน์ "สถานะหลังอนุมัติ" แยกต่างหากแทน — คอลัมน์สถานะหลักจะยุบค่าพวกนี้กลับเป็น
// "Approved" เสมอ (ดู displayQuoteStatus/displaySoStatus) เพราะทั้งหมดล้วนเป็นสถานะที่มาหลัง Approved อยู่แล้ว
const _soAfterApprovalStatuses = ['PartiallyDelivered', 'FullyDelivered', 'Closed'];
const _quoteAfterApprovalStatuses = ['PartiallyConverted', 'FullyConverted', 'Closed'];

class QuoteSoStatusReportRow {
  final int? quoteId;
  final String? quoteDocNo;
  final DateTime? quoteDocDate;
  final String? quotePreparedByName;
  final String? quoteApproverName;
  final DateTime? quoteDecidedAt; // วันที่ผู้อนุมัติคนล่าสุดตัดสินใจ (อนุมัติ/ปฏิเสธ) — จาก quote_transaction_approval
  final String? quoteStatus;
  final DateTime? quoteUpdatedAt;
  final List<QuoteSoStatusReportItem> quoteItems;

  final int? soId;
  final String? soDocNo;
  final DateTime? soDocDate;
  final DateTime? soApprovedAt;
  final String? soCreatedBy;
  final String? soApproverName;
  final String? soStatus;
  final DateTime? soUpdatedAt;
  final List<QuoteSoStatusReportItem> soItems;

  const QuoteSoStatusReportRow({
    this.quoteId, this.quoteDocNo, this.quoteDocDate, this.quotePreparedByName, this.quoteApproverName, this.quoteDecidedAt, this.quoteStatus,
    this.quoteUpdatedAt, this.quoteItems = const [],
    this.soId, this.soDocNo, this.soDocDate, this.soApprovedAt, this.soCreatedBy, this.soApproverName, this.soStatus,
    this.soUpdatedAt, this.soItems = const [],
  });

  // สถานะที่ใช้แสดงในคอลัมน์สถานะหลัก (สถานะเสนอราคา/สถานะสั่งขาย) — ยุบสถานะหลังอนุมัติ (ส่งบางส่วน/ส่งครบ/แปลง
  // บางส่วน/แปลงครบ/ปิด) กลับเป็น "Approved" เสมอ เพราะรายละเอียดหลังอนุมัติย้ายไปอยู่คอลัมน์แยกแล้ว
  String? get displayQuoteStatus => _quoteAfterApprovalStatuses.contains(quoteStatus) ? 'Approved' : quoteStatus;
  String? get displaySoStatus => _soAfterApprovalStatuses.contains(soStatus) ? 'Approved' : soStatus;

  // สถานะหลังอนุมัติ (คอลัมน์ใหม่) — ถ้ามี SO ใช้สถานะของ SO เสมอ (แม้ Quote จะโยงมาก็ตาม) เพราะ SO คือฝั่งที่
  // ติดตามความคืบหน้าการส่งสินค้าจริง ถ้ายังไม่มี SO ใช้สถานะของ Quote เอง (แปลงบางส่วน/แปลงครบ/ปิด)
  String? get afterApprovalStatus {
    if (soId != null) return _soAfterApprovalStatuses.contains(soStatus) ? soStatus : null;
    return _quoteAfterApprovalStatuses.contains(quoteStatus) ? quoteStatus : null;
  }

  // วันที่ของสถานะหลังอนุมัติ — ไม่มีคอลัมน์ timestamp เฉพาะต่อสถานะในตาราง จึงใช้ updated_at ของฝั่งที่เกี่ยวข้อง
  // เป็นตัวประมาณ (ทุกการเปลี่ยนสถานะของ Quote/SO อัปเดตคอลัมน์นี้เสมอ)
  DateTime? get afterApprovalStatusDate {
    if (afterApprovalStatus == null) return null;
    return soId != null ? soUpdatedAt : quoteUpdatedAt;
  }

  // วันที่อนุมัติ/ปฏิเสธ ที่จะแสดงในรายงาน — ถ้ามี SO และ SO อนุมัติแล้ว(หรือสถานะถัดจากอนุมัติ) ใช้วันที่อนุมัติ SO
  // ถ้ายังไม่มี SO ใช้วันที่ Quote เองถูกอนุมัติ/ปฏิเสธ (ถ้ามี) — นอกเหนือจากนี้ไม่แสดง (ยังไม่ถึงจุดตัดสินใจ)
  DateTime? get approvalOrRejectionDate {
    if (soId != null) {
      return _soDoneStatuses.contains(soStatus) ? soApprovedAt : null;
    }
    if (quoteStatus == 'Approved' || quoteStatus == 'Rejected') return quoteDecidedAt;
    return null;
  }

  // ระยะเวลา(วัน): เริ่มจากวันที่ Quote ถ้ามี Quote ไม่งั้นวันที่ SO — สิ้นสุดที่วันที่อนุมัติ SO ถ้า SO อนุมัติแล้ว
  // (หรือสถานะถัดจากอนุมัติ) ไม่งั้นใช้วันปัจจุบัน (ยังไม่จบ) — ไม่คำนวณเลยถ้า Quote ถูก Void/Rejected/Closed
  // (ไม่มี SO) หรือ SO ถูก Void เพราะถือเป็นทางตัน ไม่มีความหมายที่จะนับระยะเวลาต่อ
  int? get durationDays {
    if (quoteStatus == 'Void') return null;
    if (soId == null && (quoteStatus == 'Rejected' || quoteStatus == 'Closed')) return null;
    if (soId != null && soStatus == 'Void') return null;

    final anchorDate = quoteId != null ? quoteDocDate : soDocDate;
    if (anchorDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime endDate;
    if (soId != null && _soDoneStatuses.contains(soStatus)) {
      endDate = soApprovedAt ?? today;
    } else {
      endDate = today;
    }
    return endDate.difference(anchorDate).inDays;
  }

  // เสนอราคาถึงสถานะล่าสุด(วัน): เหมือน durationDays แต่ถ้ามีสถานะหลังอนุมัติแล้ว (ส่งบางส่วน/ส่งครบ/แปลงบางส่วน/
  // แปลงครบ/ปิด) ใช้วันที่ของสถานะนั้นเป็นวันสิ้นสุดแทน แสดงความคืบหน้าทั้งหมดจนถึงปัจจุบัน ไม่ใช่แค่ถึงจุดอนุมัติ
  // — ยกเว้น Quote/SO ที่ถูก Void (ทางตันเสมอ) หรือ Quote ที่ถูก Rejected โดยยังไม่มี SO (ไม่เคยเดินหน้าต่อ)
  int? get durationToLatestStatusDays {
    if (quoteStatus == 'Void') return null;
    if (soId == null && quoteStatus == 'Rejected') return null;
    if (soId != null && soStatus == 'Void') return null;

    final anchorDate = quoteId != null ? quoteDocDate : soDocDate;
    if (anchorDate == null) return null;

    final afterDate = afterApprovalStatusDate;
    if (afterDate != null) return afterDate.difference(anchorDate).inDays;
    return durationDays;
  }

  factory QuoteSoStatusReportRow.fromJson(Map<String, dynamic> json) {
    return QuoteSoStatusReportRow(
      quoteId: json['quote_id'],
      quoteDocNo: json['quote_doc_no'],
      quoteDocDate: parseLocalDateNullable(json['quote_doc_date']),
      quotePreparedByName: json['quote_prepared_by_name'],
      quoteApproverName: json['quote_approver_name'],
      quoteDecidedAt: parseLocalDateNullable(json['quote_decided_at']),
      quoteStatus: json['quote_status'],
      quoteUpdatedAt: parseLocalDateNullable(json['quote_updated_at']),
      quoteItems: (json['quote_items'] as List<dynamic>? ?? []).map((e) => QuoteSoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
      soId: json['so_id'],
      soDocNo: json['so_doc_no'],
      soDocDate: parseLocalDateNullable(json['so_doc_date']),
      soApprovedAt: parseLocalDateNullable(json['so_approved_at']),
      soCreatedBy: json['so_created_by'],
      soApproverName: json['so_approver_name'],
      soStatus: json['so_status'],
      soUpdatedAt: parseLocalDateNullable(json['so_updated_at']),
      soItems: (json['so_items'] as List<dynamic>? ?? []).map((e) => QuoteSoStatusReportItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
