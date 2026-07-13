// widgets/cd_business_type_detail_widget.dart
import 'package:flutter/material.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/cd_business_type.dart';

class BusinessTypeDetailWidget extends StatefulWidget {
  final Mode mode;
  final BusinessType? selected;
  final Function(BusinessType) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const BusinessTypeDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<BusinessTypeDetailWidget> createState() =>
      BusinessTypeDetailWidgetState();
}

class BusinessTypeDetailWidgetState extends State<BusinessTypeDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameThaController;
  late TextEditingController _nameEngController;
  late TextEditingController _descriptionController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.selected);
  }

  void _initControllers(BusinessType? data) {
    _codeController = TextEditingController(text: data?.businessTypeCode ?? '');
    _nameThaController =
        TextEditingController(text: data?.businessTypeNameThai ?? '');
    _nameEngController =
        TextEditingController(text: data?.businessTypeNameEng ?? '');
    _descriptionController =
        TextEditingController(text: data?.description ?? '');
    _isActive = data?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant BusinessTypeDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _codeController.text = widget.selected?.businessTypeCode ?? '';
      _nameThaController.text = widget.selected?.businessTypeNameThai ?? '';
      _nameEngController.text = widget.selected?.businessTypeNameEng ?? '';
      _descriptionController.text = widget.selected?.description ?? '';
      _isActive = widget.selected?.isActive ?? true;
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _codeController.clear();
      _nameThaController.clear();
      _nameEngController.clear();
      _descriptionController.clear();
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameThaController.dispose();
    _nameEngController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final row = BusinessType(
          id: widget.selected?.id ?? 0,
          businessTypeCode: _codeController.text.trim().toUpperCase(),
          businessTypeNameThai: _nameThaController.text.trim(),
          businessTypeNameEng: _nameEngController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isActive: _isActive,
        );
        await widget.onSubmit(row);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกประเภทธุรกิจเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? 'ดูข้อมูล'
                  : widget.mode == Mode.edit
                      ? 'แก้ไขข้อมูล'
                      : 'เพิ่มข้อมูลใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // รหัสประเภทธุรกิจ
            TextFormField(
              readOnly: widget.mode != Mode.add,
              controller: _codeController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'รหัสประเภทธุรกิจ *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'โปรดระบุรหัสประเภทธุรกิจ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ชื่อ (ไทย / อังกฤษ) แบบ Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _nameThaController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อประเภทธุรกิจ (ไทย) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'โปรดระบุชื่อภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _nameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อประเภทธุรกิจ (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // คำอธิบาย
            TextFormField(
              readOnly: readOnly,
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // สถานะ
            Row(
              children: [
                Expanded(
                  child: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: readOnly
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ปุ่ม
            Row(
              children: [
                if (widget.mode != Mode.view)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitForm,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving
                          ? 'กำลังบันทึก...'
                          : widget.mode == Mode.edit
                              ? 'บันทึก'
                              : 'เพิ่ม'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (widget.mode != Mode.view) const SizedBox(width: 16),
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
