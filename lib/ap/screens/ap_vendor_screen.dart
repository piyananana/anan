import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../cd/services/cd_currency_service.dart';
import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../models/ap_vendor_summary.dart';
import '../services/ap_vendor_group_service.dart';
import '../services/ap_vendor_service.dart';
import '../widgets/ap_vendor_detail_widget.dart';

// หน้าจอข้อมูลผู้ขาย — แบบ B ของ IM (user 2026-11-28, เหมือนหน้าลูกค้า AR)
//   ซ้าย: การ์ดผู้ขาย + ยอดค้างจ่าย/เกินกำหนด/มัดจำ, ตัวกรอง กลุ่ม / เกินกำหนด / มีมัดจำค้าง / ไม่มีบัญชีธนาคาร / หยุดใช้
//   ขวา: เปิดมาเป็นโหมดดู → แก้ไข / สำเนาเป็นผู้ขายใหม่ / ลบ ที่แถบหัว; มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยนผู้ขาย
//   ปุ่มย่อ/ขยายรายการอยู่หน้าชื่อบนแถบหัวแผงขวา (ImListToggle ผ่าน ImMasterShell)
class ApVendorScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ApVendorScreen({super.key, required this.onFieldsChanged, this.onExit});

  @override
  State<ApVendorScreen> createState() => _ApVendorScreenState();
}

