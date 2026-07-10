// screens/account_screen.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../sa/utils/menu_scope.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../widgets/account_list_tree_widget.dart';
import '../widgets/account_detail_widget.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const AccountScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit, 
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<AccountListTreeWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<AccountDetailWidgetState> _detailWidgetKey = GlobalKey();
  bool _isImportOrExport = false;
  AccountMode _mode = AccountMode.none;
  Account? _selectedData;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

// --- ปรับปรุง: Import/Export Logic ---
  Future<void> _importData() async {
    setState(() {
      _isImportOrExport = true;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        // สำหรับเว็บ, ต้องตั้งค่า bytes ให้เป็น true เพื่อให้ได้ข้อมูลไฟล์มาเลย
        // เนื่องจากไม่สามารถเข้าถึง path ได้
        withData: kIsWeb,
      );

      if (result != null && result.files.single.bytes != null ||
          result?.files.single.path != null) {
        // ตรวจสอบ bytes หรือ path
        PlatformFile platformFile = result!.files.single;

        // ส่ง PlatformFile เข้าไปใน service
        await Provider.of<AccountService>(context, listen: false)
            .importDataExcel(platformFile);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        widget.onFieldsChanged(); // แจ้ง Home Screen ด้วย
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import สำเร็จ!'),),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ยกเลิกการเลือกไฟล์')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการ Import: ${e.toString()}'),),
        );
      }
    } finally {
      setState(() {
        _isImportOrExport = false;
      });
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isImportOrExport = true;
    });
    try {
      await Provider.of<AccountService>(context, listen: false)
          .exportDataExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Export สำเร็จ! ไฟล์ถูกบันทึกใน Downloads'),),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการ Export: ${e.toString()}'),),
        );
      }
    } finally {
      setState(() {
        _isImportOrExport = false;
      });
    }
  }

  Future<void> _deleteRows() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบทั้งหมด'),
          content: const Text(
              'คุณแน่ใจหรือไม่ว่าต้องการลบทั้งหมด? การกระทำนี้ไม่สามารถย้อนกลับได้!'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final dataService = Provider.of<AccountService>(context, listen: false);
        await dataService.deleteRows();
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ลบทั้งหมดสำเร็จ'),));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบทั้งหมด: ${e.toString()}'),));
        }
      }
    }
  }

  void _onAddRoot() {
    setState(() {
      _mode = AccountMode.addRoot;
      _selectedData = null;
    });
  }

  void _onAddChild(Account parent) {
    setState(() {
      _mode = AccountMode.addChild;
      _selectedData = parent;
    });
  }

  void _onEdit(Account row) {
    setState(() {
      _mode = AccountMode.edit;
      _selectedData = row;
    });
  }

  void _onView(Account row) {
    setState(() {
      _mode = AccountMode.view;
      _selectedData = row;
    });
  }

  Future<void> _onDelete(Account row) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text(
            'คุณแน่ใจหรือไม่ที่จะลบ "${row.accountCode} ${row.accountNameThai}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ลบ'),
            ),
          ],
      ),
    );

    if (confirm == true) {
      try {
        final dataService = Provider.of<AccountService>(context, listen: false);
        await dataService.deleteRow(row.id);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ลบ "${row.accountCode} ${row.accountNameThai}" สำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _onSubmit(Account row) async {
    try {
      final dataService = Provider.of<AccountService>(context, listen: false);
      if (_mode == AccountMode.addRoot || _mode == AccountMode.addChild) {
        await dataService.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เพิ่มข้อมูล "${row.accountCode} ${row.accountNameThai}" สำเร็จ')),
          );
        }
      } else if (_mode == AccountMode.edit && _selectedData != null) {
        await dataService.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('บันทึกข้อมูล "${row.accountCode} ${row.accountNameThai}" สำเร็จ')),
          );
        }
      }
      _listWidgetKey.currentState?.refresh();
      _onCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')));
      }
    }
  }

  void _onCancel() {
    setState(() {
      _mode = AccountMode.none;
      _selectedData = null;
    });
  }

  void _onCallback(Account row) {
    setState(() {
      _mode = AccountMode.none;
      _selectedData = row;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // This is crucial for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange.shade900,
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
              Container(
                width: 36,
                color: Colors.deepOrange[900],
                child: IconButton(
                  icon: Icon(
                    _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
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
                    child: Container(
                      color: Colors.blueGrey[100],
                      child: Column(
                        children: [
                          Expanded(
                            child: AccountListTreeWidget(
                              key: _listWidgetKey,
                              enableAddRootButton: true,
                              enableAddChildButton: true,
                              enableEditButton: true,
                              enableViewButton: true,
                              enableDeleteButton: true,
                              enableCardSelect: false,
                              showInactive: true,
                              onAddRoot: _onAddRoot,
                              onAddChild: _onAddChild,
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

  Widget _buildRightPanel() {
    switch (_mode) {
      case AccountMode.none:
        return AccountDetailWidget(
          key: _detailWidgetKey,
          mode: AccountMode.addRoot,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case AccountMode.addRoot:
        return AccountDetailWidget(
          key: _detailWidgetKey,
          mode: AccountMode.addRoot,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case AccountMode.addChild:
        return AccountDetailWidget(
          key: _detailWidgetKey,
          mode: AccountMode.addChild,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case AccountMode.edit:
        return AccountDetailWidget(
          key: _detailWidgetKey,
          mode: AccountMode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case AccountMode.view:
        return AccountDetailWidget(
          key: _detailWidgetKey,
          mode: AccountMode.view,
          selected: _selectedData,
          onSubmit: (row){},
          onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }

}
