// widgets/ar_customer_group_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../models/ar_customer_group.dart';

class ArCustomerGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCustomerGroup? selected;
  final Function(ArCustomerGroup) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ArCustomerGroupDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ArCustomerGroupDetailWidget> createState() =>
      ArCustomerGroupDetailWidgetState();
}

class ArCustomerGroupDetailWidgetState
    extends State<ArCustomerGroupDetailWidget> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameThaController;
  late TextEditingController _nameEngController;
  late TextEditingController _descriptionController;
  late TextEditingController _creditDaysController;
  late TextEditingController _creditLimitController;
  late TextEditingController _discountPercentController;
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountNameThai;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromSelected(widget.selected);
  }

  void _initFromSelected(ArCustomerGroup? data) {
    _codeController = TextEditingController(text: data?.groupCode ?? '');
    _nameThaController =
        TextEditingController(text: data?.groupNameThai ?? '');
    _nameEngController =
        TextEditingController(text: data?.groupNameEng ?? '');
    _descriptionController =
        TextEditingController(text: data?.description ?? '');
    _creditDaysController =
        TextEditingController(text: data?.creditDays.toString() ?? '30');
    _creditLimitController =
        TextEditingController(text: data?.creditLimit.toStringAsFixed(2) ?? '0.00');
    _discountPercentController =
        TextEditingController(text: data?.discountPercent.toStringAsFixed(2) ?? '0.00');
    _glAccountId = data?.glAccountId;
    _glAccountCode = data?.glAccountCode;
    _glAccountNameThai = data?.glAccountNameThai;
    _isActive = data?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant ArCustomerGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _codeController.text = widget.selected?.groupCode ?? '';
      _nameThaController.text = widget.selected?.groupNameThai ?? '';
      _nameEngController.text = widget.selected?.groupNameEng ?? '';
      _descriptionController.text = widget.selected?.description ?? '';
      _creditDaysController.text =
          widget.selected?.creditDays.toString() ?? '30';
      _creditLimitController.text =
          widget.selected?.creditLimit.toStringAsFixed(2) ?? '0.00';
      _discountPercentController.text =
          widget.selected?.discountPercent.toStringAsFixed(2) ?? '0.00';
      _glAccountId = widget.selected?.glAccountId;
      _glAccountCode = widget.selected?.glAccountCode;
      _glAccountNameThai = widget.selected?.glAccountNameThai;
      _isActive = widget.selected?.isActive ?? true;
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _codeController.clear();
      _nameThaController.clear();
      _nameEngController.clear();
      _descriptionController.clear();
      _creditDaysController.text = '30';
      _creditLimitController.text = '0.00';
      _discountPercentController.text = '0.00';
      _glAccountId = null;
      _glAccountCode = null;
      _glAccountNameThai = null;
      _isActive = true;
    }
  }

  Future<void> _pickGlAccount() async {
    final svc = Provider.of<AccountService>(context, listen: false);
    List<Account> accounts = [];
    try {
      accounts = await svc.fetchRowsControlAccount()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    } catch (_) {}

    if (!mounted) return;

    final TextEditingController searchCtrl = TextEditingController();
    List<Account> filtered = List.from(accounts);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          void doFilter(String q) {
            setDlgState(() {
              if (q.isEmpty) {
                filtered = List.from(accounts);
              } else {
                final lq = q.toLowerCase();
                filtered = accounts
                    .where((a) =>
                        a.accountCode.toLowerCase().contains(lq) ||
                        a.accountNameThai.toLowerCase().contains(lq))
                    .toList()
                  ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
              }
            });
          }

          return AlertDialog(
            title: const Text('เลือกบัญชีควบคุม (Control Account)'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onChanged: doFilter,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: accounts.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? const Center(child: Text('ไม่พบบัญชี'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final a = filtered[i];
                                  final isSelected = _glAccountId == a.id;
                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    selectedTileColor: Colors.indigo.shade50,
                                    leading: isSelected
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.indigo, size: 18)
                                        : const SizedBox(width: 18),
                                    title: Row(
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            a.accountCode,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo),
                                          ),
                                        ),
                                        Expanded(
                                            child: Text(a.accountNameThai)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            accountTypeOptions[a.accountType] ??
                                                a.accountType,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _glAccountId = a.id;
                                        _glAccountCode = a.accountCode;
                                        _glAccountNameThai = a.accountNameThai;
                                      });
                                      Navigator.of(ctx).pop();
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ปิด'),
              ),
            ],
          );
        });
      },
    );
    searchCtrl.dispose();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameThaController.dispose();
    _nameEngController.dispose();
    _descriptionController.dispose();
    _creditDaysController.dispose();
    _creditLimitController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final row = ArCustomerGroup(
          id: widget.selected?.id ?? 0,
          groupCode: _codeController.text.trim().toUpperCase(),
          groupNameThai: _nameThaController.text.trim(),
          groupNameEng: _nameEngController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          creditDays: int.tryParse(_creditDaysController.text) ?? 30,
          creditLimit: double.tryParse(_creditLimitController.text) ?? 0,
          discountPercent:
              double.tryParse(_discountPercentController.text) ?? 0,
          glAccountId: _glAccountId,
          glAccountCode: _glAccountCode,
          glAccountNameThai: _glAccountNameThai,
          isActive: _isActive,
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
            'เลือกกลุ่มลูกค้าเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มใหม่'),
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
                      : 'เพิ่มข้อมูลใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // รหัสกลุ่ม
            TextFormField(
              readOnly: widget.mode != Mode.add,
              controller: _codeController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'รหัสกลุ่มลูกค้า *',
                border: OutlineInputBorder(),
              ),
              maxLength: 20,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'โปรดระบุรหัสกลุ่มลูกค้า';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ชื่อ (ไทย / อังกฤษ)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _nameThaController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อกลุ่มลูกค้า (ไทย) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'โปรดระบุชื่อภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _nameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อกลุ่มลูกค้า (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // คำอธิบาย
            TextFormField(
              readOnly: readOnly,
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // เงื่อนไขเครดิต
            Text('เงื่อนไขเครดิตเริ่มต้นของกลุ่ม',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade700)),
            const SizedBox(height: 10),

            Row(
              children: [
                // วันเครดิต
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _creditDaysController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'วันเครดิต (วัน)',
                      border: OutlineInputBorder(),
                      suffixText: 'วัน',
                    ),
                    validator: (value) {
                      if (value == null ||
                          int.tryParse(value) == null ||
                          int.parse(value) < 0) {
                        return 'โปรดระบุจำนวนวัน';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // วงเงินเครดิต
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _creditLimitController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'วงเงินเครดิต',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return 'โปรดระบุวงเงินที่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // ส่วนลด
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _discountPercentController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'ส่วนลด (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return 'โปรดระบุส่วนลดที่ถูกต้อง';
                      }
                      final d = double.parse(value);
                      if (d < 0 || d > 100) return 'ต้องอยู่ระหว่าง 0-100';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // บัญชี GL (Control Account)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'รหัสบัญชี GL (Control Account)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _glAccountCode != null
                        ? Text(
                            '$_glAccountCode — ${_glAccountNameThai ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : const Text('— ไม่ระบุ —',
                            style: TextStyle(color: Colors.grey)),
                  ),
                  if (!readOnly) ...[
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.blue),
                      tooltip: 'ค้นหาบัญชี',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _pickGlAccount,
                    ),
                    if (_glAccountId != null)
                      IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.red, size: 18),
                        tooltip: 'ล้างบัญชี',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() {
                          _glAccountId = null;
                          _glAccountCode = null;
                          _glAccountNameThai = null;
                        }),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // สถานะ
            Row(
              children: [
                Expanded(
                  child: Text(
                      'สถานะการใช้: ${_isActive ? 'ใช้' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: readOnly
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ปุ่ม
            Row(
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
                                  strokeWidth: 2, color: Colors.white),
                            )
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
