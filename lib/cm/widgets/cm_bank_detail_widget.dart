// lib/cm/widgets/cm_bank_detail_widget.dart
import 'package:flutter/material.dart';
import '../../sa/models/anan_module.dart';
import '../models/cm_bank.dart';

class CmBankDetailWidget extends StatefulWidget {
  final Mode mode;
  final CmBank? selected;
  final Future<void> Function(CmBank) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const CmBankDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<CmBankDetailWidget> createState() => CmBankDetailWidgetState();
}

class CmBankDetailWidgetState extends State<CmBankDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameTh;
  late TextEditingController _nameEn;
  late TextEditingController _shortNameCtrl;
  late TextEditingController _swiftCtrl;
  late TextEditingController _remarkCtrl;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _init(widget.selected);
  }

  void _init(CmBank? d) {
    _codeCtrl = TextEditingController(text: d?.bankCode ?? '');
    _nameTh = TextEditingController(text: d?.bankNameTh ?? '');
    _nameEn = TextEditingController(text: d?.bankNameEn ?? '');
    _shortNameCtrl = TextEditingController(text: d?.shortName ?? '');
    _swiftCtrl = TextEditingController(text: d?.swiftCode ?? '');
    _remarkCtrl = TextEditingController(text: d?.remark ?? '');
    _isActive = d?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant CmBankDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        (widget.mode == Mode.add && oldWidget.mode != Mode.add)) {
      _codeCtrl.text = widget.selected?.bankCode ?? '';
      _nameTh.text = widget.selected?.bankNameTh ?? '';
      _nameEn.text = widget.selected?.bankNameEn ?? '';
      _shortNameCtrl.text = widget.selected?.shortName ?? '';
      _swiftCtrl.text = widget.selected?.swiftCode ?? '';
      _remarkCtrl.text = widget.selected?.remark ?? '';
      _isActive = widget.selected?.isActive ?? true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameTh.dispose();
    _nameEn.dispose();
    _shortNameCtrl.dispose();
    _swiftCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = CmBank(
        id: widget.selected?.id,
        bankCode: _codeCtrl.text.trim().toUpperCase(),
        bankNameTh: _nameTh.text.trim(),
        bankNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        shortName: _shortNameCtrl.text.trim().isEmpty ? null : _shortNameCtrl.text.trim(),
        swiftCode: _swiftCtrl.text.trim().isEmpty ? null : _swiftCtrl.text.trim().toUpperCase(),
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(child: Text('เลือกธนาคารเพื่อแก้ไข หรือกดปุ่ม + เพื่อเพิ่มใหม่'));
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
                  ? 'ดูข้อมูลธนาคาร'
                  : widget.mode == Mode.edit
                      ? 'แก้ไขธนาคาร'
                      : 'เพิ่มธนาคาร',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // รหัส
            TextFormField(
              controller: _codeCtrl,
              readOnly: widget.mode != Mode.add,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'รหัสธนาคาร *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัส' : null,
            ),
            const SizedBox(height: 12),

            // ชื่อไทย / อังกฤษ
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameTh,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อธนาคาร (ไทย) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'โปรดระบุชื่อ' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _nameEn,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อธนาคาร (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ชื่อย่อ / SWIFT
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shortNameCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อย่อ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _swiftCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'SWIFT Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // หมายเหตุ
            TextFormField(
              controller: _remarkCtrl,
              readOnly: ro,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // สถานะ
            Row(
              children: [
                Expanded(child: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                Switch(
                  value: _isActive,
                  onChanged: ro ? null : (v) => setState(() => _isActive = v),
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
                          : widget.mode == Mode.edit ? 'บันทึก' : 'เพิ่ม'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
