import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../utils/date_utils.dart';
import '../models/im_transaction.dart' show ImDocBlock;
import '../services/im_consignment_settlement_service.dart';

// Consignment Settlement — แปลงยอดขายสินค้าฝากขาย (sys_doc_type='13') ที่ขายออกไปแล้วแต่ยังไม่ตั้งหนี้ ให้เป็นใบ
// ตั้งหนี้ AP จริงก้อนเดียวต่อผู้ฝากขาย (Dr เจ้าหนี้ฝากขาย / Cr เจ้าหนี้การค้า) — ดู
// imConsignmentSettlementController.js สำหรับรายละเอียด backend และ verify ที่ทำไว้ก่อนเขียนหน้าจอนี้
// เลือกผู้ฝากขายก่อนเสมอ (การ Settlement หนึ่งครั้งทำได้ทีละผู้ฝากขายเดียวเท่านั้น) ค่าเริ่มต้นติ๊กเลือกทุกแถว
// แท็บประวัติ: ถอยเป็นร่าง (งวดเปิด + ยังไม่จ่าย/จับคู่) → โพสต์ใหม่ด้วยเลขที่เดิม หรือลบ (คืนรายการไปรอตั้งหนี้)
// ยกเลิกใช้เมื่อถอยไม่ได้ (รายการบัญชีกลับวันนี้) ทุกการกระทำต้องมีเหตุผล — กดแถวเพื่อดูประวัติ

class ImConsignmentSettlementScreen extends StatefulWidget {
  const ImConsignmentSettlementScreen({super.key});

  @override
  State<ImConsignmentSettlementScreen> createState() => _ImConsignmentSettlementScreenState();
}

class _ImConsignmentSettlementScreenState extends State<ImConsignmentSettlementScreen> with SingleTickerProviderStateMixin {
  final _svc = ImConsignmentSettlementService();
  final _refNoCtrl = TextEditingController();
  late final TabController _tabController;

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isSubmitting = false;

  int? _vendorId;
  String _vendorLabel = '';
  DateTime _docDate = DateTime.now();
  // ประเภทเอกสาร AP ตั้งหนี้ — ผู้ใช้ต้องเลือกทุกครั้งเพื่อยืนยัน (ล้างค่าหลังสร้างใบตั้งหนี้สำเร็จ)
  List<Map<String, dynamic>> _apDocTypes = [];
  int? _apDocId;
  List<Map<String, dynamic>> _rows = [];
  final Set<int> _selected = {};

