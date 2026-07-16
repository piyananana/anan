import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/gl_dimension.dart';

enum GlDimValueMode { none, add, addChild, edit, view }

class GlDimensionValueDetailWidget extends StatefulWidget {
  final GlDimValueMode mode;
  final GlDimensionType? selectedType;
  final GlDimensionValue? selected;       // row ที่เลือกในรายการ (edit/view/addChild)
  final List<GlDimensionValue> allValues; // ทั้งหมดของ type นั้น (สำหรับ parent picker)
  final Future<void> Function(GlDimensionValue) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const GlDimensionValueDetailWidget({
    super.key,
    required this.mode,
    this.selectedType,
    this.selected,
    required this.allValues,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<GlDimensionValueDetailWidget> createState() =>
      GlDimensionValueDetailWidgetState();
}

class GlDimensionValueDetailWidgetState
    extends State<GlDimensionValueDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameTh;
  late TextEditingController _nameEng;
  int? _parentId;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  @override
  void didUpdateWidget(covariant GlDimensionValueDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected || oldWidget.mode != widget.mode) {
      _initFields();
    }
  }

  void _initFields() {
    final e = widget.selected;
    final isAddChild = widget.mode == GlDimValueMode.addChild;
    _codeCtrl   = TextEditingController(text: widget.mode == GlDimValueMode.edit ? (e?.valueCode ?? '') : '');
    _nameTh     = TextEditingController(text: widget.mode == GlDimValueMode.edit || widget.mode == GlDimValueMode.view ? (e?.valueNameThai ?? '') : '');
    _nameEng    = TextEditingController(text: widget.mode == GlDimValueMode.edit || widget.mode == GlDimValueMode.view ? (e?.valueNameEng ?? '') : '');
    _parentId   = isAddChild ? e?.id : (widget.mode == GlDimValueMode.edit ? e?.parentId : null);
    _isActive   = widget.mode == GlDimValueMode.edit ? (e?.isActive ?? true) : true;
    _isSaving   = false;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameTh.dispose();
    _nameEng.dispose();
    super.dispose();
  }

  bool get _isReadOnly => widget.mode == GlDimValueMode.view;

  InputDecoration _fieldDeco(String label, {bool required = false}) =>
      InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        filled: _isReadOnly,
        fillColor: _isReadOnly ? Colors.grey[100] : null,
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(GlDimensionValue(
        id:            widget.selected?.id ?? 0,
        typeCode:      widget.selectedType?.typeCode ?? '',
        valueCode:     _codeCtrl.text.trim().toUpperCase(),
        valueNameThai: _nameTh.text.trim(),
        valueNameEng:  _nameEng.text.trim().isEmpty ? null : _nameEng.text.trim(),
        parentId:      _parentId,
        isActive:      _isActive,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    if (widget.isPlaceholder || widget.mode == GlDimValueMode.none) {
      return Center(
        child: Text(
            isEnglish
                ? 'Select an item from the left, or press + to add new data'
                : 'เลือกรายการจากด้านซ้าย หรือกดปุ่ม + เพื่อเพิ่มข้อมูลใหม่',
            style: const TextStyle(color: Colors.grey)),
      );
    }

    final selectedType = widget.selectedType;
    final typeName = selectedType == null
        ? 'Dimension'
        : (isEnglish && (selectedType.nameEng ?? '').isNotEmpty
            ? selectedType.nameEng!
            : selectedType.nameThai);
    final String title = switch (widget.mode) {
      GlDimValueMode.add      => isEnglish ? 'Add $typeName' : 'เพิ่ม $typeName',
      GlDimValueMode.addChild => isEnglish ? 'Add $typeName (Child)' : 'เพิ่ม $typeName (ย่อย)',
      GlDimValueMode.edit     => isEnglish ? 'Edit $typeName' : 'แก้ไข $typeName',
      GlDimValueMode.view     => isEnglish ? 'View $typeName' : 'ดู $typeName',
      _                       => typeName,
    };

    // parents = ทุก value ยกเว้นตัวเอง + ลูกหลาน
    final parents = widget.allValues
        .where((v) => v.id != (widget.selected?.id ?? 0) && v.isActive)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── หัวเรื่อง ──────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.tune, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ]),
            const SizedBox(height: 20),

            // ── รหัส + ชื่อไทย ─────────────────────────────────────────
            Row(children: [
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _codeCtrl,
                  readOnly: _isReadOnly || widget.mode == GlDimValueMode.edit,
                  decoration: _fieldDeco(isEnglish ? 'Code' : 'รหัส', required: true),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (isEnglish ? 'Please enter a code' : 'กรุณาระบุรหัส')
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _nameTh,
                  readOnly: _isReadOnly,
                  decoration: _fieldDeco(isEnglish ? 'Thai Name' : 'ชื่อภาษาไทย', required: true),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (isEnglish ? 'Please enter a name' : 'กรุณาระบุชื่อ')
                      : null,
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // ── ชื่ออังกฤษ ──────────────────────────────────────────────
            TextFormField(
              controller: _nameEng,
              readOnly: _isReadOnly,
              decoration: _fieldDeco(isEnglish ? 'English Name' : 'ชื่อภาษาอังกฤษ'),
            ),
            const SizedBox(height: 14),

            // ── Parent picker ────────────────────────────────────────────
            if (parents.isNotEmpty)
              DropdownButtonFormField<int?>(
                isExpanded: true,
                value: _parentId,
                decoration: _fieldDeco(isEnglish ? 'Parent Level' : 'ระดับบน (Parent)'),
                items: [
                  DropdownMenuItem<int?>(
                      value: null,
                      child: Text(isEnglish ? '— None (Top Level) —' : '— ไม่มี (ระดับบนสุด) —')),
                  ...parents.map((p) => DropdownMenuItem<int?>(
                        value: p.id,
                        child: Text('${p.valueCode} — ${isEnglish && (p.valueNameEng ?? '').isNotEmpty ? p.valueNameEng! : p.valueNameThai}'),
                      )),
                ],
                onChanged: _isReadOnly ? null : (v) => setState(() => _parentId = v),
              ),
            const SizedBox(height: 14),

            // ── สถานะ ────────────────────────────────────────────────────
            Row(children: [
              Switch(
                value: _isActive,
                onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
              ),
              const SizedBox(width: 8),
              Text(
                  _isActive
                      ? (isEnglish ? 'Enabled' : 'เปิดใช้งาน')
                      : (isEnglish ? 'Disabled' : 'ปิดใช้งาน'),
                  style: TextStyle(
                    color: _isActive ? Colors.green[700] : Colors.grey,
                    fontWeight: FontWeight.w500,
                  )),
            ]),
            const SizedBox(height: 28),

            // ── ปุ่ม ─────────────────────────────────────────────────────
            if (!_isReadOnly)
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: _isSaving ? null : widget.onCancel,
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving
                      ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                      : l.save),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
