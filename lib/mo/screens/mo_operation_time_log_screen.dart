// lib/mo/screens/mo_operation_time_log_screen.dart — บันทึกเวลาปฏิบัติงาน (Operation Time Log) หน้าจอสำหรับ
// ฝ่ายผลิต (Production): เลือกใบสั่งผลิตที่ Released/InProgress และใช้การคิดต้นทุนแบบ Routing (costing_mode=
// 'ROUTING') เท่านั้น แล้วบันทึกชั่วโมงแรงงาน/เครื่องจักรจริงต่อขั้นตอน (operation) ทีละขั้นตอน — ไม่ใช่ im_transaction
// ไม่มีผล GL/สต็อกตรงนี้เลย แค่สะสม actual_labor_hours/actual_machine_hours ไว้ให้ computeMoReceiptUnitCost ใช้
// ตอน Post รับสินค้าเข้าคลังจากการผลิต ('95') — ดู logOperationTime ใน moHeaderController.js
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoOperationTimeLogScreen extends StatefulWidget {
  const MoOperationTimeLogScreen({super.key});

  @override
  State<MoOperationTimeLogScreen> createState() => _MoOperationTimeLogScreenState();
}

class _OperationLine {
  final MoOperationDetail detail;
  final TextEditingController laborCtrl = TextEditingController();
  final TextEditingController machineCtrl = TextEditingController();
  bool markDone = false;
  bool isSubmitting = false;
  _OperationLine(this.detail);

  void dispose() {
    laborCtrl.dispose();
    machineCtrl.dispose();
  }
}

class _MoOperationTimeLogScreenState extends State<MoOperationTimeLogScreen> {
  final _moService = MoHeaderService();
  final _fmtQty = NumberFormat('#,##0.####');
  bool _isEnglish = false;
  bool _isLoadingMo = false;

  MoHeader? _mo;
  List<_OperationLine> _lines = [];

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMo() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoadingMo = true);
    List<MoHeader> rows = [];
    try {
      final released = await _moService.fetchRows(status: 'Released');
      final inProgress = await _moService.fetchRows(status: 'InProgress');
      rows = [...released, ...inProgress].where((m) => m.costingMode == 'ROUTING').toList();
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
                    ? Center(child: Text(isEnglish ? 'No open MOs using Routing costing found' : 'ไม่พบใบสั่งผลิตที่เปิดอยู่และใช้การคิดต้นทุนแบบ Routing'))
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
        l.dispose();
      }
      setState(() {
        _mo = full;
        _lines = full.operations.map((o) => _OperationLine(o)).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingMo = false);
    }
  }

  Future<void> _submitLine(_OperationLine line) async {
    final isEnglish = _isEnglish;
    final mo = _mo;
    if (mo == null) return;
    final labor = double.tryParse(line.laborCtrl.text) ?? 0;
    final machine = double.tryParse(line.machineCtrl.text) ?? 0;
    if (labor <= 0 && machine <= 0 && !line.markDone) {
      _warn(isEnglish
          ? 'Please enter labor/machine hours, or mark this operation as done'
          : 'กรุณาระบุชั่วโมงแรงงานหรือเครื่องจักร หรือเลือกเสร็จสิ้นขั้นตอน');
      return;
    }
    setState(() => line.isSubmitting = true);
    try {
      final updated = await _moService.logOperationTime(
        moId: mo.id, operationId: line.detail.id!,
        laborHours: labor, machineHours: machine, markDone: line.markDone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Time logged' : 'บันทึกเวลาปฏิบัติงานสำเร็จ'), backgroundColor: Colors.green));
        for (final l in _lines) {
          l.dispose();
        }
        setState(() {
          _mo = updated;
          _lines = updated.operations.map((o) => _OperationLine(o)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
        setState(() => line.isSubmitting = false);
      }
    }
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Done':
        return Colors.green;
      case 'InProgress':
        return Colors.blue;
      default:
        return Colors.grey;
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
      body: _isLoadingMo
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
                        Text(isEnglish ? 'Operations' : 'ขั้นตอนการผลิต', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        if (_lines.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(isEnglish ? 'No operations on this MO' : 'ใบสั่งผลิตนี้ไม่มีขั้นตอนการผลิต', style: TextStyle(color: Colors.grey.shade600)),
                          )
                        else
                          ..._lines.map((l) => _buildOperationCard(l, isEnglish, canCreate)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }

  Widget _buildOperationCard(_OperationLine l, bool isEnglish, bool canCreate) {
    final op = l.detail;
    final isDone = op.status == 'Done';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${op.workCenterCode ?? ''} ${isEnglish ? (op.workCenterNameEn ?? op.workCenterNameTh ?? '') : (op.workCenterNameTh ?? '')} — ${op.operationName ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _statusColor(op.status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(op.status, style: TextStyle(color: _statusColor(op.status), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          isEnglish
              ? 'Planned: ${_fmtQty.format(op.plannedLaborHours)} hr labor / ${_fmtQty.format(op.plannedMachineHours)} hr machine  ·  Logged so far: ${_fmtQty.format(op.actualLaborHours)} / ${_fmtQty.format(op.actualMachineHours)} hr'
              : 'แผน: ${_fmtQty.format(op.plannedLaborHours)} ชม.แรงงาน / ${_fmtQty.format(op.plannedMachineHours)} ชม.เครื่องจักร  ·  บันทึกแล้ว: ${_fmtQty.format(op.actualLaborHours)} / ${_fmtQty.format(op.actualMachineHours)} ชม.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        if (!isDone) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: l.laborCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Add labor hours' : 'เพิ่มชั่วโมงแรงงาน',
                  isDense: true, border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: l.machineCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Add machine hours' : 'เพิ่มชั่วโมงเครื่องจักร',
                  isDense: true, border: const OutlineInputBorder(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(
              value: l.markDone,
              onChanged: (v) => setState(() => l.markDone = v ?? false),
            ),
            Text(isEnglish ? 'Mark operation as done' : 'เสร็จสิ้นขั้นตอนนี้'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: (!canCreate || l.isSubmitting) ? null : () => _submitLine(l),
              icon: l.isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(isEnglish ? 'Save' : 'บันทึก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white),
            ),
          ]),
        ],
      ]),
    );
  }
}
