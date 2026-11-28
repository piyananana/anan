// lib/ar/screens/ar_year_end_setup_screen.dart — ตั้งค่าสิ้นปี AR แบบ B ของ IM (user 2026-11-28)
//   แก้ไขครั้งเดียวทั้งหน้า (บัญชี/เอกสาร + อัตราค่าเผื่อหนี้) แทนปุ่มบันทึกแยก 2 แท็บเดิม
//   บัญชีที่ยังไม่ได้ตั้งขึ้นสีแดง, ช่วงอายุหนี้ทับกันบันทึกไม่ได้ (backend ตรวจซ้ำ), ช่วงที่ขาดแสดงเตือน
//   ตัวเลขสรุป + ค่าเผื่อที่คำนวณได้ต่อช่วง ณ วันนี้ + ยอดค้างสกุลต่างประเทศ + ประวัติการประมวลผล
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/utils/sa_menu_theme.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/ar_year_end.dart';
import '../services/ar_year_end_service.dart';

class ArYearEndSetupScreen extends StatefulWidget {
  const ArYearEndSetupScreen({super.key});

  @override
  State<ArYearEndSetupScreen> createState() => _ArYearEndSetupScreenState();
}

// แถวอัตราค่าเผื่อหนี้ที่กำลังแก้
class _RuleRow {
  final TextEditingController from;
  final TextEditingController to;
  final TextEditingController rate;
  bool active;
  _RuleRow(ArAllowanceRule r)
      : from = TextEditingController(text: '${r.ageFromDays}'),
        to = TextEditingController(text: r.ageToDays == null ? '' : '${r.ageToDays}'),
        rate = TextEditingController(text: r.rate.toStringAsFixed(2)),
        active = r.isActive;
  int? get fromV => int.tryParse(from.text.trim());
  int? get toV => to.text.trim().isEmpty ? null : int.tryParse(to.text.trim());
  bool get toInvalid => to.text.trim().isNotEmpty && int.tryParse(to.text.trim()) == null;
  double? get rateV => double.tryParse(rate.text.trim());
  void dispose() {
    from.dispose();
    to.dispose();
    rate.dispose();
  }
}

