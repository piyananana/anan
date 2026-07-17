import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/ar_year_end.dart';
import '../services/ar_year_end_service.dart';

class ArPreCloseCheckScreen extends StatefulWidget {
  const ArPreCloseCheckScreen({super.key});

  @override
  State<ArPreCloseCheckScreen> createState() => _ArPreCloseCheckScreenState();
}

class _ArPreCloseCheckScreenState extends State<ArPreCloseCheckScreen>
    with AutomaticKeepAliveClientMixin {
  final ArYearEndService _svc = ArYearEndService();
  final _fmt    = NumberFormat('#,##0.00', 'en_US');

  bool _isEnglish = false;

  int               _periodYear = DateTime.now().year - 1;
  ArPreCloseResult? _result;
  bool              _isLoading  = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _check() async {
    setState(() { _isLoading = true; _result = null; });
    try {
      final r = await _svc.preCloseCheck(_periodYear);
      setState(() => _result = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _checkItem({
    required bool ok,
    required String label,
    required String value,
    List<Map<String, dynamic>>? docs,
    bool isWarning = false,
  }) {
    final isEnglish = _isEnglish;
    final icon = ok
        ? const Icon(Icons.check_circle, color: Colors.teal, size: 20)
        : isWarning
            ? const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20)
            : const Icon(Icons.cancel, color: Colors.red, size: 20);
    final color = ok ? Colors.teal : isWarning ? Colors.orange : Colors.red;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ]),
      if (docs != null && docs.isNotEmpty) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Wrap(
            spacing: 8, runSpacing: 4,
            children: docs.take(5).map((d) => Chip(
              label: Text(d['doc_no']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Colors.orange[50],
            )).toList()
              ..addAll(docs.length > 5
                  ? [Chip(label: Text(isEnglish ? '+${docs.length - 5} items' : '+${docs.length - 5} รายการ', style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]
                  : []),
          ),
        ),
      ],
      const Divider(height: 20),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Year selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text(isEnglish ? 'Year to close:' : 'ปีที่ต้องการปิด:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<int>(
                    value: _periodYear,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    items: List.generate(5, (i) => DateTime.now().year - i).map((y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: (v) => setState(() => _periodYear = v ?? _periodYear),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 16),
                  label: Text(isEnglish ? 'Check' : 'ตรวจสอบ'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: _isLoading ? null : _check,
                ),
              ]),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 20),
            // Result checklist
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEnglish ? 'Check result for year $_periodYear' : 'ผลการตรวจสอบปี $_periodYear',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(height: 24),
                  _checkItem(
                    ok: r.draftCount == 0,
                    label: isEnglish ? 'Outstanding Draft transactions' : 'ธุรกรรมสถานะ Draft ค้างอยู่',
                    value: isEnglish ? '${r.draftCount} items' : '${r.draftCount} รายการ',
                    docs: r.draftDocs,
                  ),
                  _checkItem(
                    ok: r.openBcCount == 0,
                    isWarning: true,
                    label: isEnglish ? 'Unpaid billing statements' : 'ใบวางบิลที่ยังไม่ชำระ',
                    value: isEnglish ? '${r.openBcCount} items' : '${r.openBcCount} ใบ',
                    docs: r.openBcDocs,
                  ),
                  _checkItem(
                    ok: r.openAdvanceCount == 0,
                    isWarning: true,
                    label: isEnglish ? 'Outstanding advance receipts' : 'เงินมัดจำค้างอยู่',
                    value: isEnglish ? '${r.openAdvanceCount} items' : '${r.openAdvanceCount} รายการ',
                    docs: r.openAdvanceDocs,
                  ),
                  _checkItem(
                    ok: r.reconcileDiff < 1,
                    label: isEnglish ? 'Reconcile AR balance with GL' : 'ยันยอดลูกหนี้กับบัญชีแยกประเภท',
                    value: r.reconcileDiff < 1
                        ? (isEnglish ? 'Matched ✓' : 'ตรงกัน ✓')
                        : (isEnglish ? 'Difference ${_fmt.format(r.reconcileDiff)}' : 'ผลต่าง ${_fmt.format(r.reconcileDiff)}'),
                  ),
                  // Reconcile detail
                  Container(
                    margin: const EdgeInsets.only(left: 28, bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(children: [
                      _reconRow(isEnglish ? 'Outstanding AR balance' : 'ยอดลูกหนี้คงค้าง', r.arModuleBalance),
                      _reconRow(isEnglish ? 'AR balance in GL' : 'ยอดลูกหนี้ในบัญชีแยกประเภท', r.glArBalance),
                      const Divider(height: 12),
                      _reconRow(isEnglish ? 'Difference' : 'ผลต่าง', r.reconcileDiff,
                          bold: true,
                          color: r.reconcileDiff < 1 ? Colors.teal : Colors.red),
                    ]),
                  ),
                  if (!r.canProceed)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.block, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(isEnglish
                            ? 'Please resolve outstanding Draft transactions before proceeding'
                            : 'กรุณาแก้ไขธุรกรรมสถานะ Draft ก่อนดำเนินการต่อ',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.teal, size: 18),
                        const SizedBox(width: 8),
                        Text(isEnglish
                            ? 'Ready to close the year — proceed to FX Revaluation or create Allowance for Doubtful Accounts entries'
                            : 'พร้อมดำเนินการปิดปี — ไปขั้นตอน ปรับมูลค่าหนี้ตามอัตราแลกเปลี่ยน หรือ สร้างรายการค่าเผื่อหนี้สงสัยจะสูญ',
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _reconRow(String label, double amount, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label,
          style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(_fmt.format(amount),
          style: TextStyle(fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color)),
    ]),
  );
}
