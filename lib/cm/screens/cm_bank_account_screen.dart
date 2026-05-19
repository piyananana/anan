// lib/cm/screens/cm_bank_account_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../models/cm_bank_account.dart';
import '../services/cm_bank_account_service.dart';
import '../widgets/cm_bank_account_list_widget.dart';
import '../widgets/cm_bank_account_detail_widget.dart';

class CmBankAccountScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const CmBankAccountScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<CmBankAccountScreen> createState() => _CmBankAccountScreenState();
}

class _CmBankAccountScreenState extends State<CmBankAccountScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<CmBankAccountListWidgetState> _listKey = GlobalKey();
  final GlobalKey<CmBankAccountDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  CmBankAccount? _selectedData;
  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 420.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selectedData = null;
      });

  void _onEdit(CmBankAccount row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
      });

  void _onView(CmBankAccount row) => setState(() {
        _mode = Mode.view;
        _selectedData = row;
      });

  Future<void> _onDelete(CmBankAccount row) async {
    final service = Provider.of<CmBankAccountService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบบัญชีธนาคาร "${row.accountCode} — ${row.accountNameTh}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await service.deleteRow(row.id!);
      _listKey.currentState?.refresh();
      _onCancel();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ลบล้มเหลว: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSubmit(CmBankAccount row) async {
    final service = Provider.of<CmBankAccountService>(context, listen: false);
    if (_mode == Mode.add) {
      final created = await service.addRow(row);
      _listKey.currentState?.refresh();
      setState(() {
        _mode = Mode.edit;
        _selectedData = created;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('เพิ่มสำเร็จ')));
      }
    } else {
      await service.updateRow(row);
      _listKey.currentState?.refresh();
      setState(() => _selectedData = row);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      }
    }
    widget.onFieldsChanged();
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
      });

  void _onCallback(CmBankAccount row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
      });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.savings, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('ตั้งค่าบัญชีธนาคาร'),
        ]),
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
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
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
                      child: CmBankAccountListWidget(
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
        return CmBankAccountDetailWidget(
          key: _detailKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return CmBankAccountDetailWidget(
          key: _detailKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return CmBankAccountDetailWidget(
          key: _detailKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return CmBankAccountDetailWidget(
          key: _detailKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (_) async {},
          onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
