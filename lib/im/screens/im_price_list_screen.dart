import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_price_list.dart';
import '../services/im_price_list_service.dart';
import '../widgets/im_master_kit.dart';
import '../widgets/im_price_list_list_widget.dart';
import '../widgets/im_price_list_detail_widget.dart';

// หน้าจอตารางราคา — แบบ B (user 2026-11-25): ซ้ายการ์ด / ขวารายละเอียด; คลิกการ์ด = ดู (โหลดรายการราคาเต็มก่อนแก้ไขได้),
// ปุ่มแก้ไข/ลบที่แถบหัว, บันทึกแล้วแสดงตารางนั้นต่อ, มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยนรายการ
class ImPriceListScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImPriceListScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImPriceListScreen> createState() => _ImPriceListScreenState();
}

class _ImPriceListScreenState extends State<ImPriceListScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImPriceListListWidgetState> _listKey = GlobalKey();
  final GlobalKey<ImPriceListDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImPriceListService();

  Mode _mode = Mode.none;
  ImPriceListHeader? _selected;
  bool _fullLoaded = false;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — บังคับให้ฟอร์มเคลียร์เสมอแม้ mode/selected ซ้ำ
  int _requestSeq = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  void _set(Mode m, ImPriceListHeader? row, {bool full = false}) => setState(() {
        _mode = m;
        _selected = row;
        _fullLoaded = full;
        _requestSeq++;
      });

  void _show(ImPriceListHeader row) {
    _set(Mode.view, row);
    _fetchFull(row);
  }

  Future<void> _fetchFull(ImPriceListHeader row) async {
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

  Future<void> _onAdd() async {
    if (await _confirmLeave()) _set(Mode.add, null);
  }

  Future<void> _onView(ImPriceListHeader row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (await _confirmLeave()) _show(row);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _show(_selected!);
    } else {
      _set(Mode.none, null);
    }
  }

  Future<void> _onDelete() async {
    final row = _selected;
    if (row?.id == null) return;
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete price list "${row!.priceListCode} ${row.priceListName}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบตารางราคา "${row!.priceListCode} ${row.priceListName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isEnglish ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.deleteRow(row!.id!);
      _listKey.currentState?.refresh();
      _set(Mode.none, null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error deleting: $e' : 'เกิดข้อผิดพลาดในการลบ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(ImPriceListHeader row) async {
    final isEnglish = _isEnglish;
    try {
      final saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_mode == Mode.add ? (isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ') : (isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
      }
      _listKey.currentState?.refresh();
      widget.onFieldsChanged();
      if (mounted) _set(Mode.view, saved, full: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final view = _mode == Mode.view;
    return ImMasterShell(
      isEnglish: isEnglish,
      barActions: [
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add price list' : 'เพิ่มตารางราคา', Icons.add, _onAdd, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            _listKey.currentState?.refresh();
            if (_selected != null && _mode != Mode.add) {
              _show(_selected!);
            } else {
              _set(Mode.none, null);
            }
          },
        ),
      ],
      list: ImPriceListListWidget(
        key: _listKey,
        enableAddButton: false,
        enableEditButton: false,
        enableViewButton: true,
        enableDeleteButton: false,
        selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null,
        onAdd: _onAdd,
        onEdit: _onView,
        onView: _onView,
        onDelete: (_) {},
        onCallback: _onView,
      ),
      detail: ImPriceListDetailWidget(
        key: _detailKey,
        mode: _mode,
        selected: _mode == Mode.add ? null : _selected,
        isPlaceholder: _mode == Mode.none,
        onSubmit: _onSubmit,
        onCancel: view ? () => _set(Mode.none, null) : _onCancel,
        onEdit: view && canEdit ? (_fullLoaded ? () => _set(Mode.edit, _selected, full: true) : null) : null,
        onDelete: view && canDelete ? _onDelete : null,
        requestSeq: _requestSeq,
      ),
    );
  }
}
