// lib/sa/widgets/sa_gl_setup_kit.dart
// หน้าจอ "ประเภทเอกสาร ... เชื่อมต่อ GL" แบบเดียวกับ IM (im_gl_account_setup_screen.dart, user 2026-11-26)
// ใช้ร่วม AR / AP / CM / MO — แต่ละโมดูลส่ง GlSetupSpec (ช่องบัญชีต่อ sys_doc_type, ค่าที่ใช้แทนเมื่อเว้นว่าง, Dr/Cr)
// ซ้าย: การ์ดจัดกลุ่ม + ป้าย ครบ/ขาด N/ไม่ลงบัญชี + ตัวกรองยังไม่ครบ
// ขวา: แถบหัว (ดู → แก้ไข), ตัวเลขสรุป, ประเภทเอกสาร GL, ตารางรหัสบัญชีพร้อม "ถ้าเว้นว่าง ใช้", ตัวอย่างการลงบัญชี,
//      สำเนาการตั้งค่าจากประเภทเอกสารอื่นใต้ประเภทระบบเดียวกัน
// ข้อมูลเป็น Map ดิบจาก GET <baseUrl> (คอลัมน์ <x>_account_id / <x>_account_code / <x>_account_name, gl_doc_id ...)
// บันทึกด้วย POST <baseUrl>/<doc_code> — ช่องที่ประเภทนี้ไม่ใช้ บันทึกเป็นค่าว่างเสมอ (เหมือน IM)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../im/widgets/im_master_kit.dart';
import '../models/sa_module_document.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../services/sa_module_document_service.dart';
import '../utils/sa_menu_scope.dart';
import 'sa_doc_appbar_actions.dart';
import 'sa_sys_doc_type_guide.dart';

/// ช่องบัญชีหนึ่งช่องของการตั้งค่า
class GlAcct {
  final String key; // คอลัมน์ เช่น 'ar_account_id'
  final String th, en;
  final bool Function(String sdt) show;

  /// ว่างแล้วลงบัญชีไม่ได้ (นับเป็น "ยังไม่ตั้ง")
  final bool Function(String sdt)? requiredFor;

  /// "ถ้าเว้นว่าง ใช้" — null = ไม่มีค่าอื่นแทน
  final String? fbTh, fbEn;

  /// ข้อความเมื่อไม่มีค่าอื่นแทนและไม่บังคับ (เช่น ต้องตั้งเมื่อมีรายการนั้น)
  final String? optTh, optEn;

  /// "ตั้งที่ชั้นอื่นได้"
  final String levelsTh, levelsEn;

  /// ป้ายต่อ sys_doc_type (ถ้าต่างจากป้ายปกติ)
  final String? Function(String sdt, bool e)? labelOf;

  const GlAcct(this.key, this.th, this.en,
      {required this.show,
      this.requiredFor,
      this.fbTh,
      this.fbEn,
      this.optTh,
      this.optEn,
      this.levelsTh = '—',
      this.levelsEn = '—',
      this.labelOf});

  bool req(String sdt) => requiredFor?.call(sdt) ?? false;
  String label(String sdt, bool e) => labelOf?.call(sdt, e) ?? (e ? en : th);
}

/// บรรทัดตัวอย่างการลงบัญชี: key = บัญชีในหน้านี้ / ไม่มี key = ข้อความ
class GlJ {
  final String drCr;
  final String? key;
  final String? th, en; // ข้อความ (ไม่มี key) หรือหมายเหตุท้ายบัญชี
  const GlJ(this.drCr, this.key, [this.th, this.en]);
  const GlJ.text(this.drCr, String this.th, String this.en) : key = null;
}

class GlJSection {
  final String? th, en;
  final List<GlJ> lines;
  const GlJSection(this.lines, {this.th, this.en});
}

class GlSetupSpec {
  final String module; // AR / AP / CM / MO
  final String? guideModule; // ปุ่มคู่มือประเภทระบบ (null = ไม่แสดง)
  final String baseUrl;
  final List<GlAcct> accounts;
  final bool Function(String sdt) noGl;
  final bool Function(String sdt)? showGlDoc; // ค่าปกติ = !noGl
  final String Function(String sdt) groupOf;
  final List<(String, String, String)> groups; // (key, th, en)
  final List<GlJSection> Function(String sdt) journal;
  final String? Function(String sdt, bool e)? banner;
  final String? glDocTh, glDocEn; // ป้ายช่องประเภทเอกสาร GL (ถ้าต่างจากปกติ)
  final String? glDocHintTh, glDocHintEn;
  final String placeholderTh, placeholderEn;

