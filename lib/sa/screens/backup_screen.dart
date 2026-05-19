// // lib/screens/backup_screen.dart (เวอร์ชันแก้ไข)

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../models/backup_schedule.dart';
// import '../services/backup_service.dart';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:url_launcher/url_launcher.dart';

// class BackupScreen extends StatefulWidget {
//   const BackupScreen({super.key});

//   @override
//   State<BackupScreen> createState() => _BackupScreenState();
// }

// class _BackupScreenState extends State<BackupScreen>
//     with AutomaticKeepAliveClientMixin {
//   // static const String baseUrl = 'http://localhost:3000/api/sa';
//   static const String baseUrl = AppConfig.apiSa;
//   final _backupService = BackupService();

//   List<BackupSchedule> _schedules = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   // Polling timers for each schedule ID
//   final Map<int, Timer> _pollingTimers = {};

//   // Daily
//   List<bool> _dailyDaysOfWeek = List.filled(7, false);
//   TimeOfDay _dailyTime = TimeOfDay.now();
//   List<String> _dailyFiles = [];
//   String? _dailyLastBackup;
//   String? _dailyStatus;

//   // Instant
//   List<String> _instantFiles = [];
//   String? _instantLastBackup;
//   String? _instantStatus;
//   bool _isInstantBackupRunning = false;
//   Timer? _instantBackupStatusTimer;

//   // Monthly
//   List<String> _monthlyDaysOfMonth = [];
//   TimeOfDay _monthlyTime = TimeOfDay.now();
//   List<String> _monthlyFiles = [];
//   String? _monthlyLastBackup;
//   String? _monthlyStatus;

//   // Yearly
//   List<String> _yearlyDates = [];
//   TimeOfDay _yearlyTime = TimeOfDay.now();
//   List<String> _yearlyFiles = [];
//   String? _yearlyLastBackup;
//   String? _yearlyStatus;

//   @override
//   bool get wantKeepAlive => true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchSchedules();
//     _fetchBackupFiles();
//     _startInstantBackupStatusPolling();
//   }

//   @override
//   void dispose() {
//     _pollingTimers.forEach((id, timer) => timer.cancel());
//     _instantBackupStatusTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _fetchSchedules() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//     try {
//       final schedules = await _backupService.getSchedules();
//       setState(() {
//         _schedules = schedules;
//         _isLoading = false;
//         // Start polling for each schedule
//         for (var schedule in _schedules) {
//           _startPollingForSchedule(schedule.id);
//         }
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = e.toString();
//         _isLoading = false;
//       });
//     }
//   }

//   void _startPollingForSchedule(int scheduleId) {
//     if (_pollingTimers.containsKey(scheduleId)) {
//       _pollingTimers[scheduleId]!.cancel();
//     }
//     _pollingTimers[scheduleId] = Timer.periodic(const Duration(seconds: 5), (_) {
//       _fetchScheduleStatus(scheduleId);
//     });
//   }

//   void _startInstantBackupStatusPolling() {
//     _instantBackupStatusTimer?.cancel();
//     _instantBackupStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
//       _fetchInstantBackupStatus();
//     });
//   }

//   Future<void> _fetchScheduleStatus(int scheduleId) async {
//     try {
//       final status = await _backupService.getScheduleStatus(scheduleId);
//       final scheduleType = status['scheduleType'];
//       setState(() {
//         switch (scheduleType) {
//           case 'daily':
//             _dailyStatus = status['status'];
//             _dailyLastBackup = status['lastBackup'];
//             break;
//           case 'monthly':
//             _monthlyStatus = status['status'];
//             _monthlyLastBackup = status['lastBackup'];
//             break;
//           case 'yearly':
//             _yearlyStatus = status['status'];
//             _yearlyLastBackup = status['lastBackup'];
//             break;
//         }
//       });
//     } catch (e) {
//       print('Error fetching schedule status: $e');
//     }
//   }

//   Future<void> _fetchInstantBackupStatus() async {
//     try {
//       final status = await _backupService.checkInstantBackupStatus();
//       setState(() {
//         _isInstantBackupRunning = status['isRunning'] ?? false;
//         _instantStatus = status['status'];
//         _instantLastBackup = status['lastBackup'];
//       });
//     } catch (e) {
//       print('Error fetching instant backup status: $e');
//     }
//   }

//   Future<void> _fetchBackupFiles() async {
//     try {
//       final dailyFiles = await _backupService.getBackupFiles('daily');
//       final monthlyFiles = await _backupService.getBackupFiles('monthly');
//       final yearlyFiles = await _backupService.getBackupFiles('yearly');
//       final instantFiles = await _backupService.getBackupFiles('instant');
//       setState(() {
//         _dailyFiles = dailyFiles;
//         _monthlyFiles = monthlyFiles;
//         _yearlyFiles = yearlyFiles;
//         _instantFiles = instantFiles;
//       });
//     } catch (e) {
//       print('Error fetching backup files: $e');
//     }
//   }

