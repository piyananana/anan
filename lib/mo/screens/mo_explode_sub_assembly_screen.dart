// lib/mo/screens/mo_explode_sub_assembly_screen.dart — สร้างใบสั่งผลิตย่อย (Explode Sub-Assembly) หน้าจอสำหรับ
// ฝ่ายวางแผน (Planning): เลือกใบสั่งผลิตหลัก แล้วดูว่าส่วนประกอบใดเป็นสินค้าที่ผลิตเอง (มีสูตรการผลิต/BOM ของตัวเอง)
// จากนั้นเลือก opt-in ต่อรายการเพื่อสร้างใบสั่งผลิตย่อย (Draft) จำนวน = ส่วนที่ยังไม่ได้เบิก — ถ้า MO ย่อยที่สร้างขึ้น
// มีส่วนประกอบที่ผลิตเองอีกชั้น ก็เลือก MO ย่อยนั้นมาเปิดหน้าจอนี้ซ้ำได้ ไล่ลึกได้หลายชั้นเท่าที่ต้องการ ดู
// fetchExplosionCandidates/explodeSubAssembly ใน moHeaderController.js
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoExplodeSubAssemblyScreen extends StatefulWidget {
  const MoExplodeSubAssemblyScreen({super.key});

  @override
  State<MoExplodeSubAssemblyScreen> createState() => _MoExplodeSubAssemblyScreenState();
}

String _uomName(String? code, String? nameTh, String? nameEn, bool isEnglish) {
  if (isEnglish && (nameEn ?? '').isNotEmpty) return nameEn!;
  if ((nameTh ?? '').isNotEmpty) return nameTh!;
  return code ?? '';
}

class _MoExplodeSubAssemblyScreenState extends State<MoExplodeSubAssemblyScreen> {
  final _moService = MoHeaderService();
  final _fmtQty = NumberFormat('#,##0.####');
  bool _isEnglish = false;
  bool _isLoading = false;
  final Set<int> _submittingIds = {};

  MoHeader? _mo;
  List<MoExplosionCandidate> _candidates = [];

  Future<void> _pickMo() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    List<MoHeader> rows = [];
    try {
      final statuses = ['Draft', 'Released', 'InProgress'];
      for (final s in statuses) {
        rows.addAll(await _moService.fetchRows(status: s));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    if (picked != null) await _loadMo(picked);
  }

  Future<void> _loadMo(MoHeader mo) async {
    final isEnglish = _isEnglish;
    setState(() {
      _mo = mo;
      _isLoading = true;
    });
    try {
      final candidates = await _moService.fetchExplosionCandidates(mo.id);
      if (mounted) setState(() => _candidates = candidates);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _explode(MoExplosionCandidate c) async {
    final isEnglish = _isEnglish;
    final mo = _mo;
    if (mo == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Create Child MO?' : 'สร้างใบสั่งผลิตย่อย?'),
        content: Text(isEnglish
            ? 'Create a new Draft MO for ${c.itemCode} (${_fmtQty.format(c.remainingQty)} ${_uomName(c.uomCode, c.uomNameTh, c.uomNameEn, isEnglish)}), linked to this MO?'
            : 'สร้างใบสั่งผลิตย่อยสถานะ Draft สำหรับ ${c.itemCode} จำนวน ${_fmtQty.format(c.remainingQty)} ${_uomName(c.uomCode, c.uomNameTh, c.uomNameEn, isEnglish)} เชื่อมโยงกับใบสั่งผลิตนี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Create' : 'สร้าง')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submittingIds.add(c.componentDetailId));
    try {
      final child = await _moService.explodeSubAssembly(moId: mo.id, componentDetailId: c.componentDetailId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Created child MO ${child.docNo}' : 'สร้างใบสั่งผลิตย่อย ${child.docNo} สำเร็จ'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submittingIds.remove(c.componentDetailId));
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
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
                  ),
                ),
                if (mo != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isEnglish ? 'Components' : 'ส่วนประกอบ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        if (_candidates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(isEnglish ? 'No components on this MO' : 'ใบสั่งผลิตนี้ไม่มีส่วนประกอบ', style: TextStyle(color: Colors.grey.shade600)),
                          )
                        else
                          ..._candidates.map((c) => _buildCandidateRow(c, isEnglish, canCreate)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }

  Widget _buildCandidateRow(MoExplosionCandidate c, bool isEnglish, bool canCreate) {
    final isSubmitting = _submittingIds.contains(c.componentDetailId);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: c.canExplode ? Colors.deepOrange.shade100 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
        color: c.canExplode ? Colors.deepOrange.shade50.withOpacity(0.3) : null,
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c.itemCode ?? ''}  ${c.itemName ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              isEnglish
                  ? 'Remaining: ${_fmtQty.format(c.remainingQty)} ${_uomName(c.uomCode, c.uomNameTh, c.uomNameEn, isEnglish)}'
                  : 'คงเหลือที่ยังต้องเบิก: ${_fmtQty.format(c.remainingQty)} ${_uomName(c.uomCode, c.uomNameTh, c.uomNameEn, isEnglish)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ]),
        ),
        if (c.canExplode)
          ElevatedButton.icon(
            onPressed: (!canCreate || isSubmitting) ? null : () => _explode(c),
            icon: isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.call_split, size: 18),
            label: Text(isEnglish ? 'Create Child MO' : 'สร้างใบสั่งผลิตย่อย'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white),
          )
        else
          Text(isEnglish ? 'Stock item' : 'สินค้าซื้อ/สต็อก', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }
}
