// lib/cd/screens/cd_sales_territory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/cd_sales_territory.dart';
import '../services/cd_sales_territory_service.dart';
import '../widgets/cd_sales_territory_list_widget.dart';
import '../widgets/cd_sales_territory_detail_widget.dart';

class SalesTerritoryScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const SalesTerritoryScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<SalesTerritoryScreen> createState() => _SalesTerritoryScreenState();
}

class _SalesTerritoryScreenState extends State<SalesTerritoryScreen>
    with AutomaticKeepAliveClientMixin {
  final _listKey = GlobalKey<SalesTerritoryListWidgetState>();
  final _detailKey = GlobalKey<SalesTerritoryDetailWidgetState>();

  Mode _mode = Mode.none;
  SalesTerritory? _selected;
  SalesTerritory? _parentForAdd; // pre-fill parent when adding child

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 400.0;
  bool _isDragging = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selected = null;
        _parentForAdd = null;
      });

  void _onAddChild(SalesTerritory parent) => setState(() {
        _mode = Mode.add;
        // Pass a template with parentId pre-filled so detail widget picks it up
        _selected = SalesTerritory(
          territoryCode: '',
          territoryNameThai: '',
          parentId: parent.id,
          parentNameThai: parent.territoryNameThai,
        );
        _parentForAdd = parent;
      });

  void _onEdit(SalesTerritory row) => setState(() {
        _mode = Mode.edit;
        _selected = row;
      });

  void _onView(SalesTerritory row) => setState(() {
        _mode = Mode.view;
        _selected = row;
      });

  Future<void> _onDelete(SalesTerritory row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    final displayName = (isEnglish && (row.territoryNameEng?.isNotEmpty ?? false))
        ? row.territoryNameEng!
        : row.territoryNameThai;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(
            '${isEnglish ? 'Delete' : 'ลบ'} "${row.territoryCode} ($displayName)" ${isEnglish ? '?' : 'ใช่หรือไม่?'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Provider.of<SalesTerritoryService>(context, listen: false)
          .deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.deletedSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${isEnglish ? 'Delete failed' : 'ลบล้มเหลว'}: $e')));
      }
    }
  }

  Future<void> _onSubmit(SalesTerritory row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    try {
      final svc =
          Provider.of<SalesTerritoryService>(context, listen: false);
      if (_mode == Mode.add) {
        await svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
        }
      } else {
        await svc.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.savedSuccess)));
        }
      }
      _listKey.currentState?.refresh();
      setState(() {
        _mode = Mode.none;
        _selected = null;
        _parentForAdd = null;
      });
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${isEnglish ? 'An error occurred' : 'เกิดข้อผิดพลาด'}: $e')));
      }
    }
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selected = null;
        _parentForAdd = null;
      });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final l = AppL10n(isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.refresh,
            onPressed: () {
              _listKey.currentState?.refresh();
              _onCancel();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final maxLeft =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // collapse button
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
                  tooltip:
                      _isLeftPanelExpanded ? (isEnglish ? 'Collapse' : 'ย่อรายการ') : (isEnglish ? 'Expand' : 'ขยายรายการ'),
                ),
              ),
              // left panel
              AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    alignment: Alignment.topLeft,
                    child: ColoredBox(
                      color: Colors.blueGrey.shade100,
                      child: SalesTerritoryListWidget(
                        key: _listKey,
                        enableAddButton: canCreate,
                        enableAddChildButton: canCreate,
                        enableEditButton: canEdit,
                        enableViewButton: true,
                        enableDeleteButton: canDelete,
                        enableCardSelect: false,
                        onAdd: _onAdd,
                        onAddChild: _onAddChild,
                        onEdit: _onEdit,
                        onView: _onView,
                        onDelete: _onDelete,
                        onCallback: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
              // divider
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) =>
                        setState(() => _isDragging = true),
                    onHorizontalDragUpdate: (d) => setState(() {
                      _leftPanelWidth =
                          (_leftPanelWidth + d.delta.dx).clamp(200.0, maxLeft);
                    }),
                    onHorizontalDragEnd: (_) =>
                        setState(() => _isDragging = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              // right panel
              Expanded(child: _buildRight()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRight() {
    switch (_mode) {
      case Mode.none:
        return SalesTerritoryDetailWidget(
          key: _detailKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return SalesTerritoryDetailWidget(
          key: _detailKey,
          mode: Mode.add,
          selected: _parentForAdd != null ? _selected : null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return SalesTerritoryDetailWidget(
          key: _detailKey,
          mode: Mode.edit,
          selected: _selected,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return SalesTerritoryDetailWidget(
          key: _detailKey,
          mode: Mode.view,
          selected: _selected,
          onSubmit: (_) {},
          onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
