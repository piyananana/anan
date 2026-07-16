// screens/cd_zipcode_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/cd_zipcode.dart';
import '../services/cd_zipcode_service.dart';
import '../widgets/cd_zipcode_list_widget.dart';
import '../widgets/cd_zipcode_detail_widget.dart';

class ZipcodeScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ZipcodeScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ZipcodeScreen> createState() => _ZipcodeScreenState();
}

class _ZipcodeScreenState extends State<ZipcodeScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ZipcodeListWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<ZipcodeDetailWidgetState> _detailWidgetKey = GlobalKey();
  bool _isImportOrExport = false;
  Mode _mode = Mode.none;
  Zipcode? _selectedData;

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

  Future<void> _importData() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
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
        await Provider.of<ZipcodeService>(context, listen: false)
            .importDataExcel(platformFile);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        widget.onFieldsChanged(); // แจ้ง Home Screen ด้วย
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Import successful!' : 'Import สำเร็จ!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'File selection cancelled' : 'ยกเลิกการเลือกไฟล์')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${isEnglish ? 'An error occurred during Import' : 'เกิดข้อผิดพลาดในการ Import'}: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImportOrExport = false;
      });
    }
  }

  Future<void> _exportData() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() {
      _isImportOrExport = true;
    });
    try {
      await Provider.of<ZipcodeService>(context, listen: false)
          .exportDataExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish
                  ? 'Export successful! File saved in Downloads'
                  : 'Export สำเร็จ! ไฟล์ถูกบันทึกใน Downloads')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish
                  ? 'Export failed: ${e.toString()}'
                  : 'เกิดข้อผิดพลาดในการ Export: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImportOrExport = false;
      });
    }
  }

  Future<void> _deleteRows() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete All' : 'ยืนยันการลบ'),
        content: Text(isEnglish ? 'Are you sure you want to delete all?' : 'คุณแน่ใจหรือไม่ที่จะลบทั้งหมด ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isEnglish ? 'Delete' : 'ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dataService = Provider.of<ZipcodeService>(context, listen: false);
        await dataService.deleteRows();
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Deleted all successfully' : 'ลบทั้งหมด สำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isEnglish
                    ? 'Delete all failed: ${e.toString()}'
                    : 'เกิดข้อผิดพลาดในการลบทั้งหมด: ${e.toString()}')),
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

  void _onEdit(Zipcode row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
    });
  }

  void _onView(Zipcode row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
  }

  Future<void> _onDelete(Zipcode row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete "${row.zipcode} (${row.subDistrict})"?'
            : 'คุณแน่ใจหรือไม่ที่จะลบ "${row.zipcode} (${row.subDistrict})" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isEnglish ? 'Delete' : 'ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dataService = Provider.of<ZipcodeService>(context, listen: false);
        await dataService.deleteRow(row.id!);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish
                ? 'Delete failed: ${e.toString()}'
                : 'เกิดข้อผิดพลาดในการลบ: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _onSubmit(Zipcode row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    try {
      final dataService = Provider.of<ZipcodeService>(context, listen: false);
      if (_selectedData == null) {
        await dataService.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Added successfully' : 'เพิ่มสำเร็จ')),
          );
        }
      } else {
        await dataService.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')),
          );
        }
      }
      _listWidgetKey.currentState?.refresh();
      _onCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish
              ? 'Save failed: ${e.toString()}'
              : 'เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')),
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

  void _onCallback(Zipcode row) {
    setState(() {
      _mode = Mode.none;
      _selectedData = row;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
            onPressed: () {
              _listWidgetKey.currentState?.refresh();
              _onCancel();
            },
          ),
          // ปุ่ม Import/Export
          if (_isImportOrExport)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: isEnglish ? 'Import from Spreadsheet' : 'นำข้อมูลเข้าจาก Spredsheet',
              onPressed: _importData,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: isEnglish ? 'Export to Spreadsheet' : 'นำข้อมูลออกไป Spredsheet',
              onPressed: _exportData,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: isEnglish ? 'Delete All Zipcodes' : 'ลบรหัสไปรษณีย์ทั้งหมด',
            onPressed: _deleteRows,
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
                  tooltip: _isLeftPanelExpanded ? (isEnglish ? 'Collapse' : 'ย่อรายการ') : (isEnglish ? 'Expand' : 'ขยายรายการ'),
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
                            child: ZipcodeListWidget(
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
        return ZipcodeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.none,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
        );
      case Mode.add:
        return ZipcodeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.add,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.edit:
        return ZipcodeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
        );
      case Mode.view:
        return ZipcodeDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (zipcode) {},
          onCancel: _onCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
