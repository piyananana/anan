import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_location.dart';
import '../models/im_warehouse.dart';
import '../services/im_location_service.dart';
import '../services/im_warehouse_service.dart';
import '../widgets/im_location_detail_widget.dart';
import '../widgets/im_master_kit.dart';
import '../widgets/im_master_tree.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้าจอตำแหน่งจัดเก็บ (user 2026-11-25): ซ้ายเลือกคลัง + ต้นไม้ (กลุ่ม G / ช่องเก็บ B, จำนวนช่อง/สินค้า, ＋ เพิ่มลูกใต้กลุ่ม,
// ลากเพื่อย้ายใต้กลุ่มอื่นในคลังเดียวกัน) ขวารายละเอียด; บันทึกแล้วแสดงตำแหน่งนั้นต่อ, มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยน
// (dialog ค้นหาตำแหน่งในหน้าจออื่นยังใช้ ImLocationTreeWidget เดิม)
class ImLocationScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;
  final int? initialWarehouseId;

  const ImLocationScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
    this.initialWarehouseId,
  });

  @override
  State<ImLocationScreen> createState() => _ImLocationScreenState();
}

class _ImLocationScreenState extends State<ImLocationScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImLocationDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImLocationService();
  final _searchCtrl = TextEditingController();

  List<ImWarehouse> _warehouses = [];
  int? _warehouseId;
  List<ImLocation> _locs = [];
  bool _loading = true;
  String _query = '';
  String? _filter; // bin | empty | inactive

  Mode _mode = Mode.none;
  ImLocation? _selected; // addChild = กลุ่มแม่
  int _requestSeq = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    try {
      final list = await ImWarehouseService().fetchActiveRows();
      if (!mounted) return;
      setState(() {
        _warehouses = list;
        _warehouseId = widget.initialWarehouseId != null && list.any((w) => w.id == widget.initialWarehouseId)
            ? widget.initialWarehouseId
            : (list.isNotEmpty ? list.first.id : null);
      });
      await _load();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final wh = _warehouseId;
    if (wh == null) {
      setState(() { _locs = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await _svc.fetchRows(warehouseId: wh, withUsage: true);
      if (mounted && wh == _warehouseId) setState(() => _locs = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ImWarehouse? get _wh => _warehouses.where((w) => w.id == _warehouseId).firstOrNull;

  // ช่องเก็บทุกระดับใต้กลุ่ม
  Map<int, int> _binCounts() {
    final kids = <int?, List<ImLocation>>{};
    for (final l in _locs) {
      kids.putIfAbsent(l.parentId, () => []).add(l);
    }
    final memo = <int, int>{};
    int total(ImLocation l) => memo[l.id] ??=
        (kids[l.id] ?? const []).fold(0, (s, k) => s + (k.locationType == 'BIN' ? 1 : 0) + total(k));
    for (final l in _locs) {
      total(l);
    }
    return memo;
  }

  String _pathOf(ImLocation? l) {
    final parts = <String>[if (_wh != null) _wh!.warehouseCode];
    if (l != null) {
      final byId = {for (final x in _locs) x.id: x};
      final chain = <String>[];
      var p = l.parentId;
      while (p != null && byId.containsKey(p)) {
        final x = byId[p]!;
        chain.insert(0, '${x.locationCode} ${x.displayName(_isEnglish)}'.trim());
        p = x.parentId;
      }
      parts.addAll(chain);
    }
    return parts.join(' › ');
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  void _set(Mode m, ImLocation? row) => setState(() {
        _mode = m;
        _selected = row;
        _requestSeq++;
      });

  Future<void> _onView(ImLocation row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (await _confirmLeave()) _set(Mode.view, row);
  }

  Future<void> _onAddRoot() async {
    if (_warehouseId == null) return;
    if (await _confirmLeave()) _set(Mode.addRoot, null);
  }

  Future<void> _onAddChild(ImLocation parent) async {
    if (parent.locationType != 'GROUP') return;
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

  Future<void> _changeWarehouse(int? id) async {
    if (id == null || id == _warehouseId) return;
    if (!await _confirmLeave()) return;
    setState(() {
      _warehouseId = id;
      _locs = [];
    });
    _set(Mode.none, null);
    await _load();
  }

  Future<void> _onDelete() async {
    final row = _selected;
    if (row == null) return;
    final e = _isEnglish;
    if (_locs.any((l) => l.parentId == row.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e ? 'Cannot delete a location that has sub-locations. Remove or move them first.' : 'ไม่สามารถลบตำแหน่งที่มีตำแหน่งย่อยได้ กรุณาลบหรือย้ายตำแหน่งย่อยออกก่อน'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(e ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(e
            ? 'Are you sure you want to delete location "${row.locationCode} ${row.displayName(e)}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบตำแหน่ง "${row.locationCode} ${row.displayName(e)}" ?'),
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

  Future<void> _onSubmit(ImLocation row) async {
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
      final fresh = _locs.where((l) => l.id == saved.id).firstOrNull ?? saved;
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
      final fresh = _locs.where((l) => l.id == node.id).firstOrNull;
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
    final bins = _binCounts();
    final binCount = _locs.where((l) => l.locationType == 'BIN').length;
    final emptyBins = _locs.where((l) => l.locationType == 'BIN' && l.itemCount == 0).length;
    final inactive = _locs.where((l) => !l.isActive).length;
    final byId = {for (final l in _locs) l.id: l};
    final nodes = [
      for (final l in _locs)
        ImTreeNode(
          id: l.id,
          parentId: l.parentId,
          code: l.locationCode,
          name: l.displayName(e),
          kind: l.locationType == 'GROUP' ? 'G' : 'B',
          kindBg: l.locationType == 'GROUP' ? ImKit.ro : ImKit.goldSoft,
          kindFg: l.locationType == 'GROUP' ? ImKit.gMore : ImKit.amber,
          count: l.locationType == 'GROUP'
              ? (e ? '${bins[l.id] ?? 0} bins' : '${bins[l.id] ?? 0} ช่อง')
              : (l.itemCount == 0 ? (e ? 'empty' : 'ว่าง') : (e ? '${l.itemCount} items' : '${l.itemCount} สินค้า')),
          active: l.isActive,
          canHaveChildren: l.locationType == 'GROUP',
        ),
    ];
    void toggle(String f) => setState(() => _filter = _filter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(6)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _warehouseId,
              isExpanded: true,
              hint: Text(e ? 'No warehouses found' : 'ไม่พบคลังสินค้า'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              items: [
                for (final w in _warehouses)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: e ? 'Warehouse ' : 'คลัง ', style: const TextStyle(color: ImKit.ink2)),
                        TextSpan(text: '${w.warehouseCode}  ', style: TextStyle(fontWeight: FontWeight.w600, color: ScreenTheme.of(context).ink)),
                        TextSpan(text: w.warehouseName(e)),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _changeWarehouse,
            ),
          ),
        ),
      ),
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search code / location name' : 'ค้นหา รหัส / ชื่อตำแหน่ง',
        onSearch: (v) => setState(() => _query = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _filter == null, onTap: () => setState(() => _filter = null)),
          ImMasterFilterChip(label: e ? 'Bins $binCount' : 'ช่องเก็บ $binCount', on: _filter == 'bin', onTap: () => toggle('bin')),
          ImMasterFilterChip(label: e ? 'Empty bins $emptyBins' : 'ช่องว่าง $emptyBins', on: _filter == 'empty', onTap: () => toggle('empty')),
          ImMasterFilterChip(label: e ? 'Inactive $inactive' : 'หยุดใช้ $inactive', on: _filter == 'inactive', onTap: () => toggle('inactive')),
        ],
        countText: e ? '${_locs.length} location(s)' : 'ทั้งหมด ${_locs.length} ตำแหน่ง',
      ),
      Expanded(
        child: _loading && _locs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ImMasterTree(
                nodes: nodes,
                selectedId: _mode == Mode.view || _mode == Mode.edit || _mode == Mode.addChild ? _selected?.id : null,
                query: _query,
                filter: _filter == null
                    ? null
                    : (n) {
                        final l = byId[n.id];
                        if (l == null) return false;
                        switch (_filter) {
                          case 'bin': return l.locationType == 'BIN';
                          case 'empty': return l.locationType == 'BIN' && l.itemCount == 0;
                          default: return !l.isActive;
                        }
                      },
                onTap: (n) {
                  final l = byId[n.id];
                  if (l != null) _onView(l);
                },
                onAddChild: canCreate
                    ? (n) {
                        final l = byId[n.id];
                        if (l != null) _onAddChild(l);
                      }
                    : null,
                onMove: canEdit ? _onMove : null,
                isEnglish: e,
                emptyText: _warehouseId == null
                    ? (e ? 'No warehouses found' : 'ไม่พบคลังสินค้า')
                    : (e ? 'No location in this warehouse yet' : 'ยังไม่มีผังตำแหน่งในคลังนี้'),
                legend: [
                  ('G', e ? 'Group' : 'กลุ่ม', ImKit.ro, ImKit.gMore),
                  ('B', e ? 'Bin' : 'ช่องเก็บ', ImKit.goldSoft, ImKit.amber),
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
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final byId = {for (final l in _locs) l.id: l};
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 320,
      barActions: [
        if (canCreate && !narrow)
          ImKit.barButton(context, e ? 'Import' : 'นำเข้าข้อมูล', Icons.upload_file,
              () => ImKit.openMenu(context, 'ImLocationImportScreen', 'นำเข้าข้อมูลตำแหน่งจัดเก็บ', 'Location Import', e)),
        if (canCreate && _warehouseId != null) ImKit.barButton(context, e ? 'Add zone' : 'เพิ่มโซน', Icons.add, _onAddRoot, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _load();
            final fresh = _selected == null ? null : _locs.where((l) => l.id == _selected!.id).firstOrNull;
            _set(fresh != null && _mode != Mode.addRoot ? Mode.view : Mode.none, fresh);
          },
        ),
      ],
      list: _buildList(e, canCreate, canEdit),
      detail: _warehouseId == null
          // ยังไม่มีคลัง — หน้าว่างที่ยังมีปุ่มย่อ/ขยายรายการ (Builder: ต้องอยู่ใต้ ImMasterShell จึงเห็นสถานะปุ่ม)
          ? Builder(builder: (ctx) => ImListToggle.placeholder(ctx, null, ''))
          : ImLocationDetailWidget(
              key: _detailKey,
              mode: _mode,
              selected: _selected,
              warehouseId: _warehouseId!,
              isPlaceholder: _mode == Mode.none,
              parentPath: _pathOf(_selected),
              onSubmit: _onSubmit,
              onCancel: view ? () => _set(Mode.none, null) : _onCancel,
              onEdit: view && canEdit ? () => _set(Mode.edit, _selected) : null,
              onDelete: view && canDelete ? _onDelete : null,
              onAddChild: view && canCreate && _selected?.locationType == 'GROUP' ? () => _onAddChild(_selected!) : null,
              onOpenChild: (id) {
                final l = byId[id];
                if (l != null) _onView(l);
              },
              requestSeq: _requestSeq,
            ),
    );
  }
}
