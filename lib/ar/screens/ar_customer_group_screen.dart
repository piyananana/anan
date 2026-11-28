// screens/ar_customer_group_screen.dart — กลุ่มลูกค้า แบบ B ของ IM (user 2026-11-28)
//   ซ้าย: การ์ดกลุ่ม (จำนวนลูกค้า เครดิต วงเงิน ป้ายรหัสอัตโนมัติ) / ขวา: เปิดเป็นโหมดดู → แก้ไข / ลบ ที่แถบหัว
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
import '../models/ar_customer_group.dart';
import '../services/ar_customer_group_service.dart';
import '../widgets/ar_customer_group_detail_widget.dart';

class ArCustomerGroupScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ArCustomerGroupScreen({super.key, required this.onFieldsChanged, this.onExit});

  @override
  State<ArCustomerGroupScreen> createState() => _ArCustomerGroupScreenState();
}

class _ArCustomerGroupScreenState extends State<ArCustomerGroupScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_GroupListState> _listKey = GlobalKey();
  final GlobalKey<ArCustomerGroupDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  ArCustomerGroup? _selected;
  bool _fullLoaded = false;
  int _requestSeq = 0;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  ArCustomerGroupService get _svc => Provider.of<ArCustomerGroupService>(context, listen: false);

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

  Future<void> _onView(ArCustomerGroup row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(ArCustomerGroup row) {
    setState(() {
      _mode = Mode.view;
      _selected = row;
      _fullLoaded = false;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  // ข้อมูลเต็ม (เงื่อนไขวางบิล/รับชำระ) — ก่อนโหลดเสร็จยังแก้ไขไม่ได้
  Future<void> _fetchFull(ArCustomerGroup row) async {
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
    final name = e && row!.groupNameEng.isNotEmpty ? row.groupNameEng : row!.groupNameThai;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e
            ? 'Are you sure you want to delete customer group "${row.groupCode} $name" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบกลุ่มลูกค้า "${row.groupCode} $name" ?'),
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

  // บันทึกแล้วแสดงกลุ่มนั้นต่อ
  Future<void> _onSubmit(ArCustomerGroup row) async {
    final e = _isEnglish;
    try {
      final ArCustomerGroup saved;
      if (_mode == Mode.add) {
        saved = await _svc.addRow(row);
      } else {
        saved = await _svc.updateRow(row);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_mode == Mode.add ? (e ? 'Added ${saved.groupCode}' : 'เพิ่มกลุ่ม ${saved.groupCode} สำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
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
      return ArCustomerGroupDetailWidget(
          key: _detailKey, mode: Mode.none, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return ArCustomerGroupDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selected,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? (_fullLoaded ? _onEdit : null) : null,
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
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add group' : 'เพิ่มกลุ่มลูกค้า', Icons.add, _onAdd, primary: true),
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
      list: _GroupList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _detail(canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการกลุ่มลูกค้า (แผงซ้าย)
// ---------------------------------------------------------------------------
class _GroupList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<ArCustomerGroup> onTap;
  const _GroupList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_GroupList> createState() => _GroupListState();
}

enum _GFlag { auto, billing, inactive }

class _GroupListState extends State<_GroupList> {
  final _search = TextEditingController();
  final _money = NumberFormat('#,##0');
  List<ArCustomerGroup> _rows = [];
  _GFlag? _flag;
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
      final rows = await Provider.of<ArCustomerGroupService>(context, listen: false).fetchRows();
      if (mounted) setState(() => _rows = rows);
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _ok(ArCustomerGroup g, _GFlag? f) => switch (f) {
        null => true,
        _GFlag.auto => g.isAutoNumber,
        _GFlag.billing => g.requiresBilling,
        _GFlag.inactive => !g.isActive,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows
        .where((g) => q.isEmpty || g.groupCode.toLowerCase().contains(q) || g.groupNameThai.toLowerCase().contains(q) || g.groupNameEng.toLowerCase().contains(q))
        .toList();
    final shown = base.where((g) => _ok(g, _flag)).toList()..sort((a, b) => a.groupCode.compareTo(b.groupCode));
    int n(_GFlag f) => base.where((g) => _ok(g, f)).length;
    void flag(_GFlag f) => setState(() => _flag = _flag == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อกลุ่ม',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length ? (e ? '${_rows.length} groups' : 'ทั้งหมด ${_rows.length} กลุ่ม') : (e ? '${shown.length} of ${_rows.length} groups' : '${shown.length} จาก ${_rows.length} กลุ่ม')),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _flag == null, onTap: () => setState(() => _flag = null)),
          ImMasterFilterChip(label: '${e ? 'Auto code' : 'รหัสอัตโนมัติ'} ${n(_GFlag.auto)}', on: _flag == _GFlag.auto, onTap: () => flag(_GFlag.auto)),
          ImMasterFilterChip(label: '${e ? 'Billing' : 'ต้องวางบิล'} ${n(_GFlag.billing)}', on: _flag == _GFlag.billing, onTap: () => flag(_GFlag.billing)),
          ImMasterFilterChip(label: '${e ? 'Inactive' : 'หยุดใช้'} ${n(_GFlag.inactive)}', on: _flag == _GFlag.inactive, onTap: () => flag(_GFlag.inactive)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No customer groups found' : 'ไม่พบกลุ่มลูกค้า', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final g = shown[i];
                      final term = g.creditTermMonths > 0
                          ? (e ? '${g.creditTermMonths} mo ${g.creditTermDays} d' : '${g.creditTermMonths} ด. ${g.creditTermDays} ว.')
                          : (e ? '${g.creditTermDays} days' : '${g.creditTermDays} วัน');
                      return ImMasterListCard(
                        code: g.groupCode,
                        chips: [
                          if (g.isAutoNumber) ImKit.chip(e ? 'Auto' : 'รหัสอัตโนมัติ', ImKit.blueSoft, ImKit.blue),
                          if (!g.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: e && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai,
                        meta: TextSpan(
                            text: [
                          e ? '${g.customerCount} customer(s)' : 'ลูกค้า ${g.customerCount} ราย',
                          '${e ? 'credit' : 'เครดิต'} $term',
                          if (g.creditLimit > 0) '${e ? 'limit' : 'วงเงิน'} ${_money.format(g.creditLimit)}',
                        ].join(' · ')),
                        selected: widget.selectedId != null && widget.selectedId == g.id,
                        active: g.isActive,
                        onTap: () => widget.onTap(g),
                      );
                    },
                  ),
      ),
    ]);
  }
}
