// lib/sa/widgets/sa_module_document_detail_widget.dart

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/sa_module_document.dart';
import '../models/sa_module_approver.dart';
import '../models/sa_user.dart';
import '../services/sa_language_provider.dart';
import '../services/sa_module_approver_service.dart';
import '../services/sa_user_service.dart';

// ── Local helper ──────────────────────────────────────────────────────────────

class _ApproverRow {
  int? id;
  TextEditingController levelCtrl;
  int userId;
  String userDisplayName;
  bool isActive;
  String? signatureImage;

  _ApproverRow({
    this.id,
    required String level,
    this.userId = 0,
    this.userDisplayName = '',
    this.isActive = true,
    this.signatureImage,
  }) : levelCtrl = TextEditingController(text: level);

  void dispose() => levelCtrl.dispose();
}

// ── Widget ────────────────────────────────────────────────────────────────────

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
  bool _isSaving = false;
  late TextEditingController _sampleDocNoController;

  // Approver state
  final _approverSvc = SaModuleApproverService();
  final _userSvc = UserService();
  List<_ApproverRow> _approverRows = [];
  Set<int> _originalApproverIds = {};
  List<User> _users = [];
  bool _approverSectionExpanded = false;
  bool _approversLoading = false;
  String _approverLoadedKey = '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _syncStateFromSelected();
    _initControllers();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeLoadApprovers());
  }

  @override
  void didUpdateWidget(covariant ModuleDocumentDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _disposeControllers();
      _selected = widget.selected;
      _syncStateFromSelected();
      _initControllers();
      setState(() {});
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeLoadApprovers());
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
    _disposeApproverRows();
  }

  void _disposeApproverRows() {
    for (final r in _approverRows) {
      r.dispose();
    }
    _approverRows = [];
    _originalApproverIds = {};
    _approverLoadedKey = '';
  }

  // ── Approver load ─────────────────────────────────────────────────────────

  void _maybeLoadApprovers() {
    if (!mounted) return;
    final canLoad = _isDocType &&
        _sysModule.isNotEmpty &&
        _sysDocType.isNotEmpty &&
        (widget.mode == Mode.edit || widget.mode == Mode.view);
    if (!canLoad) return;
    final key = '${_sysModule}_${_sysDocType}_${_selected?.id ?? 0}';
    if (key == _approverLoadedKey) return;
    _loadApprovers(key);
  }

  Future<void> _loadApprovers(String key) async {
    if (!mounted) return;
    setState(() => _approversLoading = true);
    try {
      final approvers = await _approverSvc.fetchRows(
          moduleCode: _sysModule, docCategory: _sysDocType);
      if (!mounted) return;
      final newRows = approvers
          .map((a) => _ApproverRow(
                id: a.id,
                level: a.approvalLevel.toString(),
                userId: a.approverUserId,
                userDisplayName: _buildUserDisplay(
                    a.approverUsername, a.approverFirstName, a.approverLastName),
                isActive: a.isActive,
                signatureImage: a.signatureImage,
              ))
          .toList();
      final newOriginalIds =
          approvers.where((a) => a.id != null).map((a) => a.id!).toSet();
      setState(() {
        for (final r in _approverRows) {
          r.dispose();
        }
        _approverRows = newRows;
        _originalApproverIds = newOriginalIds;
        _approverLoadedKey = key;
        _approversLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _approversLoading = false);
    }
  }

  String _buildUserDisplay(
      String? username, String? firstName, String? lastName) {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (username == null && name.isEmpty) return '';
    if (name.isEmpty) return username ?? '';
    if (username == null) return name;
    return '$username - $name';
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Snapshot approver data synchronously BEFORE any await to avoid
    // race condition where didUpdateWidget clears state mid-save
    final shouldSaveApprovers = _isDocType &&
        _sysModule.isNotEmpty &&
        _sysDocType.isNotEmpty &&
        widget.mode == Mode.edit;
    final approverModule = _sysModule;
    final approverDocType = _sysDocType;
    final approverOriginalIds = Set<int>.from(_originalApproverIds);
    final approverSnapshots = _approverRows
        .map((r) => {
              'id': r.id,
              'approval_level': int.tryParse(r.levelCtrl.text) ?? 1,
              'approver_user_id': r.userId,
              'signature_image': r.signatureImage,
              'is_active': r.isActive,
            })
        .toList();

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

      if (shouldSaveApprovers) {
        await _saveApproversFromSnapshot(
            approverModule, approverDocType, approverOriginalIds, approverSnapshots);
      }
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

  Future<void> _saveApproversFromSnapshot(
    String moduleCode,
    String docCategory,
    Set<int> originalIds,
    List<Map<String, dynamic>> snapshots,
  ) async {
    final currentIds = snapshots
        .where((s) => s['id'] != null)
        .map<int>((s) => s['id'] as int)
        .toSet();
    for (final id in originalIds) {
      if (!currentIds.contains(id)) await _approverSvc.deleteRow(id);
    }
    for (final s in snapshots) {
      final approver = SaModuleApprover(
        id: s['id'] as int?,
        moduleCode: moduleCode,
        docCategory: docCategory,
        approvalLevel: s['approval_level'] as int,
        approverUserId: s['approver_user_id'] as int,
        signatureImage: s['signature_image'] as String?,
        isActive: s['is_active'] as bool,
      );
      if (approver.id != null) {
        await _approverSvc.updateRow(approver);
      } else {
        await _approverSvc.addRow(approver);
      }
    }
  }

  // ── Approver row actions ──────────────────────────────────────────────────

  void _addApproverRow() {
    final nextLevel = _approverRows.isEmpty
        ? 1
        : (_approverRows
                .map((r) => int.tryParse(r.levelCtrl.text) ?? 0)
                .reduce((a, b) => a > b ? a : b) +
            1);
    setState(
        () => _approverRows.add(_ApproverRow(level: nextLevel.toString())));
  }

  void _removeApproverRow(int index) {
    setState(() {
      _approverRows[index].dispose();
      _approverRows.removeAt(index);
    });
  }

  Future<void> _pickUser(_ApproverRow row) async {
    if (_users.isEmpty) {
      try {
        final users = await _userSvc.fetchUsers();
        if (mounted) setState(() => _users = users);
      } catch (_) {}
    }
    if (!mounted) return;
    final user = await showDialog<User>(
      context: context,
      builder: (ctx) => _UserPickerDialog(users: _users),
    );
    if (user != null && mounted) {
      setState(() {
        row.userId = user.id;
        row.userDisplayName =
            _buildUserDisplay(user.userName, user.firstName, user.lastName);
      });
    }
  }

  void _uploadSignature(_ApproverRow row) {
    if (!kIsWeb) return;
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    input.onChange.listen((e) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoad.listen((_) {
        if (mounted) {
          setState(() => row.signatureImage = reader.result as String);
        }
      });
    });
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

    final bool showApprovers = _isDocType &&
        _sysModule.isNotEmpty &&
        _sysDocType.isNotEmpty &&
        (widget.mode == Mode.edit || widget.mode == Mode.view);

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
                                      _disposeApproverRows();
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
                                        _disposeApproverRows();
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                              (_) => _maybeLoadApprovers());
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

                  // ── Approver section ─────────────────────────────────────
                  if (showApprovers) ...[
                    const SizedBox(height: 8),
                    _buildApproverSection(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Approver section ──────────────────────────────────────────────────────

  Widget _buildApproverSection() {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(
              () => _approverSectionExpanded = !_approverSectionExpanded),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade50,
              border: Border.all(color: Colors.deepOrange.shade200),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _approverSectionExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.deepOrange[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEnglish ? 'Approvers' : 'ผู้อนุมัติ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange[800]),
                ),
                if (_approversLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ],
                const Spacer(),
                if (widget.mode == Mode.edit)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: Colors.deepOrange[700], size: 22),
                    tooltip: isEnglish ? 'Add Approver' : 'เพิ่มผู้อนุมัติ',
                    onPressed: _addApproverRow,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
        if (_approverSectionExpanded)
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.deepOrange.shade200),
                right: BorderSide(color: Colors.deepOrange.shade200),
                bottom: BorderSide(color: Colors.deepOrange.shade200),
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
            child: _approverRows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      isEnglish ? 'No approvers yet' : 'ยังไม่มีผู้อนุมัติ',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < _approverRows.length; i++)
                        _buildApproverRow(_approverRows[i], i, isEnglish),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildApproverRow(_ApproverRow row, int index, bool isEnglish) {
    final readOnly = widget.mode == Mode.view;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Line 1: level | user | status | delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Level
              Flexible(
                flex: 1,
                child: TextFormField(
                  controller: row.levelCtrl,
                  readOnly: readOnly,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Level' : 'ลำดับ',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // User picker
              Flexible(
                flex: 5,
                child: InkWell(
                  onTap: readOnly ? null : () => _pickUser(row),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: readOnly
                              ? Colors.grey.shade400
                              : Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.userDisplayName.isEmpty
                                ? (isEnglish ? '- Select Approver -' : '- เลือกผู้อนุมัติ -')
                                : row.userDisplayName,
                            style: TextStyle(
                                color: row.userDisplayName.isEmpty
                                    ? Colors.grey
                                    : null,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!readOnly)
                          const Icon(Icons.search,
                              size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status switch
              Flexible(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEnglish
                            ? (row.isActive ? 'Active' : 'Inactive')
                            : (row.isActive ? 'ใช้งาน' : 'หยุดใช้'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Switch(
                      value: row.isActive,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => row.isActive = v),
                    ),
                  ],
                ),
              ),
              // Delete
              if (!readOnly)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  tooltip: isEnglish ? 'Remove Approver' : 'ลบผู้อนุมัติ',
                  onPressed: () => _removeApproverRow(index),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          // Line 2: signature
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (row.signatureImage != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildSignatureImage(row.signatureImage!),
                ),
              if (!readOnly)
                TextButton.icon(
                  icon: const Icon(Icons.upload, size: 16),
                  label: Text(
                    row.signatureImage == null
                        ? (isEnglish ? 'Upload Signature' : 'อัปโหลดลายเซ็น')
                        : (isEnglish ? 'Change Signature' : 'เปลี่ยนลายเซ็น'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _uploadSignature(row),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String dataUrl) {
    try {
      final data =
          dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      return Image.memory(base64Decode(data),
          height: 60, fit: BoxFit.contain);
    } catch (_) {
      return const Text('ไม่สามารถแสดงรูปได้',
          style: TextStyle(color: Colors.red, fontSize: 11));
    }
  }
}

// ── User picker dialog ────────────────────────────────────────────────────────

class _UserPickerDialog extends StatefulWidget {
  final List<User> users;
  const _UserPickerDialog({required this.users});

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final filtered = widget.users.where((u) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return u.userName.toLowerCase().contains(q) ||
          (u.firstName?.toLowerCase().contains(q) ?? false) ||
          (u.lastName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          children: [
            Container(
              color: Colors.blueGrey[700],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.person_search,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEnglish ? 'Select Approver' : 'เลือกผู้อนุมัติ',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Search' : 'ค้นหา',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        isEnglish ? 'No users found' : 'ไม่พบผู้ใช้',
                        style: const TextStyle(color: Colors.grey),
                      ))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        final name =
                            '${u.firstName ?? ''} ${u.lastName ?? ''}'
                                .trim();
                        return ListTile(
                          dense: true,
                          title: Text(u.userName),
                          subtitle:
                              name.isNotEmpty ? Text(name) : null,
                          onTap: () => Navigator.of(context).pop(u),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
