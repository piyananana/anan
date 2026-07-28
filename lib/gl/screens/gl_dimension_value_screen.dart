import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';
import '../widgets/gl_dimension_value_list_widget.dart';
import '../widgets/gl_dimension_value_detail_widget.dart';

class GlDimensionValueScreen extends StatefulWidget {
  const GlDimensionValueScreen({super.key});

  @override
  State<GlDimensionValueScreen> createState() => _GlDimensionValueScreenState();
}

class _GlDimensionValueScreenState extends State<GlDimensionValueScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<GlDimensionValueListWidgetState> _listKey = GlobalKey();
  final _service = GlDimensionService();

  GlDimValueMode _mode = GlDimValueMode.none;
  GlDimensionType? _currentType;
  GlDimensionValue? _selectedData;
  List<GlDimensionValue> _currentValues = [];

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 380.0;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  void _onAddRoot(GlDimensionType type) {
    setState(() {
      _mode = GlDimValueMode.add;
      _currentType = type;
      _selectedData = null;
    });
  }

  void _onAddChild(GlDimensionType type, GlDimensionValue parent) {
    setState(() {
      _mode = GlDimValueMode.addChild;
      _currentType = type;
      _selectedData = parent;
    });
  }

  void _onEdit(GlDimensionType type, GlDimensionValue row) {
    setState(() {
      _mode = GlDimValueMode.edit;
      _currentType = type;
      _selectedData = row;
    });
  }

  void _onView(GlDimensionType type, GlDimensionValue row) {
    setState(() {
      _mode = GlDimValueMode.view;
      _currentType = type;
      _selectedData = row;
    });
  }

  Future<void> _onDelete(GlDimensionType type, GlDimensionValue v) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.delete_forever, color: Colors.red),
          const SizedBox(width: 8),
          Text(l.confirmDelete),
        ]),
        content: Text(
          isEnglish
              ? 'Delete "${v.valueCode} — ${v.valueNameThai}" ?\n\n'
                  'Cannot be deleted if used in GL transactions'
              : 'ลบ "${v.valueCode} — ${v.valueNameThai}" ?\n\n'
                  'ไม่สามารถลบได้หากมีการใช้งานในธุรกรรม GL',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 16),
            label: Text(l.delete),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteValue(v.id);
      _listKey.currentState?.refresh();
      if (_selectedData?.id == v.id) _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Deleted "${v.valueCode}" successfully' : 'ลบ "${v.valueCode}" เรียบร้อย')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _onSubmit(GlDimensionValue row) async {
    final isEnglish = _isEnglish;
    try {
      if (_mode == GlDimValueMode.add || _mode == GlDimValueMode.addChild) {
        await _service.addValue(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isEnglish ? 'Added "${row.valueCode}" successfully' : 'เพิ่ม "${row.valueCode}" เรียบร้อย')));
        }
      } else if (_mode == GlDimValueMode.edit) {
        await _service.updateValue(row.id, row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isEnglish ? 'Saved "${row.valueCode}" successfully' : 'บันทึก "${row.valueCode}" เรียบร้อย')));
        }
      }
      _listKey.currentState?.refresh();
      _onCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Error: $e' : 'ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _onCancel() {
    setState(() {
      _mode = GlDimValueMode.none;
      _selectedData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
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
            tooltip: isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: () {
              _listKey.currentState?.refresh();
              _onCancel();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── ปุ่ม collapse/expand ───────────────────────────────────
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
                      ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                      : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                ),
              ),

              // ── Left panel (list) ───────────────────────────────────────
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
                      child: GlDimensionValueListWidget(
                        key: _listKey,
                        enableAddButton: canCreate,
                        enableEditButton: canEdit,
                        enableDeleteButton: canDelete,
                        onAddRoot: _onAddRoot,
                        onAddChild: _onAddChild,
                        onEdit: _onEdit,
                        onView: _onView,
                        onDelete: _onDelete,
                        onTypeChanged: (type, values) {
                          setState(() {
                            _currentType = type;
                            _currentValues = values;
                            // ถ้า type เปลี่ยน ล้าง right panel
                            if (_selectedData != null &&
                                type?.typeCode != _currentType?.typeCode) {
                              _mode = GlDimValueMode.none;
                              _selectedData = null;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // ── Divider ─────────────────────────────────────────────────
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
                                .clamp(250.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) =>
                        setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),

              // ── Right panel (detail form) ────────────────────────────────
              Expanded(
                child: GlDimensionValueDetailWidget(
                  key: ValueKey('$_mode-${_selectedData?.id}-${_currentType?.typeCode}'),
                  mode: _mode,
                  selectedType: _currentType,
                  selected: _selectedData,
                  allValues: _currentValues,
                  onSubmit: _onSubmit,
                  onCancel: _onCancel,
                  isPlaceholder: _mode == GlDimValueMode.none,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
