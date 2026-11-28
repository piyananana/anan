// lib/mo/screens/mo_work_center_screen.dart — ศูนย์ปฏิบัติงาน แบบ B ของ IM (user 2026-11-29)
//   ซ้าย: การ์ดศูนย์งาน (อัตรารวม จำนวนสูตรที่ใช้) + ตัวกรอง / ขวา: โหมดดู → แก้ไข / สำเนา / ลบ ที่แถบหัว
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
import '../models/mo_master_summary.dart';
import '../models/mo_work_center.dart';
import '../services/mo_work_center_service.dart';
import '../widgets/mo_work_center_detail_widget.dart';

class MoWorkCenterScreen extends StatefulWidget {
  final VoidCallback? onFieldsChanged;
  const MoWorkCenterScreen({super.key, this.onFieldsChanged});

  @override
  State<MoWorkCenterScreen> createState() => _MoWorkCenterScreenState();
}

class _MoWorkCenterScreenState extends State<MoWorkCenterScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_WcListState> _listKey = GlobalKey();
  final GlobalKey<MoWorkCenterDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  MoWorkCenter? _selected;
  MoWorkCenter? _copyFrom;
  int _requestSeq = 0;
  bool _isEnglish = false;
  final _svc = MoWorkCenterService();

  @override
  bool get wantKeepAlive => true;

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
      _copyFrom = null;
      _requestSeq++;
    });
  }

  void _onCopy() {
    final src = _selected;
    if (src == null) return;
    setState(() {
      _mode = Mode.add;
      _selected = null;
      _copyFrom = src;
      _requestSeq++;
    });
  }

  void _onEdit() {
    if (_selected == null) return;
    setState(() {
      _mode = Mode.edit;
      _copyFrom = null;
      _requestSeq++;
    });
  }

  Future<void> _onView(MoWorkCenter row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(MoWorkCenter row) => setState(() {
        _mode = Mode.view;
        _selected = row;
        _copyFrom = null;
        _requestSeq++;
      });

  Future<void> _onDelete() async {
    final row = _selected;
    if (row == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final name = e && (row.workCenterNameEn ?? '').isNotEmpty ? row.workCenterNameEn! : row.workCenterNameTh;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Delete work center "${row.workCenterCode} $name"?' : 'ลบศูนย์งาน "${row.workCenterCode} $name" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row.id);
      _listKey.currentState?.refresh();
      _close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(MoWorkCenter row) async {
    final e = _isEnglish;
    final MoWorkCenter saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_mode == Mode.add ? (e ? 'Added ${saved.workCenterCode}' : 'เพิ่มศูนย์งาน ${saved.workCenterCode} สำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
    }
    widget.onFieldsChanged?.call();
    final rows = await _listKey.currentState?.refresh();
    final fresh = rows?.where((r) => r.id == saved.id).firstOrNull ?? saved;
    if (mounted) _show(fresh);
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
        _copyFrom = null;
        _requestSeq++;
      });

  Widget _detail(bool canCreate, bool canEdit, bool canDelete) {
    if (_mode == Mode.none) {
      return MoWorkCenterDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return MoWorkCenterDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selected,
      copyFrom: _mode == Mode.add ? _copyFrom : null,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? _onEdit : null,
      onDelete: view && canDelete ? _onDelete : null,
      onCopy: view && canCreate ? _onCopy : null,
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
      initialListWidth: 320,
      barActions: [
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add work center' : 'เพิ่มศูนย์งาน', Icons.add, _onAdd, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            final rows = await _listKey.currentState?.refresh();
            final cur = _selected;
            if (cur != null && _mode != Mode.add) {
              final fresh = rows?.where((r) => r.id == cur.id).firstOrNull;
              fresh == null ? _close() : _show(fresh);
            } else {
              _close();
            }
          },
        ),
      ],
      list: _WcList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _detail(canCreate, canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการศูนย์งาน (แผงซ้าย)
// ---------------------------------------------------------------------------
class _WcList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<MoWorkCenter> onTap;
  const _WcList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_WcList> createState() => _WcListState();
}

enum _WFlag { noRate, unused, inactive }

class _WcListState extends State<_WcList> {
  final _search = TextEditingController();
  List<MoWorkCenter> _rows = [];
  Map<int, MoWorkCenterUsage> _usage = {};
  _WFlag? _flag;
  bool _loading = false;
  static final _money = NumberFormat('#,##0.00');

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

  Future<List<MoWorkCenter>?> refresh() async {
    setState(() => _loading = true);
    List<MoWorkCenter>? out;
    final svc = MoWorkCenterService();
    try {
      final rows = await svc.fetchRows();
      out = rows;
      if (mounted) setState(() => _rows = rows);
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    try {
      final u = await svc.fetchUsage();
      if (mounted) setState(() => _usage = u);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    return out;
  }

  double _total(MoWorkCenter w) => w.laborRatePerHour + w.machineRatePerHour + w.overheadRatePerHour;

  bool _ok(MoWorkCenter w, _WFlag? f) => switch (f) {
        null => true,
        _WFlag.noRate => _total(w) == 0,
        _WFlag.unused => (_usage[w.id]?.bomCount ?? 0) == 0,
        _WFlag.inactive => !w.isActive,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows
        .where((w) =>
            q.isEmpty ||
            w.workCenterCode.toLowerCase().contains(q) ||
            w.workCenterNameTh.toLowerCase().contains(q) ||
            (w.workCenterNameEn ?? '').toLowerCase().contains(q))
        .toList();
    final shown = base.where((w) => _ok(w, _flag)).toList()..sort((a, b) => a.workCenterCode.compareTo(b.workCenterCode));
    int n(_WFlag f) => base.where((w) => _ok(w, f)).length;
    void flag(_WFlag f) => setState(() => _flag = _flag == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length
                ? (e ? '${_rows.length} work centers' : 'ทั้งหมด ${_rows.length} ศูนย์งาน')
                : (e ? '${shown.length} of ${_rows.length} work centers' : '${shown.length} จาก ${_rows.length} ศูนย์งาน')),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _flag == null, onTap: () => setState(() => _flag = null)),
          ImMasterFilterChip(label: '${e ? 'No rates' : 'ยังไม่ตั้งอัตรา'} ${n(_WFlag.noRate)}', on: _flag == _WFlag.noRate, onTap: () => flag(_WFlag.noRate)),
          ImMasterFilterChip(label: '${e ? 'Not used by a BOM' : 'ไม่มีสูตรใช้'} ${n(_WFlag.unused)}', on: _flag == _WFlag.unused, onTap: () => flag(_WFlag.unused)),
          ImMasterFilterChip(label: '${e ? 'Inactive' : 'หยุดใช้'} ${n(_WFlag.inactive)}', on: _flag == _WFlag.inactive, onTap: () => flag(_WFlag.inactive)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No work centers found' : 'ไม่พบศูนย์งาน', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final w = shown[i];
                      final u = _usage[w.id];
                      final boms = u?.bomCount ?? 0;
                      final total = _total(w);
                      return ImMasterListCard(
                        code: w.workCenterCode,
                        chips: [
                          if (total == 0) ImKit.chip(e ? 'No rates' : 'ยังไม่ตั้งอัตรา', ImKit.goldSoft, ImKit.amber),
                          if (boms == 0) ImKit.chip(e ? 'Unused' : 'ไม่มีสูตรใช้', ImKit.ro, ImKit.ink2),
                          if (!w.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: e && (w.workCenterNameEn ?? '').isNotEmpty ? w.workCenterNameEn! : w.workCenterNameTh,
                        meta: TextSpan(
                            text: [
                          e ? 'total ${_money.format(total)} / h' : 'รวม ${_money.format(total)} / ชม.',
                          if (boms > 0) (e ? 'used in $boms BOM(s)' : 'ใช้ใน $boms สูตร'),
                          if ((u?.openMoCount ?? 0) > 0) (e ? '${u!.openMoCount} open MO(s)' : 'ใบสั่งผลิตค้าง ${u!.openMoCount} ใบ'),
                        ].join(' · ')),
                        selected: widget.selectedId != null && widget.selectedId == w.id,
                        active: w.isActive,
                        onTap: () => widget.onTap(w),
                      );
                    },
                  ),
      ),
    ]);
  }
}
