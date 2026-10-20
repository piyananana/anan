// วงเงินเครดิตลูกหนี้ + ขั้นตอนอนุมัติเกินวงเงิน — ใช้ร่วม AR / IM (backend: utils/creditCheck.js)
double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

class CreditInfo {
  final double creditLimit;     // 0 = ไม่ได้กำหนด ไม่ตรวจ
  final double outstanding;     // ยอดคงค้าง (ไม่รวมเอกสารนี้)
  final double arOutstanding;
  final double unbilledDelivery; // ใบส่งสินค้ารอตั้งหนี้ที่ส่งแล้ว
  const CreditInfo({required this.creditLimit, required this.outstanding,
      this.arOutstanding = 0, this.unbilledDelivery = 0});

  bool get checked => creditLimit > 0;
  double after(double amount) => outstanding + amount;
  bool exceeded(double amount) => checked && after(amount) > creditLimit + 0.005;

  factory CreditInfo.fromJson(Map<String, dynamic> j) => CreditInfo(
        creditLimit: _num(j['credit_limit']),
        outstanding: _num(j['outstanding']),
        arOutstanding: _num(j['ar_outstanding']),
        unbilledDelivery: _num(j['unbilled_delivery']),
      );
}

class CreditApprovalStep {
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected / Skipped
  final String? remarks;
  final DateTime? approvedAt;
  const CreditApprovalStep({required this.approverUserId, required this.approverUserName,
      required this.sequenceNo, required this.status, this.remarks, this.approvedAt});

  factory CreditApprovalStep.fromJson(Map<String, dynamic> j) => CreditApprovalStep(
        approverUserId: j['approver_user_id'] as int,
        approverUserName: j['approver_user_name'] ?? '',
        sequenceNo: j['sequence_no'] as int? ?? 1,
        status: j['status'] ?? 'Pending',
        remarks: j['remarks'] as String?,
        approvedAt: DateTime.tryParse(j['approved_at']?.toString() ?? '')?.toLocal(),
      );

  static List<CreditApprovalStep> listFromJson(dynamic list) => (list as List? ?? [])
      .map((e) => CreditApprovalStep.fromJson(e as Map<String, dynamic>))
      .toList();
}

// สถานะคำขอบนเอกสาร (คอลัมน์ credit_status / credit_amount)
class DocCreditState {
  final String? status;  // null / Pending / Approved
  final double? amount;  // ยอดเอกสารที่ได้รับอนุมัติ (ใบลดหนี้ติดลบ)
  final List<CreditApprovalStep> approvals;
  const DocCreditState({this.status, this.amount, this.approvals = const []});

  bool get isPending => status == 'Pending';
  // อนุมัติแล้วครอบคลุมยอดนี้ (ยอดไม่เพิ่มจากที่อนุมัติ)
  bool covers(double docAmount) => status == 'Approved' && amount != null && docAmount <= amount! + 0.005;

  factory DocCreditState.fromJson(Map<String, dynamic> header, dynamic approvals) => DocCreditState(
        status: header['credit_status'] as String?,
        amount: header['credit_amount'] == null ? null : _num(header['credit_amount']),
        approvals: CreditApprovalStep.listFromJson(approvals),
      );
}
