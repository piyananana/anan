// lib/cd/widgets/sales_territory_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/sales_territory.dart';
import '../services/sales_territory_service.dart';

class SalesTerritoryDetailWidget extends StatefulWidget {
  final Mode mode;
  final SalesTerritory? selected;
  final Function(SalesTerritory) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const SalesTerritoryDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<SalesTerritoryDetailWidget> createState() =>
      SalesTerritoryDetailWidgetState();
}

class SalesTerritoryDetailWidgetState
    extends State<SalesTerritoryDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThaCtrl;
  late TextEditingController _nameEngCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _sortCtrl;

  int? _parentId;
  String? _parentCode;
  String? _parentNameThai;

  DateTime? _effectiveDateFrom;
  DateTime? _effectiveDateTo;
  bool _isActive = true;
  bool _isSaving = false;

  List<TerritoryMember> _members = [];
  bool _loadingMembers = false;
  int? _loadedTerritoryId;

  @override
  void initState() {
    super.initState();
    _init(widget.selected);
    _loadMembers(widget.selected?.id);
  }

  void _init(SalesTerritory? d) {
    _codeCtrl = TextEditingController(text: d?.territoryCode ?? '');
    _nameThaCtrl = TextEditingController(text: d?.territoryNameThai ?? '');
    _nameEngCtrl = TextEditingController(text: d?.territoryNameEng ?? '');
    _descCtrl = TextEditingController(text: d?.description ?? '');
    _sortCtrl =
        TextEditingController(text: (d?.sortOrder ?? 0).toString());
    _parentId = d?.parentId;
    _parentNameThai = d?.parentNameThai;
    _effectiveDateFrom = d?.effectiveDateFrom;
    _effectiveDateTo = d?.effectiveDateTo;
    _isActive = d?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant SalesTerritoryDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        (widget.mode == Mode.add && oldWidget.mode != Mode.add)) {
      _codeCtrl.text = widget.selected?.territoryCode ?? '';
      _nameThaCtrl.text = widget.selected?.territoryNameThai ?? '';
      _nameEngCtrl.text = widget.selected?.territoryNameEng ?? '';
      _descCtrl.text = widget.selected?.description ?? '';
      _sortCtrl.text = (widget.selected?.sortOrder ?? 0).toString();
      _parentId = widget.selected?.parentId;
      _parentNameThai = widget.selected?.parentNameThai;
      _effectiveDateFrom = widget.selected?.effectiveDateFrom;
      _effectiveDateTo = widget.selected?.effectiveDateTo;
      _isActive = widget.selected?.isActive ?? true;
      if (mounted) setState(() {});
      _loadMembers(widget.selected?.id);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThaCtrl.dispose();
    _nameEngCtrl.dispose();
    _descCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers(int? territoryId) async {
    if (territoryId == null || territoryId == _loadedTerritoryId) return;
    setState(() => _loadingMembers = true);
    try {
      final rows = await Provider.of<SalesTerritoryService>(context, listen: false)
          .fetchMembers(territoryId);
      if (mounted) {
        setState(() {
          _members = rows;
          _loadedTerritoryId = territoryId;
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _pickParent() async {
    final List<SalesTerritory> all;
    try {
      all = await Provider.of<SalesTerritoryService>(context, listen: false)
          .fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดข้อมูลเขตล้มเหลว: $e')));
      }
      return;
    }
    // ตัดตัวเอง (กัน circular) กรณีแก้ไข
    final choices = all
        .where((t) => t.id != widget.selected?.id)
        .toList()
      ..sort((a, b) => a.territoryCode.compareTo(b.territoryCode));

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('เลือกเขตแม่',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: ListView.builder(
            itemCount: choices.length,
            itemBuilder: (_, i) {
              final t = choices[i];
              return ListTile(
                title: Text('${t.territoryCode} — ${t.territoryNameThai}'),
                onTap: () {
                  setState(() {
                    _parentId = t.id;
                    _parentNameThai = t.territoryNameThai;
                    _parentCode = t.territoryCode;
                  });
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text('ยกเลิก', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_effectiveDateFrom ?? DateTime.now())
        : (_effectiveDateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _effectiveDateFrom = picked;
        } else {
          _effectiveDateTo = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = SalesTerritory(
        id: widget.selected?.id,
        territoryCode: _codeCtrl.text.trim().toUpperCase(),
        territoryNameThai: _nameThaCtrl.text.trim(),
        territoryNameEng: _nameEngCtrl.text.trim().isEmpty
            ? null
            : _nameEngCtrl.text.trim(),
        parentId: _parentId,
        sortOrder: int.tryParse(_sortCtrl.text) ?? 0,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        effectiveDateFrom: _effectiveDateFrom,
        effectiveDateTo: _effectiveDateTo,
        isActive: _isActive,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
          child: Text(
              'เลือกเขตการขายเพื่อแก้ไข หรือ กดปุ่ม + เพื่อเพิ่มใหม่'));
    }

    final bool ro = widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Text(
                    widget.mode == Mode.view
                        ? 'ดูข้อมูลเขตการขาย'
                        : widget.mode == Mode.edit
                            ? 'แก้ไขเขตการขาย'
                            : 'เพิ่มเขตการขาย',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),

                  // รหัส
                  TextFormField(
                    controller: _codeCtrl,
                    readOnly: widget.mode != Mode.add,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'รหัสเขตการขาย *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัส' : null,
                  ),
                  const SizedBox(height: 12),

                  // ชื่อ ไทย / อังกฤษ
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameThaCtrl,
                          readOnly: ro,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อเขต (ไทย) *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'โปรดระบุชื่อภาษาไทย'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _nameEngCtrl,
                          readOnly: ro,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อเขต (อังกฤษ)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // เขตแม่
                  InkWell(
                    onTap: ro ? null : _pickParent,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'เขตแม่ (ถ้ามี)',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_parentId != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _parentId = null;
                                  _parentCode = null;
                                  _parentNameThai = null;
                                }),
                              ),
                            const Icon(Icons.search),
                          ],
                        ),
                      ),
                      child: Text(
                        _parentId == null
                            ? '— ไม่มี —'
                            : '${_parentCode ?? ''} ${_parentNameThai ?? ''}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // sort_order
                  TextFormField(
                    controller: _sortCtrl,
                    readOnly: ro,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'ลำดับการแสดง',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // วันที่เริ่ม/สิ้นสุด
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: ro ? null : () => _pickDate(true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'วันที่เริ่มใช้',
                              border: const OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_effectiveDateFrom != null && !ro)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(
                                          () => _effectiveDateFrom = null),
                                    ),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ),
                            child: Text(_formatDate(_effectiveDateFrom).isEmpty
                                ? '—'
                                : _formatDate(_effectiveDateFrom)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: ro ? null : () => _pickDate(false),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'วันที่สิ้นสุด',
                              border: const OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_effectiveDateTo != null && !ro)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(
                                          () => _effectiveDateTo = null),
                                    ),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ),
                            child: Text(_formatDate(_effectiveDateTo).isEmpty
                                ? '—'
                                : _formatDate(_effectiveDateTo)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // คำอธิบาย
                  TextFormField(
                    controller: _descCtrl,
                    readOnly: ro,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'คำอธิบาย',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // สถานะ
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                      Switch(
                        value: _isActive,
                        onChanged: ro
                            ? null
                            : (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ปุ่ม
                  Row(
                    children: [
                      if (widget.mode != Mode.view)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submit,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                            label: Text(_isSaving
                                ? 'กำลังบันทึก...'
                                : widget.mode == Mode.edit
                                    ? 'บันทึก'
                                    : 'เพิ่ม'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (widget.mode != Mode.view) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onCancel,
                          icon: const Icon(Icons.cancel),
                          label: const Text('ยกเลิก'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ─── พนักงานขายที่รับผิดชอบ ───────────────────────
                  if (widget.selected?.id != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('พนักงานขายที่รับผิดชอบ',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        if (_loadingMembers)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const Divider(),
                    if (!_loadingMembers && _members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('— ยังไม่มีพนักงานขายในเขตนี้ —',
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        itemBuilder: (ctx, i) {
                          final m = _members[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                m.isPrimary ? Icons.star : Icons.star_border,
                                color: m.isPrimary
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                              title: Text(
                                '${m.salespersonCode} — ${m.salespersonNameThai}',
                                style: TextStyle(
                                  color: m.isActive ? null : Colors.grey,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.isPrimary)
                                    const Text('เขตหลัก',
                                        style: TextStyle(color: Colors.amber)),
                                  Text(
                                    _salespersonTypeLabel(m.salespersonType),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (m.effectiveDateFrom != null ||
                                      m.effectiveDateTo != null)
                                    Text(
                                      '${_formatDate(m.effectiveDateFrom)} — ${_formatDate(m.effectiveDateTo)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
          ],
        ),
      ),
    );
  }

  String _salespersonTypeLabel(String type) {
    const labels = {
      'EMPLOYEE': 'พนักงานภายใน',
      'INDIVIDUAL': 'บุคคลภายนอก',
      'COMPANY': 'บริษัท/นิติบุคคล',
    };
    return labels[type] ?? type;
  }
}
