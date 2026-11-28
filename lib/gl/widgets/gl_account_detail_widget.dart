// lib/gl/widgets/gl_account_detail_widget.dart
// รายละเอียดบัญชีบนหน้าจอผังบัญชี แบบ IM design B (user 2026-11-28):
//   แถบหัว (รหัส ชื่อ ป้ายสถานะ/ประเภท·ดุล/ชนิด เส้นทางหัวบัญชี) + ตัวเลขสรุป + 4 กลุ่มสี
//   (ข้อมูลหลัก / การลงรายการ / สาขาและมิติที่ต้องระบุ / เพิ่มเติม) + ยอดรายงวด + ถูกใช้ในการตั้งค่าบัญชี
//   หัวบัญชี: แทนกลุ่มมิติด้วยตารางบัญชีย่อย, ตัวเลขสรุปรวมทั้งกิ่ง
// มิติต่อบัญชีเลือกได้ 3 แบบ: ไม่ใช้ (ไม่มี rule — ช่องมิติในรายการบัญชีปิด) / ระบุได้ (is_required=false) / ต้องระบุ
// mode addChild: selected = หัวบัญชีแม่ (ฟอร์มว่าง), addRoot: ไม่มีแม่; template = สำเนาจากบัญชีเดิม (รหัสว่าง)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_account.dart';
import '../models/gl_account_summary.dart';
import '../models/gl_dimension.dart';
import '../services/gl_account_service.dart';
import '../services/gl_dimension_service.dart';

String glAccountName(Account a, bool e) => e && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

/// ยอดตามดุลปกติ: บัญชีดุลเดบิต = เดบิต-เครดิต, ดุลเครดิต = เครดิต-เดบิต (ติดลบ = ผิดดุล)
double glNormalSigned(double net, String normalBalance) => normalBalance == 'CR' ? -net : net;

class AccountDetailWidget extends StatefulWidget {
  final Mode mode;
  final Account? selected;
  final Account? template;
  final Future<void> Function(Account) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddChild;
  final VoidCallback? onCopy;
  final String parentPath;
  /// บัญชีลูกระดับถัดไปของหัวบัญชีที่เลือก + ยอดทั้งปี (ตามดุลปกติของลูก) จากต้นไม้
  final List<Account> children;
  final Map<int, double> childBalance;
  final ValueChanged<Account>? onOpenChild;
  final bool isPlaceholder;
  final int requestSeq;

  const AccountDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    this.template,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.onAddChild,
    this.onCopy,
    this.parentPath = '',
    this.children = const [],
    this.childBalance = const {},
    this.onOpenChild,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<AccountDetailWidget> createState() => AccountDetailWidgetState();
}

class AccountDetailWidgetState extends State<AccountDetailWidget> with ImMasterKit {
  final _svc = AccountService();
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  String _type = 'ASSET';
  String _normal = 'DR';
  bool _isNormalAccount = true;
  bool _isControl = false;
  String _currency = '';
  bool _branchRequired = false;
  bool _isActive = true;
  Map<String, bool> _dims = {}; // type_code → is_required (ไม่มี key = ไม่ใช้)

  List<Currency> _currencies = [];
  List<GlDimensionType> _dimTypes = [];
  bool _isSaving = false;
  bool _isEnglish = false;

  GlAccountSummary? _summary;
  bool _loadingSummary = false;
  int _summarySeq = 0;
  int? _fyId;
  String _snapshot = '';

  static final _amt = NumberFormat('#,##0.00');
  static final _int = NumberFormat('#,##0');

  bool get _isNew => widget.mode == Mode.addRoot || widget.mode == Mode.addChild;
  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;
  bool get _posted => !_isNew && (widget.selected?.hasTransactions ?? false);
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => _isReadOnly;

