// lib/ap/screens/ap_year_end_setup_screen.dart — ตั้งค่าสิ้นปี AP แบบ B ของ IM (user 2026-11-28, เหมือนตั้งค่าสิ้นปี AR)
//   เปิดมาเป็นโหมดดู → แก้ไข/บันทึกที่แถบหัว (เดิมแก้ได้ทันที + ปุ่มบันทึกท้ายหน้า)
//   ช่องที่ยังไม่ได้ตั้งขึ้นสีแดง + ตัวเลขสรุป + เจ้าหนี้สกุลต่างประเทศที่ค้าง + ประวัติการปรับมูลค่า FX
//   AP มีเฉพาะการปรับมูลค่าหนี้ FX (ไม่มีค่าเผื่อหนี้สงสัยจะสูญแบบ AR)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/utils/sa_menu_theme.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/ap_year_end.dart';
import '../models/ap_vendor_summary.dart';
import '../services/ap_year_end_service.dart';

class ApYearEndSetupScreen extends StatefulWidget {
  const ApYearEndSetupScreen({super.key});

  @override
  State<ApYearEndSetupScreen> createState() => _ApYearEndSetupScreenState();
}

class _ApYearEndSetupScreenState extends State<ApYearEndSetupScreen> with AutomaticKeepAliveClientMixin, ImMasterKit {
  final ApYearEndService _svc = ApYearEndService();
  final AccountService _acctSvc = AccountService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();

  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];

  bool _isEnglish = false;
  bool _editing = false;

  int? _fxGainId, _fxLossId, _ufxGainId, _ufxLossId, _fxRevalDocId;
  ApYearEndSetup? _saved;

  ApYearEndSummary? _summary;
  List<ApFxRevaluationHeader> _revals = [];
  String _snapshot = '';

  bool _isLoading = true;
  bool _isSaving = false;

  static final _money = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  bool get wantKeepAlive => true;
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => !_editing;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchSetup(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      _saved = results[0] as ApYearEndSetup?;
      _accounts = (results[1] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
      _glDocs = (results[2] as List<ModuleDocument>).where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
        ..sort((a, b) => a.docCode.compareTo(b.docCode));
      _applySaved();
      _editing = false;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString());
      }
    }
    _loadExtras();
  }

  // ตัวเลขสรุป + ประวัติ — โหลดไม่ได้ก็ยังแก้ตั้งค่าได้
  Future<void> _loadExtras() async {
    try {
      final s = await _svc.fetchSummary();
      if (mounted) setState(() => _summary = s);
    } catch (_) {
      if (mounted) setState(() => _summary = null);
    }
    try {
      final revals = await _svc.fetchRevaluations();
      if (mounted) setState(() => _revals = revals.take(5).toList());
    } catch (_) {}
  }

  void _applySaved() {
    final s = _saved;
    int? z(int? v) => v == null || v == 0 ? null : v;
    _fxGainId = z(s?.fxGainAccountId);
    _fxLossId = z(s?.fxLossAccountId);
    _ufxGainId = z(s?.unrealizedFxGainAccountId);
    _ufxLossId = z(s?.unrealizedFxLossAccountId);
    _fxRevalDocId = z(s?.fxRevalGlDocId);
    _snapshot = _fingerprint();
  }

  ApYearEndSetup _buildSetup() => ApYearEndSetup(
        fxGainAccountId: _fxGainId,
        fxLossAccountId: _fxLossId,
        unrealizedFxGainAccountId: _ufxGainId,
        unrealizedFxLossAccountId: _ufxLossId,
        fxRevalGlDocId: _fxRevalDocId,
      );

  String _fingerprint() => jsonEncode(_buildSetup().toJson());

  bool get isDirty => _editing && _fingerprint() != _snapshot;

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _save() async {
    final e = _isEnglish;
    setState(() => _isSaving = true);
    try {
      await _svc.saveSetup(_buildSetup());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      if (mounted) setState(() => _isSaving = false);
      await _loadAll();
    } catch (ex) {
      if (mounted) _showError(ex.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancel() async {
    if (isDirty && !await confirmDiscardChanges(context, _isEnglish)) return;
    setState(() {
      _applySaved();
      _editing = false;
    });
  }

  Account? _findAccount(int? id) => id == null ? null : _accounts.where((a) => a.id == id).firstOrNull;
  ModuleDocument? _findDoc(int? id) => id == null ? null : _glDocs.where((d) => d.id == id).firstOrNull;
  String _accountLabel(Account a) => _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
  String _docLabel(ModuleDocument d) => _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  Future<Account?> _pickAccount(String title) async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);
    Account? picked;
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
                  hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty
                      ? List.from(_accounts)
                      : _accounts
                          .where((a) =>
                              a.accountCode.toLowerCase().contains(lq) ||
                              a.accountNameThai.toLowerCase().contains(lq) ||
                              a.accountNameEng.toLowerCase().contains(lq))
                          .toList();
                }),
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
                      title: Text('${a.accountCode}  ${_accountLabel(a)}', style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        picked = a;
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<ModuleDocument?> _pickGlDoc() async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(_glDocs);
    ModuleDocument? picked;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(isEnglish ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search' : 'ค้นหา',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty
                      ? List.from(_glDocs)
                      : _glDocs
                          .where((d) =>
                              d.docCode.toLowerCase().contains(lq) ||
                              d.docNameThai.toLowerCase().contains(lq) ||
                              d.docNameEng.toLowerCase().contains(lq))
                          .toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text('${d.docCode}  ${_docLabel(d)}', style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        picked = d;
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  // ── ส่วนที่ 1: บัญชีและเอกสาร ────────────────────────────────────────────────────
  Widget _accField(String label, int? id, void Function(int?) set) {
    final a = _findAccount(id);
    return kFk(
      label: label,
      text: a == null ? (id == null ? '' : '#$id') : '${a.accountCode} ${_accountLabel(a)}',
      hasValue: id != null,
      onSearch: () async {
        final p = await _pickAccount(label);
        if (p != null) setState(() => set(p.id));
      },
      onClear: () => setState(() => set(null)),
    );
  }

  Widget _docField(String label, int? id, void Function(int?) set) {
    final d = _findDoc(id);
    return kFk(
      label: label,
      text: d == null ? (id == null ? '' : '#$id') : '${d.docCode} ${_docLabel(d)}',
      hasValue: id != null,
      onSearch: () async {
        final p = await _pickGlDoc();
        if (p != null) setState(() => set(p.id));
      },
      onClear: () => setState(() => set(null)),
    );
  }

  Widget _missing(List<int?> ids, String usedFor) {
    final n = ids.where((v) => v == null).length;
    if (n == 0) return const SizedBox.shrink();
    return kNote(_isEnglish ? '$n not set yet · $usedFor' : 'ยังไม่ได้ตั้ง $n ช่อง · $usedFor', color: ImKit.red);
  }

  int get _missingCount => [_fxGainId, _fxLossId, _ufxGainId, _ufxLossId, _fxRevalDocId].where((v) => v == null).length;

  Widget _setupCard() {
    final e = _isEnglish;
    return kCard(
      title: e ? 'Accounts and document type' : 'บัญชีและประเภทเอกสาร',
      count: e ? 'Postable accounts only · red = not set' : 'เลือกได้เฉพาะบัญชีที่ลงรายการได้ · สีแดง = ยังไม่ได้ตั้ง',
      child: kGroups([
        kGroup(1, e ? 'FX revaluation — realized' : 'ปรับมูลค่าหนี้ FX แบบ Realized', ImKit.gDoc, [
          _accField(e ? 'FX gain account' : 'บัญชีกำไรอัตราแลกเปลี่ยน', _fxGainId, (v) => _fxGainId = v),
          _accField(e ? 'FX loss account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยน', _fxLossId, (v) => _fxLossId = v),
          _missing([_fxGainId, _fxLossId], e ? 'used by realized revaluation' : 'ใช้เมื่อปรับมูลค่าแบบ Realized'),
        ]),
        kGroup(2, e ? 'FX revaluation — reversing' : 'ปรับมูลค่าหนี้ FX แบบ Reversing', ImKit.gParty, [
          _accField(e ? 'Unrealized FX gain account' : 'บัญชีกำไรอัตราแลกเปลี่ยนที่ยังไม่เกิดขึ้น', _ufxGainId, (v) => _ufxGainId = v),
          _accField(e ? 'Unrealized FX loss account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยนที่ยังไม่เกิดขึ้น', _ufxLossId, (v) => _ufxLossId = v),
          _missing([_ufxGainId, _ufxLossId], e ? 'used by reversing revaluation (reversed at the start of the new period)' : 'ใช้เมื่อปรับมูลค่าแบบ Reversing (กลับรายการต้นงวดใหม่)'),
        ]),
        kGroup(3, e ? 'GL document type' : 'ประเภทเอกสาร GL', ImKit.gFin, [
          _docField(e ? 'FX revaluation document type' : 'ประเภทเอกสารปรับมูลค่าหนี้ FX', _fxRevalDocId, (v) => _fxRevalDocId = v),
          _missing([_fxRevalDocId], e ? 'used to create the GL entry' : 'ใช้สร้างรายการในบัญชีแยกประเภท'),
        ]),
      ]),
    );
  }

  // ── ส่วนที่ 2: เจ้าหนี้สกุลต่างประเทศที่ค้าง ──────────────────────────────────────────
  void _openReval() => ImKit.openMenu(context, 'ApFxRevaluationScreen', 'ปรับมูลค่าหนี้จากอัตราแลกเปลี่ยน', 'AP FX Revaluation', _isEnglish);

  Widget _fxCard() {
    final e = _isEnglish;
    final s = _summary;
    final fx = s?.currencies ?? const <ApFxOpenCurrency>[];
    return kCard(
      title: e ? 'Foreign-currency payables' : 'เจ้าหนี้ค้างสกุลเงินต่างประเทศ',
      count: e ? 'Bills / debit notes open today — candidates for FX revaluation' : 'ใบตั้งหนี้/เพิ่มหนี้ที่ค้าง ณ วันนี้ — รายการที่ต้องปรับมูลค่า FX',
      trailing: kGhost(e ? 'FX revaluation' : 'ปรับมูลค่าหนี้ FX', Icons.open_in_new, _openReval),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Currency' : 'สกุลเงิน', 2),
          KCol(e ? 'Vendors' : 'ผู้ขาย', 2, num: true),
          KCol(e ? 'Open docs' : 'เอกสารค้าง', 2, num: true),
          KCol(e ? 'Balance (doc currency)' : 'ยอดค้าง (สกุลเอกสาร)', 4, num: true),
          KCol(e ? 'Balance (base, last rate)' : 'ยอดค้าง (สกุลหลัก ตามอัตราล่าสุด)', 4, num: true),
        ],
        [
          for (final c in fx)
            [
              kCell(c.currencyCode, bold: true),
              kCell('${c.vendorCount}', mono: true),
              kCell('${c.docCount}', mono: true),
              kCell(_money.format(c.balanceFc), mono: true),
              kCell(_money.format(c.balanceLc), mono: true),
            ],
          if (fx.length > 1)
            [
              kCell(e ? 'Total' : 'รวม', bold: true),
              kCell(''),
              kCell('${s!.docCount}', mono: true, bold: true),
              kCell(''),
              kCell(_money.format(s.balanceLc), mono: true, bold: true),
            ],
        ],
        minWidth: 620,
        empty: s == null
            ? (e ? 'Could not load open payables' : 'โหลดยอดค้างไม่ได้')
            : (e ? 'No foreign-currency payables open' : 'ไม่มีเจ้าหนี้ค้างสกุลต่างประเทศ'),
      ),
    );
  }

  // ── ส่วนที่ 3: ประวัติการปรับมูลค่า FX ────────────────────────────────────────────
  Widget _statusChip(String s) {
    final e = _isEnglish;
    return switch (s) {
      'Posted' => ImKit.chip(e ? 'Posted' : 'ลงบัญชีแล้ว', ImKit.okSoft, ImKit.ok),
      'Void' => ImKit.chip(e ? 'Void' : 'ยกเลิก', ImKit.redSoft, ImKit.red),
      'Reversed' => ImKit.chip(e ? 'Reversed' : 'กลับรายการ', ImKit.goldSoft, ImKit.amber),
      _ => ImKit.chip(e ? 'Draft' : 'ร่าง', ImKit.ro, ImKit.ink2),
    };
  }

  Widget _historyCard() {
    final e = _isEnglish;
    return kCard(
      title: e ? 'FX revaluation history' : 'ประวัติการปรับมูลค่า FX',
      count: e ? 'Latest 5' : '5 ครั้งล่าสุด',
      trailing: kGhost(e ? 'FX revaluation' : 'ปรับมูลค่าหนี้ FX', Icons.open_in_new, _openReval),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Date' : 'วันที่', 3),
          KCol(e ? 'Method' : 'วิธี', 3),
          KCol(e ? 'Year' : 'ปี', 2),
          KCol(e ? 'Status' : 'สถานะ', 3),
          KCol(e ? 'Gain (loss)' : 'กำไร (ขาดทุน)', 3, num: true),
          KCol(e ? 'GL doc no.' : 'เลขที่เอกสาร GL', 3),
        ],
        [
          for (final r in _revals)
            [
              kCell(_dateFmt.format(r.revalDate), mono: true),
              kCell(r.method == 'reversing' ? 'Reversing' : 'Realized', color: ImKit.ink2),
              kCell('${r.periodYear}', mono: true),
              _statusChip(r.status),
              kCell(r.totalFxGainLoss < 0 ? '(${_money.format(-r.totalFxGainLoss)})' : _money.format(r.totalFxGainLoss),
                  mono: true, color: r.totalFxGainLoss < -0.005 ? ImKit.red : null),
              kCell(r.glDocNo ?? '', mono: true),
            ],
        ],
        onTap: [for (final _ in _revals) _openReval],
        minWidth: 680,
        empty: e ? 'No FX revaluation yet' : 'ยังไม่เคยปรับมูลค่า FX',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    final miss = _missingCount;
    final last = _revals.where((r) => r.status == 'Posted').firstOrNull;
    return kKpis([
      ImKpi(
        e ? 'Last FX revaluation' : 'ปรับมูลค่า FX ล่าสุด',
        last == null ? '—' : _dateFmt.format(last.revalDate),
        last == null
            ? (e ? 'none posted yet' : 'ยังไม่เคยลงบัญชี')
            : '${last.glDocNo ?? ''} · ${last.totalFxGainLoss < 0 ? (e ? 'loss' : 'ขาดทุน') : (e ? 'gain' : 'กำไร')} ${_money.format(last.totalFxGainLoss.abs())}',
        onTap: _openReval,
      ),
      ImKpi(
        e ? 'Foreign-currency payables' : 'เจ้าหนี้สกุลต่างประเทศค้าง',
        s == null ? '—' : (e ? '${s.docCount} doc(s)' : '${s.docCount} ใบ'),
        s == null || s.currencies.isEmpty
            ? (e ? 'none open' : 'ไม่มียอดค้าง')
            : s.currencies.map((c) => e ? '${c.currencyCode} ${c.vendorCount} vendor(s)' : '${c.currencyCode} ${c.vendorCount} ราย').join(' · '),
      ),
      ImKpi(e ? 'Open balance (base)' : 'ยอดค้าง (สกุลหลัก)', s == null ? '—' : _money.format(s.balanceLc),
          e ? 'at the last booked rate' : 'ตามอัตราล่าสุดของเอกสาร'),
      ImKpi(e ? 'Setup not complete' : 'ช่องที่ยังไม่ได้ตั้ง', '$miss', e ? 'of 5 accounts / document type' : 'จาก 5 บัญชี/ประเภทเอกสาร', warn: miss > 0),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    Widget body;
    if (_isLoading && _saved == null && _accounts.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final ink = ScreenTheme.of(context).ink;
      final acts = _editing
          ? [
              DocBarAction(e ? 'Cancel' : 'ยกเลิก', _isSaving ? null : _cancel, fg: ink),
              DocBarAction(_isSaving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _isSaving ? null : _save,
                  fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
            ]
          : [
              DocBarAction(e ? 'Pre-close check' : 'ไปหน้าตรวจก่อนปิดปี',
                  () => ImKit.openMenu(context, 'ApPreCloseCheckScreen', 'ตรวจสอบก่อนปิดปี AP', 'AP Pre-close Check', e), fg: ink),
              if (canEdit) DocBarAction(e ? 'Edit' : 'แก้ไข', () => setState(() => _editing = true), fg: Colors.white, bg: ink, primary: true),
            ];
      body = kPage(
        header: kHeaderBar(
          title: e ? 'AP year-end setup' : 'ตั้งค่าสิ้นปี AP',
          badges: [
            if (_editing) kEditingBadge(),
            _missingCount == 0
                ? ImKit.chip(e ? 'Complete' : 'ตั้งครบแล้ว', ImKit.okSoft, ImKit.ok)
                : ImKit.chip(e ? '$_missingCount not set' : 'ยังไม่ได้ตั้ง $_missingCount ช่อง', ImKit.redSoft, ImKit.red),
          ],
          acts: acts,
          busy: _isSaving,
        ),
        top: _kpis(),
        sections: [
          (0, e ? 'Accounts' : 'บัญชีและเอกสาร', _setupCard()),
          (1, e ? 'Foreign currency' : 'เจ้าหนี้สกุลต่างประเทศ', _fxCard()),
          (2, e ? 'History' : 'ประวัติ', _historyCard()),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: ScreenTheme.of(context).bar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: e ? 'Refresh' : 'รีเฟรช',
            onPressed: _isSaving
                ? null
                : () async {
                    if (isDirty && !await confirmDiscardChanges(context, e)) return;
                    _loadAll();
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
