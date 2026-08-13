import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/im_location.dart';
import '../models/im_item_category.dart';
import '../widgets/im_item_category_list_tree_widget.dart';

class ImLocationDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImLocation? selected;
  final int warehouseId;
  final Function(ImLocation) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ImLocationDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.warehouseId,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ImLocationDetailWidget> createState() => ImLocationDetailWidgetState();
}

class ImLocationDetailWidgetState extends State<ImLocationDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEnglish = false;
  String _locationType = 'BIN';

  int? _categoryId; String? _categoryCode; String? _categoryNameTh; String? _categoryNameEn;

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _populate(widget.selected, widget.mode);
  }

  @override
  void didUpdateWidget(covariant ImLocationDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      _populate(widget.selected, widget.mode);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _populate(ImLocation? l, Mode mode) {
    // addChild passes the PARENT location as `selected`; the form itself starts blank.
    final isNewNode = mode == Mode.addRoot || mode == Mode.addChild;
    _codeCtrl.text = isNewNode ? '' : (l?.locationCode ?? '');
    _nameCtrl.text = isNewNode ? '' : (l?.locationName ?? '');
    _isActive = isNewNode ? true : (l?.isActive ?? true);
    _locationType = isNewNode ? 'BIN' : (l?.locationType ?? 'BIN');
    final src = isNewNode ? null : l;
    _categoryId = src?.categoryId;
    _categoryCode = src?.categoryCode;
    _categoryNameTh = src?.categoryNameTh;
    _categoryNameEn = src?.categoryNameEn;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ImLocation(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        warehouseId: widget.warehouseId,
        parentId: widget.mode == Mode.addRoot
            ? null
            : widget.mode == Mode.addChild
                ? widget.selected!.id
                : widget.selected!.parentId,
        locationCode: _codeCtrl.text.trim().toUpperCase(),
        locationName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        locationType: _locationType,
        categoryId: _locationType == 'BIN' ? _categoryId : null,
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

  Future<void> _pickCategory() async {
    final isEnglish = _isEnglish;
    await ImItemCategoryListTreeWidget.search(context, onSelected: (ImItemCategory c) {
      setState(() {
        _categoryId = c.id; _categoryCode = c.categoryCode;
        _categoryNameTh = c.categoryNameTh; _categoryNameEn = c.categoryNameEn;
      });
      if (c.categoryType != 'CATEGORY') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Note: "${c.categoryCode}" is a header, not a real category — pick a leaf category instead'
              : 'ข้อสังเกต: "${c.categoryCode}" เป็นหัวข้อ ไม่ใช่หมวดหมู่จริง — ควรเลือกหมวดหมู่ปลายทาง'),
          backgroundColor: Colors.orange,
        ));
      }
    });
  }

  Widget _buildFkField({
    required String label,
    required String? displayText,
    required bool hasValue,
    required VoidCallback onSearch,
    VoidCallback? onClear,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
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
              IconButton(
                icon: const Icon(Icons.search, color: Colors.teal),
                tooltip: _isEnglish ? 'Search' : 'ค้นหา',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onSearch,
              ),
              if (hasValue && onClear != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                  tooltip: _isEnglish ? 'Clear' : 'ล้าง',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                ),
            ],
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    final categoryName = isEnglish && (_categoryNameEn ?? '').isNotEmpty ? _categoryNameEn : _categoryNameTh;

    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish
              ? 'Select a location to view its data, or press + to add a new one'
              : 'เลือกตำแหน่งเพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มตำแหน่งใหม่',
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
                      ? (isEnglish ? 'Edit Location' : 'แก้ไขตำแหน่ง')
                      : widget.mode == Mode.addChild
                          ? '${isEnglish ? 'Add sub-location under' : 'เพิ่มตำแหน่งย่อยของ'}: ${widget.selected?.locationCode}'
                          : (isEnglish ? 'Add Location' : 'เพิ่มตำแหน่ง'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Location Code' : 'รหัสตำแหน่ง',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the location code' : 'กรุณาป้อนรหัสตำแหน่ง') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Location Name' : 'ชื่อตำแหน่ง', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(isEnglish ? 'Status: ${_isActive ? 'Active' : 'Inactive'}' : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
              Switch(
                value: _isActive,
                activeColor: Colors.teal,
                onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _locationType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Type' : 'ประเภท',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: imLocationTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(imLocationTypeLabel(t, isEnglish))))
                  .toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _locationType = v ?? 'BIN'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                _locationType == 'GROUP'
                    ? (isEnglish ? 'Organizational only (zone/aisle) — cannot hold stock or a category' : 'ใช้จัดกลุ่มในผังเท่านั้น (โซน/แถว) — เก็บสินค้าหรือกำหนดหมวดหมู่ไม่ได้')
                    : (isEnglish ? 'A real storage slot — can be assigned a category and hold stock' : 'ช่องเก็บจริง — กำหนดหมวดหมู่และเก็บสินค้าได้'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            if (_locationType == 'BIN') ...[
              const SizedBox(height: 10),
              _buildFkField(
                label: isEnglish ? 'Assigned Category' : 'หมวดหมู่ที่กำหนดให้เก็บ',
                hasValue: _categoryId != null,
                displayText: '$_categoryCode — $categoryName',
                onSearch: _pickCategory,
                onClear: () => setState(() { _categoryId = null; _categoryCode = null; _categoryNameTh = null; _categoryNameEn = null; }),
              ),
              Text(
                isEnglish
                    ? 'Used to flag mismatches when the actual item stored here belongs to a different category.'
                    : 'ใช้ตรวจสอบว่าสินค้าที่วางอยู่จริงในช่องนี้ตรงกับหมวดหมู่ที่กำหนดไว้หรือไม่',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
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
