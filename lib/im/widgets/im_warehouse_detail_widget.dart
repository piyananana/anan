import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/widgets/cd_branch_list_widget.dart';
import '../models/im_warehouse.dart';

// ---------------------------------------------------------------------------
// Add/Edit location dialog
// ---------------------------------------------------------------------------
Future<ImLocation?> _showLocationDialog(BuildContext context, ImLocation? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  final codeCtrl = TextEditingController(text: existing?.locationCode ?? '');
  final nameCtrl = TextEditingController(text: existing?.locationName ?? '');
  bool isActive = existing?.isActive ?? true;

  return showDialog<ImLocation>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Location' : 'เพิ่มตำแหน่งจัดเก็บ') : (isEnglish ? 'Edit Location' : 'แก้ไขตำแหน่งจัดเก็บ')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: isEnglish ? 'Location Code *' : 'รหัสตำแหน่ง *', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: isEnglish ? 'Location Name' : 'ชื่อตำแหน่ง', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(isEnglish ? 'Active' : 'ใช้งาน'),
                value: isActive,
                activeColor: Colors.teal,
                onChanged: (v) => setDlg(() => isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (codeCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please enter the location code' : 'กรุณาป้อนรหัสตำแหน่ง')));
                return;
              }
              Navigator.of(ctx).pop(ImLocation(
                id: existing?.id,
                locationCode: codeCtrl.text.trim().toUpperCase(),
                locationName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                isActive: isActive,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

class ImWarehouseDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImWarehouse? selected;
  final Function(ImWarehouse) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ImWarehouseDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ImWarehouseDetailWidget> createState() => ImWarehouseDetailWidgetState();
}

class ImWarehouseDetailWidgetState extends State<ImWarehouseDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _addressCtrl;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEnglish = false;

  int? _branchId; String? _branchCode; String? _branchName;
  List<ImLocation> _locations = [];

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameThCtrl = TextEditingController();
    _nameEnCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _populate(widget.selected, widget.mode);
  }

  @override
  void didUpdateWidget(covariant ImWarehouseDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      _populate(widget.selected, widget.mode);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _populate(ImWarehouse? w, Mode mode) {
    final isNew = mode == Mode.add;
    _codeCtrl.text = isNew ? '' : (w?.warehouseCode ?? '');
    _nameThCtrl.text = isNew ? '' : (w?.warehouseNameTh ?? '');
    _nameEnCtrl.text = isNew ? '' : (w?.warehouseNameEn ?? '');
    _addressCtrl.text = isNew ? '' : (w?.address ?? '');
    _isActive = isNew ? true : (w?.isActive ?? true);
    final src = isNew ? null : w;
    _branchId = src?.branchId; _branchCode = src?.branchCode;
    _branchName = _isEnglish && (src?.branchNameEn ?? '').isNotEmpty ? src?.branchNameEn : src?.branchNameTh;
    _locations = isNew ? [] : List.from(w?.locations ?? []);
  }

  Future<void> _addLocation() async {
    final result = await _showLocationDialog(context, null);
    if (result != null) setState(() => _locations.add(result));
  }

  Future<void> _editLocation(int index) async {
    final result = await _showLocationDialog(context, _locations[index]);
    if (result != null) setState(() => _locations[index] = result);
  }

  void _removeLocation(int index) => setState(() => _locations.removeAt(index));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ImWarehouse(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        warehouseCode: _codeCtrl.text.trim().toUpperCase(),
        warehouseNameTh: _nameThCtrl.text.trim(),
        warehouseNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        branchId: _branchId,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        isActive: _isActive,
        locations: _locations,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBranch() async {
    final isEnglish = _isEnglish;
    await BranchListWidget.search(context, onSelected: (Branch b) {
      setState(() {
        _branchId = b.id; _branchCode = b.branchCode;
        _branchName = isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai;
      });
    });
  }

  Widget _buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch, VoidCallback? onClear}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Row(children: [
            Expanded(
              child: hasValue
                  ? Row(children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ])
                  : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
            ),
            if (!_isReadOnly) ...[
              IconButton(icon: const Icon(Icons.search, color: Colors.teal), tooltip: _isEnglish ? 'Search $label' : 'ค้นหา$label', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              if (hasValue && onClear != null)
                IconButton(icon: const Icon(Icons.clear, color: Colors.red, size: 18), tooltip: _isEnglish ? 'Clear' : 'ล้าง', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
            ],
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish ? 'Select a warehouse to view its data, or press + to add a new one' : 'เลือกคลังสินค้าเพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มคลังสินค้าใหม่',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? (isEnglish ? 'View Data' : 'ดูข้อมูล')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Warehouse' : 'แก้ไขคลังสินค้า')
                      : (isEnglish ? 'Add Warehouse' : 'เพิ่มคลังสินค้า'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: isEnglish ? 'Warehouse Code' : 'รหัสคลังสินค้า', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the warehouse code' : 'กรุณาป้อนรหัสคลังสินค้า') : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  readOnly: _isReadOnly,
                  controller: _nameThCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse Name (Thai)' : 'ชื่อคลังสินค้า (ไทย)', border: const OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the warehouse name (Thai)' : 'กรุณาป้อนชื่อคลังสินค้า (ไทย)') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  readOnly: _isReadOnly,
                  controller: _nameEnCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse Name (English)' : 'ชื่อคลังสินค้า (อังกฤษ)', border: const OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildFkField(
              label: isEnglish ? 'Branch' : 'สาขา',
              hasValue: _branchId != null,
              displayText: '$_branchCode — $_branchName',
              onSearch: _pickBranch,
              onClear: () => setState(() { _branchId = null; _branchCode = null; _branchName = null; }),
            ),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _addressCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: isEnglish ? 'Address' : 'ที่อยู่', border: const OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(isEnglish ? 'Status: ${_isActive ? 'Active' : 'Inactive'}' : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
              Switch(value: _isActive, activeColor: Colors.teal, onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v)),
            ]),
            const SizedBox(height: 24),
            const Divider(),
            Row(children: [
              Expanded(
                child: Text(isEnglish ? 'Locations (${_locations.length})' : 'ตำแหน่งจัดเก็บ (${_locations.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (!_isReadOnly)
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add location' : 'เพิ่มตำแหน่งจัดเก็บ', onPressed: _addLocation),
            ]),
            if (_locations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(isEnglish ? 'No locations yet' : 'ยังไม่มีตำแหน่งจัดเก็บ', style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              ..._locations.asMap().entries.map((entry) {
                final i = entry.key;
                final l = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.inventory_outlined, color: l.isActive ? Colors.teal : Colors.grey, size: 20),
                    title: Text('${l.locationCode}  ${l.locationName ?? ''}', style: TextStyle(color: l.isActive ? null : Colors.grey)),
                    trailing: _isReadOnly
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editLocation(i)),
                            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeLocation(i)),
                          ]),
                  ),
                );
              }),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container()
                    : Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : widget.mode == Mode.edit ? l.save : l.add),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel),
                    label: Text(l.cancel),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