  bool get isDirty => !_isReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _apply();
  }

  @override
  void didUpdateWidget(covariant AccountDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final cur = await Provider.of<CurrencyService>(context, listen: false).fetchActiveRows();
      final dims = await GlDimensionService().fetchActiveTypes();
      if (!mounted) return;
      setState(() {
        _currencies = cur;
        _dimTypes = dims;
        if (_currency.isEmpty) {
          _currency = _baseCurrency();
          _snapshot = _fingerprint();
        }
      });
    } catch (_) {}
  }

  String _baseCurrency() => _currencies.where((c) => c.baseCurrencyFlag).firstOrNull?.currencyCode ?? CurrencyService.baseCode;

  static String _defaultNormal(String type) => type == 'ASSET' || type == 'EXPENSE' ? 'DR' : 'CR';

  void _apply() {
    final a = _isNew ? widget.template : widget.selected;
    final parent = widget.mode == Mode.addChild ? widget.selected : null;
    _codeCtrl.text = _isNew ? '' : (a?.accountCode ?? '');
    _nameThCtrl.text = a?.accountNameThai ?? '';
    _nameEnCtrl.text = a?.accountNameEng ?? '';
    _type = a?.accountType ?? parent?.accountType ?? 'ASSET';
    _normal = a?.normalBalance ?? _defaultNormal(_type);
    // หัวบัญชีใหม่ระดับบนสุด = หัวบัญชี, ใต้หัวบัญชี = ลงรายการได้
    _isNormalAccount = a?.isNormalAccount ?? (widget.mode != Mode.addRoot);
    _isControl = a?.isControlAccount ?? false;
    _currency = a?.currencyCode ?? (_currencies.isEmpty ? '' : _baseCurrency());
    _branchRequired = a?.branchRequired ?? false;
    _isActive = _isNew ? true : (a?.isActive ?? true);
    _dims = {for (final r in a?.dimRules ?? const <GlAccountDimRule>[]) r.typeCode: r.isRequired};
    _summary = null;
    _summarySeq++;
    if (!_isNew && widget.selected != null && widget.mode != Mode.none) _loadSummary(widget.selected!.id, _fyId);
    kScrollTop();
    _snapshot = _fingerprint();
  }

  Future<void> _loadSummary(int id, int? fy) async {
    final seq = ++_summarySeq;
    _loadingSummary = true;
    try {
      final s = await _svc.fetchSummary(id, fiscalYearId: fy);
      if (mounted && seq == _summarySeq) setState(() => _summary = s);
    } catch (_) {
    } finally {
      if (mounted && seq == _summarySeq) setState(() => _loadingSummary = false);
    }
  }

  Account _build() => Account(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        parentId: widget.mode == Mode.addRoot
            ? null
            : widget.mode == Mode.addChild
                ? widget.selected?.id
                : widget.selected?.parentId,
        accountCode: _codeCtrl.text.trim(),
        accountNameThai: _nameThCtrl.text.trim(),
        accountNameEng: _nameEnCtrl.text.trim(),
        accountType: _type,
        normalBalance: _normal,
        isNormalAccount: _isNormalAccount,
        isControlAccount: _isNormalAccount && _isControl,
        currencyCode: _currency,
        branchRequired: _isNormalAccount && _branchRequired,
        isActive: _isActive,
        dimRules: _isNormalAccount
            ? [for (final t in _dimTypes) if (_dims.containsKey(t.typeCode)) GlAccountDimRule(typeCode: t.typeCode, isRequired: _dims[t.typeCode]!)]
            : const [],
      );

  String _fingerprint() => docFingerprint(_build().toJson()..remove('created_at')..remove('updated_at'));

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the account code' : 'กรุณาป้อนรหัสบัญชี';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the account name (Thai)' : 'กรุณาป้อนชื่อบัญชี (ภาษาไทย)';
    } else if (_nameEnCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the account name (English)' : 'กรุณาป้อนชื่อบัญชี (ภาษาอังกฤษ)';
    } else if (_currency.isEmpty) {
      err = e ? 'Please select the currency' : 'กรุณาเลือกสกุลเงิน';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _drCr(double net) {
    if (net.abs() < 0.005) return '0.00';
    return '${_amt.format(net.abs())} ${net > 0 ? 'Dr' : 'Cr'}';
  }

  String _date(String? ymd) {
    if (ymd == null || ymd.length < 10) return '';
    final p = ymd.substring(0, 10).split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  String _dimName(GlDimensionType t) => _isEnglish && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;

  // ── 3 ทาง: ไม่ใช้ / ระบุได้ / ต้องระบุ ──
  Widget _seg(List<String> labels, int value, ValueChanged<int>? onChanged) => Container(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              onTap: onChanged == null || i == value ? null : () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                color: i == value ? (onChanged == null ? ImKit.ink2 : kInk) : Colors.white,
                child: Text(labels[i],
                    style: TextStyle(fontSize: 12, color: i == value ? Colors.white : ImKit.ink2, fontWeight: i == value ? FontWeight.w600 : null)),
              ),
            ),
        ]),
      );

  Widget _segRow(String label, Widget seg) => Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E9EE)))),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))), seg]),
      );

  // ── การ์ดข้อมูลบัญชี ──
  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    final parent = widget.mode == Mode.addChild ? widget.selected : null;
    final parentText = parent != null
        ? '${parent.accountCode}  ${glAccountName(parent, e)}'
        : (widget.mode == Mode.addRoot || widget.parentPath.isEmpty ? (e ? '— Top level —' : '— ระดับบนสุด —') : widget.parentPath);
    final typeLocked = _posted;
    final headerLocked = _posted && (widget.selected?.isNormalAccount ?? false);
    final hasKids = !_isNew && widget.children.isNotEmpty;
    final groups = <Widget>[
      kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
        kRow([
          kTxt(_isNew ? (e ? 'Account Code *' : 'รหัสบัญชี *') : (e ? 'Account Code' : 'รหัสบัญชี'), _codeCtrl, editable: _isNew),
          kDd<String>(
            e ? 'Account Type' : 'ประเภทบัญชี',
            _type,
            [for (final k in accountTypeOptions.keys) DropdownMenuItem(value: k, child: Text('$k - ${accountTypeLabel(k, e)}', overflow: TextOverflow.ellipsis))],
            ed && !typeLocked ? (v) => setState(() {
                  _type = v ?? _type;
                  _normal = _defaultNormal(_type);
                }) : null,
          ),
        ]),
        kRow([
          kTxt(e ? 'Account Name (Thai) *' : 'ชื่อบัญชี (ไทย) *', _nameThCtrl),
          kTxt(e ? 'Account Name (English) *' : 'ชื่อบัญชี (อังกฤษ) *', _nameEnCtrl),
        ]),
        InputDecorator(
          decoration: kDec(e ? 'Parent' : 'อยู่ภายใต้', editable: false),
          child: Text(parentText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
        ),
        if (ed)
          kNote(typeLocked
              ? (e ? 'Account type is locked because the account already has postings.' : 'ประเภทบัญชีล็อก เพราะบัญชีนี้มีรายการลงบัญชีแล้ว')
              : (e ? 'Account type defaults to the parent header; normal balance follows the type.' : 'ประเภทบัญชีตั้งต้นตามหัวบัญชี ดุลปกติเปลี่ยนตามประเภท')),
      ]),
      kGroup(2, e ? 'Posting' : 'การลงรายการ', ImKit.gParty, [
        kRow([
          kDd<String>(e ? 'Normal Balance' : 'ดุลบัญชีปกติ', _normal, [
            DropdownMenuItem(value: 'DR', child: Text(e ? 'DR - Debit' : 'DR - เดบิต')),
            DropdownMenuItem(value: 'CR', child: Text(e ? 'CR - Credit' : 'CR - เครดิต')),
          ], ed ? (v) => setState(() => _normal = v ?? _normal) : null),
          kDd<String>(
            e ? 'Base Currency' : 'สกุลเงินหลัก',
            _currencies.any((c) => c.currencyCode == _currency) ? _currency : null,
            [
              for (final c in _currencies)
                DropdownMenuItem(
                    value: c.currencyCode,
                    child: Text('${c.currencyCode} - ${e && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai}',
                        overflow: TextOverflow.ellipsis)),
            ],
            ed ? (v) => setState(() => _currency = v ?? _currency) : null,
          ),
        ]),
        kChecks([
          kCk(e ? 'Postable (not a header)' : 'ลงรายการได้ (ไม่ใช่หัวบัญชี)', _isNormalAccount,
              ed && !headerLocked && !(hasKids && !_isNormalAccount) ? (v) => setState(() => _isNormalAccount = v) : null,
              tooltip: hasKids && !_isNormalAccount ? (e ? 'A header with sub-accounts cannot be postable' : 'หัวบัญชีที่มีบัญชีย่อย เปลี่ยนเป็นบัญชีลงรายการไม่ได้') : null),
          if (_isNormalAccount)
            kCk(e ? 'Control account — posted only from other modules' : 'Control account — บันทึกได้เฉพาะจากโมดูลอื่น', _isControl,
                ed ? (v) => setState(() => _isControl = v) : null),
        ]),
        if (headerLocked && ed)
          kNote(e
              ? 'Cannot change to a header because the account already has postings.'
              : 'เปลี่ยนเป็นหัวบัญชีไม่ได้ เพราะบัญชีนี้มีรายการลงบัญชีแล้ว'),
      ]),
      if (_isNormalAccount)
        kGroup(3, e ? 'Branch and Required Dimensions' : 'สาขาและมิติที่ต้องระบุ', ImKit.gFin, [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _segRow(e ? 'Branch' : 'สาขา',
                _seg([e ? 'Not required' : 'ไม่ต้องระบุ', e ? 'Required' : 'ต้องระบุ'], _branchRequired ? 1 : 0,
                    ed ? (i) => setState(() => _branchRequired = i == 1) : null)),
            for (final t in _dimTypes)
              _segRow('${_dimName(t)} (${t.typeCode})',
                  _seg([e ? 'Not used' : 'ไม่ใช้', e ? 'Optional' : 'ระบุได้', e ? 'Required' : 'ต้องระบุ'],
                      !_dims.containsKey(t.typeCode) ? 0 : (_dims[t.typeCode]! ? 2 : 1),
                      ed
                          ? (i) => setState(() {
                                if (i == 0) {
                                  _dims.remove(t.typeCode);
                                } else {
                                  _dims[t.typeCode] = i == 2;
                                }
                              })
                          : null)),
          ]),
          kNote(e
              ? 'Only dimensions enabled on the Dimension Types screen are listed. "Not used" hides the field on journal lines; reports split balances only by required branch/dimensions.'
              : 'แสดงเฉพาะมิติที่เปิดใช้ในหน้า "ประเภทมิติ" · "ไม่ใช้" = ช่องมิติในรายการบัญชีปิด · รายงานแยกยอดตามสาขา/มิติเฉพาะที่ต้องระบุ'),
        ]),
      kGroup(_isNormalAccount ? 4 : 3, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
        kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null)]),
        if (!_isNew)
          kRow([
            _roField(e ? 'Created by' : 'สร้างโดย', _who(widget.selected?.createdBy, widget.selected?.createdAt)),
            _roField(e ? 'Last updated' : 'แก้ไขล่าสุด', _who(widget.selected?.updatedBy, widget.selected?.updatedAt)),
          ]),
      ]),
    ];
    return kCard(
      title: e ? 'Account Information' : 'ข้อมูลบัญชี',
      trailing: _isReadOnly ? null : kLegend(),
      child: kGroups(groups),
    );
  }

  String _who(String? by, DateTime? at) {
    final d = at == null ? '' : DateFormat('dd/MM/yyyy').format(at);
    return [by ?? '', d].where((s) => s.isNotEmpty).join(' · ');
  }

  Widget _roField(String label, String text) => InputDecorator(
        decoration: kDec(label, editable: false),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
      );

  // ── ยอดรายงวด ──
  Widget _periodsCard() {
    final e = _isEnglish;
    final s = _summary;
    final rows = <List<Widget>>[];
    final colors = <Color?>[];
    double run = 0, td = 0, tc = 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (s != null) {
      for (var i = 0; i < s.periods.length; i++) {
        final p = s.periods[i];
        final open = run;
        run += p.net;
        td += p.debit;
        tc += p.credit;
        final current = p.startDate.compareTo(today) <= 0 && p.endDate.compareTo(today) >= 0;
        final first = i == 0;
        rows.add([
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: kCell(first && e ? 'Opening (${p.periodName})' : p.periodName)),
            const SizedBox(width: 6),
            p.glStatus == 'CLOSED'
                ? ImKit.chip(e ? 'Closed' : 'ปิด', ImKit.redSoft, ImKit.red)
                : ImKit.chip(e ? 'Open' : 'เปิด', ImKit.okSoft, ImKit.ok),
          ]),
          kCell(first ? '' : _drCr(open), mono: true, color: ImKit.ink2),
          kCell(p.debit == 0 ? '' : _amt.format(p.debit), mono: true),
          kCell(p.credit == 0 ? '' : _amt.format(p.credit), mono: true),
          kCell(_drCr(run), mono: true, bold: true),
        ]);
        colors.add(current ? const Color(0xFFFFFCF2) : null);
      }
      rows.add([
        kCell(e ? 'Year total' : 'รวมทั้งปี', bold: true),
        kCell(''),
        kCell(_amt.format(td), mono: true, bold: true),
        kCell(_amt.format(tc), mono: true, bold: true),
        kCell(_drCr(run), mono: true, bold: true),
      ]);
      colors.add(const Color(0xFFF6F8FA));
    }
    final years = s?.fiscalYears ?? const <GlFiscalYearRef>[];
    return kCard(
      title: e ? 'Balance by Period' : 'ยอดรายงวด',
      count: s?.fiscalYear == null
          ? (s == null ? null : (e ? 'No fiscal year' : 'ยังไม่มีปีบัญชี'))
          : (e ? 'Read-only · fiscal year ${s!.fiscalYear!.fyCode} · posted only' : 'อ่านอย่างเดียว · ปีบัญชี ${s!.fiscalYear!.fyCode} · Posted เท่านั้น'),
      trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (years.length > 1)
          ImMasterPopupFilter(
            label: e ? 'Year' : 'ปี',
            value: s?.fiscalYear?.id.toString(),
            valueLabel: s?.fiscalYear?.fyCode,
            options: [for (final y in years) (y.id.toString(), y.fyCode)],
            allLabel: e ? 'Current year' : 'ปีปัจจุบัน',
            onChanged: (v) {
              _fyId = v == null ? null : int.tryParse(v);
              if (widget.selected != null) _loadSummary(widget.selected!.id, _fyId);
            },
          ),
        kGhost(e ? 'Open General Ledger' : 'เปิดบัญชีแยกประเภท', Icons.open_in_new,
            () => ImKit.openMenu(context, 'GeneralLedgerReportScreen', 'รายงานบัญชีแยกประเภท', 'General Ledger', e)),
      ]),
      padding: EdgeInsets.zero,
      child: s == null
          ? _loadingBox()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              kTable([
                KCol(e ? 'Period' : 'งวด', 5),
                KCol(e ? 'Opening' : 'ยอดยกมา', 4, num: true),
                KCol(e ? 'Debit' : 'เดบิต', 4, num: true),
                KCol(e ? 'Credit' : 'เครดิต', 4, num: true),
                KCol(e ? 'Balance' : 'คงเหลือ', 4, num: true),
              ], rows, rowColors: colors, minWidth: 760, empty: e ? 'No period' : 'ไม่มีงวดบัญชี'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: kNote(widget.selected?.isNormalAccount == false
                    ? (e ? 'Header account: totals of all accounts under it. Amounts in base currency from posted entries.'
                        : 'หัวบัญชี: รวมยอดทุกบัญชีใต้หัว · จำนวนเงินสกุลหลัก จากรายการที่ Posted')
                    : (e ? 'Amounts in base currency from posted entries.' : 'จำนวนเงินสกุลหลัก จากรายการที่ Posted')),
              ),
            ]),
    );
  }

  Widget _loadingBox() => Padding(
        padding: const EdgeInsets.all(14),
        child: Center(
            child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
      );

  // ── ถูกใช้ในการตั้งค่าบัญชี ──
  Widget _usageCard() {
    final e = _isEnglish;
    final s = _summary;
    final list = s?.usage ?? const <GlAccountUsage>[];
    final shown = <String, int>{};
    for (final u in list) {
      shown[u.table] = (shown[u.table] ?? 0) + 1;
    }
    final more = <GlAccountUsage>[
      for (final u in list)
        if (u.total > (shown[u.table] ?? 0) && list.lastWhere((x) => x.table == u.table) == u) u,
    ];
    return kCard(
      title: e ? 'Used in Account Setups' : 'ถูกใช้ในการตั้งค่าบัญชี',
      count: e ? 'Read-only · where the system posts to this account automatically' : 'อ่านอย่างเดียว · ที่ที่ระบบจะลงบัญชีนี้อัตโนมัติ',
      padding: EdgeInsets.zero,
      child: s == null
          ? _loadingBox()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              kTable([
                KCol(e ? 'Module' : 'โมดูล', 2),
                KCol(e ? 'Setup screen' : 'หน้าจอตั้งค่า', 5),
                KCol(e ? 'Reference' : 'อ้างอิง', 6),
                KCol(e ? 'Account field' : 'ช่องบัญชี', 4),
                const KCol('', 2),
              ], [
                for (final u in list)
                  [
                    ImKit.chip(u.module, ImKit.blueSoft, ImKit.blue),
                    kCell(u.screen(e)),
                    kCell(u.ref(e)),
                    kCell(u.field(e), color: ImKit.ink2),
                    u.targetPath == null
                        ? const SizedBox.shrink()
                        : InkWell(
                            onTap: () => ImKit.openMenu(context, u.targetPath!, u.screenTh, u.screenEn, e),
                            child: Text(e ? 'Open ›' : 'เปิด ›',
                                style: TextStyle(fontSize: 12.5, color: kInk, decoration: TextDecoration.underline)),
                          ),
                  ],
              ], minWidth: 820, empty: e ? 'Not used in any setup' : 'ยังไม่ถูกใช้ในการตั้งค่าใด'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: kNote([
                  for (final u in more)
                    e ? '${u.screen(e)}: ${u.total} in total (showing ${shown[u.table]})' : '${u.screen(e)}: ทั้งหมด ${u.total} รายการ (แสดง ${shown[u.table]})',
                  e
                      ? 'Checks AR/AP/IM/CM/MO GL setups, customers/vendors and groups, items/categories/warehouses, bank accounts, VAT/WHT, company defaults, year-end closing and financial reports — check before deactivating or deleting.'
                      : 'ตรวจจากตั้งค่าบัญชี AR/AP/IM/CM/MO, ลูกค้า-ผู้ขายและกลุ่ม, สินค้า-หมวด-คลัง, บัญชีธนาคาร, ภาษี, ค่าเริ่มต้นบริษัท, ปิดบัญชีสิ้นปี และงบการเงิน · ช่วยตัดสินใจก่อนหยุดใช้หรือลบบัญชี',
                ].join('\n')),
              ),
            ]),
    );
  }

  // ── บัญชีย่อย (หัวบัญชี) ──
  Widget _childrenCard() {
    final e = _isEnglish;
    final kids = widget.children;
    return kCard(
      title: e ? 'Sub-accounts' : 'บัญชีย่อย',
      count: e ? '${kids.length} account(s) directly under this header' : '${kids.length} บัญชีระดับถัดไป',
      trailing: widget.onAddChild == null ? null : kGhost(e ? 'Add sub-account' : 'เพิ่มบัญชีย่อย', Icons.add, widget.onAddChild),
      padding: EdgeInsets.zero,
      child: kTable([
        KCol(e ? 'Account' : 'บัญชี', 7),
        KCol(e ? 'Kind' : 'ชนิด', 3),
        KCol(e ? 'Normal' : 'ดุลปกติ', 2),
        KCol(e ? 'Balance (year)' : 'ยอดทั้งปี', 4, num: true),
        KCol(e ? 'Status' : 'สถานะ', 2),
      ], [
        for (final a in kids)
          [
            kCell('${a.accountCode}  ${glAccountName(a, e)}'),
            kCell(!a.isNormalAccount ? (e ? 'Header' : 'หัวบัญชี') : (a.isControlAccount ? 'Control' : (e ? 'Postable' : 'ลงรายการได้')), color: ImKit.ink2),
            kCell(a.normalBalance),
            kCell(_amt.format(widget.childBalance[a.id] ?? 0), mono: true),
            ImKit.activeChip(a.isActive, e),
          ],
      ], onTap: [for (final a in kids) widget.onOpenChild == null ? null : () => widget.onOpenChild!(a)], minWidth: 760,
          empty: e ? 'No sub-account yet' : 'ยังไม่มีบัญชีย่อย'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    final a = widget.selected;
    if (s == null || a == null) return const [];
    final fy = s.fiscalYear?.fyCode ?? '-';
    final byMod = s.usageByModule;
    final usageSub = byMod.isEmpty ? (e ? 'Not used in setups' : 'ยังไม่ถูกใช้') : byMod.entries.map((x) => '${x.key} ${x.value}').join(' · ');
    final bal = ImKpi(
        a.isNormalAccount ? (e ? 'Balance as of today' : 'ยอดคงเหลือ ณ วันนี้') : (e ? 'Total under header' : 'ยอดรวมใต้หัวบัญชี'),
        _drCr(s.balanceToday),
        e ? 'Fiscal year $fy' : 'ปีบัญชี $fy',
        warn: glNormalSigned(s.balanceToday, a.normalBalance) < -0.005);
    final lines = ImKpi(e ? 'Lines this year' : 'รายการปีนี้', _int.format(s.linesPosted),
        e ? 'posted lines · draft ${s.linesDraft}' : 'บรรทัด Posted · Draft ${s.linesDraft}');
    final last = ImKpi(e ? 'Last movement' : 'เคลื่อนไหวล่าสุด', s.lastDate == null ? '-' : _date(s.lastDate), s.lastDocNo ?? (e ? 'No posting yet' : 'ยังไม่มีรายการ'));
    final usage = ImKpi(e ? 'Used in setups' : 'ถูกใช้ในการตั้งค่า', e ? '${s.usageTotal}' : '${s.usageTotal} ที่', usageSub);
    if (a.isNormalAccount) return [bal, lines, last, usage];
    final kids = widget.children;
    return [
      bal,
      ImKpi(e ? 'Sub-accounts' : 'บัญชีย่อย', '${kids.length}',
          e ? 'headers ${kids.where((k) => !k.isNormalAccount).length} · postable ${kids.where((k) => k.isNormalAccount).length}'
              : 'หัวบัญชี ${kids.where((k) => !k.isNormalAccount).length} · ลงรายการได้ ${kids.where((k) => k.isNormalAccount).length}'),
      ImKpi(e ? 'Inactive sub-accounts' : 'บัญชีย่อยหยุดใช้', '${kids.where((k) => !k.isActive).length}', e ? 'directly under this header' : 'ระดับถัดไป'),
      lines,
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.account_tree_outlined, e ? 'Select an account on the left to view its data' : 'เลือกบัญชีทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = !_isNew && widget.selected != null;
    final a = widget.selected;
    final title = saved
        ? glAccountName(a!, e)
        : widget.mode == Mode.addChild
            ? (e ? 'Add account under ${a?.accountCode ?? ''}' : 'เพิ่มบัญชีใต้ ${a?.accountCode ?? ''} ${a == null ? '' : glAccountName(a, e)}')
            : (e ? 'Add Root Account' : 'เพิ่มบัญชีหลัก');
    final kind = saved
        ? (!a!.isNormalAccount
            ? ImKit.chip(e ? 'Header' : 'หัวบัญชี', ImKit.blueSoft, ImKit.blue)
            : a.isControlAccount
                ? ImKit.chip('Control', ImKit.purSoft, ImKit.pur)
                : ImKit.chip(e ? 'Postable' : 'ลงรายการได้', ImKit.goldSoft, ImKit.amber))
        : null;
    return kPage(
      header: kHeaderBar(
        code: saved ? a!.accountCode : null,
        title: title,
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved) ImKit.activeChip(a!.isActive, e),
          if (saved) ImKit.chip('${accountTypeLabel(a!.accountType, e)} · ${a.normalBalance == 'CR' ? 'Cr' : 'Dr'}', ImKit.blueSoft, ImKit.blue),
          if (kind != null) kind,
          if (saved && widget.parentPath.isNotEmpty) Text(widget.parentPath, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _save,
          extra: [
            if (widget.onAddChild != null && saved && !a!.isNormalAccount)
              DocBarAction(e ? '+ Sub-account' : '+ บัญชีย่อย', widget.onAddChild, fg: kInk),
            if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นบัญชีใหม่', widget.onCopy, fg: kInk),
          ],
        ),
        busy: _isSaving,
      ),
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved && !a!.isNormalAccount) (1, e ? 'Sub-accounts' : 'บัญชีย่อย', _childrenCard()),
        if (saved) (2, e ? 'By period' : 'ยอดรายงวด', _periodsCard()),
        if (saved) (3, e ? 'Used in setups' : 'ถูกใช้ในการตั้งค่า', _usageCard()),
      ],
    );
  }
}
