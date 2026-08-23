import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_item_category.dart';
import '../services/im_item_category_service.dart';
import '../widgets/im_item_category_list_tree_widget.dart';
import '../widgets/im_item_category_detail_widget.dart';

class ImItemCategoryScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImItemCategoryScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImItemCategoryScreen> createState() => _ImItemCategoryScreenState();
}

class _ImItemCategoryScreenState extends State<ImItemCategoryScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImItemCategoryListTreeWidgetState> _listKey = GlobalKey();
  final GlobalKey<ImItemCategoryDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImItemCategoryService();

  Mode _mode = Mode.none;
  ImItemCategory? _selectedData;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — ส่งให้ ImItemCategoryDetailWidget เพื่อบังคับเคลียร์ฟอร์มเสมอ
  // แม้ mode/selected จะซ้ำกับครั้งก่อน (เช่น กด "เพิ่มหมวดหมู่หลัก" ซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  int _requestSeq = 0;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  void _onAddRoot() => setState(() {
        _mode = Mode.addRoot;
        _selectedData = null;
        _requestSeq++;
      });

  void _onAddChild(ImItemCategory parent) => setState(() {
        _mode = Mode.addChild;
        _selectedData = parent;
        _requestSeq++;
      });

  void _onEdit(ImItemCategory row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
        _requestSeq++;
      });

  void _onView(ImItemCategory row) => setState(() {
        _mode = Mode.view;
        _selectedData = row;
        _requestSeq++;
      });

  Future<void> _onDelete(ImItemCategory row) async {
    final isEnglish = _isEnglish;
    final l = AppL10n(isEnglish);
    final name = isEnglish && (row.categoryNameEn ?? '').isNotEmpty ? row.categoryNameEn! : row.categoryNameTh;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete category "${row.categoryCode} $name" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบหมวดหมู่ "${row.categoryCode} $name" ?'),
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

  Future<void> _onSubmit(ImItemCategory row) async {
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
        _requestSeq++;
      });

  void _onCallback(ImItemCategory row) => setState(() {
        _mode = Mode.none;
        _selectedData = row;
        _requestSeq++;
      });

  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return ImItemCategoryDetailWidget(
          key: _detailKey,
          mode: Mode.addRoot,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
          requestSeq: _requestSeq,
        );
      case Mode.addRoot:
        return ImItemCategoryDetailWidget(
          key: _detailKey,
          mode: Mode.addRoot,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.addChild:
        return ImItemCategoryDetailWidget(
          key: _detailKey,
          mode: Mode.addChild,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.edit:
        return ImItemCategoryDetailWidget(
          key: _detailKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.view:
        return ImItemCategoryDetailWidget(
          key: _detailKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (_) async {},
          onCancel: _onCancel,
          requestSeq: _requestSeq,
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
                      child: ImItemCategoryListTreeWidget(
                        key: _listKey,
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
