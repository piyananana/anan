// ประวัติการถอยเอกสารกลับเป็นร่าง / การลบเอกสาร (backend: sa_document_reverse_log, utils/reverseLog.js)
// ใช้ร่วมทุกโมดูล (GL, AP, ...)
class DocReverseLog {
  final String? fromStatus;
  final String? toStatus; // Draft = ถอยเป็นร่าง, Deleted = ลบ, Void = ยกเลิก, Pending/Bounced = CM
  final String reason;
  final String? createdByName;
  final DateTime? createdAt;

  DocReverseLog({this.fromStatus, this.toStatus, required this.reason, this.createdByName, this.createdAt});

  bool get isDelete => toStatus == 'Deleted';
  bool get isVoid => toStatus == 'Void';

  // ชื่อการกระทำสำหรับแสดงในประวัติ (CM รายการรับ/จ่าย: Pending = ยกเลิกการเคลียร์, Bounced = เช็คคืน;
  // เช็คลงวันที่ล่วงหน้า: Holding/Deposited/Returned = ถอยสถานะ)
  String actionLabel(bool isEnglish) {
    // ใบสั่งซื้อ/ใบสั่งขาย/ใบสั่งผลิต: ถอยจากปิดแล้วกลับเป็นสถานะที่คำนวณจากเอกสารอ้างอิง
    if (fromStatus == 'Closed' && toStatus != 'Posted' && toStatus != 'Draft' && toStatus != 'Void') {
      return isEnglish ? 'Closing reversed' : 'ถอยการปิด';
    }
    switch (toStatus) {
      case 'Deleted': return isEnglish ? 'Deleted' : 'ลบ';
      case 'Void':    return isEnglish ? 'Voided' : 'ยกเลิก';
      case 'Pending': return isEnglish ? 'Clearing undone' : 'ยกเลิกการเคลียร์';
      case 'Bounced': return isEnglish ? 'Bounced check' : 'เช็คคืน';
      // เช็คลงวันที่ล่วงหน้า: ถอยกลับไปสถานะก่อนหน้า
      case 'Holding':
      case 'Deposited':
      case 'Returned': return isEnglish ? 'Status reverted' : 'ถอยสถานะ';
      // IM รับ/ส่งสินค้ารอตั้งหนี้: ถอยเฉพาะใบตั้งหนี้
      case 'Received':
      case 'Delivered': return isEnglish ? 'Billing reversed' : 'ถอยการตั้งหนี้';
      // ใบสั่งผลิต: ถอยจากปิดแล้ว (ลบ/กลับรายการปรับ WIP)
      case 'Completed': return isEnglish ? 'Closing reversed' : 'ถอยการปิด';
      // ใบตรวจนับสต็อก: ถอยจากปิดแล้ว (ลบใบปรับยอด) / อนุมัติแล้ว กลับเป็นบันทึกแล้ว
      case 'Posted':
        return fromStatus == 'Closed'
            ? (isEnglish ? 'Adjustment reversed' : 'ถอยการปรับยอด')
            : (isEnglish ? 'Approval reversed' : 'ถอยการอนุมัติ');
      default:        return isEnglish ? 'Reversed to draft' : 'ถอยเป็นร่าง';
    }
  }

  factory DocReverseLog.fromJson(Map<String, dynamic> json) => DocReverseLog(
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        reason: json['reason'] ?? '',
        createdByName: json['created_by_name'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
      );

  static List<DocReverseLog> listFromJson(dynamic list) => (list as List? ?? [])
      .map((e) => DocReverseLog.fromJson(e as Map<String, dynamic>))
      .toList();
}

// เหตุที่ถอย / ยกเลิก / ลบไม่ได้ ที่ backend ส่งมาเป็น { code, ref, message } (null = ทำได้)
// message เป็นภาษาไทยจาก backend — ภาษาอังกฤษแปลจาก code
class DocBlock {
  final String code;
  final String? ref;
  final String message;

  const DocBlock({required this.code, this.ref, required this.message});

  static DocBlock? fromJson(dynamic json) => json is Map<String, dynamic>
      ? DocBlock(code: json['code'] ?? '', ref: json['ref'] as String?, message: json['message'] ?? '')
      : null;

  static const Map<String, String> _en = {
    'NOT_REVERSIBLE':  'Only posted documents can be reversed',
    'NOT_POSTED':      'Only posted documents can be voided (delete a draft instead)',
    'NOT_DRAFT':       'Posted documents cannot be deleted — reverse to draft first',
    'PERIOD_CLOSED':   'The accounting period of this document is closed',
    'INVOICE_CHANGED': 'A revalued document has changed since revaluation (payment, later revaluation or reversal)',
    'LATER_RUN':       'A later allowance run has been posted (it was calculated from a balance that includes this run)',
    'LATER_REVAL':     'A later revaluation of the same bank account has been posted',
    'REF_DOCS':        'Other documents (issues/receipts/deliveries) reference this document — reverse and delete them first',
    'NOT_APPROVED':    'A closed document cannot be voided — reopen it first',
    'TIME_LOGGED':     'Operation time has already been logged',
    'CHILD_MO':        'Sub-assembly MOs were created from this MO — cancel or delete them first',
    'NOT_RELEASED':    'Only released MOs that have not started production can be cancelled',
    'VOIDED':          'This document has been voided or deleted',
  };

  String text(bool isEnglish) =>
      isEnglish ? '${_en[code] ?? message}${ref != null ? ' ($ref)' : ''}' : message;
}

// ปุ่มถอย / ยกเลิก / ลบ ของเอกสาร + ประวัติ — backend ส่ง reverse_block / void_block / delete_block / reverse_history
class DocActions {
  final DocBlock? reverseBlock;
  final DocBlock? voidBlock;
  final DocBlock? deleteBlock;
  final List<DocReverseLog> history;

  const DocActions({this.reverseBlock, this.voidBlock, this.deleteBlock, this.history = const []});

  factory DocActions.fromJson(Map<String, dynamic> j) => DocActions(
        reverseBlock: DocBlock.fromJson(j['reverse_block']),
        voidBlock: DocBlock.fromJson(j['void_block']),
        deleteBlock: DocBlock.fromJson(j['delete_block']),
        history: DocReverseLog.listFromJson(j['reverse_history']),
      );
}
