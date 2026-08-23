// lib/sa/widgets/sa_module_document_detail_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/sa_module_document.dart';
import '../services/sa_language_provider.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

class ModuleDocumentDetailWidget extends StatefulWidget {
  final Mode mode;
  final ModuleDocument? selected;
  final Function(ModuleDocument) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มโมดูลหลักซ้ำหลังพิมพ์ข้อมูลค้างไว้ หรือ
  // กดเพิ่มโมดูลหลักหลังจากหน้าจออยู่ในสถานะ placeholder ที่ใช้ mode: Mode.addRoot, selected: null ชุดเดียวกันโดยบังเอิญ)
  final int requestSeq;

  const ModuleDocumentDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
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
  bool _isSaving = false;
  late TextEditingController _sampleDocNoController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _syncStateFromSelected();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant ModuleDocumentDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        widget.requestSeq != oldWidget.requestSeq) {
      _disposeControllers();
      _selected = widget.selected;
      _syncStateFromSelected();
      _initControllers();
      setState(() {});
    } else if (widget.mode == Mode.addRoot && oldWidget.mode != Mode.addRoot) {
      _disposeControllers();
      _selected = null;
      _syncStateFromSelected();
      _initControllers();
      setState(() {});
    } else if (widget.mode == Mode.addChild &&
        oldWidget.mode != Mode.addChild) {
      _disposeControllers();
      _syncStateFromSelected();
      _initControllers();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  void _syncStateFromSelected() {
    _isDocType = _selected?.isDocType ?? true;
    _isAutoNumbering = _selected?.isAutoNumbering ?? true;
    _formatSuffixDate = _selected?.formatSuffixDate ?? '';
    _runningLength = _selected?.runningLength ?? 3;
    _isActive = _selected?.isActive ?? true;
    _sysModule = _selected?.sysModule ?? '';
    _sysDocType = _selected?.sysDocType ?? '';
    _sysDocTypes = getSysDocType(_sysModule);

    if (widget.mode == Mode.addRoot) {
      _isDocType = false;
      _isAutoNumbering = false;
      _isActive = true;
      _sysModule = '';
      _sysDocType = '';
      _sysDocTypes = {};
    } else if (widget.mode == Mode.addChild) {
      _isDocType = true;
      _isAutoNumbering = true;
      _formatSuffixDate = '';
      _runningLength = 3;
      _isActive = true;
      _sysModule = '';
      _sysDocType = '';
      _sysDocTypes = {};
    }
  }

  void _initControllers() {
    final isAdd =
        widget.mode == Mode.addRoot || widget.mode == Mode.addChild;
    _docCodeController =
        TextEditingController(text: isAdd ? '' : (_selected?.docCode ?? ''));
    _docNameThaiController = TextEditingController(
        text: isAdd ? '' : (_selected?.docNameThai ?? ''));
    _docNameEngController =
        TextEditingController(text: isAdd ? '' : (_selected?.docNameEng ?? ''));
    _sortOrderController = TextEditingController(
        text: isAdd ? '10' : (_selected?.sortOrder.toString() ?? '10'));
    _formatPrefixController = TextEditingController(
        text: isAdd ? '' : (_selected?.formatPrefix ?? ''));
    _formatSeparatorController = TextEditingController(
        text: isAdd ? '' : (_selected?.formatSeparator ?? ''));
    _nextRunningNumberController = TextEditingController(
        text: isAdd
            ? '001'
            : (_selected?.nextRunningNumber
                    .toString()
                    .padLeft(_runningLength, '0') ??
                '001'));
    _sampleDocNoController =
        TextEditingController(text: isAdd ? '' : generateDocNo());
  }

  void _disposeControllers() {
    _docCodeController.dispose();
    _docNameThaiController.dispose();
    _docNameEngController.dispose();
    _sortOrderController.dispose();
    _formatPrefixController.dispose();
    _formatSeparatorController.dispose();
    _nextRunningNumberController.dispose();
    _sampleDocNoController.dispose();
  }

  // ── Form logic ────────────────────────────────────────────────────────────

  String generateDocNo() {
    String prefix = _formatPrefixController.text;
    String suffix = '';
    if (_formatSuffixDate == 'YY') {
      suffix = DateTime.now().year.toString().substring(2);
    } else if (_formatSuffixDate == 'YYYY') {
      suffix = DateTime.now().year.toString();
    } else if (_formatSuffixDate == 'YYMM') {
      suffix =
          '${DateTime.now().year.toString().substring(2)}${DateTime.now().month.toString().padLeft(2, '0')}';
    } else if (_formatSuffixDate == 'YYYYMM') {
      suffix =
          '${DateTime.now().year.toString()}${DateTime.now().month.toString().padLeft(2, '0')}';
    } else if (_formatSuffixDate == 'YYMMDD') {
      suffix =
          '${DateTime.now().year.toString().substring(2)}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
    }
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
        return cmSysDocType;
      // case '86':
      //   return dsSysDocType;
      // case '91':
      //   return vpSysDocType;
      // case '96':
      //   return vsSysDocType;
      default:
        return {};
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final isEnglish = mounted
        ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
        : false;
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
        sysModule: _sysModule,
        isAutoNumbering: _isDocType ? _isAutoNumbering : false,
        formatPrefix: _isDocType ? _formatPrefixController.text : '',
        formatSeparator: _isDocType ? _formatSeparatorController.text : '',
        formatSuffixDate: _isDocType ? _formatSuffixDate : '',
        runningLength: _isDocType ? _runningLength : 0,
        nextRunningNumber:
            _isDocType ? int.parse(_nextRunningNumberController.text) : 1,
        sysDocType: _isDocType ? _sysDocType : '',
      );
      await widget.onSubmit(newDetail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    if (widget.isPlaceholder) {
      return Center(
        child: Text(isEnglish
            ? 'Select a document type or module to edit/delete, or press + to add new'
            : 'เลือกประเภทเอกสารหรือโมดูลเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มข้อมูลใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;

    final String title = widget.mode == Mode.view
        ? (isEnglish ? 'View' : 'ดูข้อมูล')
        : widget.mode == Mode.edit
            ? (isEnglish ? 'Edit' : 'แก้ไขข้อมูล')
            : widget.mode == Mode.addChild
                ? (isEnglish
                    ? 'Add Sub-item: ${_selected?.docCode} ${_selected?.docNameEng ?? _selected?.docNameThai}'
                    : 'เพิ่มข้อมูลย่อย: ${_selected?.docCode} ${_selected?.docNameThai}')
                : (isEnglish ? 'Add Main Module' : 'เพิ่มข้อมูลโมดูลหลัก');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header bar ────────────────────────────────────────────────────
        Container(
          color: Colors.deepOrange[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.mode != Mode.view) ...[
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitForm,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.deepOrange))
                      : const Icon(Icons.save, size: 16),
                  label: Text(
                      _isSaving
                          ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                          : widget.mode == Mode.edit
                              ? (isEnglish ? 'Save' : 'บันทึก')
                              : (isEnglish ? 'Add' : 'เพิ่ม'),
                      style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange[900],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.cancel, size: 16),
                label: Text(isEnglish ? 'Cancel' : 'ยกเลิก', style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white54,
                  foregroundColor: Colors.deepOrange[900],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // ── Form body ─────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doc code
                  TextFormField(
                    readOnly: widget.mode != Mode.addRoot &&
                        widget.mode != Mode.addChild,
                    controller: _docCodeController,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 24),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Document Type Code / Module Code' : 'รหัสประเภทเอกสาร/รหัสโมดูล',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish
                            ? 'Please enter a document type or module code'
                            : 'กรุณาป้อนรหัสประเภทเอกสารหรือโมดูล';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Names row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: readOnly,
                          controller: _docNameThaiController,
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Name (Thai)' : 'ชื่อ (ภาษาไทย)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return isEnglish ? 'Please enter a Thai name' : 'กรุณาป้อนชื่อ (ภาษาไทย)';
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
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Name (English)' : 'ชื่อ (ภาษาอังกฤษ)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return isEnglish ? 'Please enter an English name' : 'กรุณาป้อนชื่อ (ภาษาอังกฤษ)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Sort order + status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: readOnly,
                          controller: _sortOrderController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Sort Order' : 'ลำดับ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return isEnglish ? 'Please enter sort order' : 'กรุณาป้อนลำดับ';
                            }
                            if (int.tryParse(value) == null) {
                              return isEnglish ? 'Must be a number' : 'ต้องเป็นตัวเลขเท่านั้น';
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
                            side: BorderSide(color: Colors.grey.shade700),
                          ),
                          title: Text(isEnglish
                              ? 'Status: ${_isActive ? 'Active' : 'Inactive'}'
                              : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                          trailing: Switch(
                            value: _isActive,
                            onChanged: readOnly
                                ? null
                                : (bool value) {
                                    setState(() => _isActive = value);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Doc type + module
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _isDocType
                              ? (isEnglish ? 'Document Type' : 'ประเภทเอกสาร')
                              : (isEnglish ? 'Header' : 'หัวข้อ'),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Data Type' : 'ชนิดข้อมูล',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
                              child: Text(isEnglish ? 'Document Type' : 'ประเภทเอกสาร'),
                            ),
                            DropdownMenuItem(
                              value: isEnglish ? 'Header' : 'หัวข้อ',
                              child: Text(isEnglish ? 'Header' : 'หัวข้อ'),
                            ),
                          ],
                          onChanged: readOnly
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _isDocType = isEnglish
                                          ? value == 'Document Type'
                                          : value == 'ประเภทเอกสาร';
                                    });
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sysModule,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Module' : 'โมดูล',
                            border: const OutlineInputBorder(),
                          ),
                          items: sysModules.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text('${entry.key} - ${entry.value}'),
                            );
                          }).toList(),
                          onChanged: readOnly
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _sysModule = value;
                                      _sysDocTypes = getSysDocType(_sysModule);
                                      _sysDocType = '';
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Doc-type-specific fields
                  if (_isDocType) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sysDocTypes.containsKey(_sysDocType)
                                ? _sysDocType
                                : '',
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _sysDocTypes.isNotEmpty
                                  ? (isEnglish
                                      ? 'Main Doc Type of ${sysModules[_sysModule]}'
                                      : 'ประเภทเอกสารหลักของ ${sysModules[_sysModule]}')
                                  : (isEnglish ? 'Main Document Type' : 'ประเภทเอกสารหลัก'),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: '',
                                  child: Text(isEnglish ? '- None -' : '- ไม่ระบุ -')),
                              ..._sysDocTypes.entries.map((entry) {
                                return DropdownMenuItem(
                                  value: entry.key,
                                  child: Text('${entry.key} - ${entry.value}'),
                                );
                              }),
                            ],
                            onChanged: readOnly
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() {
                                        _sysDocType = value;
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
                              side: BorderSide(color: Colors.grey.shade700),
                            ),
                            title: Text(isEnglish
                                ? 'Auto Document No: ${_isAutoNumbering ? 'Yes' : 'No'}'
                                : 'เลขที่เอกสารอัตโนมัติ: ${_isAutoNumbering ? 'ใช่' : 'ไม่'}'),
                            trailing: Switch(
                              value: _isAutoNumbering,
                              onChanged: readOnly
                                  ? null
                                  : (bool value) {
                                      setState(
                                          () => _isAutoNumbering = value);
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Auto-numbering fields
                    if (_isAutoNumbering) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              readOnly: readOnly,
                              controller: _formatPrefixController,
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Prefix' : 'คำนำหน้า',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return isEnglish ? 'Please enter a prefix' : 'กรุณาป้อนคำนำหน้า';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {
                                  _sampleDocNoController.text = generateDocNo();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _formatSuffixDate,
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Date Suffix (YYYYMMDD)' : 'คำต่อ(ปีเดือนวัน)',
                                border: const OutlineInputBorder(),
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
                              onChanged: readOnly
                                  ? null
                                  : (value) {
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
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Separator' : 'อักษรคั่น',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _sampleDocNoController.text = generateDocNo();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: _runningLength,
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Number Length' : 'ความยาวเลขที่',
                                border: const OutlineInputBorder(),
                              ),
                              items: [3, 4, 5, 6, 7, 8, 9].map((val) {
                                return DropdownMenuItem(
                                  value: val,
                                  child: Text(val.toString()),
                                );
                              }).toList(),
                              onChanged: readOnly
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() {
                                          _runningLength = value;
                                          final cur =
                                              _nextRunningNumberController.text;
                                          if (cur.length < _runningLength) {
                                            _nextRunningNumberController =
                                                TextEditingController(
                                                    text: cur.padLeft(
                                                        _runningLength, '0'));
                                          } else {
                                            _nextRunningNumberController =
                                                TextEditingController(
                                                    text: cur.substring(
                                                        cur.length -
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
                              controller: _nextRunningNumberController,
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Next Number' : 'เลขที่ถัดไป',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return isEnglish ? 'Please enter the next auto number' : 'กรุณาป้อนเลขที่อัตโนมัติถัดไป';
                                }
                                if (int.tryParse(value) == null ||
                                    int.tryParse(value)! <= 0) {
                                  return isEnglish ? 'Must be a number greater than zero' : 'ต้องเป็นตัวเลขมากกว่าศูนย์เท่านั้น';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {
                                  _sampleDocNoController.text = generateDocNo();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Sample doc no
                      TextFormField(
                        controller: _sampleDocNoController,
                        enabled: false,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Sample Auto Document No.' : 'ตัวอย่างเลขที่เอกสารอัตโนมัติ',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
