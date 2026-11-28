// lib/cm/widgets/cm_bank_account_detail_widget.dart — บัญชีธนาคาร/เงินสดย่อย แบบ B ของ IM (user 2026-11-28)
//   แถบหัว (รหัส ชื่อ ป้าย / ปุ่ม) + ตัวเลขสรุป + ลิงก์ข้ามส่วน + เลื่อนหน้าเดียว
//   ส่วน: ข้อมูลบัญชี (4 กลุ่มสี) / บัญชี GL ตามประเภทการชำระเงิน / รายการเข้า-ออกล่าสุด / สมุดเช็ค
//   สำเนาเป็นบัญชีใหม่: ไม่คัดลอกรหัส เลขที่บัญชี และบัญชี GL
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../cd/models/cd_bank.dart';
import '../../cd/services/cd_bank_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_master_summary.dart';
import '../services/cm_bank_account_service.dart';

class CmBankAccountDetailWidget extends StatefulWidget {
  final Mode mode;
  final CmBankAccount? selected;
  final CmBankAccount? copyFrom;
  final Future<void> Function(CmBankAccount) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  const CmBankAccountDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    this.copyFrom,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  @override
  State<CmBankAccountDetailWidget> createState() => CmBankAccountDetailWidgetState();
}

class CmBankAccountDetailWidgetState extends State<CmBankAccountDetailWidget> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _codeCtrl = TextEditingController();
  final _nameTh = TextEditingController();
  final _nameEn = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _taxBranchCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  String _accountType = 'SAVING';
  String _cmType = 'BANK';
  String _currencyCode = CurrencyService.baseCode;
  List<Currency> _currencies = [];
  bool _isCheckAccount = false;
  int? _bankId;
  String? _bankDisplay;
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountName;
  String? _glAccountNameEn;
  bool _isActive = true;
  // สาขาของบัญชีธนาคาร — ตีราคา FX ธนาคารลงรายการบัญชีที่สาขานี้
  int? _branchId;
  String? _branchLabel;
  List<Branch> _branches = [];

  bool _isSaving = false;
  String _snapshot = '';

  CmBankSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;

  static final _money = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  @override
  void initState() {
    super.initState();
    _applyCurrent();
    _loadCurrencies();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant CmBankAccountDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected &&
        widget.mode == oldWidget.mode &&
        widget.requestSeq == oldWidget.requestSeq &&
        widget.copyFrom == oldWidget.copyFrom) {
      return;
    }
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    final onlyFullLoad = sameRecord && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq;
    _applyCurrent();
    if (widget.mode == Mode.add && !_isCopy) _loadDefaultCurrency();
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: !onlyFullLoad && sameRecord && widget.mode == Mode.view);
    if (!onlyFullLoad) kScrollTop();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameTh, _nameEn, _accountNumberCtrl, _taxIdCtrl, _taxBranchCtrl, _remarkCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyCurrent() {
    if (widget.mode == Mode.add) {
      _apply(widget.copyFrom, copy: widget.copyFrom != null);
    } else {
      _apply(widget.selected);
    }
  }

  void _apply(CmBankAccount? d, {bool copy = false}) {
    _codeCtrl.text = copy ? '' : (d?.accountCode ?? '');
    _nameTh.text = d?.accountNameTh ?? '';
    _nameEn.text = d?.accountNameEn ?? '';
    _accountNumberCtrl.text = copy ? '' : (d?.accountNumber ?? '');
    _taxIdCtrl.text = d?.taxId ?? '';
    _taxBranchCtrl.text = d?.taxBranchCode ?? '';
    _remarkCtrl.text = d?.remark ?? '';
    _accountType = d?.accountType ?? 'SAVING';
    _cmType = d?.cmType ?? 'BANK';
    _currencyCode = d?.currencyCode ?? CurrencyService.baseCode;
    _isCheckAccount = d?.isCheckAccount ?? false;
    _bankId = d?.bankId;
    _bankDisplay = d == null ? null : _bankText(d);
    _glAccountId = copy ? null : d?.glAccountId;
    _glAccountCode = copy ? null : d?.glAccountCode;
    _glAccountName = copy ? null : d?.glAccountName;
    _glAccountNameEn = copy ? null : d?.glAccountNameEn;
    _isActive = copy ? true : (d?.isActive ?? true);
    _branchId = d?.branchId;
    _branchLabel = d?.branchCode == null ? null : '${d!.branchCode} ${d.branchNameTh ?? ''}'.trim();
    _snapshot = copy ? '' : _fingerprint();
  }

  String? _bankText(CmBankAccount d) {
    if (d.bankId == null) return null;
    final n = d.bankName(_isEnglish);
    return '${d.bankCode ?? ''} ${n.isEmpty ? d.bankDisplay : n}'.trim();
  }

  // ค่าที่โหลดตามหลังมาเปลี่ยนฟอร์ม — ถ้ายังไม่ได้แก้อะไรให้ถือว่ายังไม่แก้
  void _keepClean(VoidCallback fn) {
    final wasClean = _fingerprint() == _snapshot;
    setState(fn);
    if (wasClean) _snapshot = _fingerprint();
  }

  Future<void> _loadCurrencies() async {
    try {
      final list = await CurrencyService().fetchActiveRows();
      if (mounted) setState(() => _currencies = list);
    } catch (_) {}
    if (widget.mode == Mode.add && !_isCopy) _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    try {
      final code = await CurrencyService().getBaseCurrencyCode();
      if (mounted && widget.mode == Mode.add && !_isCopy) _keepClean(() => _currencyCode = code);
    } catch (_) {}
  }

  Future<void> _loadSummary({bool force = false}) async {
    final id = widget.mode == Mode.add ? null : widget.selected?.id;
    if (id == null) {
      _summary = null;
      _summaryFor = null;
      return;
    }
    if (!force && _summaryFor == id && _summary != null) return;
    _summaryFor = id;
    _summaryLoading = true;
    try {
      final s = await CmBankAccountService().fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    }
    if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
  }

  CmBankAccount _build() {
    final bank = _cmType == 'BANK';
    return CmBankAccount(
      id: widget.mode == Mode.add ? null : widget.selected?.id,
      accountCode: _codeCtrl.text.trim().toUpperCase(),
      accountNameTh: _nameTh.text.trim(),
      accountNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
      bankId: _bankId,
      accountNumber: _accountNumberCtrl.text.trim().isEmpty ? null : _accountNumberCtrl.text.trim(),
      taxId: bank && _taxIdCtrl.text.trim().isNotEmpty ? _taxIdCtrl.text.trim() : null,
      taxBranchCode: bank && _taxBranchCtrl.text.trim().isNotEmpty ? _taxBranchCtrl.text.trim() : null,
      accountType: _accountType,
      cmType: _cmType,
      currencyCode: _currencyCode,
      isCheckAccount: _isCheckAccount,
      glAccountId: _glAccountId,
      branchId: _branchId,
      isActive: _isActive,
      remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
    );
  }

  String _fingerprint() {
    try {
      return jsonEncode(_build().toJson());
    } catch (_) {
      return '';
    }
  }

  Future<void> _submit() async {
    final e = _isEnglish;
    String? err;
    final tb = _taxBranchCtrl.text.trim();
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the account code' : 'โปรดระบุรหัสบัญชี';
    } else if (_nameTh.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'โปรดระบุชื่อบัญชี (ไทย)';
    } else if (_cmType == 'BANK' && tb.isNotEmpty && !RegExp(r'^\d{1,5}$').hasMatch(tb)) {
      err = e ? 'Tax branch must be up to 5 digits' : 'สาขาภาษีต้องเป็นตัวเลขไม่เกิน 5 หลัก';
    } else if (_glAccountId == null) {
      err = e ? 'Please select the GL account' : 'โปรดเลือกรหัสบัญชี GL';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e ? 'An error occurred: $ex' : 'เกิดข้อผิดพลาด: $ex'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── ตัวเลือก ──────────────────────────────────────────────────────────────────
  Future<void> _pickBranch() async {
    final e = _isEnglish;
    try {
      if (_branches.isEmpty) _branches = await BranchService().fetchActiveRows();
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e ? 'Failed to load branches' : 'โหลดสาขาล้มเหลว'}: $ex')));
      return;
    }
    if (!mounted) return;
    final r = await showUserBranchPicker(context, branches: _branches, selectedId: _branchId, isEnglish: e, userFilter: false);
    if (r == null || !mounted) return;
    setState(() {
      _branchId = r.$2?.id;
      _branchLabel = r.$2 == null ? null : branchLabel(r.$2, e);
    });
  }

  Future<void> _pickBank() async {
    final e = _isEnglish;
    List<Bank> banks;
    try {
      banks = await Provider.of<BankService>(context, listen: false).fetchRows();
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e ? 'Failed to load banks' : 'โหลดข้อมูลธนาคารล้มเหลว'}: $ex')));
      return;
    }
    final active = banks.where((b) => b.isActive).toList()..sort((a, b) => a.bankCode.compareTo(b.bankCode));
    if (!mounted) return;
    await _pickList<Bank>(
      title: e ? 'Select bank' : 'เลือกธนาคาร',
      items: active,
      code: (b) => b.bankCode,
      name: (b) => e && b.bankNameEng.isNotEmpty ? b.bankNameEng : b.bankNameThai,
      search: (b) => '${b.bankCode} ${b.bankNameThai} ${b.bankNameEng}',
      selected: (b) => b.id == _bankId,
      onPick: (b) => setState(() {
        _bankId = b.id;
        _bankDisplay = '${b.bankCode} ${e && b.bankNameEng.isNotEmpty ? b.bankNameEng : b.bankNameThai}';
      }),
    );
  }

  // บัญชี GL ของบัญชีธนาคาร: เฉพาะบัญชีที่ลงรายการได้
  Future<void> _pickGlAccount() async {
    final e = _isEnglish;
    List<Account> accounts;
    try {
      accounts = await Provider.of<AccountService>(context, listen: false).fetchRows();
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e ? 'Failed to load accounts' : 'โหลดข้อมูลบัญชีล้มเหลว'}: $ex')));
      return;
    }
    final leaf = accounts.where((a) => a.isActive && a.isNormalAccount).toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    if (!mounted) return;
    await _pickList<Account>(
      title: e ? 'Select GL account' : 'เลือกบัญชี GL',
      items: leaf,
      code: (a) => a.accountCode,
      name: (a) => e && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai,
      search: (a) => '${a.accountCode} ${a.accountNameThai} ${a.accountNameEng}',
      selected: (a) => a.id == _glAccountId,
      onPick: (a) => setState(() {
        _glAccountId = a.id;
        _glAccountCode = a.accountCode;
        _glAccountName = a.accountNameThai;
        _glAccountNameEn = a.accountNameEng;
      }),
    );
  }

  Future<void> _pickList<T>({
    required String title,
    required List<T> items,
    required String Function(T) code,
    required String Function(T) name,
    required String Function(T) search,
    required bool Function(T) selected,
    required ValueChanged<T> onPick,
  }) async {
    final e = _isEnglish;
    final searchCtrl = TextEditingController();
    List<T> filtered = List.from(items);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = items.where((x) => search(x).toLowerCase().contains(lq)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(e ? 'No data found' : 'ไม่พบข้อมูล'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final x = filtered[i];
                          final sel = selected(x);
                          return ListTile(
                            dense: true,
                            selected: sel,
                            leading: sel ? Icon(Icons.check_circle, color: kInk, size: 18) : const SizedBox(width: 18),
                            title: Row(children: [
                              SizedBox(width: 90, child: Text(code(x), style: TextStyle(fontWeight: FontWeight.bold, color: kInk))),
                              Expanded(child: Text(name(x))),
                            ]),
                            onTap: () {
                              onPick(x);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(e ? 'Close' : 'ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ─── ข้อมูลบัญชี ────────────────────────────────────────────────────────────────
  List<DropdownMenuItem<String>> _currencyItems(bool e) {
    final codes = {..._currencies.map((c) => c.currencyCode), _currencyCode};
    String label(String code) {
      final c = _currencies.where((c) => c.currencyCode == code).firstOrNull;
      final n = c == null ? '' : (e && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai);
      return n.isEmpty ? code : '$code  $n';
    }

    return [for (final c in codes) DropdownMenuItem(value: c, child: Text(label(c), overflow: TextOverflow.ellipsis))];
  }

  String _glText(bool e) {
    if (_glAccountId == null) return '';
    final n = e && (_glAccountNameEn ?? '').isNotEmpty ? _glAccountNameEn! : (_glAccountName ?? '');
    return '${_glAccountCode ?? ''} $n'.trim();
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final bank = _cmType == 'BANK';
    return kCard(
      title: e ? 'Account details' : 'ข้อมูลบัญชี',
      trailing: kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Account code *' : 'รหัสบัญชี *', _codeCtrl, editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Main type *' : 'ประเภทหลัก *', _cmType,
                [for (final k in cmCmTypeOptions.keys) DropdownMenuItem(value: k, child: Text(cmCmTypeLabel(k, e), overflow: TextOverflow.ellipsis))],
                ro ? null : (v) => setState(() => _cmType = v ?? 'BANK'), auto: false),
          ]),
          kTxt(e ? 'Account name (TH) *' : 'ชื่อบัญชี (ไทย) *', _nameTh),
          kTxt(e ? 'Account name (EN)' : 'ชื่อบัญชี (อังกฤษ)', _nameEn),
          kRow([
            if (bank)
              kDd<String>(e ? 'Account type' : 'ประเภทบัญชี', _accountType,
                  [for (final k in cmAccountTypeOptions.keys) DropdownMenuItem(value: k, child: Text(cmAccountTypeLabel(k, e), overflow: TextOverflow.ellipsis))],
                  ro ? null : (v) => setState(() => _accountType = v ?? 'SAVING'), auto: false),
            kDd<String>(e ? 'Currency' : 'สกุลเงิน', _currencyCode, _currencyItems(e),
                ro ? null : (v) => setState(() => _currencyCode = v ?? CurrencyService.baseCode)),
          ]),
        ]),
        if (bank)
          kGroup(2, e ? 'Bank' : 'ธนาคาร', ImKit.gParty, [
            kFk(
              label: e ? 'Bank' : 'ธนาคาร',
              text: _bankDisplay,
              hasValue: _bankId != null,
              onSearch: _pickBank,
              onClear: () => setState(() {
                _bankId = null;
                _bankDisplay = null;
              }),
            ),
            kTxt(e ? 'Account number' : 'เลขที่บัญชี', _accountNumberCtrl),
            kRow([
              kTxt(e ? 'Bank tax ID' : 'เลขผู้เสียภาษีของธนาคาร', _taxIdCtrl, digitsOnly: true),
              kTxt(e ? 'Tax branch (5 digits)' : 'สาขาภาษี (5 หลัก)', _taxBranchCtrl, digitsOnly: true),
            ], [3, 2]),
            kNote(e
                ? 'The tax ID is used as the seller on bank fee documents (CM 70)'
                : 'เลขผู้เสียภาษีใช้เป็นข้อมูลผู้ขายในเอกสารค่าธรรมเนียมธนาคาร (CM 70)'),
          ]),
        kGroup(bank ? 3 : 2, e ? 'Posting' : 'การลงบัญชี', ImKit.gFin, [
          kFk(
            label: e ? 'GL account *' : 'รหัสบัญชี GL *',
            text: _glText(e),
            hasValue: _glAccountId != null,
            onSearch: _pickGlAccount,
            onClear: () => setState(() {
              _glAccountId = null;
              _glAccountCode = null;
              _glAccountName = null;
              _glAccountNameEn = null;
            }),
          ),
          kFk(
            label: e ? 'Branch (GL posting)' : 'สาขา (ลงรายการบัญชี)',
            text: _branchLabel,
            hasValue: _branchId != null,
            onSearch: _pickBranch,
            onClear: () => setState(() {
              _branchId = null;
              _branchLabel = null;
            }),
          ),
          kNote(e ? 'Postable accounts only · the branch is used for bank FX revaluation entries' : 'แสดงเฉพาะบัญชีที่ลงรายการได้ · สาขาใช้ลงรายการตีราคา FX ธนาคาร'),
        ]),
        kGroup(bank ? 4 : 3, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([
            if (bank) kCk(e ? 'Issue / receive cheques' : 'ใช้ออก/รับเช็ค', _isCheckAccount, ro ? null : (v) => setState(() => _isCheckAccount = v)),
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v)),
          ]),
          kTxt(e ? 'Note' : 'หมายเหตุ', _remarkCtrl),
        ]),
      ]),
    );
  }

  // ─── บัญชี GL ตามประเภทการชำระเงิน ──────────────────────────────────────────────
  Widget _loadingOr(String title, String failText) => kCard(
        title: title,
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(failText),
      );

  Widget _glCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'GL account used for posting' : 'บัญชี GL ที่ใช้ลงบัญชี';
    if (s == null) return _loadingOr(title, e ? 'Could not load' : 'โหลดข้อมูลไม่ได้');
    final own = s.methods.where((m) => m.source == 'method').length;
    return kCard(
      title: title,
      count: e
          ? 'Order: payment method › bank account${own > 0 ? ' · $own method(s) use their own account' : ''}'
          : 'ลำดับที่ใช้: ประเภทการชำระเงิน › บัญชีธนาคาร${own > 0 ? ' · $own ประเภทตั้งบัญชีเอง' : ''}',
      trailing: kGhost(e ? 'Payment methods' : 'ประเภทการชำระเงิน', Icons.open_in_new,
          () => ImKit.openMenu(context, 'CmPaymentMethodScreen', 'ประเภทการชำระเงิน', 'Payment Method', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Payment method' : 'ประเภทการชำระเงิน', 5),
          KCol(e ? 'Account used' : 'บัญชีที่ใช้', 7),
          KCol(e ? 'From' : 'มาจาก', 4),
        ],
        [
          for (final m in s.methods)
            [
              kCell('${m.methodCode} ${m.name(e)}'),
              kCell(m.glText(e), mono: true),
              switch (m.source) {
                'method' => ImKit.chip(e ? 'Payment method' : 'ประเภทการชำระเงินตั้งเอง', ImKit.goldSoft, ImKit.amber),
                'bank' => ImKit.chip(e ? 'This bank account' : 'บัญชีธนาคารนี้', ImKit.okSoft, ImKit.ok),
                _ => ImKit.chip(e ? 'Not set' : 'ยังไม่ได้ตั้ง', ImKit.redSoft, ImKit.red),
              },
            ],
        ],
        rowColors: [for (final m in s.methods) m.source == 'method' ? const Color(0xFFFFFCF2) : null],
        minWidth: 640,
        empty: e ? 'No active payment methods' : 'ไม่มีประเภทการชำระเงินที่ใช้งาน',
      ),
    );
  }

  // ─── รายการเข้า-ออกล่าสุด ─────────────────────────────────────────────────────────
  String _methodLabel(String? t, bool e) => switch (t) {
        'CASH' => e ? 'Cash' : 'เงินสด',
        'CHECK' => e ? 'Cheque' : 'เช็ค',
        'TRANSFER' => e ? 'Transfer' : 'โอนเงิน',
        'BILL_OF_EXCHANGE' => e ? 'Bill of exchange' : 'ตั๋วแลกเงิน',
        'CREDIT_CARD' => e ? 'Credit card' : 'บัตรเครดิต',
        'DEBIT_CARD' => e ? 'Debit card' : 'บัตรเดบิต',
        'MOBILE_BANKING' => e ? 'Mobile banking' : 'โมบายแบงก์กิ้ง',
        null => '',
        _ => t,
      };

  Widget _recentCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'Latest 10 movements' : 'รายการเข้า-ออก 10 รายการล่าสุด';
    if (s == null) return _loadingOr(title, e ? 'Could not load' : 'โหลดข้อมูลไม่ได้');
    return kCard(
      title: title,
      count: e ? 'Read-only · base currency' : 'อ่านอย่างเดียว · สกุลหลัก',
      trailing: kGhost(e ? 'Bank transaction report' : 'รายงานธุรกรรมธนาคาร', Icons.open_in_new,
          () => ImKit.openMenu(context, 'CmBankTransactionReportScreen', 'รายงานธุรกรรมธนาคาร', 'Bank Transaction Report', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Date' : 'วันที่', 3),
          KCol(e ? 'Document' : 'เอกสาร', 4),
          KCol(e ? 'Payer / payee' : 'ผู้รับ/ผู้จ่าย', 6),
          KCol(e ? 'Method' : 'ช่องทาง', 4),
          KCol(e ? 'In' : 'เงินเข้า', 3, num: true),
          KCol(e ? 'Out' : 'เงินออก', 3, num: true),
          KCol(e ? 'Reconciled' : 'กระทบยอด', 3),
        ],
        [
          for (final r in s.recent)
            [
              kCell(r.date == null ? '' : _dateFmt.format(r.date!), mono: true),
              kCell(r.docNo ?? '', mono: true),
              kCell(r.party ?? ''),
              kCell([_methodLabel(r.methodType, e), if ((r.checkNo ?? '').isNotEmpty) r.checkNo!].join(' ')),
              kCell(r.isIn ? _money.format(r.amount) : ' ', mono: true),
              kCell(r.isIn ? ' ' : _money.format(r.amount), mono: true),
              r.reconciled
                  ? ImKit.chip(e ? 'Yes' : 'แล้ว', ImKit.okSoft, ImKit.ok)
                  : Text(e ? 'Not yet' : 'ยังไม่', style: const TextStyle(fontSize: 12.5, color: ImKit.ink3)),
            ],
        ],
        minWidth: 820,
        empty: e ? 'No movements yet' : 'ยังไม่มีรายการเข้า-ออก',
      ),
    );
  }

  // ─── สมุดเช็คของบัญชี ────────────────────────────────────────────────────────────
  Widget _bookStatus(String st, bool e) => switch (st) {
        'Active' => ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok),
        'Used' => ImKit.chip(e ? 'Used up' : 'ใช้หมดแล้ว', ImKit.ro, ImKit.ink2),
        'Cancelled' => ImKit.chip(e ? 'Cancelled' : 'ยกเลิก', ImKit.redSoft, ImKit.red),
        _ => ImKit.chip(st, ImKit.ro, ImKit.ink2),
      };

  Widget _checkbookCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'Chequebooks' : 'สมุดเช็คของบัญชีนี้';
    if (s == null) return _loadingOr(title, e ? 'Could not load' : 'โหลดข้อมูลไม่ได้');
    return kCard(
      title: '$title (${s.checkbooks.length})',
      count: e ? 'Read-only' : 'อ่านอย่างเดียว',
      trailing: kGhost(e ? 'Chequebooks' : 'ไปหน้าสมุดเช็ค', Icons.open_in_new,
          () => ImKit.openMenu(context, 'CmCheckbookScreen', 'สมุดเช็ค', 'Cheque Book', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Book' : 'เล่ม', 4),
          KCol(e ? 'Numbers' : 'เลขที่', 5),
          KCol(e ? 'Next' : 'ถัดไป', 3),
          KCol(e ? 'Left' : 'คงเหลือ', 2, num: true),
          KCol(e ? 'Status' : 'สถานะ', 3),
        ],
        [
          for (final b in s.checkbooks)
            [
              kCell(b.code, mono: true),
              kCell('${b.startNo}–${b.endNo}', mono: true),
              kCell(b.status == 'Active' ? (b.nextNo ?? '') : '', mono: true),
              kCell(b.remaining == null ? '' : '${b.remaining}', mono: true, color: b.status == 'Active' && (b.remaining ?? 99) < 10 ? ImKit.amber : null),
              _bookStatus(b.status, e),
            ],
        ],
        minWidth: 600,
        empty: e ? 'No chequebooks yet' : 'ยังไม่มีสมุดเช็ค',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    final net = s.unrecInAmount - s.unrecOutAmount;
    final check = _isCheckAccount && _cmType == 'BANK';
    return kKpis([
      ImKpi(e ? 'Balance today' : 'ยอดคงเหลือ ณ วันนี้', _money.format(s.balance),
          e ? 'opening + in − out + FX revaluation' : 'ยอดยกมา + เงินเข้า − เงินออก + ปรับมูลค่า FX',
          onTap: () => ImKit.openMenu(context, 'CmCashPositionReportScreen', 'รายงานสถานะเงินสด/เงินฝาก', 'Cash Position Report', e)),
      ImKpi(e ? 'Not reconciled' : 'ยังไม่กระทบยอด', '${s.unrecCount}',
          s.unrecCount == 0
              ? (e ? 'none' : 'ไม่มี')
              : (e
                  ? 'in ${s.unrecInCount} · out ${s.unrecOutCount} · net ${_money.format(net)}'
                  : 'เงินเข้า ${s.unrecInCount} · เงินออก ${s.unrecOutCount} · สุทธิ ${_money.format(net)}'),
          warn: s.unrecCount > 0,
          onTap: () => ImKit.openMenu(context, 'CmBankReconcileScreen', 'กระทบยอดบัญชีธนาคาร', 'Bank Reconciliation', e)),
      ImKpi(e ? 'Last reconciled' : 'กระทบยอดล่าสุด', s.lastReconcileDate == null ? '—' : _dateFmt.format(s.lastReconcileDate!),
          s.lastStatementTo == null
              ? (e ? 'no statement yet' : 'ยังไม่มีใบแจ้งยอด')
              : (e
                  ? 'statement to ${_dateFmt.format(s.lastStatementTo!)} · closing ${_money.format(s.lastStatementClosing ?? 0)}'
                  : 'ใบแจ้งยอดถึง ${_dateFmt.format(s.lastStatementTo!)} · ปิดยอด ${_money.format(s.lastStatementClosing ?? 0)}')),
      check
          ? ImKpi(e ? 'Cheques left' : 'เช็คคงเหลือ', e ? '${s.checksLeft}' : '${s.checksLeft} ใบ',
              s.activeBooks == 0
                  ? (e ? 'no active book' : 'ไม่มีเล่มที่ใช้งาน')
                  : (e ? '${s.activeBooks} active book(s) · next ${s.nextCheckNo ?? '—'}' : '${s.activeBooks} เล่มที่ใช้งาน · เลขถัดไป ${s.nextCheckNo ?? '—'}'),
              warn: s.checksLeft < 10)
          : ImKpi(e ? 'Cheques' : 'เช็ค', '—', e ? 'not a cheque account' : 'บัญชีนี้ไม่ใช้เช็ค'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.account_balance_outlined,
          e ? 'Select an account on the left, or press "Add account"' : 'เลือกบัญชีจากรายการด้านซ้าย หรือกด "เพิ่มบัญชี"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = e && _nameEn.text.trim().isNotEmpty ? _nameEn.text.trim() : _nameTh.text.trim();
    final bank = _cmType == 'BANK';
    final path = [
      _currencyCode,
      if (bank && _accountNumberCtrl.text.trim().isNotEmpty) _accountNumberCtrl.text.trim(),
    ].join(' · ');
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.accountCode,
        title: isAdd
            ? (_isCopy
                ? (e ? 'New account (copy of ${widget.copyFrom!.accountCode})' : 'บัญชีใหม่ (สำเนาจาก ${widget.copyFrom!.accountCode})')
                : (e ? 'New account' : 'บัญชีใหม่'))
            : name,
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          bank
              ? ImKit.chip(cmAccountTypeLabel(_accountType, e).split(' (').first, ImKit.blueSoft, ImKit.blue)
              : ImKit.chip(e ? 'Petty cash' : 'เงินสดย่อย', ImKit.goldSoft, ImKit.amber),
          if (bank && _isCheckAccount) ImKit.chip(e ? 'Cheque' : 'เช็ค', const Color(0xFFEFE8FB), const Color(0xFF5B3B9A)),
          Text(path, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (!ro) kEditingBadge(),
        ],
        busy: _isSaving,
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _submit,
          extra: [
            if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นบัญชีใหม่', widget.onCopy, fg: kInk),
          ],
        ),
      ),
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'GL account' : 'บัญชี GL', _glCard()),
        if (saved) (2, e ? 'Latest movements' : 'รายการล่าสุด', _recentCard()),
        if (saved && bank && _isCheckAccount) (3, e ? 'Chequebooks' : 'สมุดเช็ค', _checkbookCard()),
      ],
    );
  }
}
