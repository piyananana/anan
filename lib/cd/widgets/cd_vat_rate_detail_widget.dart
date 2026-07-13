import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/cd_vat_rate.dart';

class VatRateDetailWidget extends StatefulWidget {
  final Mode mode;
  final VatRate? selected;
  final Function(VatRate) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const VatRateDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<VatRateDetailWidget> createState() => VatRateDetailWidgetState();
}

class VatRateDetailWidgetState extends State<VatRateDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vatCodeController;
  late TextEditingController _vatNameThController;
  late TextEditingController _vatNameEnController;
  late TextEditingController _rateController;
  late TextEditingController _remarkController;
  DateTime? _effectiveDate;
  DateTime? _endDate;
  late bool _isActive;
  int?    _glAccountId;
  String? _glAccountCode;
  String? _glAccountName;
  bool _isSaving = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _initFields(widget.selected);
  }

  void _initFields(VatRate? row) {
    _vatCodeController = TextEditingController(text: row?.vatCode ?? '');
    _vatNameThController = TextEditingController(text: row?.vatNameTh ?? '');
    _vatNameEnController = TextEditingController(text: row?.vatNameEn ?? '');
    _rateController =
        TextEditingController(text: row != null ? row.rate.toString() : '');
    _remarkController = TextEditingController(text: row?.remark ?? '');
    _effectiveDate = row?.effectiveDate;
    _endDate = row?.endDate;
    _isActive = row?.isActive ?? true;
    _glAccountId   = row?.glAccountId;
    _glAccountCode = row?.glAccountCode;
    _glAccountName = row?.glAccountName;
  }

  @override
  void didUpdateWidget(covariant VatRateDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _disposeControllers();
      _initFields(widget.selected);
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _disposeControllers();
      _initFields(null);
    }
  }

  void _disposeControllers() {
    _vatCodeController.dispose();
    _vatNameThController.dispose();
    _vatNameEnController.dispose();
    _rateController.dispose();
    _remarkController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

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
          title: const Text('เลือกบัญชีภาษีมูลค่าเพิ่มจาก GL'),
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_effectiveDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาระบุวันที่มีผลบังคับใช้')),
        );
        return;
      }
      setState(() => _isSaving = true);
      try {
        final row = VatRate(
          id: widget.selected?.id,
          vatCode: _vatCodeController.text.toUpperCase().trim(),
          vatNameTh: _vatNameThController.text.trim(),
          vatNameEn: _vatNameEnController.text.trim().isEmpty
              ? null
              : _vatNameEnController.text.trim(),
          rate: double.tryParse(_rateController.text) ?? 0.0,
          effectiveDate: _effectiveDate!,
          endDate: _endDate,
          isActive: _isActive,
          remark: _remarkController.text.trim().isEmpty
              ? null
              : _remarkController.text.trim(),
          glAccountId: _glAccountId,
        );
        await widget.onSubmit(row);
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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกอัตราภาษีเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มอัตราใหม่'),
      );
    }

    final readOnly = widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? 'ดูข้อมูลอัตราภาษี'
                  : widget.mode == Mode.edit
                      ? 'แก้ไขอัตราภาษี'
                      : 'เพิ่มอัตราภาษีใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // รหัส VAT + อัตรา %
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _vatCodeController,
                    readOnly: readOnly,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'รหัสภาษี (VAT Code) *',
                      border: OutlineInputBorder(),
                      hintText: 'เช่น VAT7, VAT0, EXEMPT',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัสภาษี' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    readOnly: readOnly,
                    textAlign: TextAlign.right,
                    // style: const TextStyle(
                    //     fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'อัตรา (%) *',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'โปรดระบุอัตรา';
                      if (double.tryParse(v) == null) return 'ตัวเลขไม่ถูกต้อง';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ชื่อภาษาไทย
            TextFormField(
              controller: _vatNameThController,
              readOnly: readOnly,
              decoration: const InputDecoration(
                labelText: 'ชื่อภาษี (ไทย) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'โปรดระบุชื่อภาษาไทย' : null,
            ),
            const SizedBox(height: 12),

            // ชื่อภาษาอังกฤษ
            TextFormField(
              controller: _vatNameEnController,
              readOnly: readOnly,
              decoration: const InputDecoration(
                labelText: 'ชื่อภาษี (อังกฤษ)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // วันที่มีผลบังคับใช้
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: readOnly ? null : () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันที่มีผลบังคับใช้ *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _effectiveDate != null
                            ? _dateFmt.format(_effectiveDate!)
                            : 'เลือกวันที่',
                        style: TextStyle(
                          color: _effectiveDate != null
                              ? null
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: readOnly ? null : () => _pickDate(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'วันสิ้นสุด (ว่าง = ปัจจุบัน)',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_endDate != null && !readOnly)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _endDate = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                      child: Text(
                        _endDate != null
                            ? _dateFmt.format(_endDate!)
                            : 'ปัจจุบัน',
                        style: TextStyle(
                          color: _endDate != null ? null : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // บัญชี GL (VAT)
            InkWell(
              onTap: readOnly ? null : _pickAccount,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'บัญชี GL (ภาษีมูลค่าเพิ่ม)',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_glAccountId != null && !readOnly)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() {
                          _glAccountId = null;
                          _glAccountCode = null;
                          _glAccountName = null;
                        }),
                      ),
                    const Icon(Icons.account_tree_outlined, size: 18),
                  ]),
                ),
                child: Text(
                  _glAccountId != null
                      ? '$_glAccountCode  $_glAccountName'
                      : '— ไม่ระบุ —',
                  style: TextStyle(
                      color: _glAccountId != null ? null : Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // หมายเหตุ
            TextFormField(
              controller: _remarkController,
              readOnly: readOnly,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // สถานะ
            Row(
              children: [
                Expanded(
                  child: Text(
                      'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: readOnly
                      ? null
                      : (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.mode != Mode.view)
                  Expanded(
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
                if (widget.mode != Mode.view) const SizedBox(width: 16),
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
