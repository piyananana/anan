// lib/sa/screens/sa_menu_screen.dart — จัดการเมนู แบบเดียวกับหน้าจอหมวดหมู่สินค้า (IM แบบ B, user 2026-11-27)
// ซ้าย: ต้นไม้เมนู (ImMasterTree) — ป้ายชนิด F/W/L, จุดสีธีม (ทึบ = ตั้งเอง / ขอบ = ตามเมนูแม่), จำนวนเมนูย่อย,
//       ＋ เพิ่มเมนูย่อย, ตัวกรอง, ลากวางบนโฟลเดอร์เพื่อย้าย / ที่ขอบแถวเพื่อเรียงลำดับ (PUT /sa_menu/:id/move)
// ขวา: แถบหัว (ดู → แก้ไข), ตัวเลขสรุป (GET /sa_menu/:id/summary), ข้อมูลเมนู 3 กลุ่ม, สีธีม 10 แบบ + ตามเมนูแม่,
//       กลุ่มผู้ใช้ที่มีสิทธิ์ (อ่านอย่างเดียว) · ชื่อหน้าจอเลือกจากรายการหน้าจอที่ลงทะเบียนไว้ (Menu.registeredScreens)
// ลบทั้งหมด อยู่ในเมนู ⋮ และต้องพิมพ์คำยืนยัน
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../im/widgets/im_master_tree.dart';
import '../models/sa_menu.dart';
import '../services/sa_language_provider.dart';
import '../services/sa_menu_service.dart';
import '../utils/sa_menu_scope.dart';
import '../utils/sa_menu_theme.dart';
import '../widgets/sa_doc_appbar_actions.dart';

enum _Mode { none, view, edit, addRoot, addChild }

class MenuScreen extends StatefulWidget {
  final VoidCallback onMenusChanged; // แจ้งหน้าแรกให้โหลดเมนูใหม่
  final VoidCallback? onExit;

  const MenuScreen({super.key, required this.onMenusChanged, this.onExit});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with AutomaticKeepAliveClientMixin {
  List<Menu> _all = [];
  bool _loading = true;
  bool _busy = false; // นำเข้า/ส่งออก/ลบทั้งหมด
  String _query = '';
  String? _filter;
  final TextEditingController _searchCtrl = TextEditingController();

  _Mode _mode = _Mode.none;
  Menu? _selected; // เมนูที่ดู/แก้ หรือโฟลเดอร์แม่ของเมนูใหม่ (addChild)
  int _seq = 0; // เปลี่ยนทุกครั้งที่เปลี่ยนโหมด → สร้างฟอร์มใหม่เสมอ (pattern_detail_widget_stale_form_bug)
  GlobalKey<_MenuDetailState> _detailKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  MenuService get _svc => Provider.of<MenuService>(context, listen: false);
  bool get _en => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

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
      final menus = await _svc.fetchMenus(includeInactive: true);
      ScreenTheme.register(menus);
      if (!mounted) return;
      setState(() {
        _all = menus;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(_en ? 'Failed to load menus: $e' : 'โหลดเมนูไม่สำเร็จ: $e', error: true);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? ImKit.red : null));
  }

