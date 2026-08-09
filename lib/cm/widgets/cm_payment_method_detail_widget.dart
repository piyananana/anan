// lib/cm/widgets/cm_payment_method_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_payment_method.dart';
import '../services/cm_bank_account_service.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';

class CmPaymentMethodDetailWidget extends StatefulWidget {
  final Mode mode;
  final CmPaymentMethod? selected;
  final Future<void> Function(CmPaymentMethod) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const CmPaymentMethodDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<CmPaymentMethodDetailWidget> createState() =>
      CmPaymentMethodDetailWidgetState();
}

class CmPaymentMethodDetailWidgetState
    extends State<CmPaymentMethodDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameTh;
  late TextEditingController _nameEn;
  late TextEditingController _remarkCtrl;

  String _methodType = 'CASH';
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountName;
  int? _bankAccountId;
  String? _bankAccountDisplay;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _init(widget.selected);
  }

  void _init(CmPaymentMethod? d) {
    _codeCtrl = TextEditingController(text: d?.methodCode ?? '');
    _nameTh = TextEditingController(text: d?.methodNameTh ?? '');
    _nameEn = TextEditingController(text: d?.methodNameEn ?? '');
    _remarkCtrl = TextEditingController(text: d?.remark ?? '');
    _methodType = d?.methodType ?? 'CASH';
    _glAccountId = d?.glAccountId;
    _glAccountCode = d?.glAccountCode;
    _glAccountName = d?.glAccountName;
    _bankAccountId = d?.cmBankAccountId;
    _bankAccountDisplay = _buildBankAccountDisplay(d);
    _isActive = d?.isActive ?? true;
  }

  String? _buildBankAccountDisplay(CmPaymentMethod? d) {
    if (d?.cmBankAccountId == null) return null;
    final parts = <String>[];
    if ((d!.bankShortName ?? d.bankNameTh ?? '').isNotEmpty) {
      parts.add(d.bankShortName ?? d.bankNameTh!);
    }
    if ((d.bankAccountCode ?? '').isNotEmpty) parts.add(d.bankAccountCode!);
    if ((d.bankAccountNumber ?? '').isNotEmpty) parts.add(d.bankAccountNumber!);
    return parts.join(' — ');
  }

  @override
  void didUpdateWidget(covariant CmPaymentMethodDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        (widget.mode == Mode.add && oldWidget.mode != Mode.add)) {
      _codeCtrl.text = widget.selected?.methodCode ?? '';
      _nameTh.text = widget.selected?.methodNameTh ?? '';
      _nameEn.text = widget.selected?.methodNameEn ?? '';
      _remarkCtrl.text = widget.selected?.remark ?? '';
      _methodType = widget.selected?.methodType ?? 'CASH';
      _glAccountId = widget.selected?.glAccountId;
      _glAccountCode = widget.selected?.glAccountCode;
      _glAccountName = widget.selected?.glAccountName;
      _bankAccountId = widget.selected?.cmBankAccountId;
      _bankAccountDisplay = _buildBankAccountDisplay(widget.selected);
      _isActive = widget.selected?.isActive ?? true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameTh.dispose();
    _nameEn.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGlAccount() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    List<Account> accounts;
    try {
      accounts = await Provider.of<AccountService>(context, listen: false).fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${isEnglish ? 'Failed to load accounts' : 'โหลดข้อมูลบัญชีล้มเหลว'}: $e')));
      }
      return;
    }
    final leaf = accounts.where((a) => a.isActive && a.isNormalAccount).toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    if (!mounted) return;

    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(leaf);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void doFilter(String q) {
            setDlg(() {
              final lq = q.toLowerCase();
              filtered = q.isEmpty
                  ? List.from(leaf)
                  : leaf.where((a) =>
                      a.accountCode.toLowerCase().contains(lq) ||
                      a.accountNameThai.toLowerCase().contains(lq) ||
                      a.accountNameEng.toLowerCase().contains(lq)).toList();
            });
          }

          return AlertDialog(
            title: Text(isEnglish ? 'Select GL Account' : 'เลือกบัญชี GL'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: isEnglish ? 'Search (code / name)' : 'ค้นหา (รหัส / ชื่อ)',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onChanged: doFilter,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text(isEnglish ? 'No accounts found' : 'ไม่พบบัญชี'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final a = filtered[i];
                              final name = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
                              return ListTile(
                                title: Text('${a.accountCode} — $name'),
                                onTap: () {
                                  setState(() {
                                    _glAccountId = a.id;
                                    _glAccountCode = a.accountCode;
                                    _glAccountName = name;
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
                child: Text(isEnglish ? 'Cancel' : 'ยกเลิก', style: const TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickBankAccount() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    List<CmBankAccount> bankAccounts;
    try {
      bankAccounts = await Provider.of<CmBankAccountService>(context, listen: false)
          .fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${isEnglish ? 'Failed to load bank accounts' : 'โหลดข้อมูลบัญชีธนาคารล้มเหลว'}: $e')));
      }
      return;
    }
    final active = bankAccounts.where((b) => b.isActive).toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Select Bank Account' : 'เลือกบัญชีธนาคาร',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 520,
          height: 480,
          child: active.isEmpty
              ? Center(child: Text(isEnglish ? 'No bank accounts found' : 'ไม่พบข้อมูลบัญชีธนาคาร'))
              : ListView.builder(
                  itemCount: active.length,
                  itemBuilder: (_, i) {
                    final b = active[i];
                    final name = isEnglish && (b.accountNameEn ?? '').isNotEmpty ? b.accountNameEn! : b.accountNameTh;
                    return ListTile(
                      title: Text('${b.accountCode} — $name'),
                      subtitle: Text([
                        if (b.bankDisplay.isNotEmpty) b.bankDisplay,
                        if ((b.accountNumber ?? '').isNotEmpty)
                          b.accountNumber!,
                      ].join('  ')),
                      onTap: () {
                        setState(() {
                          _bankAccountId = b.id;
                          _bankAccountDisplay = [
                            if (b.bankDisplay.isNotEmpty) b.bankDisplay,
                            b.accountCode,
                            if ((b.accountNumber ?? '').isNotEmpty)
                              b.accountNumber!,
                          ].join(' — ');
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
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeHelperText() {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final Map<String, String> hints = {
      'CASH':            'ข้อมูลที่ระบุเมื่อรับชำระ: จำนวนเงิน',
      'CHECK':           'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่เช็ค, วันที่เช็ค, ธนาคาร, สาขา, เลขที่บัญชี',
      'TRANSFER':        'ข้อมูลที่ระบุเมื่อรับชำระ: เลขอ้างอิงการโอน, ธนาคารต้นทาง, สาขา, วันที่โอน',
      'CREDIT_CARD':     'ข้อมูลที่ระบุเมื่อรับชำระ: ประเภทบัตร, 4 หลักท้าย, รหัสอนุมัติ, รหัสเครื่อง EDC, Batch No',
      'DEBIT_CARD':      'ข้อมูลที่ระบุเมื่อรับชำระ: ประเภทบัตร, 4 หลักท้าย, รหัสอนุมัติ, รหัสเครื่อง EDC, Batch No',
      'QR_CODE':         'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่อ้างอิง (Ref No), วันที่/เวลาชำระ',
      'MOBILE_BANKING':  'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่อ้างอิง (Ref No), ธนาคารต้นทาง, วันที่โอน',
      'BILL_OF_EXCHANGE':'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่ตั๋ว, วันครบกำหนด, ธนาคาร',
      'OTHER':           'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่อ้างอิง, วันที่, หมายเหตุ',
    };
    final Map<String, String> hintsEng = {
      'CASH':            'Fields captured on receipt: Amount',
      'CHECK':           'Fields captured on receipt: Check No., Check Date, Bank, Branch, Account No.',
      'TRANSFER':        'Fields captured on receipt: Transfer Ref No., Source Bank, Branch, Transfer Date',
      'CREDIT_CARD':     'Fields captured on receipt: Card Type, Last 4 Digits, Approval Code, EDC No., Batch No.',
      'DEBIT_CARD':      'Fields captured on receipt: Card Type, Last 4 Digits, Approval Code, EDC No., Batch No.',
      'QR_CODE':         'Fields captured on receipt: Ref No., Payment Date/Time',
      'MOBILE_BANKING':  'Fields captured on receipt: Ref No., Source Bank, Transfer Date',
      'BILL_OF_EXCHANGE':'Fields captured on receipt: Bill No., Due Date, Bank',
      'OTHER':           'Fields captured on receipt: Ref No., Date, Note',
    };
    final hint = isEnglish ? hintsEng[_methodType] : hints[_methodType];
    if (hint == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(hint, style: TextStyle(fontSize: 12, color: Colors.blue[800])),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    setState(() => _isSaving = true);
    try {
      final row = CmPaymentMethod(
        id: widget.selected?.id,
        methodCode: _codeCtrl.text.trim().toUpperCase(),
        methodNameTh: _nameTh.text.trim(),
        methodNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        methodType: _methodType,
        glAccountId: _glAccountId,
        cmBankAccountId: _bankAccountId,
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isEnglish ? 'An error occurred' : 'เกิดข้อผิดพลาด'}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    if (widget.isPlaceholder) {
      return Center(child: Text(isEnglish
          ? 'Select a payment method to edit, or press + to add a new one'
          : 'เลือกประเภทการชำระเงินเพื่อแก้ไข หรือกดปุ่ม + เพื่อเพิ่มใหม่'));
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
                  ? (isEnglish ? 'View Payment Method' : 'ดูข้อมูลประเภทการชำระเงิน')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Payment Method' : 'แก้ไขประเภทการชำระเงิน')
                      : (isEnglish ? 'Add Payment Method' : 'เพิ่มประเภทการชำระเงิน'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // รหัส
            TextFormField(
              controller: _codeCtrl,
              readOnly: widget.mode != Mode.add,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: isEnglish ? 'Payment Method Code *' : 'รหัสประเภทการชำระ *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isEnglish ? 'Please enter a code' : 'โปรดระบุรหัส') : null,
            ),
            const SizedBox(height: 12),

            // ชื่อไทย / อังกฤษ
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameTh,
                    readOnly: ro,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Name (Thai) *' : 'ชื่อ (ไทย) *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEnglish ? 'Please enter a name' : 'โปรดระบุชื่อ') : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _nameEn,
                    readOnly: ro,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Name (English)' : 'ชื่อ (อังกฤษ)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ประเภท
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _methodType,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Payment Type *' : 'ประเภทการชำระ *',
                border: const OutlineInputBorder(),
              ),
              items: cmMethodTypeOptions.keys
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text(cmMethodTypeLabel(k, isEnglish), overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: ro ? null : (v) => setState(() => _methodType = v!),
            ),
            const SizedBox(height: 8),
            // คำอธิบายช่องข้อมูลต่างๆ ตามประเภท
            _buildTypeHelperText(),
            const SizedBox(height: 12),

            // บัญชี GL (สำหรับลงบัญชี)
            InkWell(
              onTap: ro ? null : _pickGlAccount,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'GL Account (Payment Posting)' : 'บัญชี GL (ลงบัญชีการชำระ)',
                  helperText: isEnglish
                      ? 'If not specified, uses the document setup or bank account'
                      : 'ถ้าไม่ระบุ จะใช้จากตั้งค่าเอกสาร หรือ บัญชีธนาคาร',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_glAccountId != null && !ro)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _glAccountId = null;
                            _glAccountCode = null;
                            _glAccountName = null;
                          }),
                        ),
                      const Icon(Icons.search),
                    ],
                  ),
                ),
                child: Text(
                  _glAccountId == null
                      ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —')
                      : '${_glAccountCode ?? ''} ${_glAccountName ?? ''}',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // บัญชีธนาคาร (optional, for check/transfer/card)
            InkWell(
              onTap: ro ? null : _pickBankAccount,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Bank Account (optional)' : 'บัญชีธนาคาร (ถ้ามี)',
                  helperText: ['CREDIT_CARD', 'DEBIT_CARD'].contains(_methodType)
                      ? (isEnglish ? 'Account receiving card settlements (Merchant Account)' : 'บัญชีที่รับยอดจากบัตร (Merchant Account)')
                      : (isEnglish ? 'Account receiving funds (for check / transfer / bill of exchange)' : 'บัญชีที่รับเงิน (สำหรับเช็ค / โอน / ตั๋วแลกเงิน)'),
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_bankAccountId != null && !ro)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _bankAccountId = null;
                            _bankAccountDisplay = null;
                          }),
                        ),
                      const Icon(Icons.search),
                    ],
                  ),
                ),
                child: Text(
                  _bankAccountId == null
                      ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —')
                      : _bankAccountDisplay ?? '',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // หมายเหตุ
            TextFormField(
              controller: _remarkCtrl,
              readOnly: ro,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Note' : 'หมายเหตุ',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // สถานะ
            Row(
              children: [
                Expanded(child: Text(isEnglish
                    ? 'Status: ${_isActive ? 'Active' : 'Inactive'}'
                    : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                Switch(
                  value: _isActive,
                  onChanged: ro ? null : (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ปุ่ม
            Row(
              children: [
                if (widget.mode != Mode.view)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isSaving ||
                              !(widget.mode == Mode.add
                                  ? (MenuScope.of(context)?.canCreate ?? true)
                                  : (MenuScope.of(context)?.canEdit ?? true)))
                          ? null
                          : _submit,
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
                    label: Text(l.cancel),
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
