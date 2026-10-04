// lib/im/widgets/im_price_group_detail_widget.dart — มิเรอร์ im_uom_detail_widget.dart ทุกประการ เพิ่มฟีลด์
// description (im_uom ไม่มี)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/im_price_group.dart';

class ImPriceGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImPriceGroup? selected;
  final Function(ImPriceGroup) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มกลุ่มราคาซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ImPriceGroupDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImPriceGroupDetailWidget> createState() => ImPriceGroupDetailWidgetState();
}

class ImPriceGroupDetailWidgetState extends State<ImPriceGroupDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _descCtrl;
  bool _isActive = true;
  bool _isSaving = false;

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.selected?.priceGroupCode ?? '');
    _nameThCtrl = TextEditingController(text: widget.selected?.priceGroupNameTh ?? '');
    _nameEnCtrl = TextEditingController(text: widget.selected?.priceGroupNameEn ?? '');
    _descCtrl = TextEditingController(text: widget.selected?.description ?? '');
    _isActive = widget.selected?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant ImPriceGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      _codeCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.priceGroupCode ?? '');
      _nameThCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.priceGroupNameTh ?? '');
      _nameEnCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.priceGroupNameEn ?? '');
      _descCtrl.text = widget.mode == Mode.add ? '' : (widget.selected?.description ?? '');
      _isActive = widget.mode == Mode.add ? true : (widget.selected?.isActive ?? true);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ImPriceGroup(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        priceGroupCode: _codeCtrl.text.trim().toUpperCase(),
        priceGroupNameTh: _nameThCtrl.text.trim(),
        priceGroupNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isActive: _isActive,
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
          isEnglish ? 'Select a price group to view its data, or press + to add a new one' : 'เลือกกลุ่มราคาเพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มกลุ่มราคาใหม่',
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
                      ? (isEnglish ? 'Edit Price Group' : 'แก้ไขกลุ่มราคา')
                      : (isEnglish ? 'Add Price Group' : 'เพิ่มกลุ่มราคา'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: isEnglish ? 'Price Group Code' : 'รหัสกลุ่มราคา', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the price group code' : 'กรุณาป้อนรหัสกลุ่มราคา') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameThCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Price Group Name (Thai)' : 'ชื่อกลุ่มราคา (ไทย)', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the price group name (Thai)' : 'กรุณาป้อนชื่อกลุ่มราคา (ไทย)') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameEnCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Price Group Name (English)' : 'ชื่อกลุ่มราคา (อังกฤษ)', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'คำอธิบาย', border: const OutlineInputBorder()),
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
