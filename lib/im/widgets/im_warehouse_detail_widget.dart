import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/widgets/cd_branch_list_widget.dart';
import '../models/im_warehouse.dart';

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
  }

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
