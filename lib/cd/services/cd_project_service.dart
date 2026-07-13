import '../../../config/app_config.dart';
// services/cd_project_service.dart
import 'dart:convert';
import 'dart:io';
// import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:http/http.dart' as http;
import 'dart:html' as html;
// import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import '../../sa/services/sa_auth_service.dart';

import '../models/cd_project.dart';

class ProjectService {
  // final String baseUrl = 'http://localhost:3000/api/cd'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiCd;
  final AuthService authService = AuthService();

  Future<List<Project>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_project'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lists) => Project.fromJson(lists)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลโครงการล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<Project>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_project/active'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lists) => Project.fromJson(lists)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลโครงการล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add Project ***
  Future<Project> addRow(Project row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cd_project'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'project_code': row.projectCode,
        'project_name_thai': row.projectNameThai,
        'project_name_eng': row.projectNameEng,
        'is_active': row.isActive,
        'start_date': row.startDate?.toIso8601String().split('T')[0],
        'end_date': row.endDate?.toIso8601String().split('T')[0],
      }),
    );

    if (response.statusCode == 201) {
      return Project.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data. Please login again.');
    } else {
      throw Exception('Failed to add data: ${response.body}');
    }
  }

  // *** NEW: Update Project ***
  Future<Project> updateRow(Project row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cd_project/${row.id}'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'project_code': row.projectCode,
        'project_name_thai': row.projectNameThai,
        'project_name_eng': row.projectNameEng,
        'is_active': row.isActive,
        'start_date': row.startDate?.toIso8601String().split('T')[0],
        'end_date': row.endDate?.toIso8601String().split('T')[0],
      }),
    );

    if (response.statusCode == 200) {
      return Project.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update data. Please login again.');
    } else {
      throw Exception('Failed to update data: ${response.body}');
    }
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_project/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Project not found.');
    } else {
      throw Exception('Failed to delete data: ${response.body}');
    }
  }

  Future<void> deleteRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_project'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete all data Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Project not found.');
    } else {
      throw Exception('Failed to delete all data: ${response.body}');
    }
  }

  // *** ปรับปรุง: Export Menus to Excel (สำหรับการดาวน์โหลดบน Web) ***
  Future<void> exportDataExcel() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_project/export'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;

      if (kIsWeb) {
        // สำหรับ Flutter Web: ดาวน์โหลดผ่าน Browser
        final blob = html.Blob([bytes]); // ต้อง import dart:html as html;
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download",
              "project_export_${DateTime.now().millisecondsSinceEpoch}.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url); // Clean up
        print('Project exported (web download)');
      } else {
        // สำหรับ Non-Web: บันทึกไฟล์ลงใน Downloads directory (เดิม)
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory.');
        }
        final filePath =
            '${directory.path}/project_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Project exported to: $filePath');
      }
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to export cd_project. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to export cd_project: ${errorBody['message'] ?? 'Unknown error'}');
    }
  }

}
