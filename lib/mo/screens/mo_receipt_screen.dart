// lib/mo/screens/mo_receipt_screen.dart — รับสินค้าเข้าคลังจากการผลิต (Manufacturing Receipt, sys_doc_type='95')
// หน้าจอสำหรับฝ่ายผลิต (Production): เลือกใบสั่งผลิตที่ Released/InProgress แล้วรับผลผลิตตามจำนวนจริง ไม่มีช่อง
// ต้นทุนให้กรอกเลย — server คำนวณต้นทุนต่อหน่วยให้อัตโนมัติจากวัตถุดิบที่เบิกจริง+ต้นทุนแปรรูปของ MO เอง (ดู
// computeMoReceiptUnitCost/createMoReceipt ใน imTransactionController.js/moHeaderController.js) กดยืนยันครั้งเดียว
// Post ผ่าน POST /im_transaction/mo_receipt ทันที — มิเรอร์ mo_issue_screen.dart ทุกประการฝั่งโครงสร้าง UI
//
// MO แบบ BACKFLUSH (issue_method='BACKFLUSH'): หน้าจอนี้เป็นธุรกรรมเดียวที่ต้องทำ — การเบิกวัตถุดิบคำนวณ/ตัดสต็อก
// อัตโนมัติไปพร้อมกันตอนรับเข้าผลิต (ยังไม่ทำในเฟสนี้ — ตอนนี้รองรับเฉพาะ MO แบบ EXPLICIT ที่เบิกผ่าน
// mo_issue_screen.dart แยกไว้ก่อนแล้วเท่านั้น ดูแผนออกแบบโมดูล MO)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../im/services/im_transaction_service.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoReceiptScreen extends StatefulWidget {
  const MoReceiptScreen({super.key});

  @override
  State<MoReceiptScreen> createState() => _MoReceiptScreenState();
}

class _OutputLine {
  final MoOutputDetail detail;
  final TextEditingController qtyCtrl;
  _OutputLine(this.detail) : qtyCtrl = TextEditingController(text: _fmt(detail.qtyRemaining));
  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  double get qtyToReceive => double.tryParse(qtyCtrl.text) ?? 0;
}

class _MoReceiptScreenState extends State<MoReceiptScreen> {
  final _moService = MoHeaderService();
  final _imService = ImTransactionService();
  final _fmtQty = NumberFormat('#,##0.####');
  bool _isEnglish = false;
  bool _isLoadingMo = false;
  bool _isSubmitting = false;

  MoHeader? _mo;
  List<_OutputLine> _lines = [];
  int? _morDocId;

  @override
  void dispose() {
    for (final l in _lines) {
      l.qtyCtrl.dispose();
    }
    super.dispose();
  }

  Future<int?> _resolveMorDocId() async {
    if (_morDocId != null) return _morDocId;
    final docTypes = await _imService.fetchDocTypesByUser();
    final matches = docTypes.where((d) => d.isDocType && d.sysDocType == '95').toList();
    if (matches.isEmpty) return null;
    _morDocId = matches.first.id;
    return _morDocId;
  }

