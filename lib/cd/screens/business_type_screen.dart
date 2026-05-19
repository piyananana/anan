// screens/business_type_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../models/business_type.dart';
import '../services/business_type_service.dart';
import '../widgets/business_type_list_widget.dart';
import '../widgets/business_type_detail_widget.dart';

class BusinessTypeScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const BusinessTypeScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<BusinessTypeScreen> createState() => _BusinessTypeScreenState();
}

class _BusinessTypeScreenState extends State<BusinessTypeScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<BusinessTypeListWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<BusinessTypeDetailWidgetState> _detailWidgetKey = GlobalKey();

  Mode _mode = Mode.none;
  BusinessType? _selectedData;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 380.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() {
    setState(() {
      _mode = Mode.add;
      _selectedData = null;
    });
  }

  void _onEdit(BusinessType row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
    });
  }

  void _onView(BusinessType row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
  }

  Future<void> _onDelete(BusinessType row) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'คุณแน่ใจหรือไม่ที่จะลบ "${row.businessTypeCode} (${row.businessTypeNameThai})" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Provider.of<BusinessTypeService>(context, listen: false)
            .deleteRow(row.id!);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบสำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _onSubmit(BusinessType row) async {
    try {
      final service =
          Provider.of<BusinessTypeService>(context, listen: false);
      if (_selectedData == null) {
        await service.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('เพิ่มสำเร็จ')));
        }
      } else {
        await service.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
        }
      }
      _listWidgetKey.currentState?.refresh();
      _onCancel();
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')),
        );
      }
    }
  }

  void _onCancel() {
    setState(() {
      _mode = Mode.none;
      _selectedData = null;
    });
  }

  void _onCallback(BusinessType row) {
    setState(() {
      _mode = Mode.none;
      _selectedData = row;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.category, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('ประเภทธุรกิจ'),
        ]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
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
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ปุ่ม collapse
              Container(
                width: 36,
                color: Colors.deepOrange[900],
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
                  tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
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
                            child: BusinessTypeListWidget(
                              key: _listWidgetKey,
                              enableAddButton: true,
                              enableEditButton: true,
                              enableViewButton: true,
                              enableDeleteButton: true,
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
              // Divider (drag resize)
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
        return BusinessTypeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return BusinessTypeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return BusinessTypeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return BusinessTypeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (_) {},
          onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
