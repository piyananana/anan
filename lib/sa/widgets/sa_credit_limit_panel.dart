import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sa_credit_approval.dart';
import '../models/sa_doc_approval.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_credit_approval_service.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_menu_scope.dart';

final _fmt = NumberFormat('#,##0.00');

// ตรวจวงเงินก่อนกด Post — คืน true = โพสต์ต่อได้
// เกินวงเงินและยังไม่ได้รับอนุมัติ: ถามว่าจะ "บันทึกร่างและขออนุมัติ" ไหม (saveDraft คืน id ของร่าง, null = บันทึกไม่สำเร็จ)
// backend ตรวจซ้ำตอนโพสต์เสมอ — ตรงนี้แค่ให้ผู้ใช้รู้ก่อนและส่งคำขอได้ทันที
Future<bool> checkCreditBeforePost(
  BuildContext context, {
  required CreditApprovalService service,
  required int customerId,
  required int? docId,
  required double amount,
  required DocCreditState credit,
  required Future<int?> Function() saveDraft,
  VoidCallback? onRequested,
}) async {
  final isEnglish = context.read<LanguageProvider>().isEnglish;
  final messenger = ScaffoldMessenger.of(context);
  final menuId = MenuScope.of(context)?.id;
  CreditInfo info;
  try {
    info = await service.info(customerId, excludeId: docId);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    return false;
  }
  if (!info.exceeded(amount) || credit.covers(amount)) return true;
  if (credit.isPending) {
    messenger.showSnackBar(SnackBar(content: Text(isEnglish
        ? 'This document is waiting for credit limit approval'
        : 'เอกสารนี้อยู่ระหว่างรออนุมัติเกินวงเงินเครดิต')));
    return false;
  }
  if (!context.mounted) return false;
  final after = info.after(amount);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
        const SizedBox(width: 8),
        Text(isEnglish ? 'Credit limit exceeded' : 'เกินวงเงินเครดิต'),
      ]),
      content: Text(isEnglish
          ? 'Balance after this document ${_fmt.format(after)} exceeds the credit limit ${_fmt.format(info.creditLimit)} '
              '(over ${_fmt.format(after - info.creditLimit)}).\nApproval is required before posting.'
          : 'ยอดหนี้หลังเอกสารนี้ ${_fmt.format(after)} เกินวงเงินเครดิต ${_fmt.format(info.creditLimit)} '
              '(เกิน ${_fmt.format(after - info.creditLimit)})\nต้องขออนุมัติก่อนโพสต์'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
        ElevatedButton.icon(
          icon: const Icon(Icons.send, size: 16),
          label: Text(isEnglish ? 'Save draft & request approval' : 'บันทึกร่างและขออนุมัติ'),
          onPressed: menuId == null ? null : () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final id = await saveDraft();
  if (id == null || menuId == null) return false;
  try {
    final msg = await service.request(id, menuId: menuId);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
    onRequested?.call();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }
  return false;
}

// กล่องวงเงินเครดิตของลูกค้าในหน้าจอเอกสาร + สถานะ/ขั้นตอนอนุมัติ + ปุ่มขอ / ถอน / อนุมัติ / ปฏิเสธ
class CreditLimitPanel extends StatefulWidget {
  final CreditApprovalService service;
  final int? customerId;
  final int? docId;          // null = ยังไม่บันทึก (ขออนุมัติไม่ได้)
  final String docNo;
  final double amount;       // ยอดเอกสาร รวม VAT (ใบลดหนี้ติดลบ)
  final DocCreditState credit;
  final bool isDraft;
  final VoidCallback onChanged; // หลังขอ/ถอน/อนุมัติ/ปฏิเสธ — ให้หน้าจอโหลดเอกสารใหม่

  const CreditLimitPanel({
    super.key,
    required this.service,
    required this.customerId,
    required this.docId,
    required this.docNo,
    required this.amount,
    required this.credit,
    required this.isDraft,
    required this.onChanged,
  });

  @override
  State<CreditLimitPanel> createState() => _CreditLimitPanelState();
}

class _CreditLimitPanelState extends State<CreditLimitPanel> {
  CreditInfo? _info;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CreditLimitPanel old) {
    super.didUpdateWidget(old);
    if (old.customerId != widget.customerId || old.docId != widget.docId || old.credit.status != widget.credit.status) {
      _load();
    }
  }

  Future<void> _load() async {
    final cid = widget.customerId;
    if (cid == null) {
      setState(() => _info = null);
      return;
    }
    try {
      final info = await widget.service.info(cid, excludeId: widget.docId);
      if (mounted && widget.customerId == cid) setState(() => _info = info);
    } catch (_) {
      if (mounted) setState(() => _info = null);
    }
  }

  Future<void> _run(Future<String> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final msg = await fn();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      widget.onChanged();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(bool approve, bool isEnglish) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve
            ? (isEnglish ? 'Approve credit limit excess' : 'อนุมัติเกินวงเงินเครดิต')
            : (isEnglish ? 'Reject credit limit request' : 'ปฏิเสธคำขอเกินวงเงินเครดิต')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.docNo),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Remarks (optional)' : 'หมายเหตุ (ถ้ามี)',
                border: const OutlineInputBorder(), isDense: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green[700] : Colors.red[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? (isEnglish ? 'Approve' : 'อนุมัติ') : (isEnglish ? 'Reject' : 'ปฏิเสธ')),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final info = _info;
    final credit = widget.credit;
    if (widget.customerId == null || info == null) return const SizedBox.shrink();
    if (!info.checked && credit.status == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(isEnglish ? 'Credit limit: not set (not checked)' : 'วงเงินเครดิต: ไม่ได้กำหนด (ไม่ตรวจ)',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }
    final after = info.after(widget.amount);
    final exceeded = info.exceeded(widget.amount);
    final covered = credit.covers(widget.amount);
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final canApproveMenu = MenuScope.of(context)?.canApprove ?? true;
    final steps = credit.approvals;
    // ถึงคิวผู้ใช้นี้ (ตามลำดับ / คนใดคนหนึ่ง)
    final canAct = credit.isPending && canApproveMenu && isMyApprovalTurn(steps, userId, credit.approvalMode);
    final color = !exceeded ? Colors.green[700]! : covered ? Colors.blue[700]! : Colors.red[700]!;

    Widget cell(String label, double v, {Color? c, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(_fmt.format(v), style: TextStyle(fontSize: 13, color: c, fontWeight: bold ? FontWeight.bold : null)),
          ]),
        );

    final statusText = credit.isPending
        ? (isEnglish ? 'Waiting for approval' : 'รออนุมัติเกินวงเงิน')
        : covered
            ? (isEnglish ? 'Over limit — approved' : 'เกินวงเงิน — อนุมัติแล้ว')
            : exceeded
                ? (isEnglish ? 'Over limit — approval required' : 'เกินวงเงิน — ต้องขออนุมัติ')
                : (isEnglish ? 'Within limit' : 'อยู่ในวงเงิน');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.credit_score, size: 18, color: color),
              const SizedBox(width: 6),
              Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ]),
          ),
          cell(isEnglish ? 'Credit limit' : 'วงเงิน', info.creditLimit),
          cell(isEnglish ? 'Outstanding' : 'ยอดคงค้าง', info.outstanding),
          cell(isEnglish ? 'This document' : 'เอกสารนี้', widget.amount),
          cell(isEnglish ? 'After' : 'ยอดหลังเอกสาร', after, c: exceeded ? Colors.red[700] : null, bold: true),
          if (exceeded) cell(isEnglish ? 'Over' : 'เกิน', after - info.creditLimit, c: Colors.red[700], bold: true),
          if (_busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_busy && widget.isDraft && widget.docId != null && exceeded && !covered && credit.status != 'Pending')
            OutlinedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: Text(isEnglish ? 'Request approval' : 'ขออนุมัติเกินวงเงิน'),
              onPressed: MenuScope.of(context)?.id == null
                  ? null
                  : () => _run(() => widget.service.request(widget.docId!, menuId: MenuScope.of(context)!.id)),
            ),
          if (!_busy && widget.isDraft && credit.isPending) ...[
            if (canAct) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
                onPressed: () => _decide(true, isEnglish),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text(isEnglish ? 'Reject' : 'ปฏิเสธ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
                onPressed: () => _decide(false, isEnglish),
              ),
              const SizedBox(width: 8),
            ],
            TextButton.icon(
              icon: const Icon(Icons.undo, size: 16),
              label: Text(isEnglish ? 'Withdraw request' : 'ถอนคำขอ'),
              onPressed: () => _run(() => widget.service.withdraw(widget.docId!)),
            ),
          ],
        ]),
        if (credit.status == 'Approved' && !covered && exceeded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                isEnglish
                    ? 'Approved for ${_fmt.format(credit.amount ?? 0)} — the document amount increased, request approval again'
                    : 'อนุมัติไว้ที่ยอด ${_fmt.format(credit.amount ?? 0)} — ยอดเอกสารเพิ่มขึ้น ต้องขออนุมัติใหม่',
                style: TextStyle(fontSize: 12, color: Colors.red[700])),
          ),
        if (steps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 12, runSpacing: 4, children: [
              for (final a in steps)
                Text(
                  '${a.sequenceNo}. ${a.approverUserName}: ${_stepLabel(a.status, isEnglish)}'
                  '${(a.remarks ?? '').isNotEmpty ? ' (${a.remarks})' : ''}',
                  style: TextStyle(fontSize: 12, color: _stepColor(a.status)),
                ),
            ]),
          ),
      ]),
    );
  }
}
