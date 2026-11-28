// lib/mo/screens/mo_bom_screen.dart — สูตรการผลิต แบบ B ของ IM (user 2026-11-29)
//   ซ้าย: การ์ดเรียงตามสินค้า (เวอร์ชัน วิธีคิดต้นทุน ต้นทุนต่อหน่วยตามสูตร) + ตัวกรอง
//   ขวา: โหมดดู → แก้ไข / สร้างเวอร์ชันใหม่ / ลบ ที่แถบหัว
//   ปุ่มย่อ/ขยายรายการอยู่หน้าชื่อบนแถบหัวแผงขวา (ImListToggle ผ่าน ImMasterShell)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/mo_bom.dart';
import '../models/mo_master_summary.dart';
import '../services/mo_bom_service.dart';
import '../widgets/mo_bom_detail_widget.dart';

class MoBomScreen extends StatefulWidget {
  final VoidCallback? onFieldsChanged;
  const MoBomScreen({super.key, this.onFieldsChanged});

  @override
  State<MoBomScreen> createState() => _MoBomScreenState();
}

class _MoBomScreenState extends State<MoBomScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_BomListState> _listKey = GlobalKey();
  final GlobalKey<MoBomDetailWidgetState> _detailKey = GlobalKey();
  final _svc = MoBomService();

  Mode _mode = Mode.none;
  MoBomHeader? _selected;
  MoBomHeader? _newVersionOf;
  String? _nextVersion;
  bool _fullLoaded = false;
  int _requestSeq = 0;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  List<MoBomHeader> get _allRows => _listKey.currentState?.rows ?? const [];

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onAdd() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _mode = Mode.add;
      _selected = null;
      _newVersionOf = null;
      _requestSeq++;
    });
  }

  // เลขเวอร์ชันถัดไปของสินค้า: เลขที่มากที่สุด + 1 (ถ้าเวอร์ชันไม่ใช่ตัวเลข ต่อท้าย -2, -3, ...)
  String _nextVersionFor(MoBomHeader src) {
    final versions = _allRows.where((b) => b.parentItemId == src.parentItemId).map((b) => b.bomVersion.trim()).toSet();
    final nums = versions.map(int.tryParse).whereType<int>().toList();
    if (nums.isNotEmpty) return '${nums.reduce((a, b) => a > b ? a : b) + 1}';
    var n = 2;
    while (versions.contains('${src.bomVersion}-$n')) {
      n++;
    }
    return '${src.bomVersion}-$n';
  }

  void _onNewVersion() {
    final src = _selected;
    if (src == null) return;
    setState(() {
      _mode = Mode.add;
      _newVersionOf = src;
      _nextVersion = _nextVersionFor(src);
      _selected = null;
      _requestSeq++;
    });
  }

  void _onEdit() {
    if (_selected == null) return;
    setState(() {
      _mode = Mode.edit;
      _newVersionOf = null;
      _requestSeq++;
    });
  }

  Future<void> _onView(MoBomHeader row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(MoBomHeader row) {
    setState(() {
      _mode = Mode.view;
      _selected = row;
      _newVersionOf = null;
      _fullLoaded = false;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  // ข้อมูลเต็มของสูตร (บรรทัดส่วนประกอบ/ขั้นตอน) — ก่อนโหลดเสร็จยังแก้ไข/สร้างเวอร์ชันใหม่ไม่ได้
  Future<void> _fetchFull(MoBomHeader row) async {
    if (row.id == null) return;
    try {
      final full = await _svc.fetchRow(row.id!);
      if (!mounted || _selected?.id != row.id || _mode != Mode.view) return;
      setState(() {
        _selected = full;
        _fullLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _onDelete() async {
    final row = _selected;
    if (row?.id == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final name = e && (row!.parentItemNameEn ?? '').isNotEmpty ? row.parentItemNameEn : row!.parentItemNameTh;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e
            ? 'Delete BOM "${row.parentItemCode} $name" version ${row.bomVersion}?'
            : 'ลบสูตรการผลิต "${row.parentItemCode} $name" เวอร์ชัน ${row.bomVersion} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(MoBomHeader row) async {
    final e = _isEnglish;
    final saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mode == Mode.add ? (e ? 'Added successfully' : 'เพิ่มสำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
    }
    widget.onFieldsChanged?.call();
    await _listKey.currentState?.refresh();
    if (mounted) _show(saved);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _show(_selected!);
    } else {
      _close();
    }
  }

  void _close() => setState(() {
        _mode = Mode.none;
        _selected = null;
        _newVersionOf = null;
        _requestSeq++;
      });

  Widget _detail(bool canCreate, bool canEdit, bool canDelete) {
    if (_mode == Mode.none) {
      return MoBomDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return MoBomDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selected,
      newVersionOf: _mode == Mode.add ? _newVersionOf : null,
      nextVersion: _nextVersion,
      allRows: _allRows,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? (_fullLoaded ? _onEdit : null) : null,
      onDelete: view && canDelete ? _onDelete : null,
      onNewVersion: view && canCreate ? (_fullLoaded ? _onNewVersion : null) : null,
      requestSeq: _requestSeq,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 340,
      barActions: [
        ImKit.barButton(context, isEnglish ? 'BOM cost report' : 'รายงานต้นทุนสูตร', Icons.summarize_outlined,
            () => ImKit.openMenu(context, 'MoBomCostReportScreen', 'รายงานต้นทุนสูตรการผลิตที่ใช้', 'BOM Cost Report', isEnglish)),
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add BOM' : 'เพิ่มสูตร', Icons.add, _onAdd, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _listKey.currentState?.refresh();
            if (_selected != null && _mode != Mode.add) {
              _show(_selected!);
            } else {
              _close();
            }
          },
        ),
      ],
      list: _BomList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _detail(canCreate, canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการสูตร (แผงซ้าย)
// ---------------------------------------------------------------------------
class _BomList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<MoBomHeader> onTap;
  const _BomList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_BomList> createState() => _BomListState();
}

enum _BFlag { routing, sub, coProduct, stdMissing }

class _BomListState extends State<_BomList> {
  final _search = TextEditingController();
  List<MoBomHeader> rows = [];
  Map<int, MoBomCost> _costs = {};
  bool _allVersions = false;
  _BFlag? _flag;
  bool _loading = false;
  static final _money = NumberFormat('#,##0.00##');

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final svc = MoBomService();
    try {
      final r = await svc.fetchRows();
      if (mounted) setState(() => rows = r);
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    if (mounted) setState(() => _loading = false);
    try {
      final c = await svc.fetchCosts();
      if (mounted) setState(() => _costs = c);
    } catch (_) {}
  }

  bool _stdMissing(MoBomHeader b) => b.costingMethod == 'STANDARD' && ((_costs[b.id]?.standardCost ?? 0) <= 0) && _costs[b.id] != null;

  bool _ok(MoBomHeader b, _BFlag? f) => switch (f) {
        null => true,
        _BFlag.routing => b.costingMode == 'ROUTING',
        _BFlag.sub => _costs[b.id]?.hasSub ?? false,
        _BFlag.coProduct => b.outputCount > 0,
        _BFlag.stdMissing => _stdMissing(b),
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final searched = rows
        .where((b) =>
            q.isEmpty ||
            (b.parentItemCode ?? '').toLowerCase().contains(q) ||
            (b.parentItemNameTh ?? '').toLowerCase().contains(q) ||
            (b.parentItemNameEn ?? '').toLowerCase().contains(q))
        .toList();
    final base = _allVersions ? searched : searched.where((b) => b.isActive).toList();
    final shown = base.where((b) => _ok(b, _flag)).toList()
      ..sort((a, b) {
        final x = (a.parentItemCode ?? '').compareTo(b.parentItemCode ?? '');
        if (x != 0) return x;
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.bomVersion.compareTo(a.bomVersion);
      });
    int n(_BFlag f) => base.where((b) => _ok(b, f)).length;
    void flag(_BFlag f) => setState(() => _flag = _flag == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search item code / name' : 'ค้นหา รหัส / ชื่อสินค้าที่ผลิต',
        onSearch: (_) => setState(() {}),
        countText: _loading ? (e ? 'Loading...' : 'กำลังโหลด...') : (e ? '${shown.length} BOM(s)' : 'สูตร ${shown.length} สูตร'),
        filters: [
          ImMasterFilterChip(
              label: '${e ? 'Active' : 'ใช้งาน'} ${searched.where((b) => b.isActive).length}',
              on: !_allVersions,
              onTap: () => setState(() => _allVersions = false)),
          ImMasterFilterChip(label: '${e ? 'All versions' : 'ทุกเวอร์ชัน'} ${searched.length}', on: _allVersions, onTap: () => setState(() => _allVersions = true)),
          ImMasterFilterChip(label: '${e ? 'Routing' : 'ตามขั้นตอนผลิต'} ${n(_BFlag.routing)}', on: _flag == _BFlag.routing, onTap: () => flag(_BFlag.routing)),
          ImMasterFilterChip(label: '${e ? 'Has sub BOM' : 'มีสูตรย่อย'} ${n(_BFlag.sub)}', on: _flag == _BFlag.sub, onTap: () => flag(_BFlag.sub)),
          ImMasterFilterChip(label: '${e ? 'Co-products' : 'มีผลิตภัณฑ์ร่วม'} ${n(_BFlag.coProduct)}', on: _flag == _BFlag.coProduct, onTap: () => flag(_BFlag.coProduct)),
          ImMasterFilterChip(
              label: '${e ? 'No standard cost' : 'ต้นทุนมาตรฐานยังไม่ตั้ง'} ${n(_BFlag.stdMissing)}', on: _flag == _BFlag.stdMissing, onTap: () => flag(_BFlag.stdMissing)),
        ],
      ),
      Expanded(
        child: _loading && rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No BOMs found' : 'ไม่พบสูตรการผลิต', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final b = shown[i];
                      final c = _costs[b.id];
                      final uom = e && (b.outputUomNameEn ?? '').isNotEmpty ? b.outputUomNameEn : (b.outputUomNameTh ?? b.outputUomCode ?? '');
                      return ImMasterListCard(
                        code: '${b.parentItemCode ?? ''} · v${b.bomVersion}',
                        chips: [
                          b.isActive ? ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Inactive' : 'ไม่ใช้งาน', ImKit.ro, ImKit.ink2),
                          if (b.costingMode == 'ROUTING')
                            ImKit.chip(e ? 'Routing' : 'ขั้นตอนผลิต', ImKit.blueSoft, ImKit.blue)
                          else
                            ImKit.chip('Overhead ${NumberFormat('0.##').format(b.overheadPercent)}%', ImKit.ro, ImKit.ink2),
                          if (_stdMissing(b)) ImKit.chip(e ? 'No std cost' : 'ต้นทุนมาตรฐานยังไม่ตั้ง', ImKit.goldSoft, ImKit.amber),
                        ],
                        name: e && (b.parentItemNameEn ?? '').isNotEmpty ? b.parentItemNameEn! : (b.parentItemNameTh ?? ''),
                        meta: TextSpan(
                            text: [
                          e ? '${b.componentCount} component(s)' : '${b.componentCount} ส่วนประกอบ',
                          if (c?.unitCost != null) (e ? 'cost ${_money.format(c!.unitCost)} / $uom' : 'ต้นทุน ${_money.format(c!.unitCost)} / $uom'),
                          if (c?.error != null) (e ? 'cannot cost' : 'คิดต้นทุนไม่ได้'),
                          if ((c?.usedInCount ?? 0) > 0) (e ? 'used in ${c!.usedInCount} BOM(s)' : 'ใช้ใน ${c!.usedInCount} สูตร'),
                        ].join(' · ')),
                        selected: widget.selectedId != null && widget.selectedId == b.id,
                        active: b.isActive,
                        onTap: () => widget.onTap(b),
                      );
                    },
                  ),
      ),
    ]);
  }
}
