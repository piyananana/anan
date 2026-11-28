// lib/gl/screens/gl_dimension_type_screen.dart
// หน้าจอประเภทมิติ แบบ IM design B (user 2026-11-28):
//   ซ้าย = การ์ด 5 ช่อง (slot) ตายตัว (ช่องที่ยังไม่เปิดใช้สีจาง) + จำนวนค่า / บัญชีที่ต้องระบุ
//   ขวา = รายละเอียดช่อง (เปิดมาเป็นโหมดดู แก้ไขผ่านแถบหัว) + ตัวเลขสรุป + บัญชีที่ใช้มิตินี้ + ค่าในมิตินี้
// รหัส (type_code) แก้ไม่ได้เมื่อมีค่ามิติหรือบัญชีอ้างแล้ว (backend ตรวจซ้ำ)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_account.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';

class GlDimensionTypeScreen extends StatefulWidget {
  const GlDimensionTypeScreen({super.key});

  @override
  State<GlDimensionTypeScreen> createState() => _GlDimensionTypeScreenState();
}

class _GlDimensionTypeScreenState extends State<GlDimensionTypeScreen> {
  final _svc = GlDimensionService();
  final GlobalKey<_DimTypeDetailState> _detailKey = GlobalKey();
  List<GlDimensionType> _types = [];
  Set<int> _saved = {}; // ช่องที่มีแถวใน DB แล้ว
  Map<int, GlDimTypeUsage> _usage = {};
  bool _loading = false;
  String? _filter; // on | off
  int? _slot;
  bool _editing = false;
  int _requestSeq = 0;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _svc.fetchAllTypes();
      Map<int, GlDimTypeUsage> usage = {};
      try {
        usage = await _svc.fetchTypeUsage();
      } catch (_) {}
      final bySlot = {for (final r in rows) r.slotNo: r};
      if (!mounted) return;
      setState(() {
        _saved = bySlot.keys.toSet();
        _types = [
          for (var s = 1; s <= 5; s++)
            bySlot[s] ?? GlDimensionType(slotNo: s, typeCode: 'DIM$s', nameThai: 'Dimension $s', nameEng: 'Dimension $s', isActive: false, sortOrder: s),
        ];
        _usage = usage;
        _slot ??= 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _select(int slot) async {
    if (_slot == slot && !_editing) return;
    if (!await _confirmLeave()) return;
    setState(() {
      _slot = slot;
      _editing = false;
      _requestSeq++;
    });
  }

  Future<void> _save(GlDimensionType t) async {
    final e = _isEnglish;
    try {
      await _svc.upsertType(t);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกเรียบร้อย')));
      await _load();
      if (mounted) {
        setState(() {
          _editing = false;
          _requestSeq++;
        });
      }
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  String _name(GlDimensionType t, bool e) => e && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;

  Widget _list(bool e) {
    final shown = _types.where((t) => _filter == null || (_filter == 'on') == (t.isActive && _saved.contains(t.slotNo))).toList();
    final on = _types.where((t) => t.isActive && _saved.contains(t.slotNo)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          ImMasterFilterChip(label: e ? 'All 5' : 'ทั้งหมด 5', on: _filter == null, onTap: () => setState(() => _filter = null)),
          ImMasterFilterChip(label: e ? 'Enabled $on' : 'เปิดใช้ $on', on: _filter == 'on', onTap: () => setState(() => _filter = _filter == 'on' ? null : 'on')),
          ImMasterFilterChip(label: e ? 'Not enabled ${5 - on}' : 'ยังไม่เปิด ${5 - on}', on: _filter == 'off',
              onTap: () => setState(() => _filter = _filter == 'off' ? null : 'off')),
        ]),
      ),
      Expanded(
        child: _loading && _types.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                for (final t in shown)
                  () {
                    final enabled = t.isActive && _saved.contains(t.slotNo);
                    final u = _usage[t.slotNo];
                    return ImMasterListCard(
                      code: '${e ? 'Slot' : 'ช่อง'} ${t.slotNo} · ${t.typeCode}',
                      chips: [
                        enabled
                            ? ImKit.chip(e ? 'Enabled' : 'เปิดใช้', ImKit.okSoft, ImKit.ok)
                            : ImKit.chip(e ? 'Not enabled' : 'ยังไม่เปิด', ImKit.ro, ImKit.gMore),
                      ],
                      name: _name(t, e),
                      meta: TextSpan(
                          text: u == null || u.valueCount == 0 && u.requiredAccounts == 0 && u.optionalAccounts == 0
                              ? (e ? 'No values yet' : 'ยังไม่มีค่า')
                              : e
                                  ? 'values ${u.valueCount} · required on ${u.requiredAccounts} · optional ${u.optionalAccounts}'
                                  : 'ค่า ${u.valueCount} · บัญชีต้องระบุ ${u.requiredAccounts} · ระบุได้ ${u.optionalAccounts}'),
                      selected: _slot == t.slotNo,
                      active: enabled,
                      onTap: () => _select(t.slotNo),
                    );
                  }(),
              ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    final t = _slot == null || _types.isEmpty ? null : _types.firstWhere((x) => x.slotNo == _slot);
    final u = t == null ? null : _usage[t.slotNo];
    final used = u != null && (u.valueCount > 0 || u.requiredAccounts > 0 || u.optionalAccounts > 0);
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 300,
      barActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            setState(() => _editing = false);
            await _load();
            setState(() => _requestSeq++);
          },
        ),
      ],
      list: _list(e),
      detail: t == null
          ? ImListToggle.placeholder(context, Icons.view_module_outlined, e ? 'Select a slot on the left' : 'เลือกช่องมิติทางซ้าย')
          : _DimTypeDetail(
              key: _detailKey,
              type: t,
              saved: _saved.contains(t.slotNo),
              codeLocked: used,
              editing: _editing,
              requestSeq: _requestSeq,
              onEdit: canEdit
                  ? () => setState(() {
                        _editing = true;
                        _requestSeq++;
                      })
                  : null,
              onCancel: () async {
                if (!await _confirmLeave()) return;
                setState(() {
                  _editing = false;
                  _requestSeq++;
                });
              },
              onSave: _save,
            ),
    );
  }
}