class _ApVendorScreenState extends State<ApVendorScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_ApVendorMasterListState> _listKey = GlobalKey();
  final GlobalKey<ApVendorDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  ApVendor? _selected;
  ApVendor? _copyFrom;
  bool _fullLoaded = false;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  int _requestSeq = 0;

  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  final _svc = ApVendorService();

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

  Future<void> _onView(ApVendor row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(ApVendor row) {
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
  Future<void> _fetchFull(ApVendor row) async {
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
    final name = isEnglish && (row!.vendorNameEn?.isNotEmpty ?? false) ? row.vendorNameEn! : row!.vendorNameTh;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(isEnglish
            ? 'Are you sure you want to delete vendor "${row.vendorCode} $name" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบผู้ขาย "${row.vendorCode} $name" ?'),
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

  // บันทึกแล้วแสดงผู้ขายนั้นต่อ (ไม่ปิดแผงขวา)
  Future<void> _onSubmit(ApVendor row) async {
    final isEnglish = _isEnglish;
    try {
      final ApVendor saved;
      if (_mode == Mode.add) {
        saved = await _svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEnglish ? 'Added ${saved.vendorCode}' : 'เพิ่มผู้ขาย ${saved.vendorCode} สำเร็จ')));
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

  // ยกเลิก: แก้ไข → กลับไปดูผู้ขายเดิม, สำเนา → กลับไปดูต้นฉบับ, อื่นๆ → ปิดแผงขวา
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
      return ApVendorDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return ApVendorDetailWidget(
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
              () => ImKit.openMenu(context, 'ApVendorImportScreen', 'นำเข้าข้อมูลผู้ขาย', 'Vendor Import', isEnglish)),
        if (!narrow)
          ImKit.barButton(context, isEnglish ? 'Vendor report' : 'พิมพ์รายงานผู้ขาย', Icons.print_outlined,
              () => ImKit.openMenu(context, 'ApVendorReportScreen', 'รายงานข้อมูลผู้ขาย', 'Vendor Report', isEnglish)),
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add vendor' : 'เพิ่มผู้ขาย', Icons.add, _onAdd, primary: true),
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
      list: _ApVendorMasterList(
        key: _listKey,
        selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null,
        onTap: _onView,
      ),
      detail: _detail(canCreate, canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการผู้ขาย (แผงซ้าย)
// ---------------------------------------------------------------------------
class _ApVendorMasterList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<ApVendor> onTap;
  const _ApVendorMasterList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_ApVendorMasterList> createState() => _ApVendorMasterListState();
}

enum _Flag { overdue, deposit, noBank, inactive }

class _ApVendorMasterListState extends State<_ApVendorMasterList> {
  final _search = TextEditingController();
  final _money = NumberFormat('#,##0.00');
  List<ApVendor> _rows = [];
  Map<int, ApVendorBalance> _bal = {};
  List<ApVendorGroup> _groups = [];
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
    final svc = ApVendorService();
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
      final g = await ApVendorGroupService().fetchRows();
      if (mounted) setState(() => _groups = g);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  ApVendorBalance? _b(ApVendor v) => v.id == null ? null : _bal[v.id];
  bool _isOverdue(ApVendor v) => (_b(v)?.overdue ?? 0) > 0.005;
  bool _hasDeposit(ApVendor v) => (_b(v)?.deposit ?? 0) > 0.005;
  // ยังโหลดยอดไม่ได้ = ไม่รู้ → ไม่นับเป็น "ไม่มีบัญชีธนาคาร"
  bool _noBank(ApVendor v) => _bal.isNotEmpty && (_b(v)?.bankAccountCount ?? 0) == 0;

  bool _match(ApVendor v, String q) {
    if (q.isEmpty) return true;
    return v.vendorCode.toLowerCase().contains(q) ||
        v.vendorNameTh.toLowerCase().contains(q) ||
        (v.vendorNameEn?.toLowerCase().contains(q) ?? false) ||
        (v.taxId?.toLowerCase().contains(q) ?? false) ||
        (v.oldVendorCode?.toLowerCase().contains(q) ?? false);
  }

  bool _flagOk(ApVendor v, _Flag? f) => switch (f) {
        null => true,
        _Flag.overdue => _isOverdue(v),
        _Flag.deposit => _hasDeposit(v),
        _Flag.noBank => _noBank(v),
        _Flag.inactive => !v.isActive,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows.where((v) => _match(v, q) && (_groupId == null || '${v.vendorGroupId}' == _groupId)).toList();
    final shown = base.where((v) => _flagOk(v, _flag)).toList()..sort((a, b) => a.vendorCode.compareTo(b.vendorCode));
    int n(_Flag f) => base.where((v) => _flagOk(v, f)).length;
    void flag(_Flag f) => setState(() => _flag = _flag == f ? null : f);
    final grp = _groups.where((g) => '${g.id}' == _groupId).firstOrNull;
    String gName(ApVendorGroup g) => e && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name / tax ID / old code' : 'ค้นหา รหัส / ชื่อ / เลขผู้เสียภาษี / รหัสเดิม',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length
                ? (e ? '${_rows.length} vendors' : 'ทั้งหมด ${_rows.length} ราย')
                : (e ? '${shown.length} of ${_rows.length} vendors' : '${shown.length} จาก ${_rows.length} ราย')),
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
          ImMasterFilterChip(label: '${e ? 'Open deposit' : 'มีมัดจำค้าง'} ${n(_Flag.deposit)}', on: _flag == _Flag.deposit, onTap: () => flag(_Flag.deposit)),
          ImMasterFilterChip(label: '${e ? 'No bank account' : 'ไม่มีบัญชีธนาคาร'} ${n(_Flag.noBank)}', on: _flag == _Flag.noBank, onTap: () => flag(_Flag.noBank), fg: ImKit.amber),
          ImMasterFilterChip(label: '${e ? 'Inactive' : 'หยุดใช้'} ${n(_Flag.inactive)}', on: _flag == _Flag.inactive, onTap: () => flag(_Flag.inactive)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No vendors found' : 'ไม่พบข้อมูลผู้ขาย', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _card(shown[i], e),
                  ),
      ),
    ]);
  }

  Widget _card(ApVendor v, bool e) {
    final b = _b(v);
    final name = e && (v.vendorNameEn?.isNotEmpty ?? false) ? v.vendorNameEn! : v.vendorNameTh;
    final out = b?.outstanding ?? 0;
    final over = b?.overdue ?? 0;
    final dep = b?.deposit ?? 0;
    final meta = <InlineSpan>[];
    if (out > 0.005) {
      meta.add(TextSpan(text: '${e ? 'Payable' : 'ค้างจ่าย'} ${_money.format(out)}'));
      if (over > 0.005) {
        meta.add(TextSpan(
            text: ' · ${e ? 'overdue' : 'เกินกำหนด'} ${_money.format(over)}', style: const TextStyle(color: ImKit.red, fontWeight: FontWeight.w600)));
      }
    } else {
      meta.add(TextSpan(text: e ? 'nothing payable' : 'ไม่มียอดค้าง'));
    }
    if (dep > 0.005) meta.add(TextSpan(text: ' · ${e ? 'deposit' : 'มัดจำ'} ${_money.format(dep)}'));
    final foreign = v.currencyCode.isNotEmpty && v.currencyCode != CurrencyService.baseCode;
    return ImMasterListCard(
      code: v.vendorCode,
      chips: [
        if (v.vendorGroupCode != null) ImKit.chip(v.vendorGroupCode!, ImKit.blueSoft, ImKit.blue),
        if (foreign) ImKit.chip(v.currencyCode, ImKit.ro, ImKit.ink2),
        if (over > 0.005) ImKit.chip(e ? 'Overdue' : 'เกินกำหนด', ImKit.redSoft, ImKit.red),
        if (_noBank(v) && v.isActive) ImKit.chip(e ? 'No bank' : 'ไม่มีบัญชีธนาคาร', ImKit.goldSoft, ImKit.amber),
        if (!v.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
      ],
      name: name,
      meta: TextSpan(children: meta),
      selected: widget.selectedId != null && widget.selectedId == v.id,
      active: v.isActive,
      onTap: () => widget.onTap(v),
    );
  }
}