  Map<int, Menu> get _byId => {for (final m in _all) m.id: m};
  List<Menu> _kids(int? id) => _all.where((m) => m.parentId == id).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<String> _pathOf(Menu? m, bool e) {
    final byId = _byId;
    final out = <String>[];
    var p = m?.parentId == null ? null : byId[m!.parentId];
    while (p != null && out.length < 20) {
      out.insert(0, p.localName(e));
      p = p.parentId == null ? null : byId[p.parentId];
    }
    return out;
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _en);
    return true;
  }

  Future<void> _set(_Mode mode, Menu? m) async {
    setState(() {
      _mode = mode;
      _selected = m;
      _seq++;
      _detailKey = GlobalKey();
    });
  }

  Future<void> _go(_Mode mode, Menu? m) async {
    if (!await _confirmLeave()) return;
    await _set(mode, m);
  }

  // ── บันทึก / ลบ / ย้าย ──
  Future<Menu?> _save(_MenuPayload p) async {
    final e = _en;
    try {
      Menu saved;
      if (_mode == _Mode.edit && _selected != null) {
        saved = await _svc.updateMenu(_selected!.id,
            menuName: p.name,
            menuNameEn: p.nameEn,
            menuType: p.type,
            targetPath: p.target,
            sortOrder: p.sort ?? _selected!.sortOrder,
            isActive: p.active,
            isSystem: p.system,
            contentType: p.contentType,
            contentData: p.contentData,
            requiresApproval: p.approval,
            themeColor: p.theme);
      } else {
        saved = await _svc.addMenu(
            parentId: _mode == _Mode.addChild ? _selected?.id : null,
            menuName: p.name,
            menuNameEn: p.nameEn,
            menuType: p.type,
            targetPath: p.target,
            sortOrder: p.sort,
            isSystem: p.system,
            contentType: p.contentType,
            contentData: p.contentData,
            requiresApproval: p.approval,
            themeColor: p.theme);
      }
      await _load();
      widget.onMenusChanged();
      final fresh = _byId[saved.id] ?? saved;
      await _set(_Mode.view, fresh);
      _snack(e ? 'Saved "${fresh.localName(e)}"' : 'บันทึกเมนู "${fresh.menuName}" แล้ว');
      return fresh;
    } catch (err) {
      _snack(e ? 'Save failed: $err' : 'บันทึกไม่สำเร็จ: $err', error: true);
      return null;
    }
  }

  Future<void> _delete(Menu m) async {
    final e = _en;
    if (m.menuType == 'folder' && _kids(m.id).isNotEmpty) {
      _snack(e ? 'Delete the sub-menus first' : 'ลบเมนูย่อยในโฟลเดอร์นี้ก่อน', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e ? 'Delete menu' : 'ลบเมนู'),
        content: Text(e ? 'Delete "${m.localName(e)}"?' : 'ลบเมนู "${m.menuName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ImKit.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(e ? 'Delete' : 'ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteMenu(m.id);
      await _load();
      widget.onMenusChanged();
      await _set(_Mode.none, null);
      _snack(e ? 'Menu deleted' : 'ลบเมนูแล้ว');
    } catch (err) {
      _snack(e ? 'Delete failed: $err' : 'ลบไม่สำเร็จ: $err', error: true);
    }
  }

  Future<void> _move(ImTreeNode node, ImTreeNode? parent, ImTreeNode? before) async {
    final e = _en;
    try {
      await _svc.moveMenu(node.id, parentId: parent?.id, beforeId: before?.id);
      await _load();
      widget.onMenusChanged();
      if (_selected != null && _mode == _Mode.view) await _set(_Mode.view, _byId[_selected!.id]);
    } catch (err) {
      _snack(e ? 'Move failed: $err' : 'ย้ายไม่สำเร็จ: $err', error: true);
    }
  }

  // ── นำเข้า / ส่งออก / ลบทั้งหมด ──
  Future<void> _import() async {
    final e = _en;
    setState(() => _busy = true);
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: kIsWeb);
      final f = r?.files.single;
      if (f == null || (f.bytes == null && f.path == null)) {
        _snack(e ? 'No file selected' : 'ยกเลิกการเลือกไฟล์');
        return;
      }
      await _svc.importMenu(f);
      await _load();
      widget.onMenusChanged();
      _snack(e ? 'Menus imported' : 'นำเข้าเมนูแล้ว');
    } catch (err) {
      _snack(e ? 'Import failed: $err' : 'นำเข้าไม่สำเร็จ: $err', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final e = _en;
    setState(() => _busy = true);
    try {
      await _svc.exportMenu();
      _snack(e ? 'Menus exported' : 'ส่งออกเมนูแล้ว');
    } catch (err) {
      _snack(e ? 'Export failed: $err' : 'ส่งออกไม่สำเร็จ: $err', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final e = _en;
    final word = e ? 'DELETE ALL' : 'ลบทั้งหมด';
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(e ? 'Delete all menus' : 'ลบเมนูทั้งหมด', style: const TextStyle(color: ImKit.red)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e
                  ? 'Every menu (${_all.length}) and its content will be deleted. This cannot be undone. Export the menus first if you may need them.'
                  : 'เมนูทั้งหมด ${_all.length} เมนูและเนื้อหาจะถูกลบ ย้อนกลับไม่ได้ ถ้าอาจต้องใช้อีก ให้ส่งออก Excel ไว้ก่อน'),
              const SizedBox(height: 12),
              Text(e ? 'Type "$word" to confirm' : 'พิมพ์ "$word" เพื่อยืนยัน', style: const TextStyle(fontSize: 12.5, color: ImKit.ink2)),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                onChanged: (_) => setDlg(() {}),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ImKit.red, foregroundColor: Colors.white),
              onPressed: ctrl.text.trim() == word ? () => Navigator.pop(ctx, true) : null,
              child: Text(e ? 'Delete all' : 'ลบทั้งหมด'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _svc.deleteAllMenu();
      await _load();
      widget.onMenusChanged();
      await _set(_Mode.none, null);
      _snack(e ? 'All menus deleted' : 'ลบเมนูทั้งหมดแล้ว');
    } catch (err) {
      _snack(e ? 'Delete failed: $err' : 'ลบไม่สำเร็จ: $err', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── แผงซ้าย ──
  static (String, Color, Color) _kindOf(String type) => switch (type) {
        'folder' => ('F', ImKit.blueSoft, ImKit.blue),
        'link' => ('L', ImKit.goldSoft, ImKit.amber),
        _ => ('W', ImKit.okSoft, ImKit.ok),
      };

  bool _missingScreen(Menu m) => m.menuType == 'widget' && !Menu.isRegisteredScreen(m.targetPath);

  Widget _buildList(bool e, bool canCreate, bool canEdit) {
    final lookup = _byId;
    final inactive = _all.where((m) => !m.isActive).length;
    final system = _all.where((m) => m.isSystem).length;
    final approval = _all.where((m) => m.requiresApproval).length;
    final missing = _all.where(_missingScreen).length;
    final noColor = _all.where((m) => m.parentId == null && !ScreenTheme.isKey(m.themeColor)).length;
    final nodes = [
      for (final m in _all)
        () {
          final k = _kindOf(m.menuType);
          final t = ScreenTheme.resolve(m, lookup: lookup).$1;
          final own = ScreenTheme.isKey(m.themeColor);
          return ImTreeNode(
            id: m.id,
            parentId: m.parentId,
            code: '',
            name: m.localName(e),
            kind: k.$1,
            kindBg: k.$2,
            kindFg: k.$3,
            count: m.menuType == 'folder' ? '${_kids(m.id).length}' : null,
            active: m.isActive,
            canHaveChildren: m.menuType == 'folder',
            order: m.sortOrder,
            search: '${m.menuName} ${m.menuNameEn} ${m.targetPath ?? ''}',
            lead: Tooltip(
              message: '${t.name(e)}${own ? '' : (e ? ' (follows parent)' : ' (ตามเมนูแม่)')}',
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: own ? t.bar : Colors.transparent,
                  border: Border.all(color: t.bar, width: own ? 0 : 2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            trail: m.isSystem ? ImKit.chip('SYS', ImKit.redSoft, ImKit.red) : (_missingScreen(m) ? const Icon(Icons.error_outline, size: 15, color: ImKit.red) : null),
          );
        }(),
    ];
    void toggle(String f) => setState(() => _filter = _filter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search menu name / screen (Widget)' : 'ค้นหา ชื่อเมนู / ชื่อหน้าจอ (Widget)',
        onSearch: (v) => setState(() => _query = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _filter == null, onTap: () => setState(() => _filter = null)),
          ImMasterFilterChip(label: e ? 'Inactive $inactive' : 'หยุดใช้ $inactive', on: _filter == 'inactive', onTap: () => toggle('inactive')),
          ImMasterFilterChip(label: e ? 'System $system' : 'เมนูระบบ $system', on: _filter == 'system', onTap: () => toggle('system')),
          ImMasterFilterChip(label: e ? 'Approval $approval' : 'มีผู้อนุมัติ $approval', on: _filter == 'approval', onTap: () => toggle('approval')),
          ImMasterFilterChip(
              label: e ? 'Screen not found $missing' : 'ไม่พบหน้าจอ $missing',
              on: _filter == 'missing',
              fg: missing > 0 ? ImKit.red : null,
              onTap: () => toggle('missing')),
          ImMasterFilterChip(label: e ? 'Top level, no colour $noColor' : 'บนสุดไม่ตั้งสี $noColor', on: _filter == 'nocolor', onTap: () => toggle('nocolor')),
        ],
        countText: e ? '${_all.length} menus' : 'ทั้งหมด ${_all.length} เมนู',
      ),
      Expanded(
        child: _loading && _all.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ImMasterTree(
                nodes: nodes,
                selectedId: _mode == _Mode.view || _mode == _Mode.edit || _mode == _Mode.addChild ? _selected?.id : null,
                query: _query,
                filter: _filter == null
                    ? null
                    : (n) {
                        final m = lookup[n.id];
                        if (m == null) return false;
                        return switch (_filter) {
                          'inactive' => !m.isActive,
                          'system' => m.isSystem,
                          'approval' => m.requiresApproval,
                          'missing' => _missingScreen(m),
                          _ => m.parentId == null && !ScreenTheme.isKey(m.themeColor),
                        };
                      },
                onTap: (n) {
                  final m = lookup[n.id];
                  if (m != null) _go(_Mode.view, m);
                },
                onAddChild: canCreate
                    ? (n) {
                        final m = lookup[n.id];
                        if (m != null) _go(_Mode.addChild, m);
                      }
                    : null,
                onReorder: canEdit ? _move : null,
                isEnglish: e,
                emptyText: e ? 'No menu found' : 'ไม่พบเมนู',
                legend: [
                  ('F', e ? 'Folder' : 'โฟลเดอร์', ImKit.blueSoft, ImKit.blue),
                  ('W', e ? 'Screen' : 'หน้าจอ', ImKit.okSoft, ImKit.ok),
                  ('L', e ? 'Link' : 'ลิงก์', ImKit.goldSoft, ImKit.amber),
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
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 340,
      barActions: [
        if (canCreate) ImKit.barButton(context, e ? 'Add root menu' : 'เพิ่มเมนูหลัก', Icons.add, () => _go(_Mode.addRoot, null), primary: true),
        if (canCreate) ImKit.barButton(context, e ? 'Import Excel' : 'นำเข้า Excel', Icons.upload_file, _busy ? () {} : _import),
        ImKit.barButton(context, e ? 'Export Excel' : 'ส่งออก Excel', Icons.download, _busy ? () {} : _export),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _load();
            final fresh = _selected == null ? null : _byId[_selected!.id];
            await _set(fresh != null && _mode != _Mode.addRoot ? _Mode.view : _Mode.none, fresh);
          },
        ),
        if (canDelete)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: e ? 'More' : 'เพิ่มเติม',
            onSelected: (v) {
              if (v == 'deleteAll') _deleteAll();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'deleteAll',
                child: Row(children: [
                  const Icon(Icons.delete_forever, color: ImKit.red, size: 18),
                  const SizedBox(width: 8),
                  Text(e ? 'Delete all menus…' : 'ลบเมนูทั้งหมด…', style: const TextStyle(color: ImKit.red)),
                ]),
              ),
            ],
          ),
      ],
      list: _buildList(e, canCreate, canEdit),
      detail: _mode == _Mode.none
          ? Builder(
              builder: (ctx) => ImListToggle.placeholder(
                  ctx, Icons.account_tree_outlined, e ? 'Select a menu on the left, or add a root menu' : 'เลือกเมนูด้านซ้าย หรือเพิ่มเมนูหลัก'))
          : _MenuDetail(
              key: _detailKey,
              seq: _seq,
              mode: _mode,
              menu: _mode == _Mode.view || _mode == _Mode.edit ? _selected : null,
              parent: _mode == _Mode.addChild ? _selected : (_selected?.parentId == null ? null : _byId[_selected!.parentId]),
              all: _all,
              path: _mode == _Mode.addChild
                  ? [..._pathOf(_selected, e), _selected!.localName(e)]
                  : _mode == _Mode.addRoot
                      ? const []
                      : _pathOf(_selected, e),
              nextSort: (_kids(_mode == _Mode.addChild ? _selected?.id : null).length + 1) * 10,
              canEdit: canEdit,
              canCreate: canCreate,
              canDelete: canDelete,
              onEdit: () => _go(_Mode.edit, _selected),
              onAddChild: (m) => _go(_Mode.addChild, m),
              onDelete: _delete,
              onClose: () => _go(_Mode.none, null),
              onCancel: () => _set(_mode == _Mode.edit ? _Mode.view : _Mode.none, _mode == _Mode.edit ? _selected : null),
              onSave: _save,
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// แผงรายละเอียด
// ═══════════════════════════════════════════════════════════════════════════════
class _MenuPayload {
  final String name, nameEn, type;
  final String? target, contentType, contentData, theme;
  final int? sort;
  final bool active, system, approval;
  const _MenuPayload(this.name, this.nameEn, this.type, this.target, this.contentType, this.contentData, this.theme, this.sort,
      this.active, this.system, this.approval);
}

class _MenuDetail extends StatefulWidget {
  final int seq;
  final _Mode mode;
  final Menu? menu; // ดู/แก้
  final Menu? parent; // แม่ของเมนู (หรือโฟลเดอร์ที่จะเพิ่มลูก)
  final List<Menu> all;
  final List<String> path;
  final int nextSort;
  final bool canEdit, canCreate, canDelete;
  final VoidCallback onEdit, onClose, onCancel;
  final ValueChanged<Menu> onAddChild, onDelete;
  final Future<Menu?> Function(_MenuPayload) onSave;

  const _MenuDetail({
    super.key,
    required this.seq,
    required this.mode,
    required this.menu,
    required this.parent,
    required this.all,
    required this.path,
    required this.nextSort,
    required this.canEdit,
    required this.canCreate,
    required this.canDelete,
    required this.onEdit,
    required this.onClose,
    required this.onCancel,
    required this.onAddChild,
    required this.onDelete,
    required this.onSave,
  });

  @override
  State<_MenuDetail> createState() => _MenuDetailState();
}

class _MenuDetailState extends State<_MenuDetail> with ImMasterKit {
  bool _e = false;
  bool _saving = false;
  final _name = TextEditingController();
  final _nameEn = TextEditingController();
  final _target = TextEditingController();
  final _content = TextEditingController();
  final _sort = TextEditingController();
  String _type = 'folder';
  String _contentType = 'widget';
  String? _theme;
  bool _active = true, _system = false, _approval = false;
  String _snap = '';
  Map<String, dynamic>? _summary;

  bool get _view => widget.mode == _Mode.view;
  bool get _adding => widget.mode == _Mode.addRoot || widget.mode == _Mode.addChild;

  @override
  bool get kitEnglish => _e;
  @override
  bool get kitReadOnly => _view;

  @override
  void initState() {
    super.initState();
    _e = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final m = widget.menu;
    if (m != null) {
      _name.text = m.menuName;
      _nameEn.text = m.menuNameEn;
      _target.text = m.targetPath ?? '';
      _sort.text = '${m.sortOrder}';
      _type = m.menuType;
      _theme = ScreenTheme.isKey(m.themeColor) ? m.themeColor : null;
      _active = m.isActive;
      _system = m.isSystem;
      _approval = m.requiresApproval;
      _loadContent(m.id);
      _loadSummary(m.id);
    } else {
      _sort.text = '${widget.nextSort}';
    }
    _snap = _fp();
  }

  @override
  void dispose() {
    for (final c in [_name, _nameEn, _target, _content, _sort]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fp() => [_name.text, _nameEn.text, _target.text, _content.text, _sort.text, _type, _contentType, _theme, _active, _system, _approval].join('|');
  bool get isDirty => !_view && _fp() != _snap;

  Future<void> _loadContent(int id) async {
    try {
      final c = await Provider.of<MenuService>(context, listen: false).fetchMenuContent(id);
      if (!mounted) return;
      setState(() {
        _contentType = c.contentType ?? 'widget';
        _content.text = c.contentData ?? '';
        _snap = _fp();
      });
    } catch (_) {
      // ไม่มีเนื้อหา (โฟลเดอร์ / เมนูเก่า) — ใช้ค่าเริ่มต้น
    }
  }

  Future<void> _loadSummary(int id) async {
    try {
      final s = await Provider.of<MenuService>(context, listen: false).fetchMenuSummary(id);
      if (mounted) setState(() => _summary = s);
    } catch (_) {
      if (mounted) setState(() => _summary = const {});
    }
  }

  // สีที่ใช้จริงของฟอร์มนี้ (ตามค่าที่เลือกอยู่ ยังไม่บันทึกก็ได้)
  (ScreenThemeColors, String) _effective(bool e) {
    if (_theme != null) return (ScreenTheme.byKey(_theme), e ? 'Set on this menu' : 'ตั้งที่เมนูนี้');
    final lookup = {for (final m in widget.all) m.id: m};
    final r = ScreenTheme.resolve(widget.parent, lookup: lookup);
    if (widget.parent == null || r.$2 == null) return (r.$1, e ? 'System default' : 'ค่าเริ่มต้นระบบ');
    return (r.$1, e ? 'From "${r.$2!.localName(e)}"' : 'ตาม "${r.$2!.localName(false)}"');
  }

  Future<void> _submit() async {
    final e = _e;
    String? err;
    if (_name.text.trim().isEmpty) err = e ? 'Enter the menu name' : 'กรอกชื่อเมนู (ไทย)';
    if (err == null && _type != 'folder' && _target.text.trim().isEmpty) {
      err = _type == 'widget' ? (e ? 'Choose the screen' : 'เลือกชื่อหน้าจอ') : (e ? 'Enter the link' : 'กรอกลิงก์');
    }
    if (err == null && int.tryParse(_sort.text.trim()) == null) err = e ? 'Sort order must be a number' : 'ลำดับต้องเป็นตัวเลข';
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: ImKit.red));
      return;
    }
    setState(() => _saving = true);
    final folder = _type == 'folder';
    final saved = await widget.onSave(_MenuPayload(
      _name.text.trim(),
      _nameEn.text.trim(),
      _type,
      folder ? null : _target.text.trim(),
      folder ? null : _contentType,
      folder || _content.text.trim().isEmpty ? null : _content.text.trim(),
      _theme,
      int.tryParse(_sort.text.trim()),
      _active,
      _system,
      folder ? false : _approval,
    ));
    if (mounted && saved == null) setState(() => _saving = false);
  }

  Future<void> _pickScreen() async {
    final e = _e;
    final all = Menu.registeredScreens;
    final used = {for (final m in widget.all) if (m.menuType == 'widget' && m.id != widget.menu?.id) m.targetPath: m.localName(e)};
    final ctrl = TextEditingController();
    var list = all;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(e ? 'Choose a screen' : 'เลือกหน้าจอ'),
          content: SizedBox(
            width: 520,
            height: 440,
            child: Column(children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: e ? 'Search screen name' : 'ค้นหาชื่อหน้าจอ',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (q) => setDlg(() => list = all.where((s) => s.toLowerCase().contains(q.toLowerCase())).toList()),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(e ? '${list.length} of ${all.length} registered screens' : '${list.length} จาก ${all.length} หน้าจอที่ลงทะเบียนไว้',
                    style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final u = used[s];
                    return ListTile(
                      dense: true,
                      title: Text(s, style: const TextStyle(fontSize: 13)),
                      subtitle: u == null ? null : Text(e ? 'Used by "$u"' : 'ใช้แล้วที่เมนู "$u"', style: const TextStyle(fontSize: 11.5)),
                      onTap: () => Navigator.pop(ctx, s),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(e ? 'Cancel' : 'ยกเลิก'))],
        ),
      ),
    );
    ctrl.dispose();
    if (picked != null) {
      setState(() {
        _target.text = picked;
        if (_contentType == 'widget' && _content.text.trim().isEmpty) _content.text = picked;
      });
    }
  }

  // ── ส่วนต่างๆ ──
  Widget _infoCard(bool e) {
    final folder = _type == 'folder';
    final registered = Menu.isRegisteredScreen(_target.text.trim());
    final typeItems = [
      DropdownMenuItem(value: 'folder', child: Text(e ? 'Folder' : 'โฟลเดอร์ (Folder)')),
      DropdownMenuItem(value: 'widget', child: Text(e ? 'Screen (Widget)' : 'หน้าจอ (Widget)')),
      DropdownMenuItem(value: 'link', child: Text(e ? 'Link' : 'ลิงก์ (Link)')),
    ];
    final multi = _contentType == 'html' || _contentType == 'markdown';
    return kCard(
      title: e ? 'Menu details' : 'ข้อมูลเมนู',
      trailing: kLegend(withAuto: true),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([kTxt(e ? 'Name (Thai) *' : 'ชื่อเมนู (ไทย) *', _name), kTxt(e ? 'Name (English)' : 'ชื่อเมนู (อังกฤษ)', _nameEn)]),
          kRow([
            kDd<String>(e ? 'Menu type *' : 'ประเภทเมนู *', _type, typeItems, _view || (widget.menu != null && widget.all.any((m) => m.parentId == widget.menu!.id))
                ? null
                : (v) => setState(() {
                      _type = v ?? 'folder';
                      if (_type == 'folder') {
                        _target.clear();
                        _content.clear();
                      } else {
                        _contentType = _type == 'link' ? 'url' : 'widget';
                      }
                    })),
            kTxt(e ? 'Sort order *' : 'ลำดับการแสดงผล *', _sort, numeric: true, digitsOnly: true),
          ]),
          InputDecorator(
            decoration: kDec(e ? 'Under' : 'อยู่ภายใต้', editable: false),
            child: Text(widget.path.isEmpty ? (e ? '— Top level —' : '— เมนูบนสุด —') : widget.path.join(' › '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
          ),
          if (widget.menu != null && widget.all.any((m) => m.parentId == widget.menu!.id))
            kNote(e ? 'A folder with sub-menus cannot change type.' : 'โฟลเดอร์ที่มีเมนูย่อย เปลี่ยนประเภทไม่ได้'),
        ]),
        kGroup(2, e ? 'How it opens' : 'การเปิดหน้าจอ', ImKit.gParty, [
          if (folder)
            kNote(e ? 'A folder groups menus and does not open a screen.' : 'โฟลเดอร์ใช้จัดกลุ่มเมนู ไม่เปิดหน้าจอ')
          else ...[
            if (_type == 'widget') ...[
              kFk(
                label: e ? 'Screen (Widget) *' : 'ชื่อหน้าจอ (Widget) *',
                text: _target.text,
                hasValue: _target.text.trim().isNotEmpty,
                onSearch: _pickScreen,
                onClear: () => setState(() => _target.clear()),
              ),
              if (_target.text.trim().isNotEmpty)
                Row(children: [
                  Icon(registered ? Icons.check_circle : Icons.error_outline, size: 15, color: registered ? ImKit.ok : ImKit.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        registered
                            ? (e ? 'Found among the registered screens' : 'พบในรายการหน้าจอของระบบ')
                            : (e ? 'Not a registered screen — the menu will show "not found"' : 'ไม่พบในรายการหน้าจอของระบบ — เปิดเมนูแล้วจะขึ้นว่าไม่พบหน้าจอ'),
                        style: TextStyle(fontSize: 12, color: registered ? ImKit.ok : ImKit.red)),
                  ),
                ]),
            ] else
              kTxt(e ? 'Link path / URL *' : 'ลิงก์ / URL *', _target),
            kDd<String>(
                e ? 'Content type' : 'ประเภท Content',
                _contentType,
                const [
                  DropdownMenuItem(value: 'widget', child: Text('Widget Name')),
                  DropdownMenuItem(value: 'html', child: Text('HTML Content')),
                  DropdownMenuItem(value: 'markdown', child: Text('Markdown Content')),
                  DropdownMenuItem(value: 'url', child: Text('URL')),
                ],
                _view ? null : (v) => setState(() => _contentType = v ?? 'widget')),
            if (multi)
              TextField(
                controller: _content,
                readOnly: _view,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(fontSize: ImKit.font),
                decoration: InputDecoration(
                  labelText: _contentType == 'html' ? 'HTML Content' : 'Markdown Content',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  filled: _view,
                  fillColor: ImKit.ro,
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              kTxt(_contentType == 'url' ? 'URL' : (e ? 'Widget name' : 'Widget Name'), _content),
          ],
        ]),
        kGroup(3, e ? 'Access and approval' : 'สิทธิ์และการอนุมัติ', ImKit.gMore, [
          kChecks([
            kCk(e ? 'Active' : 'ใช้งาน', _active, _view || _adding ? null : (v) => setState(() => _active = v)),
            kCk(e ? 'System menu (developer only)' : 'เมนูระบบ (เฉพาะ Developer)', _system, _view ? null : (v) => setState(() => _system = v)),
            if (!folder) kCk(e ? 'Can have an approver' : 'มีผู้อนุมัติได้', _approval, _view ? null : (v) => setState(() => _approval = v)),
          ]),
          if (!folder && _approval)
            kNote(e
                ? 'Approval mode, approvers and document types are set on the "Approver Setup" screen.'
                : 'รูปแบบการอนุมัติ ผู้อนุมัติ และประเภทเอกสาร ตั้งที่หน้า "ตั้งค่าผู้อนุมัติ"'),
        ]),
      ]),
    );
  }

  Widget _swatch({required String? key, required ScreenThemeColors t, required String title, required String sub, bool inherit = false}) {
    final on = _theme == key;
    final tile = Container(
      width: 124,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: on ? Colors.black87 : ImKit.line, width: on ? 1.5 : 1),
        boxShadow: on ? [BoxShadow(color: ImKit.gold.withOpacity(0.7), spreadRadius: 2)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 26,
          color: inherit ? null : t.bar,
          decoration: inherit ? BoxDecoration(color: t.soft) : null,
          alignment: Alignment.center,
          child: inherit ? Icon(Icons.subdirectory_arrow_right, size: 16, color: t.ink) : null,
        ),
        Container(height: 10, color: inherit ? const Color(0xFFE1E6E3) : t.strip),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w600 : null)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: ImKit.ink3)),
          ]),
        ),
      ]),
    );
    if (_view) return Opacity(opacity: on ? 1 : 0.5, child: tile);
    return InkWell(borderRadius: BorderRadius.circular(8), onTap: () => setState(() => _theme = key), child: tile);
  }

  Widget _themeCard(bool e) {
    final eff = _effective(e);
    final lookup = {for (final m in widget.all) m.id: m};
    final parentT = ScreenTheme.resolve(widget.parent, lookup: lookup).$1;
    final t = eff.$1;
    final name = _name.text.trim().isEmpty ? (e ? 'New menu' : 'เมนูใหม่') : (e && _nameEn.text.trim().isNotEmpty ? _nameEn.text.trim() : _name.text.trim());
    final preview = Container(
      width: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: ImKit.pageBg, border: Border.all(color: ImKit.line), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          color: t.bar,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Container(
          height: 32,
          color: t.strip,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            Expanded(child: Text(e ? 'Header bar' : 'แถบหัว', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: t.ink, border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(6)),
              child: Text(e ? 'Edit' : 'แก้ไข', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 26, decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 6),
            FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.85,
                child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFDDE3E0), borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 6),
            FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.6,
                child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFDDE3E0), borderRadius: BorderRadius.circular(3)))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text.rich(
            TextSpan(style: const TextStyle(fontSize: 11.5, color: ImKit.ink2), children: [
              TextSpan(text: e ? 'Colour used: ' : 'สีที่ใช้: '),
              TextSpan(text: t.name(e), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
              TextSpan(text: ' · ${eff.$2}'),
            ]),
          ),
        ),
      ]),
    );
    final swatches = Wrap(spacing: 8, runSpacing: 8, children: [
      _swatch(key: null, t: parentT, title: e ? 'Follow parent' : 'ตามเมนูแม่', sub: parentT.name(e), inherit: true),
      for (final x in ScreenTheme.themes) _swatch(key: x.key, t: x, title: x.name(e), sub: x.fit(e)),
    ]);
    return kCard(
      title: e ? 'Theme colour' : 'สีธีม',
      count: e
          ? 'AppBar and header colour of this screen${_type == 'folder' ? ' · sub-menus set to "Follow parent" use it' : ''}'
          : 'สี AppBar และแถบหัวของหน้าจอนี้${_type == 'folder' ? ' · เมนูย่อยที่เลือก "ตามเมนูแม่" ใช้สีนี้' : ''}',
      child: LayoutBuilder(
        builder: (c, cons) => cons.maxWidth >= 900
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: swatches), const SizedBox(width: 14), preview])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [swatches, const SizedBox(height: 12), preview]),
      ),
    );
  }

  List<ImKpi> _kpis(bool e) {
    final m = widget.menu!;
    final s = _summary;
    final groups = (s?['groups'] as List?) ?? const [];
    final eff = _effective(e);
    final colour = ImKpi(e ? 'Theme colour' : 'สีธีม', eff.$1.name(e), eff.$2);
    if (m.menuType == 'folder') {
      final kids = widget.all.where((x) => x.parentId == m.id).toList();
      final folders = kids.where((x) => x.menuType == 'folder').length;
      return [
        ImKpi(e ? 'Sub-menus' : 'เมนูย่อย', '${kids.length}', e ? 'Folders $folders · screens ${kids.length - folders}' : 'โฟลเดอร์ $folders · หน้าจอ ${kids.length - folders}'),
        ImKpi(e ? 'Use this folder\'s colour' : 'ใช้สีตามโฟลเดอร์นี้', '${kids.where((x) => !ScreenTheme.isKey(x.themeColor)).length}',
            e ? 'Sub-menus without their own colour' : 'เมนูย่อยที่ไม่ได้ตั้งสีเอง'),
        ImKpi(e ? 'Groups that see it' : 'กลุ่มผู้ใช้ที่เห็นโฟลเดอร์', s == null ? '—' : '${groups.length}',
            e ? 'Have at least one menu inside' : 'มีสิทธิ์อย่างน้อย 1 เมนูข้างใน'),
        colour,
      ];
    }
    return [
      ImKpi(e ? 'Groups with access' : 'กลุ่มผู้ใช้ที่มีสิทธิ์', s == null ? '—' : '${groups.length}', e ? 'See the card below' : 'ดูรายชื่อในการ์ดด้านล่าง'),
      ImKpi(e ? 'Users with access' : 'ผู้ใช้ที่มีสิทธิ์', s == null ? '—' : '${s['user_count'] ?? 0}', e ? 'Granted to the user' : 'สิทธิ์ที่ให้กับผู้ใช้'),
      ImKpi(e ? 'Added to favourites' : 'เพิ่มเป็นเมนูโปรด', s == null ? '—' : '${s['favorite_count'] ?? 0}', e ? 'Users who pinned it' : 'ผู้ใช้ที่ปักหมุดไว้หน้าแรก'),
      colour,
    ];
  }

  Widget _accessCard(bool e) {
    final groups = ((_summary?['groups'] as List?) ?? const []).cast<Map>();
    Widget yes(dynamic v) => v == true ? ImKit.chip(e ? 'Yes' : 'ใช่', ImKit.okSoft, ImKit.ok) : const Text('—', style: TextStyle(color: ImKit.ink3));
    return kCard(
      title: e ? 'User groups with access' : 'กลุ่มผู้ใช้ที่มีสิทธิ์',
      count: e ? 'Read-only · change it on the group permission screen' : 'อ่านอย่างเดียว · แก้ที่หน้ากำหนดสิทธิ์กลุ่ม',
      trailing: kGhost(e ? 'Group permissions' : 'ไปหน้ากำหนดสิทธิ์', Icons.open_in_new,
          () => ImKit.openMenu(context, 'GroupMenuManagementScreen', 'กำหนดสิทธิ์เมนูของกลุ่ม', 'group menu permissions', e)),
      padding: EdgeInsets.zero,
      child: _summary == null
          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : kTable(
              [
                KCol(e ? 'Group' : 'กลุ่ม', 4),
                KCol(e ? 'Users' : 'ผู้ใช้', 1, num: true),
                KCol(e ? 'View' : 'ดู', 1),
                KCol(e ? 'Add' : 'เพิ่ม', 1),
                KCol(e ? 'Edit' : 'แก้ไข', 1),
                KCol(e ? 'Delete' : 'ลบ', 1),
                KCol(e ? 'Print' : 'พิมพ์', 1),
                KCol(e ? 'Approve' : 'อนุมัติ', 1),
              ],
              [
                for (final g in groups)
                  [
                    kCell('${g['name'] ?? ''}', bold: true),
                    kCell('${g['user_count'] ?? 0}', mono: true),
                    yes(g['can_view']),
                    yes(g['can_create']),
                    yes(g['can_edit']),
                    yes(g['can_delete']),
                    yes(g['can_print']),
                    yes(g['can_approve']),
                  ],
              ],
              minWidth: 640,
              empty: e ? 'No user group has this menu yet' : 'ยังไม่มีกลุ่มผู้ใช้ที่มีสิทธิ์เมนูนี้',
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    _e = e;
    final m = widget.menu;
    final folder = _type == 'folder';
    final title = m != null
        ? m.localName(e)
        : widget.mode == _Mode.addChild
            ? (e ? 'New sub-menu' : 'เพิ่มเมนูย่อย')
            : (e ? 'New root menu' : 'เพิ่มเมนูหลัก');
    final badges = <Widget>[
      ImKit.chip(folder ? (e ? 'Folder' : 'โฟลเดอร์') : (_type == 'link' ? (e ? 'Link' : 'ลิงก์') : (e ? 'Screen' : 'หน้าจอ')), Colors.white24, Colors.white),
      if (!_view) kEditingBadge(),
      if (m != null) _active ? ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.redSoft, ImKit.red),
      if (_system) ImKit.chip(e ? 'System menu' : 'เมนูระบบ', ImKit.redSoft, ImKit.red),
      if (!folder && _approval) ImKit.chip(e ? 'Can have an approver' : 'มีผู้อนุมัติได้', ImKit.goldSoft, ImKit.amber),
      if (widget.path.isNotEmpty)
        Text(widget.path.join(' › '), style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
    ];
    return kPage(
      header: kHeaderBar(
        title: title,
        badges: badges,
        acts: kStdActs(
          saving: _saving,
          onEdit: widget.canEdit && m != null ? widget.onEdit : null,
          onDelete: widget.canDelete && m != null ? () => widget.onDelete(m) : null,
          onClose: widget.onClose,
          onCancel: widget.onCancel,
          onSave: _submit,
          extra: [
            if (m != null && m.menuType == 'folder' && widget.canCreate)
              DocBarAction(e ? '+ Sub-menu' : '+ เมนูย่อย', () => widget.onAddChild(m), fg: kInk),
          ],
        ),
        busy: _saving,
      ),
      top: m == null ? null : kKpis(_kpis(e)),
      sections: [
        (0, e ? 'Menu details' : 'ข้อมูลเมนู', _infoCard(e)),
        (1, e ? 'Theme colour' : 'สีธีม', _themeCard(e)),
        if (m != null) (2, e ? 'User groups with access' : 'กลุ่มผู้ใช้ที่มีสิทธิ์', _accessCard(e)),
      ],
    );
  }
}
