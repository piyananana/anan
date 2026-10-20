// แผงขั้นตอนอนุมัติเอกสาร (คิวผู้อนุมัติของเมนู — backend utils/docApproval.js)
// แสดงผู้อนุมัติแต่ละลำดับ + ปุ่มอนุมัติ/ปฏิเสธ เมื่อถึงคิวผู้ใช้นี้และมีสิทธิ์ "อนุมัติ" ในเมนู
// ใช้ร่วม PO / SO / เปลี่ยนแปลงราคา / ตรวจนับสต็อก / ใบสั่งผลิต
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sa_doc_approval.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_menu_scope.dart';

class DocApprovalPanel extends StatefulWidget {
  final String docNo;
  final List<DocApprovalStep> approvals;
  final String? approvalMode; // ALL / ANY
  final bool awaiting; // เอกสารอยู่ระหว่างรออนุมัติ (เช่น สถานะ Submitted)
  final Future<void> Function(String? remarks) onApprove;
  final Future<void> Function(String? remarks) onReject;
  final Future<void> Function() onDone; // โหลดเอกสารใหม่หลังอนุมัติ/ปฏิเสธ

  const DocApprovalPanel({
    super.key,
    required this.docNo,
    required this.approvals,
    required this.approvalMode,
    required this.awaiting,
    required this.onApprove,
    required this.onReject,
    required this.onDone,
  });

  @override
  State<DocApprovalPanel> createState() => _DocApprovalPanelState();
}

class _DocApprovalPanelState extends State<DocApprovalPanel> {
  bool _busy = false;

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

  Future<void> _decide(bool approve, bool isEnglish) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? (isEnglish ? 'Confirm Approval' : 'ยืนยันการอนุมัติ') : (isEnglish ? 'Confirm Rejection' : 'ยืนยันการปฏิเสธ')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(approve ? (isEnglish ? 'Approve ${widget.docNo}?' : 'อนุมัติ ${widget.docNo}?') : (isEnglish ? 'Reject ${widget.docNo}?' : 'ปฏิเสธ ${widget.docNo}?')),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Remarks (optional)' : 'หมายเหตุ (ถ้ามี)', border: const OutlineInputBorder(), isDense: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: approve ? Colors.green[700] : Colors.red[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? (isEnglish ? 'Approve' : 'อนุมัติ') : (isEnglish ? 'Reject' : 'ปฏิเสธ')),
          ),
        ],
      ),
    );
    final remarks = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (approve) {
        await widget.onApprove(remarks);
      } else {
        await widget.onReject(remarks);
      }
      messenger.showSnackBar(SnackBar(
          content: Text(approve ? (isEnglish ? 'Approved successfully' : 'อนุมัติสำเร็จ') : (isEnglish ? 'Rejected successfully' : 'ปฏิเสธสำเร็จ'))));
      await widget.onDone();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final steps = widget.approvals;
    if (steps.isEmpty) return const SizedBox.shrink();
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final canApproveMenu = MenuScope.of(context)?.canApprove ?? true;
    final canAct = widget.awaiting && canApproveMenu && isMyApprovalTurn(steps, userId, widget.approvalMode);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.approval_outlined, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 6),
          Text(isEnglish ? 'Approval Steps' : 'ขั้นตอนการอนุมัติ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (widget.approvalMode == 'ANY')
            Text(isEnglish ? '  (any one approver)' : '  (คนใดคนหนึ่ง)', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const Spacer(),
          if (_busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_busy && canAct) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(isEnglish ? 'Approve' : 'อนุมัติ', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
              onPressed: () => _decide(true, isEnglish),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text(isEnglish ? 'Reject' : 'ปฏิเสธ', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
              onPressed: () => _decide(false, isEnglish),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 16, runSpacing: 4, children: [
          for (final a in steps)
            Text(
              '${a.sequenceNo}. ${a.approverUserName}: ${_stepLabel(a.status, isEnglish)}'
              '${(a.remarks ?? '').isNotEmpty ? ' (${a.remarks})' : ''}',
              style: TextStyle(fontSize: 12, color: _stepColor(a.status)),
            ),
        ]),
      ]),
    );
  }
}
