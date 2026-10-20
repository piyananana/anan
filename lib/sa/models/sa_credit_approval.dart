// วงเงินเครดิตลูกหนี้ + ขั้นตอนอนุมัติเกินวงเงิน — ใช้ร่วม AR / IM (backend: utils/creditCheck.js)
// ขั้นตอนอนุมัติเก็บที่ตารางกลาง doc_approval — ใช้ model กลาง DocApprovalStep
import 'sa_doc_approval.dart';

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

// สถานะคำขอบนเอกสาร (คอลัมน์ credit_status / credit_amount)
class DocCreditState {
  final String? status;  // null / Pending / Approved
  final double? amount;  // ยอดเอกสารที่ได้รับอนุมัติ (ใบลดหนี้ติดลบ)
  final List<DocApprovalStep> approvals;
  final String? approvalMode; // ALL / ANY (credit_approval_mode)
  const DocCreditState({this.status, this.amount, this.approvals = const [], this.approvalMode});

  bool get isPending => status == 'Pending';
  // อนุมัติแล้วครอบคลุมยอดนี้ (ยอดไม่เพิ่มจากที่อนุมัติ)
  bool covers(double docAmount) => status == 'Approved' && amount != null && docAmount <= amount! + 0.005;

  factory DocCreditState.fromJson(Map<String, dynamic> header, dynamic approvals) => DocCreditState(
        status: header['credit_status'] as String?,
        amount: header['credit_amount'] == null ? null : _num(header['credit_amount']),
        approvals: DocApprovalStep.listFromJson(approvals),
        approvalMode: header['credit_approval_mode'] as String?,
      );
}
