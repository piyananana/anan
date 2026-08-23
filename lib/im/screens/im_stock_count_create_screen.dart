// lib/im/screens/im_stock_count_create_screen.dart — ขั้นตอนที่ 2: สร้างข้อมูลตรวจนับ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_stock_count.dart';
import '../models/im_warehouse.dart';
import '../services/im_stock_count_service.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../widgets/im_stock_count_review_tree_widget.dart';

class ImStockCountCreateScreen extends StatefulWidget {
  const ImStockCountCreateScreen({super.key});

  @override
  State<ImStockCountCreateScreen> createState() => _ImStockCountCreateScreenState();
}

class _ImStockCountCreateScreenState extends State<ImStockCountCreateScreen> {
  final ImStockCountService _service = ImStockCountService();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  List<ImStockCountHeader> _rows = [];
  bool _isLoading = false;
  bool _sortNewestFirst = true;

  int? _selectedId;
  bool _viewOnly = false;
  int _resetKey = 0;
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _fetchRows();
  }

  Future<void> _fetchRows() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows();
      rows.sort((a, b) => _sortNewestFirst ? b.countDate.compareTo(a.countDate) : a.countDate.compareTo(b.countDate));
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSort() {
    setState(() {
      _sortNewestFirst = !_sortNewestFirst;
      _rows.sort((a, b) => _sortNewestFirst ? b.countDate.compareTo(a.countDate) : a.countDate.compareTo(b.countDate));
    });
  }

  void _openNew() => setState(() {
        _selectedId = null;
        _viewOnly = false;
        _resetKey++;
      });

  void _openView(int id) => setState(() {
        _selectedId = id;
        _viewOnly = true;
      });

  void _openEdit(int id) => setState(() {
        _selectedId = id;
        _viewOnly = false;
      });

  void _onSaved() {
    _fetchRows();
    setState(() {}); // ให้ panel ขวารีโหลดสถานะล่าสุดของ id เดิม (ไม่ reset กลับหน้าว่าง)
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':    return Colors.orange;
      case 'Posted':   return Colors.blue;
      case 'Approved': return Colors.purple;
      case 'Closed':   return Colors.green;
      case 'Void':     return Colors.red;
      default:         return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: isEnglish ? 'Refresh' : 'รีเฟรช', onPressed: _fetchRows),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: ColoredBox(
              color: Colors.blueGrey.shade100,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(_sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward),
                      tooltip: _sortNewestFirst
                          ? (isEnglish ? 'Newest first' : 'ล่าสุด-เก่าสุด')
                          : (isEnglish ? 'Oldest first' : 'เก่าสุด-ล่าสุด'),
                      onPressed: _toggleSort,
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openNew,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isEnglish ? 'Add Count Sheet' : 'เพิ่มข้อมูลตรวจนับ'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                          ? Center(child: Text(isEnglish ? 'No count sheets found' : 'ไม่พบใบตรวจนับ', style: const TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: _rows.length,
                              itemBuilder: (context, i) {
                                final r = _rows[i];
                                final canEdit = r.status != 'Approved' && r.status != 'Closed' && r.status != 'Void';
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(child: Text(r.countNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: _statusColor(r.status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                          child: Text(r.status, style: TextStyle(color: _statusColor(r.status), fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text('${_dateFmt.format(r.countDate)}   ${r.warehouseCode ?? ''} ${r.warehouseNameTh ?? ''}', style: const TextStyle(fontSize: 12)),
                                      if ((r.description ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(r.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                                        ),
                                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility, size: 18),
                                          tooltip: isEnglish ? 'View' : 'ดู',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _openView(r.id),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: canEdit ? () => _openEdit(r.id) : null,
                                        ),
                                      ]),
                                    ]),
                                  ),
                                );
                              },
                            ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: _CreateDetailPanel(
              key: ValueKey('$_selectedId-$_resetKey'),
              countId: _selectedId,
              viewOnly: _viewOnly,
              onSaved: _onSaved,
              onBack: () => setState(() => _selectedId = null),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateDetailPanel extends StatefulWidget {
  final int? countId;
  final bool viewOnly;
  final VoidCallback onSaved;
  final VoidCallback onBack;

  const _CreateDetailPanel({super.key, this.countId, required this.viewOnly, required this.onSaved, required this.onBack});

  @override
  State<_CreateDetailPanel> createState() => _CreateDetailPanelState();
}

class _CreateDetailPanelState extends State<_CreateDetailPanel> {
  final ImStockCountService _service = ImStockCountService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _descCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEnglish = false;

  int? _id;
  String _countNo = '';
  int? _warehouseId;
  String? _warehouseLabel;
  DateTime _countDate = DateTime.now();
  String _status = 'Draft';
  List<ImStockCountDetail> _lines = [];

  bool get _isDraft => _status == 'Draft';
  bool get _canEditFields => !widget.viewOnly && (_id == null || _isDraft);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.countId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchRow(widget.countId!);
      final h = data.header;
      _id = h.id;
      _countNo = h.countNo;
      _warehouseId = h.warehouseId;
      _warehouseLabel = '${h.warehouseCode ?? ''} ${h.warehouseNameTh ?? ''}'.trim();
      _countDate = h.countDate;
      _descCtrl.text = h.description ?? '';
      _status = h.status;
      _lines = data.details;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _hydrate(ImStockCount data) async {
    final h = data.header;
    _id = h.id;
    _countNo = h.countNo;
    _warehouseId = h.warehouseId;
    _warehouseLabel = '${h.warehouseCode ?? ''} ${h.warehouseNameTh ?? ''}'.trim();
    _countDate = h.countDate;
    _descCtrl.text = h.description ?? '';
    _status = h.status;
    _lines = data.details;
  }

  // "Draft" — บันทึกข้อมูลเอกสาร (สร้างใหม่ถ้ายังไม่มี id) โดยไม่เปลี่ยนสถานะ
  Future<ImStockCount?> _saveDraft() async {
    final isEnglish = _isEnglish;
    if (_warehouseId == null) {
      _warn(isEnglish ? 'Please select a warehouse' : 'กรุณาเลือกคลังสินค้า');
      return null;
    }
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    if (_id == null) {
      return _service.createCount(warehouseId: _warehouseId!, countDate: _countDate, description: desc);
    }
    return _service.updateHeader(id: _id!, warehouseId: _warehouseId!, countDate: _countDate, description: desc);
  }

  Future<void> _onDraftPressed() async {
    setState(() => _isSaving = true);
    try {
      final result = await _saveDraft();
      if (result != null) {
        await _hydrate(result);
        widget.onSaved();
        if (mounted) {
          setState(() {});
          _warn(_isEnglish ? 'Saved' : 'บันทึกสำเร็จ');
        }
      }
    } catch (e) {
      _warn(_isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // "บันทึกใบตรวจนับ" — บันทึกเอกสาร (ถ้ายังไม่มี) แล้ว Post ทันที (ล็อครายการ + freeze system_qty)
  Future<void> _onPostPressed() async {
    setState(() => _isSaving = true);
    try {
      var result = await _saveDraft();
      if (result == null) return;
      await _hydrate(result);
      result = await _service.postCount(_id!);
      await _hydrate(result);
      widget.onSaved();
      if (mounted) {
        setState(() {});
        _warn(_isEnglish ? 'Count sheet saved and posted' : 'บันทึกใบตรวจนับสำเร็จ');
      }
    } catch (e) {
      _warn(_isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onResyncPressed() async {
    if (_id == null) return;
    setState(() => _isSaving = true);
    try {
      final result = await _service.resyncLines(_id!);
      await _hydrate(result);
      if (mounted) {
        setState(() {});
        _warn(_isEnglish ? 'Location plan reloaded' : 'โหลดผังใหม่สำเร็จ');
      }
    } catch (e) {
      _warn(_isEnglish ? 'Reload failed: $e' : 'โหลดผังใหม่ล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onVoidPressed() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Void Count Sheet' : 'ยกเลิกใบตรวจนับ'),
        content: Text(isEnglish ? 'This cannot be undone.' : 'ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Back' : 'ย้อนกลับ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(isEnglish ? 'Void' : 'ยืนยันยกเลิก')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      final result = await _service.voidCount(_id!);
      await _hydrate(result);
      widget.onSaved();
      if (mounted) setState(() {});
    } catch (e) {
      _warn(isEnglish ? 'Void failed: $e' : 'ยกเลิกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _countDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _countDate = picked);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':    return Colors.orange;
      case 'Posted':   return Colors.blue;
      case 'Approved': return Colors.purple;
      case 'Closed':   return Colors.green;
      case 'Void':     return Colors.red;
      default:         return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.teal.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Text(
                _id == null
                    ? (isEnglish ? 'Add Count Sheet' : 'เพิ่มข้อมูลตรวจนับ')
                    : '${isEnglish ? 'Edit' : 'แก้ไข'} — $_countNo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (_id != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(_status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(_status, style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: (_isSaving || _id == null || !_isDraft) ? null : _onResyncPressed,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(isEnglish ? 'Reload Plan' : 'โหลดผังใหม่'),
            ),
            OutlinedButton(
              onPressed: (_isSaving || widget.viewOnly || !_canEditFields) ? null : _onDraftPressed,
              child: Text(isEnglish ? 'Draft' : 'Draft'),
            ),
            TextButton(
              onPressed: (_isSaving || widget.viewOnly || _id == null || !(_isDraft || _status == 'Posted')) ? null : _onVoidPressed,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isEnglish ? 'Void' : 'Void'),
            ),
            ElevatedButton(
              onPressed: (_isSaving || widget.viewOnly || !_canEditFields) ? null : _onPostPressed,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              child: Text(isEnglish ? 'Save Count Sheet' : 'บันทึกใบตรวจนับ'),
            ),
            OutlinedButton(onPressed: widget.onBack, child: Text(isEnglish ? 'Back' : 'กลับ')),
            if (_isSaving) const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 1,
              child: InputDecorator(
                decoration: InputDecoration(labelText: isEnglish ? 'Warehouse *' : 'คลังสินค้า *', border: const OutlineInputBorder(), isDense: true),
                child: Row(children: [
                  Expanded(
                    child: Text(_warehouseLabel ?? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
                        style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                  if (_canEditFields)
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.teal, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ImWarehouseListWidget.search(context, onSelected: (ImWarehouse w) {
                        setState(() { _warehouseId = w.id; _warehouseLabel = '${w.warehouseCode} ${w.warehouseNameTh}'; });
                      }),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: _canEditFields ? _pickDate : null,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'Count Date *' : 'วันที่ตรวจนับ *', border: const OutlineInputBorder(), isDense: true),
                  child: Text(_dateFmt.format(_countDate)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _descCtrl,
                readOnly: !_canEditFields,
                decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'คำอธิบาย', border: const OutlineInputBorder(), isDense: true),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _warehouseId == null
              ? Center(child: Text(isEnglish ? 'Select a warehouse to preview the location plan' : 'เลือกคลังสินค้าเพื่อดูผังตำแหน่งจัดเก็บ', style: const TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ImStockCountReviewTreeWidget(warehouseId: _warehouseId!, details: _lines),
                ),
        ),
      ],
    );
  }
}