class _DimTypeDetail extends StatefulWidget {
  final GlDimensionType type;
  final bool saved;
  final bool codeLocked;
  final bool editing;
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback onCancel;
  final Future<void> Function(GlDimensionType) onSave;
  const _DimTypeDetail({super.key, required this.type, required this.saved, required this.codeLocked, required this.editing,
      required this.requestSeq, this.onEdit, required this.onCancel, required this.onSave});

  @override
  State<_DimTypeDetail> createState() => _DimTypeDetailState();
}

class _DimTypeDetailState extends State<_DimTypeDetail> with ImMasterKit {
  final _svc = GlDimensionService();
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  bool _active = false;
  bool _saving = false;
  bool _isEnglish = false;
  bool _requiredTab = true;
  GlDimTypeSummary? _summary;
  bool _loadingSummary = false;
  int _seq = 0;
  String _snapshot = '';

  static final _int = NumberFormat('#,##0');

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => !widget.editing;

  bool get isDirty => widget.editing && _fp() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply(reloadSummary: true);
  }

  @override
  void didUpdateWidget(covariant _DimTypeDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final slotChanged = oldWidget.type.slotNo != widget.type.slotNo;
    if (slotChanged || oldWidget.requestSeq != widget.requestSeq || oldWidget.editing != widget.editing) {
      _apply(reloadSummary: slotChanged || !widget.editing);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  void _apply({required bool reloadSummary}) {
    final t = widget.type;
    _codeCtrl.text = t.typeCode;
    _nameThCtrl.text = t.nameThai;
    _nameEnCtrl.text = t.nameEng ?? '';
    // ช่องที่ยังไม่บันทึก: กดแก้ไข = ตั้งค่าเพื่อเปิดใช้
    _active = widget.saved ? t.isActive : widget.editing;
    if (reloadSummary) {
      _summary = null;
      _loadSummary();
      kScrollTop();
    }
    _snapshot = _fp();
  }

  Future<void> _loadSummary() async {
    final seq = ++_seq;
    _loadingSummary = true;
    try {
      final s = await _svc.fetchTypeSummary(widget.type.slotNo);
      if (mounted && seq == _seq) setState(() => _summary = s);
    } catch (_) {
    } finally {
      if (mounted && seq == _seq) setState(() => _loadingSummary = false);
    }
  }

  GlDimensionType _build() => GlDimensionType(
        slotNo: widget.type.slotNo,
        typeCode: _codeCtrl.text.trim().toUpperCase(),
        nameThai: _nameThCtrl.text.trim(),
        nameEng: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        isActive: _active,
        sortOrder: widget.type.sortOrder == 0 ? widget.type.slotNo : widget.type.sortOrder,
      );

  String _fp() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the code' : 'กรุณาระบุรหัส';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'กรุณาระบุชื่อภาษาไทย';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(_build());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _name(bool e) => e && (widget.type.nameEng ?? '').isNotEmpty ? widget.type.nameEng! : widget.type.nameThai;

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    return [
      ImKpi(e ? 'Values' : 'ค่าในมิติ', '${s.valueCount}',
          e ? 'active ${s.activeValues} · inactive ${s.valueCount - s.activeValues}' : 'ใช้งาน ${s.activeValues} · หยุดใช้ ${s.valueCount - s.activeValues}'),
      ImKpi(e ? 'Accounts requiring it' : 'บัญชีที่ต้องระบุ', '${s.requiredAccounts}',
          e ? 'optional on ${s.optionalAccounts}' : 'ระบุได้ (ไม่บังคับ) ${s.optionalAccounts}'),
      ImKpi(e ? 'Lines this year' : 'บรรทัดที่ใช้ปีนี้', _int.format(s.linesYear),
          e ? 'posted · fiscal year ${s.fyCode ?? '-'}' : 'GL Posted · ปีบัญชี ${s.fyCode ?? '-'}'),
      ImKpi(e ? 'Lines missing it' : 'บรรทัดขาดมิติ', _int.format(s.missingDraft),
          e ? 'draft lines on required accounts' : 'Draft บนบัญชีที่ต้องระบุ', warn: s.missingDraft > 0),
    ];
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ed = widget.editing;
    return kCard(
      title: e ? 'Dimension Type' : 'ข้อมูลประเภทมิติ',
      trailing: ed ? kLegend(withAuto: false) : null,
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            InputDecorator(
              decoration: kDec(e ? 'Slot' : 'ช่อง (slot)', editable: false),
              child: Text('${widget.type.slotNo}', style: const TextStyle(fontSize: ImKit.font)),
            ),
            kTxt(e ? 'Code (type_code) *' : 'รหัส (type_code) *', _codeCtrl, editable: ed && !widget.codeLocked, cap: TextCapitalization.characters),
          ]),
          kRow([
            kTxt(e ? 'Thai Name *' : 'ชื่อ (ไทย) *', _nameThCtrl),
            kTxt(e ? 'English Name' : 'ชื่อ (อังกฤษ)', _nameEnCtrl),
          ]),
          kNote(widget.codeLocked
              ? (e ? 'The code is locked because values or accounts already refer to it.' : 'รหัสแก้ไม่ได้ เพราะมีค่าหรือบัญชีอ้างถึงแล้ว')
              : (e ? 'The code cannot be changed once values or accounts refer to it.' : 'รหัสแก้ไม่ได้เมื่อมีค่าหรือบัญชีอ้างถึงแล้ว')),
        ]),
        kGroup(2, e ? 'Usage' : 'การใช้งาน', ImKit.gMore, [
          kChecks([kCk(e ? 'Enable this dimension' : 'เปิดใช้มิตินี้', _active, ed ? (v) => setState(() => _active = v) : null)]),
          kNote(e
              ? 'When disabled, this dimension disappears from journal entry and account setup screens; existing data stays in reports.'
              : 'ปิดใช้แล้วช่องมิตินี้จะหายจากหน้าบันทึกบัญชีและการตั้งค่าบัญชี แต่ข้อมูลเดิมยังอยู่ในรายงาน'),
        ]),
      ]),
    );
  }

  Widget _loadingBox() => Padding(
        padding: const EdgeInsets.all(14),
        child: Center(
            child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
      );

  Widget _seg(String a, String b, bool first, ValueChanged<bool> onChanged) => Container(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, label) in [(true, a), (false, b)])
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                color: i == first ? kInk : Colors.white,
                child: Text(label, style: TextStyle(fontSize: 12, color: i == first ? Colors.white : ImKit.ink2, fontWeight: i == first ? FontWeight.w600 : null)),
              ),
            ),
        ]),
      );

  Widget _accountsCard() {
    final e = _isEnglish;
    final s = _summary;
    final rows = (s?.accounts ?? const <GlDimTypeAccountRow>[]).where((a) => a.isRequired == _requiredTab).toList();
    return kCard(
      title: e ? 'Accounts Using This Dimension' : 'บัญชีที่ใช้มิตินี้',
      count: e ? 'Read-only · set on the Chart of Accounts screen' : 'อ่านอย่างเดียว · ตั้งค่าที่หน้าผังบัญชี',
      trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _seg(e ? 'Required ${s?.requiredAccounts ?? 0}' : 'ต้องระบุ ${s?.requiredAccounts ?? 0}',
            e ? 'Optional ${s?.optionalAccounts ?? 0}' : 'ระบุได้ ${s?.optionalAccounts ?? 0}', _requiredTab, (v) => setState(() => _requiredTab = v)),
        kGhost(e ? 'Open Chart of Accounts' : 'เปิดผังบัญชี', Icons.open_in_new,
            () => ImKit.openMenu(context, 'AccountScreen', 'ผังบัญชี', 'Chart of Accounts', e)),
      ]),
      padding: EdgeInsets.zero,
      child: s == null
          ? _loadingBox()
          : kTable([
              KCol(e ? 'Account' : 'บัญชี', 7),
              KCol(e ? 'Type' : 'ประเภท', 3),
              KCol(e ? 'Lines this year' : 'บรรทัดปีนี้', 3, num: true),
              KCol(e ? 'Missing (draft)' : 'ขาดมิติ (Draft)', 3, num: true),
            ], [
              for (final a in rows)
                [
                  kCell('${a.code}  ${a.name(e)}'),
                  kCell(accountTypeLabel(a.accountType, e), color: ImKit.ink2),
                  kCell(_int.format(a.linesYear), mono: true),
                  kCell(_int.format(a.missingDraft), mono: true, color: a.missingDraft > 0 ? ImKit.red : null, bold: a.missingDraft > 0),
                ],
            ], minWidth: 680, empty: _requiredTab ? (e ? 'No account requires this dimension' : 'ยังไม่มีบัญชีที่ต้องระบุมิตินี้') : (e ? 'No account' : 'ไม่มีบัญชี')),
    );
  }

  Widget _valuesCard() {
    final e = _isEnglish;
    final s = _summary;
    final vals = s?.values ?? const <GlDimValueUsageRow>[];
    return kCard(
      title: e ? 'Values in This Dimension' : 'ค่าในมิตินี้',
      count: s == null
          ? null
          : (e
              ? 'Read-only · ${s.valueCount} value(s)${vals.length < s.valueCount ? ' (first ${vals.length})' : ''}'
              : 'อ่านอย่างเดียว · ${s.valueCount} ค่า${vals.length < s.valueCount ? ' (แสดง ${vals.length} แรก)' : ''}'),
      trailing: kGhost(e ? 'Open Dimension Values' : 'ไปหน้าค่ามิติ', Icons.open_in_new,
          () => ImKit.openMenu(context, 'GlDimensionValueScreen', 'ค่ามิติ', 'Dimension Values', e)),
      padding: EdgeInsets.zero,
      child: s == null
          ? _loadingBox()
          : kTable([
              KCol(e ? 'Code' : 'รหัส', 3),
              KCol(e ? 'Name' : 'ชื่อ', 6),
              KCol(e ? 'Parent' : 'ระดับบน', 3),
              KCol(e ? 'Lines this year' : 'บรรทัดปีนี้', 3, num: true),
              KCol(e ? 'Status' : 'สถานะ', 2),
            ], [
              for (final v in vals)
                [
                  kCell(v.code, bold: true),
                  kCell(v.name(e)),
                  kCell(v.parentCode ?? '', color: ImKit.ink2),
                  kCell(_int.format(v.linesYear), mono: true),
                  ImKit.activeChip(v.isActive, e),
                ],
            ], minWidth: 680, empty: e ? 'No value yet' : 'ยังไม่มีค่าในมิตินี้'),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    final t = widget.type;
    final enabled = widget.saved && t.isActive;
    return kPage(
      header: kHeaderBar(
        code: t.typeCode,
        title: _name(e),
        badges: [
          if (widget.editing) kEditingBadge(),
          enabled ? ImKit.chip(e ? 'Enabled' : 'เปิดใช้', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Not enabled' : 'ยังไม่เปิด', ImKit.ro, ImKit.gMore),
          ImKit.chip(e ? 'Slot ${t.slotNo}' : 'ช่อง ${t.slotNo}', ImKit.goldSoft, ImKit.amber),
        ],
        acts: widget.editing
            ? [
                DocBarAction(e ? 'Cancel' : 'ยกเลิก', _saving ? null : widget.onCancel, fg: kInk),
                DocBarAction(_saving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _saving ? null : _save,
                    fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
              ]
            : [
                DocBarAction(e ? 'Open values' : 'ไปหน้าค่ามิติ',
                    () => ImKit.openMenu(context, 'GlDimensionValueScreen', 'ค่ามิติ', 'Dimension Values', e), fg: kInk),
                if (widget.onEdit != null) DocBarAction(e ? 'Edit' : 'แก้ไข', widget.onEdit, fg: Colors.white, bg: kInk, primary: true),
              ],
        busy: _saving,
      ),
      top: kKpis(_kpis(), loading: _loadingSummary),
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        (1, e ? 'Accounts using it' : 'บัญชีที่ใช้มิตินี้', _accountsCard()),
        (2, e ? 'Values' : 'ค่าในมิตินี้', _valuesCard()),
      ],
    );
  }
}
