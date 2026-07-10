// lib/ar/screens/ar_collector_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/ar_collector.dart';
import '../services/ar_collector_service.dart';
import '../widgets/ar_collector_list_widget.dart';
import '../widgets/ar_collector_detail_widget.dart';

class ArCollectorScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ArCollectorScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ArCollectorScreen> createState() => _ArCollectorScreenState();
}

class _ArCollectorScreenState extends State<ArCollectorScreen>
    with AutomaticKeepAliveClientMixin {
  final _listKey = GlobalKey<ArCollectorListWidgetState>();
  final _detailKey = GlobalKey<ArCollectorDetailWidgetState>();

  Mode _mode = Mode.none;
  ArCollector? _selected;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 400.0;
  bool _isDragging = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selected = null;
      });

  Future<void> _onEdit(ArCollector row) async {
    setState(() {
      _mode = Mode.edit;
      _selected = row;
    });
    try {
      final full =
          await Provider.of<ArCollectorService>(context, listen: false)
              .fetchRow(row.id!);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  Future<void> _onView(ArCollector row) async {
    setState(() {
      _mode = Mode.view;
      _selected = row;
    });
    try {
      final full =
          await Provider.of<ArCollectorService>(context, listen: false)
              .fetchRow(row.id!);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  Future<void> _onDelete(ArCollector row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'ลบ "${row.collectorCode} (${row.collectorNameThai})" ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Provider.of<ArCollectorService>(context, listen: false)
          .deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ลบล้มเหลว: $e')));
      }
    }
  }

  Future<void> _onSubmit(ArCollector row) async {
    try {
      final svc = Provider.of<ArCollectorService>(context, listen: false);
      if (_selected == null) {
        await svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('เพิ่มสำเร็จ')));
        }
      } else {
        await svc.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
        }
      }
      _listKey.currentState?.refresh();
      _onCancel();
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.indigo[700],
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
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final maxLeft = (constraints.maxWidth - 36 - 5 - 300)
              .clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // collapse button
              Container(
                width: 36,
                color: Colors.indigo[700],
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
                      _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
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
                      child: ArCollectorListWidget(
                        key: _listKey,
                        enableAddButton: true,
                        enableEditButton: true,
                        enableViewButton: true,
                        enableDeleteButton: true,
                        enableCardSelect: false,
                        onAdd: _onAdd,
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
        return ArCollectorDetailWidget(
          key: _detailKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return ArCollectorDetailWidget(
          key: _detailKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return ArCollectorDetailWidget(
          key: _detailKey,
          mode: Mode.edit,
          selected: _selected,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return ArCollectorDetailWidget(
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
