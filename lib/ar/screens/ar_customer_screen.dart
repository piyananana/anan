import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/ar_customer.dart';
import '../services/ar_customer_service.dart';
import '../widgets/ar_customer_list_widget.dart';
import '../widgets/ar_customer_detail_widget.dart';

class ArCustomerScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ArCustomerScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ArCustomerScreen> createState() => _ArCustomerScreenState();
}

class _ArCustomerScreenState extends State<ArCustomerScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ArCustomerListWidgetState> _listKey = GlobalKey();
  final GlobalKey<ArCustomerDetailWidgetState> _detailKey = GlobalKey();
  Mode _mode = Mode.none;
  ArCustomer? _selectedData;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selectedData = null;
      });

  void _onEdit(ArCustomer row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
    });
    _fetchFull(row);
  }

  void _onView(ArCustomer row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
    _fetchFull(row);
  }

  Future<void> _fetchFull(ArCustomer row) async {
    if (row.id == null) return;
    final svc = Provider.of<ArCustomerService>(context, listen: false);
    try {
      final full = await svc.fetchRow(row.id!);
      if (mounted) setState(() => _selectedData = full);
    } catch (_) {}
  }

  Future<void> _onDelete(ArCustomer row) async {
    final isEnglish = _isEnglish;
    final l = AppL10n(isEnglish);
    final svc = Provider.of<ArCustomerService>(context, listen: false);
    final displayName = isEnglish && (row.customerNameEn?.isNotEmpty ?? false)
        ? row.customerNameEn!
        : row.customerNameTh;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(isEnglish
            ? 'Are you sure you want to delete customer "${row.customerCode} $displayName" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบลูกหนี้ "${row.customerCode} $displayName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await svc.deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish
                  ? 'Failed to delete: ${e.toString()}'
                  : 'เกิดข้อผิดพลาดในการลบ: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _onSubmit(ArCustomer row) async {
    final isEnglish = _isEnglish;
    final svc = Provider.of<ArCustomerService>(context, listen: false);
    if (_selectedData == null) {
      await svc.addRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
      }
    } else {
      await svc.updateRow(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      }
    }
    _listKey.currentState?.refresh();
    _onCancel();
    widget.onFieldsChanged();
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
      });

  void _onCallback(ArCustomer row) => setState(() {
        _mode = Mode.none;
        _selectedData = row;
      });

  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return ArCustomerDetailWidget(
          key: _detailKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return ArCustomerDetailWidget(
          key: _detailKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return ArCustomerDetailWidget(
          key: _detailKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return ArCustomerDetailWidget(
          key: _detailKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (_) {},
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
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: () {
              _listKey.currentState?.refresh();
              _onCancel();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36,
                color: Colors.orange[700],
                child: IconButton(
                  icon: Icon(
                    _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded
                      ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                      : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                ),
              ),
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
                      child: ArCustomerListWidget(
                        key: _listKey,
                        enableAddButton: canCreate,
                        enableEditButton: canEdit,
                        enableViewButton: true,
                        enableDeleteButton: canDelete,
                        enableCardSelect: false,
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
                    onHorizontalDragStart: (_) =>
                        setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _leftPanelWidth = (_leftPanelWidth + details.delta.dx)
                            .clamp(200.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) =>
                        setState(() => _isDraggingDivider = false),
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
