// lib/cm/screens/cm_payment_method_screen.dart — ประเภทการชำระเงิน แบบ B ของ IM (user 2026-11-28)
//   ซ้าย: การ์ดประเภท (ประเภท บัญชี GL ที่ใช้ จำนวนผู้ขายที่ใช้) + ตัวกรอง / ขวา: โหมดดู → แก้ไข / สำเนา / ลบ ที่แถบหัว
//   ปุ่มย่อ/ขยายรายการอยู่หน้าชื่อบนแถบหัวแผงขวา (ImListToggle ผ่าน ImMasterShell)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/cm_payment_method.dart';
import '../services/cm_payment_method_service.dart';
import '../widgets/cm_payment_method_detail_widget.dart';

class CmPaymentMethodScreen extends StatefulWidget {
  final VoidCallback? onFieldsChanged;
  const CmPaymentMethodScreen({super.key, this.onFieldsChanged});

  @override
  State<CmPaymentMethodScreen> createState() => _CmPaymentMethodScreenState();
}

class _CmPaymentMethodScreenState extends State<CmPaymentMethodScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_MethodListState> _listKey = GlobalKey();
  final GlobalKey<CmPaymentMethodDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  CmPaymentMethod? _selected;
  CmPaymentMethod? _copyFrom;
  int _requestSeq = 0;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  final _svc = CmPaymentMethodService();

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

  Future<void> _onView(CmPaymentMethod row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(CmPaymentMethod row) => setState(() {
        _mode = Mode.view;
        _selected = row;
        _copyFrom = null;
        _requestSeq++;
      });

  Future<void> _onDelete() async {
    final row = _selected;
    if (row?.id == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Delete payment method "${row!.methodCode} ${row.name(e)}"?' : 'ลบประเภทการชำระเงิน "${row!.methodCode} ${row.name(e)}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row!.id!);
      _listKey.currentState?.refresh();
      _close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Delete failed: $ex' : 'ลบล้มเหลว: $ex'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(CmPaymentMethod row) async {
    final e = _isEnglish;
    final CmPaymentMethod saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_mode == Mode.add ? (e ? 'Added ${saved.methodCode}' : 'เพิ่ม ${saved.methodCode} สำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
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
      return CmPaymentMethodDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return CmPaymentMethodDetailWidget(
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
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add method' : 'เพิ่มประเภท', Icons.add, _onAdd, primary: true),
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
      list: _MethodList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _detail(canCreate, canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการประเภทการชำระเงิน (แผงซ้าย)
// ---------------------------------------------------------------------------
class _MethodList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<CmPaymentMethod> onTap;
  const _MethodList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_MethodList> createState() => _MethodListState();
}

class _MethodListState extends State<_MethodList> {
  final _search = TextEditingController();
  List<CmPaymentMethod> _rows = [];
  Map<int, int> _usage = {};
  String? _type;
  bool _ownGl = false;
  bool _inactive = false;
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

  Future<List<CmPaymentMethod>?> refresh() async {
    setState(() => _loading = true);
    List<CmPaymentMethod>? out;
    final svc = CmPaymentMethodService();
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

  Color _typeFg(String t) => switch (t) {
        'CHECK' => const Color(0xFF5B3B9A),
        'TRANSFER' || 'MOBILE_BANKING' || 'QR_CODE' => ImKit.blue,
        'BILL_OF_EXCHANGE' => ImKit.amber,
        _ => ImKit.ink2,
      };
  Color _typeBg(String t) => switch (t) {
        'CHECK' => const Color(0xFFEFE8FB),
        'TRANSFER' || 'MOBILE_BANKING' || 'QR_CODE' => ImKit.blueSoft,
        'BILL_OF_EXCHANGE' => ImKit.goldSoft,
        _ => ImKit.ro,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows
        .where((m) =>
            q.isEmpty ||
            m.methodCode.toLowerCase().contains(q) ||
            m.methodNameTh.toLowerCase().contains(q) ||
            (m.methodNameEn ?? '').toLowerCase().contains(q))
        .toList();
    final shown = base
        .where((m) => (_type == null || m.methodType == _type) && (!_ownGl || m.glAccountId != null) && (!_inactive || !m.isActive))
        .toList()
      ..sort((a, b) => a.methodCode.compareTo(b.methodCode));
    final types = {for (final m in _rows) m.methodType}.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length
                ? (e ? '${_rows.length} methods' : 'ทั้งหมด ${_rows.length} ประเภท')
                : (e ? '${shown.length} of ${_rows.length} methods' : '${shown.length} จาก ${_rows.length} ประเภท')),
        filters: [
          ImMasterFilterChip(
              label: e ? 'All' : 'ทั้งหมด',
              on: _type == null && !_ownGl && !_inactive,
              onTap: () => setState(() {
                    _type = null;
                    _ownGl = false;
                    _inactive = false;
                  })),
          ImMasterPopupFilter(
            label: e ? 'Type' : 'ประเภท',
            value: _type,
            valueLabel: _type == null ? null : cmMethodTypeLabel(_type!, e).split(' (').first,
            options: [for (final t in types) (t, cmMethodTypeLabel(t, e))],
            allLabel: e ? 'All types' : 'ทุกประเภท',
            onChanged: (v) => setState(() => _type = v),
          ),
          ImMasterFilterChip(
              label: '${e ? 'Own GL account' : 'ตั้งบัญชี GL เอง'} ${base.where((m) => m.glAccountId != null).length}',
              on: _ownGl,
              onTap: () => setState(() => _ownGl = !_ownGl)),
          ImMasterFilterChip(
              label: '${e ? 'Inactive' : 'หยุดใช้'} ${base.where((m) => !m.isActive).length}',
              on: _inactive,
              onTap: () => setState(() => _inactive = !_inactive)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No payment methods found' : 'ไม่พบประเภทการชำระเงิน', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final m = shown[i];
                      final n = m.id == null ? 0 : (_usage[m.id] ?? 0);
                      final gl = m.glAccountId != null
                          ? 'GL ${m.glAccountCode ?? ''} ${m.glName(e)}'.trim()
                          : (e ? 'GL by bank account' : 'GL ตามบัญชีธนาคาร');
                      return ImMasterListCard(
                        code: m.methodCode,
                        chips: [
                          ImKit.chip(cmMethodTypeLabel(m.methodType, e).split(' (').first, _typeBg(m.methodType), _typeFg(m.methodType)),
                          if (!m.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: m.name(e),
                        meta: TextSpan(text: [gl, if (n > 0) (e ? '$n vendor(s)' : 'ผู้ขาย $n ราย')].join(' · ')),
                        selected: widget.selectedId != null && widget.selectedId == m.id,
                        active: m.isActive,
                        onTap: () => widget.onTap(m),
                      );
                    },
                  ),
      ),
    ]);
  }
}
