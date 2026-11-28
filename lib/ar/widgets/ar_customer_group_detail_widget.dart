// widgets/ar_customer_group_detail_widget.dart — กลุ่มลูกค้า แบบ B ของ IM (user 2026-11-28)
//   แถบหัว (รหัส ชื่อ ป้าย / ปุ่ม) + ตัวเลขสรุป + ลิงก์ข้ามส่วน + เลื่อนหน้าเดียว
//   ส่วน: ข้อมูลกลุ่ม (3 กลุ่มสี) / รหัสลูกค้าอัตโนมัติ (ตัวอย่างรหัส) / วางบิลและรับชำระ / ลูกค้าในกลุ่ม
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../models/ar_customer_summary.dart';
import '../services/ar_customer_group_service.dart';
import 'ar_customer_detail_widget.dart' show showBillingConditionDialog, showPaymentConditionDialog;

class ArCustomerGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCustomerGroup? selected;
  final Function(ArCustomerGroup) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ArCustomerGroupDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ArCustomerGroupDetailWidget> createState() => ArCustomerGroupDetailWidgetState();
}

class ArCustomerGroupDetailWidgetState extends State<ArCustomerGroupDetailWidget> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _discCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _sepCtrl = TextEditingController();
  final _lenCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  bool _isActive = true;
  bool _isAutoNumber = false;
  String _suffixDate = '';
  bool _requiresBilling = false;
  List<ArCustomerBillingCondition> _billing = [];
  List<ArCustomerPaymentCondition> _payment = [];
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountNameThai;
  String? _glAccountNameEng;

  bool _isSaving = false;
  String _snapshot = '';

  ArCustomerGroupSummary? _summary;
  ArCodePreview? _preview;
  bool _summaryLoading = false;
  int? _summaryFor;

  static final _money = NumberFormat('#,##0.00');

  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply(widget.mode == Mode.add ? null : widget.selected);
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant ArCustomerGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq) return;
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    final onlyFullLoad = sameRecord && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq;
    _apply(widget.mode == Mode.add ? null : widget.selected);
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: !onlyFullLoad && sameRecord && widget.mode == Mode.view);
    if (!onlyFullLoad) kScrollTop();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameThCtrl, _nameEnCtrl, _descCtrl, _monthsCtrl, _daysCtrl, _limitCtrl, _discCtrl, _prefixCtrl, _sepCtrl, _lenCtrl, _nextCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(ArCustomerGroup? d) {
    _codeCtrl.text = d?.groupCode ?? '';
    _nameThCtrl.text = d?.groupNameThai ?? '';
    _nameEnCtrl.text = d?.groupNameEng ?? '';
    _descCtrl.text = d?.description ?? '';
    _monthsCtrl.text = (d?.creditTermMonths ?? 0).toString();
    _daysCtrl.text = (d?.creditTermDays ?? 30).toString();
    _limitCtrl.text = (d?.creditLimit ?? 0).toStringAsFixed(2);
    _discCtrl.text = (d?.discountPercent ?? 0).toStringAsFixed(2);
    _isActive = d?.isActive ?? true;
    _isAutoNumber = d?.isAutoNumber ?? false;
    _prefixCtrl.text = d?.runningPrefix ?? 'CUST';
    _sepCtrl.text = d?.runningSeparator ?? '-';
    _suffixDate = d?.runningSuffixDate ?? '';
    _lenCtrl.text = (d?.runningLength ?? 4).toString();
    _nextCtrl.text = (d?.runningNextNumber ?? 1).toString();
    _requiresBilling = d?.requiresBilling ?? false;
    _billing = List.from(d?.billingConditions ?? const <ArCustomerBillingCondition>[]);
    _payment = List.from(d?.paymentConditions ?? const <ArCustomerPaymentCondition>[]);
    _glAccountId = d?.glAccountId;
    _glAccountCode = d?.glAccountCode;
    _glAccountNameThai = d?.glAccountNameThai;
    _glAccountNameEng = null;
    _snapshot = _fingerprint();
  }

  Future<void> _loadSummary({bool force = false}) async {
    final id = widget.mode == Mode.add ? null : widget.selected?.id;
    if (id == null) {
      _summary = null;
      _preview = null;
      _summaryFor = null;
      return;
    }
    if (!force && _summaryFor == id && _summary != null) return;
    _summaryFor = id;
    _summaryLoading = true;
    final svc = Provider.of<ArCustomerGroupService>(context, listen: false);
    try {
      final s = await svc.fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    }
    try {
      final p = widget.selected?.isAutoNumber == true ? await svc.fetchCodePreview(id) : null;
      if (mounted && _summaryFor == id) setState(() => _preview = p);
    } catch (_) {}
    if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
  }

  ArCustomerGroup _build() => ArCustomerGroup(
        id: widget.mode == Mode.add ? 0 : (widget.selected?.id ?? 0),
        groupCode: _codeCtrl.text.trim().toUpperCase(),
        groupNameThai: _nameThCtrl.text.trim(),
        groupNameEng: _nameEnCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        creditTermMonths: int.tryParse(_monthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_daysCtrl.text) ?? 30,
        creditLimit: double.tryParse(_limitCtrl.text) ?? 0,
        discountPercent: double.tryParse(_discCtrl.text) ?? 0,
        glAccountId: _glAccountId,
        glAccountCode: _glAccountCode,
        glAccountNameThai: _glAccountNameThai,
        isAutoNumber: _isAutoNumber,
        runningPrefix: _prefixCtrl.text.trim(),
        runningSeparator: _sepCtrl.text,
        runningSuffixDate: _suffixDate,
        runningLength: int.tryParse(_lenCtrl.text) ?? 4,
        runningNextNumber: int.tryParse(_nextCtrl.text) ?? 1,
        isActive: _isActive,
        requiresBilling: _requiresBilling,
        billingConditions: List.from(_billing),
        paymentConditions: List.from(_payment),
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
    final disc = double.tryParse(_discCtrl.text);
    final len = int.tryParse(_lenCtrl.text);
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the customer group code' : 'โปรดระบุรหัสกลุ่มลูกค้า';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'โปรดระบุชื่อภาษาไทย';
    } else if (double.tryParse(_limitCtrl.text) == null) {
      err = e ? 'Credit limit must be a number' : 'วงเงินเครดิตต้องเป็นตัวเลข';
    } else if (disc == null || disc < 0 || disc > 100) {
      err = e ? 'Discount must be 0-100' : 'ส่วนลดต้องอยู่ระหว่าง 0-100';
    } else if (_isAutoNumber && (len == null || len < 1 || len > 10)) {
      err = e ? 'Digit length must be 1-10' : 'ความยาวตัวเลขต้องเป็น 1-10';
    } else if (_isAutoNumber && int.tryParse(_nextCtrl.text) == null) {
      err = e ? 'Next number must be a number' : 'เลขที่ถัดไปต้องเป็นตัวเลข';
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

  // ─── บัญชีลูกหนี้ของกลุ่ม: บัญชีคุม (control) ที่ลงรายการได้เท่านั้น ─────────────────────
  Future<void> _pickGlAccount() async {
    final e = _isEnglish;
    final svc = Provider.of<AccountService>(context, listen: false);
    List<Account> accounts = [];
    try {
      final all = await svc.fetchRows();
      accounts = all.where((a) => a.isControlAccount && a.isNormalAccount && a.isActive).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    } catch (_) {}
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(accounts);
    String nm(Account a) => e && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(e ? 'Select receivable account' : 'เลือกบัญชีลูกหนี้'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: e ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = accounts
                      .where((a) => a.accountCode.toLowerCase().contains(lq) ||
                          a.accountNameThai.toLowerCase().contains(lq) ||
                          a.accountNameEng.toLowerCase().contains(lq))
                      .toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(e ? 'No accounts found' : 'ไม่พบบัญชี'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final a = filtered[i];
                          final sel = _glAccountId == a.id;
                          return ListTile(
                            dense: true,
                            selected: sel,
                            leading: sel ? Icon(Icons.check_circle, color: kInk, size: 18) : const SizedBox(width: 18),
                            title: Row(children: [
                              SizedBox(width: 90, child: Text(a.accountCode, style: TextStyle(fontWeight: FontWeight.bold, color: kInk))),
                              Expanded(child: Text(nm(a))),
                              Text(accountTypeLabel(a.accountType, e), style: const TextStyle(fontSize: 11, color: ImKit.ink3)),
                            ]),
                            onTap: () {
                              setState(() {
                                _glAccountId = a.id;
                                _glAccountCode = a.accountCode;
                                _glAccountNameThai = a.accountNameThai;
                                _glAccountNameEng = a.accountNameEng;
                              });
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

  // ─── รหัสอัตโนมัติ ─────────────────────────────────────────────────────────────
  List<DropdownMenuItem<String>> _suffixOptions(bool e) => [
        DropdownMenuItem(value: '', child: Text(e ? '— No date —' : '— ไม่มีวันที่ —')),
        DropdownMenuItem(value: 'YY', child: Text(e ? 'YY (e.g. 25)' : 'YY (เช่น 25)')),
        DropdownMenuItem(value: 'YYYY', child: Text(e ? 'YYYY (e.g. 2025)' : 'YYYY (เช่น 2025)')),
        DropdownMenuItem(value: 'YYMM', child: Text(e ? 'YYMM (e.g. 2503)' : 'YYMM (เช่น 2503)')),
        DropdownMenuItem(value: 'YYYYMM', child: Text(e ? 'YYYYMM (e.g. 202503)' : 'YYYYMM (เช่น 202503)')),
        DropdownMenuItem(value: 'YYMMDD', child: Text(e ? 'YYMMDD (e.g. 250315)' : 'YYMMDD (เช่น 250315)')),
      ];

  String _datePart() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return switch (_suffixDate) {
      'YY' => y.substring(2),
      'YYYY' => y,
      'YYMM' => y.substring(2) + m,
      'YYYYMM' => y + m,
      'YYMMDD' => y.substring(2) + m + d,
      _ => '',
    };
  }

  String _numPart(int offset) {
    final len = int.tryParse(_lenCtrl.text) ?? 4;
    final next = int.tryParse(_nextCtrl.text) ?? 1;
    return (next + offset).toString().padLeft(len.clamp(1, 10), '0');
  }

  Widget _codeSample() {
    TextSpan part(String t, Color c) => TextSpan(text: t, style: TextStyle(color: c, fontWeight: FontWeight.bold));
    return Text.rich(
      TextSpan(style: const TextStyle(fontSize: 20, letterSpacing: 1, fontFeatures: [FontFeature.tabularFigures()]), children: [
        part(_prefixCtrl.text, ImKit.gDoc),
        part(_datePart(), ImKit.gFin),
        part(_sepCtrl.text, ImKit.ink3),
        part(_numPart(0), ImKit.gParty),
      ]),
    );
  }

  Widget _autoNumberCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final p = _preview;
    final saved = widget.selected;
    // ค่าในฟอร์มยังตรงกับที่บันทึก → ใช้ตัวอย่างจาก server (ข้ามรหัสที่มีลูกค้าใช้แล้ว)
    final formSame = saved != null &&
        widget.mode != Mode.add &&
        saved.isAutoNumber == _isAutoNumber &&
        saved.runningPrefix == _prefixCtrl.text.trim() &&
        saved.runningSeparator == _sepCtrl.text &&
        saved.runningSuffixDate == _suffixDate &&
        saved.runningLength == (int.tryParse(_lenCtrl.text) ?? -1) &&
        saved.runningNextNumber == (int.tryParse(_nextCtrl.text) ?? -1);
    final next = formSame && p != null && p.nextCodes.isNotEmpty
        ? p.nextCodes
        : [for (var i = 0; i < 3; i++) '${_prefixCtrl.text}${_datePart()}${_sepCtrl.text}${_numPart(i)}'];
    return kCard(
      title: e ? 'Auto customer code' : 'รหัสลูกค้าอัตโนมัติ',
      count: _isAutoNumber
          ? (e ? 'Customers added to this group get a code on save' : 'ลูกค้าที่เพิ่มในกลุ่มนี้ได้รหัสอัตโนมัติเมื่อบันทึก')
          : (e ? 'Off — uses the global customer code setting, or entered by hand' : 'ปิด — ใช้รหัสลูกค้าอัตโนมัติของระบบ หรือกรอกเอง'),
      trailing: kCk(e ? 'Use auto code for this group' : 'ออกรหัสอัตโนมัติสำหรับกลุ่มนี้', _isAutoNumber,
          ro ? null : (v) => setState(() => _isAutoNumber = v)),
      collapsed: !_isAutoNumber,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kRow([
          kTxt(e ? 'Prefix' : 'อักษรนำหน้า', _prefixCtrl, cap: TextCapitalization.characters),
          kDd<String>(e ? 'Date in code' : 'วันที่ในรหัส', _suffixDate, _suffixOptions(e),
              ro ? null : (v) => setState(() => _suffixDate = v ?? ''), auto: false),
          kTxt(e ? 'Separator' : 'ตัวคั่น', _sepCtrl),
          kTxt(e ? 'Digits' : 'จำนวนหลัก', _lenCtrl, digitsOnly: true, numeric: true),
          kTxt(e ? 'Next number' : 'เลขถัดไป', _nextCtrl, digitsOnly: true, numeric: true),
        ], [3, 4, 2, 2, 2]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: kTheme.soft, borderRadius: BorderRadius.circular(8)),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 18, runSpacing: 8, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(e ? 'Sample' : 'ตัวอย่างรหัส', style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
              _codeSample(),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(e ? 'Next 3 codes' : 'รหัสถัดไป 3 รหัส', style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
              Text(next.join('  ·  '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
            ]),
            if (p?.lastCode != null)
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(e ? 'Last code issued' : 'รหัสล่าสุดที่ออก', style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
                Text(p!.lastCode!, style: const TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
          ]),
        ),
        const SizedBox(height: 8),
        kNote(e
            ? 'Codes already used by a customer are skipped automatically.${formSame ? '' : ' Next codes are calculated from the form; existing codes are checked on save.'}'
            : 'รหัสที่มีลูกค้าใช้แล้วจะถูกข้ามไปเลขถัดไปอัตโนมัติ${formSame ? '' : ' — รหัสถัดไปคำนวณจากค่าในฟอร์ม ระบบตรวจรหัสซ้ำตอนบันทึกลูกค้า'}'),
      ]),
    );
  }

  // ─── ข้อมูลกลุ่ม ────────────────────────────────────────────────────────────────
  String _accText(bool e) {
    if (_glAccountId == null) return '';
    final n = e && (_glAccountNameEng?.isNotEmpty ?? false) ? _glAccountNameEng! : (_glAccountNameThai ?? '');
    return '${_glAccountCode ?? ''} $n'.trim();
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final s = _summary;
    return kCard(
      title: e ? 'Group details' : 'ข้อมูลกลุ่ม',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kTxt(e ? 'Group code *' : 'รหัสกลุ่ม *', _codeCtrl, editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
          kTxt(e ? 'Group name (TH) *' : 'ชื่อกลุ่ม (ไทย) *', _nameThCtrl),
          kTxt(e ? 'Group name (EN)' : 'ชื่อกลุ่ม (อังกฤษ)', _nameEnCtrl),
          kTxt(e ? 'Description' : 'คำอธิบาย', _descCtrl),
        ]),
        kGroup(2, e ? 'Defaults for customers' : 'ค่าตั้งต้นให้ลูกค้า', ImKit.gFin, [
          kRow([
            kTxt(e ? 'Credit (months)' : 'เครดิต (เดือน)', _monthsCtrl, digitsOnly: true, numeric: true),
            kTxt(e ? 'Credit (days)' : 'เครดิต (วัน)', _daysCtrl, digitsOnly: true, numeric: true),
          ]),
          kRow([
            kTxt(e ? 'Credit limit' : 'วงเงินเครดิต', _limitCtrl, numeric: true),
            kTxt(e ? 'Discount %' : 'ส่วนลด %', _discCtrl, numeric: true),
          ]),
          kFk(
            label: e ? 'Receivable account' : 'บัญชีลูกหนี้',
            text: _accText(e),
            hasValue: _glAccountId != null,
            onSearch: _pickGlAccount,
            onClear: () => setState(() {
              _glAccountId = null;
              _glAccountCode = null;
              _glAccountNameThai = null;
              _glAccountNameEng = null;
            }),
          ),
          kNote(e
              ? 'Order used when posting: customer › group › document type${s != null && s.ownAccountCount > 0 ? ' — ${s.ownAccountCount} customer(s) set their own account and do not use this one' : ''}'
              : 'ลำดับตอนลงบัญชี: ลูกค้า › กลุ่ม › ประเภทเอกสาร${s != null && s.ownAccountCount > 0 ? ' — ลูกค้า ${s.ownAccountCount} รายตั้งบัญชีเอง จึงไม่ใช้บัญชีนี้' : ''}'),
          kNote(e
              ? 'Values are copied to a customer when the group is chosen; changing them here does not change existing customers'
              : 'ค่าเหล่านี้คัดลอกไปที่ลูกค้าตอนเลือกกลุ่ม แก้ที่นี่ไม่เปลี่ยนลูกค้าที่มีอยู่แล้ว'),
        ]),
        kGroup(3, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v)),
            kCk(e ? 'Requires billing before payment' : 'ต้องวางบิลก่อนรับชำระ', _requiresBilling,
                ro ? null : (v) => setState(() => _requiresBilling = v)),
          ]),
        ]),
      ]),
    );
  }

  // ─── วางบิลและรับชำระ ──────────────────────────────────────────────────────────
  Widget _delBtn(VoidCallback onTap) => kIconBtn(Icons.delete_outline, _isEnglish ? 'Remove' : 'ลบ', onTap, color: ImKit.red);

  Widget _conditionsCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final rows = <List<Widget>>[];
    final taps = <VoidCallback?>[];
    for (var i = 0; i < _billing.length; i++) {
      final b = _billing[i];
      rows.add([
        ImKit.chip(e ? 'Billing' : 'วางบิล', ImKit.blueSoft, ImKit.blue),
        kCell('${i + 1}', mono: true),
        Text(_billingSummary(b, e), style: const TextStyle(fontSize: 12.5)),
        ro
            ? const SizedBox.shrink()
            : _delBtn(() => setState(() {
                  _billing.removeAt(i);
                  for (var j = 0; j < _billing.length; j++) {
                    _billing[j] = _billing[j].copyWith(sortOrder: j + 1);
                  }
                })),
      ]);
      taps.add(() async {
        final r = await showBillingConditionDialog(context, b, ro);
        if (r != null && !ro) setState(() => _billing[i] = r);
      });
    }
    for (var i = 0; i < _payment.length; i++) {
      final p = _payment[i];
      rows.add([
        ImKit.chip(e ? 'Payment' : 'รับชำระ', ImKit.okSoft, ImKit.ok),
        kCell('${i + 1}', mono: true),
        Text(_paymentSummary(p, e), style: const TextStyle(fontSize: 12.5)),
        ro
            ? const SizedBox.shrink()
            : _delBtn(() => setState(() {
                  _payment.removeAt(i);
                  for (var j = 0; j < _payment.length; j++) {
                    _payment[j] = _payment[j].copyWith(sortOrder: j + 1);
                  }
                })),
      ]);
      taps.add(() async {
        final r = await showPaymentConditionDialog(context, p, ro);
        if (r != null && !ro) setState(() => _payment[i] = r);
      });
    }
    return kCard(
      title: e ? 'Billing and payment' : 'วางบิลและรับชำระ',
      count: e ? 'Copied to a customer when this group is chosen' : 'คัดลอกไปที่ลูกค้าตอนเลือกกลุ่มนี้',
      trailing: ro
          ? null
          : Wrap(spacing: 6, children: [
              kGhost(e ? 'Billing' : 'วางบิล', Icons.add, () async {
                final r = await showBillingConditionDialog(context, null, false);
                if (r != null) setState(() => _billing.add(r.copyWith(sortOrder: _billing.length + 1)));
              }),
              kGhost(e ? 'Payment' : 'รับชำระ', Icons.add, () async {
                final r = await showPaymentConditionDialog(context, null, false);
                if (r != null) setState(() => _payment.add(r.copyWith(sortOrder: _payment.length + 1)));
              }),
            ]),
      padding: EdgeInsets.zero,
      child: kTable(
        [KCol(e ? 'Condition' : 'เงื่อนไข', 2), KCol(e ? 'No.' : 'ลำดับ', 1), KCol(e ? 'Details' : 'รายละเอียด', 10), const KCol('', 1)],
        rows,
        onTap: taps,
        minWidth: 640,
        rowMinHeight: 40,
        empty: e ? 'No conditions — payment date follows the due date' : 'ยังไม่มีเงื่อนไข — วันรับชำระเท่ากับวันครบกำหนด',
      ),
    );
  }

  String _billingSummary(ArCustomerBillingCondition b, bool e) {
    final dayNames = e ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] : const ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    final weekNames = e ? const {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'} : const {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (b.billWithDelivery) parts.add(e ? 'Bill with delivery' : 'วางบิลพร้อมส่งของ');
    if (b.billingDayOfMonth.isNotEmpty) {
      parts.add(b.billingDayOfMonth.map((d) => d == 31 ? (e ? 'End of month' : 'สิ้นเดือน') : (e ? 'Day $d' : 'วันที่ $d')).join(', '));
    }
    if (b.billingDayOfWeek.isNotEmpty) parts.add((e ? '' : 'วัน') + b.billingDayOfWeek.map((d) => dayNames[d]).join('-'));
    if (b.billingWeekOfMonth.isNotEmpty) {
      parts.add((e ? 'Week ' : 'สัปดาห์') + b.billingWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/'));
    }
    if (b.billingTimeFrom != null || b.billingTimeTo != null) parts.add('${b.billingTimeFrom ?? ''}–${b.billingTimeTo ?? ''}');
    if (b.dueFromBillingDate) parts.add(e ? 'Due from billing date' : 'ครบกำหนดนับจากวันวางบิล');
    return parts.isEmpty ? (e ? '(No condition specified)' : '(ไม่ระบุเงื่อนไข)') : parts.join('  ·  ');
  }

  String _paymentSummary(ArCustomerPaymentCondition p, bool e) {
    final dayNames = e ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] : const ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    final weekNames = e ? const {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'} : const {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (p.paymentDayOfMonth.isNotEmpty) {
      parts.add(p.paymentDayOfMonth.map((d) => d == 31 ? (e ? 'End of month' : 'สิ้นเดือน') : (e ? 'Day $d' : 'วันที่ $d')).join(', '));
    }
    if (p.paymentDayOfWeek.isNotEmpty) parts.add((e ? '' : 'วัน') + p.paymentDayOfWeek.map((d) => dayNames[d]).join('-'));
    if (p.paymentWeekOfMonth.isNotEmpty) {
      parts.add((e ? 'Week ' : 'สัปดาห์') + p.paymentWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/'));
    }
    if (p.withinMonthsFromBilling > 0) {
      parts.add(e ? 'Within ${p.withinMonthsFromBilling} month(s) of billing' : 'ภายใน ${p.withinMonthsFromBilling} เดือนจากวางบิล');
    }
    if (p.additionalDays != 0) parts.add(e ? '+${p.additionalDays} day(s)' : '+${p.additionalDays} วัน');
    if (p.paymentTimeFrom != null || p.paymentTimeTo != null) parts.add('${p.paymentTimeFrom ?? ''}–${p.paymentTimeTo ?? ''}');
    return parts.isEmpty ? (e ? '(No condition specified)' : '(ไม่ระบุเงื่อนไข)') : parts.join('  ·  ');
  }

  // ─── ลูกค้าในกลุ่ม ───────────────────────────────────────────────────────────────
  Widget _customersCard() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) {
      return kCard(
        title: e ? 'Customers in this group' : 'ลูกค้าในกลุ่ม',
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(e ? 'Could not load customers' : 'โหลดรายชื่อลูกค้าไม่ได้'),
      );
    }
    String term(ArGroupCustomer c) => c.creditTermMonths > 0
        ? (e ? '${c.creditTermMonths} mo ${c.creditTermDays} d' : '${c.creditTermMonths} ด. ${c.creditTermDays} ว.')
        : (e ? '${c.creditTermDays} days' : '${c.creditTermDays} วัน');
    Color? own(bool same) => same ? null : ImKit.amber;
    return kCard(
      title: e ? 'Customers in this group' : 'ลูกค้าในกลุ่ม',
      count: e
          ? '${s.customerCount} · ${s.ownTermsCount} with their own credit/discount (amber)'
          : '${s.customerCount} ราย · ตั้งเครดิต/วงเงิน/ส่วนลดเอง ${s.ownTermsCount} ราย (สีส้ม)',
      trailing: kGhost(e ? 'Customers' : 'ข้อมูลลูกค้า', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ArCustomerScreen', 'ข้อมูลลูกค้า', 'Customers', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Code' : 'รหัส', 3),
          KCol(e ? 'Name' : 'ชื่อลูกค้า', 7),
          KCol(e ? 'Credit' : 'เครดิต', 3),
          KCol(e ? 'Limit' : 'วงเงิน', 3, num: true),
          KCol(e ? 'Disc. %' : 'ส่วนลด %', 2, num: true),
          KCol(e ? 'Outstanding' : 'ยอดค้าง', 3, num: true),
          KCol(e ? 'Values' : 'ค่าที่ใช้', 3),
        ],
        [
          for (final c in s.customers)
            [
              kCell(c.code, mono: true, color: c.isActive ? null : ImKit.ink3),
              kCell(c.name(e), color: c.isActive ? null : ImKit.ink3),
              kCell(term(c), color: own(c.sameTerm)),
              kCell(_money.format(c.creditLimit), mono: true, color: own(c.sameLimit)),
              kCell(c.discountPercent.toStringAsFixed(2), mono: true, color: own(c.sameDiscount)),
              kCell(c.outstanding.abs() < 0.005 ? '' : _money.format(c.outstanding), mono: true, color: c.overdue > 0.005 ? ImKit.red : null),
              c.usesGroup ? ImKit.chip(e ? 'Group' : 'ของกลุ่ม', ImKit.blueSoft, ImKit.blue) : ImKit.chip(e ? 'Own' : 'ตั้งเอง', ImKit.goldSoft, ImKit.amber),
            ],
        ],
        minWidth: 820,
        empty: e ? 'No customers in this group yet' : 'ยังไม่มีลูกค้าในกลุ่มนี้',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    return kKpis([
      ImKpi(e ? 'Customers' : 'ลูกค้าในกลุ่ม', '${s.customerCount}', e ? '${s.activeCount} active' : 'ใช้งาน ${s.activeCount} ราย'),
      ImKpi(e ? 'Outstanding' : 'ยอดค้างรวม', _money.format(s.outstanding), e ? 'base currency' : 'สกุลหลัก'),
      ImKpi(e ? 'Overdue' : 'เกินกำหนด', _money.format(s.overdue),
          s.overdueCustomers == 0 ? (e ? 'none' : 'ไม่มี') : (e ? '${s.overdueCustomers} customer(s)' : '${s.overdueCustomers} ราย'),
          warn: s.overdue > 0.005,
          onTap: () => ImKit.openMenu(context, 'ArAgingReportScreen', 'รายงานอายุลูกหนี้', 'AR Aging Report', e)),
      ImKpi(e ? 'Own settings' : 'ตั้งค่าเอง', '${s.ownTermsCount}',
          e ? 'credit/limit/discount differ from group' : 'เครดิต/วงเงิน/ส่วนลด ต่างจากกลุ่ม'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.groups_outlined,
          e ? 'Select a customer group on the left, or press "Add group"' : 'เลือกกลุ่มลูกค้าจากรายการด้านซ้าย หรือกด "เพิ่มกลุ่มลูกค้า"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = e && _nameEnCtrl.text.trim().isNotEmpty ? _nameEnCtrl.text.trim() : _nameThCtrl.text.trim();
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.groupCode,
        title: isAdd ? (e ? 'New customer group' : 'กลุ่มลูกค้าใหม่') : name,
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          if (_isAutoNumber) ImKit.chip(e ? 'Auto code' : 'รหัสอัตโนมัติ', ImKit.blueSoft, ImKit.blue),
          if (_requiresBilling) ImKit.chip(e ? 'Billing required' : 'ต้องวางบิล', ImKit.goldSoft, ImKit.amber),
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
        ),
      ),
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Group' : 'ข้อมูลกลุ่ม', _mainCard()),
        (1, e ? 'Auto code' : 'รหัสอัตโนมัติ', _autoNumberCard()),
        (2, e ? 'Billing and payment' : 'วางบิลและรับชำระ', _conditionsCard()),
        if (saved) (3, e ? 'Customers' : 'ลูกค้าในกลุ่ม', _customersCard()),
      ],
    );
  }
}
