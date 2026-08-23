// lib/cd/screens/cd_bank_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cd_bank.dart';
import '../services/cd_bank_service.dart';
import '../widgets/cd_bank_list_widget.dart';
import '../widgets/cd_bank_detail_widget.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';

class BankScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const BankScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<BankListWidgetState> _listKey = GlobalKey();
  final GlobalKey<BankDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  Bank? _selectedData;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — ส่งให้ BankDetailWidget เพื่อบังคับเคลียร์ฟอร์มเสมอ
  // แม้ mode/selected จะซ้ำกับครั้งก่อน
  int _requestSeq = 0;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 400.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  void _onAdd() => setState(() {
        _mode = Mode.add;
        _selectedData = null;
        _requestSeq++;
      });

  void _onEdit(Bank row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
        _requestSeq++;
      });

  void _onView(Bank row) => setState(() {
        _mode = Mode.view;
        _selectedData = row;
        _requestSeq++;
      });

  Future<void> _onDelete(Bank row) async {
    // Capture service before any await to avoid async context issues
    final service = Provider.of<BankService>(context, listen: false);
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(
            isEnglish
                ? 'Are you sure you want to delete "${row.bankCode} ${row.shortName ?? row.bankNameEng}"?'
                : 'คุณแน่ใจหรือไม่ที่จะลบ "${row.bankCode} ${row.bankNameThai}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.delete, style: const TextStyle(color: Colors.red))),
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
            .showSnackBar(SnackBar(content: Text(l.deletedSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Delete failed: $e' : 'ลบล้มเหลว: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onSubmit(Bank row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    try {
      final service = Provider.of<BankService>(context, listen: false);
      if (_mode == Mode.add) {
        final created = await service.addRow(row);
        _listKey.currentState?.refresh();
        // Switch to edit mode so user can add branches right away
        setState(() {
          _mode = Mode.edit;
          _selectedData = created;
          _requestSeq++;
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')));
        }
      } else {
        await service.updateRow(row);
        _listKey.currentState?.refresh();
        setState(() {
          _selectedData = row;
          _requestSeq++;
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.savedSuccess)));
        }
      }
      widget.onFieldsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e'),
              backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  void _onCancel() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
        _requestSeq++;
      });

  void _onCallback(Bank row) => setState(() {
        _mode = Mode.edit;
        _selectedData = row;
        _requestSeq++;
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
        backgroundColor: Colors.indigo[700],
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
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle button
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
                  tooltip: _isLeftPanelExpanded ? (isEnglish ? 'Collapse' : 'ย่อรายการ') : (isEnglish ? 'Expand' : 'ขยายรายการ'),
                ),
              ),
              // Left panel: bank list
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
                      child: BankListWidget(
                        key: _listKey,
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
                  ),
                ),
              ),
              // Drag divider
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
              // Right panel: bank detail + branches
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
        return BankDetailWidget(
          key: _detailKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
          requestSeq: _requestSeq,
        );
      case Mode.add:
        return BankDetailWidget(
          key: _detailKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.edit:
        return BankDetailWidget(
          key: _detailKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.view:
        return BankDetailWidget(
          key: _detailKey,
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
