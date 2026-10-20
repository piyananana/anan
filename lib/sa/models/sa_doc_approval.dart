// ขั้นตอนคิวอนุมัติเอกสาร (backend: utils/docApproval.js ตาราง doc_approval)
// ใช้ร่วม PO / SO / เปลี่ยนแปลงราคา / ตรวจนับสต็อก / ใบสั่งผลิต
class DocApprovalStep {
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected / Skipped
  final String? remarks;
  final DateTime? approvedAt;
  const DocApprovalStep({required this.approverUserId, required this.approverUserName,
      required this.sequenceNo, required this.status, this.remarks, this.approvedAt});

  factory DocApprovalStep.fromJson(Map<String, dynamic> j) => DocApprovalStep(
        approverUserId: j['approver_user_id'] as int,
        approverUserName: j['approver_user_name'] ?? '',
        sequenceNo: j['sequence_no'] as int? ?? 1,
        status: j['status'] ?? 'Pending',
        remarks: j['remarks'] as String?,
        approvedAt: DateTime.tryParse(j['approved_at']?.toString() ?? '')?.toLocal(),
      );

  static List<DocApprovalStep> listFromJson(dynamic list) => (list as List? ?? [])
      .map((e) => DocApprovalStep.fromJson(e as Map<String, dynamic>))
      .toList();
}

// ผู้ใช้นี้ถึงคิวอนุมัติไหม — ALL: ลำดับก่อนหน้าต้องอนุมัติครบ, ANY: ไม่ต้องรอลำดับ
bool isMyApprovalTurn(List<DocApprovalStep> steps, int? userId, String? approvalMode) {
  if (userId == null) return false;
  final mine = steps.where((a) => a.approverUserId == userId && a.status == 'Pending').toList();
  if (mine.isEmpty) return false;
  if (approvalMode == 'ANY') return true;
  return !steps.any((a) => a.sequenceNo < mine.first.sequenceNo && a.status == 'Pending');
}
