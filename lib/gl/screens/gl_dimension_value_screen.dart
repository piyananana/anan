// lib/gl/screens/gl_dimension_value_screen.dart
// หน้าจอค่ามิติ แบบ IM design B (user 2026-11-28; ไม่ทำนำเข้า Excel — ข้อ 9):
//   ซ้าย = เลือกประเภทมิติ + ต้นไม้ค่า (ระดับบน-ล่าง, จำนวนบรรทัด Posted ปีนี้รวมค่าย่อย, ＋ เพิ่มค่าย่อย,
//          ลากไปวางบนค่าอื่นเพื่อย้ายระดับ, กรอง ไม่เคยใช้ / หยุดใช้)
//   ขวา = รายละเอียดค่า (เปิดมาเป็นโหมดดู) + ตัวเลขสรุป (บรรทัด/รายได้/ค่าใช้จ่ายปีนี้, ใช้ล่าสุด — รวมค่าย่อย)
//         + ยอดตามบัญชี 10 อันดับ + ค่าย่อย
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../im/widgets/im_master_tree.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';

String _dimTypeName(GlDimensionType t, bool e) => e && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;
String _dimValueName(GlDimensionValue v, bool e) => e && (v.valueNameEng ?? '').isNotEmpty ? v.valueNameEng! : v.valueNameThai;

class GlDimensionValueScreen extends StatefulWidget {
  const GlDimensionValueScreen({super.key});

  @override
  State<GlDimensionValueScreen> createState() => _GlDimensionValueScreenState();
}

class _GlDimensionValueScreenState extends State<GlDimensionValueScreen> with AutomaticKeepAliveClientMixin {
  final _svc = GlDimensionService();
  final GlobalKey<_DimValueDetailState> _detailKey = GlobalKey();
  final _searchCtrl = TextEditingController();

  List<GlDimensionType> _types = [];
  GlDimensionType? _type;
  List<GlDimensionValue> _values = [];
  Map<int, GlDimValueLineCount> _lines = {};
  bool _loading = false;
  String _query = '';
  String? _filter; // unused | inactive

  Mode _mode = Mode.none;
  GlDimensionValue? _selected; // addChild = ค่าระดับบน
  int _requestSeq = 0;

  static final _int = NumberFormat('#,##0');