  bool _isLoadingSettled = false;
  List<Map<String, dynamic>> _settled = [];
  int? _busyId;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApDocTypes();
  }

  Future<void> _loadApDocTypes() async {
    try {
      final rows = await _svc.fetchApDocTypes();
      if (mounted) setState(() => _apDocTypes = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _refNoCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  static num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
  num _amount(Map<String, dynamic> r) => _num(r['qty']) * _num(r['unit_cost']);
  num get _selectedTotal => _rows.where((r) => _selected.contains(r['consumption_id'] as int)).fold<num>(0, (s, r) => s + _amount(r));

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy').format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  String _itemLabel(Map<String, dynamic> r, bool isEnglish) {
    final en = r['item_name_en'] as String?;
    final name = isEnglish && (en ?? '').isNotEmpty ? en! : (r['item_name_th'] as String? ?? '');
    return '${r['item_code'] ?? ''}  $name';
  }

  Future<void> _pickVendor() async {
    await ApVendorListWidget.search(context, onSelected: (ApVendor v) {
      setState(() {
        _vendorId = v.id;
        _vendorLabel = '${v.vendorCode}  ${v.vendorNameTh}';
        _rows = [];
        _selected.clear();
        _settled = [];
      });
      _loadPending();
      _loadSettled();
    });
  }

  Future<void> _loadSettled() async {
    if (_vendorId == null) return;
    setState(() => _isLoadingSettled = true);
    try {
      final rows = await _svc.fetchSettled(vendorId: _vendorId!);
      if (mounted) setState(() => _settled = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingSettled = false);
    }
  }

  static const Map<String, List<String>> _statusLabels = {
    'Posted':  ['โพสต์แล้ว', 'Posted'],
    'Draft':   ['ร่าง', 'Draft'],
    'Void':    ['ยกเลิก', 'Void'],
    'Deleted': ['ลบแล้ว', 'Deleted'],
  };
  String _statusLabel(String s, bool isEnglish) => _statusLabels[s]?[isEnglish ? 1 : 0] ?? s;

  Color _statusColor(String s) {
    switch (s) {
      case 'Posted': return Colors.green.shade100;
      case 'Draft':  return Colors.orange.shade100;
      default:       return Colors.grey.shade300;
    }
  }

  // ทำรายการกับใบตั้งหนี้ แล้วโหลดประวัติและรายการรอตั้งหนี้ใหม่
  Future<void> _runRowAction(int id, Future<void> Function() action, String doneMsg) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(doneMsg)));
      }
      await _loadSettled();
      await _loadPending();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reverseSettlement(Map<String, dynamic> row) async {
    final isEnglish = _isEnglish;
    final docNo = row['doc_no'] as String? ?? '';
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Reverse to Draft' : 'ถอยใบตั้งหนี้เป็นร่าง',
      message: isEnglish
          ? 'Reverse AP bill $docNo to draft? Its GL entry will be removed. The consignment sale lines stay with this draft — post it again with the same number, or delete it to return the lines to Pending.'
          : 'ถอยใบตั้งหนี้ $docNo เป็นร่าง? รายการบัญชีจะถูกลบ รายการขายฝากขายยังผูกกับร่างนี้ โพสต์ใหม่ได้ด้วยเลขที่เดิม หรือลบร่างเพื่อคืนรายการกลับไปรอตั้งหนี้',
      confirmLabel: isEnglish ? 'Reverse' : 'ถอยเป็นร่าง',
      confirmColor: Colors.orange.shade800,
    );
    if (reason == null) return;
    await _runRowAction(row['id'] as int, () => _svc.reverseSettlement(row['id'] as int, reason),
        isEnglish ? 'Reversed to draft' : 'ถอยเป็นร่างสำเร็จ');
  }

  Future<void> _voidSettlement(Map<String, dynamic> row) async {
    final isEnglish = _isEnglish;
    final docNo = row['doc_no'] as String? ?? '';
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Void Settlement' : 'ยกเลิกใบตั้งหนี้ฝากขาย',
      message: isEnglish
          ? 'Void AP bill $docNo? A reversing GL entry will be posted today and the consignment sale lines it settled will return to Pending so they can be re-settled.'
          : 'ยกเลิกใบตั้งหนี้ $docNo? ระบบจะลงรายการบัญชีกลับในวันนี้ และรายการขายสินค้าฝากขายที่ตั้งหนี้ไว้จะกลับไปอยู่ในแท็บ "รอตั้งหนี้" เพื่อตั้งหนี้ใหม่ได้',
      confirmLabel: isEnglish ? 'Void' : 'ยืนยันยกเลิก',
      confirmColor: Colors.red.shade700,
    );
    if (reason == null) return;
    await _runRowAction(row['id'] as int, () => _svc.voidSettlement(row['id'] as int, reason),
        isEnglish ? 'Settlement voided' : 'ยกเลิกใบตั้งหนี้สำเร็จ');
  }

  Future<void> _deleteSettlement(Map<String, dynamic> row) async {
    final isEnglish = _isEnglish;
    final docNo = row['doc_no'] as String? ?? '';
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Delete Draft' : 'ลบร่างใบตั้งหนี้',
      message: isEnglish
          ? 'Delete draft $docNo? It will be kept as Deleted for audit (the number cannot be reused) and its consignment sale lines will return to Pending.'
          : 'ลบร่าง $docNo? ระบบเก็บไว้ด้วยสถานะ "ลบแล้ว" เพื่อตรวจสอบ (นำเลขที่กลับมาใช้ไม่ได้) และคืนรายการขายฝากขายกลับไปรอตั้งหนี้',
      confirmLabel: isEnglish ? 'Delete' : 'ลบ',
    );
    if (reason == null) return;
    await _runRowAction(row['id'] as int, () => _svc.deleteSettlement(row['id'] as int, reason),
        isEnglish ? 'Draft deleted' : 'ลบร่างสำเร็จ');
  }

  // โพสต์ร่างใหม่ด้วยเลขที่เดิม: เลือกวันที่ (ค่าเริ่มต้น = วันที่เดิม) และเลขที่อ้างอิง
  Future<void> _repostSettlement(Map<String, dynamic> row) async {
    final isEnglish = _isEnglish;
    final docNo = row['doc_no'] as String? ?? '';
    var date = parseLocalDateNullable(row['doc_date']) ?? DateTime.now();
    final refCtrl = TextEditingController(text: row['ref_no'] as String? ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEnglish ? 'Post $docNo' : 'โพสต์ใบตั้งหนี้ $docNo'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setD(() => date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'AP Bill Date' : 'วันที่ใบตั้งหนี้',
                      border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                  child: Text(DateFormat('dd/MM/yyyy').format(date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Reference No. (optional)' : 'เลขที่อ้างอิง (ถ้ามี)',
                    border: const OutlineInputBorder(), isDense: true),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
              child: Text(isEnglish ? 'Post' : 'โพสต์'),
            ),
          ],
        ),
      ),
    );
    final refNo = refCtrl.text.trim();
    refCtrl.dispose();
    if (confirmed != true) return;
    await _runRowAction(row['id'] as int,
        () => _svc.repostSettlement(row['id'] as int, docDate: formatLocalDate(date), refNo: refNo.isEmpty ? null : refNo),
        isEnglish ? 'Posted' : 'โพสต์สำเร็จ');
  }

  // ปุ่มที่ทำไม่ได้: ล็อกและแสดงเหตุผลเมื่อชี้เมาส์
  Widget _rowAction(Map<String, dynamic> r, String key, bool canApprove,
      {required IconData icon, required String label, required Color color, required Future<void> Function(Map<String, dynamic>) onTap}) {
    final block = ImDocBlock.fromJson(r[key]);
    final id = r['id'] as int;
    final enabled = canApprove && block == null && _busyId == null;
    final button = TextButton.icon(
      onPressed: enabled ? () => onTap(r) : null,
      icon: _busyId == id ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 6)),
    );
    return block == null ? button : Tooltip(message: block.text(_isEnglish), child: button);
  }

  Future<void> _loadPending() async {
    if (_vendorId == null) return;
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _svc.fetchPending(vendorId: _vendorId);
      setState(() {
        _rows = rows;
        _selected
          ..clear()
          ..addAll(rows.map((r) => r['consumption_id'] as int));
      });
      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
            ? 'No pending consignment sales for this vendor'
            : 'ไม่มีรายการขายสินค้าฝากขายที่รอตั้งหนี้สำหรับผู้ฝากขายรายนี้')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _settle() async {
    final isEnglish = _isEnglish;
    if (_vendorId == null || _selected.isEmpty || _apDocId == null) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await _svc.postSettlement(
        vendorId: _vendorId!,
        apDocId: _apDocId!,
        consumptionIds: _selected.toList(),
        refNo: _refNoCtrl.text.trim(),
        docDate: DateFormat('yyyy-MM-dd').format(_docDate),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.green,
            content: Text(isEnglish
                ? 'AP bill ${result['ap_doc_no']} created (${result['line_count']} line(s), total ${NumberFormat('#,##0.00').format(_num(result['total_amount']))})'
                : 'สร้างใบตั้งหนี้ ${result['ap_doc_no']} สำเร็จ (${result['line_count']} รายการ ยอดรวม ${NumberFormat('#,##0.00').format(_num(result['total_amount']))})')));
      }
      _refNoCtrl.clear();
      setState(() => _apDocId = null);
      await _loadPending();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPickerField({required String label, required String displayText, required VoidCallback onPick}) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(icon: Icon(Icons.search, color: Colors.teal[700]), onPressed: onPick),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (_isEnglish ? '— Select consignor vendor —' : '— เลือกผู้ฝากขาย —'),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPendingTab(bool isEnglish, NumberFormat fmt, NumberFormat fmtQty) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_vendorId == null) {
      return Center(
          child: Text(isEnglish ? 'Please select a consignor vendor' : 'กรุณาเลือกผู้ฝากขาย',
              style: const TextStyle(color: Colors.grey)));
    }
    if (_rows.isEmpty) {
      return Center(
          child: Text(isEnglish ? 'No pending consignment sales' : 'ไม่มีรายการขายสินค้าฝากขายที่รอตั้งหนี้',
              style: const TextStyle(color: Colors.grey)));
    }
    return Column(children: [
      Container(
        color: Colors.teal[50],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Checkbox(
            value: _selected.length == _rows.length,
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.addAll(_rows.map((r) => r['consumption_id'] as int));
              } else {
                _selected.clear();
              }
            }),
          ),
          Expanded(flex: 3, child: Text(isEnglish ? 'Item' : 'สินค้า', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text(isEnglish ? 'Lot/Serial' : 'ล็อต/ซีเรียล', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text(isEnglish ? 'Sale Doc' : 'เลขที่เอกสารขาย', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text(isEnglish ? 'Receipt Doc' : 'เลขที่เอกสารรับ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text(isEnglish ? 'Qty' : 'จำนวน', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text(isEnglish ? 'Unit Cost' : 'ต้นทุน/หน่วย', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text(isEnglish ? 'Amount' : 'จำนวนเงิน', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final r = _rows[i];
            final id = r['consumption_id'] as int;
            final lotSerial = (r['serial_no'] as String?)?.isNotEmpty == true ? r['serial_no'] : (r['lot_no'] as String?) ?? '';
            return Container(
              color: i.isOdd ? Colors.grey.shade50 : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Checkbox(
                  value: _selected.contains(id),
                  onChanged: (v) => setState(() {
                    if (v == true) { _selected.add(id); } else { _selected.remove(id); }
                  }),
                ),
                Expanded(flex: 3, child: Text(_itemLabel(r, isEnglish), style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(lotSerial ?? '', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(
                    '${r['sale_doc_no'] ?? ''}\n${_fmtDate(r['sale_doc_date'] as String?)}',
                    style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(r['receipt_doc_no'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 1, child: Text(fmtQty.format(_num(r['qty'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                Expanded(flex: 1, child: Text(fmt.format(_num(r['unit_cost'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                Expanded(flex: 1, child: Text(fmt.format(_amount(r)), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              ]),
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(top: BorderSide(color: Colors.grey.shade300))),
        child: Row(children: [
          Expanded(
            child: Text(
              isEnglish
                  ? '${_selected.length} of ${_rows.length} line(s) selected — Total: ${fmt.format(_selectedTotal)}'
                  : 'เลือก ${_selected.length} จาก ${_rows.length} รายการ — ยอดรวม: ${fmt.format(_selectedTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          ElevatedButton.icon(
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.receipt_long),
            label: Text(isEnglish ? 'Create AP Bill' : 'สร้างใบตั้งหนี้'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            onPressed: (_isSubmitting || _selected.isEmpty || _apDocId == null) ? null : _settle,
          ),
        ]),
      ),
    ]);
  }

  Widget _buildHistoryTab(bool isEnglish, NumberFormat fmt, bool canApprove) {
    if (_isLoadingSettled) return const Center(child: CircularProgressIndicator());
    if (_vendorId == null) {
      return Center(
          child: Text(isEnglish ? 'Please select a consignor vendor' : 'กรุณาเลือกผู้ฝากขาย',
              style: const TextStyle(color: Colors.grey)));
    }
    if (_settled.isEmpty) {
      return Center(
          child: Text(isEnglish ? 'No settlement history for this vendor' : 'ยังไม่มีประวัติการตั้งหนี้ฝากขายสำหรับผู้ฝากขายรายนี้',
              style: const TextStyle(color: Colors.grey)));
    }
    return Column(children: [
      Container(
        color: Colors.teal[50],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(flex: 2, child: Text(isEnglish ? 'AP Bill No.' : 'เลขที่ใบตั้งหนี้', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text(isEnglish ? 'Reference' : 'เลขที่อ้างอิง', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text(isEnglish ? 'Amount' : 'จำนวนเงิน', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text(isEnglish ? 'Status' : 'สถานะ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 220),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: _settled.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final r = _settled[i];
            final status = r['status'] as String? ?? '';
            final id = r['id'] as int;
            final history = DocReverseLog.listFromJson(r['reverse_history']);
            final expanded = _expandedId == id;
            return InkWell(
              onTap: history.isEmpty ? null : () => setState(() => _expandedId = expanded ? null : id),
              child: Container(
              color: i.isOdd ? Colors.grey.shade50 : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(children: [
              Row(children: [
                Expanded(flex: 2, child: Row(children: [
                  Flexible(child: Text(r['doc_no'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                  if (history.isNotEmpty)
                    Icon(expanded ? Icons.expand_less : Icons.history, size: 16, color: Colors.grey.shade600),
                ])),
                Expanded(flex: 2, child: Text(_fmtDate(r['doc_date'] as String?), style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(r['ref_no'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 1, child: Text(fmt.format(_num(r['total_amount_lc'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_statusLabel(status, isEnglish), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (status == 'Posted') ...[
                      _rowAction(r, 'reverse_block', canApprove, icon: Icons.undo, label: isEnglish ? 'Reverse' : 'ถอยเป็นร่าง',
                          color: Colors.orange.shade800, onTap: _reverseSettlement),
                      _rowAction(r, 'void_block', canApprove, icon: Icons.block, label: isEnglish ? 'Void' : 'ยกเลิก',
                          color: Colors.red.shade700, onTap: _voidSettlement),
                    ],
                    if (status == 'Draft') ...[
                      _rowAction(r, 'post_block', canApprove, icon: Icons.check_circle_outline, label: isEnglish ? 'Post' : 'โพสต์',
                          color: Colors.teal.shade700, onTap: _repostSettlement),
                      _rowAction(r, 'delete_block', canApprove, icon: Icons.delete_outline, label: isEnglish ? 'Delete' : 'ลบ',
                          color: Colors.red.shade700, onTap: _deleteSettlement),
                    ],
                  ]),
                ),
              ]),
              if (expanded)
                DocReverseHistoryPanel(
                  history: history,
                  isDeleted: status == 'Deleted',
                  isEnglish: isEnglish,
                  margin: const EdgeInsets.only(top: 6),
                ),
              ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final canApprove = MenuScope.of(context)?.canApprove ?? false;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final fmtQty = NumberFormat('#,##0.####', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 2,
                child: _buildPickerField(
                  label: isEnglish ? 'Consignor (Vendor)' : 'ผู้ฝากขาย',
                  displayText: _vendorLabel,
                  onPick: _pickVendor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _docDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: isEnglish ? 'AP Bill Date' : 'วันที่ใบตั้งหนี้',
                        border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                    child: Text(DateFormat('dd/MM/yyyy').format(_docDate)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _apDocId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'AP Billing Document Type (required)' : 'ประเภทเอกสาร AP ตั้งหนี้ (ต้องเลือก)',
                    border: const OutlineInputBorder(), isDense: true,
                  ),
                  items: [
                    for (final d in _apDocTypes)
                      DropdownMenuItem<int>(
                        value: d['id'] as int,
                        child: Text(
                          '${d['doc_code']}  ${isEnglish && ((d['doc_name_eng'] as String?) ?? '').isNotEmpty ? d['doc_name_eng'] : (d['doc_name_thai'] ?? '')}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _apDocId = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _refNoCtrl,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Reference No. (optional)' : 'เลขที่อ้างอิง (ถ้ามี)',
                      border: const OutlineInputBorder(), isDense: true),
                ),
              ),
            ]),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Colors.teal[800],
          indicatorColor: Colors.teal[800],
          tabs: [
            Tab(text: isEnglish ? 'Pending' : 'รอตั้งหนี้'),
            Tab(text: isEnglish ? 'History' : 'ประวัติ'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(isEnglish, fmt, fmtQty),
              _buildHistoryTab(isEnglish, fmt, canApprove),
            ],
          ),
        ),
      ]),
    );
  }
}
