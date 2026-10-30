import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../services/im_period_closing_service.dart';

// ปิดงวดสต็อกสินค้า Periodic แบบปรับยอดให้ตรง (ดู computeClosing ใน imPeriodClosingController.js และ
// project_im_mixed_accounting_mode) — แสดงการกระทบยอดบัญชีสต็อกกับมูลค่าสต็อก ณ วันสิ้นงวด และรายการบัญชีที่จะโพสต์
// แล้วโพสต์ GL entry เดียวสำหรับทั้งงวด จากนั้นล็อกงวดฝั่ง IM (im_status='CLOSED' ผ่าน endpoint เดิมของ GL)
class ImPeriodClosingScreen extends StatefulWidget {
  const ImPeriodClosingScreen({super.key});

  @override
  State<ImPeriodClosingScreen> createState() => _ImPeriodClosingScreenState();
}

class _ImPeriodClosingScreenState extends State<ImPeriodClosingScreen> {
  final ImPeriodClosingService _svc = ImPeriodClosingService();
  final PeriodService _periodSvc = PeriodService();
  final _fmtMoney = NumberFormat('#,##0.00');

  bool _isLoading = true;
  bool _isBusy = false;

  List<PostingPeriod> _periods = [];
  PostingPeriod? _selectedPeriod;
  ImPeriodClosingPreview? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final all = await _periodSvc.fetchOpenGlPeriods();
      _periods = all.where((p) => p.imStatus != 'CLOSED').toList()
        ..sort((a, b) => a.periodStartDate.compareTo(b.periodStartDate));
      if (_periods.isNotEmpty) {
        _selectedPeriod = _periods.first;
        await _loadPreview();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPreview() async {
    if (_selectedPeriod == null) return;
    setState(() => _isBusy = true);
    try {
      _preview = await _svc.fetchPreview(_selectedPeriod!.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('โหลดตัวอย่างล้มเหลว: $e')));
      _preview = null;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _postClosing() async {
    if (_selectedPeriod == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันปิดงวดสต็อก'),
        content: Text('โพสต์ GL entry ปิดงวดสต็อกสำหรับงวด "${_selectedPeriod!.periodName}"? การกระทำนี้ย้อนกลับไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isBusy = true);
    try {
      await _svc.confirmClose(_selectedPeriod!.id);
      await _loadPreview();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('โพสต์ปิดงวดสต็อกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ปิดงวดล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _lockPeriod() async {
    if (_selectedPeriod == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันล็อกงวด IM'),
        content: Text('ล็อกงวด "${_selectedPeriod!.periodName}" สำหรับ IM? หลังจากนี้จะไม่สามารถ Post ธุรกรรม IM ในงวดนี้ได้อีก'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isBusy = true);
    try {
      await _periodSvc.updateStatusDetailRow(_selectedPeriod!.id, 'im', 'CLOSED');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ล็อกงวด IM สำเร็จ')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ล็อกงวดล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _row(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
          Text(_fmtMoney.format(value), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  Widget _messages(List<String> items, Color color, IconData icon) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(m, style: TextStyle(color: color, fontSize: 12))),
              ]),
            ),
        ],
      );

  Widget _cell(String text, {bool right = false, bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      );

  List<Widget> _buildPreview(ImPeriodClosingPreview p, bool isEnglish) {
    String money(double v) => _fmtMoney.format(v);
    return [
      if (p.errors.isNotEmpty) _messages(p.errors, Colors.red.shade700, Icons.block),
      if (p.warnings.isNotEmpty) _messages(p.warnings, Colors.orange.shade800, Icons.warning_amber),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish ? 'Closing Summary' : 'สรุปการปิดงวด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(),
            _row(isEnglish ? 'Inventory GL balance before adjustment' : 'ยอด GL บัญชีสต็อกก่อนปรับ', p.beginningValue),
            _row(isEnglish ? 'Stock value at period end' : 'มูลค่าสต็อก ณ วันสิ้นงวด', p.endingValue),
            _row(isEnglish ? 'Inventory adjustment' : 'ปรับปรุงบัญชีสต็อก', p.inventoryAdjustment),
            _row(isEnglish ? 'Net purchases in the period (closed)' : 'ซื้อสุทธิในงวด (ปิดบัญชี)', p.purchasesValue),
            const Divider(),
            _row(isEnglish ? 'Cost of goods sold' : 'ต้นทุนขาย (COGS)', p.cogsValue, bold: true),
            _row(isEnglish ? '  - per item COGS account (sold/issued at stock cost)' : '  - ตามบัญชีต้นทุนของสินค้า (ขาย/เบิกตามต้นทุนสต็อก)', p.subledgerCogs),
            _row(isEnglish ? '  - adjustment difference (default COGS account)' : '  - ส่วนต่างจากการปรับยอด (บัญชีต้นทุนเริ่มต้น)', p.residualCogs),
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? 'COGS = net purchases - inventory adjustment. The difference covers shrinkage, count adjustments, purchase price differences and any other GL postings to these accounts.'
                  : 'ต้นทุนขาย = ซื้อสุทธิ - ส่วนที่ปรับเพิ่มบัญชีสต็อก ส่วนต่างรวมสินค้าสูญหาย การปรับยอดนับ ส่วนต่างราคาซื้อ และรายการ GL อื่นที่ลงบัญชีเหล่านี้',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
            if (p.alreadyPosted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(isEnglish ? 'This period has already been closed.' : 'งวดนี้ถูกปิดงวดสต็อกไปแล้ว',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish ? 'Inventory Reconciliation (GL vs stock at period end)' : 'กระทบยอดบัญชีสต็อก (GL เทียบมูลค่าสต็อก ณ วันสิ้นงวด)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
                children: [
                  TableRow(decoration: BoxDecoration(color: Colors.grey.shade200), children: [
                    _cell(isEnglish ? 'Account' : 'บัญชี', bold: true),
                    _cell(isEnglish ? 'GL balance' : 'ยอด GL', right: true, bold: true),
                    _cell(isEnglish ? 'Stock value' : 'มูลค่าสต็อก', right: true, bold: true),
                    _cell('Periodic', right: true, bold: true),
                    _cell('Perpetual', right: true, bold: true),
                    _cell(isEnglish ? 'Difference' : 'ผลต่าง', right: true, bold: true),
                    _cell(isEnglish ? 'Adjust' : 'ปรับยอด', bold: true),
                  ]),
                  for (final r in p.reconciliation)
                    TableRow(children: [
                      _cell('${r.accountCode} ${r.name(isEnglish)}'),
                      _cell(money(r.num('gl_balance')), right: true),
                      _cell(money(r.num('stock_value')), right: true),
                      _cell(money(r.num('periodic_value')), right: true),
                      _cell(money(r.num('perpetual_value')), right: true),
                      _cell(money(r.num('difference')), right: true,
                          color: r.num('difference').abs() >= 0.005 ? Colors.red.shade700 : null),
                      _cell(r.raw['adjusted'] == true ? (isEnglish ? 'Yes' : 'ปรับ') : (isEnglish ? 'No (Perpetual only)' : 'ไม่ปรับ (มีแต่ Perpetual)')),
                    ]),
                ],
              ),
            ),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish ? 'Closing Journal Preview' : 'ตัวอย่างรายการบัญชีปิดงวด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(),
            if (p.journal.isEmpty)
              Text(isEnglish ? 'Nothing to post.' : 'ไม่มีรายการที่ต้องโพสต์', style: TextStyle(color: Colors.grey.shade600))
            else
              for (final j in p.journal)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${j.accountCode} ${j.name(isEnglish)}', style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 120, child: Text(j.num('debit') > 0 ? money(j.num('debit')) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 120, child: Text(j.num('credit') > 0 ? money(j.num('credit')) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                  ]),
                ),
          ]),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEnglish ? 'IM Period-End Closing' : 'ปิดงวดสต็อกสินค้า (Periodic)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (_periods.isEmpty)
          Text(isEnglish ? 'No open periods to close.' : 'ไม่มีงวดที่เปิดให้ปิด', style: TextStyle(color: Colors.grey.shade600))
        else ...[
          DropdownButtonFormField<int>(
            value: _selectedPeriod?.id,
            decoration: InputDecoration(labelText: isEnglish ? 'Period' : 'งวดบัญชี', border: const OutlineInputBorder(), isDense: true),
            items: _periods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.periodName))).toList(),
            onChanged: (v) {
              setState(() => _selectedPeriod = _periods.firstWhere((p) => p.id == v));
              _loadPreview();
            },
          ),
          const SizedBox(height: 16),
          if (_preview != null) ..._buildPreview(_preview!, isEnglish),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton(
              onPressed: (_isBusy || _preview == null || _preview!.alreadyPosted || _preview!.errors.isNotEmpty) ? null : _postClosing,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              child: Text(isEnglish ? 'Post Closing Entry' : 'โพสต์ปิดงวด'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: (_isBusy || _preview == null || !_preview!.alreadyPosted) ? null : _lockPeriod,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              child: Text(isEnglish ? 'Lock IM Period' : 'ล็อกงวด IM'),
            ),
            if (_isBusy) ...[
              const SizedBox(width: 12),
              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ]),
        ],
      ]),
    );
  }
}
