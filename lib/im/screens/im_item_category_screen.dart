import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_item_category.dart';
import '../services/im_item_category_service.dart';
import '../widgets/im_item_category_detail_widget.dart';
import '../widgets/im_master_kit.dart';
import '../widgets/im_master_tree.dart';

// หน้าจอหมวดหมู่สินค้า (user 2026-11-25): ซ้ายต้นไม้ (ค้นหา/กรอง, จำนวนสินค้ารวมหมวดย่อย, ＋ เพิ่มหมวดย่อย, ลากเพื่อย้าย)
// ขวารายละเอียด; คลิกแถว = ดู, บันทึกแล้วแสดงหมวดนั้นต่อ, มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยน
// (dialog ค้นหาหมวดหมู่ในหน้าจออื่นยังใช้ ImItemCategoryListTreeWidget เดิม)
class ImItemCategoryScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImItemCategoryScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImItemCategoryScreen> createState() => _ImItemCategoryScreenState();
}

class _ImItemCategoryScreenState extends State<ImItemCategoryScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImItemCategoryDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImItemCategoryService();
  final _searchCtrl = TextEditingController();

  List<ImItemCategory> _cats = [];
  bool _loading = false;
  String _query = '';
  String? _filter; // auto | empty | inactive

  Mode _mode = Mode.none;
  ImItemCategory? _selected; // addChild = หมวดแม่
  int _requestSeq = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _svc.fetchRows(withUsage: true);
      if (mounted) setState(() => _cats = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // จำนวนสินค้ารวมหมวดย่อยทุกระดับ
  Map<int, int> _subtreeCounts() {
    final kids = <int?, List<ImItemCategory>>{};
    for (final c in _cats) {
      kids.putIfAbsent(c.parentId, () => []).add(c);
    }
    final memo = <int, int>{};
    int total(ImItemCategory c) => memo[c.id] ??= c.itemCount + (kids[c.id] ?? const []).fold(0, (s, k) => s + total(k));
    for (final c in _cats) {
      total(c);
    }
    return memo;
  }

  String _pathOf(ImItemCategory? c) {
    if (c == null) return '';
    final byId = {for (final x in _cats) x.id: x};
    final parts = <String>[];
    var p = c.parentId;
    while (p != null && byId.containsKey(p)) {
      final x = byId[p]!;
      parts.insert(0, '${x.categoryCode} ${x.displayName(_isEnglish)}');
      p = x.parentId;
    }
    return parts.join(' › ');
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  void _set(Mode m, ImItemCategory? row) => setState(() {
        _mode = m;
        _selected = row;
        _requestSeq++;
      });

  Future<void> _onView(ImItemCategory row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (await _confirmLeave()) _set(Mode.view, row);
  }

  Future<void> _onAddRoot() async {
    if (await _confirmLeave()) _set(Mode.addRoot, null);
  }

  Future<void> _onAddChild(ImItemCategory parent) async {
    if (await _confirmLeave()) _set(Mode.addChild, parent);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _set(Mode.view, _selected);
    } else if (_mode == Mode.addChild && _selected != null) {
      _set(Mode.view, _selected);
    } else {
      _set(Mode.none, null);
    }
  }

  Future<void> _onDelete() async {
    final row = _selected;
    if (row == null) return;
    final e = _isEnglish;
    if (_cats.any((c) => c.parentId == row.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e ? 'Cannot delete a category with sub-categories. Remove or move them first.' : 'ไม่สามารถลบหมวดหมู่ที่มีหมวดย่อยได้ กรุณาลบหรือย้ายหมวดย่อยออกก่อน'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(e ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(e
            ? 'Are you sure you want to delete category "${row.categoryCode} ${row.displayName(e)}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบหมวดหมู่ "${row.categoryCode} ${row.displayName(e)}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(e ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.deleteRow(row.id);
      await _load();
      _set(Mode.none, null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e ? 'Error deleting: $ex' : 'เกิดข้อผิดพลาดในการลบ: $ex'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(ImItemCategory row) async {
    final e = _isEnglish;
    final adding = _mode == Mode.addRoot || _mode == Mode.addChild;
    try {
      final saved = adding ? await _svc.addRow(row) : await _svc.updateRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(adding ? (e ? 'Added successfully' : 'เพิ่มสำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
      }
      widget.onFieldsChanged();
      await _load();
      final fresh = _cats.where((c) => c.id == saved.id).firstOrNull ?? saved;
      if (mounted) _set(Mode.view, fresh);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e ? 'Error: $ex' : 'เกิดข้อผิดพลาด: $ex'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onMove(ImTreeNode node, ImTreeNode? parent) async {
    final e = _isEnglish;
    if (!await _confirmLeave()) return;
    try {
      await _svc.moveNode(node.id, parent?.id);
      await _load();
      final fresh = _cats.where((c) => c.id == node.id).firstOrNull;
      if (fresh != null) _set(Mode.view, fresh);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Moved' : 'ย้ายแล้ว')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildList(bool e, bool canCreate, bool canEdit) {
    final counts = _subtreeCounts();
    final auto = _cats.where((c) => c.isAutoNumber).length;
    final empty = _cats.where((c) => c.categoryType == 'CATEGORY' && (counts[c.id] ?? 0) == 0).length;
    final inactive = _cats.where((c) => !c.isActive).length;
    final byId = {for (final c in _cats) c.id: c};
    final nodes = [
      for (final c in _cats)
        ImTreeNode(
          id: c.id,
          parentId: c.parentId,
          code: c.categoryCode,
          name: c.displayName(e),
          kind: c.categoryType == 'HEADER' ? 'H' : 'C',
          kindBg: c.categoryType == 'HEADER' ? ImKit.blueSoft : ImKit.okSoft,
          kindFg: c.categoryType == 'HEADER' ? ImKit.blue : ImKit.ok,
          count: '${counts[c.id] ?? 0}',
          active: c.isActive,
        ),
    ];
    void toggle(String f) => setState(() => _filter = _filter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search code / category name' : 'ค้นหา รหัส / ชื่อหมวด',
        onSearch: (v) => setState(() => _query = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _filter == null, onTap: () => setState(() => _filter = null)),
          ImMasterFilterChip(label: e ? 'Auto numbering $auto' : 'รหัสอัตโนมัติ $auto', on: _filter == 'auto', onTap: () => toggle('auto')),
          ImMasterFilterChip(label: e ? 'No items $empty' : 'ไม่มีสินค้า $empty', on: _filter == 'empty', onTap: () => toggle('empty')),
          ImMasterFilterChip(label: e ? 'Inactive $inactive' : 'หยุดใช้ $inactive', on: _filter == 'inactive', onTap: () => toggle('inactive')),
        ],
        countText: e ? '${_cats.length} categories' : 'ทั้งหมด ${_cats.length} หมวด',
      ),
      Expanded(
        child: _loading && _cats.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ImMasterTree(
                nodes: nodes,
                selectedId: _mode == Mode.view || _mode == Mode.edit || _mode == Mode.addChild ? _selected?.id : null,
                query: _query,
                filter: _filter == null
                    ? null
                    : (n) {
                        final c = byId[n.id];
                        if (c == null) return false;
                        switch (_filter) {
                          case 'auto': return c.isAutoNumber;
                          case 'empty': return c.categoryType == 'CATEGORY' && (counts[c.id] ?? 0) == 0;
                          default: return !c.isActive;
                        }
                      },
                onTap: (n) {
                  final c = byId[n.id];
                  if (c != null) _onView(c);
                },
                onAddChild: canCreate
                    ? (n) {
                        final c = byId[n.id];
                        if (c != null) _onAddChild(c);
                      }
                    : null,
                onMove: canEdit ? _onMove : null,
                isEnglish: e,
                emptyText: e ? 'No category found' : 'ไม่พบหมวดหมู่สินค้า',
                legend: [
                  ('H', e ? 'Header' : 'หัวข้อ', ImKit.blueSoft, ImKit.blue),
                  ('C', e ? 'Category' : 'หมวด', ImKit.okSoft, ImKit.ok),
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
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 320,
      barActions: [
        if (canCreate) ImKit.barButton(context, e ? 'Add root category' : 'เพิ่มหมวดหมู่หลัก', Icons.add, _onAddRoot, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _load();
            final fresh = _selected == null ? null : _cats.where((c) => c.id == _selected!.id).firstOrNull;
            _set(fresh != null && _mode != Mode.addRoot ? Mode.view : Mode.none, fresh);
          },
        ),
      ],
      list: _buildList(e, canCreate, canEdit),
      detail: ImItemCategoryDetailWidget(
        key: _detailKey,
        mode: _mode,
        selected: _selected,
        isPlaceholder: _mode == Mode.none,
        parentPath: _pathOf(_mode == Mode.addChild ? null : _selected),
        onSubmit: _onSubmit,
        onCancel: view ? () => _set(Mode.none, null) : _onCancel,
        onEdit: view && canEdit ? () => _set(Mode.edit, _selected) : null,
        onDelete: view && canDelete ? _onDelete : null,
        onAddChild: view && canCreate && _selected != null ? () => _onAddChild(_selected!) : null,
        requestSeq: _requestSeq,
      ),
    );
  }
}
