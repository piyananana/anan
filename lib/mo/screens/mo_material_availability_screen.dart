// lib/mo/screens/mo_material_availability_screen.dart — ตรวจสอบวัตถุดิบพร้อมผลิต (Material Availability Check)
// หน้าจอสำหรับฝ่ายวางแผน (Planning): เลือกใบสั่งผลิตที่ยังไม่ปิด/ยกเลิก แล้วเทียบจำนวนที่ยังต้องเบิกอีก (planned_qty
// - issued_qty ต่อบรรทัด) กับคงเหลือในคลังปลายทางของ MO นั้นตอนนี้ — read-only ล้วน ไม่มีการโพสต์ธุรกรรมใดๆเลย ดู
// checkMaterialAvailability ใน moHeaderController.js
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoMaterialAvailabilityScreen extends StatefulWidget {
  const MoMaterialAvailabilityScreen({super.key});

  @override
  State<MoMaterialAvailabilityScreen> createState() => _MoMaterialAvailabilityScreenState();
}

String _uomName(String? code, String? nameTh, String? nameEn, bool isEnglish) {
  if (isEnglish && (nameEn ?? '').isNotEmpty) return nameEn!;
  if ((nameTh ?? '').isNotEmpty) return nameTh!;
  return code ?? '';
}

class _MoMaterialAvailabilityScreenState extends State<MoMaterialAvailabilityScreen> {
  final _moService = MoHeaderService();
  final _fmtQty = NumberFormat('#,##0.####');
  bool _isEnglish = false;
  bool _isLoading = false;

  MoHeader? _mo;
  MoMaterialAvailability? _result;

  Future<void> _pickMo() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    List<MoHeader> rows = [];
    try {
      final statuses = ['Draft', 'Released', 'InProgress', 'Completed'];
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
                    ? Center(child: Text(isEnglish ? 'No open MOs found' : 'ไม่พบใบสั่งผลิตที่ยังไม่ปิด/ยกเลิก'))
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
    if (picked != null) await _check(picked);
  }

  Future<void> _check(MoHeader mo) async {
    final isEnglish = _isEnglish;
    setState(() {
      _mo = mo;
      _isLoading = true;
    });
    try {
      final result = await _moService.checkMaterialAvailability(mo.id);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final mo = _mo;
    final result = _result;

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
                if (result != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: result.hasShortage ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: result.hasShortage ? Colors.red.shade200 : Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Icon(result.hasShortage ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          color: result.hasShortage ? Colors.red.shade700 : Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        result.hasShortage
                            ? (isEnglish ? 'Some components are short of stock' : 'มีวัตถุดิบบางรายการไม่พอในคลัง')
                            : (isEnglish ? 'All components have enough stock' : 'วัตถุดิบมีพอทุกรายการ'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result.hasShortage ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isEnglish ? 'Components' : 'รายการวัตถุดิบ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(1.4),
                            2: FlexColumnWidth(1.4),
                            3: FlexColumnWidth(1.4),
                            4: FlexColumnWidth(1.4),
                          },
                          border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade100),
                              children: [
                                _headerCell(isEnglish ? 'Item' : 'สินค้า'),
                                _headerCell(isEnglish ? 'Remaining' : 'ที่ยังต้องเบิก', alignEnd: true),
                                _headerCell(isEnglish ? 'Available' : 'คงเหลือในคลัง', alignEnd: true),
                                _headerCell(isEnglish ? 'Shortage' : 'ขาด', alignEnd: true),
                                _headerCell(isEnglish ? 'Status' : 'สถานะ', alignEnd: true),
                              ],
                            ),
                            ...result.lines.map((l) {
                              final uom = _uomName(l.uomCode, l.uomNameTh, l.uomNameEn, isEnglish);
                              return TableRow(children: [
                                  _cell('${l.itemCode ?? ''}  ${l.itemName ?? ''}'),
                                  _cell('${_fmtQty.format(l.remainingQty)} $uom', alignEnd: true),
                                  _cell('${_fmtQty.format(l.availableQty)} $uom', alignEnd: true),
                                  _cell(l.isShort ? '${_fmtQty.format(l.shortageQty)} $uom' : '-',
                                      alignEnd: true, color: l.isShort ? Colors.red.shade700 : null),
                                  _cell(
                                    l.isShort ? (isEnglish ? 'Short' : 'ขาด') : (isEnglish ? 'OK' : 'พอ'),
                                    alignEnd: true,
                                    color: l.isShort ? Colors.red.shade700 : Colors.green.shade700,
                                    bold: true,
                                  ),
                                ]);
                            }),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }

  Widget _headerCell(String text, {bool alignEnd = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _cell(String text, {bool alignEnd = false, Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.bold : null)),
      );
}
