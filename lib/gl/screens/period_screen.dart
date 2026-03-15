// screens/zipcode_screen.dart

// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../models/period.dart';
import '../services/period_service.dart';
import '../widgets/period_list_widget.dart';
import '../widgets/period_detail_widget.dart';

class PeriodScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const PeriodScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends State<PeriodScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<PeriodListWidgetState> _listWidgetKey = GlobalKey();
  final GlobalKey<PeriodDetailWidgetState> _detailWidgetKey = GlobalKey();
  // bool _isImportOrExport = false;
  Mode _mode = Mode.none;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 300.0;
  bool _isDraggingDivider = false;
  FiscalYear? _selectedData;
  List<PostingPeriod> _selectedDetail = [];

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
  //       await Provider.of<PeriodService>(context, listen: false)
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

  // Future<void> _exportData() async {
  //   setState(() {
  //     _isImportOrExport = true;
  //   });
  //   try {
  //     await Provider.of<PeriodService>(context, listen: false)
  //         .exportDataExcel();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //             content: Text('Export สำเร็จ! ไฟล์ถูกบันทึกใน Downloads')),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //             content: Text('เกิดข้อผิดพลาดในการ Export: ${e.toString()}')),
  //       );
  //     }
  //   } finally {
  //     setState(() {
  //       _isImportOrExport = false;
  //     });
  //   }
  // }

  // Future<void> _deleteRows() async {
  //   final bool? confirm = await showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('ยืนยันการลบ'),
  //       content: const Text('คุณแน่ใจหรือไม่ที่จะลบทั้งหมด ?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(false),
  //           child: const Text('ยกเลิก'),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(true),
  //           child: const Text('ลบ'),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirm == true) {
  //     try {
  //       final dataService = Provider.of<PeriodService>(context, listen: false);
  //       // await dataService.deleteRows();
  //       _listWidgetKey.currentState?.refresh();
  //       _onCancel();
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('ลบทั้งหมด สำเร็จ')),
  //         );
  //       }
  //     } catch (e) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //               content: Text('เกิดข้อผิดพลาดในการลบทั้งหมด: ${e.toString()}')),
  //         );
  //       }
  //     }
  //   }
  // }

  void _onAdd() {
    setState(() {
      _mode = Mode.add;
      _selectedData = null;
    });
  }

  void _onEdit(FiscalYear row) {
    setState(() {
      _mode = Mode.edit;
      _selectedData = row;
    });
    _fetchPeriods(row);
  }

  void _onView(FiscalYear row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
    _fetchPeriods(row);
  }

  Future<void> _onDelete(FiscalYear row) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'คุณแน่ใจหรือไม่ที่จะลบ "${row.fyCode} - (${row.description} ?? '')" ?'),
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
        final dataService = Provider.of<PeriodService>(context, listen: false);
        await dataService.deleteHeaderRow(row.id);
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

  Future<void> _onSubmitHead(FiscalYear row) async {
    try {
      final dataService = Provider.of<PeriodService>(context, listen: false);
      if (_selectedData == null) {
        await dataService.addHeaderRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เพิ่มสำเร็จ')),
          );
        }
      } else {
        await dataService.updateHeaderRow(row);
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

  void _onCallback(FiscalYear row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
    });
    _fetchPeriods(row);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.date_range, color: Colors.white, size: 20), SizedBox(width: 8), Text('ปีบัญชีและงวดเดือนบัญชี')]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
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
        //     tooltip: 'ลบรหัสไปรษณีย์ทั้งหมด',
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
                    child: Column(
                      children: [
                        Expanded(
                          child: PeriodListWidget(
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
        return PeriodDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.none,
          selectedHead: null,
          selectedDetail: const [],
          onSubmitHead: _onSubmitHead,
          onCancel: _onCancel,
          isPlaceholder: true,
          // onMessage: _showSnackbar,
          onDetailChange: _reloadDetail,
        );
      case Mode.add:
        return PeriodDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.add,
          selectedHead: null,
          selectedDetail: const [],
          onSubmitHead: _onSubmitHead,
          onCancel: _onCancel,
          // onMessage: _showSnackbar,
          onDetailChange: _reloadDetail,
        );
      case Mode.edit:
        return PeriodDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.edit,
          selectedHead: _selectedData,
          selectedDetail: _selectedDetail,
          onSubmitHead: _onSubmitHead,
          onCancel: _onCancel,
          // onMessage: _showSnackbar,
          onDetailChange: _reloadDetail,
        );
      case Mode.view:
        return PeriodDetailWidget(
          key: _detailWidgetKey,
          mode: Mode.view,
          selectedHead: _selectedData,
          selectedDetail: _selectedDetail,
          onSubmitHead: (FiscalYear row) {},
          onCancel: _onCancel,
          // onMessage: _showSnackbar,
          onDetailChange: (){},
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // void _handleSaveYear(FiscalYear fyToSave) async {
  //   try {
  //     if (fyToSave.id == 0) {
  //       // Create
  //       final dataService = Provider.of<PeriodService>(context, listen: false);
  //       await dataService.addHeaderRow(fyToSave);
  //       _showSnackbar('สร้างปีงบประมาณสำเร็จ');
  //     } else {
  //       // Update
  //       // await _service.updateFiscalYear(fyToSave, _currentUserId);
  //       _showSnackbar('แก้ไขปีงบประมาณสำเร็จ');
  //     }
  //     // _fetchFiscalYears();
  //     _listWidgetKey.currentState?.refresh();
  //   } catch (e) {
  //     _showSnackbar('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}', isError: true);
  //   }
  // }

  Future<void> _reloadDetail() async {
    // ใช้เพื่อแจ้งให้ Detail Form โหลด Periods ใหม่หลังจาก Create/Update/Delete
    if (_selectedData != null) {
      _fetchPeriods(_selectedData!);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _fetchPeriods(FiscalYear fy) async {
    try {
      final dataService = Provider.of<PeriodService>(context, listen: false);
      final periods = await dataService.fetchDetailRows(fy.id);
      setState(() {
        _selectedDetail = periods;
        // _selectedData = fy;
      });
    } catch (e) {
      _showSnackbar('ไม่สามารถโหลดรอบบัญชีได้: ${e.toString()}', isError: true);
      setState(() { _selectedDetail = []; });
    }
  }

}


// // File: gl/screens/gl_period_screen.dart
// import 'package:flutter/material.dart';
// import '../models/period.dart';
// // import '../models/gl_fiscal_year.dart';
// // import '../models/gl_posting_period.dart';
// import '../services/period_service.dart';
// import '../widgets/period_detail_widget.dart'; 

// class PeriodScreen extends StatefulWidget {
//   const PeriodScreen({super.key});

//   @override
//   State<PeriodScreen> createState() => PeriodScreenState();
// }

// class PeriodScreenState extends State<PeriodScreen> {
//   final PeriodService _service = PeriodService();
//   Future<List<FiscalYear>>? _fiscalYearsFuture;
//   FiscalYear? _selectedFy;
//   List<PostingPeriod> _periods = [];
//   final int _currentUserId = 1; // สมมติ User ID

//   @override
//   void initState() {
//     super.initState();
//     _fetchFiscalYears();
//   }

//   // --- Fetching Data ---
//   void _fetchFiscalYears() {
//     setState(() {
//       _fiscalYearsFuture = _service.fetchFiscalYears();
//       _selectedFy = null; // Clear selection when refreshing list
//       _periods = [];
//     });
//   }

//   void _fetchPeriods(FiscalYear fy) async {
//     try {
//       final periods = await _service.fetchPeriodsByYearId(fy.id);
//       setState(() {
//         _periods = periods;
//         _selectedFy = fy;
//       });
//     } catch (e) {
//       _showSnackbar('ไม่สามารถโหลดรอบบัญชีได้: ${e.toString()}', isError: true);
//       setState(() { _periods = []; });
//     }
//   }

//   // --- Handlers ---
//   void _handleYearSelect(FiscalYear fy) {
//     if (_selectedFy?.id != fy.id) {
//       _fetchPeriods(fy);
//     }
//   }

  // void _handleSaveYear(FiscalYear fyToSave) async {
  //   try {
  //     if (fyToSave.id == 0) {
  //       // Create
  //       await _service.createFiscalYear(fyToSave, _currentUserId);
  //       _showSnackbar('สร้างปีงบประมาณสำเร็จ');
  //     } else {
  //       // Update
  //       // await _service.updateFiscalYear(fyToSave, _currentUserId);
  //       _showSnackbar('แก้ไขปีงบประมาณสำเร็จ');
  //     }
  //     _fetchFiscalYears();
  //   } catch (e) {
  //     _showSnackbar('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}', isError: true);
  //   }
  // }
  
//   void _handleDeleteYear() async {
//     if (_selectedFy == null) return;
    
//     final bool confirm = await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('ยืนยันการลบ'),
//         content: Text('คุณแน่ใจว่าต้องการลบปีงบประมาณ ${_selectedFy!.fyCode} และรอบบัญชีทั้งหมดที่เกี่ยวข้องหรือไม่?'),
//         actions: [
//           TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
//           TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ลบ')),
//         ],
//       ),
//     ) ?? false;
    
//     if (confirm) {
//       try {
//         // await _service.deleteFiscalYear(_selectedFy!.id);
//         _showSnackbar('ลบปีงบประมาณสำเร็จ');
//         _fetchFiscalYears();
//       } catch (e) {
//         _showSnackbar('ไม่สามารถลบได้: ${e.toString()}', isError: true);
//       }
//     }
//   }
  
  // void _reloadDetail() {
  //   // ใช้เพื่อแจ้งให้ Detail Form โหลด Periods ใหม่หลังจาก Create/Update/Delete
  //   if (_selectedFy != null) {
  //     _fetchPeriods(_selectedFy!);
  //   }
  // }

  // void _showSnackbar(String message, {bool isError = false}) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       backgroundColor: isError ? Colors.red : Colors.green,
  //     ),
  //   );
  // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('จัดการปฏิทินบัญชีและรอบบัญชี'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _fetchFiscalYears,
//             tooltip: 'โหลดข้อมูลปีงบประมาณใหม่',
//           ),
//           IconButton(
//             icon: const Icon(Icons.add),
//             onPressed: () {
//               setState(() {
//                 _selectedFy = null; // เข้าสู่โหมดสร้างใหม่
//                 _periods = [];
//               });
//             },
//             tooltip: 'สร้างปีงบประมาณใหม่',
//           ),
//         ],
//       ),
//       body: Row(
//         children: <Widget>[
//           // 1. ส่วนแสดงรายการ Fiscal Year (ซ้าย)
//           Expanded(
//             flex: 2,
//             child: Card(
//               margin: const EdgeInsets.all(8.0),
//               child: FutureBuilder<List<FiscalYear>>(
//                 future: _fiscalYearsFuture,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   } else if (snapshot.hasError) {
//                     return Center(child: Text('Error: ${snapshot.error}'));
//                   } else if (snapshot.hasData) {
//                     return ListView.builder(
//                       itemCount: snapshot.data!.length,
//                       itemBuilder: (context, index) {
//                         final fy = snapshot.data![index];
//                         return ListTile(
//                           title: Text(fy.fyCode, style: TextStyle(fontWeight: FontWeight.bold)),
//                           subtitle: Text('รอบบัญชี: ${fy.closedPeriods}/${fy.totalPeriods} ปิด'),
//                           onTap: () => _handleYearSelect(fy),
//                           selected: fy.id == _selectedFy?.id,
//                         );
//                       },
//                     );
//                   } else {
//                     return const Center(child: Text('ไม่พบข้อมูลปีงบประมาณ'));
//                   }
//                 },
//               ),
//             ),
//           ),
          
//           // 2. ส่วนแสดง Detail Form (ขวา)
//           Expanded(
//             flex: 3,
//             child: Card(
//               margin: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 8.0),
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: PeriodDetailWidget(
//                       fiscalYear: _selectedFy,
//                       periods: _periods,
//                       onSubmitHead: _handleSaveYear,
//                       onMessage: _showSnackbar,
//                       onDetailChange: _reloadDetail,
//                     ),
//                   ),
//                   if (_selectedFy != null)
//                     Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: ElevatedButton.icon(
//                         icon: const Icon(Icons.delete),
//                         label: const Text('ลบปีงบประมาณนี้'),
//                         style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                         onPressed: _handleDeleteYear,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }