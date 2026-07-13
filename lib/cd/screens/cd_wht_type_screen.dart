// lib/cd/screens/cd_wht_type_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cd_wht_type.dart';
import '../services/cd_wht_type_service.dart';
import '../widgets/cd_wht_type_list_widget.dart';
import '../widgets/cd_wht_type_detail_widget.dart';

class CdWhtTypeScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const CdWhtTypeScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<CdWhtTypeScreen> createState() => _CdWhtTypeScreenState();
}

class _CdWhtTypeScreenState extends State<CdWhtTypeScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<CdWhtTypeListWidgetState>   _listKey   = GlobalKey();
  final GlobalKey<CdWhtTypeDetailWidgetState> _detailKey = GlobalKey();

  Mode        _mode     = Mode.none;
  CdWhtType?  _selected;

  bool   _isLeftPanelExpanded = true;
  double _leftPanelWidth      = 420.0;
  bool   _isDraggingDivider   = false;

  @override
  bool get wantKeepAlive => true;

  // ── CRUD actions ──────────────────────────────────────────────────────────
  void _onAdd() => setState(() { _mode = Mode.add; _selected = null; });

  void _onEdit(CdWhtType row) => setState(() { _mode = Mode.edit; _selected = row; });

  void _onView(CdWhtType row) => setState(() { _mode = Mode.view; _selected = row; });

  Future<void> _onDelete(CdWhtType row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบ "${row.whtCode} ${row.whtName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Provider.of<CdWhtTypeService>(context, listen: false).deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
    }
  }

  Future<void> _onSubmit(CdWhtType row) async {
    try {
      final svc = Provider.of<CdWhtTypeService>(context, listen: false);
      if (_selected == null) {
        await svc.addRow(row);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เพิ่มสำเร็จ')));
      } else {
        await svc.updateRow(row);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      }
      _listKey.currentState?.refresh();
      _onCancel();
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
    }
  }

  void _onCancel() => setState(() { _mode = Mode.none; _selected = null; });

  void _onCallback(CdWhtType row) => setState(() { _mode = Mode.none; _selected = row; });

  // ── Right panel ───────────────────────────────────────────────────────────
  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return CdWhtTypeDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null,
          onSubmit: _onSubmit, onCancel: _onCancel, isPlaceholder: true,
        );
      case Mode.add:
        return CdWhtTypeDetailWidget(
          key: _detailKey, mode: Mode.add, selected: null,
          onSubmit: _onSubmit, onCancel: _onCancel,
        );
      case Mode.edit:
        return CdWhtTypeDetailWidget(
          key: _detailKey, mode: Mode.edit, selected: _selected,
          onSubmit: _onSubmit, onCancel: _onCancel,
        );
      case Mode.view:
        return CdWhtTypeDetailWidget(
          key: _detailKey, mode: Mode.view, selected: _selected,
          onSubmit: (_) {}, onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: () {
              _listKey.currentState?.refresh();
              _onCancel();
            },
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Collapse toggle
          Container(
            width: 36,
            color: Colors.teal[700],
            child: IconButton(
              icon: Icon(
                _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.white, size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
              tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
            ),
          ),
          // Left: list
          AnimatedContainer(
            duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
            width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _leftPanelWidth, minWidth: _leftPanelWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.blueGrey.shade100,
                  child: CdWhtTypeListWidget(
                    key: _listKey,
                    enableAddButton: true, enableEditButton: true,
                    enableViewButton: true, enableDeleteButton: true,
                    enableCardSelect: false,
                    onAdd: _onAdd, onEdit: _onEdit, onView: _onView,
                    onDelete: _onDelete, onCallback: _onCallback,
                  ),
                ),
              ),
            ),
          ),
          // Drag divider
          if (_isLeftPanelExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                onHorizontalDragUpdate: (d) => setState(() {
                  _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(200.0, maxLeft);
                }),
                onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          // Right: detail
          Expanded(child: _buildRightPanel()),
        ]);
      }),
    );
  }
}
