// lib/ar/screens/ar_collector_screen.dart — ผู้วางบิล/ผู้เก็บเงิน แบบ B ของ IM (user 2026-11-28)
//   ซ้าย: การ์ด + ป้ายวันที่มีผล (มีผล/หมดอายุ/ยังไม่เริ่ม) + ตัวกรองชนิด / ขวา: เปิดเป็นโหมดดู → แก้ไข / ลบ ที่แถบหัว
//   ปุ่มย่อ/ขยายรายการอยู่หน้าชื่อบนแถบหัวแผงขวา (ImListToggle ผ่าน ImMasterShell)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/ar_collector.dart';
import '../services/ar_collector_service.dart';
import '../widgets/ar_collector_detail_widget.dart';

class ArCollectorScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ArCollectorScreen({super.key, required this.onFieldsChanged, this.onExit});

  @override
  State<ArCollectorScreen> createState() => _ArCollectorScreenState();
}

class _ArCollectorScreenState extends State<ArCollectorScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_CollectorListState> _listKey = GlobalKey();
  final GlobalKey<ArCollectorDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  ArCollector? _selected;
  int _requestSeq = 0;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  ArCollectorService get _svc => Provider.of<ArCollectorService>(context, listen: false);

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
      _requestSeq++;
    });
  }

  void _onEdit() {
    if (_selected == null) return;
    setState(() {
      _mode = Mode.edit;
      _requestSeq++;
    });
  }

  Future<void> _onView(ArCollector row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(ArCollector row) => setState(() {
        _mode = Mode.view;
        _selected = row;
        _requestSeq++;
      });

  Future<void> _onDelete() async {
    final row = _selected;
    if (row?.id == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final name = e && (row!.collectorNameEng?.isNotEmpty ?? false) ? row.collectorNameEng! : row!.collectorNameThai;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Are you sure you want to delete "${row.collectorCode} $name" ?' : 'คุณแน่ใจหรือไม่ที่จะลบ "${row.collectorCode} $name" ?'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e ? 'Error deleting: $ex' : 'เกิดข้อผิดพลาดในการลบ: $ex'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(ArCollector row) async {
    final e = _isEnglish;
    try {
      final ArCollector saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_mode == Mode.add ? (e ? 'Added ${saved.collectorCode}' : 'เพิ่ม ${saved.collectorCode} สำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
      }
      _listKey.currentState?.refresh();
      widget.onFieldsChanged();
      if (mounted) _show(saved);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e ? 'Error saving: $ex' : 'เกิดข้อผิดพลาดในการบันทึก: $ex'), backgroundColor: Colors.red));
      }
    }
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
        _requestSeq++;
      });

  Widget _detail(bool canEdit, bool canDelete) {
    if (_mode == Mode.none) {
      return ArCollectorDetailWidget(
          key: _detailKey, mode: Mode.none, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return ArCollectorDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selected,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? _onEdit : null,
      onDelete: view && canDelete ? _onDelete : null,
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
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add' : 'เพิ่มผู้วางบิล/ผู้เก็บเงิน', Icons.add, _onAdd, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            _listKey.currentState?.refresh();
            if (_selected != null && _mode != Mode.add) {
              _show(_selected!);
            } else {
              _close();
            }
          },
        ),
      ],
      list: _CollectorList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _detail(canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการผู้วางบิล/ผู้เก็บเงิน (แผงซ้าย)
// ---------------------------------------------------------------------------
class _CollectorList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<ArCollector> onTap;
  const _CollectorList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_CollectorList> createState() => _CollectorListState();
}

class _CollectorListState extends State<_CollectorList> {
  final _search = TextEditingController();
  List<ArCollector> _rows = [];
  String? _type;
  String? _state; // active / expired / future / inactive
  bool _loading = false;

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
    try {
      final rows = await Provider.of<ArCollectorService>(context, listen: false).fetchRows();
      if (mounted) setState(() => _rows = rows);
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _stateOk(ArCollector c, String? s) => switch (s) {
        null => true,
        'inactive' => !c.isActive,
        _ => c.isActive && c.effectiveState() == s,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows
        .where((c) =>
            (q.isEmpty ||
                c.collectorCode.toLowerCase().contains(q) ||
                c.collectorNameThai.toLowerCase().contains(q) ||
                (c.collectorNameEng?.toLowerCase().contains(q) ?? false) ||
                (c.phone?.toLowerCase().contains(q) ?? false)) &&
            (_type == null || c.collectorType == _type))
        .toList();
    final shown = base.where((c) => _stateOk(c, _state)).toList()..sort((a, b) => a.collectorCode.compareTo(b.collectorCode));
    int n(String s) => base.where((c) => _stateOk(c, s)).length;
    void st(String s) => setState(() => _state = _state == s ? null : s);
    final types = e ? arCollectorTypeOptionsEng : arCollectorTypeOptions;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name / phone' : 'ค้นหา รหัส / ชื่อ / โทรศัพท์',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length ? (e ? '${_rows.length} people' : 'ทั้งหมด ${_rows.length} ราย') : (e ? '${shown.length} of ${_rows.length}' : '${shown.length} จาก ${_rows.length} ราย')),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _state == null && _type == null, onTap: () => setState(() {
                _state = null;
                _type = null;
              })),
          ImMasterPopupFilter(
            label: e ? 'Type' : 'ชนิด',
            value: _type,
            valueLabel: _type == null ? null : types[_type],
            allLabel: e ? 'All types' : 'ทุกชนิด',
            options: [for (final t in types.entries) (t.key, t.value)],
            onChanged: (v) => setState(() => _type = v),
          ),
          ImMasterFilterChip(label: '${e ? 'In effect' : 'มีผล'} ${n('active')}', on: _state == 'active', onTap: () => st('active')),
          ImMasterFilterChip(label: '${e ? 'Expired' : 'หมดอายุ'} ${n('expired')}', on: _state == 'expired', onTap: () => st('expired'), fg: ImKit.red),
          ImMasterFilterChip(label: '${e ? 'Not started' : 'ยังไม่เริ่ม'} ${n('future')}', on: _state == 'future', onTap: () => st('future')),
          ImMasterFilterChip(label: '${e ? 'Inactive' : 'หยุดใช้'} ${n('inactive')}', on: _state == 'inactive', onTap: () => st('inactive')),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No billers / collectors found' : 'ไม่พบผู้วางบิล/ผู้เก็บเงิน', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final c = shown[i];
                      return ImMasterListCard(
                        code: c.collectorCode,
                        chips: [
                          if (c.effectiveDateFrom != null || c.effectiveDateTo != null) arCollectorEffectiveChip(c, e),
                          if (!c.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: e && (c.collectorNameEng?.isNotEmpty ?? false) ? c.collectorNameEng! : c.collectorNameThai,
                        meta: TextSpan(
                            text: [
                          arCollectorTypeLabel(c.collectorType, e),
                          e ? 'billing ${c.billingCustomerCount}' : 'วางบิล ${c.billingCustomerCount} ราย',
                          e ? 'collecting ${c.collectionCustomerCount}' : 'เก็บเงิน ${c.collectionCustomerCount} ราย',
                        ].join(' · ')),
                        selected: widget.selectedId != null && widget.selectedId == c.id,
                        active: c.isActive,
                        onTap: () => widget.onTap(c),
                      );
                    },
                  ),
      ),
    ]);
  }
}
