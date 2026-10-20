// lib/im/screens/im_stock_count_summary_screen.dart — ขั้นตอนที่ 6: สรุปผลการตรวจนับ
// รูปแบบคล้ายการปิดสิ้นปี AR/AP: เลือกเอกสาร -> ตรวจผล (read-only) -> ส่งขออนุมัติ (คิวผู้อนุมัติของเมนู) ->
// อนุมัติตามคิว (แผงขั้นตอนการอนุมัติ) -> บันทึกปรับยอด (หลังอนุมัติ)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/im_stock_count.dart';
import '../services/im_stock_count_service.dart';
import '../widgets/im_stock_count_picker_field.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';

class ImStockCountSummaryScreen extends StatefulWidget {
  // เปิดใบตรวจนับนี้ทันที (เช่น จากกระดิ่งรายการรออนุมัติ)
  final int? initialCountId;
  const ImStockCountSummaryScreen({super.key, this.initialCountId});

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
  ImStockCount? _selectedFull; // รวมเหตุที่ถอยไม่ได้ (ล็อกปุ่ม)
  ImStockCountCheckResult? _result;

  @override
  void initState() {
    super.initState();
    final id = widget.initialCountId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final full = await _service.fetchRow(id);
          if (mounted) setState(() { _selectedCount = full.header; _selectedFull = full; });
        } catch (_) {}
      });
    }
  }

  Future<void> _selectCount(ImStockCountHeader h) async {
    setState(() { _selectedCount = h; _selectedFull = null; _result = null; });
    try {
      final full = await _service.fetchRow(h.id);
      if (mounted && _selectedCount?.id == h.id) setState(() => _selectedFull = full);
    } catch (_) {
      // เงียบไว้ — ปุ่มถอยยังเรียก backend ซึ่งตรวจซ้ำอยู่แล้ว
    }
  }

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
      final full = await _service.fetchRow(_selectedCount!.id);
      if (mounted) setState(() { _selectedCount = full.header; _selectedFull = full; });
    } catch (_) {
      // เงียบไว้ — ไม่ใช่ operation หลัก
    }
  }

  // ส่งขออนุมัติผลการตรวจนับ — เข้าคิวผู้อนุมัติของเมนู (ไม่มีผู้อนุมัติ: ตามตัวเลือกของเมนู ให้ผ่าน/ไม่ให้ผ่าน)
  Future<void> _submit() async {
    final isEnglish = _isEnglish;
    final menuId = MenuScope.of(context)?.id;
    if (_selectedCount == null || menuId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Submit Count Results for Approval' : 'ส่งขออนุมัติผลการตรวจนับ'),
        content: Text(isEnglish
            ? 'Submit the results shown above for approval? Counts cannot be changed while waiting.'
            : 'ส่งขออนุมัติผลการตรวจนับตามที่แสดงด้านบน? ระหว่างรออนุมัติจะแก้ยอดนับไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Submit' : 'ส่งขออนุมัติ')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.submitCount(_selectedCount!.id, menuId: menuId);
      await _refreshSelectedCount();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Submitted for approval' : 'ส่งขออนุมัติสำเร็จ')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
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

  Future<void> _reverseToPosted() async {
    final isEnglish = _isEnglish;
    if (_selectedCount == null) return;
    final isClosed = _selectedCount!.status == 'Closed';
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: isEnglish ? 'Reverse to Posted' : 'ถอยกลับเป็น Posted',
        message: isEnglish
            ? (isClosed
                ? 'The stock adjustment (AJS) is removed and its stock and journal entry are reversed. You can then correct counts and approve again; the same adjustment number is reused.'
                : 'The approval will be undone and you will be able to re-approve it.')
            : (isClosed
                ? 'ใบปรับยอด (AJS) จะถูกลบ พร้อมย้อนสต็อกและรายการบัญชี แล้วจะแก้ยอดตรวจนับและอนุมัติใหม่ได้ เมื่อบันทึกปรับยอดใหม่จะใช้เลขที่ใบปรับยอดเดิม'
                : 'การอนุมัติจะถูกยกเลิก แล้วจะสามารถอนุมัติใหม่ได้'),
        confirmLabel: isEnglish ? 'Reverse' : 'ยืนยันถอยกลับ',
        confirmColor: Colors.orange[800]!);
    if (reason == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.reverseCount(_selectedCount!.id, reason);
      await _refreshSelectedCount();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Reversed to Posted' : 'ถอยกลับเป็น Posted สำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Reverse failed: $e' : 'ถอยกลับล้มเหลว: $e')));
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
    final isSubmitted = _selectedCount?.status == 'Submitted';
    final isClosed = _selectedCount?.status == 'Closed';

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
                              onPressed: () => ImStockCountPickerField.search(context, includeClosed: true, onSelected: _selectCount),
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
                      if (isPosted)
                        ElevatedButton.icon(
                          onPressed: (_result == null || _isSaving) ? null : _submit,
                          icon: const Icon(Icons.send, size: 18),
                          label: Text(isEnglish ? 'Submit for Approval' : 'ส่งขออนุมัติ'),
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
                      // ถอนคำขอ (Submitted) ทำได้ทุกคน ส่วนถอยใบที่อนุมัติ/ปิดแล้วต้องมีสิทธิ์อนุมัติ
                      if (isSubmitted || canApprove && (isApproved || isClosed)) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (_) {
                          final block = _selectedFull?.reverseBlock;
                          final button = OutlinedButton.icon(
                            onPressed: (_isSaving || block != null) ? null : _reverseToPosted,
                            icon: const Icon(Icons.undo, size: 18),
                            label: Text(isEnglish ? 'Reverse to Posted' : 'ถอยกลับเป็น Posted'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
                          );
                          return block == null ? button : Tooltip(message: block.text(isEnglish), child: button);
                        }),
                      ],
                    ]),
                    if (_selectedCount != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                        child: Text(imStockCountStatusLabel(_selectedCount!.status, isEnglish), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if ((_selectedFull?.approvals ?? const []).isNotEmpty)
                      DocApprovalPanel(
                        docNo: _selectedCount?.countNo ?? '',
                        approvals: _selectedFull!.approvals,
                        approvalMode: _selectedFull!.approvalMode,
                        awaiting: isSubmitted,
                        // อนุมัติครบ = Approved (บันทึกปรับยอดได้) / ไม่อนุมัติ = กลับเป็น Posted แก้ยอดนับได้
                        onApprove: (r) => _service.approveCount(_selectedCount!.id, remarks: r),
                        onReject: (r) => _service.rejectCount(_selectedCount!.id, remarks: r),
                        onDone: _refreshSelectedCount,
                      ),
                    if ((_selectedFull?.reverseHistory ?? const []).isNotEmpty)
                      DocReverseHistoryPanel(
                        history: _selectedFull!.reverseHistory,
                        isDeleted: false,
                        isEnglish: isEnglish,
                        margin: const EdgeInsets.only(top: 12),
                      ),
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
