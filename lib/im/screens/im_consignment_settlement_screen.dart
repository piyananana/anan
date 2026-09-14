import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../services/im_consignment_settlement_service.dart';

// Consignment Settlement — แปลงยอดขายสินค้าฝากขาย (sys_doc_type='13') ที่ขายออกไปแล้วแต่ยังไม่ตั้งหนี้ ให้เป็นใบ
// ตั้งหนี้ AP จริงก้อนเดียวต่อผู้ฝากขาย (Dr เจ้าหนี้ฝากขาย / Cr เจ้าหนี้การค้า) — ดู
// imConsignmentSettlementController.js สำหรับรายละเอียด backend และ verify ที่ทำไว้ก่อนเขียนหน้าจอนี้
// เลือกผู้ฝากขายก่อนเสมอ (การ Settlement หนึ่งครั้งทำได้ทีละผู้ฝากขายเดียวเท่านั้น) ค่าเริ่มต้นติ๊กเลือกทุกแถว

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
  List<Map<String, dynamic>> _rows = [];
  final Set<int> _selected = {};

  bool _isLoadingSettled = false;
  List<Map<String, dynamic>> _settled = [];
  int? _voidingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> _voidSettlement(Map<String, dynamic> row) async {
    final isEnglish = _isEnglish;
    final id = row['id'] as int;
    final docNo = row['doc_no'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Void Settlement' : 'ยกเลิกใบตั้งหนี้ฝากขาย'),
        content: Text(isEnglish
            ? 'Void AP bill $docNo? Its GL entry will be voided and the consignment sale lines it settled will return to Pending so they can be re-settled.'
            : 'ยกเลิกใบตั้งหนี้ $docNo? รายการบัญชีที่ผูกไว้จะถูกยกเลิก และรายการขายสินค้าฝากขายที่ตั้งหนี้ไปแล้วจะกลับไปอยู่ในแท็บ "รอตั้งหนี้" เพื่อตั้งหนี้ใหม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Void' : 'ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _voidingId = id);
    try {
      await _svc.voidSettlement(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text(isEnglish ? 'Settlement voided' : 'ยกเลิกใบตั้งหนี้สำเร็จ')));
      await _loadSettled();
      await _loadPending();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _voidingId = null);
    }
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
    if (_vendorId == null || _selected.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await _svc.postSettlement(
        vendorId: _vendorId!,
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
            onPressed: (_isSubmitting || _selected.isEmpty) ? null : _settle,
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
          const SizedBox(width: 90),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: _settled.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final r = _settled[i];
            final status = r['status'] as String? ?? '';
            final isVoid = status == 'Void';
            final id = r['id'] as int;
            return Container(
              color: i.isOdd ? Colors.grey.shade50 : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Expanded(flex: 2, child: Text(r['doc_no'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(_fmtDate(r['doc_date'] as String?), style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(r['ref_no'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 1, child: Text(fmt.format(_num(r['total_amount_lc'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVoid ? Colors.grey.shade300 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(status, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: (canApprove && !isVoid)
                      ? TextButton.icon(
                          onPressed: _voidingId == id ? null : () => _voidSettlement(r),
                          icon: _voidingId == id
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.undo, size: 16),
                          label: Text(isEnglish ? 'Void' : 'ยกเลิก', style: const TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
                        )
                      : null,
                ),
              ]),
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
