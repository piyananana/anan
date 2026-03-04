// widgets/user_detail_form.dart
import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../models/business_unit.dart';

class BusinessUnitDetailWidget extends StatefulWidget {
  final Mode mode;
  final BusinessUnit? selected;
  final Function(BusinessUnit) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const BusinessUnitDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<BusinessUnitDetailWidget> createState() => BusinessUnitDetailWidgetState();
}

class BusinessUnitDetailWidgetState extends State<BusinessUnitDetailWidget> {
  BusinessUnit? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _buCodeController;
  late TextEditingController _buNameThaiController;
  late TextEditingController _buNameEngController;
  late bool _isControlBU;
  late bool _isActive;

  bool _isSaving = false;

  // bool _isLoading = false;
  // String _error = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _buCodeController =
        TextEditingController(text: _selected?.buCode ?? '');
    _isActive = _selected?.isActive ?? true;
    if (widget.mode == Mode.addChild) {
      _buNameThaiController.clear();
      _buNameEngController.clear();
      _isControlBU = true;
    } else {
      _buNameThaiController =
          TextEditingController(text: _selected?.buNameThai ?? '');
      _buNameEngController =
          TextEditingController(text: _selected?.buNameEng ?? '');
      _isControlBU = _selected?.isControlBU ?? true;
    }

    // โหลดข้อมูลสกุลเงินจาก backend หรือกำหนดค่าเริ่มต้น
  }

  @override
  void didUpdateWidget(covariant BusinessUnitDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (oldWidget.selected != null) {
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;

      _buCodeController =
          TextEditingController(text: _selected?.buCode ?? '');
      _isActive = _selected?.isActive ?? true;

      if (widget.mode == Mode.addChild) {
        _buNameThaiController.clear();
        _buNameEngController.clear();
        _isControlBU = true;
      } else {
        _buNameThaiController =
            TextEditingController(text: _selected?.buNameThai ?? '');
        _buNameEngController =
            TextEditingController(text: _selected?.buNameEng ?? '');
        _isControlBU = _selected?.isControlBU ?? false;
      }
    } else if (widget.mode == Mode.addRoot &&
        oldWidget.mode != Mode.addRoot) {
      // กรณีเปลี่ยนเป็นโหมดเพิ่มข้อมูลใหม่
      _selected = null;
      _buCodeController.clear();
      _buNameThaiController.clear();
      _buNameEngController.clear();
      _isControlBU = false;
      _isActive = true;
    } else if (widget.mode == Mode.addChild &&
        oldWidget.mode != Mode.addChild) {
      // กรณีเปลี่ยนเป็นโหมดเพิ่มข้อมูลใหม่
      _selected = widget.selected;
      _buCodeController =
          TextEditingController(text: _selected?.buCode ?? '');
      _buNameThaiController.clear();
      _buNameEngController.clear();
      _isControlBU = true;
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _buCodeController.dispose();
    _buNameThaiController.dispose();
    _buNameEngController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = BusinessUnit(
          id: widget.mode == Mode.edit ? widget.selected!.id : 0,
          parentId: widget.mode == Mode.addRoot
              ? null
              : widget.mode == Mode.addChild
                  ? widget.selected!.id
                  : widget.selected!.parentId,
          buCode: _buCodeController.text,
          buNameThai: _buNameThaiController.text,
          buNameEng: _buNameEngController.text,
          isControlBU: _isControlBU,
          isActive: _isActive,
        );
        await widget.onSubmit(newDetail);
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text(widget.mode == Mode.edit
        //           ? 'บันทึกข้อมูลเรียบร้อย: ${_buCodeController.text} ${_buNameThaiController.text}'
        //           : 'เพิ่มข้อมูลเรียบร้อย: ${_buCodeController.text} ${_buNameThaiController.text}'),
        //       backgroundColor: Colors.green,
        //     ),
        //   );
        // }
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
            'เลือกรายการหน่วยงานเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มหน่วยงานใหม่'),
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
                  ? 'ดูข้อมูล'
                  : widget.mode == Mode.edit
                      ? 'แก้ไขข้อมูล'
                      : widget.mode == Mode.addChild
                          ? 'เพิ่มหน่วยงานย่อย: ${_selected?.buCode} ${_selected?.buNameThai}'
                          : 'เพิ่มหน่วยงานหลัก',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              enabled: widget.mode != Mode.edit,
              controller: _buCodeController,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'รหัสหน่วยงาน',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนรหัสหน่วยงาน';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อหน่วยงาน (ภาษาไทย)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณาป้อนชื่อหน่วยงาน (ภาษาไทย)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _buNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อหน่วยงาน (ภาษาอังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณาป้อนชื่อหน่วยงาน (ภาษาอังกฤษ)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('สถานะ: ${_isActive ? 'ใช้' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (bool value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                      'การลงรายการ: ${_isControlBU ? 'ใช้ลงรายการ' : 'เป็นหน่วยงานหลัก'}'),
                ),
                Switch(
                  value: _isControlBU,
                  onChanged: (bool value) {
                    setState(() {
                      _isControlBU = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            // --- Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container() // ไม่แสดงปุ่มใดๆ หากเป็นโหมดดูอย่างเดียว
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
