import '../../config/app_config.dart';
// lib/services/backup_service.dart

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/backup_schedule.dart';
import 'auth_service.dart';

class BackupService {
  // static const String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนเป็น IP/Domain ของ Backend ของคุณ
  static const String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  Future<List<BackupSchedule>> getSchedules() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/backup/schedules'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BackupSchedule.fromJson(json)).toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load backup schedules with status: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getScheduleStatus(int scheduleId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/backup/schedules/status/$scheduleId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to get schedule status with status: ${response.statusCode}');
    }
  }

  Future<void> updateSchedule(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/schedules/$id'),
      headers: headers,
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update schedule with status: ${response.statusCode}');
    }
  }

  Future<List<String>> getBackupFiles(String scheduleType) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/backup/files/$scheduleType'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<String>();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load backup files with status: ${response.statusCode}');
    }
  }

  Future<void> restoreBackup(String filename) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/restore'),
      headers: headers,
      body: json.encode({'filename': filename}),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to restore backup with status: ${response.statusCode}');
    }
  }

  Future<http.Response> downloadBackupFile(String filename) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/backup/files/download/$filename'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return response;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to download file with status: ${response.statusCode}');
    }
  }

  Future<void> deleteBackupFile(String filename) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/backup/files/$filename'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete backup file with status: ${response.statusCode}');
    }
  }

  // New Methods for Instant Backup
  Future<void> startInstantBackup() async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/instant/start'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to start instant backup with status: ${response.statusCode}');
    }
  }

  Future<void> stopInstantBackup() async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/instant/stop'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to stop instant backup with status: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> checkInstantBackupStatus() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/backup/instant/status'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to check instant backup status with status: ${response.statusCode}');
    }
  }

  Future<void> restoreInstantBackup(String filename) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/instant/restore'),
      headers: headers,
      body: json.encode({'filename': filename}),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to restore instant backup with status: ${response.statusCode}');
    }
  }

  /// Upload ไฟล์ .backup จากเครื่อง client แล้ว restore ไปยัง targetDatabase
  Future<void> restoreFromUpload(PlatformFile file, String targetDatabase) async {
    final authHeaders = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/backup/restore-from-upload');
    final request = http.MultipartRequest('POST', uri);

    // ใส่ header ยกเว้น Content-Type (multipart จัดการเอง)
    authHeaders.forEach((key, value) {
      if (key.toLowerCase() != 'content-type') request.headers[key] = value;
    });

    request.fields['targetDatabase'] = targetDatabase;

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'backupFile', file.bytes!, filename: file.name,
      ));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'backupFile', file.path!, filename: file.name,
      ));
    } else {
      throw Exception('ไม่สามารถอ่านไฟล์ได้');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Restore failed: ${response.statusCode}');
    }
  }

  Future<void> saveSchedule(int id, BackupSchedule schedule) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/schedules/$id'),
      headers: headers,
      body: json.encode(schedule.toJson()),
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to save backup schedule with status: ${response.statusCode}');
    }
  }

  Future<void> startSchedule(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/schedules/$id/start'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to start backup schedule with status: ${response.statusCode}');
      // throw Exception('Failed to start backup schedule');
    }
  }

  Future<void> stopSchedule(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/backup/schedules/$id/stop'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to stop backup schedule with status: ${response.statusCode}');
      // throw Exception('Failed to stop backup schedule');
    }
  }

}


// // lib/services/backup_service.dart

// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/backup_schedule.dart';
// import 'auth_service.dart';

// class BackupService {

//   // static const String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนเป็น IP/Domain ของ Backend ของคุณ
//   static const String baseUrl = AppConfig.apiSa;
//   final AuthService authService = AuthService();

//   // Map<String, String> getHeaders() {
//   //   // Replace with your actual logic for authentication headers
//   //   return {
//   //     'Content-Type': 'application/json',
//   //     // 'Authorization': 'Bearer your_token', // Uncomment and set token if needed
//   //   };
//   // }

//   Future<List<BackupSchedule>> getSchedules() async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.get(
//       Uri.parse('$baseUrl/backup/schedules'),
//       headers: headers,
//     );
//     if (response.statusCode == 200) {
//       final List<dynamic> data = json.decode(response.body);
//       return data.map((json) => BackupSchedule.fromJson(json)).toList();
//     } else {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to load backup schedules with status: ${response.statusCode}');
//       // throw Exception('Failed to load backup schedules');
//     }
//   }

//   // Future<BackupStatus> getStatus() async {
//   //   final response = await http.get(
//   //     Uri.parse('$baseUrl/backup/status'),
//   //     headers: getHeaders(),
//   //   );
//   //   if (response.statusCode == 200) {
//   //     return BackupStatus.fromJson(json.decode(response.body));
//   //   } else {
//   //     throw Exception('Failed to load backup status');
//   //   }
//   // }

//   Future<void> saveSchedule(int id, BackupSchedule schedule) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.post(
//       Uri.parse('$baseUrl/backup/schedules/$id'),
//       headers: headers,
//       body: json.encode(schedule.toJson()),
//     );
//     if (response.statusCode != 200) {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to save backup schedule with status: ${response.statusCode}');
//       // throw Exception('Failed to save backup schedule');
//     }
//   }

//   Future<void> startSchedule(int id) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.post(
//       Uri.parse('$baseUrl/backup/schedules/$id/start'),
//       headers: headers,
//     );
//     if (response.statusCode != 200) {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to start backup schedule with status: ${response.statusCode}');
//       // throw Exception('Failed to start backup schedule');
//     }
//   }

//   Future<void> stopSchedule(int id) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.post(
//       Uri.parse('$baseUrl/backup/schedules/$id/stop'),
//       headers: headers,
//     );
//     if (response.statusCode != 200) {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to stop backup schedule with status: ${response.statusCode}');
//       // throw Exception('Failed to stop backup schedule');
//     }
//   }

//   // *** เมธอดใหม่: ดึงรายชื่อไฟล์สำรองข้อมูล ***
//   Future<List<String>> getBackupFiles(String scheduleType) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.get(
//       Uri.parse('$baseUrl/backup/files/$scheduleType'),
//       headers: headers,
//     );
//     if (response.statusCode == 200) {
//       final List<dynamic> data = json.decode(response.body);
//       return data.cast<String>();
//     } else {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to load backup files with status: ${response.statusCode}');
//     }
//   }

//   // *** เมธอดใหม่: เรียกคืนข้อมูล ***
//   Future<void> restoreBackup(String filename) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.post(
//       Uri.parse('$baseUrl/backup/restore'),
//       headers: headers,
//       body: json.encode({'filename': filename}),
//     );
//     if (response.statusCode != 200) {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to restore backup with status: ${response.statusCode}');
//     }
//   }

//   // *** เมธอดใหม่: ดาวน์โหลดไฟล์
//   Future<http.Response> downloadBackupFile(String filename) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.get(
//       Uri.parse('$baseUrl/backup/files/download/$filename'),
//       headers: headers,
//     );
//     if (response.statusCode == 200) {
//       return response;
//     } else {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to download file with status: ${response.statusCode}');
//     }
//   }

//   // *** เมธอดใหม่: ลบไฟล์
//   Future<void> deleteBackupFile(String filename) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.delete(
//       Uri.parse('$baseUrl/backup/files/$filename'),
//       headers: headers,
//     );
//     if (response.statusCode != 200) {
//       final errorData = json.decode(response.body);
//       throw Exception(errorData['message'] ?? 'Failed to delete file with status: ${response.statusCode}');
//     }
//   }

// }