//   Future<void> _startInstantBackup() async {
//     try {
//       _showSnackBar('กำลังเริ่มการสำรองข้อมูลทันที...', Colors.blue);
//       await _backupService.startInstantBackup();
//       _fetchInstantBackupStatus();
//     } catch (e) {
//       _showSnackBar('เกิดข้อผิดพลาดในการเริ่มการสำรองข้อมูล: $e', Colors.red);
//     }
//   }

//   Future<void> _stopInstantBackup() async {
//     try {
//       _showSnackBar('กำลังหยุดการสำรองข้อมูลทันที...', Colors.blue);
//       await _backupService.stopInstantBackup();
//       _fetchInstantBackupStatus();
//     } catch (e) {
//       _showSnackBar('เกิดข้อผิดพลาดในการหยุดการสำรองข้อมูล: $e', Colors.red);
//     }
//   }

//   Future<void> _restoreInstantBackup(String filename) async {
//     try {
//       _showSnackBar('กำลังเรียกคืนข้อมูล...', Colors.orange);
//       await _backupService.restoreInstantBackup(filename);
//       _showSnackBar('เรียกคืนข้อมูลสำเร็จ', Colors.green);
//     } catch (e) {
//       _showSnackBar('เกิดข้อผิดพลาดในการเรียกคืนข้อมูล: $e', Colors.red);
//     }
//   }

//   Future<void> _restoreDailyData(String filename) async {
//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('กำลังเรียกคืนข้อมูลรายวัน...')));
//       await _backupService.restoreBackup(filename);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('เรียกคืนข้อมูลสำเร็จ')));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')));
//     }
//   }

//   Future<void> _restoreMonthlyData(String filename) async {
//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('กำลังเรียกคืนข้อมูลรายเดือน...')));
//       await _backupService.restoreBackup(filename);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('เรียกคืนข้อมูลสำเร็จ')));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')));
//     }
//   }

//   Future<void> _restoreYearlyData(String filename) async {
//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('กำลังเรียกคืนข้อมูลรายปี...')));
//       await _backupService.restoreBackup(filename);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('เรียกคืนข้อมูลสำเร็จ')));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')));
//     }
//   }

//   Future<void> _downloadFile(String filename) async {
//     try {
//       final response = await _backupService.downloadBackupFile(filename);
//       if (kIsWeb) {
//         final blob = response.bodyBytes;
//         final url = Uri.dataFromBytes(
//           blob,
//           mimeType: 'application/octet-stream',
//           parameters: {'filename': filename},
//         ).toString();
//         await launchUrl(Uri.parse(url));
//       } else {
//         final directory = await getApplicationDocumentsDirectory();
//         final filePath = path.join(directory.path, filename);
//         final file = File(filePath);
//         await file.writeAsBytes(response.bodyBytes);
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text('ดาวน์โหลดสำเร็จ: ${file.path}'),
//             backgroundColor: Colors.green));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('เกิดข้อผิดพลาดในการดาวน์โหลด: ${e.toString()}'),
//           backgroundColor: Colors.red));
//     }
//   }

//   Future<void> _deleteFile(String filename) async {
//     try {
//       await _backupService.deleteBackupFile(filename);
//       _showSnackBar('ลบไฟล์สำรองสำเร็จ', Colors.green);
//       _fetchBackupFiles();
//     } catch (e) {
//       _showSnackBar('เกิดข้อผิดพลาดในการลบไฟล์: ${e.toString()}', Colors.red);
//     }
//   }

//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//       ),
//     );
//   }

