// lib/cm/widgets/cm_payment_method_detail_widget.dart — ประเภทการชำระเงิน แบบ B ของ IM (user 2026-11-28)
//   แถบหัว + ตัวเลขสรุป (รับ/จ่ายเดือนนี้, ผู้ขายที่ใช้, บัญชี GL) + ลิงก์ข้ามส่วน
//   ส่วน: ข้อมูลประเภท (3 กลุ่มสี) / บัญชี GL ที่จะใช้ (ประเภทการชำระเงิน › บัญชีธนาคาร) / ผู้ขายที่ใช้เป็นช่องทางตั้งต้น
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_master_summary.dart';
import '../models/cm_payment_method.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_payment_method_service.dart';

class CmPaymentMethodDetailWidget extends StatefulWidget {
  final Mode mode;
  final CmPaymentMethod? selected;
  final CmPaymentMethod? copyFrom;
  final Future<void> Function(CmPaymentMethod) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  const CmPaymentMethodDetailWidget({
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
  State<CmPaymentMethodDetailWidget> createState() => CmPaymentMethodDetailWidgetState();
}

class CmPaymentMethodDetailWidgetState extends State<CmPaymentMethodDetailWidget> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _codeCtrl = TextEditingController();
  final _nameTh = TextEditingController();
  final _nameEn = TextEditingController();
  final _remarkCtrl = TextEditingController();

  String _methodType = 'CASH';
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountName;
  String? _glAccountNameEn;
  int? _bankAccountId;
  String? _bankAccountDisplay;
  bool _isActive = true;

  bool _isSaving = false;
  String _snapshot = '';

  CmMethodSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;

  static final _money = NumberFormat('#,##0.00');

  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  @override
  void initState() {
    super.initState();
    _applyCurrent();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant CmPaymentMethodDetailWidget oldWidget) {
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
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: !onlyFullLoad && sameRecord && widget.mode == Mode.view);
    if (!onlyFullLoad) kScrollTop();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameTh, _nameEn, _remarkCtrl]) {
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

  void _apply(CmPaymentMethod? d, {bool copy = false}) {
    _codeCtrl.text = copy ? '' : (d?.methodCode ?? '');
    _nameTh.text = d?.methodNameTh ?? '';
    _nameEn.text = d?.methodNameEn ?? '';
    _remarkCtrl.text = d?.remark ?? '';
    _methodType = d?.methodType ?? 'CASH';
    _glAccountId = d?.glAccountId;
    _glAccountCode = d?.glAccountCode;
    _glAccountName = d?.glAccountName;
    _glAccountNameEn = d?.glAccountNameEn;
    _bankAccountId = d?.cmBankAccountId;
    _bankAccountDisplay = _bankText(d);
    _isActive = copy ? true : (d?.isActive ?? true);
    _snapshot = copy ? '' : _fingerprint();
  }

  String? _bankText(CmPaymentMethod? d) {
    if (d?.cmBankAccountId == null) return null;
    final name = _isEnglish && (d!.bankAccountNameEn ?? '').isNotEmpty ? d.bankAccountNameEn! : (d!.bankAccountNameTh ?? '');
    return [
      d.bankAccountCode ?? '',
      name,
      if ((d.bankAccountNumber ?? '').isNotEmpty) '· ${d.bankAccountNumber}',
    ].where((x) => x.isNotEmpty).join(' ');
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
      final s = await CmPaymentMethodService().fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    }
    if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
  }

  CmPaymentMethod _build() => CmPaymentMethod(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        methodCode: _codeCtrl.text.trim().toUpperCase(),
        methodNameTh: _nameTh.text.trim(),
        methodNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        methodType: _methodType,
        glAccountId: _glAccountId,
        cmBankAccountId: _bankAccountId,
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      );

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
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the code' : 'โปรดระบุรหัส';
    } else if (_nameTh.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'โปรดระบุชื่อ (ไทย)';
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

  // บัญชี GL: เฉพาะบัญชีที่ลงรายการได้
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

  Future<void> _pickBankAccount() async {
    final e = _isEnglish;
    List<CmBankAccount> rows;
    try {
      rows = await Provider.of<CmBankAccountService>(context, listen: false).fetchRows();
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e ? 'Failed to load bank accounts' : 'โหลดข้อมูลบัญชีธนาคารล้มเหลว'}: $ex')));
      return;
    }
    final active = rows.where((b) => b.isActive).toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    if (!mounted) return;
    await _pickList<CmBankAccount>(
      title: e ? 'Select bank account' : 'เลือกบัญชีธนาคาร',
      items: active,
      code: (b) => b.accountCode,
      name: (b) => [b.name(e), if ((b.accountNumber ?? '').isNotEmpty) '· ${b.accountNumber}'].join(' '),
      search: (b) => '${b.accountCode} ${b.accountNameTh} ${b.accountNameEn ?? ''} ${b.accountNumber ?? ''} ${b.bankDisplay}',
      selected: (b) => b.id == _bankAccountId,
      onPick: (b) => setState(() {
        _bankAccountId = b.id;
        _bankAccountDisplay = [b.accountCode, b.name(e), if ((b.accountNumber ?? '').isNotEmpty) '· ${b.accountNumber}'].join(' ');
      }),
    );
  }

  // ─── ข้อมูลประเภท ────────────────────────────────────────────────────────────────
  String _fieldsHint(bool e) {
    const th = {
      'CASH': 'ข้อมูลที่ระบุเมื่อรับชำระ: จำนวนเงิน',
      'CHECK': 'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่เช็ค, วันที่เช็ค, ธนาคาร, สาขา, เลขที่บัญชี',
      'TRANSFER': 'ข้อมูลที่ระบุเมื่อรับชำระ: เลขอ้างอิงการโอน, ธนาคารต้นทาง, สาขา, วันที่โอน',
      'CREDIT_CARD': 'ข้อมูลที่ระบุเมื่อรับชำระ: ประเภทบัตร, 4 หลักท้าย, รหัสอนุมัติ, รหัสเครื่อง EDC, Batch No',
      'DEBIT_CARD': 'ข้อมูลที่ระบุเมื่อรับชำระ: ประเภทบัตร, 4 หลักท้าย, รหัสอนุมัติ, รหัสเครื่อง EDC, Batch No',
      'QR_CODE': 'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่อ้างอิง (Ref No), วันที่/เวลาชำระ',
      'MOBILE_BANKING': 'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่อ้างอิง (Ref No), ธนาคารต้นทาง, วันที่โอน',
      'BILL_OF_EXCHANGE': 'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่ตั๋ว, วันครบกำหนด, ธนาคาร',
      'OTHER': 'ข้อมูลที่ระบุเมื่อรับชำระ: เลขที่อ้างอิง, วันที่, หมายเหตุ',
    };
    const en = {
      'CASH': 'Fields captured on receipt: Amount',
      'CHECK': 'Fields captured on receipt: Cheque No., Cheque Date, Bank, Branch, Account No.',
      'TRANSFER': 'Fields captured on receipt: Transfer Ref No., Source Bank, Branch, Transfer Date',
      'CREDIT_CARD': 'Fields captured on receipt: Card Type, Last 4 Digits, Approval Code, EDC No., Batch No.',
      'DEBIT_CARD': 'Fields captured on receipt: Card Type, Last 4 Digits, Approval Code, EDC No., Batch No.',
      'QR_CODE': 'Fields captured on receipt: Ref No., Payment Date/Time',
      'MOBILE_BANKING': 'Fields captured on receipt: Ref No., Source Bank, Transfer Date',
      'BILL_OF_EXCHANGE': 'Fields captured on receipt: Bill No., Due Date, Bank',
      'OTHER': 'Fields captured on receipt: Ref No., Date, Note',
    };
    return (e ? en[_methodType] : th[_methodType]) ?? '';
  }

  String _glText(bool e) {
    if (_glAccountId == null) return '';
    final n = e && (_glAccountNameEn ?? '').isNotEmpty ? _glAccountNameEn! : (_glAccountName ?? '');
    return '${_glAccountCode ?? ''} $n'.trim();
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final card = ['CREDIT_CARD', 'DEBIT_CARD'].contains(_methodType);
    final types = {...cmMethodTypeOptions.keys, _methodType};
    return kCard(
      title: e ? 'Payment method details' : 'ข้อมูลประเภทการชำระเงิน',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Code *' : 'รหัส *', _codeCtrl, editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Type *' : 'ประเภท *', _methodType,
                [for (final k in types) DropdownMenuItem(value: k, child: Text(cmMethodTypeLabel(k, e), overflow: TextOverflow.ellipsis))],
                ro ? null : (v) => setState(() => _methodType = v ?? 'CASH'), auto: false),
          ]),
          kTxt(e ? 'Name (TH) *' : 'ชื่อ (ไทย) *', _nameTh),
          kTxt(e ? 'Name (EN)' : 'ชื่อ (อังกฤษ)', _nameEn),
          if (_fieldsHint(e).isNotEmpty) kNote(_fieldsHint(e), color: ImKit.blue),
        ]),
        kGroup(2, e ? 'Posting' : 'การลงบัญชี', ImKit.gFin, [
          kFk(
            label: card
                ? (e ? 'Default bank account (merchant account)' : 'บัญชีธนาคารตั้งต้น (บัญชีรับยอดบัตร)')
                : (e ? 'Default bank account' : 'บัญชีธนาคารตั้งต้น'),
            text: _bankAccountDisplay,
            hasValue: _bankAccountId != null,
            onSearch: _pickBankAccount,
            onClear: () => setState(() {
              _bankAccountId = null;
              _bankAccountDisplay = null;
            }),
          ),
          kFk(
            label: e ? 'GL account (instead of the bank account\'s)' : 'รหัสบัญชี GL (ถ้าต้องการแทนบัญชีของบัญชีธนาคาร)',
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
          kNote(e
              ? 'Leave empty to use the GL account of the bank account on the document · postable accounts only'
              : 'ว่างไว้ = ใช้บัญชี GL ของบัญชีธนาคารในเอกสาร · แสดงเฉพาะบัญชีที่ลงรายการได้'),
        ]),
        kGroup(3, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v))]),
          kTxt(e ? 'Note' : 'หมายเหตุ', _remarkCtrl),
        ]),
      ]),
    );
  }

  Widget _loadingOr(String title) => kCard(
        title: title,
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(_isEnglish ? 'Could not load' : 'โหลดข้อมูลไม่ได้'),
      );

  // ─── บัญชี GL ที่จะใช้ ────────────────────────────────────────────────────────────
  Widget _glCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'GL account that will be used' : 'บัญชี GL ที่จะใช้';
    if (s == null) return _loadingOr(title);
    final own = _glAccountId != null;
    final examples = s.bankAccounts.map((b) => '${b.code} → ${b.glCode ?? (e ? 'not set' : 'ยังไม่ได้ตั้ง')}').join(', ');
    return kCard(
      title: title,
      count: e ? 'Order: payment method › bank account' : 'ลำดับที่ใช้: ประเภทการชำระเงิน › บัญชีธนาคาร',
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable(
          [
            KCol(e ? 'Level' : 'ระดับ', 4),
            KCol(e ? 'Account' : 'บัญชี', 9),
            KCol(e ? 'Status' : 'สถานะ', 3),
          ],
          [
            [
              kCell(e ? 'This payment method' : 'ประเภทการชำระเงินนี้'),
              kCell(own ? _glText(e) : '', mono: true),
              own
                  ? ImKit.chip(e ? 'Used' : 'ใช้ระดับนี้', ImKit.okSoft, ImKit.ok)
                  : Text(e ? 'Skipped' : 'ข้าม', style: const TextStyle(fontSize: 12.5, color: ImKit.ink3)),
            ],
            [
              kCell(e ? 'Bank account on the document' : 'บัญชีธนาคารในเอกสาร'),
              kCell(e ? 'By the chosen account, e.g. $examples' : 'ตามบัญชีที่เลือก เช่น $examples'),
              own
                  ? Text(e ? 'Not used' : 'ไม่ได้ใช้', style: const TextStyle(fontSize: 12.5, color: ImKit.ink3))
                  : ImKit.chip(e ? 'Used' : 'ใช้ระดับนี้', ImKit.okSoft, ImKit.ok),
            ],
          ],
          rowColors: [own ? const Color(0xFFFFFCF2) : null, own ? null : const Color(0xFFFFFCF2)],
          minWidth: 620,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: kNote(e
              ? 'AR receipts and AP payments use the same order; if neither is set they fall back to the cash account in the GL setup'
              : 'ใบรับชำระ AR และใบจ่ายชำระ AP ใช้ลำดับเดียวกัน ถ้าไม่ได้ตั้งทั้งสองระดับจะใช้บัญชีเงินสดในหน้าเชื่อมบัญชี GL'),
        ),
      ]),
    );
  }

  // ─── ผู้ขายที่ใช้เป็นช่องทางตั้งต้น ────────────────────────────────────────────────
  Widget _vendorsCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'Vendors using it as default' : 'ผู้ขายที่ใช้เป็นช่องทางตั้งต้น';
    if (s == null) return _loadingOr(title);
    return kCard(
      title: '$title (${s.vendorCount})',
      count: s.vendorCount > s.vendors.length
          ? (e ? 'Read-only · first ${s.vendors.length}' : 'อ่านอย่างเดียว · ${s.vendors.length} รายแรก')
          : (e ? 'Read-only' : 'อ่านอย่างเดียว'),
      trailing: kGhost(e ? 'Vendors' : 'ข้อมูลผู้ขาย', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ApVendorScreen', 'ข้อมูลผู้ขาย', 'Vendors', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Code' : 'รหัส', 3),
          KCol(e ? 'Vendor name' : 'ชื่อผู้ขาย', 7),
          KCol(e ? 'Group' : 'กลุ่ม', 2),
          KCol(e ? 'Main bank account' : 'บัญชีรับโอนหลัก', 6),
        ],
        [
          for (final v in s.vendors)
            [
              kCell(v.code, mono: true, color: v.isActive ? null : ImKit.ink3),
              kCell(v.name(e), color: v.isActive ? null : ImKit.ink3),
              kCell(v.groupCode ?? '', mono: true),
              (v.accountNumber ?? '').isEmpty
                  ? kCell(e ? 'No bank account' : 'ไม่มีบัญชีธนาคาร', color: ImKit.red)
                  : kCell('${v.bankName ?? ''} ${v.accountNumber}'.trim(), mono: true),
            ],
        ],
        minWidth: 640,
        empty: e ? 'No vendor uses this payment method as default' : 'ยังไม่มีผู้ขายตั้งช่องทางนี้เป็นค่าตั้งต้น',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    return kKpis([
      ImKpi(e ? 'Received this month' : 'รับเงินเดือนนี้', _money.format(s.monthInAmount), e ? '${s.monthInCount} item(s)' : '${s.monthInCount} รายการ'),
      ImKpi(e ? 'Paid this month' : 'จ่ายเงินเดือนนี้', _money.format(s.monthOutAmount), e ? '${s.monthOutCount} item(s)' : '${s.monthOutCount} รายการ'),
      ImKpi(e ? 'Vendors using as default' : 'ผู้ขายที่ใช้เป็นค่าตั้งต้น', '${s.vendorCount}', e ? 'of ${s.vendorTotal}' : 'จาก ${s.vendorTotal} ราย'),
      ImKpi(e ? 'GL account' : 'บัญชี GL', s.glSource == 'method' ? (s.glCode ?? '') : (e ? 'By bank account' : 'ตามบัญชีธนาคาร'),
          s.glSource == 'method' ? s.glText(e).replaceFirst('${s.glCode} ', '') : (e ? 'not set on the method' : 'ไม่ได้ตั้งบัญชีเอง')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.payments_outlined,
          e ? 'Select a payment method on the left, or press "Add method"' : 'เลือกประเภทการชำระเงินจากรายการด้านซ้าย หรือกด "เพิ่มประเภท"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = e && _nameEn.text.trim().isNotEmpty ? _nameEn.text.trim() : _nameTh.text.trim();
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.methodCode,
        title: isAdd
            ? (_isCopy
                ? (e ? 'New payment method (copy of ${widget.copyFrom!.methodCode})' : 'ประเภทใหม่ (สำเนาจาก ${widget.copyFrom!.methodCode})')
                : (e ? 'New payment method' : 'ประเภทการชำระเงินใหม่'))
            : name,
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          ImKit.chip(cmMethodTypeLabel(_methodType, e).split(' (').first, ImKit.blueSoft, ImKit.blue),
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
            if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นประเภทใหม่', widget.onCopy, fg: kInk),
          ],
        ),
      ),
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'Posting' : 'การลงบัญชี', _glCard()),
        if (saved) (2, e ? 'Vendors' : 'ผู้ขายที่ใช้', _vendorsCard()),
      ],
    );
  }
}
