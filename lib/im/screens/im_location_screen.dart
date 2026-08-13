import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_location.dart';
import '../models/im_warehouse.dart';
import '../services/im_location_service.dart';
import '../services/im_warehouse_service.dart';
import '../widgets/im_location_tree_widget.dart';
import '../widgets/im_location_detail_widget.dart';

class ImLocationScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;
  final int? initialWarehouseId;

  const ImLocationScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
    this.initialWarehouseId,
  });

  @override
  State<ImLocationScreen> createState() => _ImLocationScreenState();
}

class _ImLocationScreenState extends State<ImLocationScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImLocationTreeWidgetState> _listKey = GlobalKey();
  final _svc = ImLocationService();

  Mode _mode = Mode.none;
  ImLocation? _selectedData;

  List<ImWarehouse> _warehouses = [];
  int? _selectedWarehouseId;
  bool _isLoadingWarehouses = true;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final list = await ImWarehouseService().fetchActiveRows();
      if (!mounted) return;
      setState(() {
        _warehouses = list;
        _selectedWarehouseId = widget.initialWarehouseId != null &&
                list.any((w) => w.id == widget.initialWarehouseId)
            ? widget.initialWarehouseId
            : (list.isNotEmpty ? list.first.id : null);
        _isLoadingWarehouses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingWarehouses = false);
    }
  }

  void _onAddRoot() => setState(() {
        _mode = Mode.addRoot;
        _selectedData = null;
      });

  void _onAddChild(ImLocation parent) => setState(() {
        _mode = Mode.addChild;
        _selectedData = parent;
      });

  void _onEdit(ImLocation row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
      });

  void _onView(ImLocation row) => setState(() {
        _mode = Mode.view;
        _selectedData = row;
      });

  Future<void> _onDelete(ImLocation row) async {
    final isEnglish = _isEnglish;
    final l = AppL10n(isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete location "${row.locationCode}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบตำแหน่ง "${row.locationCode}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Error deleting: $e' : 'เกิดข้อผิดพลาดในการลบ: $e')),
        );
      }
    }
  }

  Future<void> _onSubmit(ImLocation row) async {
    final isEnglish = _isEnglish;
    try {
      if (_mode == Mode.addRoot || _mode == Mode.addChild) {
        await _svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
        }
      } else if (_mode == Mode.edit) {
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

  void _onCallback(ImLocation row) => setState(() {
        _mode = Mode.none;
        _selectedData = row;
      });

  Widget _buildRightPanel() {
    if (_selectedWarehouseId == null) {
      return Center(
        child: Text(
          _isEnglish ? 'Select a warehouse first' : 'กรุณาเลือกคลังสินค้าก่อน',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    final warehouseId = _selectedWarehouseId!;
    switch (_mode) {
      case Mode.none:
        return ImLocationDetailWidget(
          mode: Mode.addRoot,
          selected: null,
          warehouseId: warehouseId,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.addRoot:
        return ImLocationDetailWidget(
          mode: Mode.addRoot,
          selected: null,
          warehouseId: warehouseId,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.addChild:
        return ImLocationDetailWidget(
          mode: Mode.addChild,
          selected: _selectedData,
          warehouseId: warehouseId,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return ImLocationDetailWidget(
          mode: Mode.edit,
          selected: _selectedData,
          warehouseId: warehouseId,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return ImLocationDetailWidget(
          mode: Mode.view,
          selected: _selectedData,
          warehouseId: warehouseId,
          onSubmit: (_) async {},
          onCancel: _onCancel,
        );
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
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: _isLoadingWarehouses
                              ? const LinearProgressIndicator()
                              : DropdownButtonFormField<int>(
                                  value: _selectedWarehouseId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: isEnglish ? 'Warehouse' : 'คลังสินค้า',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: _warehouses
                                      .map((w) => DropdownMenuItem(
                                            value: w.id,
                                            child: Text('${w.warehouseCode} — ${w.warehouseNameTh}', overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _selectedWarehouseId = v;
                                    _onCancel();
                                  }),
                                ),
                        ),
                        Expanded(
                          child: _selectedWarehouseId == null
                              ? Center(
                                  child: Text(
                                    isEnglish ? 'No warehouses found' : 'ไม่พบคลังสินค้า',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ImLocationTreeWidget(
                                  key: _listKey,
                                  warehouseId: _selectedWarehouseId!,
                                  enableAddRootButton: canCreate,
                                  enableAddChildButton: canCreate,
                                  enableEditButton: canEdit,
                                  enableViewButton: true,
                                  enableDeleteButton: canDelete,
                                  enableCardSelect: false,
                                  onAddRoot: _onAddRoot,
                                  onAddChild: _onAddChild,
                                  onEdit: _onEdit,
                                  onView: _onView,
                                  onDelete: _onDelete,
                                  onCallback: _onCallback,
                                ),
                        ),
                      ]),
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
