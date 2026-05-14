import 'package:flutter/material.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';

class GlDimensionValueScreen extends StatefulWidget {
  const GlDimensionValueScreen({super.key});

  @override
  State<GlDimensionValueScreen> createState() => _GlDimensionValueScreenState();
}

class _GlDimensionValueScreenState extends State<GlDimensionValueScreen> {
  final _service = GlDimensionService();
  List<GlDimensionType> _types = [];
  GlDimensionType? _selectedType;
  List<GlDimensionValue> _values = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final types = await _service.fetchAllTypes();
    setState(() {
      _types = types.where((t) => t.isActive).toList();
      if (_types.isNotEmpty) {
        _selectedType = _types.first;
        _loadValues();
      }
    });
  }

  Future<void> _loadValues() async {
    if (_selectedType == null) return;
    setState(() => _isLoading = true);
    try {
      final vals = await _service.fetchValuesByType(_selectedType!.typeCode, includeInactive: true);
      setState(() => _values = vals);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<GlDimensionValue> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _values;
    return _values.where((v) =>
        v.valueCode.toLowerCase().contains(q) ||
        v.valueNameThai.toLowerCase().contains(q)).toList();
  }

  /// จัดเรียง values แบบ DFS (parent ก่อน children) คืน list พร้อม depth
  List<({GlDimensionValue value, int depth})> _buildHierarchy(List<GlDimensionValue> values) {
    final byId = <int, GlDimensionValue>{for (final v in values) v.id: v};
    final result = <({GlDimensionValue value, int depth})>[];

    void addNode(GlDimensionValue v, int d) {
      result.add((value: v, depth: d));
      final children = values
          .where((c) => c.parentId == v.id)
          .toList()
        ..sort((a, b) => a.valueCode.compareTo(b.valueCode));
      for (final child in children) {
        addNode(child, d + 1);
      }
    }

    final roots = values
        .where((v) => v.parentId == null || !byId.containsKey(v.parentId))
        .toList()
      ..sort((a, b) => a.valueCode.compareTo(b.valueCode));
    for (final root in roots) {
      addNode(root, 0);
    }
    return result;
  }

  Future<void> _openForm([GlDimensionValue? existing]) async {
    final result = await showDialog<GlDimensionValue>(
      context: context,
      builder: (ctx) => _DimValueFormDialog(
        typeCode: _selectedType!.typeCode,
        typeName: _selectedType!.nameThai,
        existing: existing,
        allValues: _values,
      ),
    );
    if (result != null) {
      try {
        if (existing == null) {
          await _service.addValue(result);
        } else {
          await _service.updateValue(existing.id, result);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
        _loadValues();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _delete(GlDimensionValue v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการปิดใช้งาน'),
        content: Text('ปิดใช้งาน "${v.valueCode} — ${v.valueNameThai}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteValue(v.id);
        _loadValues();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.list_alt, size: 20),
          SizedBox(width: 8),
          Text('ข้อมูล GL Dimension'),
        ]),
        actions: [
          if (_selectedType != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('เพิ่ม'),
              onPressed: _openForm,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(width: 220, child: DropdownButtonFormField<GlDimensionType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'ประเภท Dimension', isDense: true, border: OutlineInputBorder()),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text('Slot ${t.slotNo}: ${t.nameThai}'))).toList(),
              onChanged: (t) {
                setState(() => _selectedType = t);
                _loadValues();
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _searchCtrl,
              decoration: const InputDecoration(labelText: 'ค้นหา', isDense: true, border: OutlineInputBorder(), prefixIcon: Icon(Icons.search, size: 16)),
              onChanged: (_) => setState(() {}),
            )),
          ]),
        ),
        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey)))
                  : SingleChildScrollView(
                      child: Builder(builder: (context) {
                        // ถ้ากำลัง search → flat list, ถ้าไม่ → hierarchy order
                        final isSearching = _searchCtrl.text.isNotEmpty;
                        final List<({GlDimensionValue value, int depth})> rows = isSearching
                            ? _filtered.map((v) => (value: v, depth: 0)).toList()
                            : _buildHierarchy(_values);

                        return DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                          columnSpacing: 12,
                          columns: const [
                            DataColumn(label: Text('รหัส', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ชื่อ (ไทย)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ชื่อ (อังกฤษ)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('จัดการ', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: rows.map((item) {
                            final v = item.value;
                            final depth = item.depth;
                            return DataRow(cells: [
                              // รหัส — เยื้องตาม depth
                              DataCell(Row(children: [
                                if (depth > 0) ...[
                                  SizedBox(width: depth * 16.0),
                                  Icon(Icons.subdirectory_arrow_right,
                                      size: 14, color: Colors.teal[300]),
                                  const SizedBox(width: 4),
                                ],
                                Text(v.valueCode,
                                    style: TextStyle(
                                      fontWeight: depth == 0 ? FontWeight.bold : FontWeight.w500,
                                      color: depth == 0 ? Colors.teal[700] : Colors.teal[500],
                                    )),
                              ])),
                              DataCell(Text(v.valueNameThai,
                                  style: TextStyle(
                                    fontSize: depth > 0 ? 12 : 13,
                                    color: v.isActive ? null : Colors.grey,
                                  ))),
                              DataCell(Text(v.valueNameEng ?? '',
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: v.isActive ? Colors.green[50] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: v.isActive ? Colors.green : Colors.grey),
                                ),
                                child: Text(v.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                                    style: TextStyle(fontSize: 11,
                                        color: v.isActive ? Colors.green[700] : Colors.grey)),
                              )),
                              DataCell(Row(children: [
                                IconButton(icon: const Icon(Icons.edit, size: 16), tooltip: 'แก้ไข',
                                    onPressed: () => _openForm(v)),
                                IconButton(icon: const Icon(Icons.block, size: 16, color: Colors.orange),
                                    tooltip: 'ปิดใช้งาน',
                                    onPressed: v.isActive ? () => _delete(v) : null),
                              ])),
                            ]);
                          }).toList(),
                        );
                      }),
                    ),
        ),
      ]),
    );
  }
}

