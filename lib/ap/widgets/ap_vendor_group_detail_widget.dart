// widgets/ap_vendor_group_detail_widget.dart — กลุ่มผู้ขาย แบบ B ของ IM (user 2026-11-28, เหมือนกลุ่มลูกค้า AR)
//   แถบหัว (รหัส ชื่อ ป้าย / ปุ่ม) + ตัวเลขสรุป + ลิงก์ข้ามส่วน + เลื่อนหน้าเดียว
//   ส่วน: ข้อมูลกลุ่ม (3 กลุ่มสี) / รหัสผู้ขายอัตโนมัติ (ตัวอย่างรหัส) / ผู้ขายในกลุ่ม
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/ap_vendor_group.dart';
import '../models/ap_vendor_summary.dart';
import '../services/ap_vendor_group_service.dart';

class ApVendorGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ApVendorGroup? selected;
  final Future<void> Function(ApVendorGroup) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ApVendorGroupDetailWidget({
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
  State<ApVendorGroupDetailWidget> createState() => ApVendorGroupDetailWidgetState();
}

class ApVendorGroupDetailWidgetState extends State<ApVendorGroupDetailWidget> with ImMasterKit {
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
  final _prefixCtrl = TextEditingController();
  final _sepCtrl = TextEditingController();
  final _lenCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  bool _isActive = true;
  bool _isAutoNumber = false;
  String _suffixDate = '';
  String _currencyCode = CurrencyService.baseCode;
  List<Currency> _currencies = [];
  int? _apAccountId;
  String? _apAccountCode;
  String? _apAccountNameThai;
  String? _apAccountNameEng;

  bool _isSaving = false;
  String _snapshot = '';

  ApVendorGroupSummary? _summary;
  ApCodePreview? _preview;
  bool _summaryLoading = false;
  int? _summaryFor;

  static final _money = NumberFormat('#,##0.00');

  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply(widget.mode == Mode.add ? null : widget.selected);
    _loadCurrencies();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant ApVendorGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq) return;
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    final onlyFullLoad = sameRecord && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq;
    _apply(widget.mode == Mode.add ? null : widget.selected);
    if (widget.mode == Mode.add) _loadDefaultCurrency();
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: !onlyFullLoad && sameRecord && widget.mode == Mode.view);
    if (!onlyFullLoad) kScrollTop();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameThCtrl, _nameEnCtrl, _descCtrl, _monthsCtrl, _daysCtrl, _prefixCtrl, _sepCtrl, _lenCtrl, _nextCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(ApVendorGroup? d) {
    _codeCtrl.text = d?.groupCode ?? '';
    _nameThCtrl.text = d?.groupNameThai ?? '';
    _nameEnCtrl.text = d?.groupNameEng ?? '';
    _descCtrl.text = d?.description ?? '';
    _monthsCtrl.text = (d?.creditTermMonths ?? 0).toString();
    _daysCtrl.text = (d?.creditTermDays ?? 30).toString();
    _currencyCode = d?.currencyCode ?? CurrencyService.baseCode;
    _isActive = d?.isActive ?? true;
    _isAutoNumber = d?.isAutoNumber ?? false;
    _prefixCtrl.text = d?.runningPrefix ?? 'VEND';
    _sepCtrl.text = d?.runningSeparator ?? '-';
    _suffixDate = d?.runningSuffixDate ?? '';
    _lenCtrl.text = (d?.runningLength ?? 4).toString();
    _nextCtrl.text = (d?.runningNextNumber ?? 1).toString();
    _apAccountId = d?.apAccountId;
    _apAccountCode = d?.apAccountCode;
    _apAccountNameThai = d?.apAccountNameThai;
    _apAccountNameEng = d?.apAccountNameEng;
    _snapshot = _fingerprint();
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
    if (widget.mode == Mode.add) _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    try {
      final code = await CurrencyService().getBaseCurrencyCode();
      if (mounted && widget.mode == Mode.add) _keepClean(() => _currencyCode = code);
    } catch (_) {}
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
    final svc = ApVendorGroupService();
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

  ApVendorGroup _build() => ApVendorGroup(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        groupCode: _codeCtrl.text.trim().toUpperCase(),
        groupNameThai: _nameThCtrl.text.trim(),
        groupNameEng: _nameEnCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        creditTermMonths: int.tryParse(_monthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_daysCtrl.text) ?? 30,
        currencyCode: _currencyCode,
        apAccountId: _apAccountId,
        apAccountCode: _apAccountCode,
        apAccountNameThai: _apAccountNameThai,
        apAccountNameEng: _apAccountNameEng,
        isAutoNumber: _isAutoNumber,
        runningPrefix: _prefixCtrl.text.trim(),
        runningSeparator: _sepCtrl.text,
        runningSuffixDate: _suffixDate,
        runningLength: int.tryParse(_lenCtrl.text) ?? 4,
        runningNextNumber: int.tryParse(_nextCtrl.text) ?? 1,
        isActive: _isActive,
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
    final len = int.tryParse(_lenCtrl.text);
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the vendor group code' : 'โปรดระบุรหัสกลุ่มผู้ขาย';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'โปรดระบุชื่อภาษาไทย';
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

  // ─── บัญชีเจ้าหนี้ของกลุ่ม: บัญชีคุม (control) ที่ลงรายการได้เท่านั้น ─────────────────────
  Future<void> _pickApAccount() async {
    final e = _isEnglish;
    List<Account> accounts = [];
    try {
      final all = await AccountService().fetchRows();
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
          title: Text(e ? 'Select payable account' : 'เลือกบัญชีเจ้าหนี้'),
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
                          final sel = _apAccountId == a.id;
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
                                _apAccountId = a.id;
                                _apAccountCode = a.accountCode;
                                _apAccountNameThai = a.accountNameThai;
                                _apAccountNameEng = a.accountNameEng;
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
    // ค่าในฟอร์มยังตรงกับที่บันทึก → ใช้ตัวอย่างจาก server (ข้ามรหัสที่มีผู้ขายใช้แล้ว)
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
      title: e ? 'Auto vendor code' : 'รหัสผู้ขายอัตโนมัติ',
      count: _isAutoNumber
          ? (e ? 'Vendors added to this group get a code on save' : 'ผู้ขายที่เพิ่มในกลุ่มนี้ได้รหัสอัตโนมัติเมื่อบันทึก')
          : (e ? 'Off — uses the global vendor code setting, or entered by hand' : 'ปิด — ใช้รหัสผู้ขายอัตโนมัติของระบบ หรือกรอกเอง'),
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
            ? 'Codes already used by a vendor are skipped automatically.${formSame ? '' : ' Next codes are calculated from the form; existing codes are checked on save.'}'
            : 'รหัสที่มีผู้ขายใช้แล้วจะถูกข้ามไปเลขถัดไปอัตโนมัติ${formSame ? '' : ' — รหัสถัดไปคำนวณจากค่าในฟอร์ม ระบบตรวจรหัสซ้ำตอนบันทึกผู้ขาย'}'),
      ]),
    );
  }

  // ─── ข้อมูลกลุ่ม ────────────────────────────────────────────────────────────────
  String _accText(bool e) {
    if (_apAccountId == null) return '';
    final n = e && (_apAccountNameEng?.isNotEmpty ?? false) ? _apAccountNameEng! : (_apAccountNameThai ?? '');
    return '${_apAccountCode ?? ''} $n'.trim();
  }

  List<DropdownMenuItem<String>> _currencyItems(bool e) {
    final codes = {..._currencies.map((c) => c.currencyCode), _currencyCode};
    String label(String code) {
      final c = _currencies.where((c) => c.currencyCode == code).firstOrNull;
      final n = c == null ? '' : (e && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai);
      return n.isEmpty ? code : '$code  $n';
    }

    return [for (final c in codes) DropdownMenuItem(value: c, child: Text(label(c), overflow: TextOverflow.ellipsis))];
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
        kGroup(2, e ? 'Defaults for vendors' : 'ค่าตั้งต้นให้ผู้ขาย', ImKit.gFin, [
          kRow([
            kTxt(e ? 'Credit (months)' : 'เครดิต (เดือน)', _monthsCtrl, digitsOnly: true, numeric: true),
            kTxt(e ? 'Credit (days)' : 'เครดิต (วัน)', _daysCtrl, digitsOnly: true, numeric: true),
          ]),
          kDd<String>(e ? 'Currency' : 'สกุลเงิน', _currencyCode, _currencyItems(e),
              ro ? null : (v) => setState(() => _currencyCode = v ?? CurrencyService.baseCode), auto: false),
          kFk(
            label: e ? 'Payable account' : 'บัญชีเจ้าหนี้',
            text: _accText(e),
            hasValue: _apAccountId != null,
            onSearch: _pickApAccount,
            onClear: () => setState(() {
              _apAccountId = null;
              _apAccountCode = null;
              _apAccountNameThai = null;
              _apAccountNameEng = null;
            }),
          ),
          kNote(e
              ? 'Order used when posting: vendor › group › document type${s != null && s.ownAccountCount > 0 ? ' — ${s.ownAccountCount} vendor(s) set their own account and do not use this one' : ''}'
              : 'ลำดับตอนลงบัญชี: ผู้ขาย › กลุ่ม › ประเภทเอกสาร${s != null && s.ownAccountCount > 0 ? ' — ผู้ขาย ${s.ownAccountCount} รายตั้งบัญชีเอง จึงไม่ใช้บัญชีนี้' : ''}'),
          kNote(e
              ? 'Credit and currency are copied to a vendor when the group is chosen; changing them here does not change existing vendors'
              : 'เครดิตและสกุลเงินคัดลอกไปที่ผู้ขายตอนเลือกกลุ่ม แก้ที่นี่ไม่เปลี่ยนผู้ขายที่มีอยู่แล้ว'),
        ]),
        kGroup(3, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v)),
          ]),
        ]),
      ]),
    );
  }

  // ─── ผู้ขายในกลุ่ม ───────────────────────────────────────────────────────────────
  Widget _vendorsCard() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) {
      return kCard(
        title: e ? 'Vendors in this group' : 'ผู้ขายในกลุ่ม',
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(e ? 'Could not load vendors' : 'โหลดรายชื่อผู้ขายไม่ได้'),
      );
    }
    String term(ApGroupVendor v) => v.creditTermMonths > 0
        ? (e ? '${v.creditTermMonths} mo ${v.creditTermDays} d' : '${v.creditTermMonths} ด. ${v.creditTermDays} ว.')
        : (e ? '${v.creditTermDays} days' : '${v.creditTermDays} วัน');
    Color? own(bool same) => same ? null : ImKit.amber;
    return kCard(
      title: e ? 'Vendors in this group' : 'ผู้ขายในกลุ่ม',
      count: e
          ? '${s.vendorCount} · ${s.ownTermsCount} with their own credit/currency (amber)'
          : '${s.vendorCount} ราย · ตั้งเครดิต/สกุลเงินเอง ${s.ownTermsCount} ราย (สีส้ม)',
      trailing: kGhost(e ? 'Vendors' : 'ข้อมูลผู้ขาย', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ApVendorScreen', 'ข้อมูลผู้ขาย', 'Vendors', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Code' : 'รหัส', 3),
          KCol(e ? 'Name' : 'ชื่อผู้ขาย', 7),
          KCol(e ? 'Credit' : 'เครดิต', 3),
          KCol(e ? 'Currency' : 'สกุลเงิน', 2),
          KCol(e ? 'Payable' : 'ยอดค้างจ่าย', 3, num: true),
          KCol(e ? 'Values' : 'ค่าที่ใช้', 3),
        ],
        [
          for (final v in s.vendors)
            [
              kCell(v.vendorCode, mono: true, color: v.isActive ? null : ImKit.ink3),
              kCell(v.name(e), color: v.isActive ? null : ImKit.ink3),
              kCell(term(v), color: own(v.sameTerm)),
              kCell(v.currencyCode, mono: true, color: own(v.sameCurrency)),
              kCell(v.outstanding.abs() < 0.005 ? '' : _money.format(v.outstanding), mono: true, color: v.overdue > 0.005 ? ImKit.red : null),
              v.usesGroup ? ImKit.chip(e ? 'Group' : 'ของกลุ่ม', ImKit.blueSoft, ImKit.blue) : ImKit.chip(e ? 'Own' : 'ตั้งเอง', ImKit.goldSoft, ImKit.amber),
            ],
        ],
        minWidth: 760,
        empty: e ? 'No vendors in this group yet' : 'ยังไม่มีผู้ขายในกลุ่มนี้',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    return kKpis([
      ImKpi(e ? 'Vendors' : 'ผู้ขายในกลุ่ม', '${s.vendorCount}', e ? '${s.activeCount} active' : 'ใช้งาน ${s.activeCount} ราย'),
      ImKpi(e ? 'Payable' : 'ยอดค้างจ่ายรวม', _money.format(s.outstanding), e ? 'base currency' : 'สกุลหลัก'),
      ImKpi(e ? 'Overdue' : 'เกินกำหนด', _money.format(s.overdue),
          s.overdueVendors == 0 ? (e ? 'none' : 'ไม่มี') : (e ? '${s.overdueVendors} vendor(s)' : '${s.overdueVendors} ราย'),
          warn: s.overdue > 0.005,
          onTap: () => ImKit.openMenu(context, 'ApAgingReportScreen', 'รายงานอายุเจ้าหนี้', 'AP Aging Report', e)),
      ImKpi(e ? 'Own settings' : 'ตั้งค่าเอง', '${s.ownTermsCount}',
          e ? 'credit/currency differ from group' : 'เครดิต/สกุลเงิน ต่างจากกลุ่ม'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.groups_outlined,
          e ? 'Select a vendor group on the left, or press "Add group"' : 'เลือกกลุ่มผู้ขายจากรายการด้านซ้าย หรือกด "เพิ่มกลุ่ม"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = e && _nameEnCtrl.text.trim().isNotEmpty ? _nameEnCtrl.text.trim() : _nameThCtrl.text.trim();
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.groupCode,
        title: isAdd ? (e ? 'New vendor group' : 'กลุ่มผู้ขายใหม่') : name,
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          if (_isAutoNumber) ImKit.chip(e ? 'Auto code' : 'รหัสอัตโนมัติ', ImKit.blueSoft, ImKit.blue),
          Text(_currencyCode, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
        if (saved) (2, e ? 'Vendors' : 'ผู้ขายในกลุ่ม', _vendorsCard()),
      ],
    );
  }
}
