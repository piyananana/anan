// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/project.dart';

class ProjectDetailWidget extends StatefulWidget {
  final Mode mode;
  final Project? selected;
  final Function(Project) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ProjectDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ProjectDetailWidget> createState() => ProjectDetailWidgetState();
}

class ProjectDetailWidgetState extends State<ProjectDetailWidget> {
  Project? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _projectCodeController;
  late TextEditingController _projectNameThaiController;
  late TextEditingController _projectNameEngController;
  late bool _isActive; 
  late DateTime _startDate;
  late DateTime _endDate;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;

    _projectCodeController = TextEditingController(text: _selected?.projectCode ?? '');
    _projectNameThaiController = TextEditingController(text: _selected?.projectNameThai ?? '');
    _projectNameEngController = TextEditingController(text: _selected?.projectNameEng ?? '');
    _isActive = _selected?.isActive ?? true;  
    _startDate = _selected?.startDate?.toLocal() ?? DateTime.now().toLocal();
    _endDate = _selected?.endDate?.toLocal() ??
        DateTime.now().add(const Duration(days: 365)).toLocal();
  }

  @override
  void didUpdateWidget(covariant ProjectDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;

      _projectCodeController.text = _selected?.projectCode ?? '';
      _projectNameThaiController.text = _selected?.projectNameThai ?? '';
      _projectNameEngController.text = _selected?.projectNameEng ?? '';
      _isActive = _selected?.isActive ?? true;  
      _startDate = _selected?.startDate?.toLocal() ?? DateTime.now().toLocal();
      _endDate = _selected?.endDate?.toLocal() ??
        DateTime.now().add(const Duration(days: 365)).toLocal();

      // *ไม่ต้องเรียก setState() เพราะการเปลี่ยนแปลงสถานะใน didUpdateWidget จะถูกนำไปใช้ในการ build ถัดไป*
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      // กรณีเปลี่ยนเป็นโหมดเพิ่มข้อมูลใหม่
      _selected = null;
      _projectCodeController.clear();
      _projectNameThaiController.clear();
      _projectNameEngController.clear();
      _isActive = true;  
      _startDate = DateTime.now().toLocal();
      _endDate = DateTime.now().add(const Duration(days: 365)).toLocal();
    }
  }

  @override
  void dispose() {
    _projectCodeController.dispose();
    _projectNameThaiController.dispose();
    _projectNameEngController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = Project(
          id: widget.selected?.id ?? 0,
          projectCode: _projectCodeController.text.toUpperCase(),
          projectNameThai: _projectNameThaiController.text,
          projectNameEng: _projectNameEngController.text,
          isActive: _isActive,
          startDate: _startDate,
          endDate: _endDate,
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
            'เลือกโครงการเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มโครงการใหม่'),
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
              widget.mode == Mode.view // _isViewing
                  ? 'ดูข้อมูล'
                  : widget.mode == Mode.edit // _isEditing
                      ? 'แก้ไขข้อมูล'
                      : 'เพิ่มข้อมูลใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child:
                  TextFormField(
                    readOnly: widget.mode != Mode.add,
                    controller: _projectCodeController,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'รหัสโครงการ',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 50,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length > 50) {
                        return 'โปรดระบุรหัสไม่เกิน 50 ตัวอักษร';
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
                Expanded(child:
                  TextFormField(
                    readOnly: readOnly,
                    controller: _projectNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อโครงการ (ไทย)',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 255,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'โปรดระบุชื่อโครงการภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child:
                  TextFormField(
                    readOnly: readOnly,
                    controller: _projectNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อโครงการ (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 255,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'โปรดระบุชื่อโครงการภาษาอังกฤษ';
                      }
                      return null;
                    },
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      side: BorderSide(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                    trailing: Switch(
                      value: _isActive,
                      onChanged: readOnly ? null : (bool value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    side: BorderSide(
                      color: widget.mode == Mode.view 
                        ? Colors.grey.shade500
                        : Colors.grey.shade700,
                    ),
                  ),
                  title: Text(
                      'วันที่เริ่มต้น: ${_dateFormat.format(_startDate.toLocal())}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: readOnly ? null : () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null) {
                            setState(() {
                              _startDate = picked;
                              if (widget.mode == Mode.add) {
                                _endDate = DateTime(
                                    picked.year + 1, picked.month, picked.day).toLocal();
                                _endDate = _endDate.subtract(const Duration(days: 1)).toLocal();
                              }
                            });
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    side: BorderSide(
                      color: widget.mode == Mode.view 
                        ? Colors.grey.shade500
                        : Colors.grey.shade700,
                    ),
                  ),
                  title: Text(
                      'วันที่สิ้นสุด: ${_dateFormat.format(_endDate.toLocal())}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: readOnly ? null : () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null) {
                            setState(() => _endDate = picked);
                          }
                        },
                ),
              ),
            ]),
            // --- สิ้นสุดการเพิ่ม Project ---
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
