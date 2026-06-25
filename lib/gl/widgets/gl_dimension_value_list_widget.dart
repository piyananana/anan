import 'package:flutter/material.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';

class GlDimensionValueListWidget extends StatefulWidget {
  final Function(GlDimensionType type, GlDimensionValue row) onEdit;
  final Function(GlDimensionType type, GlDimensionValue row) onView;
  final Function(GlDimensionType type, GlDimensionValue row) onDelete;
  final Function(GlDimensionType type, GlDimensionValue row) onAddChild;
  final Function(GlDimensionType type) onAddRoot;
  final Function(GlDimensionType? type, List<GlDimensionValue> values) onTypeChanged;

  const GlDimensionValueListWidget({
    super.key,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onAddChild,
    required this.onAddRoot,
    required this.onTypeChanged,
  });

  @override
  State<GlDimensionValueListWidget> createState() =>
      GlDimensionValueListWidgetState();
}

class GlDimensionValueListWidgetState
    extends State<GlDimensionValueListWidget> {
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
      if (_types.isNotEmpty && _selectedType == null) {
        _selectedType = _types.first;
        _loadValues();
      }
    });
  }

  Future<void> refresh() async {
    if (_selectedType == null) {
      await _loadTypes();
    } else {
      await _loadValues();
    }
  }

  Future<void> _loadValues() async {
    if (_selectedType == null) return;
    setState(() => _isLoading = true);
    try {
      final vals = await _service.fetchValuesByType(
          _selectedType!.typeCode,
          includeInactive: true);
      setState(() => _values = vals);
      widget.onTypeChanged(_selectedType, vals);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<GlDimensionValue> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _values;
    return _values
        .where((v) =>
            v.valueCode.toLowerCase().contains(q) ||
            v.valueNameThai.toLowerCase().contains(q))
        .toList();
  }

  List<({GlDimensionValue value, int depth})> _buildHierarchy(
      List<GlDimensionValue> values) {
    final byId = <int, GlDimensionValue>{for (final v in values) v.id: v};
    final result = <({GlDimensionValue value, int depth})>[];

    void addNode(GlDimensionValue v, int d) {
      result.add((value: v, depth: d));
      final children = values
          .where((c) => c.parentId == v.id)
          .toList()
        ..sort((a, b) => a.valueCode.compareTo(b.valueCode));
      for (final child in children) addNode(child, d + 1);
    }

    final roots = values
        .where((v) => v.parentId == null || !byId.containsKey(v.parentId))
        .toList()
      ..sort((a, b) => a.valueCode.compareTo(b.valueCode));
    for (final root in roots) addNode(root, 0);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar: ประเภท + ปุ่มเพิ่ม ─────────────────────────────────
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (_selectedType != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
              tooltip: 'เพิ่ม ${_selectedType!.nameThai}',
              onPressed: () => widget.onAddRoot(_selectedType!),
            ),
          Expanded(
            child: DropdownButtonFormField<GlDimensionType>(
              isExpanded: true,
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'ประเภท Dimension',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text('Slot ${t.slotNo}: ${t.nameThai}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (t) {
                setState(() {
                  _selectedType = t;
                  _values = [];
                  _searchCtrl.clear();
                });
                _loadValues();
              },
            ),
          ),
        ]),
      ),

      // ── Search ─────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'ค้นหา (รหัส, ชื่อ)',
            prefixIcon: Icon(Icons.search, size: 18),
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(height: 4),

      // ── Count ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _searchCtrl.text.isEmpty
                ? 'ทั้งหมด ${_values.length} รายการ'
                : 'พบ ${_filtered.length} จาก ${_values.length} รายการ',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),

      // ── List ────────────────────────────────────────────────────────────
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const Center(
                    child: Text('ไม่มีข้อมูล',
                        style: TextStyle(color: Colors.grey)))
                : Builder(builder: (context) {
                    final isSearching = _searchCtrl.text.isNotEmpty;
                    final rows = isSearching
                        ? _filtered.map((v) => (value: v, depth: 0)).toList()
                        : _buildHierarchy(_values);

                    return ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final item = rows[i];
                        final v = item.value;
                        final depth = item.depth;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          elevation: 0.5,
                          color: v.isActive ? null : Colors.grey[50],
                          child: Stack(children: [
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.only(
                              left: 8 + depth * 16.0,
                              right: 4,
                            ),
                            leading: depth > 0
                                ? Icon(Icons.subdirectory_arrow_right,
                                    size: 14, color: Colors.teal[300])
                                : Icon(Icons.label,
                                    size: 16,
                                    color: v.isActive
                                        ? Colors.teal[600]
                                        : Colors.grey[400]),
                            title: Text(
                              '${v.valueCode}  ${v.valueNameThai}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: depth == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: v.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: v.valueNameEng != null &&
                                    v.valueNameEng!.isNotEmpty
                                ? Text(v.valueNameEng!,
                                    style: const TextStyle(fontSize: 11))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // สถานะ badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: v.isActive
                                        ? Colors.green[50]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: v.isActive
                                            ? Colors.green
                                            : Colors.grey),
                                  ),
                                  child: Text(
                                    v.isActive ? 'ใช้งาน' : 'ปิด',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: v.isActive
                                            ? Colors.green[700]
                                            : Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: const Icon(Icons.visibility,
                                      size: 16, color: Colors.green),
                                  tooltip: 'ดู',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () =>
                                      widget.onView(_selectedType!, v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 16, color: Colors.blue),
                                  tooltip: 'แก้ไข',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () =>
                                      widget.onEdit(_selectedType!, v),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      size: 16, color: Colors.teal[400]),
                                  tooltip: 'เพิ่มรายการย่อย',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () =>
                                      widget.onAddChild(_selectedType!, v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  tooltip: 'ลบ',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () =>
                                      widget.onDelete(_selectedType!, v),
                                ),
                              ],
                            ),
                          ),
                          if (!v.isActive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Icon(Icons.block, size: 72,
                                      color: Colors.red.withOpacity(0.12)),
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    );
                  }),
      ),
    ]);
  }
}
