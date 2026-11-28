import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_warehouse.dart';
import '../services/im_warehouse_service.dart';
import '../widgets/im_master_kit.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../widgets/im_warehouse_detail_widget.dart';

// หน้าจอคลังสินค้า — แบบ B (user 2026-11-25): ซ้ายการ์ด / ขวารายละเอียด; คลิกการ์ด = ดู, ปุ่มแก้ไข/ลบที่แถบหัว,
// บันทึกแล้วแสดงรายการนั้นต่อ, มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยนรายการ
class ImWarehouseScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImWarehouseScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImWarehouseScreen> createState() => _ImWarehouseScreenState();
}

class _ImWarehouseScreenState extends State<ImWarehouseScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImWarehouseListWidgetState> _listKey = GlobalKey();
  final GlobalKey<ImWarehouseDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImWarehouseService();

  Mode _mode = Mode.none;
  ImWarehouse? _selected;
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

  void _set(Mode m, ImWarehouse? row) => setState(() {
        _mode = m;
        _selected = row;
        _requestSeq++;
      });

  Future<void> _onAdd() async {
    if (await _confirmLeave()) _set(Mode.add, null);
  }

  Future<void> _onView(ImWarehouse row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (await _confirmLeave()) _set(Mode.view, row);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _set(Mode.view, _selected);
    } else {
      _set(Mode.none, null);
    }
  }

  Future<void> _onDelete() async {
    final row = _selected;
    if (row == null) return;
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete warehouse "${row.warehouseCode} ${row.warehouseNameTh}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบคลังสินค้า "${row.warehouseCode} ${row.warehouseNameTh}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isEnglish ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.deleteRow(row.id);
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

  Future<void> _onSubmit(ImWarehouse row) async {
    final isEnglish = _isEnglish;
    try {
      final saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_mode == Mode.add ? (isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ') : (isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
      }
      _listKey.currentState?.refresh();
      widget.onFieldsChanged();
      if (mounted) _set(Mode.view, saved);
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
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add warehouse' : 'เพิ่มคลังสินค้า', Icons.add, _onAdd, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            _listKey.currentState?.refresh();
            _set(_selected != null && _mode != Mode.add ? Mode.view : Mode.none, _mode == Mode.add ? null : _selected);
          },
        ),
      ],
      list: ImWarehouseListWidget(
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
      detail: ImWarehouseDetailWidget(
        key: _detailKey,
        mode: _mode,
        selected: _mode == Mode.add ? null : _selected,
        isPlaceholder: _mode == Mode.none,
        onSubmit: _onSubmit,
        onCancel: view ? () => _set(Mode.none, null) : _onCancel,
        onEdit: view && canEdit ? () => _set(Mode.edit, _selected) : null,
        onDelete: view && canDelete ? _onDelete : null,
        requestSeq: _requestSeq,
      ),
    );
  }
}
