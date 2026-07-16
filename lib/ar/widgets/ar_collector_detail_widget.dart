// lib/ar/widgets/ar_collector_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/ar_collector.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../sa/services/sa_language_provider.dart';

class ArCollectorDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCollector? selected;
  final Function(ArCollector) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ArCollectorDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ArCollectorDetailWidget> createState() =>
      ArCollectorDetailWidgetState();
}

class ArCollectorDetailWidgetState extends State<ArCollectorDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThaCtrl;
  late TextEditingController _nameEngCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;

  String _collectorType = 'EMPLOYEE';
  int? _branchId;
  String? _branchNameThai;
  DateTime? _effectiveDateFrom;
  DateTime? _effectiveDateTo;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _init(widget.selected);
  }

  void _init(ArCollector? d) {
    _codeCtrl = TextEditingController(text: d?.collectorCode ?? '');
    _nameThaCtrl = TextEditingController(text: d?.collectorNameThai ?? '');
    _nameEngCtrl = TextEditingController(text: d?.collectorNameEng ?? '');
    _taxIdCtrl = TextEditingController(text: d?.taxId ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _collectorType = d?.collectorType ?? 'EMPLOYEE';
    _branchId = d?.branchId;
    _branchNameThai = d?.branchNameThai;
    _effectiveDateFrom = d?.effectiveDateFrom;
    _effectiveDateTo = d?.effectiveDateTo;
    _isActive = d?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant ArCollectorDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        (widget.mode == Mode.add && oldWidget.mode != Mode.add)) {
      _codeCtrl.text = widget.selected?.collectorCode ?? '';
      _nameThaCtrl.text = widget.selected?.collectorNameThai ?? '';
      _nameEngCtrl.text = widget.selected?.collectorNameEng ?? '';
      _taxIdCtrl.text = widget.selected?.taxId ?? '';
      _phoneCtrl.text = widget.selected?.phone ?? '';
      _emailCtrl.text = widget.selected?.email ?? '';
      _addressCtrl.text = widget.selected?.address ?? '';
      _collectorType = widget.selected?.collectorType ?? 'EMPLOYEE';
      _branchId = widget.selected?.branchId;
      _branchNameThai = widget.selected?.branchNameThai;
      _effectiveDateFrom = widget.selected?.effectiveDateFrom;
      _effectiveDateTo = widget.selected?.effectiveDateTo;
      _isActive = widget.selected?.isActive ?? true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThaCtrl.dispose();
    _nameEngCtrl.dispose();
    _taxIdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_effectiveDateFrom ?? DateTime.now())
        : (_effectiveDateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _effectiveDateFrom = picked;
        } else {
          _effectiveDateTo = picked;
        }
      });
    }
  }

  Future<void> _pickBranch(bool isEnglish) async {
    final List<Branch> all;
    try {
      all = await Provider.of<BranchService>(context, listen: false).fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish
                ? 'Failed to load branches: $e'
                : 'โหลดข้อมูลสาขาล้มเหลว: $e')));
      }
      return;
    }
    final choices = all
        .where((b) => b.isActive)
        .toList()
      ..sort((a, b) => a.branchCode.compareTo(b.branchCode));

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Select Branch' : 'เลือกสาขา',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: choices.isEmpty
              ? Center(child: Text(isEnglish ? 'No branches found' : 'ไม่พบข้อมูลสาขา'))
              : ListView.builder(
                  itemCount: choices.length,
                  itemBuilder: (_, i) {
                    final b = choices[i];
                    final displayName = isEnglish && b.branchNameEng.isNotEmpty
                        ? b.branchNameEng
                        : b.branchNameThai;
                    return ListTile(
                      title: Text('${b.branchCode} — $displayName'),
                      onTap: () {
                        setState(() {
                          _branchId = b.id;
                          _branchNameThai = b.branchNameThai;
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isEnglish ? 'Cancel' : 'ยกเลิก',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ArCollector(
        id: widget.selected?.id,
        collectorCode: _codeCtrl.text.trim().toUpperCase(),
        collectorNameThai: _nameThaCtrl.text.trim(),
        collectorNameEng: _nameEngCtrl.text.trim().isEmpty
            ? null
            : _nameEngCtrl.text.trim(),
        collectorType: _collectorType,
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        branchId: _branchId,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        effectiveDateFrom: _effectiveDateFrom,
        effectiveDateTo: _effectiveDateTo,
        isActive: _isActive,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    if (widget.isPlaceholder) {
      return Center(
          child: Text(isEnglish
              ? 'Select a collector to edit or press + to add new'
              : 'เลือกผู้วางบิล/รับชำระเพื่อแก้ไข หรือ กดปุ่ม + เพื่อเพิ่มใหม่'));
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
                  ? (isEnglish ? 'View Collector' : 'ดูข้อมูลผู้วางบิล/รับชำระ')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Collector' : 'แก้ไขผู้วางบิล/รับชำระ')
                      : (isEnglish ? 'Add Collector' : 'เพิ่มผู้วางบิล/รับชำระ'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _codeCtrl,
              readOnly: widget.mode != Mode.add,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: isEnglish ? 'Code *' : 'รหัส *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isEnglish ? 'Please enter code' : 'โปรดระบุรหัส')
                  : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameThaCtrl,
                    readOnly: ro,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Name (TH) *' : 'ชื่อ (ไทย) *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEnglish ? 'Please enter Thai name' : 'โปรดระบุชื่อภาษาไทย')
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _nameEngCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'Name (EN)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _collectorType,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Type *' : 'ประเภท *',
                      border: const OutlineInputBorder(),
                    ),
                    items: arCollectorTypeOptions.keys
                        .map((k) => DropdownMenuItem(
                            value: k, child: Text(arCollectorTypeLabel(k, isEnglish))))
                        .toList(),
                    onChanged: ro
                        ? null
                        : (v) => setState(() => _collectorType = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _taxIdCtrl,
                    readOnly: ro,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Tax ID / National ID' : 'เลขภาษี/เลขบัตรประชาชน',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : () => _pickBranch(isEnglish),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Branch' : 'สาขา',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_branchId != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _branchId = null;
                                  _branchNameThai = null;
                                }),
                              ),
                            const Icon(Icons.search),
                          ],
                        ),
                      ),
                      child: Text(_branchId == null
                          ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —')
                          : _branchNameThai ?? ''),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    readOnly: ro,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Phone' : 'โทรศัพท์',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    readOnly: ro,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Email' : 'อีเมล',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressCtrl,
              readOnly: ro,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Address' : 'ที่อยู่',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : () => _pickDate(true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Start Date' : 'วันที่เริ่มงาน',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_effectiveDateFrom != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _effectiveDateFrom = null),
                              ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                      child: Text(_formatDate(_effectiveDateFrom)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : () => _pickDate(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'End Date' : 'วันที่สิ้นสุด',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_effectiveDateTo != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _effectiveDateTo = null),
                              ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                      child: Text(_formatDate(_effectiveDateTo)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                    child: Text(isEnglish
                        ? 'Status: ${_isActive ? 'Active' : 'Inactive'}'
                        : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                Switch(
                  value: _isActive,
                  onChanged:
                      ro ? null : (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                          ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                          : widget.mode == Mode.edit
                              ? (isEnglish ? 'Save' : 'บันทึก')
                              : (isEnglish ? 'Add' : 'เพิ่ม')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
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
                    label: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
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