  const GlSetupSpec({
    required this.module,
    this.guideModule,
    required this.baseUrl,
    required this.accounts,
    required this.noGl,
    this.showGlDoc,
    required this.groupOf,
    required this.groups,
    required this.journal,
    this.banner,
    this.glDocTh,
    this.glDocEn,
    this.glDocHintTh,
    this.glDocHintEn,
    required this.placeholderTh,
    required this.placeholderEn,
  });

  bool glDocShown(String sdt) => showGlDoc?.call(sdt) ?? !noGl(sdt);

  /// ช่องที่ยังไม่ตั้ง — นับเฉพาะช่องบังคับที่ไม่มีค่าอื่นมาแทน
  List<String> missing(String sdt, bool e, int? Function(String key) idOf) {
    if (noGl(sdt)) return const [];
    return [
      if (glDocShown(sdt) && idOf('gl_doc_id') == null) e ? 'GL document type' : 'ประเภทเอกสาร GL',
      for (final a in accounts)
        if (a.show(sdt) && a.req(sdt) && idOf(a.key) == null) a.label(sdt, e),
    ];
  }
}

int? _int(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String _sib(String key, String suffix) => key.replaceFirst(RegExp(r'_id$'), suffix);

class _Svc {
  final AuthService _auth = AuthService();
  final String base;
  _Svc(this.base);

  Future<dynamic> _get(String url) async {
    final res = await http.get(Uri.parse(url), headers: await _auth.getAuthHeader());
    if (res.statusCode == 200) return json.decode(res.body);
    if (res.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> rows() async => [for (final r in (await _get(base) as List)) Map<String, dynamic>.from(r as Map)];

  Future<Map<String, dynamic>> summary(String docCode) async =>
      Map<String, dynamic>.from(await _get('$base/${Uri.encodeComponent(docCode)}/summary') as Map);

  Future<Map<String, dynamic>> save(String docCode, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$base/${Uri.encodeComponent(docCode)}'), headers: await _auth.getAuthHeader(), body: jsonEncode(body));
    if (res.statusCode == 200) return Map<String, dynamic>.from(json.decode(res.body) as Map);
    if (res.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    String msg = res.body;
    try {
      msg = (json.decode(res.body) as Map)['message']?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }
}

class GlSetupScreen extends StatefulWidget {
  final GlSetupSpec spec;
  const GlSetupScreen({super.key, required this.spec});

  @override
  State<GlSetupScreen> createState() => _GlSetupScreenState();
}

class _GlSetupScreenState extends State<GlSetupScreen> with AutomaticKeepAliveClientMixin {
  late final _Svc _svc = _Svc(widget.spec.baseUrl);
  final ModuleDocumentService _docSvc = ModuleDocumentService();
  final AccountService _acctSvc = AccountService();
  final GlobalKey<_GlSetupFormState> _formKey = GlobalKey();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];
  Map<String, ModuleDocument> _docByCode = {};

  bool _isEnglish = false;
  bool _isLoading = true;
  String _selectedDocCode = '';
  String _search = '';
  String _filter = ''; // '' ทั้งหมด / MISSING / <group key>

  GlSetupSpec get spec => widget.spec;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([_svc.rows(), _acctSvc.fetchRows(), _docSvc.fetchRows()]);
      setState(() {
        _rows = results[0] as List<Map<String, dynamic>>;
        _accounts = (results[1] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        final docs = results[2] as List<ModuleDocument>;
        _docByCode = {for (final d in docs.where((d) => d.isDocType)) d.docCode: d};
        _glDocs = docs.where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()..sort((a, b) => a.docCode.compareTo(b.docCode));
        _isLoading = false;
        if (_rows.isNotEmpty && (_selectedDocCode.isEmpty || !_rows.any((r) => r['doc_code'] == _selectedDocCode))) {
          _selectedDocCode = '${_rows.first['doc_code']}';
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'โหลดข้อมูลล้มเหลว: $e')));
      }
    }
  }

  Map<String, dynamic>? get _selected => _rows.where((r) => r['doc_code'] == _selectedDocCode).firstOrNull;

  String _sdtOf(Map<String, dynamic> r) => '${r['sys_doc_type'] ?? ''}';

  String _docLabel(Map<String, dynamic> r, bool e) {
    final code = '${r['doc_code']}';
    final en = '${r['doc_name_eng'] ?? _docByCode[code]?.docNameEng ?? ''}';
    return e && en.isNotEmpty ? en : '${r['doc_name_thai'] ?? code}';
  }

  List<String> _missingOf(Map<String, dynamic> r, bool e) => spec.missing(_sdtOf(r), e, (k) => _int(r[k]));

  Future<bool> _confirmLeave() async {
    final f = _formKey.currentState;
    if (f != null && f.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _select(String docCode) async {
    if (docCode == _selectedDocCode) return;
    if (!await _confirmLeave()) return;
    setState(() => _selectedDocCode = docCode);
  }

  Future<bool> _onSave(String docCode, Map<String, dynamic> body) async {
    final isEnglish = _isEnglish;
    try {
      final saved = await _svc.save(docCode, body);
      setState(() {
        final idx = _rows.indexWhere((r) => r['doc_code'] == docCode);
        if (idx >= 0) _rows[idx] = saved;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e'), backgroundColor: Colors.red));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final sel = _selected;

    Widget detail;
    if (_isLoading && _rows.isEmpty) {
      detail = const ColoredBox(color: ImKit.pageBg, child: Center(child: CircularProgressIndicator()));
    } else if (sel == null) {
      detail = Builder(builder: (ctx) => ImListToggle.placeholder(ctx, Icons.account_tree_outlined, isEnglish ? spec.placeholderEn : spec.placeholderTh));
    } else {
      final sdt = _sdtOf(sel);
      detail = _GlSetupForm(
        key: _formKey,
        spec: spec,
        row: sel,
        title: _docLabel(sel, isEnglish),
        accounts: _accounts,
        glDocs: _glDocs,
        siblings: [
          for (final r in _rows)
            if (_sdtOf(r) == sdt && r['doc_code'] != sel['doc_code']) (r, _docLabel(r, isEnglish)),
        ],
        svc: _svc,
        onSave: _onSave,
      );
    }

    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 320,
      barActions: [
        if (spec.guideModule != null)
          SysDocTypeGuideButton(
            module: spec.guideModule!,
            isEnglish: isEnglish,
            docCodesBySdt: SysDocTypeGuideButton.groupDocCodes(_rows, (r) => r['sys_doc_type'] as String?, (r) => '${r['doc_code']}'),
            currentSdt: sel == null ? null : _sdtOf(sel),
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: isEnglish ? 'Reload' : 'โหลดใหม่',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            _loadAll();
          },
        ),
      ],
      list: _buildList(isEnglish),
      detail: detail,
    );
  }

  Widget _buildList(bool e) {
    final q = _search.trim().toLowerCase();
    final missingOf = {for (final r in _rows) '${r['doc_code']}': _missingOf(r, e)};
    final groupKeys = spec.groups.map((g) => g.$1).toList();
    bool match(Map<String, dynamic> r) {
      final sdt = _sdtOf(r);
      if (_filter == 'MISSING' && (missingOf['${r['doc_code']}']?.isEmpty ?? true)) return false;
      if (groupKeys.contains(_filter) && spec.groupOf(sdt) != _filter) return false;
      if (q.isEmpty) return true;
      return '${r['doc_code']}'.toLowerCase().contains(q) ||
          '${r['doc_name_thai'] ?? ''}'.toLowerCase().contains(q) ||
          _docLabel(r, true).toLowerCase().contains(q) ||
          sdt.contains(q);
    }

    final shown = _rows.where(match).toList();
    final missingCount = _rows.where((r) => missingOf['${r['doc_code']}']!.isNotEmpty).length;
    final groups = <(String, String, String), List<Map<String, dynamic>>>{};
    for (final g in spec.groups) {
      final list = shown.where((r) => spec.groupOf(_sdtOf(r)) == g.$1).toList();
      if (list.isNotEmpty) groups[g] = list;
    }

    Widget card(Map<String, dynamic> r) {
      final sdt = _sdtOf(r);
      final code = '${r['doc_code']}';
      final miss = missingOf[code]!;
      final noGl = spec.noGl(sdt);
      final status = noGl
          ? ImKit.chip(e ? 'No GL' : 'ไม่ลงบัญชี', ImKit.ro, ImKit.gMore)
          : miss.isEmpty
              ? ImKit.chip(e ? 'Complete' : 'ครบ', ImKit.okSoft, ImKit.ok)
              : ImKit.chip(e ? '${miss.length} missing' : 'ขาด ${miss.length}', ImKit.redSoft, ImKit.red);
      final meta = noGl
          ? (e ? 'Nothing to set up' : 'ไม่ต้องตั้งค่า')
          : spec.glDocShown(sdt)
              ? 'GL: ${r['gl_doc_code'] ?? (e ? 'not set' : 'ยังไม่ตั้ง')}'
              : (e ? 'Uses the bank account GL accounts' : 'ใช้บัญชี GL ของบัญชีธนาคาร');
      return Tooltip(
        message: miss.isEmpty ? '' : miss.join(', '),
        child: ImMasterListCard(
          code: code,
          chips: [if (sdt.isNotEmpty) ImKit.chip(sdt, ImKit.blueSoft, ImKit.blue), status],
          name: _docLabel(r, e),
          meta: TextSpan(text: meta),
          selected: code == _selectedDocCode,
          active: r['doc_is_active'] != false,
          onTap: () => _select(code),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อประเภทเอกสาร',
        onSearch: (v) => setState(() => _search = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All ${_rows.length}' : 'ทั้งหมด ${_rows.length}', on: _filter == '', onTap: () => setState(() => _filter = '')),
          ImMasterFilterChip(
              label: e ? 'Incomplete $missingCount' : 'ยังไม่ครบ $missingCount',
              on: _filter == 'MISSING',
              fg: missingCount > 0 ? ImKit.red : null,
              onTap: () => setState(() => _filter = _filter == 'MISSING' ? '' : 'MISSING')),
          if (spec.groups.length > 1)
            for (final g in spec.groups)
              ImMasterFilterChip(label: e ? g.$3 : g.$2, on: _filter == g.$1, onTap: () => setState(() => _filter = _filter == g.$1 ? '' : g.$1)),
        ],
        countText: e ? 'Showing ${shown.length} of ${_rows.length}' : 'แสดง ${shown.length} จาก ${_rows.length} รายการ',
      ),
      Expanded(
        child: _isLoading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.only(bottom: 12), children: [
                for (final g in groups.entries) ...[
                  if (spec.groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                      child: Row(children: [
                        Expanded(child: Text(e ? g.key.$3 : g.key.$2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ImKit.ink2))),
                        Text('${g.value.length}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ImKit.ink2)),
                      ]),
                    ),
                  for (final r in g.value) card(r),
                ],
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(e ? 'No document types match' : 'ไม่พบประเภทเอกสารที่ตรงเงื่อนไข', textAlign: TextAlign.center, style: const TextStyle(color: ImKit.ink2)),
                  ),
              ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Form widget
// ═══════════════════════════════════════════════════════════════════════════════
typedef _Val = ({int? id, String? code, String? name});

class _GlSetupForm extends StatefulWidget {
  final GlSetupSpec spec;
  final Map<String, dynamic> row;
  final String title;
  final List<Account> accounts;
  final List<ModuleDocument> glDocs;
  final List<(Map<String, dynamic>, String)> siblings; // (row, ชื่อที่แสดง)
  final _Svc svc;
  final Future<bool> Function(String docCode, Map<String, dynamic> body) onSave;

  const _GlSetupForm({
    super.key,
    required this.spec,
    required this.row,
    required this.title,
    required this.accounts,
    required this.glDocs,
    required this.siblings,
    required this.svc,
    required this.onSave,
  });

  @override
  State<_GlSetupForm> createState() => _GlSetupFormState();
}

class _GlSetupFormState extends State<_GlSetupForm> with ImMasterKit {
  bool _isEnglish = false;
  bool _editing = false;
  bool _isSaving = false;
  String _snapshot = '';
  Map<String, dynamic>? _summary;
  int _summarySeq = 0;
  final Map<String, _Val> _v = {}; // account keys + 'gl_doc_id'

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => !_editing;

  GlSetupSpec get spec => widget.spec;
  String get _docCode => '${widget.row['doc_code']}';
  String get _sdt => '${widget.row['sys_doc_type'] ?? ''}';
  bool get _noGl => spec.noGl(_sdt);
  List<GlAcct> get _shownAccts => spec.accounts.where((a) => a.show(_sdt)).toList();

  @override
  void initState() {
    super.initState();
    _isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    _loadFrom(widget.row);
    _snapshot = _fp();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant _GlSetupForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row['doc_code'] != oldWidget.row['doc_code']) {
      _loadFrom(widget.row);
      _editing = false;
      _snapshot = _fp();
      _summary = null;
      kScrollTop();
      _loadSummary();
    } else if (!identical(widget.row, oldWidget.row) && !_editing) {
      _loadFrom(widget.row); // บันทึกแล้ว — แถวใหม่จากเซิร์ฟเวอร์
      _snapshot = _fp();
    }
  }

  void _loadFrom(Map<String, dynamic> r) {
    _v.clear();
    for (final k in [...spec.accounts.map((a) => a.key), 'gl_doc_id']) {
      _v[k] = (id: _int(r[k]), code: r[_sib(k, '_code')] as String?, name: r[_sib(k, '_name')] as String?);
    }
  }

  String _fp() => [for (final k in _v.keys) _v[k]!.id].join('|');
  bool get isDirty => _editing && _fp() != _snapshot;

  Future<void> _loadSummary() async {
    final seq = ++_summarySeq;
    try {
      final s = await widget.svc.summary(_docCode);
      if (mounted && seq == _summarySeq) setState(() => _summary = s);
    } catch (_) {
      if (mounted && seq == _summarySeq) setState(() => _summary = null);
    }
  }

  String _acctName(int? id, String? stored) {
    if (id != null) {
      final a = widget.accounts.where((a) => a.id == id).firstOrNull;
      if (a != null) return _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
    }
    return stored ?? '';
  }

  String _glDocName(int? id, String? stored) {
    final d = widget.glDocs.where((d) => d.id == id).firstOrNull;
    if (d == null) return stored ?? '';
    return _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;
  }

  // ── ตัวเลือก ──
  Future<T?> _pick<T>(String title, List<T> items, String Function(T) label, {String Function(T)? search}) async {
    final e = _isEnglish;
    final searchCtrl = TextEditingController();
    List<T> filtered = List.from(items);
    T? picked;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
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
                  isDense: true,
                ),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty ? List.from(items) : items.where((x) => (search ?? label)(x).toLowerCase().contains(lq)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(label(filtered[i]), style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      picked = filtered[i];
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(e ? 'Cancel' : 'ยกเลิก'))],
        ),
      ),
    );
    searchCtrl.dispose();
    return picked;
  }

  // บัญชีที่ค้นหา: ทั้งชื่อไทยและอังกฤษ (feedback_bilingual_account_picker_gap) — รายการมีเฉพาะบัญชีลงรายการได้อยู่แล้ว
  String _acctPickLabel(Account a) => '${a.accountCode}  ${_isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai}';

  Future<void> _pickAccount(String key, String title) async {
    final a = await _pick<Account>(title, widget.accounts, _acctPickLabel,
        search: (a) => '${a.accountCode} ${a.accountNameThai} ${a.accountNameEng}');
    if (a != null) setState(() => _v[key] = (id: a.id, code: a.accountCode, name: a.accountNameThai));
  }

  Future<void> _pickGlDoc() async {
    final e = _isEnglish;
    final d = await _pick<ModuleDocument>(
        e ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL', widget.glDocs, (d) => '${d.docCode}  ${e && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}',
        search: (d) => '${d.docCode} ${d.docNameThai} ${d.docNameEng}');
    if (d != null) setState(() => _v['gl_doc_id'] = (id: d.id, code: d.docCode, name: d.docNameThai));
  }

  // ── บันทึก / ยกเลิก / สำเนา ──
  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      // ช่องที่ประเภทนี้ไม่ใช้ บันทึกเป็นค่าว่างเสมอ — ไม่ให้ค่าเก่าค้างในฐานข้อมูลโดยผู้ใช้มองไม่เห็น
      final body = <String, dynamic>{
        for (final a in spec.accounts) a.key: a.show(_sdt) ? _v[a.key]!.id : null,
        'gl_doc_id': spec.glDocShown(_sdt) ? _v['gl_doc_id']!.id : null,
      };
      final ok = await widget.onSave(_docCode, body);
      if (ok && mounted) {
        setState(() {
          _editing = false;
          _snapshot = _fp();
        });
        _loadSummary();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEdit() => setState(() {
        _loadFrom(widget.row);
        _editing = false;
      });

  void _startEdit() => setState(() {
        _editing = true;
        _snapshot = _fp();
      });

  void _copyFrom(Map<String, dynamic> src) {
    final e = _isEnglish;
    if (!_editing) _startEdit();
    setState(() => _loadFrom(src));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e ? 'Copied the setup of ${src['doc_code']} — check it, then save' : 'คัดลอกการตั้งค่าจาก ${src['doc_code']} แล้ว ตรวจสอบแล้วกดบันทึก')));
  }

  List<String> _currentMissing(bool e) => spec.missing(_sdt, e, (k) => _v[k]?.id);

  // ── ส่วนต่างๆ ──
  List<ImKpi> _kpis(bool e) {
    final missing = _currentMissing(e);
    final usage = _summary?['usage'] as Map<String, dynamic>?;
    final by = (usage?['by_status'] as Map<String, dynamic>?) ?? const {};
    final last = usage?['last_doc'] as Map<String, dynamic>?;
    final lastDate = last == null ? null : DateTime.tryParse('${last['doc_date']}');
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final statusText = by.entries.map((x) => '${x.key} ${x.value}').join(' · ');
    final sib = widget.siblings;
    return [
      ImKpi(e ? 'Fields not set' : 'ช่องที่ยังไม่ตั้ง', '${missing.length}', missing.isEmpty ? (e ? 'Ready to post' : 'พร้อมใช้งาน') : missing.join(', '),
          warn: missing.isNotEmpty),
      ImKpi(e ? 'Documents of this type' : 'เอกสารที่ใช้ประเภทนี้', usage == null ? '—' : '${usage['total'] ?? 0}',
          statusText.isEmpty ? (e ? 'None yet' : 'ยังไม่มี') : statusText),
      ImKpi(e ? 'Last used' : 'ใช้ล่าสุด', lastDate == null ? '—' : fmt(lastDate), last == null ? (e ? 'Never used' : 'ยังไม่เคยใช้') : '${last['doc_no'] ?? ''}'),
      ImKpi(e ? 'Other types under system type $_sdt' : 'ประเภทอื่นใต้ประเภทระบบ $_sdt', '${sib.length}',
          sib.isEmpty ? (e ? 'None' : 'ไม่มี') : '${sib.map((s) => s.$1['doc_code']).join(', ')} · ${e ? 'can copy setup' : 'สำเนาการตั้งค่าได้'}'),
    ];
  }

  Widget _banner(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: ImKit.blueSoft, border: Border.all(color: const Color(0xFFC7D9F0)), borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 16, color: ImKit.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: ImKit.blue))),
        ]),
      );

  Widget _buildLinkCard(bool e) {
    final banner = spec.banner?.call(_sdt, e);
    final gl = _v['gl_doc_id']!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_noGl) _banner(e ? 'This document type does not post to the GL — no accounts to set up.' : 'เอกสารประเภทนี้ไม่ลงบัญชี GL — ไม่ต้องตั้งค่ารหัสบัญชี'),
      if (banner != null) ...[if (_noGl) const SizedBox(height: 8), _banner(banner)],
      if (!_noGl && spec.glDocShown(_sdt)) ...[
        if (_noGl || banner != null) const SizedBox(height: 12),
        kCard(
          title: e ? 'GL document type' : 'ประเภทเอกสาร GL',
          trailing: kLegend(withAuto: false),
          child: kGroups([
            kGroup(1, e ? 'GL document type' : 'ประเภทเอกสาร GL', ImKit.gMore, [
              kFk(
                label: '${e ? (spec.glDocEn ?? 'GL document type (for posting)') : (spec.glDocTh ?? 'ประเภทเอกสาร GL (สำหรับ Post)')} *',
                text: '${gl.code}  ${_glDocName(gl.id, gl.name)}',
                hasValue: gl.id != null,
                onSearch: _pickGlDoc,
                onClear: () => setState(() => _v['gl_doc_id'] = (id: null, code: null, name: null)),
              ),
              if (spec.glDocHintTh != null) kNote(e ? spec.glDocHintEn! : spec.glDocHintTh!),
            ]),
          ]),
        ),
      ],
    ]);
  }

  Widget _acctCell(String key, String title) {
    final e = _isEnglish;
    final v = _v[key]!;
    final has = v.id != null;
    final text = has ? '${v.code}  ${_acctName(v.id, v.name)}' : (e ? '— Not specified —' : '— ไม่ระบุ —');
    final style = TextStyle(fontSize: 12.5, color: has ? null : ImKit.ink3);
    if (!_editing) return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    return InkWell(
      onTap: () => _pickAccount(key, title),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(5)),
        child: Row(children: [
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          if (has)
            IconButton(
              icon: const Icon(Icons.clear, size: 15, color: Colors.red),
              tooltip: e ? 'Clear' : 'ล้าง',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => setState(() => _v[key] = (id: null, code: null, name: null)),
            ),
          const Icon(Icons.search, size: 16, color: Colors.teal),
        ]),
      ),
    );
  }

  /// (ข้อความ "ถ้าเว้นว่าง ใช้", สีแดงไหม)
  (String, bool) _fallback(GlAcct a, bool e) {
    if (a.req(_sdt)) return (e ? 'None — set it here' : 'ไม่มี — ต้องตั้งที่นี่', true);
    if (a.fbTh != null) return (e ? a.fbEn! : a.fbTh!, false);
    if (a.optTh != null) return (e ? a.optEn! : a.optTh!, false);
    return (e ? 'None' : 'ไม่มี', false);
  }

  Widget _buildAccountsCard(bool e) {
    final sib = widget.siblings;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    final copyLabel = e ? 'Copy from another type' : 'สำเนาจากประเภทอื่น';
    final Widget? copyBtn = !canEdit
        ? null
        : sib.isEmpty
            ? Tooltip(
                message: e ? 'No other ${spec.module} doc types under system type $_sdt' : 'ไม่มีประเภทเอกสาร ${spec.module} อื่นใต้ประเภทระบบ $_sdt',
                child: kGhost(copyLabel, Icons.content_copy, null),
              )
            : PopupMenuButton<Map<String, dynamic>>(
                tooltip: copyLabel,
                onSelected: _copyFrom,
                itemBuilder: (_) => [for (final s in sib) PopupMenuItem(value: s.$1, child: Text('${s.$1['doc_code']}  ${s.$2}'))],
                child: IgnorePointer(child: kGhost(copyLabel, Icons.content_copy, () {})),
              );

    final accts = _shownAccts;
    return kCard(
      title: e ? 'Account codes' : 'รหัสบัญชี',
      count: e ? 'Only the accounts system type $_sdt posts to' : 'แสดงเฉพาะบัญชีที่ประเภทระบบ $_sdt ใช้ลงบัญชี',
      trailing: copyBtn,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable(
          [
            KCol(e ? 'Account' : 'บัญชี', 3),
            KCol(e ? 'Account of this type' : 'รหัสบัญชีของประเภทนี้', 6),
            KCol(e ? 'If blank, uses' : 'ถ้าเว้นว่าง ใช้', 6),
            KCol(e ? 'Can also be set at' : 'ตั้งที่ชั้นอื่นได้', 3),
          ],
          [
            for (final a in accts)
              () {
                final label = a.label(_sdt, e);
                final fb = _fallback(a, e);
                final blank = _v[a.key]!.id == null;
                return [
                  Text.rich(
                    TextSpan(text: label, children: [if (a.req(_sdt)) const TextSpan(text: ' *', style: TextStyle(color: ImKit.red))]),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  _acctCell(a.key, label),
                  Text(fb.$1, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: blank && fb.$2 ? ImKit.red : ImKit.ink2)),
                  Text(e ? a.levelsEn : a.levelsTh, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ImKit.ink2)),
                ];
              }(),
          ],
          minWidth: 820,
          rowMinHeight: 44,
          empty: e ? 'This type uses no accounts from this page' : 'ประเภทนี้ไม่ใช้รหัสบัญชีจากหน้านี้',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: kNote(e
              ? '* required to post · Accounts this type does not use are hidden and cleared on save.'
              : '* จำเป็นสำหรับการ Post · บัญชีที่ประเภทนี้ไม่ใช้จะไม่แสดง และล้างเป็นค่าว่างตอนบันทึก'),
        ),
      ]),
    );
  }

  Widget? _buildJournal(bool e) {
    final sections = spec.journal(_sdt);
    if (sections.isEmpty) return null;
    final byKey = {for (final a in spec.accounts) a.key: a};
    final rows = <Widget>[];
    Widget line(GlJ l) {
      String text;
      var missing = false;
      var dim = false;
      if (l.key == null) {
        text = e ? l.en! : l.th!;
        dim = l.drCr.isEmpty;
      } else {
        final a = byKey[l.key]!;
        final v = _v[l.key]!;
        if (v.id != null) {
          text = '${v.code}  ${_acctName(v.id, v.name)}';
        } else if (a.req(_sdt)) {
          text = '(${a.label(_sdt, e)} — ${e ? 'not set' : 'ยังไม่ตั้งค่า'})';
          missing = true;
        } else if (a.fbTh != null) {
          text = '(${a.label(_sdt, e)} — ${e ? a.fbEn : a.fbTh})';
          dim = true;
        } else {
          text = '(${a.label(_sdt, e)} — ${e ? 'not set' : 'ยังไม่ตั้งค่า'})';
          dim = true;
        }
        final note = e ? l.en : l.th;
        if (note != null) text = '$text  ($note)';
      }
      final dc = l.drCr.trim();
      final indent = l.drCr.startsWith('  ');
      return Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 56,
            child: Text(dc,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: dc == 'Dr' || dc == 'Dr/Cr' ? ImKit.blue : (dc.isEmpty ? ImKit.ink3 : ImKit.gParty))),
          ),
          if (indent) const SizedBox(width: 24),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12.5, color: missing ? ImKit.red : (dim ? ImKit.ink2 : null), fontWeight: missing ? FontWeight.w600 : null)),
          ),
        ]),
      );
    }

    for (final s in sections) {
      if (s.th != null) {
        rows.add(Container(
          color: const Color(0xFFF6F8FA),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(e ? s.en! : s.th!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ImKit.ink2)),
        ));
      }
      rows.addAll(s.lines.map(line));
    }
    return kCard(
      title: e ? 'Journal preview' : 'ตัวอย่างการลงบัญชี',
      count: e ? 'System type $_sdt' : 'ประเภทระบบ $_sdt',
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    final missing = _currentMissing(e);
    final acts = _editing
        ? [
            DocBarAction(e ? 'Cancel' : 'ยกเลิก', _isSaving ? null : _cancelEdit, fg: kInk),
            DocBarAction(_isSaving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _isSaving ? null : _submit,
                fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
          ]
        : [if (canEdit && !_noGl) DocBarAction(e ? 'Edit' : 'แก้ไข', _startEdit, fg: Colors.white, bg: kInk, primary: true)];
    final journal = _noGl ? null : _buildJournal(e);
    return kPage(
      header: kHeaderBar(
        code: _docCode,
        title: widget.title,
        badges: [
          if (_sdt.isNotEmpty) ImKit.chip(e ? 'System type $_sdt' : 'ประเภทระบบ $_sdt', Colors.white24, Colors.white),
          if (_editing) kEditingBadge(),
          if (_noGl)
            ImKit.chip(e ? 'No GL' : 'ไม่ลงบัญชี', ImKit.ro, ImKit.gMore)
          else if (missing.isEmpty)
            ImKit.chip(e ? 'Complete' : 'ครบ', ImKit.okSoft, ImKit.ok)
          else
            Tooltip(message: missing.join(', '), child: ImKit.chip(e ? '${missing.length} missing' : 'ขาด ${missing.length}', ImKit.redSoft, ImKit.red)),
          if (widget.row['doc_is_active'] == false) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.redSoft, ImKit.red),
        ],
        acts: acts,
        busy: _isSaving,
      ),
      top: _noGl ? null : kKpis(_kpis(e)),
      sections: [
        (0, e ? 'Document links' : 'การเชื่อมเอกสาร', _buildLinkCard(e)),
        if (!_noGl) (1, e ? 'Account codes' : 'รหัสบัญชี', _buildAccountsCard(e)),
        if (journal != null) (2, e ? 'Journal preview' : 'ตัวอย่างการลงบัญชี', journal),
      ],
    );
  }
}
