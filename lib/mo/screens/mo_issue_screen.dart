// lib/mo/screens/mo_issue_screen.dart — เบิกวัตถุดิบเข้าผลิต (Manufacturing Issue, sys_doc_type='90') หน้าจอ
// สำหรับฝ่ายผลิต (Production): เลือกใบสั่งผลิตที่ Released/InProgress แล้วเบิกวัตถุดิบตามจำนวนจริง ไม่มีแนวคิด
// Draft/แก้ไขทีหลัง — กดยืนยันครั้งเดียว Post ผ่าน POST /im_transaction (action='Post' ค่า default) ทันที ซึ่ง
// imTransactionController.js:postDetailLines จะตรวจคงเหลือ+ตัดสต็อก+โพสต์ GL (Dr WIP / Cr บัญชีสต็อกของสินค้านั้น)
// ให้เองทั้งหมด (ดู validateMoComponentIssueQty/refreshMoStatus ใน moHeaderController.js) เฉพาะ MO ที่ issue_method
// ='EXPLICIT' เท่านั้น — MO แบบ BACKFLUSH ไม่ต้องเบิกแยก (คำนวณอัตโนมัติตอนรับเข้าผลิตแทน)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../im/models/im_transaction.dart';
import '../../im/services/im_transaction_service.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoIssueScreen extends StatefulWidget {
  const MoIssueScreen({super.key});

  @override
  State<MoIssueScreen> createState() => _MoIssueScreenState();
}

class _ComponentLine {
  final MoComponentDetail detail;
  final TextEditingController qtyCtrl;
  _ComponentLine(this.detail) : qtyCtrl = TextEditingController(text: _fmt(detail.qtyRemaining));
  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  double get qtyToIssue => double.tryParse(qtyCtrl.text) ?? 0;
}

String _uomName(String? code, String? nameTh, String? nameEn, bool isEnglish) {
  if (isEnglish && (nameEn ?? '').isNotEmpty) return nameEn!;
  if ((nameTh ?? '').isNotEmpty) return nameTh!;
  return code ?? '';
}

class _MoIssueScreenState extends State<MoIssueScreen> {
  final _moService = MoHeaderService();
  final _imService = ImTransactionService();
  final _fmtQty = NumberFormat('#,##0.####');
  bool _isEnglish = false;
  bool _isLoadingMo = false;
  bool _isSubmitting = false;

  MoHeader? _mo;
  List<_ComponentLine> _lines = [];
  int? _moiDocId;

  @override
  void dispose() {
    for (final l in _lines) {
      l.qtyCtrl.dispose();
    }
    super.dispose();
  }

