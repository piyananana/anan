import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/im_uom.dart';
import 'im_uom_std_conversion_section.dart';

class ImUomDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImUom? selected;
  final Function(ImUom) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มหน่วยนับซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ImUomDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImUomDetailWidget> createState() => ImUomDetailWidgetState();
}

class ImUomDetailWidgetState extends State<ImUomDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  bool _isActive = true;
  String _dimension = 'COUNT';
  int _decimals = 0;
  bool _isSaving = false;

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.selected?.uomCode ?? '');
    _nameThCtrl = TextEditingController(text: widget.selected?.uomNameTh ?? '');
    _nameEnCtrl = TextEditingController(text: widget.selected?.uomNameEn ?? '');
    _isActive = widget.selected?.isActive ?? true;
    _dimension = widget.selected?.uomDimension ?? 'COUNT';
    _decimals = widget.selected?.decimalPlaces ?? 0;
  }

  @override
  void didUpdateWidget(covariant ImUomDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      _codeCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.uomCode ?? '');
      _nameThCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.uomNameTh ?? '');
      _nameEnCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.uomNameEn ?? '');
      _isActive = widget.mode == Mode.add ? true : (widget.selected?.isActive ?? true);
      _dimension = widget.mode == Mode.add ? 'COUNT' : (widget.selected?.uomDimension ?? 'COUNT');
      _decimals = widget.mode == Mode.add ? 0 : (widget.selected?.decimalPlaces ?? 0);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ImUom(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        uomCode: _codeCtrl.text.trim().toUpperCase(),
        uomNameTh: _nameThCtrl.text.trim(),
        uomNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        isActive: _isActive,
        uomDimension: _dimension,
        decimalPlaces: _decimals,
      );
      await widget.onSubmit(row);
    } catch (e) {
      final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish ? 'Select a UOM to view its data, or press + to add a new one' : 'เลือกหน่วยนับเพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มหน่วยนับใหม่',
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
                      ? (isEnglish ? 'Edit UOM' : 'แก้ไขหน่วยนับ')
                      : (isEnglish ? 'Add UOM' : 'เพิ่มหน่วยนับ'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: isEnglish ? 'UOM Code' : 'รหัสหน่วยนับ', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the UOM code' : 'กรุณาป้อนรหัสหน่วยนับ') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameThCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'UOM Name (Thai)' : 'ชื่อหน่วยนับ (ไทย)', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the UOM name (Thai)' : 'กรุณาป้อนชื่อหน่วยนับ (ไทย)') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameEnCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'UOM Name (English)' : 'ชื่อหน่วยนับ (อังกฤษ)', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _dimension,
                  decoration: InputDecoration(labelText: isEnglish ? 'UOM Type' : 'ประเภทหน่วย', border: const OutlineInputBorder()),
                  items: kUomDimensions
                      .map((d) => DropdownMenuItem(value: d, child: Text(uomDimensionLabel(d, isEnglish))))
                      .toList(),
                  onChanged: _isReadOnly ? null : (v) => setState(() => _dimension = v ?? 'COUNT'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _decimals,
                  decoration: InputDecoration(labelText: isEnglish ? 'Decimal Places' : 'ทศนิยม (ตำแหน่ง)', border: const OutlineInputBorder()),
                  items: [0, 1, 2, 3, 4, 5, 6].map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                  onChanged: _isReadOnly ? null : (v) => setState(() => _decimals = v ?? 0),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                // กฎ (2026-11-21): หน่วยนับจำนวนต้องลงตัว, หน่วยอื่นปัดตามทศนิยม
                _dimension == 'COUNT'
                    ? (isEnglish
                        ? 'Count unit: quantities must fit $_decimals decimal place(s) exactly — a conversion that does not fit is rejected. Use 0 for whole pieces.'
                        : 'หน่วยนับจำนวน: จำนวนต้องลงตัวไม่เกิน $_decimals ตำแหน่ง ถ้าแปลงหน่วยแล้วไม่ลงตัวจะไม่ให้บันทึก หน่วยที่นับเป็นชิ้นให้ตั้ง 0')
                    : (isEnglish
                        ? 'Quantities in this unit (including converted ones) are rounded to $_decimals decimal place(s).'
                        : 'จำนวนในหน่วยนี้ (รวมจำนวนที่แปลงมาจากหน่วยอื่น) จะปัดเป็น $_decimals ตำแหน่ง'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(isEnglish ? 'Status: ${_isActive ? 'Active' : 'Inactive'}' : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
              Switch(value: _isActive, activeColor: Colors.teal, onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v)),
            ]),
            if (widget.mode != Mode.add && widget.selected != null) ...[
              const SizedBox(height: 16),
              ImUomStdConversionSection(uom: widget.selected!, readOnly: _isReadOnly),
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
