// lib/cd/widgets/bank_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../models/bank.dart';
import '../models/bank_branch.dart';
import '../services/bank_branch_service.dart';

class BankDetailWidget extends StatefulWidget {
  final Mode mode;
  final Bank? selected;
  final Function(Bank) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const BankDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<BankDetailWidget> createState() => BankDetailWidgetState();
}

class BankDetailWidgetState extends State<BankDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bankCodeCtrl;
  late TextEditingController _bankNameThaiCtrl;
  late TextEditingController _bankNameEngCtrl;
  late TextEditingController _shortNameCtrl;
  late TextEditingController _swiftCodeCtrl;
  late bool _isActive;
  bool _isSaving = false;

  // Branch management
  List<BankBranch> _branches = [];
  bool _branchLoading = false;

  @override
  void initState() {
    super.initState();
    _initFields();
    if (widget.selected != null) _loadBranches();
  }

  void _initFields() {
    _bankCodeCtrl =
        TextEditingController(text: widget.selected?.bankCode ?? '');
    _bankNameThaiCtrl =
        TextEditingController(text: widget.selected?.bankNameThai ?? '');
    _bankNameEngCtrl =
        TextEditingController(text: widget.selected?.bankNameEng ?? '');
    _shortNameCtrl =
        TextEditingController(text: widget.selected?.shortName ?? '');
    _swiftCodeCtrl =
        TextEditingController(text: widget.selected?.swiftCode ?? '');
    _isActive = widget.selected?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant BankDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _bankCodeCtrl.text = widget.selected?.bankCode ?? '';
      _bankNameThaiCtrl.text = widget.selected?.bankNameThai ?? '';
      _bankNameEngCtrl.text = widget.selected?.bankNameEng ?? '';
      _shortNameCtrl.text = widget.selected?.shortName ?? '';
      _swiftCodeCtrl.text = widget.selected?.swiftCode ?? '';
      _isActive = widget.selected?.isActive ?? true;
      _branches = [];
      if (widget.selected != null) _loadBranches();
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _bankCodeCtrl.clear();
      _bankNameThaiCtrl.clear();
      _bankNameEngCtrl.clear();
      _shortNameCtrl.clear();
      _swiftCodeCtrl.clear();
      _isActive = true;
      _branches = [];
    }
  }

  @override
  void dispose() {
    _bankCodeCtrl.dispose();
    _bankNameThaiCtrl.dispose();
    _bankNameEngCtrl.dispose();
    _shortNameCtrl.dispose();
    _swiftCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    if (widget.selected?.id == null) return;
    if (!mounted) return;
    final service = Provider.of<BankBranchService>(context, listen: false);
    if (!mounted) return;
    setState(() => _branchLoading = true);
    try {
      final list = await service.fetchRows(bankId: widget.selected!.id);
      if (!mounted) return;
      setState(() {
        _branches = list;
        _branchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _branchLoading = false);
    }
  }

  void refreshBranches() => _loadBranches();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(Bank(
        id: widget.selected?.id,
        bankCode: _bankCodeCtrl.text.trim().toUpperCase(),
        bankNameThai: _bankNameThaiCtrl.text.trim(),
        bankNameEng: _bankNameEngCtrl.text.trim(),
        shortName: _shortNameCtrl.text.trim().isEmpty
            ? null
            : _shortNameCtrl.text.trim(),
        swiftCode: _swiftCodeCtrl.text.trim().isEmpty
            ? null
            : _swiftCodeCtrl.text.trim().toUpperCase(),
        isActive: _isActive,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showBranchDialog({BankBranch? existing}) async {
    final bankId = widget.selected?.id;
    if (bankId == null) return;
    // Capture service & messenger before any await
    final service = Provider.of<BankBranchService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    // Use a dedicated StatefulWidget dialog — avoids GlobalKey<FormState>
    // being created in an async closure, which can trigger _dependents.isEmpty
    final branch = await showDialog<BankBranch>(
      context: context,
      builder: (ctx) => _BranchDialog(
        bankId: bankId,
        existing: existing,
      ),
    );

    if (branch == null) return;
    if (!mounted) return;

    try {
      if (existing == null) {
        await service.addRow(branch);
      } else {
        await service.updateRow(branch);
      }
      if (!mounted) return;
      await _loadBranches();
      messenger.showSnackBar(
        const SnackBar(content: Text('บันทึกสาขาสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('บันทึกสาขาล้มเหลว: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteBranch(BankBranch branch) async {
    // Capture service & messenger before any await
    final service = Provider.of<BankBranchService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบสาขา "${branch.branchName}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await service.deleteRow(branch.id!);
      if (!mounted) return;
      await _loadBranches();
      messenger.showSnackBar(const SnackBar(content: Text('ลบสาขาสำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('ลบสาขาล้มเหลว: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text('เลือกธนาคารเพื่อแก้ไข หรือกดปุ่ม + เพื่อเพิ่มธนาคารใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;
    final bool showBranches =
        widget.selected != null || widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Row 1: รหัสธนาคาร + ชื่อย่อ
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        readOnly: readOnly || widget.mode == Mode.edit,
                        controller: _bankCodeCtrl,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'รหัสธนาคาร *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'โปรดระบุรหัสธนาคาร'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        readOnly: readOnly,
                        controller: _shortNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อย่อ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        readOnly: readOnly,
                        controller: _swiftCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SWIFT Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2: ชื่อไทย + ชื่ออังกฤษ
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: readOnly,
                        controller: _bankNameThaiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อธนาคาร (ไทย) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'โปรดระบุชื่อธนาคาร'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        readOnly: readOnly,
                        controller: _bankNameEngCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อธนาคาร (อังกฤษ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // สถานะ
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                    Switch(
                      value: _isActive,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Buttons
                if (!readOnly)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submitForm,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_isSaving
                              ? 'กำลังบันทึก...'
                              : widget.mode == Mode.edit
                                  ? 'บันทึก'
                                  : 'เพิ่ม'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onCancel,
                          icon: const Icon(Icons.cancel),
                          label: const Text('ยกเลิก'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (readOnly)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ปิด'),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Branch Section ───────────────────────────
          if (showBranches) ...[
            const Divider(height: 32),
            Row(
              children: [
                const Icon(Icons.account_balance, size: 18,
                    color: Colors.blueGrey),
                const SizedBox(width: 6),
                Text(
                  'สาขาธนาคาร',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!readOnly)
                  TextButton.icon(
                    onPressed: () => _showBranchDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('เพิ่มสาขา'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_branchLoading)
              const Center(child: CircularProgressIndicator())
            else if (_branches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('ยังไม่มีข้อมูลสาขา')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _branches.length,
                itemBuilder: (context, index) {
                  final b = _branches[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        b.branchName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: b.isActive ? null : Colors.grey,
                        ),
                      ),
                      subtitle: [
                        if (b.branchCode != null) 'รหัส: ${b.branchCode}',
                        if (b.branchAddress != null) b.branchAddress!,
                      ].isNotEmpty
                          ? Text([
                              if (b.branchCode != null)
                                'รหัส: ${b.branchCode}',
                              if (b.branchAddress != null) b.branchAddress!,
                            ].join('  '))
                          : null,
                      trailing: readOnly
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!b.isActive)
                                  const Chip(
                                    label: Text('หยุดใช้',
                                        style: TextStyle(fontSize: 10)),
                                    backgroundColor: Color(0xFFEEEEEE),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 18, color: Colors.blue),
                                  onPressed: () =>
                                      _showBranchDialog(existing: b),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  onPressed: () => _deleteBranch(b),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dedicated StatefulWidget for add/edit branch dialog.
// Using a real StatefulWidget (instead of StatefulBuilder + local GlobalKey)
// avoids the _dependents.isEmpty assertion that fires when a GlobalKey<FormState>
// created inside an async method races with the dialog's exit animation.
// ─────────────────────────────────────────────────────────────────────────────

class _BranchDialog extends StatefulWidget {
  final int bankId;
  final BankBranch? existing;

  const _BranchDialog({required this.bankId, this.existing});

  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.existing?.branchCode ?? '');
    _nameCtrl = TextEditingController(text: widget.existing?.branchName ?? '');
    _addressCtrl =
        TextEditingController(text: widget.existing?.branchAddress ?? '');
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(BankBranch(
      id: widget.existing?.id,
      bankId: widget.bankId,
      branchCode:
          _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      branchName: _nameCtrl.text.trim(),
      branchAddress: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      isActive: _isActive,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'เพิ่มสาขา' : 'แก้ไขสาขา'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'รหัสสาขา',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'ชื่อสาขา *',
                      border: OutlineInputBorder()),
                  autofocus: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'โปรดระบุชื่อสาขา'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                      labelText: 'ที่อยู่สาขา',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _submit,
          child: const Text('บันทึก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก',
              style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
