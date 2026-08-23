// screens/sa_module_document_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_app_l10n.dart';
import '../utils/sa_menu_scope.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/sa_anan_module.dart';
import '../models/sa_module_document.dart';
import '../services/sa_module_document_service.dart';
import '../widgets/sa_module_document_list_tree_widget.dart';
import '../widgets/sa_module_document_detail_widget.dart';

class ModuleDocumentScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ModuleDocumentScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit, 
  });

  @override
  State<ModuleDocumentScreen> createState() => _ModuleDocumentScreenState();
}

class _ModuleDocumentScreenState extends State<ModuleDocumentScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ModuleDocumentListTreeWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<ModuleDocumentDetailWidgetState> _detailWidgetKey = GlobalKey();
  bool _isImportOrExport = false;
  Mode _mode = Mode.none;
  ModuleDocument? _selectedData;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — ส่งให้ ModuleDocumentDetailWidget เพื่อบังคับเคลียร์ฟอร์มเสมอ
  // แม้ mode/selected จะซ้ำกับครั้งก่อน (เช่น กด "เพิ่มโมดูลหลัก" ซ้ำหลังพิมพ์ข้อมูลค้างไว้ หรือ
  // กดเพิ่มหลังจาก placeholder ที่ใช้ mode/selected ชุดเดียวกันโดยบังเอิญ)
  int _requestSeq = 0;

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
        await Provider.of<ModuleDocumentService>(context, listen: false)
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
            SnackBar(content: Text(isEnglish ? 'File selection canceled' : 'ยกเลิกการเลือกไฟล์')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Error importing: ${e.toString()}' : 'เกิดข้อผิดพลาดในการ Import: ${e.toString()}')),
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
      await Provider.of<ModuleDocumentService>(context, listen: false)
          .exportDataExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Export successful! File saved to Downloads' : 'Export สำเร็จ! ไฟล์ถูกบันทึกใน Downloads')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Error exporting: ${e.toString()}' : 'เกิดข้อผิดพลาดในการ Export: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImportOrExport = false;
      });
    }
  }

  Future<void> _deleteRows() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l.isEnglish ? 'Confirm Delete All' : 'ยืนยันการลบทั้งหมด'),
          content: Text(l.isEnglish
              ? 'Are you sure you want to delete everything? This action cannot be undone!'
              : 'คุณแน่ใจหรือไม่ว่าต้องการลบทั้งหมด? การกระทำนี้ไม่สามารถย้อนกลับได้!'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.cancel)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final dataService = Provider.of<ModuleDocumentService>(context, listen: false);
        await dataService.deleteRows();
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.isEnglish ? 'All items deleted successfully' : 'ลบทั้งหมดสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l.isEnglish ? 'Error deleting all: ${e.toString()}' : 'เกิดข้อผิดพลาดในการลบทั้งหมด: ${e.toString()}')));
        }
      }
    }
  }

  void _onAddRoot() {
    setState(() {
      _mode = Mode.addRoot;
      _selectedData = null;
      _requestSeq++;
    });
  }

  void _onAddChild(ModuleDocument parent) {
    setState(() {
      _mode = Mode.addChild;
      _selectedData = parent;
      _requestSeq++;
    });
  }

  void _onEdit(ModuleDocument row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
      _requestSeq++;
    });
  }

  void _onView(ModuleDocument row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
      _requestSeq++;
    });
  }

  Future<void> _onDelete(ModuleDocument row) async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
          title: Text(l.confirmDelete),
          content: Text(l.isEnglish
              ? 'Are you sure you want to delete "${row.docCode} ${row.docNameThai}"?'
              : 'คุณแน่ใจหรือไม่ที่จะลบ "${row.docCode} ${row.docNameThai}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.cancel)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.delete),
            ),
          ],
      ),
    );

    if (confirm == true) {
      try {
        final dataService = Provider.of<ModuleDocumentService>(context, listen: false);
        await dataService.deleteRow(row.id);
        _listWidgetKey.currentState?.refresh();
        _onCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.isEnglish ? 'Deleted "${row.docCode} ${row.docNameThai}" successfully' : 'ลบ "${row.docCode} ${row.docNameThai}" สำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l.isEnglish ? 'Error deleting: ${e.toString()}' : 'เกิดข้อผิดพลาดในการลบ: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _onSubmit(ModuleDocument row) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    try {
      final dataService = Provider.of<ModuleDocumentService>(context, listen: false);
      if (_mode == Mode.addRoot || _mode == Mode.addChild) {
        await dataService.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Added "${row.docCode} ${row.docNameThai}" successfully' : 'เพิ่มข้อมูล "${row.docCode} ${row.docNameThai}" สำเร็จ')),
          );
        }
      } else if (_mode == Mode.edit && _selectedData != null) {
        await dataService.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Saved "${row.docCode} ${row.docNameThai}" successfully' : 'บันทึกข้อมูล "${row.docCode} ${row.docNameThai}" สำเร็จ')),
          );
        }
      }
      _listWidgetKey.currentState?.refresh();
      _onCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Error saving: ${e.toString()}' : 'เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')));
      }
    }
  }

  void _onCancel() {
    setState(() {
      _mode = Mode.none;
      _selectedData = null;
      _requestSeq++;
    });
  }

  void _onCallback(ModuleDocument row) {
    setState(() {
      _mode = Mode.none;
      _selectedData = row;
      _requestSeq++;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // This is crucial for AutomaticKeepAliveClientMixin
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: () {
              _listWidgetKey.currentState?.refresh();
              _onCancel();
            },
          ),
        ],
        // actions: [
        //   // ปุ่ม Import/Export
        //   if (_isImportOrExport)
        //     const Padding(
        //       padding: EdgeInsets.symmetric(horizontal: 16.0),
        //       child:
        //           Center(child: CircularProgressIndicator(color: Colors.white)),
        //     )
        //   else ...[
        //     IconButton(
        //       icon: const Icon(Icons.upload_file),
        //       tooltip: 'นำข้อมูลเข้าจาก Spredsheet',
        //       onPressed: _importData,
        //     ),
        //     IconButton(
        //       icon: const Icon(Icons.download),
        //       tooltip: 'นำข้อมูลออกไป Spredsheet',
        //       onPressed: _exportData,
        //     ),
        //   ],
        //   IconButton(
        //     icon: const Icon(Icons.delete_sweep),
        //     tooltip: 'ลบผังบัญชีทั้งหมด',
        //     onPressed: _deleteRows,
        //   ),
        //   const SizedBox(width: 8),
        // ],
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
                  tooltip: _isLeftPanelExpanded
                      ? (l.isEnglish ? 'Collapse list' : 'ย่อรายการ')
                      : (l.isEnglish ? 'Expand list' : 'ขยายรายการ'),
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
                            child: ModuleDocumentListTreeWidget(
                              key: _listWidgetKey,
                              enableAddRootButton: true,
                              enableAddChildButton: true,
                              enableEditButton: true,
                              enableViewButton: true,
                              enableDeleteButton: true,
                              enableCardSelect: false,
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
      case Mode.none:
        return ModuleDocumentDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.addRoot,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          isPlaceholder: true,
          requestSeq: _requestSeq,
        );
      case Mode.addRoot:
        return ModuleDocumentDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.addRoot,
          selected: null,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.addChild:
        return ModuleDocumentDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.addChild,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.edit:
        return ModuleDocumentDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.edit,
          selected: _selectedData,
          onSubmit: _onSubmit,
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      case Mode.view:
        return ModuleDocumentDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.view,
          selected: _selectedData,
          onSubmit: (row){},
          onCancel: _onCancel,
          requestSeq: _requestSeq,
        );
      default:
        return const SizedBox.shrink();
    }
  }

}
