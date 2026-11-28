// lib/gl/screens/gl_account_screen.dart
// หน้าจอผังบัญชี แบบ IM design B (user 2026-11-28):
//   ซ้าย = ต้นไม้ (ป้าย H หัวบัญชี / P ลงรายการได้ / K Control, ยอดทั้งปีข้างบัญชี, กรองตามประเภทบัญชีและชนิด,
//          ＋ เพิ่มบัญชีใต้หัวบัญชี, ลากไปวางบนหัวบัญชีประเภทเดียวกันเพื่อย้าย)
//   ขวา = AccountDetailWidget (เปิดมาเป็นโหมดดู แก้ไขผ่านแถบหัว, สำเนาเป็นบัญชีใหม่)
// มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยนรายการ; บันทึกแล้วแสดงบัญชีนั้นต่อ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../im/widgets/im_master_tree.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_account.dart';
import '../services/gl_account_service.dart';
import '../widgets/gl_account_detail_widget.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const AccountScreen({super.key, required this.onFieldsChanged, this.onExit});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<AccountDetailWidgetState> _detailKey = GlobalKey();
  final _svc = AccountService();
  final _searchCtrl = TextEditingController();

  List<Account> _accounts = [];
  Map<int, double> _net = {}; // account_id → เดบิต-เครดิต ทั้งปีบัญชีปัจจุบัน
  bool _loading = false;
  String _query = '';
  String? _type; // ASSET ... (null = ทั้งหมด)
  String? _filter; // postable | control | dims | inactive
  bool _showBalance = true;

  Mode _mode = Mode.none;
  Account? _selected; // addChild = หัวบัญชีแม่
  Account? _template; // สำเนาเป็นบัญชีใหม่
  int _requestSeq = 0;
  bool _isEnglish = false;

  static final _compact = NumberFormat.compact(locale: 'en');

  @override
  bool get wantKeepAlive => true;

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
      final rows = await _svc.fetchAllRows();
      Map<int, double> net = _net;
      try {
        net = (await _svc.fetchBalances()).net;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _accounts = rows;
          _net = net;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<int?, List<Account>> get _kids {
    final m = <int?, List<Account>>{};
    for (final a in _accounts) {
      m.putIfAbsent(a.parentId, () => []).add(a);
    }
    for (final l in m.values) {
      l.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    }
    return m;
  }

  /// ยอดทั้งปีรวมทั้งกิ่ง (เดบิต-เครดิต)
  Map<int, double> _subtreeNet(Map<int?, List<Account>> kids) {
    final memo = <int, double>{};
    double total(Account a) => memo[a.id] ??= (_net[a.id] ?? 0) + (kids[a.id] ?? const []).fold(0.0, (s, k) => s + total(k));
    for (final a in _accounts) {
      total(a);
    }
    return memo;
  }

  String _pathOf(Account? a) {
    if (a == null) return '';
    final byId = {for (final x in _accounts) x.id: x};
    final parts = <String>[];
    var p = a.parentId;
    while (p != null && byId.containsKey(p)) {
      final x = byId[p]!;
      parts.insert(0, '${x.accountCode} ${glAccountName(x, _isEnglish)}');
      p = x.parentId;
    }
    return parts.join(' › ');
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  void _set(Mode m, Account? row, {Account? template}) => setState(() {
        _mode = m;
        _selected = row;
        _template = template;
        _requestSeq++;
      });

  Future<void> _onView(Account row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (await _confirmLeave()) _set(Mode.view, row);
  }

  Future<void> _onAddRoot() async {
    if (await _confirmLeave()) _set(Mode.addRoot, null);
  }

  Future<void> _onAddChild(Account parent) async {
    if (await _confirmLeave()) _set(Mode.addChild, parent);
  }

  Future<void> _onCopy() async {
    final src = _selected;
    if (src == null) return;
    final parent = _accounts.where((a) => a.id == src.parentId).firstOrNull;
    _set(parent == null ? Mode.addRoot : Mode.addChild, parent, template: src);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _set(Mode.view, _selected);
    } else if (_mode == Mode.addChild && _selected != null && _template == null) {
      _set(Mode.view, _selected);
    } else if (_template != null) {
      _set(Mode.view, _accounts.where((a) => a.id == _template!.id).firstOrNull ?? _template);
    } else {
      _set(Mode.none, null);
    }
  }

  Future<void> _onDelete() async {
    final row = _selected;
    if (row == null) return;
    final e = _isEnglish;
    final name = glAccountName(row, e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(e ? 'Are you sure you want to delete "${row.accountCode} $name"?' : 'คุณแน่ใจหรือไม่ที่จะลบ "${row.accountCode} $name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(e ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row.id);
      await _load();
      _set(Mode.none, null);
      widget.onFieldsChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted "${row.accountCode} $name"' : 'ลบ "${row.accountCode} $name" สำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(Account row) async {
    final e = _isEnglish;
    final adding = _mode == Mode.addRoot || _mode == Mode.addChild;
    if (adding && _accounts.any((a) => a.accountCode == row.accountCode)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e ? 'Account code ${row.accountCode} already exists' : 'รหัสบัญชี ${row.accountCode} มีอยู่แล้ว'), backgroundColor: Colors.red));
      return;
    }
    try {
      final saved = adding ? await _svc.addRow(row) : await _svc.updateRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(adding ? (e ? 'Added "${row.accountCode}"' : 'เพิ่ม "${row.accountCode}" สำเร็จ') : (e ? 'Saved "${row.accountCode}"' : 'บันทึก "${row.accountCode}" สำเร็จ'))));
      }
      widget.onFieldsChanged();
      await _load();
      final fresh = _accounts.where((a) => a.id == saved.id).firstOrNull ?? saved;
      if (mounted) _set(Mode.view, fresh);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${e ? 'Error' : 'เกิดข้อผิดพลาด'}: ${ex.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onMove(ImTreeNode node, ImTreeNode? parent) async {
    final e = _isEnglish;
    if (!await _confirmLeave()) return;
    try {
      await _svc.moveNode(node.id, parent?.id);
      await _load();
      final fresh = _accounts.where((a) => a.id == node.id).firstOrNull;
      if (fresh != null) _set(Mode.view, fresh);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Moved' : 'ย้ายแล้ว')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  bool _needsDims(Account a) => a.branchRequired || a.dimRules.any((r) => r.isRequired);

  bool _match(Account a) {
    if (_type != null && a.accountType != _type) return false;
    switch (_filter) {
      case 'postable':
        return a.isNormalAccount;
      case 'control':
        return a.isControlAccount;
      case 'dims':
        return _needsDims(a);
      case 'inactive':
        return !a.isActive;
    }
    return true;
  }

  String _bal(double net, String normal) {
    final v = glNormalSigned(net, normal);
    if (v.abs() < 0.005) return '0';
    return v.abs() < 1000 ? NumberFormat('#,##0').format(v) : _compact.format(v);
  }

  Widget _buildList(bool e, bool canCreate, bool canEdit) {
    final kids = _kids;
    final sub = _subtreeNet(kids);
    final byId = {for (final a in _accounts) a.id: a};
    int count(bool Function(Account) f) => _accounts.where((a) => (_type == null || a.accountType == _type) && f(a)).length;
    final nodes = [
      for (final a in _accounts)
        ImTreeNode(
          id: a.id,
          parentId: a.parentId,
          code: a.accountCode,
          name: glAccountName(a, e),
          kind: !a.isNormalAccount ? 'H' : (a.isControlAccount ? 'K' : 'P'),
          kindBg: !a.isNormalAccount ? ImKit.blueSoft : (a.isControlAccount ? ImKit.purSoft : ImKit.okSoft),
          kindFg: !a.isNormalAccount ? ImKit.blue : (a.isControlAccount ? ImKit.pur : ImKit.ok),
          count: !a.isNormalAccount
              ? (_showBalance ? _bal(sub[a.id] ?? 0, a.normalBalance) : '${(kids[a.id] ?? const []).length}')
              : (_showBalance ? _bal(_net[a.id] ?? 0, a.normalBalance) : null),
          active: a.isActive,
          canHaveChildren: !a.isNormalAccount,
          search: a.accountNameEng,
        ),
    ];
    void toggle(String f) => setState(() => _filter = _filter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search code / account name (TH/EN)' : 'ค้นหา รหัส / ชื่อบัญชี (ไทย/อังกฤษ)',
        onSearch: (v) => setState(() => _query = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _type == null, onTap: () => setState(() => _type = null)),
          for (final t in accountTypeOptions.keys)
            ImMasterFilterChip(label: accountTypeLabel(t, e), on: _type == t, onTap: () => setState(() => _type = _type == t ? null : t)),
          ImMasterFilterChip(label: e ? 'Postable ${count((a) => a.isNormalAccount)}' : 'ลงรายการได้ ${count((a) => a.isNormalAccount)}',
              on: _filter == 'postable', onTap: () => toggle('postable')),
          ImMasterFilterChip(label: 'Control ${count((a) => a.isControlAccount)}', on: _filter == 'control', onTap: () => toggle('control')),
          ImMasterFilterChip(label: e ? 'Requires dims ${count(_needsDims)}' : 'ต้องระบุมิติ ${count(_needsDims)}',
              on: _filter == 'dims', onTap: () => toggle('dims')),
          ImMasterFilterChip(label: e ? 'Inactive ${count((a) => !a.isActive)}' : 'หยุดใช้ ${count((a) => !a.isActive)}',
              on: _filter == 'inactive', onTap: () => toggle('inactive')),
          ImMasterFilterChip(label: e ? 'Show balances' : 'แสดงยอด', on: _showBalance, onTap: () => setState(() => _showBalance = !_showBalance)),
        ],
        countText: e ? '${_accounts.length} accounts' : 'ทั้งหมด ${_accounts.length} บัญชี',
      ),
      Expanded(
        child: _loading && _accounts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ImMasterTree(
                nodes: nodes,
                selectedId: _mode == Mode.view || _mode == Mode.edit || (_mode == Mode.addChild && _template == null) ? _selected?.id : null,
                query: _query,
                filter: _type == null && _filter == null ? null : (n) => byId[n.id] != null && _match(byId[n.id]!),
                onTap: (n) {
                  final a = byId[n.id];
                  if (a != null) _onView(a);
                },
                onAddChild: canCreate
                    ? (n) {
                        final a = byId[n.id];
                        if (a != null) _onAddChild(a);
                      }
                    : null,
                onMove: canEdit ? _onMove : null,
                isEnglish: e,
                emptyText: e ? 'No account found' : 'ไม่พบบัญชี',
                legend: [
                  ('H', e ? 'Header' : 'หัวบัญชี', ImKit.blueSoft, ImKit.blue),
                  ('P', e ? 'Postable' : 'ลงรายการได้', ImKit.okSoft, ImKit.ok),
                  ('K', 'Control', ImKit.purSoft, ImKit.pur),
                ],
              ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final view = _mode == Mode.view;
    final sel = _selected;
    final kids = _kids;
    final sub = _subtreeNet(kids);
    final children = sel == null || _mode == Mode.addChild ? const <Account>[] : (kids[sel.id] ?? const <Account>[]);
    // ลบได้เฉพาะบัญชีที่ไม่มีบัญชีย่อยและยังไม่มีธุรกรรม (backend ตรวจที่อ้างทั้งหมดซ้ำอีกครั้ง)
    final deletable = sel != null && children.isEmpty && !sel.hasTransactions;
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 360,
      barActions: [
        ImKit.barButton(context, e ? 'Import accounts' : 'นำเข้าผังบัญชี', Icons.upload_file,
            () => ImKit.openMenu(context, 'AccountImportScreen', 'นำเข้าผังบัญชี', 'Import chart of accounts', e)),
        ImKit.barButton(context, e ? 'Print chart' : 'พิมพ์ผังบัญชี', Icons.print,
            () => ImKit.openMenu(context, 'ChartOfAccountsReportScreen', 'รายงานผังบัญชี', 'Chart of accounts report', e)),
        if (canCreate) ImKit.barButton(context, e ? 'Add root account' : 'เพิ่มบัญชีหลัก', Icons.add, _onAddRoot, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _load();
            final fresh = _selected == null ? null : _accounts.where((a) => a.id == _selected!.id).firstOrNull;
            _set(fresh != null && (_mode == Mode.view || _mode == Mode.edit) ? Mode.view : Mode.none, fresh);
          },
        ),
      ],
      list: _buildList(e, canCreate, canEdit),
      detail: AccountDetailWidget(
        key: _detailKey,
        mode: _mode,
        selected: _selected,
        template: _template,
        isPlaceholder: _mode == Mode.none,
        parentPath: _pathOf(_mode == Mode.addChild ? null : _selected),
        children: children,
        childBalance: {for (final c in children) c.id: glNormalSigned(sub[c.id] ?? 0, c.normalBalance)},
        onOpenChild: _onView,
        onSubmit: _onSubmit,
        onCancel: view ? () => _set(Mode.none, null) : _onCancel,
        onEdit: view && canEdit ? () => _set(Mode.edit, _selected) : null,
        onDelete: view && canDelete && deletable ? _onDelete : null,
        onAddChild: canCreate && sel != null && !sel.isNormalAccount && (view || _mode == Mode.edit) ? () => _onAddChild(sel) : null,
        onCopy: view && canCreate && sel != null ? _onCopy : null,
        requestSeq: _requestSeq,
      ),
    );
  }
}
