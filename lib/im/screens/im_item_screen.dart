import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_item.dart';
import '../services/im_item_service.dart';
import '../widgets/im_item_list_widget.dart';
import '../widgets/im_item_detail_widget.dart';

class ImItemScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImItemScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImItemScreen> createState() => _ImItemScreenState();
}

class _ImItemScreenState extends State<ImItemScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImItemListWidgetState> _listKey = GlobalKey();
  final GlobalKey<ImItemDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImItemService();

  Mode _mode = Mode.none;
  ImItem? _selectedData;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selectedData = null;
      });

  void _onEdit(ImItem row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
    });
    _fetchFull(row);
  }

  void _onView(ImItem row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
    _fetchFull(row);
  }

  Future<void> _fetchFull(ImItem row) async {
    if (row.id == null) return;
    try {
      final full = await _svc.fetchRow(row.id!);
      if (mounted) setState(() => _selectedData = full);
    } catch (_) {}
  }

  Future<void> _onDelete(ImItem row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete item "${row.itemCode} ${row.itemNameTh}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบสินค้า "${row.itemCode} ${row.itemNameTh}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isEnglish ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _svc.deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Error deleting: $e' : 'เกิดข้อผิดพลาดในการลบ: $e')),
        );
      }
    }
  }

  Future<void> _onSubmit(ImItem row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    try {
      if (_selectedData == null) {
        await _svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
        }
      } else {
        await _svc.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        }
      }
      _listKey.currentState?.refresh();
      _onCancel();
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
      });

  void _onCallback(ImItem row) => setState(() {
        _mode = Mode.none;
        _selectedData = row;
      });

  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return ImItemDetailWidget(key: _detailKey, mode: Mode.none, selected: null, onSubmit: _onSubmit, onCancel: _onCancel, isPlaceholder: true);
      case Mode.add:
        return ImItemDetailWidget(key: _detailKey, mode: Mode.add, selected: null, onSubmit: _onSubmit, onCancel: _onCancel);
      case Mode.edit:
        return ImItemDetailWidget(key: _detailKey, mode: Mode.edit, selected: _selectedData, onSubmit: _onSubmit, onCancel: _onCancel);
      case Mode.view:
        return ImItemDetailWidget(key: _detailKey, mode: Mode.view, selected: _selectedData, onSubmit: (_) async {}, onCancel: _onCancel);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
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
            tooltip: l.isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
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
                  tooltip: _isLeftPanelExpanded ? (l.isEnglish ? 'Collapse list' : 'ย่อรายการ') : (l.isEnglish ? 'Expand list' : 'ขยายรายการ'),
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
                      child: ImItemListWidget(
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
