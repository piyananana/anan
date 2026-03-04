// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import '../../sa/models/anan_module.dart';
import '../models/zipcode.dart';

class ZipcodeDetailWidget extends StatefulWidget {
  final Mode mode;
  final Zipcode? selected;
  final Function(Zipcode) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ZipcodeDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ZipcodeDetailWidget> createState() => ZipcodeDetailWidgetState();
}

class ZipcodeDetailWidgetState extends State<ZipcodeDetailWidget> {
  Zipcode? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subDistrictController;
  late TextEditingController _districtController;
  late TextEditingController _provinceController;
  late TextEditingController _zipcodeController;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _subDistrictController =
        TextEditingController(text: _selected?.subDistrict ?? '');
    _districtController = TextEditingController(text: _selected?.district ?? '');
    _provinceController = TextEditingController(text: _selected?.province ?? '');
    _zipcodeController = TextEditingController(text: _selected?.zipcode ?? '');
  }

  @override
  void didUpdateWidget(covariant ZipcodeDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;

      _subDistrictController.text = _selected?.subDistrict ?? '';
      _districtController.text = _selected?.district ?? '';
      _provinceController.text = _selected?.province ?? '';
      _zipcodeController.text = _selected?.zipcode ?? '';

      // *ไม่ต้องเรียก setState() เพราะการเปลี่ยนแปลงสถานะใน didUpdateWidget จะถูกนำไปใช้ในการ build ถัดไป*
    } else if (widget.mode == Mode.add  && oldWidget.mode != Mode.add) {
      // กรณีเพิ่มข้อมูลใหม่ ให้ล้างฟิลด์
      _selected = null;
      _subDistrictController.clear();
      _districtController.clear();
      _provinceController.clear();
      _zipcodeController.clear();
    }
  }

  @override
  void dispose() {
    _subDistrictController.dispose();
    _districtController.dispose();
    _provinceController.dispose();
    _zipcodeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = Zipcode(
          id: widget.selected?.id ?? 0,
          subDistrict: _subDistrictController.text,
          district: _districtController.text,
          province: _provinceController.text,
          zipcode: _zipcodeController.text,
        );
        await widget.onSubmit(newDetail);
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
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกรหัสไปรษณีย์เพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มรหัสไปรษณีย์ใหม่'),
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
              widget.mode == Mode.view // _isViewing
                  ? 'ดูข้อมูลรหัสไปรษณีย์'
                  : widget.mode == Mode.edit // _isEditing
                      ? 'แก้ไขรหัสไปรษณีย์'
                      : 'เพิ่มรหัสไปรษณีย์ใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _subDistrictController,
              decoration: const InputDecoration(
                labelText: 'ตำบล/แขวง',
                border: OutlineInputBorder(),
              ),
              // enabled: !_isEditing,  // ถ้าเป็นโหมดแก้ไข ให้ปิดการแก้ไขฟีลด์คีย์
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนชื่อตำบล/แขวง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _districtController,
              decoration: const InputDecoration(
                labelText: 'อำเภอ/เขต',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนชื่ออำเภอ/เขต';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _provinceController,
              decoration: const InputDecoration(
                labelText: 'จังหวัด',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนชื่อจังหวัด';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _zipcodeController,
              decoration: const InputDecoration(
                labelText: 'รหัสไปรษณีย์',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนรหัสไปรษณีย์';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // --- สิ้นสุดการเพิ่ม Zipcode ---
            const SizedBox(height: 32),
            // --- Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container() // ไม่แสดงปุ่มเพิ่ม/บันทึก หากเป็นโหมดดูอย่างเดียว
                    : Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submitForm,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
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
                const SizedBox(width: 16),
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
