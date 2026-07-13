// lib/cd/widgets/cd_wht_type_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../models/cd_wht_type.dart';

class CdWhtTypeDetailWidget extends StatefulWidget {
  final Mode mode;
  final CdWhtType? selected;
  final Function(CdWhtType) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const CdWhtTypeDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<CdWhtTypeDetailWidget> createState() => CdWhtTypeDetailWidgetState();
}

class CdWhtTypeDetailWidgetState extends State<CdWhtTypeDetailWidget> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _descCtrl;
  String?   _incomeType;
  int?      _glAccountId;
  String?   _glAccountCode;
  String?   _glAccountName;
  DateTime? _effectiveDate;
  DateTime? _endDate;
  bool      _isActive = true;
  bool      _isSaving = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _initFields(widget.selected);
  }

  void _initFields(CdWhtType? row) {
    _codeCtrl     = TextEditingController(text: row?.whtCode ?? '');
    _nameCtrl     = TextEditingController(text: row?.whtName ?? '');
    _rateCtrl     = TextEditingController(text: row != null ? row.whtRate.toString() : '');
    _descCtrl     = TextEditingController(text: row?.description ?? '');
    _incomeType   = row?.incomeType;
    _glAccountId   = row?.glAccountId;
    _glAccountCode = row?.glAccountCode;
    _glAccountName = row?.glAccountName;
    _effectiveDate = row?.effectiveDate;
    _endDate       = row?.endDate;
    _isActive      = row?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant CdWhtTypeDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      _disposeControllers();
      _initFields(widget.selected);
      setState(() {});
    } else if (widget.mode == Mode.add && old.mode != Mode.add) {
      _disposeControllers();
      _initFields(null);
      setState(() {});
    }
  }

  void _disposeControllers() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    _descCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate(bool isEffective) async {
    final initial = isEffective
        ? (_effectiveDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isEffective) {
          _effectiveDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ── Account picker ────────────────────────────────────────────────────────
  Future<void> _pickAccount() async {
    final svc = Provider.of<AccountService>(context, listen: false);
    List<Account> accounts = [];
    try {
      final all = await svc.fetchRows();
      accounts = all.where((a) => a.isActive).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    } catch (_) {}
    if (!mounted) return;

    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(accounts);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            final lq = q.toLowerCase();
            filtered = q.isEmpty
                ? List.from(accounts)
                : accounts.where((a) =>
                    a.accountCode.toLowerCase().contains(lq) ||
                    a.accountNameThai.toLowerCase().contains(lq)).toList();
          });
        }

        return AlertDialog(
          title: const Text('เลือกบัญชีภาษีหัก ณ ที่จ่ายจาก GL'),
          content: SizedBox(
            width: 520, height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text('${a.accountCode}  ${a.accountNameThai}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _glAccountId   = a.id;
                          _glAccountCode = a.accountCode;
                          _glAccountName = a.accountNameThai;
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = CdWhtType(
        id:            widget.selected?.id,
        whtCode:       _codeCtrl.text.toUpperCase().trim(),
        whtName:       _nameCtrl.text.trim(),
        incomeType:    _incomeType,
        whtRate:       double.tryParse(_rateCtrl.text) ?? 0,
        glAccountId:   _glAccountId,
        description:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isActive:      _isActive,
        effectiveDate: _effectiveDate,
        endDate:       _endDate,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
          child: Text('เลือกรายการเพื่อแก้ไข หรือกดปุ่ม + เพื่อเพิ่มใหม่'));
    }

    final ro = widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            ro ? 'ดูข้อมูล' : widget.mode == Mode.edit ? 'แก้ไขข้อมูล' : 'เพิ่มข้อมูลใหม่',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // รหัส WHT + อัตรา
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _codeCtrl,
                readOnly: ro,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]'))],
                decoration: const InputDecoration(
                  labelText: 'รหัสภาษีหัก ณ ที่จ่าย *',
                  border: OutlineInputBorder(),
                  hintText: 'เช่น WHT3, WHT5',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัส' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _rateCtrl,
                readOnly: ro,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'อัตรา (%) *',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'โปรดระบุอัตรา';
                  if (double.tryParse(v) == null) return 'ตัวเลขไม่ถูกต้อง';
                  return null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ชื่อ WHT
          TextFormField(
            controller: _nameCtrl,
            readOnly: ro,
            decoration: const InputDecoration(
              labelText: 'ชื่อ *',
              border: OutlineInputBorder(),
              hintText: 'เช่น ค่าบริการ 3%, เงินปันผล 10%',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'โปรดระบุชื่อ' : null,
          ),
          const SizedBox(height: 12),

          // ประเภทเงินได้
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _incomeType,
            decoration: const InputDecoration(
              labelText: 'ประเภทเงินได้ (มาตรา)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— ไม่ระบุ —')),
              ...whtIncomeTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))),
            ],
            onChanged: ro ? null : (v) => setState(() => _incomeType = v),
          ),
          const SizedBox(height: 12),

          // บัญชี GL
          InkWell(
            onTap: ro ? null : _pickAccount,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'บัญชี GL (ภาษีหัก ณ ที่จ่าย)',
                border: const OutlineInputBorder(),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_glAccountId != null && !ro)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _glAccountId = null; _glAccountCode = null; _glAccountName = null;
                      }),
                    ),
                  const Icon(Icons.account_tree_outlined, size: 18),
                ]),
              ),
              child: Text(
                _glAccountId != null ? '$_glAccountCode  $_glAccountName' : '— ไม่ระบุ —',
                style: TextStyle(color: _glAccountId != null ? null : Colors.grey.shade600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // วันที่มีผลบังคับใช้ + วันที่สิ้นสุด
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: InkWell(
                onTap: ro ? null : () => _pickDate(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'วันที่มีผลบังคับใช้',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    _effectiveDate != null
                        ? _dateFmt.format(_effectiveDate!)
                        : 'ไม่ระบุ',
                    style: TextStyle(
                        color: _effectiveDate != null ? null : Colors.grey.shade600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: ro ? null : () => _pickDate(false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'วันที่สิ้นสุด (ว่าง = ปัจจุบัน)',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_endDate != null && !ro)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _endDate = null),
                        ),
                      const Icon(Icons.calendar_today, size: 18),
                    ]),
                  ),
                  child: Text(
                    _endDate != null ? _dateFmt.format(_endDate!) : 'ปัจจุบัน',
                    style: TextStyle(
                        color: _endDate != null ? null : Colors.grey.shade600),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // หมายเหตุ
          TextFormField(
            controller: _descCtrl,
            readOnly: ro,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'หมายเหตุ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // สถานะ
          Row(children: [
            Expanded(child: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
            Switch(
              value: _isActive,
              onChanged: ro ? null : (v) => setState(() => _isActive = v),
            ),
          ]),
          const SizedBox(height: 24),

          // Buttons
          Row(children: [
            if (widget.mode != Mode.view) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitForm,
                  icon: _isSaving
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'กำลังบันทึก...' : widget.mode == Mode.edit ? 'บันทึก' : 'เพิ่ม'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
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
          ]),
        ]),
      ),
    );
  }
}
