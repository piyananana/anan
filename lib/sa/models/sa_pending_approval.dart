// lib/sa/models/sa_pending_approval.dart — รายการรออนุมัติแบบรวมทุกโมดูล สำหรับกระดิ่งแจ้งเตือนที่ home screen
// รวมข้อมูลจาก endpoint my_pending ของทุกโมดูลที่มี workflow อนุมัติแบบคิวจริงผ่าน sa_module_approver (ai.
// ap_payment_run, ap_transaction, pr_transaction) ให้อยู่ในรูปแบบเดียวกัน เพื่อแสดงเป็น card เดียวกันบนกระดิ่ง —
// ไม่รวมโมดูลที่มีแค่ config ผู้อนุมัติทิ้งไว้แต่ยังไม่ได้ทำ workflow queued จริง (เช่น PO, CM) หรือยังไม่มีหน้าจอ
// อนุมัติในแอป (เช่น GL Period Closing)
class PendingApprovalItem {
  final String module; // 'ap_payment_run' | 'ap_transaction' | 'pr_transaction'
  final int id;
  final String docNo;
  final DateTime? date;
  final String titleTh;
  final String titleEn;
  final String? submittedBy;
  final double amount;
  final String targetPath; // Menu.targetPath ของหน้าจอที่ต้องเปิดเพื่อไปอนุมัติ

  const PendingApprovalItem({
    required this.module,
    required this.id,
    required this.docNo,
    this.date,
    required this.titleTh,
    required this.titleEn,
    this.submittedBy,
    required this.amount,
    required this.targetPath,
  });

  String title(bool isEnglish) => isEnglish ? titleEn : titleTh;
}
