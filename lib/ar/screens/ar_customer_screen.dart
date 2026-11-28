import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../models/ar_customer_summary.dart';
import '../services/ar_customer_group_service.dart';
import '../services/ar_customer_service.dart';
import '../widgets/ar_customer_detail_widget.dart';

// หน้าจอข้อมูลลูกค้า — แบบ B ของ IM (user 2026-11-28)
//   ซ้าย: การ์ดลูกค้า + ยอดค้าง/เกินกำหนด/แถบวงเงิน, ตัวกรอง กลุ่ม / เกินกำหนด / เกินวงเงิน / ต้องวางบิล / หยุดใช้
//   ขวา: เปิดมาเป็นโหมดดู → แก้ไข / สำเนาเป็นลูกค้าใหม่ / ลบ ที่แถบหัว; มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยนลูกค้า
//   ปุ่มย่อ/ขยายรายการอยู่หน้าชื่อบนแถบหัวแผงขวา (ImListToggle ผ่าน ImMasterShell)
class ArCustomerScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ArCustomerScreen({super.key, required this.onFieldsChanged, this.onExit});

  @override
  State<ArCustomerScreen> createState() => _ArCustomerScreenState();
}

class _ArCustomerScreenState extends State<ArCustomerScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_ArCustomerMasterListState> _listKey = GlobalKey();
  final GlobalKey<ArCustomerDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  ArCustomer? _selected;
  ArCustomer? _copyFrom;
  bool _fullLoaded = false;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  int _requestSeq = 0;

  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  ArCustomerService get _svc => Provider.of<ArCustomerService>(context, listen: false);

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

  Future<void> _onView(ArCustomer row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(ArCustomer row) {
    setState(() {
      _mode = Mode.view;
      _selected = row;
      _copyFrom = null;
      _fullLoaded = false;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  // ข้อมูลเต็ม (ที่อยู่/ผู้ติดต่อ/เงื่อนไข) — ก่อนโหลดเสร็จยังแก้ไข/สำเนาไม่ได้
  Future<void> _fetchFull(ArCustomer row) async {
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
    final isEnglish = _isEnglish;
    final l = AppL10n(isEnglish);
    final name = isEnglish && (row!.customerNameEn?.isNotEmpty ?? false) ? row.customerNameEn! : row!.customerNameTh;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(isEnglish
            ? 'Are you sure you want to delete customer "${row.customerCode} $name" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบลูกค้า "${row.customerCode} $name" ?'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error deleting: $e' : 'เกิดข้อผิดพลาดในการลบ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // บันทึกแล้วแสดงลูกค้านั้นต่อ (ไม่ปิดแผงขวา)
  Future<void> _onSubmit(ArCustomer row) async {
    final isEnglish = _isEnglish;
    try {
      final ArCustomer saved;
      if (_mode == Mode.add) {
        saved = await _svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEnglish ? 'Added ${saved.customerCode}' : 'เพิ่มลูกค้า ${saved.customerCode} สำเร็จ')));
        }
      } else {
        saved = await _svc.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        }
      }
      _listKey.currentState?.refresh();
      widget.onFieldsChanged();
      if (mounted) _show(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ยกเลิก: แก้ไข → กลับไปดูลูกค้าเดิม, สำเนา → กลับไปดูต้นฉบับ, อื่นๆ → ปิดแผงขวา
  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _show(_selected!);
    } else if (_mode == Mode.add && _copyFrom != null) {
      _show(_copyFrom!);
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
      return ArCustomerDetailWidget(
          key: _detailKey, mode: Mode.none, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return ArCustomerDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selected,
      copyFrom: _mode == Mode.add ? _copyFrom : null,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? (_fullLoaded ? _onEdit : null) : null,
      onCopy: view && canCreate ? (_fullLoaded ? _onCopy : null) : null,
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
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 340,
      barActions: [
        if (canCreate && !narrow)
          ImKit.barButton(context, isEnglish ? 'Import' : 'นำเข้าข้อมูล', Icons.upload_file,
              () => ImKit.openMenu(context, 'ArCustomerImportScreen', 'นำเข้าข้อมูลลูกค้า', 'Customer Import', isEnglish)),
        if (!narrow)
          ImKit.barButton(context, isEnglish ? 'Customer report' : 'พิมพ์รายงานลูกค้า', Icons.print_outlined,
              () => ImKit.openMenu(context, 'ArCustomerReportScreen', 'รายงานข้อมูลลูกค้า', 'Customer Report', isEnglish)),
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add customer' : 'เพิ่มลูกค้า', Icons.add, _onAdd, primary: true),
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
      list: _ArCustomerMasterList(
        key: _listKey,
        selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null,
        onTap: _onView,
      ),
      detail: _detail(canCreate, canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการลูกค้า (แผงซ้าย)
// ---------------------------------------------------------------------------
class _ArCustomerMasterList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<ArCustomer> onTap;
  const _ArCustomerMasterList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_ArCustomerMasterList> createState() => _ArCustomerMasterListState();
}

enum _Flag { overdue, overLimit, billing, inactive }

class _ArCustomerMasterListState extends State<_ArCustomerMasterList> {
  final _search = TextEditingController();
  final _money = NumberFormat('#,##0.00');
  List<ArCustomer> _rows = [];
  Map<int, ArCustomerBalance> _bal = {};
  List<ArCustomerGroup> _groups = [];
  String? _groupId;
  _Flag? _flag;
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
    final svc = Provider.of<ArCustomerService>(context, listen: false);
    final gsvc = Provider.of<ArCustomerGroupService>(context, listen: false);
    try {
      final rows = await svc.fetchRows();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e')));
      }
    }
    // ยอดค้าง/กลุ่ม โหลดไม่ได้ → การ์ดยังแสดง แค่ไม่มียอด
    try {
      final b = await svc.fetchBalances();
      if (mounted) setState(() => _bal = b);
    } catch (_) {}
    try {
      final g = await gsvc.fetchRows();
      if (mounted) setState(() => _groups = g);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  ArCustomerBalance? _b(ArCustomer c) => c.id == null ? null : _bal[c.id];
  bool _isOverdue(ArCustomer c) => (_b(c)?.overdue ?? 0) > 0.005;
  bool _isOverLimit(ArCustomer c) => c.creditLimit > 0 && (_b(c)?.outstanding ?? 0) > c.creditLimit + 0.005;

  bool _match(ArCustomer c, String q) {
    if (q.isEmpty) return true;
    return c.customerCode.toLowerCase().contains(q) ||
        c.customerNameTh.toLowerCase().contains(q) ||
        (c.customerNameEn?.toLowerCase().contains(q) ?? false) ||
        (c.taxId?.toLowerCase().contains(q) ?? false) ||
        (c.oldCustomerCode?.toLowerCase().contains(q) ?? false);
  }

  bool _flagOk(ArCustomer c, _Flag? f) => switch (f) {
        null => true,
        _Flag.overdue => _isOverdue(c),
        _Flag.overLimit => _isOverLimit(c),
        _Flag.billing => c.requiresBilling,
        _Flag.inactive => !c.isActive,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows.where((c) => _match(c, q) && (_groupId == null || '${c.customerGroupId}' == _groupId)).toList();
    final shown = base.where((c) => _flagOk(c, _flag)).toList()..sort((a, b) => a.customerCode.compareTo(b.customerCode));
    int n(_Flag f) => base.where((c) => _flagOk(c, f)).length;
    void flag(_Flag f) => setState(() => _flag = _flag == f ? null : f);
    final grp = _groups.where((g) => '${g.id}' == _groupId).firstOrNull;
    String gName(ArCustomerGroup g) => e && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name / tax ID / old code' : 'ค้นหา รหัส / ชื่อ / เลขผู้เสียภาษี / รหัสเดิม',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length
                ? (e ? '${_rows.length} customers' : 'ทั้งหมด ${_rows.length} ราย')
                : (e ? '${shown.length} of ${_rows.length} customers' : '${shown.length} จาก ${_rows.length} ราย')),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _flag == null && _groupId == null, onTap: () => setState(() {
                _flag = null;
                _groupId = null;
              })),
          ImMasterPopupFilter(
            label: e ? 'Group' : 'กลุ่ม',
            value: _groupId,
            valueLabel: grp?.groupCode,
            allLabel: e ? 'All groups' : 'ทุกกลุ่ม',
            options: [for (final g in _groups) ('${g.id}', '${g.groupCode}  ${gName(g)}')],
            onChanged: (v) => setState(() => _groupId = v),
          ),
          ImMasterFilterChip(label: '${e ? 'Overdue' : 'เกินกำหนด'} ${n(_Flag.overdue)}', on: _flag == _Flag.overdue, onTap: () => flag(_Flag.overdue), fg: ImKit.red),
          ImMasterFilterChip(label: '${e ? 'Over limit' : 'เกินวงเงิน'} ${n(_Flag.overLimit)}', on: _flag == _Flag.overLimit, onTap: () => flag(_Flag.overLimit), fg: ImKit.red),
          ImMasterFilterChip(label: '${e ? 'Billing' : 'ต้องวางบิล'} ${n(_Flag.billing)}', on: _flag == _Flag.billing, onTap: () => flag(_Flag.billing)),
          ImMasterFilterChip(label: '${e ? 'Inactive' : 'หยุดใช้'} ${n(_Flag.inactive)}', on: _flag == _Flag.inactive, onTap: () => flag(_Flag.inactive)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No customers found' : 'ไม่พบข้อมูลลูกค้า', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _card(shown[i], e),
                  ),
      ),
    ]);
  }

  Widget _card(ArCustomer c, bool e) {
    final b = _b(c);
    final name = e && (c.customerNameEn?.isNotEmpty ?? false) ? c.customerNameEn! : c.customerNameTh;
    final out = b?.outstanding ?? 0;
    final over = b?.overdue ?? 0;
    final overLimit = _isOverLimit(c);
    final meta = <InlineSpan>[];
    if (out.abs() > 0.005) {
      meta.add(TextSpan(text: '${e ? 'Due' : 'ค้าง'} ${_money.format(out)}'));
      if (over > 0.005) {
        meta.add(TextSpan(
            text: ' · ${e ? 'overdue' : 'เกินกำหนด'} ${_money.format(over)}', style: const TextStyle(color: ImKit.red, fontWeight: FontWeight.w600)));
      } else if (c.creditLimit > 0) {
        meta.add(TextSpan(text: ' · ${e ? 'limit' : 'วงเงิน'} ${_money.format(c.creditLimit)}'));
      }
    } else {
      meta.add(TextSpan(text: c.creditLimit > 0 ? '${e ? 'Limit' : 'วงเงิน'} ${_money.format(c.creditLimit)} · ' : ''));
      meta.add(TextSpan(text: e ? 'nothing outstanding' : 'ไม่มียอดค้าง'));
    }
    final card = ImMasterListCard(
      code: c.customerCode,
      chips: [
        if (c.customerGroupCode != null) ImKit.chip(c.customerGroupCode!, ImKit.blueSoft, ImKit.blue),
        if (over > 0.005) ImKit.chip(e ? 'Overdue' : 'เกินกำหนด', ImKit.redSoft, ImKit.red),
        if (overLimit) ImKit.chip(e ? 'Over limit' : 'เกินวงเงิน', ImKit.redSoft, ImKit.red),
        if (!c.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
      ],
      name: name,
      meta: TextSpan(children: meta),
      selected: widget.selectedId != null && widget.selectedId == c.id,
      active: c.isActive,
      onTap: () => widget.onTap(c),
    );
    if (c.creditLimit <= 0 || out <= 0.005) return card;
    // แถบวงเงินที่ใช้ไป (ยอดค้าง AR ÷ วงเงิน)
    final ratio = (out / c.creditLimit).clamp(0.0, 1.0);
    return Stack(children: [
      card,
      Positioned(
        left: 21,
        right: 21,
        bottom: 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 3,
            backgroundColor: const Color(0xFFE6EAE8),
            color: overLimit ? ImKit.red : (ratio >= 0.8 ? ImKit.gold : ImKit.ok),
          ),
        ),
      ),
    ]);
  }
}
