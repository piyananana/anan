// lib/cm/widgets/cm_bank_account_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../cd/models/cd_bank.dart';
import '../models/cm_bank_account.dart';
import '../../cd/services/cd_bank_service.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';

class CmBankAccountDetailWidget extends StatefulWidget {
  final Mode mode;
  final CmBankAccount? selected;
  final Future<void> Function(CmBankAccount) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const CmBankAccountDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<CmBankAccountDetailWidget> createState() =>
      CmBankAccountDetailWidgetState();
}

class CmBankAccountDetailWidgetState extends State<CmBankAccountDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameTh;
  late TextEditingController _nameEn;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _remarkCtrl;

  String _accountType = 'SAVING';
  String _cmType      = 'BANK';
  String _currencyCode = 'THB';
  bool   _isCheckAccount = false;
  int? _bankId;
  String? _bankDisplay;
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountName;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _init(widget.selected);
  }

  void _init(CmBankAccount? d) {
    _codeCtrl = TextEditingController(text: d?.accountCode ?? '');
    _nameTh = TextEditingController(text: d?.accountNameTh ?? '');
    _nameEn = TextEditingController(text: d?.accountNameEn ?? '');
    _accountNumberCtrl = TextEditingController(text: d?.accountNumber ?? '');
    _remarkCtrl = TextEditingController(text: d?.remark ?? '');
    _accountType    = d?.accountType    ?? 'SAVING';
    _cmType         = d?.cmType         ?? 'BANK';
    _currencyCode   = d?.currencyCode   ?? 'THB';
    _isCheckAccount = d?.isCheckAccount ?? false;
    _bankId      = d?.bankId;
    _bankDisplay = d?.bankDisplay.isNotEmpty == true ? d!.bankDisplay : null;
    _glAccountId   = d?.glAccountId;
    _glAccountCode = d?.glAccountCode;
    _glAccountName = d?.glAccountName;
    _isActive = d?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant CmBankAccountDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        (widget.mode == Mode.add && oldWidget.mode != Mode.add) ||
        widget.requestSeq != oldWidget.requestSeq) {
      _codeCtrl.text = widget.selected?.accountCode ?? '';
      _nameTh.text = widget.selected?.accountNameTh ?? '';
      _nameEn.text = widget.selected?.accountNameEn ?? '';
      _accountNumberCtrl.text = widget.selected?.accountNumber ?? '';
      _remarkCtrl.text = widget.selected?.remark ?? '';
      _accountType    = widget.selected?.accountType    ?? 'SAVING';
      _cmType         = widget.selected?.cmType         ?? 'BANK';
      _currencyCode   = widget.selected?.currencyCode   ?? 'THB';
      _isCheckAccount = widget.selected?.isCheckAccount ?? false;
      _bankId      = widget.selected?.bankId;
      _bankDisplay = widget.selected?.bankDisplay.isNotEmpty == true
          ? widget.selected!.bankDisplay
          : null;
      _glAccountId   = widget.selected?.glAccountId;
      _glAccountCode = widget.selected?.glAccountCode;
      _glAccountName = widget.selected?.glAccountName;
      _isActive = widget.selected?.isActive ?? true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameTh.dispose();
    _nameEn.dispose();
    _accountNumberCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    List<Currency> currencies;
    try {
      currencies = await Provider.of<CurrencyService>(context, listen: false).fetchRows();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isEnglish ? 'Failed to load currencies' : 'โหลดสกุลเงินล้มเหลว'}: $e')));
      return;
    }
    final active = currencies.where((c) => c.isActive).toList()
      ..sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Select Currency' : 'เลือกสกุลเงิน'),
        content: SizedBox(
          width: 380, height: 400,
          child: ListView.builder(
            itemCount: active.length,
            itemBuilder: (_, i) {
              final c = active[i];
              final name = isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;
              return ListTile(
                leading: Text(c.currencyCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                title: Text(name),
                selected: c.currencyCode == _currencyCode,
                onTap: () { setState(() => _currencyCode = c.currencyCode); Navigator.of(ctx).pop(); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก', style: const TextStyle(color: Colors.red)))],
      ),
    );
  }

  Future<void> _pickBank() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    List<Bank> banks;
    try {
      banks = await Provider.of<BankService>(context, listen: false).fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${isEnglish ? 'Failed to load banks' : 'โหลดข้อมูลธนาคารล้มเหลว'}: $e')));
      }
      return;
    }
    final active = banks.where((b) => b.isActive).toList()
      ..sort((a, b) => a.bankCode.compareTo(b.bankCode));
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Select Bank' : 'เลือกธนาคาร', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 480,
          child: active.isEmpty
              ? Center(child: Text(isEnglish ? 'No banks found' : 'ไม่พบข้อมูลธนาคาร'))
              : ListView.builder(
                  itemCount: active.length,
                  itemBuilder: (_, i) {
                    final b = active[i];
                    return ListTile(
                      title: Text('${b.bankCode} — ${isEnglish && b.bankNameEng.isNotEmpty ? b.bankNameEng : b.bankNameThai}'),
                      subtitle: !isEnglish && b.bankNameEng.isNotEmpty
                          ? Text(b.bankNameEng)
                          : null,
                      onTap: () {
                        setState(() {
                          _bankId = b.id;
                          _bankDisplay = b.displayName;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    setState(() => _isSaving = true);
    try {
      final row = CmBankAccount(
        id: widget.selected?.id,
        accountCode: _codeCtrl.text.trim().toUpperCase(),
        accountNameTh: _nameTh.text.trim(),
        accountNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        bankId: _bankId,
        accountNumber: _accountNumberCtrl.text.trim().isEmpty
            ? null
            : _accountNumberCtrl.text.trim(),
        accountType: _accountType,
        cmType: _cmType,
        currencyCode: _currencyCode,
        isCheckAccount: _isCheckAccount,
        glAccountId: _glAccountId,
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
          ? 'Select a bank account to edit, or press + to add a new one'
          : 'เลือกบัญชีธนาคารเพื่อแก้ไข หรือกดปุ่ม + เพื่อเพิ่มใหม่'));
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
                  ? (isEnglish ? 'View Bank Account' : 'ดูข้อมูลบัญชีธนาคาร')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Bank Account' : 'แก้ไขบัญชีธนาคาร')
                      : (isEnglish ? 'Add Bank Account' : 'เพิ่มบัญชีธนาคาร'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // รหัส
            TextFormField(
              controller: _codeCtrl,
              readOnly: widget.mode != Mode.add,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: isEnglish ? 'Bank Account Code *' : 'รหัสบัญชีธนาคาร *',
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
                      labelText: isEnglish ? 'Account Name (Thai) *' : 'ชื่อบัญชี (ไทย) *',
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
                      labelText: isEnglish ? 'Account Name (English)' : 'ชื่อบัญชี (อังกฤษ)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ธนาคาร
            InkWell(
              onTap: ro ? null : _pickBank,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Bank' : 'ธนาคาร',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_bankId != null && !ro)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _bankId = null;
                            _bankDisplay = null;
                          }),
                        ),
                      const Icon(Icons.search),
                    ],
                  ),
                ),
                child: Text(_bankId == null ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : _bankDisplay ?? ''),
              ),
            ),
            const SizedBox(height: 12),

            // ประเภทหลัก
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _cmType,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Main Type *' : 'ประเภทหลัก *',
                border: const OutlineInputBorder(),
              ),
              items: cmCmTypeOptions.keys
                  .map((k) => DropdownMenuItem(value: k, child: Text(cmCmTypeLabel(k, isEnglish))))
                  .toList(),
              onChanged: ro ? null : (v) => setState(() => _cmType = v!),
            ),
            const SizedBox(height: 12),

            // เลขบัญชี / ประเภทบัญชีธนาคาร (แสดงเฉพาะ BANK)
            if (_cmType == 'BANK') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accountNumberCtrl,
                      readOnly: ro,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Account Number' : 'เลขที่บัญชี',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _accountType,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Account Type *' : 'ประเภทบัญชี *',
                        border: const OutlineInputBorder(),
                      ),
                      items: cmAccountTypeOptions.keys
                          .map((k) => DropdownMenuItem(value: k, child: Text(cmAccountTypeLabel(k, isEnglish))))
                          .toList(),
                      onChanged: ro ? null : (v) => setState(() => _accountType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // สกุลเงิน + รับ/ออกเช็ค
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : _pickCurrency,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Currency *' : 'สกุลเงิน *',
                        border: const OutlineInputBorder(),
                        suffixIcon: ro ? null : const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(_currencyCode,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    dense: true,
                    title: Text(isEnglish ? 'Supports Check' : 'รองรับเช็ค', style: const TextStyle(fontSize: 14)),
                    value: _isCheckAccount,
                    onChanged: ro ? null : (v) => setState(() => _isCheckAccount = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // บัญชี GL
            InkWell(
              onTap: ro ? null : _pickGlAccount,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'GL Account (Bank Posting)' : 'บัญชี GL (ลงบัญชีธนาคาร)',
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
