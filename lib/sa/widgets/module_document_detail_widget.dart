// widgets/user_detail_form.dart
// import 'dart:js_interop';

import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../cd/models/currency.dart';
// import '../../cd/services/currency_service.dart';
import '../../sa/models/anan_module.dart';
import '../models/module_document.dart';

class ModuleDocumentDetailWidget extends StatefulWidget {
  final Mode mode;
  final ModuleDocument? selected;
  final Function(ModuleDocument) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ModuleDocumentDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ModuleDocumentDetailWidget> createState() =>
      ModuleDocumentDetailWidgetState();
}

class ModuleDocumentDetailWidgetState
    extends State<ModuleDocumentDetailWidget> {
  ModuleDocument? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _docCodeController;
  late TextEditingController _docNameThaiController;
  late TextEditingController _docNameEngController;
  late TextEditingController _sortOrderController;
  late bool _isDocType;
  late bool _isAutoNumbering;
  late TextEditingController _formatPrefixController;
  late TextEditingController _formatSeparatorController;
  late String _formatSuffixDate;
  late TextEditingController _nextRunningNumberController;
  late int _runningLength;
  late bool _isActive;
  late String _sysModule;
  late String _sysDocType;

  Map<String, String> _sysDocTypes = {};
  // String _exampleDocNo = '';
  bool _isSaving = false;
  // bool _isLoading = false;
  // String _error = '';
  late TextEditingController _sampleDocNoController;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;

    _docCodeController = TextEditingController(text: _selected?.docCode ?? '');
    _docNameThaiController =
        TextEditingController(text: _selected?.docNameThai ?? '');
    _docNameEngController =
        TextEditingController(text: _selected?.docNameEng ?? '');
    _sortOrderController =
        TextEditingController(text: _selected?.sortOrder.toString() ?? '10');
    _isDocType = _selected?.isDocType ?? true;
    _isAutoNumbering = _selected?.isAutoNumbering ?? true;
    _formatPrefixController =
        TextEditingController(text: _selected?.formatPrefix ?? '');
    _formatSeparatorController =
        TextEditingController(text: _selected?.formatSeparator ?? '');
    _formatSuffixDate = _selected?.formatSuffixDate ?? '';
    _runningLength = _selected?.runningLength ?? 3;
    _nextRunningNumberController = TextEditingController(
        text: _selected?.nextRunningNumber
                .toString()
                .padLeft(_runningLength, '0') ??
            '001');
    _isActive = _selected?.isActive ?? true;
    _sysModule = _selected?.sysModule ?? '';
    _sysDocType = _selected?.sysDocType ?? '';
    _sysDocTypes = getSysDocType(_sysModule);
    _sampleDocNoController = TextEditingController(text: generateDocNo());
    if (widget.mode == Mode.addChild) {
      _docCodeController.clear();
      _docNameThaiController.clear();
      _docNameEngController.clear();
      _isDocType = true;
      _isAutoNumbering = true;
      _formatPrefixController.clear();
      _formatSeparatorController.clear();
      _formatSuffixDate = '';
      _runningLength = 3;
      _nextRunningNumberController = TextEditingController(text: '001');
      _isActive = true;
    }

    // โหลดข้อมูลสกุลเงินจาก backend หรือกำหนดค่าเริ่มต้น
  }

  @override
  void didUpdateWidget(covariant ModuleDocumentDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      // กรณีเลือก row ใหม่
      _selected = widget.selected;

      _docCodeController =
          TextEditingController(text: _selected?.docCode ?? '');
      _docNameThaiController =
          TextEditingController(text: _selected?.docNameThai ?? '');
      _docNameEngController =
          TextEditingController(text: _selected?.docNameEng ?? '');
      _sortOrderController =
          TextEditingController(text: _selected?.sortOrder.toString() ?? '10');
      _isDocType = _selected?.isDocType ?? true;
      _isAutoNumbering = _selected?.isAutoNumbering ?? true;
      _formatPrefixController =
          TextEditingController(text: _selected?.formatPrefix ?? '');
      _formatSeparatorController =
          TextEditingController(text: _selected?.formatSeparator ?? '');
      _formatSuffixDate = _selected?.formatSuffixDate ?? '';
      _runningLength = _selected?.runningLength ?? 3;
      _nextRunningNumberController = TextEditingController(
          text: _selected?.nextRunningNumber
                  .toString()
                  .padLeft(_runningLength, '0') ??
              '001');
      _isActive = _selected?.isActive ?? true;
      _sysModule = _selected?.sysModule ?? '';
      _sysDocType = _selected?.sysDocType ?? '';
      _sysDocTypes = getSysDocType(_sysModule);
      _sampleDocNoController = TextEditingController(text: generateDocNo());
      if (widget.mode == Mode.addChild) {
        // กรณีเลือก row ใหม่ เป็นโหมดเพิ่มประเภทเอกสารใหม่
        _docCodeController.clear();
        _docNameThaiController.clear();
        _docNameEngController.clear();
        _isDocType = true;
        _isAutoNumbering = true;
        _formatPrefixController.clear();
        _formatSeparatorController.clear();
        _formatSuffixDate = '';
        _runningLength = 3;
        _nextRunningNumberController = TextEditingController(text: '001');
        _isActive = true;
        _sysModule = '';
        _sysDocType = '';
      }
    } else if (widget.mode == Mode.addRoot && oldWidget.mode != Mode.addRoot) {
      // กรณีเปลี่ยนจากโหมดอื่นเป็นเป็นโหมดเพิ่มหัวข้อใหม่
      _selected = null;
      _docCodeController.clear();
      _docNameThaiController.clear();
      _docNameEngController.clear();
      _isDocType = false;
      _isAutoNumbering = false;
      _isActive = true;
      _sysModule = '';
      _sysDocType = '';
    } else if (widget.mode == Mode.addChild &&
        oldWidget.mode != Mode.addChild) {
      // กรณีเปลี่ยนจากโหมดอื่นเป็นโหมดเพิ่มประเภทเอกสารใหม่
      _docCodeController.clear();
      _docNameThaiController.clear();
      _docNameEngController.clear();
      _isDocType = true;
      _isAutoNumbering = true;
      _formatPrefixController.clear();
      _formatSeparatorController.clear();
      _formatSuffixDate = '';
      _runningLength = 3;
      _nextRunningNumberController = TextEditingController(text: '001');
      _isActive = true;
      _sysModule = '';
      _sysDocType = '';
    }
  }

  @override
  void dispose() {
    _docCodeController.dispose();
    _docNameThaiController.dispose();
    _docNameEngController.dispose();
    _sortOrderController.dispose();
    _formatPrefixController.dispose();
    _formatSeparatorController.dispose();
    _nextRunningNumberController.dispose();
    _sampleDocNoController.dispose();
    super.dispose();
  }

  String generateDocNo() {
    String prefix =
        // '${_formatPrefixController.text}${_formatSeparatorController.text}${_nextRunningNumberController.text.padLeft(_runningLength, '0')}';
        _formatPrefixController.text;
    String suffix = '';
    if (_formatSuffixDate == 'YY') {
      suffix = DateTime.now().year.toString().substring(2);
    }
    if (_formatSuffixDate == 'YYYY') {
      suffix = DateTime.now().year.toString();
    }
    if (_formatSuffixDate == 'YYMM') {
      suffix =
          '${DateTime.now().year.toString().substring(2)}${DateTime.now().month.toString().padLeft(2, '0')}';
    }
    if (_formatSuffixDate == 'YYYYMM') {
      suffix =
          '${DateTime.now().year.toString()}${DateTime.now().month.toString().padLeft(2, '0')}';
    }
    if (_formatSuffixDate == 'YYMMDD') {
      suffix =
          '${DateTime.now().year.toString().substring(2)}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
    }

    // return '$prefix${suffix.isNotEmpty ? _formatSeparatorController.text : ''}$suffix';
    return '$prefix$suffix${_formatSeparatorController.text}${_nextRunningNumberController.text.padLeft(_runningLength, '0')}';
  }

  Map<String, String> getSysDocType(String module) {
    switch (module) {
      case '01':
        return glSysDocType;
      case '11':
        return arSysDocType;
      case '21':
        return apSysDocType;
      case '31':
        return imSysDocType;
      case '81':
        return cqSysDocType;
      case '86':
        return dsSysDocType;
      case '91':
        return vpSysDocType;
      case '96':
        return vsSysDocType;
      default:
        return {};
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = ModuleDocument(
            id: widget.mode == Mode.edit ? widget.selected!.id : 0,
            parentId: widget.mode == Mode.addRoot
                ? null
                : widget.mode == Mode.addChild
                    ? widget.selected!.id
                    : widget.selected!.parentId,
            docCode: _docCodeController.text,
            docNameThai: _docNameThaiController.text,
            docNameEng: _docNameEngController.text,
            sortOrder: int.parse(_sortOrderController.text),
            isActive: _isActive,
            isDocType: _isDocType,
            sysModule: _sysModule.isNotEmpty ? _sysModule : '',
            isAutoNumbering: _isDocType ? _isAutoNumbering : false,
            formatPrefix: _isDocType ? _formatPrefixController.text : '',
            formatSeparator: _isDocType ? _formatSeparatorController.text : '',
            formatSuffixDate: _isDocType ? _formatSuffixDate : '',
            runningLength: _isDocType ? _runningLength : 0,
            nextRunningNumber:
                _isDocType ? int.parse(_nextRunningNumberController.text) : 1,
            sysDocType: _isDocType
                ? _sysDocType.isNotEmpty
                    ? _sysDocType
                    : ''
                : '');
        await widget.onSubmit(newDetail);
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text(widget.mode == Mode.edit
        //           ? 'บันทึกข้อมูลเรียบร้อย: ${_docCodeController.text} ${_docNameThaiController.text}'
        //           : 'เพิ่มข้อมูลเรียบร้อย: ${_docCodeController.text} ${_docNameThaiController.text}'),
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
            'เลือกประเภทเอกสารหรือโมดูลเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มข้อมูลใหม่'),
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
                      : widget.mode == Mode.addChild
                          ? 'เพิ่มข้อมูลย่อย: ${_selected?.docCode} ${_selected?.docNameThai}'
                          : 'เพิ่มข้อมูลโมดูลหลัก',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: widget.mode != Mode.add && widget.mode != Mode.addChild,
              controller: _docCodeController,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'รหัสประเภทเอกสาร/รหัสโมดูล',
                border: OutlineInputBorder(),
              ),
              // maxLength: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนรหัสประเภทเอกสารหรือโมดูล';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _docNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อ (ภาษาไทย)',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 100,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณาป้อนชื่อ (ภาษาไทย)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _docNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อ (ภาษาอังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 100,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณาป้อนชื่อ (ภาษาอังกฤษ)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ลำดับ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณาป้อนลำดับ';
                      }
                      if (int.tryParse(value) == null) {
                        return 'ต้องเป็นตัวเลขเท่านั้น';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _isDocType ? 'ประเภทเอกสาร' : 'หัวข้อ',
                    decoration: const InputDecoration(
                      labelText: 'ชนิดข้อมูล',
                      border: OutlineInputBorder(),
                    ),
                    items: ['ประเภทเอกสาร', 'หัวข้อ'].map((entry) {
                      return DropdownMenuItem(
                        value: entry,
                        child: Text(entry),
                      );
                    }).toList(),
                    onChanged: readOnly ? null : (value) {
                      if (value != null) {
                        setState(() {
                          _isDocType = value == 'ประเภทเอกสาร';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sysModule,
                    decoration: const InputDecoration(
                      labelText: 'โมดูล',
                      border: OutlineInputBorder(),
                    ),
                    items: sysModules.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text('${entry.key} - ${entry.value}'),
                      );
                    }).toList(),
                    onChanged: readOnly ? null : (value) {
                      if (value != null) {
                        setState(() {
                          _sysModule = value;
                          _sysDocTypes = getSysDocType(_sysModule);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            // ควบคุมการแสดงฟีลด์ที่ ประเภทเอกสาร ต้องใช้
            _isDocType
                ? Column(children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sysDocTypes.containsKey(_sysDocType)
                                ? _sysDocType
                                : '',
                            decoration: InputDecoration(
                              labelText: _sysDocTypes.isNotEmpty
                                  ? 'ประเภทเอกสารหลักของ ${sysModules[_sysModule]}'
                                  : 'ประเภทเอกสารหลัก',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: '', child: Text('- ไม่ระบุ -')),
                              ..._sysDocTypes.entries.map((entry) {
                                return DropdownMenuItem(
                                  value: entry.key,
                                  child: Text('${entry.key} - ${entry.value}'),
                                );
                              }),
                            ],
                            onChanged: readOnly ? null : (value) {
                              if (value != null) {
                                setState(() {
                                  _sysDocType = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              side: BorderSide(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            title: Text(
                                'เลขที่เอกสารอัตโนมัติ: ${_isAutoNumbering ? 'ใช่' : 'ไม่'}'),
                            trailing: Switch(
                              value: _isAutoNumbering,
                              onChanged: readOnly ? null : (bool value) {
                                setState(() {
                                  _isAutoNumbering = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    // ควบคุมการแสดงฟีลด์ที่ ประเภทเอกสาร และเลขที่อัตโนมัติ
                    _isAutoNumbering
                        ? Column(
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: readOnly,
                                        controller: _formatPrefixController,
                                        decoration: const InputDecoration(
                                          labelText: 'คำนำหน้า',
                                          border: OutlineInputBorder(),
                                        ),
                                        // maxLength: 10,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'กรุณาป้อนคำนำหน้า';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            _sampleDocNoController.text =
                                                generateDocNo();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _formatSuffixDate,
                                        decoration: const InputDecoration(
                                          labelText: 'คำต่อ(ปีเดือนวัน)',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          '',
                                          'YY',
                                          'YYYY',
                                          'YYMM',
                                          'YYYYMM',
                                          'YYMMDD'
                                        ].map((val) {
                                          return DropdownMenuItem(
                                            value: val,
                                            child: Text(val),
                                          );
                                        }).toList(),
                                        onChanged: readOnly ? null : (value) {
                                          if (value != null) {
                                            setState(() {
                                              _formatSuffixDate = value;
                                              _sampleDocNoController.text =
                                                  generateDocNo();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: readOnly,
                                        controller: _formatSeparatorController,
                                        decoration: const InputDecoration(
                                          labelText: 'อักษรคั่น',
                                          border: OutlineInputBorder(),
                                        ),
                                        // maxLength: 5,
                                        // validator: (value) {
                                        //   if (value == null || value.isEmpty) {
                                        //     return 'กรุณาป้อนคำนำหน้า';
                                        //   }
                                        //   return null;
                                        // },
                                        onChanged: (value) {
                                          setState(() {
                                            // _formatSeparatorController.text =
                                            //     value;
                                            _sampleDocNoController.text =
                                                generateDocNo();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        value: _runningLength,
                                        decoration: const InputDecoration(
                                          labelText: 'ความยาวเลขที่',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [3, 4, 5, 6, 7, 8, 9].map((val) {
                                          return DropdownMenuItem(
                                            value: val,
                                            child: Text(val.toString()),
                                          );
                                        }).toList(),
                                        onChanged: readOnly ? null : (value) {
                                          if (value != null) {
                                            setState(() {
                                              _runningLength = value;
                                              if (_nextRunningNumberController
                                                      .text.length <
                                                  _runningLength) {
                                                _nextRunningNumberController =
                                                    TextEditingController(
                                                        text: _nextRunningNumberController
                                                            .text
                                                            .padLeft(
                                                                _runningLength,
                                                                '0'));
                                              } else {
                                                _nextRunningNumberController =
                                                    TextEditingController(
                                                        text: _nextRunningNumberController
                                                            .text
                                                            .substring(
                                                                _nextRunningNumberController
                                                                        .text
                                                                        .length -
                                                                    _runningLength));
                                              }
                                              _sampleDocNoController.text =
                                                  generateDocNo();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: readOnly,
                                        controller:
                                            _nextRunningNumberController,
                                        textAlign: TextAlign.right,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'เลขที่ถัดไป',
                                          border: OutlineInputBorder(),
                                        ),
                                        // maxLength: _runningLength,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'กรุณาป้อนเลขที่อัตโนมัติถัดไป';
                                          }
                                          if (int.tryParse(value) == null ||
                                              int.tryParse(value)! <= 0) {
                                            return 'ต้องเป็นตัวเลขมากกว่าศูนย์เท่านั้น';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            _sampleDocNoController.text =
                                                generateDocNo();
                                          });
                                        },
                                      ),
                                    ),
                                  ]),
                              const SizedBox(
                                height: 16,
                              ),
                              // Row(
                              //     crossAxisAlignment: CrossAxisAlignment.start,
                              //     children: [
                              //     ]),
                              // const SizedBox(
                              //   height: 16,
                              // ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _sampleDocNoController,
                                      enabled: false,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'ตัวอย่างเลขที่เอกสารอัตโนมัติ',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ])
                : const SizedBox.shrink(),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
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
