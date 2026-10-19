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