//   Widget _buildScheduleCard(String title, {
//     String? lastBackup,
//     String? status,
//     VoidCallback? onStart,
//     VoidCallback? onStop,
//     bool? isRunning,
//   }) {
//     Color? statusColor;
//     if (status != null) {
//       if (status.contains('Running') || status.contains('กำลังทำงาน')) {
//         statusColor = Colors.green;
//       } else if (status.contains('Waiting') || status.contains('รอการทำงาน')) {
//         statusColor = Colors.orange;
//       } else if (status.contains('Failed') || status.contains('ล้มเหลว')) {
//         statusColor = Colors.red;
//       }
//     }

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       margin: const EdgeInsets.symmetric(vertical: 10),
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 const Text('สถานะ: '),
//                 Text(
//                   status ?? 'ไม่ได้ตั้งค่า',
//                   style: TextStyle(
//                     color: statusColor,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 5),
//             Text('สำรองข้อมูลล่าสุด: ${lastBackup ?? 'ยังไม่เคยสำรอง'}'),
//             if (onStart != null && onStop != null && isRunning != null)
//               Padding(
//                 padding: const EdgeInsets.only(top: 15),
//                 child: ElevatedButton(
//                   onPressed: isRunning ? onStop : onStart,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: isRunning ? Colors.red : Colors.blue,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                     textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   child: Text(isRunning ? 'หยุด' : 'เริ่ม'),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRestoreCard(String title, List<String> files) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       margin: const EdgeInsets.symmetric(vertical: 10),
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             if (files.isEmpty)
//               const Text('ไม่มีไฟล์สำรอง'),
//             if (files.isNotEmpty)
//               ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: files.length,
//                 itemBuilder: (context, index) {
//                   final filename = files[index];
//                   return ListTile(
//                     contentPadding: EdgeInsets.zero,
//                     title: Text(filename),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Tooltip(
//                           message: 'ดาวน์โหลดไฟล์',
//                           child: IconButton(
//                             icon: const Icon(Icons.download, color: Colors.blue),
//                             onPressed: () => _downloadFile(filename),
//                           ),
//                         ),
//                         Tooltip(
//                           message: 'ลบไฟล์สำรอง',
//                           child: IconButton(
//                             icon: const Icon(Icons.delete, color: Colors.red),
//                             onPressed: () => _deleteFile(filename),
//                           ),
//                         ),
//                         Tooltip(
//                           message: 'เรียกคืนข้อมูล',
//                           child: IconButton(
//                             icon: const Icon(Icons.restore, color: Colors.green),
//                             onPressed: () => _showRestoreConfirmDialog(
//                               filename: filename,
//                               backupType: title.replaceAll('การเรียกคืน', ''),
//                               onConfirm: () {
//                                 switch (title) {
//                                   case 'การเรียกคืนข้อมูลปัจจุบัน':
//                                     _restoreInstantBackup(filename);
//                                     break;
//                                   case 'การเรียกคืนข้อมูลรายวัน':
//                                     _restoreDailyData(filename);
//                                     break;
//                                   case 'การเรียกคืนข้อมูลรายเดือน':
//                                     _restoreMonthlyData(filename);
//                                     break;
//                                   case 'การเรียกคืนข้อมูลรายปี':
//                                     _restoreYearlyData(filename);
//                                     break;
//                                 }
//                               },
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showRestoreConfirmDialog({
//     required String filename,
//     required String backupType,
//     required VoidCallback onConfirm,
//   }) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('ยืนยันการเรียกคืนข้อมูล$backupType'),
//           content: const Text(
//             'คำเตือน: การดำเนินการนี้จะแทนที่ข้อมูลปัจจุบันด้วยข้อมูลสำรองที่เลือก\n'
//             'คุณควรสำรองข้อมูลปัจจุบันไว้ก่อนดำเนินการนี้',
//             style: TextStyle(color: Colors.red),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('ยกเลิก'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 onConfirm();
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               child: const Text('ยืนยัน'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     return Padding(
//       padding: const EdgeInsets.all(20),
//       child: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _errorMessage != null
//           ? Center(child: Text('Error: $_errorMessage'))
//           : SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             _buildScheduleCard(
//               'การสำรองข้อมูลปัจจุบัน',
//               lastBackup: _instantLastBackup,
//               status: _instantStatus,
//               onStart: _startInstantBackup,
//               onStop: _stopInstantBackup,
//               isRunning: _isInstantBackupRunning,
//             ),
//             _buildRestoreCard(
//               'การเรียกคืนข้อมูลปัจจุบัน',
//               _instantFiles,
//             ),
//             _buildScheduleCard(
//               'การสำรองข้อมูลรายวัน',
//               lastBackup: _dailyLastBackup,
//               status: _dailyStatus,
//             ),
//             _buildRestoreCard(
//               'การเรียกคืนข้อมูลรายวัน',
//               _dailyFiles,
//             ),
//             _buildScheduleCard(
//               'การสำรองข้อมูลรายเดือน',
//               lastBackup: _monthlyLastBackup,
//               status: _monthlyStatus,
//             ),
//             _buildRestoreCard(
//               'การเรียกคืนข้อมูลรายเดือน',
//               _monthlyFiles,
//             ),
//             _buildScheduleCard(
//               'การสำรองข้อมูลรายปี',
//               lastBackup: _yearlyLastBackup,
//               status: _yearlyStatus,
//             ),
//             _buildRestoreCard(
//               'การเรียกคืนข้อมูลรายปี',
//               _yearlyFiles,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// lib/screens/backup_screen.dart
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/backup_schedule.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../../config/app_config.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with AutomaticKeepAliveClientMixin {
  // static const String baseUrl = 'http://localhost:3000/api/sa';
  static const String baseUrl = AppConfig.apiSa;
  final _backupService = BackupService();

  List<BackupSchedule> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Polling timers for each schedule ID
  final Map<int, Timer> _pollingTimers = {};

  // Instant
  List<String> _instantFiles = [];
  String? _selectedInstantFile;
  String? _instantLastBackup;
  String? _instantStatus;
  bool _isInstantBackupRunning = false;
  Timer? _instantBackupStatusTimer;

  // Daily
  List<bool> _dailyDaysOfWeek = List.filled(7, false);
  TimeOfDay _dailyTime = TimeOfDay.now();
  List<String> _dailyFiles = [];
  String? _selectedDailyFile;

  // Monthly
  List<bool> _monthlyMonths = List.filled(12, false);
  int _monthlyDayOfMonth = 1;
  TimeOfDay _monthlyTime = TimeOfDay.now();
  List<String> _monthlyFiles = [];
  String? _selectedMonthlyFile;

  // Yearly
  DateTime _yearlyDate = DateTime.now();
  TimeOfDay _yearlyTime = TimeOfDay.now();
  List<String> _yearlyFiles = [];
  String? _selectedYearlyFile;

  // Upload restore state
  PlatformFile? _uploadFile;
  String? _uploadTargetDatabase;
  List<String> _availableDatabases = [];
  bool _isUploadRestoring = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchDatabases();
    _startInstantBackupStatusPolling();
  }

  @override
  void dispose() {
    // for (var timer in _pollingTimers.values) {
    //   timer.cancel();
    // }
    _pollingTimers.forEach((id, timer) => timer.cancel());
    _instantBackupStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    // setState(() {
    //   _isLoading = true;
    //   _errorMessage = null;
    // });
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final schedules = await _backupService.getSchedules();
      final instantFiles = await _backupService.getBackupFiles('instant');
      final dailyFiles = await _backupService.getBackupFiles('daily');
      final monthlyFiles = await _backupService.getBackupFiles('monthly');
      final yearlyFiles = await _backupService.getBackupFiles('yearly');

      setState(() {
        _schedules = schedules;
        _instantFiles = instantFiles;
        _dailyFiles = dailyFiles;
        _monthlyFiles = monthlyFiles;
        _yearlyFiles = yearlyFiles;
      });
      _initializeControllers();
      _managePollingTimers();
    } catch (e) {
      // setState(() {
      //   _errorMessage = 'Failed to fetch data: $e';
      // });
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to fetch data: $e';
        });
      }
    } finally {
      // setState(() {
      //   _isLoading = false;
      // });
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ... (ส่วน _managePollingTimers, _startPollingForSchedule, _stopPollingForSchedule, _fetchStatus เหมือนเดิม)
  void _managePollingTimers() {
    for (final schedule in _schedules) {
      if (schedule.isRunning) {
        if (!_pollingTimers.containsKey(schedule.id)) {
          _startPollingForSchedule(schedule.id);
        }
      } else {
        if (_pollingTimers.containsKey(schedule.id)) {
          _stopPollingForSchedule(schedule.id);
        }
      }
    }
  }

  Future<void> _startInstantBackup() async {
    try {
      _showSnackBar('กำลังเริ่มการสำรองข้อมูลทันที...', Colors.blue);
      await _backupService.startInstantBackup();
      _fetchInstantBackupStatus();
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการเริ่มการสำรองข้อมูล: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _startInstantBackupStatusPolling() {
    _instantBackupStatusTimer?.cancel();
    _instantBackupStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchInstantBackupStatus();
    });
  }

  Future<void> _fetchInstantBackupStatus() async {
    try {
      final status = await _backupService.checkInstantBackupStatus();
      final wasRunning = _isInstantBackupRunning;
      final isNowRunning = status['isRunning'] ?? false;
      setState(() {
        _isInstantBackupRunning = isNowRunning;
        _instantStatus = status['status'];
        _instantLastBackup = status['lastBackup'];
      });
      // เมื่อ backup เพิ่งเสร็จ ให้โหลดรายการไฟล์ใหม่
      if (wasRunning && !isNowRunning) {
        final files = await _backupService.getBackupFiles('instant');
        if (mounted) setState(() => _instantFiles = files);
      }
    } catch (e) {
      print('Error fetching instant backup status: $e');
    }
  }

  Future<void> _stopInstantBackup() async {
    try {
      _showSnackBar('กำลังหยุดการสำรองข้อมูลทันที...', Colors.blue);
      await _backupService.stopInstantBackup();
      _fetchInstantBackupStatus();
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการหยุดการสำรองข้อมูล: $e', Colors.red);
    }
  }

  void _startPollingForSchedule(int scheduleId) {
    print('Starting polling for schedule ID: $scheduleId');
    _pollingTimers[scheduleId] =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchStatus(scheduleId);
    });
  }

  void _stopPollingForSchedule(int scheduleId) {
    print('Stopping polling for schedule ID: $scheduleId');
    _pollingTimers[scheduleId]?.cancel();
    _pollingTimers.remove(scheduleId);
  }

  Future<void> _fetchStatus(int scheduleId) async {
    try {
      final schedules = await _backupService.getSchedules();
      final wasRunning = _schedules.firstWhere((s) => s.id == scheduleId, orElse: () => schedules.firstWhere((s) => s.id == scheduleId)).isRunning;
      setState(() {
        _schedules = schedules;
      });
      final schedule = schedules.firstWhere((s) => s.id == scheduleId);
      if (!schedule.isRunning) {
        _stopPollingForSchedule(scheduleId);
        // เมื่อ backup เพิ่งเสร็จ ให้โหลดรายการไฟล์ใหม่
        if (wasRunning) {
          final files = await _backupService.getBackupFiles(schedule.scheduleType);
          if (mounted) {
            setState(() {
              if (schedule.scheduleType == 'daily') _dailyFiles = files;
              else if (schedule.scheduleType == 'monthly') _monthlyFiles = files;
              else if (schedule.scheduleType == 'yearly') _yearlyFiles = files;
            });
          }
        }
      }
    } catch (e) {
      print('Failed to fetch status: $e');
      _stopPollingForSchedule(scheduleId);
    }
  }

  // ... (ส่วน _initializeControllers, _saveSchedule, _startSchedule, _stopSchedule เหมือนเดิม)
  void _initializeControllers() {
    for (var schedule in _schedules) {
      if (schedule.scheduleType == 'daily') {
        _dailyDaysOfWeek = List.filled(7, false);
        if (schedule.dailyDaysOfWeek != null) {
          for (var day in schedule.dailyDaysOfWeek!) {
            _dailyDaysOfWeek[day] = true;
          }
        }
        _dailyTime = schedule.dailyTime ?? TimeOfDay.now();
      } else if (schedule.scheduleType == 'monthly') {
        _monthlyMonths = List.filled(12, false);
        if (schedule.monthlyMonths != null) {
          for (var month in schedule.monthlyMonths!) {
            _monthlyMonths[month - 1] = true;
          }
        }
        _monthlyDayOfMonth = schedule.monthlyDayOfMonth ?? 1;
        _monthlyTime = schedule.monthlyTime ?? TimeOfDay.now();
      } else if (schedule.scheduleType == 'yearly') {
        _yearlyDate = schedule.yearlyDate ?? DateTime.now();
        _yearlyTime = schedule.yearlyTime ?? TimeOfDay.now();
      }
    }
  }

  Future<void> _saveSchedule(String scheduleType) async {
    try {
      final scheduleToSave =
          _schedules.firstWhere((s) => s.scheduleType == scheduleType);

      if (scheduleType == 'daily') {
        scheduleToSave.dailyDaysOfWeek = _dailyDaysOfWeek
            .asMap()
            .entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList();
        scheduleToSave.dailyTime = _dailyTime;
      } else if (scheduleType == 'monthly') {
        scheduleToSave.monthlyMonths = _monthlyMonths
            .asMap()
            .entries
            .where((e) => e.value)
            .map((e) => e.key + 1)
            .toList();
        scheduleToSave.monthlyDayOfMonth = _monthlyDayOfMonth;
        scheduleToSave.monthlyTime = _monthlyTime;
      } else if (scheduleType == 'yearly') {
        scheduleToSave.yearlyDate = _yearlyDate;
        scheduleToSave.yearlyTime = _yearlyTime;
      }

      await _backupService.saveSchedule(scheduleToSave.id, scheduleToSave);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกการตั้งค่าสำเร็จ')));
      _fetchData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
    }
  }

  Future<void> _startSchedule(String scheduleType) async {
    try {
      final schedule =
          _schedules.firstWhere((s) => s.scheduleType == scheduleType);
      await _backupService.startSchedule(schedule.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('เริ่มการทำงานแล้ว')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเริ่ม: $e')));
    }
  }

  Future<void> _stopSchedule(String scheduleType) async {
    try {
      final schedule =
          _schedules.firstWhere((s) => s.scheduleType == scheduleType);
      await _backupService.stopSchedule(schedule.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('หยุดการทำงานแล้ว')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการหยุด: $e')));
    }
  }

  // *** เมธอดใหม่: จัดการการดาวน์โหลดไฟล์
  Future<void> _downloadFile(String filename) async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กำลังดาวน์โหลดไฟล์...')));
      if (kIsWeb) {
        // สำหรับเว็บ: ใช้ url_launcher เพื่อสั่งดาวน์โหลดโดยตรง
        final downloadUrl =
            Uri.parse('$baseUrl/backup/files/download/$filename');
        await launchUrl(downloadUrl, webOnlyWindowName: '_blank');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('ดาวน์โหลดสำเร็จ (เบราว์เซอร์จะจัดการการบันทึกไฟล์)')));
      } else {
        // สำหรับ Mobile และ Desktop: ใช้ path_provider
        final response = await _backupService.downloadBackupFile(filename);

        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('ไม่สามารถเข้าถึง Downloads directory ได้');
        }

        final savePath = path.join(directory.path, filename);
        final file = File(savePath);

        await file.writeAsBytes(response.bodyBytes);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ดาวน์โหลดสำเร็จ: ${file.path}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการดาวน์โหลด: $e')));
    }
  }

  // *** เมธอดใหม่: จัดการการลบไฟล์
  Future<void> _deleteFile(String filename) async {
    try {
      await _backupService.deleteBackupFile(filename);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ลบไฟล์สำเร็จ')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการลบไฟล์: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _schedules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    final dailySchedule =
        _schedules.firstWhere((s) => s.scheduleType == 'daily');
    final monthlySchedule =
        _schedules.firstWhere((s) => s.scheduleType == 'monthly');
    final yearlySchedule =
        _schedules.firstWhere((s) => s.scheduleType == 'yearly');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildUploadRestoreCard(),
          const SizedBox(height: 16),
            _buildScheduleCard(
              'สำรองข้อมูลปัจจุบัน',
              lastBackup: _instantLastBackup,
              status: _instantStatus,
              onStart: _startInstantBackup,
              onStop: _stopInstantBackup,
              isRunning: _isInstantBackupRunning,
            ),
            // _buildRestoreCard(
            //   'เรียกคืนข้อมูลปัจจุบัน',
            //   _instantFiles,
            // ),
          _buildRestoreSection(
              'เรียกคืนข้อมูลปัจจุบัน',
              _instantFiles,
              _selectedInstantFile,
              (file) => setState(() => _selectedInstantFile = file),
              (filename) => _showRestoreConfirmation(filename, 'ปัจจุบัน')),
          const SizedBox(height: 16),
          _buildBackupSection('สำรองข้อมูลรายวัน', dailySchedule),
          // const SizedBox(height: 1),
          _buildRestoreSection(
              'เรียกคืนข้อมูลรายวัน',
              _dailyFiles,
              _selectedDailyFile,
              (file) => setState(() => _selectedDailyFile = file),
              (filename) => _showRestoreConfirmation(filename, 'รายวัน')),
          const SizedBox(height: 16),
          _buildBackupSection('สำรองข้อมูลรายเดือน', monthlySchedule),
          // const SizedBox(height: 1),
          _buildRestoreSection(
              'เรียกคืนข้อมูลรายเดือน',
              _monthlyFiles,
              _selectedMonthlyFile,
              (file) => setState(() => _selectedMonthlyFile = file),
              (filename) => _showRestoreConfirmation(filename, 'รายเดือน')),
          const SizedBox(height: 16),
          _buildBackupSection('สำรองข้อมูลรายปี', yearlySchedule),
          // const SizedBox(height: 1),
          _buildRestoreSection(
              'เรียกข้อมูลคืนรายปี',
              _yearlyFiles,
              _selectedYearlyFile,
              (file) => setState(() => _selectedYearlyFile = file),
              (filename) => _showRestoreConfirmation(filename, 'รายปี')),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String title, {
    String? lastBackup,
    String? status,
    VoidCallback? onStart,
    VoidCallback? onStop,
    bool? isRunning,
  }) {
    Color? statusColor;
    if (status != null) {
      if (status.contains('Running') || status.contains('กำลังทำงาน')) {
        statusColor = Colors.green;
      } else if (status.contains('Waiting') || status.contains('รอการทำงาน')) {
        statusColor = Colors.orange;
      } else if (status.contains('Failed') || status.contains('ล้มเหลว')) {
        statusColor = Colors.red;
      }
    }
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),
            Row(
              children: [
                const Text('สถานะ: '),
                Text(
                  status ?? 'รอเริ่ม',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('สำรองข้อมูลล่าสุด: ${lastBackup ?? 'ยังไม่ได้สำรอง'}'),
            if (onStart != null && onStop != null && isRunning != null)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: ElevatedButton(
                  onPressed: isRunning ? onStop : onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? Colors.red : Colors.blue,
                    // foregroundColor: Colors.white,
                    // padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    // textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: Text(isRunning ? 'หยุด' : 'เริ่ม'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection(String title, BackupSchedule schedule) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),
            _buildScheduleForm(schedule),
            const SizedBox(height: 16),
            _buildStatusIndicator(schedule),
            const SizedBox(height: 16),
            _buildActionButtons(schedule),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleForm(BackupSchedule schedule) {
    if (schedule.scheduleType == 'daily') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เลือกวัน:', style: TextStyle(fontSize: 16)),
          Wrap(
            spacing: 8.0,
            children: List.generate(7, (index) {
              final days = [
                'อาทิตย์',
                'จันทร์',
                'อังคาร',
                'พุธ',
                'พฤหัสบดี',
                'ศุกร์',
                'เสาร์'
              ];
              return ChoiceChip(
                label: Text(days[index]),
                selected: _dailyDaysOfWeek[index],
                onSelected: schedule.isRunning
                    ? null
                    : (selected) {
                        setState(() {
                          _dailyDaysOfWeek[index] = selected;
                        });
                      },
              );
            }),
          ),
          const SizedBox(height: 16),
          _buildTimePicker(
            label: 'เลือกเวลา:',
            time: _dailyTime,
            onTimeChanged: schedule.isRunning
                ? null
                : (newTime) => setState(() => _dailyTime = newTime),
          ),
        ],
      );
    } else if (schedule.scheduleType == 'monthly') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เลือกเดือน:', style: TextStyle(fontSize: 16)),
          Wrap(
            spacing: 8.0,
            children: List.generate(12, (index) {
              final months = [
                'ม.ค.',
                'ก.พ.',
                'มี.ค.',
                'เม.ย.',
                'พ.ค.',
                'มิ.ย.',
                'ก.ค.',
                'ส.ค.',
                'ก.ย.',
                'ต.ค.',
                'พ.ย.',
                'ธ.ค.'
              ];
              return ChoiceChip(
                label: Text(months[index]),
                selected: _monthlyMonths[index],
                onSelected: schedule.isRunning
                    ? null
                    : (selected) {
                        setState(() {
                          _monthlyMonths[index] = selected;
                        });
                      },
              );
            }),
          ),
          const SizedBox(height: 16),
          _buildDropdownPicker(
            label: 'เลือกวันที่:',
            value: _monthlyDayOfMonth,
            items: List.generate(31, (index) => index + 1),
            onChanged: schedule.isRunning
                ? null
                : (value) => setState(() => _monthlyDayOfMonth = value!),
          ),
          const SizedBox(height: 16),
          _buildTimePicker(
            label: 'เลือกเวลา:',
            time: _monthlyTime,
            onTimeChanged: schedule.isRunning
                ? null
                : (newTime) => setState(() => _monthlyTime = newTime),
          ),
        ],
      );
    } else if (schedule.scheduleType == 'yearly') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDatePicker(
            label: 'เลือกวันที่:',
            date: _yearlyDate,
            onDateChanged: schedule.isRunning
                ? null
                : (newDate) => setState(() => _yearlyDate = newDate),
          ),
          const SizedBox(height: 16),
          _buildTimePicker(
            label: 'เลือกเวลา:',
            time: _yearlyTime,
            onTimeChanged: schedule.isRunning
                ? null
                : (newTime) => setState(() => _yearlyTime = newTime),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay)? onTimeChanged,
  }) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onTimeChanged != null
              ? () async {
                  final newTime =
                      await showTimePicker(context: context, initialTime: time);
                  if (newTime != null) {
                    onTimeChanged(newTime);
                  }
                }
              : null,
          child:
              Text(time.format(context), style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required Function(DateTime)? onDateChanged,
  }) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onDateChanged != null
              ? () async {
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(DateTime.now().year - 5),
                    lastDate: DateTime(DateTime.now().year + 5),
                  );
                  if (newDate != null) {
                    onDateChanged(newDate);
                  }
                }
              : null,
          child: Text(DateFormat.yMMMd().format(date),
              style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildDropdownPicker({
    required String label,
    required int value,
    required List<int> items,
    required Function(int?)? onChanged,
  }) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(BackupSchedule schedule) {
    if (schedule.isRunning) {
      if (schedule.progressPercent == 100.0) {
        _fetchData();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สถานะการทำงาน:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: schedule.progressPercent / 100,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 8),
          Text(
            '${schedule.progressPercent.toStringAsFixed(0)}% (${schedule.message})',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      );
    }

    String message = schedule.message ?? 'ยังไม่ได้เริ่ม';
    if (schedule.lastBackupTime != null) {
      final lastBackupString = DateFormat('dd MMM yyyy HH:mm')
          .format(schedule.lastBackupTime!.toLocal());
      message = 'สำรองข้อมูลครั้งล่าสุด: $lastBackupString';
    }

    return Text(
      'สถานะ: ${schedule.isRunning ? 'กำลังทำงาน...' : message}',
      style: TextStyle(
        fontSize: 16,
        color: schedule.isRunning ? Colors.green : Colors.grey[600],
      ),
    );
  }

  Widget _buildActionButtons(BackupSchedule schedule) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: schedule.isRunning
              ? null
              : () => _saveSchedule(schedule.scheduleType),
          child: const Text('บันทึก'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: schedule.isRunning
              ? null
              : () => _startSchedule(schedule.scheduleType),
          child: const Text('เริ่ม'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: schedule.isRunning
              ? () => _stopSchedule(schedule.scheduleType)
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('หยุด'),
        ),
      ],
    );
  }

  Widget _buildRestoreSection(
      String title,
      List<String> files,
      String? selectedFile,
      Function(String?) onFileSelected,
      Function(String) onRestorePressed) {
    String? selectedFile;
    if (title.contains('รายวัน')) {
      selectedFile = _selectedDailyFile;
    } else if (title.contains('รายเดือน')) {
      selectedFile = _selectedMonthlyFile;
    } else if (title.contains('รายปี')) {
      selectedFile = _selectedYearlyFile;
    } else if (title.contains('ปัจจุบัน')) {
      selectedFile = _selectedInstantFile;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),
            if (files.isEmpty)
              const Text('ไม่มีไฟล์สำรองข้อมูลที่สามารถเรียกคืนได้')
            else
              ...files.map((file) {
                String displayDate = file;

                // ชื่อไฟล์รูปแบบ: prefix_dbname_YYYY-MM-DDTHH-MM-SS.ext
                // ใช้ regex ดึง timestamp โดยตรงแทนการ split ด้วย index
                final match = RegExp(r'(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})').firstMatch(file);
                if (match != null) {
                  try {
                    final isoString = '${match.group(1)}T${match.group(2)}:${match.group(3)}:${match.group(4)}';
                    final dateTime = DateTime.parse(isoString).toLocal();
                    displayDate = DateFormat('EEE, dd MMM yyyy HH:mm:ss').format(dateTime);
                  } catch (e) {
                    print('Error parsing date from filename: $e');
                  }
                }
                return RadioListTile<String>(
                  title: Text('ไฟล์: $displayDate'),
                  value: file,
                  groupValue: selectedFile,
                  onChanged: (value) => onFileSelected(value),
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.red),
                        tooltip: "เรียกคืนข้อมูล",
                        onPressed: file == selectedFile
                            ? () => onRestorePressed(file)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: "ดาวน์โหลดไฟล์",
                        onPressed: file == selectedFile
                            ? () => _downloadFile(file)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        tooltip: "ลบไฟล์",
                        onPressed: file == selectedFile
                            ? () => _deleteFile(file)
                            : null,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchDatabases() async {
    try {
      final dbs = await AuthService().fetchDatabases();
      if (mounted) setState(() => _availableDatabases = dbs);
    } catch (_) {}
  }

  Future<void> _pickUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _uploadFile = result.files.first;
        _uploadTargetDatabase ??= AuthService().selectedDatabase;
      });
    }
  }

  Future<void> _doUploadRestore() async {
    if (_uploadFile == null || _uploadTargetDatabase == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('ยืนยันการ Restore'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลในฐานข้อมูลปลายทางจะถูกแทนที่ทั้งหมด',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('ไฟล์: ${_uploadFile!.name}'),
            Text('ฐานข้อมูลปลายทาง: $_uploadTargetDatabase'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUploadRestoring = true);
    try {
      await _backupService.restoreFromUpload(_uploadFile!, _uploadTargetDatabase!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore ไปยัง "$_uploadTargetDatabase" สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _uploadFile = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadRestoring = false);
    }
  }

  Widget _buildUploadRestoreCard() {
    return Card(
      elevation: 4,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.orange.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.upload_file, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text('Restore จากไฟล์ที่ดาวน์โหลด',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900)),
            ]),
            const SizedBox(height: 4),
            Text('สำหรับ restore ข้อมูลจากฐานข้อมูล A ไปยังฐานข้อมูล B',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const Divider(height: 20),

            // File picker
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _uploadFile?.name ?? 'ยังไม่ได้เลือกไฟล์',
                    style: TextStyle(
                      color: _uploadFile != null ? Colors.black87 : Colors.grey,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isUploadRestoring ? null : _pickUploadFile,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('เลือกไฟล์'),
              ),
            ]),
            const SizedBox(height: 12),

            // Target database dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _uploadTargetDatabase,
              decoration: const InputDecoration(
                labelText: 'ฐานข้อมูลปลายทาง',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _availableDatabases
                  .map((db) => DropdownMenuItem(value: db, child: Text(db)))
                  .toList(),
              onChanged: _isUploadRestoring
                  ? null
                  : (v) => setState(() => _uploadTargetDatabase = v),
            ),
            const SizedBox(height: 16),

            // Restore button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_uploadFile != null &&
                        _uploadTargetDatabase != null &&
                        !_isUploadRestoring)
                    ? _doUploadRestore
                    : null,
                icon: _isUploadRestoring
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.restore),
                label: Text(_isUploadRestoring ? 'กำลัง Restore...' : 'Restore ไปยังฐานข้อมูลที่เลือก'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // *** เมธอดใหม่: แสดงหน้าต่างยืนยันการเรียกคืนข้อมูล ***
  void _showRestoreConfirmation(String filename, String backupType) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ยืนยันการเรียกข้อมูลคืน $backupType'),
          content: const Text(
            'คำเตือน: การดำเนินการนี้จะแทนที่ข้อมูลปัจจุบันด้วยข้อมูลสำรองที่เลือก\n'
            'คุณควรสำรองข้อมูลปัจจุบันไว้ก่อนดำเนินการนี้',
            style: TextStyle(color: Colors.red),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _restoreData(filename, backupType);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
  }

  // *** เมธอดใหม่: ทำการเรียกคืนข้อมูลจริง ***
  Future<void> _restoreData(String filename, String backupType) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('กำลังเรียกข้อมูลคืน $backupType...')));
      await _backupService.restoreBackup(filename);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('เรียกข้อมูลคืนสำเร็จ')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเรียกข้อมูลคืน: $e')));
    }
  }
}
