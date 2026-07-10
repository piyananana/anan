// screens/branch_screen.dart

// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';
import '../widgets/branch_list_widget.dart';
import '../widgets/branch_detail_widget.dart';

class BranchScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const BranchScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<BranchListWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<BranchDetailWidgetState> _detailWidgetKey = GlobalKey();
  bool _isImportOrExport = false;
  Mode _mode = Mode.none;
  Branch? _selectedData;

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
  // bool get wantKeepAlive => throw UnimplementedError();
  bool get wantKeepAlive => true;

  // Future<void> _importData() async {
  //   setState(() {
  //     _isImportOrExport = true;
  //   });
  //   try {
  //     FilePickerResult? result = await FilePicker.platform.pickFiles(
  //       type: FileType.custom,
  //       allowedExtensions: ['xlsx'],
  //       // สำหรับเว็บ, ต้องตั้งค่า bytes ให้เป็น true เพื่อให้ได้ข้อมูลไฟล์มาเลย
  //       // เนื่องจากไม่สามารถเข้าถึง path ได้
  //       withData: kIsWeb,
  //     );

  //     if (result != null && result.files.single.bytes != null ||
  //         result?.files.single.path != null) {
  //       // ตรวจสอบ bytes หรือ path
  //       PlatformFile platformFile = result!.files.single;

  //       // ส่ง PlatformFile เข้าไปใน service
  //       await Provider.of<BranchService>(context, listen: false)
  //           .importDataExcel(platformFile);
  //       _listWidgetKey.currentState?.refresh();
  //       _onCancel();
  //       widget.onFieldsChanged(); // แจ้ง Home Screen ด้วย
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Import สำเร็จ!')),
  //         );
  //       }
  //     } else {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('ยกเลิกการเลือกไฟล์')),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //             content: Text('เกิดข้อผิดพลาดในการ Import: ${e.toString()}')),
  //       );
  //     }
  //   } finally {
  //     setState(() {
  //       _isImportOrExport = false;
  //     });
  //   }
  // }

  Future<void> _exportData() async {
    setState(() {
      _isImportOrExport = true;
    });
    try {
      await Provider.of<BranchService>(context, listen: false)
          .exportDataExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Export สำเร็จ! ไฟล์ถูกบันทึกใน Downloads')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการ Export: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImportOrExport = false;
      });
    }
  }

  Future<void> _deleteRows() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณแน่ใจหรือไม่ที่จะลบทั้งหมด ?'),
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
        final dataService = Provider.of<BranchService>(context, listen: false);
        await dataService.deleteRows();
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบทั้งหมด สำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('เกิดข้อผิดพลาดในการลบทั้งหมด: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _onAdd() {
    setState(() {
      _mode = Mode.add;
      _selectedData = null;
    });
  }

  void _onEdit(Branch row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
    });
  }

  void _onView(Branch row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
  }

  Future<void> _onDelete(Branch row) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'คุณแน่ใจหรือไม่ที่จะลบ "${row.branchCode} (${row.branchNameThai})" ?'),
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
        final dataService = Provider.of<BranchService>(context, listen: false);
        await dataService.deleteRow(row.id!);
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

  Future<void> _onSubmit(Branch row) async {
    try {
      final dataService = Provider.of<BranchService>(context, listen: false);
      if (_selectedData == null) {
        await dataService.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เพิ่มสำเร็จ')),
          );
        }
      } else {
        await dataService.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกสำเร็จ')),
          );
        }
      }
      _listWidgetKey.currentState?.refresh();
      _onCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')),
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

  void _onCallback(Branch row) {
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
        title: const MenuTitle(),
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
                    child: ColoredBox(
                      color: Colors.blueGrey.shade100,
                      child: Column(
                        children: [
                          Expanded(
                            child: BranchListWidget(
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
      case Mode.none:
        return BranchDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return BranchDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return BranchDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return BranchDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (branch) {},
          onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