// ── Form Dialog ──────────────────────────────────────────────────────────────
class _DimValueFormDialog extends StatefulWidget {
  final String typeCode;
  final String typeName;
  final GlDimensionValue? existing;
  final List<GlDimensionValue> allValues;

  const _DimValueFormDialog({required this.typeCode, required this.typeName, this.existing, required this.allValues});

  @override
  State<_DimValueFormDialog> createState() => _DimValueFormDialogState();
}

class _DimValueFormDialogState extends State<_DimValueFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nameEngCtrl;
  int? _parentId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeCtrl    = TextEditingController(text: e?.valueCode ?? '');
    _nameCtrl    = TextEditingController(text: e?.valueNameThai ?? '');
    _nameEngCtrl = TextEditingController(text: e?.valueNameEng ?? '');
    _parentId    = e?.parentId;
    _isActive    = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _nameCtrl.dispose(); _nameEngCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, GlDimensionValue(
      id:            widget.existing?.id ?? 0,
      typeCode:      widget.typeCode,
      valueCode:     _codeCtrl.text.trim().toUpperCase(),
      valueNameThai: _nameCtrl.text.trim(),
      valueNameEng:  _nameEngCtrl.text.trim().isEmpty ? null : _nameEngCtrl.text.trim(),
      parentId:      _parentId,
      isActive:      _isActive,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.allValues.where((v) => v.id != (widget.existing?.id ?? 0) && v.isActive).toList();
    return AlertDialog(
      title: Text('${widget.existing == null ? 'เพิ่ม' : 'แก้ไข'} ${widget.typeName}'),
      content: SizedBox(width: 480, child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          SizedBox(width: 140, child: TextFormField(
            controller: _codeCtrl,
            decoration: const InputDecoration(labelText: 'รหัส *', isDense: true, border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุรหัส' : null,
          )),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'ชื่อภาษาไทย *', isDense: true, border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุชื่อ' : null,
          )),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nameEngCtrl,
          decoration: const InputDecoration(labelText: 'ชื่อภาษาอังกฤษ', isDense: true, border: OutlineInputBorder()),
        ),
        if (parents.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            value: _parentId,
            decoration: const InputDecoration(labelText: 'ระดับบน (parent)', isDense: true, border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— ไม่มี —')),
              ...parents.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.displayName))),
            ],
            onChanged: (v) => setState(() => _parentId = v),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
          const Text('เปิดใช้งาน'),
        ]),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(onPressed: _submit, child: const Text('บันทึก')),
      ],
    );
  }
}
