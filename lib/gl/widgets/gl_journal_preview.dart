// lib/gl/widgets/gl_journal_preview.dart
// ตารางรายการบัญชี (ดูอย่างเดียว) ที่ backend คำนวณให้ — ก่อนโพสต์คือรายการที่จะเกิด, หลังโพสต์คือรายการจริง
// รูปแบบบรรทัดจาก backend utils/glJournalPreview.js:
//   { account_code, account_name_th, account_name_en, description, debit, credit }
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GlJournalLine {
  final String accountCode;
  final String accountNameTh;
  final String accountNameEn;
  final String description;
  final double debit;
  final double credit;

  const GlJournalLine({
    required this.accountCode,
    required this.accountNameTh,
    required this.accountNameEn,
    required this.description,
    required this.debit,
    required this.credit,
  });

  factory GlJournalLine.fromJson(Map<String, dynamic> j) => GlJournalLine(
        accountCode:   j['account_code']?.toString() ?? '',
        accountNameTh: j['account_name_th']?.toString() ?? '',
        accountNameEn: j['account_name_en']?.toString() ?? '',
        description:   j['description']?.toString() ?? '',
        debit:  double.tryParse(j['debit']?.toString() ?? '') ?? 0,
        credit: double.tryParse(j['credit']?.toString() ?? '') ?? 0,
      );

  static List<GlJournalLine> listFromJson(dynamic list) => (list as List? ?? const [])
      .map((e) => GlJournalLine.fromJson(e as Map<String, dynamic>))
      .toList();

  String accountName(bool isEnglish) =>
      isEnglish && accountNameEn.isNotEmpty ? accountNameEn : accountNameTh;
}

class GlJournalPreview extends StatelessWidget {
  final List<GlJournalLine> lines;
  final bool isEnglish;
  /// true = รายการที่โพสต์แล้ว, false = รายการที่จะเกิดเมื่อโพสต์
  final bool posted;
  /// ข้อความเมื่อคำนวณรายการบัญชีไม่ได้ (เช่น ยังไม่ได้ตั้งค่าบัญชี)
  final String? error;
  /// หมายเหตุใต้ตาราง (เช่น รายการกลับต้นงวด)
  final String? note;

  const GlJournalPreview({
    super.key,
    required this.lines,
    required this.isEnglish,
    this.posted = false,
    this.error,
    this.note,
  });

  static final _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final totalDr = lines.fold<double>(0, (s, l) => s + l.debit);
    final totalCr = lines.fold<double>(0, (s, l) => s + l.credit);
    final balanced = (totalDr - totalCr).abs() < 0.005;
    final hasDesc = lines.any((l) => l.description.isNotEmpty);
    const small = TextStyle(fontSize: 12);
    const bold = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

    Widget cell(String text, {TextStyle style = small, TextAlign align = TextAlign.left}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text, style: style, textAlign: align),
        );
    String amt(double v) => v == 0 ? '' : _fmt.format(v);

    final title = posted
        ? (isEnglish ? 'Journal Entry (posted)' : 'รายการบัญชี (โพสต์แล้ว)')
        : (isEnglish ? 'Journal Entry Preview (on Post)' : 'รายการบัญชีที่จะเกิด (เมื่อโพสต์)');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.account_balance_outlined, size: 16, color: Colors.teal.shade700),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (lines.isNotEmpty && !balanced) ...[
              const SizedBox(width: 12),
              Text(isEnglish ? 'Not balanced' : 'ไม่สมดุล',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            ],
          ]),
          const SizedBox(height: 8),
          if ((error ?? '').isNotEmpty)
            Text(error!, style: TextStyle(fontSize: 12, color: Colors.red.shade700))
          else if (lines.isEmpty)
            Text(isEnglish ? 'No journal lines' : 'ไม่มีรายการบัญชี',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          else
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: {
                0: const FixedColumnWidth(100),
                1: const FlexColumnWidth(2),
                if (hasDesc) 2: const FlexColumnWidth(2),
                (hasDesc ? 3 : 2): const FixedColumnWidth(120),
                (hasDesc ? 4 : 3): const FixedColumnWidth(120),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.teal.shade50),
                  children: [
                    cell(isEnglish ? 'Account' : 'รหัสบัญชี', style: bold),
                    cell(isEnglish ? 'Account Name' : 'ชื่อบัญชี', style: bold),
                    if (hasDesc) cell(isEnglish ? 'Description' : 'คำอธิบาย', style: bold),
                    cell(isEnglish ? 'Debit' : 'เดบิต', style: bold, align: TextAlign.right),
                    cell(isEnglish ? 'Credit' : 'เครดิต', style: bold, align: TextAlign.right),
                  ],
                ),
                for (final l in lines)
                  TableRow(children: [
                    cell(l.accountCode),
                    cell(l.accountName(isEnglish)),
                    if (hasDesc) cell(l.description),
                    cell(amt(l.debit), align: TextAlign.right),
                    cell(amt(l.credit), align: TextAlign.right),
                  ]),
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    cell(isEnglish ? 'Total' : 'รวม', style: bold),
                    const SizedBox(),
                    if (hasDesc) const SizedBox(),
                    cell(_fmt.format(totalDr), style: bold, align: TextAlign.right),
                    cell(_fmt.format(totalCr), style: bold, align: TextAlign.right),
                  ],
                ),
              ],
            ),
          if ((note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note!, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade600)),
          ],
        ]),
      ),
    );
  }
}
