// screens/ar_customer_group_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_customer_group_service.dart';
import '../widgets/ar_customer_group_list_widget.dart';
import '../widgets/ar_customer_group_detail_widget.dart';

class ArCustomerGroupScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ArCustomerGroupScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ArCustomerGroupScreen> createState() => _ArCustomerGroupScreenState();
}

class _ArCustomerGroupScreenState extends State<ArCustomerGroupScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ArCustomerGroupListWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<ArCustomerGroupDetailWidgetState> _detailWidgetKey =
      GlobalKey();

  Mode _mode = Mode.none;
  ArCustomerGroup? _selectedData;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — ส่งให้ ArCustomerGroupDetailWidget เพื่อบังคับเคลียร์ฟอร์มเสมอ
  // แม้ mode/selected จะซ้ำกับครั้งก่อน (เช่น กด "เพิ่มกลุ่มลูกค้า" ซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  int _requestSeq = 0;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 400.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() {
    setState(() {
      _mode = Mode.add;
      _selectedData = null;
      _requestSeq++;
    });
  }

  Future<void> _onEdit(ArCustomerGroup row) async {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row; // show immediately, then replace with full data
      _requestSeq++;
    });
    try {
      final full = await Provider.of<ArCustomerGroupService>(context, listen: false)
          .fetchRow(row.id!);
      if (mounted) setState(() => _selectedData = full);
    } catch (_) {}
  }

  Future<void> _onView(ArCustomerGroup row) async {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
      _requestSeq++;
    });
    try {
      final full = await Provider.of<ArCustomerGroupService>(context, listen: false)
          .fetchRow(row.id!);
      if (mounted) setState(() => _selectedData = full);
    } catch (_) {}
  }

  Future<void> _onDelete(ArCustomerGroup row) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(l.isEnglish
            ? 'Delete "${row.groupCode} (${row.groupNameEng.isNotEmpty ? row.groupNameEng : row.groupNameThai})"?'
            : 'คุณแน่ใจหรือไม่ที่จะลบ "${row.groupCode} (${row.groupNameThai})" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Provider.of<ArCustomerGroupService>(context, listen: false)
            .deleteRow(row.id!);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.deletedSuccess)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l.isEnglish
                    ? 'Delete failed: ${e.toString()}'
                    : 'เกิดข้อผิดพลาดในการลบ: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _onSubmit(ArCustomerGroup row) async {
    final isEnglish =
        Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    try {
      final service =
          Provider.of<ArCustomerGroupService>(context, listen: false);
      if (_selectedData == null) {
        await service.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
        }
      } else {
        await service.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        }
      }
      _listWidgetKey.currentState?.refresh();
      _onCancel();
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish
                  ? 'Error saving: ${e.toString()}'
                  : 'เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')),
        );
      }
    }
  }

  void _onCancel() {
    setState(() {
      _mode = Mode.none;
      _selectedData = null;
      _requestSeq++;
    });
  }

  void _onCallback(ArCustomerGroup row) {
    setState(() {
      _mode = Mode.none;
      _selectedData = row;
      _requestSeq++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    super.build(context);
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: () {
              _listWidgetKey.currentState?.refresh();
              _onCancel();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300)
                  .clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ปุ่ม collapse
              Container(
                width: 36,
                color: Colors.teal[700],
                child: IconButton(
                  icon: Icon(
                    _isLeftPanelExpanded
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(
                      () => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded
                      ? (l.isEnglish ? 'Collapse list' : 'ย่อรายการ')
                      : (l.isEnglish ? 'Expand list' : 'ขยายรายการ'),
                ),
              ),
              // Left panel (list)
              AnimatedContainer(
                duration: _isDraggingDivider
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    alignment: Alignment.topLeft,
                    child: ColoredBox(
                      color: Colors.blueGrey.shade100,
                      child: Column(
                        children: [
                          Expanded(
                            child: ArCustomerGroupListWidget(
                              key: _listWidgetKey,
                              enableAddButton: canCreate,
                              enableEditButton: canEdit,
                              enableViewButton: true,
                              enableDeleteButton: canDelete,
                              enableSortButton: true,
                              enableCardSelect: false,
                              onAdd: _onAdd,
                              onEdit: _onEdit,
                              onView: _onView,
                              onDelete: _onDelete,
                              onCallback: _onCallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Divider
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) =>
                        setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _leftPanelWidth =
                            (_leftPanelWidth + details.delta.dx)
                                .clamp(200.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) =>
                        setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              // Right panel (detail)
              Expanded(child: _buildRightPanel()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return ArCustomerGroupDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
          requestSeq: _requestSeq,
        );
      case Mode.add:
        return ArCustomerGroupDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.edit:
        return ArCustomerGroupDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.view:
        return ArCustomerGroupDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (_) {},
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
