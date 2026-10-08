import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_price_change.dart';
import '../services/im_price_change_service.dart';
import '../widgets/im_price_change_list_widget.dart';
import '../widgets/im_price_change_detail_widget.dart';

class ImPriceChangeScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImPriceChangeScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImPriceChangeScreen> createState() => _ImPriceChangeScreenState();
}

class _ImPriceChangeScreenState extends State<ImPriceChangeScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImPriceChangeListWidgetState> _listKey = GlobalKey();
  final GlobalKey<ImPriceChangeDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImPriceChangeService();

  Mode _mode = Mode.none;
  ImPriceChangeHeader? _selectedData;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — ส่งให้ ImPriceChangeDetailWidget เพื่อบังคับเคลียร์ฟอร์มเสมอ
  // แม้ mode/selected จะซ้ำกับครั้งก่อน (เช่น กด "สร้างธุรกรรม" ซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  int _requestSeq = 0;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 380.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selectedData = null;
        _requestSeq++;
      });

  void _onEdit(ImPriceChangeHeader row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  void _onView(ImPriceChangeHeader row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  Future<void> _fetchFull(ImPriceChangeHeader row) async {
    if (row.id == null) return;
    try {
      final full = await _svc.fetchRow(row.id!);
      if (mounted) setState(() => _selectedData = full);
    } catch (_) {}
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
        _requestSeq++;
      });

  void _onCallback(ImPriceChangeHeader row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  Widget _buildRightPanel() {
    switch (_mode) {
      case Mode.none:
        return ImPriceChangeDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null,
          onCancel: _onCancel, onRefreshList: () => _listKey.currentState?.refresh(),
          isPlaceholder: true, requestSeq: _requestSeq,
        );
      case Mode.add:
        return ImPriceChangeDetailWidget(
          key: _detailKey, mode: Mode.add, selected: null,
          onCancel: _onCancel, onRefreshList: () => _listKey.currentState?.refresh(),
          requestSeq: _requestSeq,
        );
      case Mode.edit:
        return ImPriceChangeDetailWidget(
          key: _detailKey, mode: Mode.edit, selected: _selectedData,
          onCancel: _onCancel, onRefreshList: () => _listKey.currentState?.refresh(),
          requestSeq: _requestSeq,
        );
      case Mode.view:
        return ImPriceChangeDetailWidget(
          key: _detailKey, mode: Mode.view, selected: _selectedData,
          onCancel: _onCancel, onRefreshList: () => _listKey.currentState?.refresh(),
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
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
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
                      child: ImPriceChangeListWidget(
                        key: _listKey,
                        enableAddButton: canCreate,
                        enableEditButton: canEdit,
                        enableViewButton: true,
                        onAdd: _onAdd,
                        onEdit: _onEdit,
                        onView: _onView,
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