  Future<void> _pickMo() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoadingMo = true);
    List<MoHeader> rows = [];
    try {
      final released = await _moService.fetchRows(status: 'Released');
      final inProgress = await _moService.fetchRows(status: 'InProgress');
      rows = [...released, ...inProgress];
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingMo = false);
    }
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    final picked = await showDialog<MoHeader>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final q = searchCtrl.text.trim().toUpperCase();
        final filtered = q.isEmpty ? rows : rows.where((r) => r.docNo.toUpperCase().contains(q) || (r.bomParentItemCode ?? '').toUpperCase().contains(q)).toList();
        return AlertDialog(
          title: Text(isEnglish ? 'Select Manufacturing Order' : 'เลือกใบสั่งผลิต'),
          content: SizedBox(
            width: 480,
            height: 480,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search (MO No. / Item)' : 'ค้นหา (เลขที่ / สินค้า)',
                  prefixIcon: const Icon(Icons.search), isDense: true, border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setDlg(() {}),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(isEnglish ? 'No open MOs found' : 'ไม่พบใบสั่งผลิตที่เปิดอยู่'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final m = filtered[i];
                          return ListTile(
                            dense: true,
                            title: Text('${m.docNo}  ${m.bomParentItemCode ?? ''}'),
                            subtitle: Text(isEnglish
                                ? '${moHeaderStatusLabel(m.status, isEnglish)} · Order Qty ${m.orderQty}'
                                : '${moHeaderStatusLabel(m.status, isEnglish)} · สั่งผลิต ${m.orderQty}'),
                            onTap: () => Navigator.of(ctx).pop(m),
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด'))],
        );
      }),
    );
    if (picked != null) await _loadMo(picked.id);
  }

  Future<void> _loadMo(int id) async {
    final isEnglish = _isEnglish;
    setState(() => _isLoadingMo = true);
    try {
      final full = await _moService.fetchRow(id);
      for (final l in _lines) {
        l.qtyCtrl.dispose();
      }
      setState(() {
        _mo = full;
        _lines = full.outputs.where((o) => o.qtyRemaining > 0.0001).map((o) => _OutputLine(o)).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingMo = false);
    }
  }

  Future<void> _submit() async {
    final isEnglish = _isEnglish;
    final mo = _mo;
    if (mo == null) return;
    if (mo.costingMethod != 'ACTUAL') {
      _warn(isEnglish
          ? 'This MO uses ${mo.costingMethod} costing, which Manufacturing Receipt does not support yet — only ACTUAL costing is supported in this version'
          : 'ใบสั่งผลิตนี้ใช้วิธีตีมูลค่าแบบ ${mo.costingMethod} ซึ่งหน้าจอรับสินค้าเข้าคลังยังไม่รองรับ — รองรับเฉพาะ ACTUAL ในเวอร์ชันนี้');
      return;
    }
    final docId = await _resolveMorDocId();
    if (docId == null) {
      _warn(isEnglish
          ? 'No document type configured for Manufacturing Receipt (sys_doc_type 95) — ask an admin to set one up in SA > Document Types'
          : 'ยังไม่มีประเภทเอกสารสำหรับรับสินค้าเข้าคลังจากการผลิต (sys_doc_type 95) — ให้ผู้ดูแลระบบตั้งค่าที่ SA > ประเภทเอกสาร');
      return;
    }
    final toReceive = _lines.where((l) => l.qtyToReceive > 0.0001).toList();
    if (toReceive.isEmpty) {
      _warn(isEnglish ? 'Please enter a qty to receive for at least one output' : 'กรุณาระบุจำนวนที่จะรับอย่างน้อย 1 รายการ');
      return;
    }
    for (final l in toReceive) {
      if (l.qtyToReceive > l.detail.qtyRemaining + 0.0001) {
        _warn(isEnglish
            ? 'Qty to receive for ${l.detail.itemCode} exceeds the remaining planned qty (${l.detail.qtyRemaining})'
            : 'จำนวนที่จะรับของ ${l.detail.itemCode} เกินกว่าที่วางแผนไว้ (คงเหลือ ${l.detail.qtyRemaining})');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await _imService.createMoReceipt(
        moId: mo.id, docId: docId, docDate: DateTime.now(),
        lines: toReceive.map((l) => (refMoOutputDetailId: l.detail.id!, qty: l.qtyToReceive)).toList(),
        description: isEnglish ? 'Receipt for MO ${mo.docNo}' : 'รับสินค้าเข้าคลังจากการผลิต สำหรับ MO ${mo.docNo}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Received successfully' : 'รับสินค้าเข้าคลังสำเร็จ'), backgroundColor: Colors.green));
        await _loadMo(mo.id);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final mo = _mo;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoadingMo
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            mo == null
                                ? (isEnglish ? 'No MO selected' : 'ยังไม่ได้เลือกใบสั่งผลิต')
                                : '${mo.docNo}   ${mo.bomParentItemCode ?? ''} ${mo.bomParentItemNameTh ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickMo,
                          icon: const Icon(Icons.search, size: 18),
                          label: Text(isEnglish ? 'Select MO' : 'เลือกใบสั่งผลิต'),
                        ),
                      ]),
                      if (mo != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          isEnglish
                              ? 'Order Qty ${_fmtQty.format(mo.orderQty)} ${mo.uomCode ?? ''} · Warehouse ${mo.warehouseCode ?? ''} · ${moHeaderStatusLabel(mo.status, isEnglish)}'
                              : 'จำนวนสั่งผลิต ${_fmtQty.format(mo.orderQty)} ${mo.uomCode ?? ''} · คลัง ${mo.warehouseCode ?? ''} · ${moHeaderStatusLabel(mo.status, isEnglish)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                        if (mo.costingMethod != 'ACTUAL')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                isEnglish
                                    ? '${mo.costingMethod} costing is not supported yet for Manufacturing Receipt'
                                    : 'ยังไม่รองรับการตีมูลค่าแบบ ${mo.costingMethod} สำหรับหน้าจอนี้',
                                style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                              ),
                            ),
                          ),
                      ],
                    ]),
                  ),
                ),
                if (mo != null && mo.costingMethod == 'ACTUAL') ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isEnglish ? 'Outputs to Receive' : 'ผลผลิตที่จะรับ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          isEnglish
                              ? 'Unit cost is calculated automatically from actual material + conversion cost — no price entry needed'
                              : 'ต้นทุนต่อหน่วยคำนวณให้อัตโนมัติจากวัตถุดิบ+ต้นทุนแปรรูปที่เกิดขึ้นจริง ไม่ต้องกรอกราคาเอง',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const Divider(),
                        if (_lines.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(isEnglish ? 'All outputs fully received' : 'รับผลผลิตครบทุกรายการแล้ว', style: TextStyle(color: Colors.grey.shade600)),
                          )
                        else
                          ..._lines.map((l) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  if (l.detail.isPrimaryOutput)
                                    const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.star, size: 16, color: Colors.amber)),
                                  Expanded(
                                    flex: 3,
                                    child: Text('${l.detail.itemCode}  ${l.detail.itemName ?? ''}', style: const TextStyle(fontSize: 14)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      isEnglish
                                          ? 'Remaining: ${_fmtQty.format(l.detail.qtyRemaining)} ${l.detail.uomCode ?? ''}'
                                          : 'คงเหลือ: ${_fmtQty.format(l.detail.qtyRemaining)} ${l.detail.uomCode ?? ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: l.qtyCtrl,
                                      textAlign: TextAlign.right,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                      decoration: InputDecoration(
                                        labelText: isEnglish ? 'Qty to receive' : 'จำนวนที่รับ',
                                        isDense: true, border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ]),
                              )),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: (_isSubmitting || _lines.isEmpty || !canCreate) ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isSubmitting ? (isEnglish ? 'Receiving...' : 'กำลังรับ...') : (isEnglish ? 'Confirm Receipt' : 'ยืนยันรับสินค้าเข้าคลัง')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }
}
