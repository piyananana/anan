import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_warehouse.dart';
import '../services/im_warehouse_service.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../widgets/im_warehouse_detail_widget.dart';

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
  ImWarehouse? _selectedData;
  bool _isEnglish = false;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selectedData = null;
      });

  void _onEdit(ImWarehouse row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
      });

  void _onView(ImWarehouse row) => setState(() {
        _mode = Mode.view;
        _selectedData = row;
      });

  Future<void> _onDelete(ImWarehouse row) async {
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
      _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error deleting: $e' : 'เกิดข้อผิดพลาดในการลบ: $e')));
      }
    }
  }

  Future<void> _onSubmit(ImWarehouse row) async {
    final isEnglish = _isEnglish;
    try {
      if (_mode == Mode.add) {
        await _svc.addRow(row);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
      } else if (_mode == Mode.edit) {
        await _svc.updateRow(row);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      }
      _listKey.currentState?.refresh();
      _onCancel();
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
      });

  void _onCallback(ImWarehouse row) => setState(() {
        _mode = Mode.none;
        _selectedData = row;
      });

  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return ImWarehouseDetailWidget(key: _detailKey, mode: Mode.add, selected: null, onSubmit: _onSubmit, onCancel: _onCancel, isPlaceholder: true);
      case Mode.add:
        return ImWarehouseDetailWidget(key: _detailKey, mode: Mode.add, selected: null, onSubmit: _onSubmit, onCancel: _onCancel);
      case Mode.edit:
        return ImWarehouseDetailWidget(key: _detailKey, mode: Mode.edit, selected: _selectedData, onSubmit: _onSubmit, onCancel: _onCancel);
      case Mode.view:
        return ImWarehouseDetailWidget(key: _detailKey, mode: Mode.view, selected: _selectedData, onSubmit: (_) async {}, onCancel: _onCancel);
      default:
        return const SizedBox.shrink();
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
            onPressed: () {
              _listKey.currentState?.refresh();
              _onCancel();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36,
                color: Colors.teal[700],
                child: IconButton(
                  icon: Icon(_isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded ? (isEnglish ? 'Collapse list' : 'ย่อรายการ') : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                ),
              ),
              AnimatedContainer(
                duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    alignment: Alignment.topLeft,
                    child: ColoredBox(
                      color: Colors.blueGrey.shade100,
                      child: ImWarehouseListWidget(
                        key: _listKey,
                        enableAddButton: canCreate,
                        enableEditButton: canEdit,
                        enableViewButton: true,
                        enableDeleteButton: canDelete,
                        onAdd: _onAdd,
                        onEdit: _onEdit,
                        onView: _onView,
                        onDelete: _onDelete,
                        onCallback: _onCallback,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _leftPanelWidth = (_leftPanelWidth + details.delta.dx).clamp(200.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              Expanded(child: _buildRightPanel()),
            ],
          );
        },
      ),
    );
  }
}
