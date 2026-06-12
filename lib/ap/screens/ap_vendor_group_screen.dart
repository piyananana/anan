// lib/ap/screens/ap_vendor_group_screen.dart
import 'package:flutter/material.dart';
import '../../sa/models/anan_module.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_vendor_group_service.dart';
import '../widgets/ap_vendor_group_list_widget.dart';
import '../widgets/ap_vendor_group_detail_widget.dart';

class ApVendorGroupScreen extends StatefulWidget {
  const ApVendorGroupScreen({super.key});

  @override
  State<ApVendorGroupScreen> createState() => _ApVendorGroupScreenState();
}

class _ApVendorGroupScreenState extends State<ApVendorGroupScreen>
    with AutomaticKeepAliveClientMixin {
  final _listKey   = GlobalKey<ApVendorGroupListWidgetState>();
  final _detailKey = GlobalKey<ApVendorGroupDetailWidgetState>();

  Mode _mode = Mode.none;
  ApVendorGroup? _selected;
  bool _isLeftExpanded = true;
  double _leftWidth = 400;
  bool _isDragging = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() { _mode = Mode.add; _selected = null; });

  Future<void> _onEdit(ApVendorGroup row) async {
    setState(() { _mode = Mode.edit; _selected = row; });
    try {
      final full = await ApVendorGroupService().fetchRow(row.id!);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  Future<void> _onView(ApVendorGroup row) async {
    setState(() { _mode = Mode.view; _selected = row; });
    try {
      final full = await ApVendorGroupService().fetchRow(row.id!);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  Future<void> _onDelete(ApVendorGroup row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบ "${row.groupCode} (${row.groupNameThai})" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApVendorGroupService().deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _onSubmit(ApVendorGroup row) async {
    final svc = ApVendorGroupService();
    if (_selected == null) {
      await svc.addRow(row);
    } else {
      await svc.updateRow(row);
    }
    _listKey.currentState?.refresh();
    _onCancel();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
  }

  void _onCancel() => setState(() { _mode = Mode.none; _selected = null; });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.group, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('กลุ่มผู้ขาย'),
        ]),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () { _listKey.currentState?.refresh(); _onCancel(); },
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Collapse button
          Container(
            width: 36,
            color: Colors.blue[700],
            child: IconButton(
              icon: Icon(_isLeftExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
              tooltip: _isLeftExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
            ),
          ),
          // Left panel
          AnimatedContainer(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
            width: _isLeftExpanded ? _leftWidth : 0,
            child: ClipRect(child: OverflowBox(
              maxWidth: _leftWidth, minWidth: _leftWidth, alignment: Alignment.topLeft,
              child: ColoredBox(
                color: Colors.blueGrey.shade100,
                child: ApVendorGroupListWidget(
                  key: _listKey,
                  enableAddButton: true, enableEditButton: true,
                  enableViewButton: true, enableDeleteButton: true,
                  enableSortButton: true, enableCardSelect: false,
                  onAdd: _onAdd, onEdit: _onEdit, onView: _onView, onDelete: _onDelete,
                  onCallback: (row) => setState(() { _mode = Mode.none; _selected = row; }),
                ),
              ),
            )),
          ),
          // Divider
          if (_isLeftExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragUpdate: (d) => setState(() => _leftWidth = (_leftWidth + d.delta.dx).clamp(200.0, maxLeft)),
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          // Right panel
          Expanded(child: _buildDetail()),
        ]);
      }),
    );
  }

  Widget _buildDetail() {
    switch (_mode) {
      case Mode.add:
        return ApVendorGroupDetailWidget(key: _detailKey, mode: Mode.add, selected: null, onSubmit: _onSubmit, onCancel: _onCancel);
      case Mode.edit:
        return ApVendorGroupDetailWidget(key: _detailKey, mode: Mode.edit, selected: _selected, onSubmit: _onSubmit, onCancel: _onCancel);
      case Mode.view:
        return ApVendorGroupDetailWidget(key: _detailKey, mode: Mode.view, selected: _selected, onSubmit: (_) async {}, onCancel: _onCancel);
      default:
        return ApVendorGroupDetailWidget(key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _onCancel, isPlaceholder: true);
    }
  }
}