  @override
  bool get wantKeepAlive => true;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await _svc.fetchAllTypes();
      if (!mounted) return;
      types.sort((a, b) => a.slotNo.compareTo(b.slotNo));
      setState(() {
        _types = types;
        _type ??= types.where((t) => t.isActive).firstOrNull ?? types.firstOrNull;
      });
      await _loadValues();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _loadValues() async {
    final t = _type;
    if (t == null) return;
    setState(() => _loading = true);
    try {
      final vals = await _svc.fetchValuesByType(t.typeCode, includeInactive: true);
      Map<int, GlDimValueLineCount> lines = {};
      try {
        lines = await _svc.fetchValueUsage(t.typeCode);
      } catch (_) {}
      if (mounted && _type?.typeCode == t.typeCode) {
        setState(() {
          _values = vals;
          _lines = lines;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<int?, List<GlDimensionValue>> get _kids {
    final m = <int?, List<GlDimensionValue>>{};
    for (final v in _values) {
      m.putIfAbsent(v.parentId, () => []).add(v);
    }
    return m;
  }

  /// บรรทัดปีนี้ / ทั้งหมด รวมค่าย่อยทุกระดับ
  Map<int, (int, int)> _subtreeLines() {
    final kids = _kids;
    final memo = <int, (int, int)>{};
    (int, int) total(GlDimensionValue v) => memo[v.id] ??= (kids[v.id] ?? const <GlDimensionValue>[]).fold(
        (_lines[v.id]?.linesYear ?? 0, _lines[v.id]?.linesAll ?? 0), (s, k) {
      final t = total(k);
      return (s.$1 + t.$1, s.$2 + t.$2);
    });
    for (final v in _values) {
      total(v);
    }
    return memo;
  }

  String _pathOf(GlDimensionValue? v) {
    if (v == null) return '';
    final byId = {for (final x in _values) x.id: x};
    final parts = <String>[];
    var p = v.parentId;
    while (p != null && byId.containsKey(p)) {
      final x = byId[p]!;
      parts.insert(0, '${x.valueCode} ${_dimValueName(x, _isEnglish)}');
      p = x.parentId;
    }
    return parts.join(' › ');
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  void _set(Mode m, GlDimensionValue? v) => setState(() {
        _mode = m;
        _selected = v;
        _requestSeq++;
      });

  Future<void> _changeType(String? code) async {
    final t = _types.where((x) => x.typeCode == code).firstOrNull;
    if (t == null || t.typeCode == _type?.typeCode) return;
    if (!await _confirmLeave()) return;
    setState(() {
      _type = t;
      _values = [];
      _lines = {};
    });
    _set(Mode.none, null);
    await _loadValues();
  }

  Future<void> _onView(GlDimensionValue v) async {
    if (_mode == Mode.view && _selected?.id == v.id) return;
    if (await _confirmLeave()) _set(Mode.view, v);
  }

  Future<void> _onAddRoot() async {
    if (await _confirmLeave()) _set(Mode.addRoot, null);
  }

  Future<void> _onAddChild(GlDimensionValue parent) async {
    if (await _confirmLeave()) _set(Mode.addChild, parent);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if ((_mode == Mode.edit || _mode == Mode.addChild) && _selected != null) {
      _set(Mode.view, _selected);
    } else {
      _set(Mode.none, null);
    }
  }

  Future<void> _onDelete() async {
    final v = _selected;
    if (v == null) return;
    final e = _isEnglish;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(e
            ? 'Delete "${v.valueCode} ${_dimValueName(v, e)}"?\n\nIt cannot be deleted if GL transactions use it.'
            : 'ลบ "${v.valueCode} ${_dimValueName(v, e)}" ?\n\nไม่สามารถลบได้หากมีการใช้งานในธุรกรรม GL'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(e ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteValue(v.id);
      await _loadValues();
      _set(Mode.none, null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted "${v.valueCode}"' : 'ลบ "${v.valueCode}" เรียบร้อย')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(GlDimensionValue row) async {
    final e = _isEnglish;
    final adding = _mode == Mode.addRoot || _mode == Mode.addChild;
    try {
      final saved = adding ? await _svc.addValue(row) : await _svc.updateValue(row.id, row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(adding ? (e ? 'Added "${row.valueCode}"' : 'เพิ่ม "${row.valueCode}" เรียบร้อย') : (e ? 'Saved "${row.valueCode}"' : 'บันทึก "${row.valueCode}" เรียบร้อย'))));
      }
      await _loadValues();
      final fresh = _values.where((v) => v.id == saved.id).firstOrNull ?? saved;
      if (mounted) _set(Mode.view, fresh);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onMove(ImTreeNode node, ImTreeNode? parent) async {
    final e = _isEnglish;
    if (!await _confirmLeave()) return;
    try {
      await _svc.moveValue(node.id, parent?.id);
      await _loadValues();
      final fresh = _values.where((v) => v.id == node.id).firstOrNull;
      if (fresh != null) _set(Mode.view, fresh);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Moved' : 'ย้ายแล้ว')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Widget _list(bool e, bool canCreate, bool canEdit) {
    final kids = _kids;
    final sub = _subtreeLines();
    final byId = {for (final v in _values) v.id: v};
    final unused = _values.where((v) => (sub[v.id]?.$2 ?? 0) == 0).length;
    final inactive = _values.where((v) => !v.isActive).length;
    final nodes = [
      for (final v in _values)
        ImTreeNode(
          id: v.id,
          parentId: v.parentId,
          code: v.valueCode,
          name: _dimValueName(v, e),
          kind: (kids[v.id] ?? const []).isNotEmpty ? 'G' : 'V',
          kindBg: (kids[v.id] ?? const []).isNotEmpty ? ImKit.blueSoft : ImKit.okSoft,
          kindFg: (kids[v.id] ?? const []).isNotEmpty ? ImKit.blue : ImKit.ok,
          count: _int.format(sub[v.id]?.$1 ?? 0),
          active: v.isActive,
          order: v.sortOrder,
          search: v.valueNameEng,
        ),
    ];
    void toggle(String f) => setState(() => _filter = _filter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: DropdownButtonFormField<String>(
          value: _type?.typeCode,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            labelText: e ? 'Dimension' : 'มิติ',
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, color: Colors.black87),
          items: [
            for (final t in _types)
              DropdownMenuItem(
                value: t.typeCode,
                child: Text('${t.typeCode}  ${_dimTypeName(t, e)}${t.isActive ? '' : (e ? ' (disabled)' : ' (ปิดใช้)')}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _changeType,
        ),
      ),
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
        onSearch: (v) => setState(() => _query = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All ${_values.length}' : 'ทั้งหมด ${_values.length}', on: _filter == null, onTap: () => setState(() => _filter = null)),
          ImMasterFilterChip(label: e ? 'Never used $unused' : 'ไม่เคยใช้ $unused', on: _filter == 'unused', onTap: () => toggle('unused')),
          ImMasterFilterChip(label: e ? 'Inactive $inactive' : 'หยุดใช้ $inactive', on: _filter == 'inactive', onTap: () => toggle('inactive')),
        ],
        countText: e ? 'Number = posted lines this year incl. sub-values' : 'ตัวเลข = บรรทัด Posted ปีนี้ รวมค่าย่อย',
      ),
      Expanded(
        child: _loading && _values.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _types.isEmpty
                ? Center(child: Text(e ? 'Set up dimension types first' : 'ยังไม่มีประเภทมิติ กรุณาตั้งค่าที่หน้าประเภทมิติก่อน', style: const TextStyle(color: ImKit.ink2)))
                : ImMasterTree(
                    nodes: nodes,
                    selectedId: _mode == Mode.view || _mode == Mode.edit || _mode == Mode.addChild ? _selected?.id : null,
                    query: _query,
                    filter: _filter == null
                        ? null
                        : (n) {
                            final v = byId[n.id];
                            if (v == null) return false;
                            return _filter == 'unused' ? (sub[v.id]?.$2 ?? 0) == 0 : !v.isActive;
                          },
                    onTap: (n) {
                      final v = byId[n.id];
                      if (v != null) _onView(v);
                    },
                    onAddChild: canCreate
                        ? (n) {
                            final v = byId[n.id];
                            if (v != null) _onAddChild(v);
                          }
                        : null,
                    onMove: canEdit ? _onMove : null,
                    isEnglish: e,
                    emptyText: e ? 'No value yet' : 'ยังไม่มีค่าในมิตินี้',
                    legend: [
                      ('G', e ? 'Has sub-values' : 'มีค่าย่อย', ImKit.blueSoft, ImKit.blue),
                      ('V', e ? 'Value' : 'ค่า', ImKit.okSoft, ImKit.ok),
                    ],
                  ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final e = context.watch<LanguageProvider>().isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final view = _mode == Mode.view;
    final sel = _selected;
    final hasKids = sel != null && _values.any((v) => v.parentId == sel.id);
    final used = sel != null && (_subtreeLines()[sel.id]?.$2 ?? 0) > 0;
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 320,
      barActions: [
        if (canCreate && _type != null) ImKit.barButton(context, e ? 'Add top value' : 'เพิ่มค่าหลัก', Icons.add, _onAddRoot, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _loadValues();
            final fresh = _selected == null ? null : _values.where((v) => v.id == _selected!.id).firstOrNull;
            _set(fresh != null && (_mode == Mode.view || _mode == Mode.edit) ? Mode.view : Mode.none, fresh);
          },
        ),
      ],
      list: _list(e, canCreate, canEdit),
      detail: _type == null || _mode == Mode.none
          ? ImListToggle.placeholder(context, Icons.label_outline, e ? 'Select a value on the left to view its data' : 'เลือกค่ามิติทางซ้ายเพื่อดูข้อมูล')
          : _DimValueDetail(
              key: _detailKey,
              type: _type!,
              mode: _mode,
              selected: _selected,
              allValues: _values,
              parentPath: _pathOf(_mode == Mode.addChild ? null : _selected),
              requestSeq: _requestSeq,
              codeLocked: used,
              onSubmit: _onSubmit,
              onCancel: view ? () => _set(Mode.none, null) : _onCancel,
              onEdit: view && canEdit ? () => _set(Mode.edit, _selected) : null,
              onDelete: view && canDelete && !hasKids && !used ? _onDelete : null,
              onAddChild: view && canCreate && sel != null ? () => _onAddChild(sel) : null,
              onOpenChild: (id) {
                final v = _values.where((x) => x.id == id).firstOrNull;
                if (v != null) _onView(v);
              },
            ),
    );
  }
}

class _DimValueDetail extends StatefulWidget {
  final GlDimensionType type;
  final Mode mode;
  final GlDimensionValue? selected;
  final List<GlDimensionValue> allValues;
  final String parentPath;
  final int requestSeq;
  final bool codeLocked;
  final Future<void> Function(GlDimensionValue) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddChild;
  final ValueChanged<int> onOpenChild;
  const _DimValueDetail({super.key, required this.type, required this.mode, this.selected, required this.allValues, required this.parentPath,
      required this.requestSeq, required this.codeLocked, required this.onSubmit, required this.onCancel, this.onEdit, this.onDelete,
      this.onAddChild, required this.onOpenChild});

  @override
  State<_DimValueDetail> createState() => _DimValueDetailState();
}

class _DimValueDetailState extends State<_DimValueDetail> with ImMasterKit {
  final _svc = GlDimensionService();
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();
  int? _parentId;
  bool _active = true;
  bool _saving = false;
  bool _isEnglish = false;
  GlDimValueSummary? _summary;
  bool _loadingSummary = false;
  int _seq = 0;
  String _snapshot = '';

  static final _int = NumberFormat('#,##0');
  static final _amt = NumberFormat('#,##0.00');

  bool get _isNew => widget.mode == Mode.addRoot || widget.mode == Mode.addChild;
  bool get _readOnly => widget.mode == Mode.view || widget.mode == Mode.none;
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => _readOnly;

  bool get isDirty => !_readOnly && _fp() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant _DimValueDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected || oldWidget.mode != widget.mode || oldWidget.requestSeq != widget.requestSeq) _apply();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameThCtrl, _nameEnCtrl, _sortCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final v = _isNew ? null : widget.selected;
    _codeCtrl.text = v?.valueCode ?? '';
    _nameThCtrl.text = v?.valueNameThai ?? '';
    _nameEnCtrl.text = v?.valueNameEng ?? '';
    _sortCtrl.text = '${v?.sortOrder ?? 0}';
    _parentId = widget.mode == Mode.addChild ? widget.selected?.id : (widget.mode == Mode.addRoot ? null : v?.parentId);
    _active = v?.isActive ?? true;
    _summary = null;
    if (!_isNew && widget.selected != null) _loadSummary(widget.selected!.id);
    kScrollTop();
    _snapshot = _fp();
  }

  Future<void> _loadSummary(int id) async {
    final seq = ++_seq;
    _loadingSummary = true;
    try {
      final s = await _svc.fetchValueSummary(id);
      if (mounted && seq == _seq) setState(() => _summary = s);
    } catch (_) {
    } finally {
      if (mounted && seq == _seq) setState(() => _loadingSummary = false);
    }
  }

  GlDimensionValue _build() => GlDimensionValue(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        typeCode: widget.type.typeCode,
        valueCode: _codeCtrl.text.trim().toUpperCase(),
        valueNameThai: _nameThCtrl.text.trim(),
        valueNameEng: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        parentId: _parentId,
        isActive: _active,
        sortOrder: int.tryParse(_sortCtrl.text) ?? 0,
      );

  String _fp() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter a code' : 'กรุณาระบุรหัส';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter a name' : 'กรุณาระบุชื่อ';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_build());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ระดับบนที่เลือกได้ = ทุกค่า ยกเว้นตัวเองและลูกหลาน
  List<GlDimensionValue> get _parentOptions {
    final self = widget.mode == Mode.edit ? widget.selected?.id : null;
    if (self == null) return widget.allValues;
    final blocked = <int>{self};
    var grew = true;
    while (grew) {
      grew = false;
      for (final v in widget.allValues) {
        if (v.parentId != null && blocked.contains(v.parentId) && blocked.add(v.id)) grew = true;
      }
    }
    return widget.allValues.where((v) => !blocked.contains(v.id)).toList();
  }

  String _date(String? ymd) {
    if (ymd == null || ymd.length < 10) return '-';
    final p = ymd.substring(0, 10).split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    final fy = s.fyCode ?? '-';
    return [
      ImKpi(e ? 'Lines this year' : 'บรรทัดบัญชีปีนี้', _int.format(s.linesYear), e ? 'posted, all modules · FY $fy' : 'Posted ทุกโมดูล · ปีบัญชี $fy'),
      ImKpi(e ? 'Revenue this year' : 'รายได้ปีนี้', _amt.format(s.revenue), e ? 'revenue accounts' : 'บัญชีประเภทรายได้'),
      ImKpi(e ? 'Expenses this year' : 'ค่าใช้จ่ายปีนี้', _amt.format(s.expense), e ? 'expense accounts' : 'บัญชีประเภทค่าใช้จ่าย'),
      ImKpi(e ? 'Last used' : 'ใช้ล่าสุด', _date(s.lastDate), s.lastDocNo ?? (e ? 'Not used yet' : 'ยังไม่เคยใช้')),
    ];
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_readOnly;
    final parents = _parentOptions;
    return kCard(
      title: e ? 'Dimension Value' : 'ข้อมูลค่ามิติ',
      trailing: ed ? kLegend() : null,
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Code *' : 'รหัส *', _codeCtrl, editable: ed && (_isNew || !widget.codeLocked), cap: TextCapitalization.characters),
            InputDecorator(
              decoration: kDec(e ? 'Dimension' : 'ประเภทมิติ', editable: false),
              child: Text('${widget.type.typeCode} ${_dimTypeName(widget.type, e)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: ImKit.font)),
            ),
          ]),
          kRow([
            kTxt(e ? 'Thai Name *' : 'ชื่อ (ไทย) *', _nameThCtrl),
            kTxt(e ? 'English Name' : 'ชื่อ (อังกฤษ)', _nameEnCtrl),
          ]),
          if (ed && widget.codeLocked && !_isNew)
            kNote(e ? 'The code is locked because posted lines use this value.' : 'รหัสแก้ไม่ได้ เพราะมีรายการบัญชีใช้ค่านี้แล้ว'),
        ]),
        kGroup(2, e ? 'Structure' : 'โครงสร้าง', ImKit.gParty, [
          kDd<int?>(
            e ? 'Parent' : 'ระดับบน',
            parents.any((p) => p.id == _parentId) ? _parentId : null,
            [
              DropdownMenuItem<int?>(value: null, child: Text(e ? '— None (top level) —' : '— ไม่มี (ระดับบนสุด) —')),
              for (final p in parents)
                DropdownMenuItem<int?>(value: p.id, child: Text('${p.valueCode}  ${_dimValueName(p, e)}', overflow: TextOverflow.ellipsis)),
            ],
            ed ? (v) => setState(() => _parentId = v) : null,
          ),
          kRow([
            kTxt(e ? 'Display order' : 'ลำดับแสดงผล', _sortCtrl, numeric: true, digitsOnly: true),
            Align(
              alignment: Alignment.centerLeft,
              child: kChecks([kCk(e ? 'Active' : 'ใช้งาน', _active, ed ? (v) => setState(() => _active = v) : null)]),
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _loadingBox() => Padding(
        padding: const EdgeInsets.all(14),
        child: Center(
            child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
      );

  Widget _byAccountCard() {
    final e = _isEnglish;
    final s = _summary;
    final rows = s?.byAccount ?? const <GlDimValueAccountRow>[];
    String net(double v) => v < 0 ? '(${_amt.format(-v)})' : _amt.format(v);
    return kCard(
      title: e ? 'Balance by Account' : 'ยอดตามบัญชี',
      count: e ? 'Read-only · fiscal year ${s?.fyCode ?? '-'} · top 10 by amount' : 'อ่านอย่างเดียว · ปีบัญชี ${s?.fyCode ?? '-'} · 10 บัญชีแรกตามยอด',
      trailing: kGhost(e ? 'Open Trial Balance' : 'เปิดงบทดลอง', Icons.open_in_new,
          () => ImKit.openMenu(context, 'TrialBalanceReportScreen', 'งบทดลอง', 'Trial Balance', e)),
      padding: EdgeInsets.zero,
      child: s == null
          ? _loadingBox()
          : kTable([
              KCol(e ? 'Account' : 'บัญชี', 7),
              KCol(e ? 'Debit' : 'เดบิต', 3, num: true),
              KCol(e ? 'Credit' : 'เครดิต', 3, num: true),
              KCol(e ? 'Net' : 'สุทธิ', 3, num: true),
            ], [
              for (final a in rows)
                [
                  kCell('${a.code}  ${a.name(e)}'),
                  kCell(_amt.format(a.debit), mono: true),
                  kCell(_amt.format(a.credit), mono: true),
                  kCell(net(a.debit - a.credit), mono: true, bold: true),
                ],
            ], minWidth: 680, empty: e ? 'No posted line uses this value this year' : 'ปีนี้ยังไม่มีรายการบัญชีที่ใช้ค่านี้'),
    );
  }

  Widget _childrenCard() {
    final e = _isEnglish;
    final s = _summary;
    final kids = s?.children ?? const <GlDimValueUsageRow>[];
    return kCard(
      title: e ? 'Sub-values' : 'ค่าย่อย',
      count: e ? '${kids.length} direct sub-value(s) · KPIs above include them' : '${kids.length} ค่าระดับถัดไป · ตัวเลขสรุปด้านบนรวมยอดค่าย่อยแล้ว',
      trailing: widget.onAddChild == null ? null : kGhost(e ? 'Add sub-value' : 'เพิ่มค่าย่อย', Icons.add, widget.onAddChild),
      padding: EdgeInsets.zero,
      child: s == null
          ? _loadingBox()
          : kTable([
              KCol(e ? 'Code' : 'รหัส', 3),
              KCol(e ? 'Name' : 'ชื่อ', 6),
              KCol(e ? 'Lines this year' : 'บรรทัดปีนี้', 3, num: true),
              KCol(e ? 'Status' : 'สถานะ', 2),
            ], [
              for (final k in kids)
                [kCell(k.code, bold: true), kCell(k.name(e)), kCell(_int.format(k.linesYear), mono: true), ImKit.activeChip(k.isActive, e)],
            ], onTap: [for (final k in kids) () => widget.onOpenChild(k.id)], minWidth: 600, empty: e ? 'No sub-value' : 'ยังไม่มีค่าย่อย'),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    final saved = !_isNew && widget.selected != null;
    final v = widget.selected;
    final typeName = _dimTypeName(widget.type, e);
    final title = saved
        ? _dimValueName(v!, e)
        : widget.mode == Mode.addChild
            ? (e ? 'Add $typeName under ${v?.valueCode ?? ''}' : 'เพิ่ม$typeNameใต้ ${v?.valueCode ?? ''}')
            : (e ? 'Add $typeName' : 'เพิ่ม$typeName');
    return kPage(
      header: kHeaderBar(
        code: saved ? v!.valueCode : null,
        title: title,
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved) ImKit.activeChip(v!.isActive, e),
          ImKit.chip(typeName, ImKit.goldSoft, ImKit.amber),
          if (saved && widget.parentPath.isNotEmpty) Text(widget.parentPath, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
        acts: kStdActs(
          saving: _saving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _save,
          extra: [if (widget.onAddChild != null) DocBarAction(e ? '+ Sub-value' : '+ ค่าย่อย', widget.onAddChild, fg: kInk)],
        ),
        busy: _saving,
      ),
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'By account' : 'ยอดตามบัญชี', _byAccountCard()),
        if (saved) (2, e ? 'Sub-values' : 'ค่าย่อย', _childrenCard()),
      ],
    );
  }
}
