// lib/im/screens/im_stock_count_summary_screen.dart — ขั้นตอนที่ 6: สรุปผลการตรวจนับ
// รูปแบบคล้ายการปิดสิ้นปี AR/AP: เลือกเอกสาร -> ตรวจผล (read-only) -> อนุมัติ (canApprove) -> บันทึกปรับยอด (หลังอนุมัติ)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/im_stock_count.dart';
import '../services/im_stock_count_service.dart';
import '../widgets/im_stock_count_picker_field.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';

class ImStockCountSummaryScreen extends StatefulWidget {
  const ImStockCountSummaryScreen({super.key});

  @override
  State<ImStockCountSummaryScreen> createState() => _ImStockCountSummaryScreenState();
}

class _ImStockCountSummaryScreenState extends State<ImStockCountSummaryScreen> {
  final ImStockCountService _service = ImStockCountService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _fmtInt = NumberFormat('#,##0');
  final _fmtMoney = NumberFormat('#,##0.00');

  bool _isEnglish = false;
  bool _isChecking = false;
  bool _isSaving = false;

  ImStockCountHeader? _selectedCount;
  ImStockCountCheckResult? _result;

  Future<void> _checkResults() async {
    final isEnglish = _isEnglish;
    if (_selectedCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a count sheet' : 'กรุณาเลือกใบตรวจนับ')));
      return;
    }
    setState(() => _isChecking = true);
    try {
      final result = await _service.checkResults(_selectedCount!.id);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _refreshSelectedCount() async {
    if (_selectedCount == null) return;
    try {
      final rows = await _service.fetchRows();
      final updated = rows.where((r) => r.id == _selectedCount!.id);
      if (updated.isNotEmpty && mounted) setState(() => _selectedCount = updated.first);
    } catch (_) {
      // เงียบไว้ — ไม่ใช่ operation หลัก
    }
  }

  Future<void> _approve() async {
    final isEnglish = _isEnglish;
    if (_selectedCount == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Approve Count Results' : 'อนุมัติผลการตรวจนับ'),
        content: Text(isEnglish ? 'Approve the results shown above?' : 'ยืนยันอนุมัติผลการตรวจนับตามที่แสดงด้านบนหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Approve' : 'อนุมัติ')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.approveCount(_selectedCount!.id);
      await _refreshSelectedCount();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Approved' : 'อนุมัติสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Approve failed: $e' : 'อนุมัติล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAdjustment() async {
    final isEnglish = _isEnglish;
    if (_selectedCount == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Save Adjustment' : 'บันทึกปรับยอด'),
        content: Text(isEnglish
            ? 'This posts a stock adjustment (AJS) for all variance lines and closes this count sheet. Continue?'
            : 'การบันทึกปรับยอดจะสร้างและ Post ใบปรับยอดสินค้า (AJS) สำหรับทุกรายการที่มีผลต่าง และปิดใบตรวจนับนี้ ยืนยันหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Save Adjustment' : 'บันทึกปรับยอด'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.closeCount(_selectedCount!.id);
      await _refreshSelectedCount();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Adjustment saved — count sheet closed' : 'บันทึกปรับยอดสำเร็จ — ปิดใบตรวจนับแล้ว')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _summaryLine(String label, List<MapEntry<String, String>> parts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 160, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: Wrap(
            spacing: 24,
            runSpacing: 4,
            children: parts
                .map((p) => Text.rich(TextSpan(children: [
                      TextSpan(text: '${p.key}: ', style: TextStyle(color: Colors.grey.shade700)),
                      TextSpan(text: p.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ])))
                .toList(),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canApprove = perm?.canApprove ?? false;
    final isApproved = _selectedCount?.status == 'Approved';
    final isPosted = _selectedCount?.status == 'Posted';

    return Scaffold(
      appBar: AppBar(title: const MenuTitle(), backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEnglish ? 'Count Result Summary' : 'สรุปผลการตรวจนับ', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: isEnglish ? 'Count Sheet *' : 'ใบตรวจนับ *', border: const OutlineInputBorder(), isDense: true),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                _selectedCount != null ? '${_selectedCount!.countNo} — ${_dateFmt.format(_selectedCount!.countDate)}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.teal, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => ImStockCountPickerField.search(context, onSelected: (h) => setState(() { _selectedCount = h; _result = null; })),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _isChecking ? null : _checkResults,
                        icon: _isChecking
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.fact_check, size: 18),
                        label: Text(isEnglish ? 'Check Results' : 'ตรวจผล'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      if (canApprove)
                        ElevatedButton.icon(
                          onPressed: (_result == null || !isPosted || _isSaving) ? null : _approve,
                          icon: const Icon(Icons.verified, size: 18),
                          label: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
                        ),
                      if (isApproved) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveAdjustment,
                          icon: const Icon(Icons.save, size: 18),
                          label: Text(isEnglish ? 'Save Adjustment' : 'บันทึกปรับยอด'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                        ),
                      ],
                    ]),
                    if (_selectedCount != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                        child: Text(_selectedCount!.status, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              if (_result != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isEnglish ? 'Results' : 'ผลการตรวจนับ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Divider(height: 24),
                      _summaryLine(isEnglish ? 'Bins' : 'จำนวน Bin', [
                        MapEntry(isEnglish ? 'Total' : 'ทั้งหมด', _fmtInt.format(_result!.totalBins)),
                        MapEntry(isEnglish ? 'Non-empty' : 'ไม่ว่าง', _fmtInt.format(_result!.nonEmptyBins)),
                        MapEntry(isEnglish ? 'Empty' : 'ว่าง', _fmtInt.format(_result!.emptyBins)),
                      ]),
                      _summaryLine(isEnglish ? 'Items' : 'จำนวน Item', [
                        MapEntry(isEnglish ? 'Total' : 'ทั้งหมด', _fmtInt.format(_result!.totalItems)),
                        MapEntry(isEnglish ? 'With stock' : 'มียอดสต็อค', _fmtInt.format(_result!.itemsWithStock)),
                        MapEntry(isEnglish ? 'No stock' : 'ไม่มีสต็อค', _fmtInt.format(_result!.itemsWithoutStock)),
                      ]),
                      _summaryLine(isEnglish ? 'Variance' : 'ผลต่าง', [
                        MapEntry(isEnglish ? 'Items with variance' : 'จำนวนที่มีผลต่าง', _fmtInt.format(_result!.itemsWithVariance)),
                        MapEntry(isEnglish ? 'Variance value' : 'มูลค่าผลต่าง', _fmtMoney.format(_result!.varianceValue)),
                      ]),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
