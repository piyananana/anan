import 'package:flutter/material.dart';
import '../models/sa_document_reverse_log.dart';

// ส่วนประกอบหน้าจอสำหรับการถอยเอกสารเป็นร่าง / ลบเอกสาร — ใช้ร่วมทุกโมดูล

/// กล่องยืนยันที่ต้องกรอกเหตุผล (ถอยเป็นร่าง / ลบ) — คืนเหตุผล หรือ null ถ้ายกเลิก
Future<String?> showDocReasonDialog(
  BuildContext context, {
  required bool isEnglish,
  required String title,
  required String message,
  required String confirmLabel,
  Color confirmColor = Colors.red,
}) async {
  final reasonCtrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final empty = reasonCtrl.text.trim().isEmpty;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                maxLength: 500,
                maxLines: 2,
                onChanged: (_) => setD(() {}),
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Reason *' : 'เหตุผล *',
                  border: const OutlineInputBorder(),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
              onPressed: empty ? null : () => Navigator.pop(ctx, reasonCtrl.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  reasonCtrl.dispose();
  return (reason == null || reason.isEmpty) ? null : reason;
}

/// กรอบประวัติการถอยเป็นร่าง / การลบ / การยกเลิก (ล่าสุดก่อน) — แสดงเมื่อมีประวัติ
class DocReverseHistoryPanel extends StatelessWidget {
  final List<DocReverseLog> history;
  final bool isDeleted;
  final bool isEnglish;
  final EdgeInsetsGeometry margin;
  final String? title;

  const DocReverseHistoryPanel({
    super.key,
    required this.history,
    required this.isDeleted,
    required this.isEnglish,
    this.margin = const EdgeInsets.fromLTRB(8, 0, 8, 4),
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime? d) =>
        d == null ? '' : '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 6),
          Text(
              isDeleted
                  ? (isEnglish
                      ? 'Deleted — kept for audit, cannot be used again'
                      : 'ลบแล้ว — เก็บไว้เพื่อตรวจสอบ นำกลับมาใช้ต่อไม่ได้')
                  : (title ?? (isEnglish ? 'Reverse / void history' : 'ประวัติการถอยเป็นร่าง / ยกเลิก')),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange[900])),
        ]),
        for (final h in history)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
                '${fmt(h.createdAt)}  '
                '${h.actionLabel(isEnglish)}'
                '  ${h.createdByName ?? '-'}  —  ${h.reason}',
                style: const TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }
}
