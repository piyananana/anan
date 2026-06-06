import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                  ? [Chip(label: Text('+${docs.length - 5} รายการ', style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]
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
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบก่อนปิดสิ้นปี'),
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
                const Text('ปีที่ต้องการปิด:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Text('ตรวจสอบ'),
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
                  Text('ผลการตรวจสอบปี $_periodYear',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(height: 24),
                  _checkItem(
                    ok: r.draftCount == 0,
                    label: 'ธุรกรรมสถานะ Draft ค้างอยู่',
                    value: '${r.draftCount} รายการ',
                    docs: r.draftDocs,
                  ),
                  _checkItem(
                    ok: r.openBcCount == 0,
                    isWarning: true,
                    label: 'ใบวางบิลที่ยังไม่ชำระ',
                    value: '${r.openBcCount} ใบ',
                    docs: r.openBcDocs,
                  ),
                  _checkItem(
                    ok: r.openAdvanceCount == 0,
                    isWarning: true,
                    label: 'เงินมัดจำค้างอยู่',
                    value: '${r.openAdvanceCount} รายการ',
                    docs: r.openAdvanceDocs,
                  ),
                  _checkItem(
                    ok: r.reconcileDiff < 1,
                    label: 'ยันยอดลูกหนี้กับบัญชีแยกประเภท',
                    value: r.reconcileDiff < 1 ? 'ตรงกัน ✓' : 'ผลต่าง ${_fmt.format(r.reconcileDiff)}',
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
                      _reconRow('ยอดลูกหนี้คงค้าง', r.arModuleBalance),
                      _reconRow('ยอดลูกหนี้ในบัญชีแยกประเภท', r.glArBalance),
                      const Divider(height: 12),
                      _reconRow('ผลต่าง', r.reconcileDiff,
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
                      child: const Row(children: [
                        Icon(Icons.block, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('กรุณาแก้ไขธุรกรรมสถานะ Draft ก่อนดำเนินการต่อ',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_circle, color: Colors.teal, size: 18),
                        SizedBox(width: 8),
                        Text('พร้อมดำเนินการปิดปี — ไปขั้นตอน ปรับมูลค่าหนี้ตามอัตราแลกเปลี่ยน หรือ สร้างรายการค่าเผื่อหนี้สงสัยจะสูญ',
                            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
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
