// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/cd_zipcode.dart';

class ZipcodeDetailWidget extends StatefulWidget {
  final Mode mode;
  final Zipcode? selected;
  final Function(Zipcode) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน
  final int requestSeq;

  const ZipcodeDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
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
    if (widget.selected != oldWidget.selected || widget.requestSeq != oldWidget.requestSeq) {
      _selected = widget.selected;

      _subDistrictController.text = _selected?.subDistrict ?? '';
      _districtController.text = _selected?.district ?? '';
      _provinceController.text = _selected?.province ?? '';
      _zipcodeController.text = _selected?.zipcode ?? '';
    } else if (widget.mode == Mode.add  && oldWidget.mode != Mode.add) {
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
          final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l.errorOccurred}: $e'),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(isEnglish
            ? 'Select a zipcode to edit or press + to add new'
            : 'เลือกรหัสไปรษณีย์เพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มรหัสไปรษณีย์ใหม่'),
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
                  ? (isEnglish ? 'View Zipcode' : 'ดูข้อมูลรหัสไปรษณีย์')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Zipcode' : 'แก้ไขรหัสไปรษณีย์')
                      : (isEnglish ? 'Add Zipcode' : 'เพิ่มรหัสไปรษณีย์ใหม่'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: readOnly,
              controller: _subDistrictController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Sub-district / Khwaeng' : 'ตำบล/แขวง',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter sub-district' : 'กรุณาป้อนชื่อตำบล/แขวง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: readOnly,
              controller: _districtController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'District / Khet' : 'อำเภอ/เขต',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter district' : 'กรุณาป้อนชื่ออำเภอ/เขต';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: readOnly,
              controller: _provinceController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Province' : 'จังหวัด',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter province' : 'กรุณาป้อนชื่อจังหวัด';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: readOnly,
              controller: _zipcodeController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Zipcode' : 'รหัสไปรษณีย์',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter zipcode' : 'กรุณาป้อนรหัสไปรษณีย์';
                }
                return null;
              },
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container()
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
                              ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                              : widget.mode == Mode.edit
                                  ? l.save
                                  : l.add),
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
                    label: Text(l.cancel),
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
