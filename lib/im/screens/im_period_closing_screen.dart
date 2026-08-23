import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../services/im_period_closing_service.dart';

// ปิดงวดสต็อกสินค้าสำหรับโหมด Periodic (ดู pattern_im_periodic_accounting_mode) — คำนวณ
// COGS = ต้นงวด + ซื้อ - ปลายงวด แล้วโพสต์ GL entry เดียวสำหรับทั้งงวด จากนั้นล็อกงวดฝั่ง IM
// (im_status='CLOSED' บน gl_posting_period ผ่าน endpoint เดิมของ GL — ไม่มี endpoint ใหม่)
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
          if (_preview != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEnglish ? 'Closing Preview' : 'ตัวอย่างการปิดงวด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(),
                  _row(isEnglish ? 'Beginning inventory' : 'สินค้าคงเหลือต้นงวด', _preview!.beginningValue),
                  _row(isEnglish ? 'Purchases' : 'ซื้อสินค้าระหว่างงวด', _preview!.purchasesValue),
                  _row(isEnglish ? 'Ending inventory' : 'สินค้าคงเหลือปลายงวด', _preview!.endingValue),
                  const Divider(),
                  _row(isEnglish ? 'Cost of goods sold' : 'ต้นทุนขาย (COGS)', _preview!.cogsValue, bold: true),
                  const SizedBox(height: 8),
                  Text(
                    isEnglish
                        ? 'Purchases is 0 until GRN is available and posts into the configured purchases account.'
                        : 'ยอดซื้อสินค้าเป็น 0 จนกว่าจะมีธุรกรรม GRN และตั้งค่าบัญชีซื้อสินค้าเรียบร้อย',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  if (_preview!.alreadyPosted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(isEnglish ? 'This period has already been closed.' : 'งวดนี้ถูกปิดงวดสต็อกไปแล้ว',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton(
              onPressed: (_isBusy || _preview == null || _preview!.alreadyPosted) ? null : _postClosing,
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
