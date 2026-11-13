// lib/im/widgets/im_payment_approval_panel.dart
// ซื้อเงินสด ('14') — ขออนุมัติจ่ายก่อน Post: ยอดจ่าย (วิธีจ่ายทั้งหมด × อัตราแลกเปลี่ยน) เทียบยอดที่อนุมัติ, ขั้นตอนผู้อนุมัติ,
// ปุ่มขอ / ถอน / อนุมัติ / ปฏิเสธ — backend: controllers/im/imCashPurchase.js (doc_kind IM_CASHPUR, วงเงินอนุมัติจ่าย)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_credit_approval.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_credit_approval_service.dart';
import '../../sa/utils/sa_menu_scope.dart';

final _fmt = NumberFormat('#,##0.00');

class ImPaymentApprovalPanel extends StatefulWidget {
  final CreditApprovalService service; // prefix 'payment'
  final int? docId;             // null = ยังไม่บันทึก
  final String docNo;
  final double paidLc;          // ยอดจ่ายปัจจุบันบนหน้าจอ (สกุลเงินหลัก)
  final DocCreditState approval;
  final bool isDraft;
  // ก่อนส่งขออนุมัติ (บันทึกร่างให้ยอดที่ขอตรงกับหน้าจอ) — คืน false = ไม่ส่ง
  final Future<bool> Function()? beforeRequest;
  final bool isEnglish;
  final VoidCallback onChanged;

  const ImPaymentApprovalPanel({
    super.key,
    required this.service,
    required this.docId,
    required this.docNo,
    required this.paidLc,
    required this.approval,
    required this.isDraft,
    required this.isEnglish,
    required this.onChanged,
    this.beforeRequest,
  });

  @override
  State<ImPaymentApprovalPanel> createState() => _ImPaymentApprovalPanelState();
}

class _ImPaymentApprovalPanelState extends State<ImPaymentApprovalPanel> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final msg = await fn();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      widget.onChanged();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(bool approve) async {
    final en = widget.isEnglish;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? (en ? 'Approve payment' : 'อนุมัติจ่าย') : (en ? 'Reject payment request' : 'ปฏิเสธคำขออนุมัติจ่าย')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.docNo}  ${_fmt.format(widget.approval.amount ?? widget.paidLc)}'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: en ? 'Remarks (optional)' : 'หมายเหตุ (ถ้ามี)', border: const OutlineInputBorder(), isDense: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(en ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green[700] : Colors.red[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? (en ? 'Approve' : 'อนุมัติ') : (en ? 'Reject' : 'ปฏิเสธ')),
          ),
        ],
      ),
    );
    final remarks = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    await _run(() => approve
        ? widget.service.approve(widget.docId!, remarks: remarks)
        : widget.service.reject(widget.docId!, remarks: remarks));
  }

  Color _stepColor(String s) => switch (s) {
        'Approved' => Colors.green[700]!,
        'Rejected' => Colors.red[700]!,
        'Skipped' => Colors.grey,
        _ => Colors.orange[700]!,
      };

  String _stepLabel(String s, bool en) => switch (s) {
        'Approved' => en ? 'Approved' : 'อนุมัติแล้ว',
        'Rejected' => en ? 'Rejected' : 'ปฏิเสธ',
        'Skipped' => en ? 'Skipped' : 'ข้าม',
        _ => en ? 'Pending' : 'รออนุมัติ',
      };

  @override
  Widget build(BuildContext context) {
    final en = widget.isEnglish;
    final a = widget.approval;
    final paid = widget.paidLc;
    final covered = a.covers(paid);
    final noPayment = paid <= 0.005;
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final menu = MenuScope.of(context);
    final canAct = a.isPending && (menu?.canApprove ?? true) && isMyApprovalTurn(a.approvals, userId, a.approvalMode);
    final color = a.isPending ? Colors.orange[800]! : (covered || noPayment) ? Colors.green[700]! : Colors.red[700]!;
    final statusText = a.isPending
        ? (en ? 'Waiting for payment approval' : 'รออนุมัติจ่าย')
        : noPayment
            ? (en ? 'No payment (deposits cover the purchase)' : 'ไม่มียอดจ่าย (มัดจำครอบคลุม)')
            : covered
                ? (en ? 'Payment approved' : 'อนุมัติจ่ายแล้ว')
                : a.status == 'Approved'
                    ? (en ? 'Amount increased — request approval again' : 'ยอดจ่ายเพิ่มจากที่อนุมัติ — ต้องขออนุมัติใหม่')
                    : (en ? 'Payment approval required before posting' : 'ต้องขออนุมัติจ่ายก่อน Post');
    final canRequest = widget.isDraft && widget.docId != null && !noPayment && !covered && !a.isPending;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_user_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ]),
          Text('${en ? 'Paying' : 'ยอดจ่าย'}: ${_fmt.format(paid)}', style: const TextStyle(fontSize: 13)),
          if (a.amount != null)
            Text('${en ? 'Approved / requested' : 'ยอดที่ขอ/อนุมัติ'}: ${_fmt.format(a.amount)}', style: const TextStyle(fontSize: 13)),
          if (_busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_busy && canRequest)
            OutlinedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: Text(en ? 'Save & request payment approval' : 'บันทึกและขออนุมัติจ่าย'),
              onPressed: menu?.id == null
                  ? null
                  : () async {
                      if (widget.beforeRequest != null && !await widget.beforeRequest!()) return;
                      await _run(() => widget.service.request(widget.docId!, menuId: menu!.id));
                    },
            ),
          if (!_busy && widget.isDraft && widget.docId != null && a.isPending && canAct) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(en ? 'Approve' : 'อนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
              onPressed: () => _decide(true),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text(en ? 'Reject' : 'ปฏิเสธ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
              onPressed: () => _decide(false),
            ),
          ],
          if (!_busy && widget.isDraft && widget.docId != null && a.status != null)
            TextButton.icon(
              icon: const Icon(Icons.undo, size: 16),
              label: Text(a.isPending ? (en ? 'Withdraw request' : 'ถอนคำขอ') : (en ? 'Cancel approval' : 'ยกเลิกการอนุมัติ')),
              onPressed: () => _run(() => widget.service.withdraw(widget.docId!)),
            ),
        ]),
        if (a.approvals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 12, runSpacing: 4, children: [
              for (final s in a.approvals)
                Text(
                  '${s.sequenceNo}. ${s.approverUserName}: ${_stepLabel(s.status, en)}'
                  '${(s.remarks ?? '').isNotEmpty ? ' (${s.remarks})' : ''}',
                  style: TextStyle(fontSize: 12, color: _stepColor(s.status)),
                ),
            ]),
          ),
      ]),
    );
  }
}