  Future<int?> _resolveMoiDocId() async {
    if (_moiDocId != null) return _moiDocId;
    final docTypes = await _imService.fetchDocTypesByUser();
    final matches = docTypes.where((d) => d.isDocType && d.sysDocType == '90').toList();
    if (matches.isEmpty) return null;
    _moiDocId = matches.first.id;
    return _moiDocId;
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
        _lines = full.components.where((c) => c.qtyRemaining > 0.0001).map((c) => _ComponentLine(c)).toList();
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
    final docId = await _resolveMoiDocId();
    if (docId == null) {
      _warn(isEnglish
          ? 'No document type configured for Manufacturing Issue (sys_doc_type 90) — ask an admin to set one up in SA > Document Types'
          : 'ยังไม่มีประเภทเอกสารสำหรับเบิกวัตถุดิบเข้าผลิต (sys_doc_type 90) — ให้ผู้ดูแลระบบตั้งค่าที่ SA > ประเภทเอกสาร');
      return;
    }
    final toIssue = _lines.where((l) => l.qtyToIssue > 0.0001).toList();
    if (toIssue.isEmpty) {
      _warn(isEnglish ? 'Please enter a qty to issue for at least one component' : 'กรุณาระบุจำนวนที่จะเบิกอย่างน้อย 1 รายการ');
      return;
    }
    for (final l in toIssue) {
      if (l.qtyToIssue > l.detail.qtyRemaining + 0.0001) {
        _warn(isEnglish
            ? 'Qty to issue for ${l.detail.itemCode} exceeds the remaining planned qty (${l.detail.qtyRemaining})'
            : 'จำนวนที่จะเบิกของ ${l.detail.itemCode} เกินกว่าที่วางแผนไว้ (คงเหลือ ${l.detail.qtyRemaining})');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final details = <ImTransactionDetail>[];
      for (final l in toIssue) {
        final c = l.detail;
        final systemQty = await _imService.fetchSystemQty(
          itemId: c.componentItemId, warehouseId: mo.warehouseId, locationId: c.locationId,
        );
        details.add(ImTransactionDetail(
          itemId: c.componentItemId, itemCode: c.itemCode, itemName: c.itemName,
          locationId: c.locationId, uomId: c.uomId,
          systemQty: systemQty, countedQty: systemQty - l.qtyToIssue,
          refMoComponentDetailId: c.id, lineNo: 1,
        ));
      }
      final header = ImTransactionHeader(
        docId: docId, docNo: 'AUTO', docDate: DateTime.now(),
        warehouseId: mo.warehouseId, refMoId: mo.id,
        description: isEnglish ? 'Issue for MO ${mo.docNo}' : 'เบิกวัตถุดิบเข้าผลิต สำหรับ MO ${mo.docNo}',
      );
      await _imService.createTransaction(header: header, details: details, action: 'Post');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Issued successfully' : 'เบิกวัตถุดิบสำเร็จ'), backgroundColor: Colors.green));
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
        backgroundColor: Colors.deepOrange[700],
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
                              ? 'Order Qty ${_fmtQty.format(mo.orderQty)} ${_uomName(mo.uomCode, mo.uomNameTh, mo.uomNameEn, isEnglish)} · Warehouse ${mo.warehouseCode ?? ''} · ${moHeaderStatusLabel(mo.status, isEnglish)}'
                              : 'จำนวนสั่งผลิต ${_fmtQty.format(mo.orderQty)} ${_uomName(mo.uomCode, mo.uomNameTh, mo.uomNameEn, isEnglish)} · คลัง ${mo.warehouseCode ?? ''} · ${moHeaderStatusLabel(mo.status, isEnglish)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                        if (mo.issueMethod == 'BACKFLUSH')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                isEnglish
                                    ? 'This MO uses Backflush issuing — components are consumed automatically when receiving output, no separate issue needed.'
                                    : 'ใบสั่งผลิตนี้ใช้วิธีเบิกแบบอัตโนมัติตามสูตร (Backflush) — ระบบจะตัดวัตถุดิบให้อัตโนมัติตอนรับสินค้าเข้าผลิต ไม่ต้องเบิกแยกที่นี่',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ]),
                  ),
                ),
                if (mo != null && mo.issueMethod == 'EXPLICIT') ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isEnglish ? 'Components to Issue' : 'วัตถุดิบที่จะเบิก', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        if (_lines.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(isEnglish ? 'All components fully issued' : 'เบิกวัตถุดิบครบทุกรายการแล้ว', style: TextStyle(color: Colors.grey.shade600)),
                          )
                        else
                          ..._lines.map((l) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text('${l.detail.itemCode}  ${l.detail.itemName ?? ''}', style: const TextStyle(fontSize: 14)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      isEnglish
                                          ? 'Remaining: ${_fmtQty.format(l.detail.qtyRemaining)} ${_uomName(l.detail.uomCode, l.detail.uomNameTh, l.detail.uomNameEn, isEnglish)}'
                                          : 'คงเหลือ: ${_fmtQty.format(l.detail.qtyRemaining)} ${_uomName(l.detail.uomCode, l.detail.uomNameTh, l.detail.uomNameEn, isEnglish)}',
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
                                        labelText: isEnglish ? 'Qty to issue' : 'จำนวนที่เบิก',
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
                      label: Text(_isSubmitting ? (isEnglish ? 'Issuing...' : 'กำลังเบิก...') : (isEnglish ? 'Confirm Issue' : 'ยืนยันเบิกวัตถุดิบ')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }
}