class _ArYearEndSetupScreenState extends State<ArYearEndSetupScreen> with AutomaticKeepAliveClientMixin, ImMasterKit {
  final ArYearEndService _svc = ArYearEndService();
  final AccountService _acctSvc = AccountService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();

  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];

  bool _isEnglish = false;
  bool _editing = false;

  int? _fxGainId, _fxLossId, _ufxGainId, _ufxLossId;
  int? _allowExpId, _allowContraId, _fxRevalDocId, _allowDocId;
  ArYearEndSetup? _saved;
  List<ArAllowanceRule> _savedRules = [];
  List<_RuleRow> _rows = [];

  Map<String, dynamic>? _summary;
  List<ArAllowanceRunHeader> _runs = [];
  List<ArFxRevaluationHeader> _revals = [];
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

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchSetup(),
        _svc.fetchAllowanceRules(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      _saved = results[0] as ArYearEndSetup?;
      _savedRules = List<ArAllowanceRule>.from(results[1] as List);
      _accounts = (results[2] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
      _glDocs = (results[3] as List<ModuleDocument>).where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
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
      final runs = await _svc.fetchAllowanceRuns();
      final revals = await _svc.fetchRevaluations();
      if (mounted) {
        setState(() {
          _runs = runs.take(5).toList();
          _revals = revals.take(5).toList();
        });
      }
    } catch (_) {}
  }

  void _applySaved() {
    final s = _saved;
    int? z(int? v) => v == null || v == 0 ? null : v;
    _fxGainId = z(s?.fxGainAccountId);
    _fxLossId = z(s?.fxLossAccountId);
    _ufxGainId = z(s?.unrealizedFxGainAccountId);
    _ufxLossId = z(s?.unrealizedFxLossAccountId);
    _allowExpId = z(s?.allowanceExpenseAccountId);
    _allowContraId = z(s?.allowanceContraAccountId);
    _fxRevalDocId = z(s?.fxRevalGlDocId);
    _allowDocId = z(s?.allowanceGlDocId);
    for (final r in _rows) {
      r.dispose();
    }
    _rows = [for (final r in _savedRules) _RuleRow(r)];
    _snapshot = _fingerprint();
  }

  ArYearEndSetup _buildSetup() => ArYearEndSetup(
        fxGainAccountId: _fxGainId,
        fxLossAccountId: _fxLossId,
        unrealizedFxGainAccountId: _ufxGainId,
        unrealizedFxLossAccountId: _ufxLossId,
        allowanceExpenseAccountId: _allowExpId,
        allowanceContraAccountId: _allowContraId,
        fxRevalGlDocId: _fxRevalDocId,
        allowanceGlDocId: _allowDocId,
      );

  List<ArAllowanceRule> _buildRules() => [
        for (var i = 0; i < _rows.length; i++)
          ArAllowanceRule(
            ageFromDays: _rows[i].fromV ?? 0,
            ageToDays: _rows[i].toV,
            rate: _rows[i].rateV ?? 0,
            sortOrder: i + 1,
            isActive: _rows[i].active,
          ),
      ];

  String _fingerprint() => jsonEncode({
        'setup': _buildSetup().toJson(),
        'rules': [for (final r in _rows) [r.from.text, r.to.text, r.rate.text, r.active]],
      });

  bool get isDirty => _editing && _fingerprint() != _snapshot;

  // ── ตรวจช่วงอายุหนี้: ทับกัน (บันทึกไม่ได้) / ช่องว่าง (เตือน) ─────────────────────────
  Set<int> _overlapRows() {
    final bad = <int>{};
    for (var i = 0; i < _rows.length; i++) {
      final a = _rows[i];
      if (!a.active || a.fromV == null) continue;
      final aTo = a.toV ?? 1 << 30;
      for (var j = i + 1; j < _rows.length; j++) {
        final b = _rows[j];
        if (!b.active || b.fromV == null) continue;
        final bTo = b.toV ?? 1 << 30;
        if (a.fromV! <= bTo && b.fromV! <= aTo) bad.addAll([i, j]);
      }
    }
    return bad;
  }

  Set<int> _invalidRows() {
    final bad = <int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final rate = r.rateV;
      if (r.fromV == null || r.fromV! < 0 || r.toInvalid || (r.toV != null && r.toV! < r.fromV!) || rate == null || rate < 0 || rate > 100) {
        bad.add(i);
      }
    }
    return bad;
  }

  // ช่วงอายุที่ไม่มีอัตรา (ไม่ตั้งค่าเผื่อ) — คิดจากแถวที่ใช้งานและถูกต้อง
  List<String> _gaps(bool e) {
    final list = [
      for (final r in _rows)
        if (r.active && r.fromV != null && !(r.toV != null && r.toV! < r.fromV!)) (r.fromV!, r.toV)
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = <String>[];
    var next = 0;
    for (final r in list) {
      if (r.$1 > next) out.add(r.$1 - 1 == next ? '$next' : '$next–${r.$1 - 1}');
      if (r.$2 == null) return out;
      if (r.$2! + 1 > next) next = r.$2! + 1;
    }
    out.add(e ? '$next+' : '$next ขึ้นไป');
    return out;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _save() async {
    final e = _isEnglish;
    if (_invalidRows().isNotEmpty) {
      _showError(e ? 'Check the allowance rates: "to" must not be before "from", rate 0–100' : 'ตรวจอัตราค่าเผื่อ: ถึงวันต้องไม่น้อยกว่าตั้งแต่วัน และอัตรา 0–100');
      return;
    }
    if (_overlapRows().isNotEmpty) {
      _showError(e ? 'Age ranges overlap — fix the red rows before saving' : 'ช่วงอายุหนี้ทับกัน — แก้แถวสีแดงก่อนบันทึก');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _svc.saveSetup(_buildSetup());
      await _svc.saveAllowanceRules(_buildRules());
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

  // ── Account picker dialog ─────────────────────────────────────────────────
  Future<Account?> _pickAccount(String title) async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);
    Account? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            final lq = q.toLowerCase();
            filtered = q.isEmpty
                ? List.from(_accounts)
                : _accounts.where((a) =>
                    a.accountCode.toLowerCase().contains(lq) ||
                    a.accountNameThai.toLowerCase().contains(lq) ||
                    a.accountNameEng.toLowerCase().contains(lq)).toList();
          });
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520, height: 420,
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
                      title: Text('${a.accountCode}  ${_accountLabel(a)}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  // ── GL Doc picker dialog ──────────────────────────────────────────────────
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
            width: 480, height: 380,
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
                onChanged: (q) {
                  setDlg(() {
                    final lq = q.toLowerCase();
                    filtered = q.isEmpty
                        ? List.from(_glDocs)
                        : _glDocs.where((d) =>
                            d.docCode.toLowerCase().contains(lq) ||
                            d.docNameThai.toLowerCase().contains(lq) ||
                            d.docNameEng.toLowerCase().contains(lq)).toList();
                  });
                },
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
                      title: Text('${d.docCode}  ${_docLabel(d)}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = d; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
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

  Widget _missing(List<int?> ids) {
    final n = ids.where((v) => v == null).length;
    if (n == 0) return const SizedBox.shrink();
    return kNote(_isEnglish ? '$n not set yet' : 'ยังไม่ได้ตั้ง $n ช่อง', color: ImKit.red);
  }

  int get _missingCount =>
      [_fxGainId, _fxLossId, _ufxGainId, _ufxLossId, _allowExpId, _allowContraId, _fxRevalDocId, _allowDocId].where((v) => v == null).length;

  Widget _setupCard() {
    final e = _isEnglish;
    return kCard(
      title: e ? 'Accounts and document types' : 'บัญชีและประเภทเอกสาร',
      count: e ? 'Postable accounts only · red = not set' : 'เลือกได้เฉพาะบัญชีที่ลงรายการได้ · สีแดง = ยังไม่ได้ตั้ง',
      child: kGroups([
        kGroup(1, e ? 'FX revaluation — realized' : 'ปรับมูลค่าหนี้ FX แบบ Realized', ImKit.gDoc, [
          _accField(e ? 'FX gain account' : 'บัญชีกำไรอัตราแลกเปลี่ยน', _fxGainId, (v) => _fxGainId = v),
          _accField(e ? 'FX loss account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยน', _fxLossId, (v) => _fxLossId = v),
          _missing([_fxGainId, _fxLossId]),
        ]),
        kGroup(2, e ? 'FX revaluation — reversing' : 'ปรับมูลค่าหนี้ FX แบบ Reversing', ImKit.gParty, [
          _accField(e ? 'Unrealized FX gain account' : 'บัญชีกำไรอัตราแลกเปลี่ยนที่ยังไม่เกิดขึ้น', _ufxGainId, (v) => _ufxGainId = v),
          _accField(e ? 'Unrealized FX loss account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยนที่ยังไม่เกิดขึ้น', _ufxLossId, (v) => _ufxLossId = v),
          _missing([_ufxGainId, _ufxLossId]),
        ]),
        kGroup(3, e ? 'Allowance for doubtful accounts' : 'ค่าเผื่อหนี้สงสัยจะสูญ', ImKit.gFin, [
          _accField(e ? 'Allowance expense account' : 'บัญชีหนี้สงสัยจะสูญ (ค่าใช้จ่าย)', _allowExpId, (v) => _allowExpId = v),
          _accField(e ? 'Allowance contra account' : 'บัญชีค่าเผื่อหนี้สงสัยจะสูญสะสม (contra)', _allowContraId, (v) => _allowContraId = v),
          _missing([_allowExpId, _allowContraId]),
        ]),
        kGroup(4, e ? 'GL document types' : 'ประเภทเอกสาร GL', ImKit.gMore, [
          _docField(e ? 'FX revaluation document type' : 'ประเภทเอกสารปรับมูลค่าหนี้ FX', _fxRevalDocId, (v) => _fxRevalDocId = v),
          _docField(e ? 'Allowance adjustment document type' : 'ประเภทเอกสารปรับปรุงค่าเผื่อหนี้', _allowDocId, (v) => _allowDocId = v),
          _missing([_fxRevalDocId, _allowDocId]),
        ]),
      ]),
    );
  }

  // ── ส่วนที่ 2: อัตราค่าเผื่อหนี้ + ค่าเผื่อที่คำนวณได้ ณ วันนี้ ──────────────────────────
  Map<String, dynamic>? _calcFor(_RuleRow r) {
    // ค่าที่คำนวณจาก server ตรงกับแถวที่บันทึกไว้เท่านั้น (แถวที่กำลังแก้ยังไม่มีผลคำนวณ)
    final list = ((_summary?['rules'] as List?) ?? const []).cast<Map<String, dynamic>>();
    for (final s in list) {
      final to = s['age_to_days'];
      if (s['age_from_days'] == r.fromV && (to == null ? r.toV == null : to == r.toV) && ((s['rate'] as num).toDouble() - (r.rateV ?? -1)).abs() < 0.005 && r.active) {
        return s;
      }
    }
    return null;
  }

  Widget _numField(TextEditingController c, {bool decimal = false, String? hint, bool error = false}) => TextField(
        controller: c,
        readOnly: kitReadOnly,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[\d.]' : r'\d'))],
        style: const TextStyle(fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: kitReadOnly ? InputBorder.none : const OutlineInputBorder(),
          enabledBorder: kitReadOnly ? InputBorder.none : OutlineInputBorder(borderSide: BorderSide(color: error ? ImKit.red : const Color(0xFFC9D1CC))),
        ),
        onChanged: (_) => setState(() {}),
      );

  Widget _rulesCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final overlap = _overlapRows();
    final invalid = _invalidRows();
    final gaps = _gaps(e);
    final s = _summary;
    final unmatched = (s?['unmatched_count'] as num?)?.toInt() ?? 0;
    return kCard(
      title: e ? 'Allowance rates by age' : 'อัตราค่าเผื่อหนี้สงสัยจะสูญตามอายุหนี้',
      count: e ? 'Age = days past due · calculated as of today' : 'อายุ = จำนวนวันที่เกินกำหนด · คำนวณ ณ วันนี้',
      trailing: ro
          ? null
          : kGhost(e ? 'Add range' : 'เพิ่มช่วง', Icons.add, () {
              final last = _rows.isEmpty ? null : _rows.last;
              final start = last == null ? 0 : ((last.toV ?? last.fromV ?? 0) + 1);
              setState(() => _rows.add(_RuleRow(ArAllowanceRule(ageFromDays: start, rate: 0))));
            }),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable(
          [
            KCol(e ? 'From (days)' : 'ตั้งแต่ (วัน)', 3, num: true),
            KCol(e ? 'To (days)' : 'ถึง (วัน)', 3, num: true),
            KCol(e ? 'Rate %' : 'อัตรา %', 3, num: true),
            KCol(e ? 'Active' : 'ใช้งาน', 2),
            KCol(e ? 'Docs' : 'ใบ', 2, num: true),
            KCol(e ? 'Outstanding' : 'ยอดค้าง', 4, num: true),
            KCol(e ? 'Allowance' : 'ค่าเผื่อ', 4, num: true),
            const KCol('', 1),
          ],
          [
            for (var i = 0; i < _rows.length; i++)
              () {
                final r = _rows[i];
                final c = _calcFor(r);
                final bad = overlap.contains(i) || invalid.contains(i);
                return [
                  _numField(r.from, error: bad),
                  _numField(r.to, hint: e ? 'no limit' : 'ไม่จำกัด', error: bad),
                  _numField(r.rate, decimal: true, error: bad),
                  Checkbox(
                    value: r.active,
                    visualDensity: VisualDensity.compact,
                    onChanged: ro ? null : (v) => setState(() => r.active = v ?? true),
                  ),
                  kCell(c == null ? '' : '${c['doc_count']}', mono: true),
                  kCell(c == null ? '' : _money.format((c['balance'] as num).toDouble()), mono: true),
                  kCell(c == null ? '' : _money.format((c['allowance'] as num).toDouble()), mono: true, bold: true),
                  ro
                      ? const SizedBox.shrink()
                      : kIconBtn(Icons.delete_outline, e ? 'Remove' : 'ลบ', () => setState(() => _rows.removeAt(i).dispose()), color: ImKit.red),
                ];
              }(),
          ],
          rowColors: [for (var i = 0; i < _rows.length; i++) overlap.contains(i) || invalid.contains(i) ? ImKit.redSoft : null],
          minWidth: 760,
          rowMinHeight: 44,
          empty: e ? 'No rates yet — allowance cannot be calculated' : 'ยังไม่มีอัตรา — คำนวณค่าเผื่อหนี้ไม่ได้',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (overlap.isNotEmpty)
              kNote(e ? 'Red rows overlap — each age may fall into one range only. Save is blocked.' : 'แถวสีแดงช่วงอายุทับกัน — อายุหนึ่งต้องอยู่ได้ช่วงเดียว บันทึกไม่ได้จนกว่าจะแก้', color: ImKit.red),
            if (invalid.isNotEmpty && overlap.isEmpty)
              kNote(e ? 'Red rows are invalid: "to" before "from", or rate not 0–100' : 'แถวสีแดงไม่ถูกต้อง: ถึงวันน้อยกว่าตั้งแต่วัน หรืออัตราไม่อยู่ใน 0–100', color: ImKit.red),
            if (gaps.isNotEmpty && _rows.isNotEmpty)
              kNote(e ? 'No rate for ages ${gaps.join(', ')} days — no allowance is set for those documents' : 'อายุ ${gaps.join(', ')} วัน ไม่มีอัตรา — เอกสารช่วงนี้ไม่ตั้งค่าเผื่อ', color: ImKit.amber),
            if (unmatched > 0 && !_editing)
              kNote(e ? '$unmatched past-due document(s) fall outside every range today' : 'วันนี้มีเอกสารเกินกำหนด $unmatched ใบที่ไม่เข้าช่วงใดเลย', color: ImKit.amber),
            if (_editing) kNote(e ? 'Calculated columns refresh after saving' : 'คอลัมน์ที่คำนวณจะอัปเดตหลังบันทึก'),
          ]),
        ),
      ]),
    );
  }

  // ── ส่วนที่ 3: ยอดค้างสกุลต่างประเทศ ────────────────────────────────────────────
  Widget _fxCard() {
    final e = _isEnglish;
    final fx = ((_summary?['fx_currencies'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return kCard(
      title: e ? 'Foreign-currency receivables' : 'ลูกหนี้ค้างสกุลเงินต่างประเทศ',
      count: e ? 'Invoices / debit notes open today — candidates for FX revaluation' : 'ใบแจ้งหนี้/เพิ่มหนี้ที่ค้าง ณ วันนี้ — รายการที่ต้องปรับมูลค่า FX',
      trailing: kGhost(e ? 'FX revaluation' : 'ปรับมูลค่าหนี้ FX', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ArFxRevaluationScreen', 'ปรับมูลค่าหนี้จากอัตราแลกเปลี่ยน', 'AR FX Revaluation', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [KCol(e ? 'Currency' : 'สกุลเงิน', 3), KCol(e ? 'Open docs' : 'เอกสารค้าง', 3, num: true), KCol(e ? 'Balance (base currency, booked rate)' : 'ยอดค้าง (สกุลหลัก ตามอัตราที่บันทึก)', 6, num: true)],
        [
          for (final c in fx)
            [
              kCell('${c['currency_code']}', bold: true),
              kCell('${c['doc_count']}', mono: true),
              kCell(_money.format((c['balance_lc'] as num?)?.toDouble() ?? 0), mono: true),
            ],
        ],
        minWidth: 520,
        empty: e ? 'No foreign-currency receivables open' : 'ไม่มีลูกหนี้ค้างสกุลต่างประเทศ',
      ),
    );
  }

  // ── ส่วนที่ 4: ประวัติการประมวลผล ───────────────────────────────────────────────
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
    final rows = <List<Widget>>[];
    for (final r in _runs) {
      rows.add([
        kCell(e ? 'Allowance' : 'ค่าเผื่อหนี้', color: ImKit.ink2),
        kCell(_dateFmt.format(r.runDate), mono: true),
        kCell('${r.periodYear}', mono: true),
        _statusChip(r.status),
        kCell(_money.format(r.adjustmentAmount), mono: true),
        kCell(r.glDocNo ?? '', mono: true),
      ]);
    }
    for (final r in _revals) {
      rows.add([
        kCell(r.method == 'reversing' ? (e ? 'FX (reversing)' : 'FX (Reversing)') : (e ? 'FX (realized)' : 'FX (Realized)'), color: ImKit.ink2),
        kCell(_dateFmt.format(r.revalDate), mono: true),
        kCell('${r.periodYear}', mono: true),
        _statusChip(r.status),
        kCell(_money.format(r.totalFxGainLoss), mono: true),
        kCell(r.glDocNo ?? '', mono: true),
      ]);
    }
    return kCard(
      title: e ? 'Processing history' : 'ประวัติการประมวลผล',
      count: e ? 'Latest 5 of each' : 'ล่าสุดอย่างละ 5 รายการ',
      trailing: kGhost(e ? 'Allowance run' : 'ประมวลผลค่าเผื่อหนี้', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ArAllowanceRunScreen', 'ประมวลผลค่าเผื่อหนี้สงสัยจะสูญ', 'AR Allowance Run', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Process' : 'งาน', 3),
          KCol(e ? 'Date' : 'วันที่', 3),
          KCol(e ? 'Year' : 'ปี', 2),
          KCol(e ? 'Status' : 'สถานะ', 3),
          KCol(e ? 'Amount' : 'จำนวนเงิน', 3, num: true),
          KCol(e ? 'GL doc no.' : 'เลขที่เอกสาร GL', 3),
        ],
        rows,
        minWidth: 680,
        empty: e ? 'Nothing processed yet' : 'ยังไม่เคยประมวลผล',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    final miss = _missingCount;
    final missTile = ImKpi(e ? 'Setup not complete' : 'ช่องที่ยังไม่ได้ตั้ง', '$miss', e ? 'of 8 accounts / document types' : 'จาก 8 บัญชี/ประเภทเอกสาร', warn: miss > 0);
    if (s == null) return kKpis([missTile]);
    double d(String k) => (s[k] as num?)?.toDouble() ?? 0;
    final contra = _findAccount(_allowContraId);
    return kKpis([
      ImKpi(e ? 'Allowance needed today' : 'ค่าเผื่อที่ควรตั้ง ณ วันนี้', _money.format(d('total_allowance')), e ? 'at the saved rates' : 'ตามอัตราที่บันทึกไว้'),
      ImKpi(e ? 'Booked allowance' : 'ยอดค่าเผื่อสะสมใน GL', _money.format(d('prior_allowance')),
          contra == null ? (e ? 'contra account not set' : 'ยังไม่ได้ตั้งบัญชีสะสม') : contra.accountCode),
      ImKpi(e ? 'Adjustment needed' : 'ต้องปรับปรุง', _money.format(d('adjustment')), e ? 'needed − booked' : 'ที่ควรตั้ง − ยอดสะสม',
          warn: d('adjustment').abs() > 0.005,
          onTap: () => ImKit.openMenu(context, 'ArAllowanceRunScreen', 'ประมวลผลค่าเผื่อหนี้สงสัยจะสูญ', 'AR Allowance Run', e)),
      missTile,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    Widget body;
    if (_isLoading && _saved == null && _savedRules.isEmpty) {
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
              if (canEdit) DocBarAction(e ? 'Edit' : 'แก้ไข', () => setState(() => _editing = true), fg: Colors.white, bg: ink, primary: true),
            ];
      body = kPage(
        header: kHeaderBar(
          title: e ? 'AR year-end setup' : 'ตั้งค่าสิ้นปี AR',
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
          (1, e ? 'Allowance rates' : 'อัตราค่าเผื่อหนี้', _rulesCard()),
          (2, e ? 'Foreign currency' : 'ลูกหนี้สกุลต่างประเทศ', _fxCard()),
          (3, e ? 'History' : 'ประวัติ', _historyCard()),
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
