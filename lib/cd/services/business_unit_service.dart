import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:path_provider/path_provider.dart'; // For getDownloadsDirectory
import 'dart:io'; // For File
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:file_picker/file_picker.dart'; // Import FilePicker for PlatformFile
import 'dart:html' as html;

import '../models/business_unit.dart';
import '../../sa/services/auth_service.dart';

class BusinessUnitService {
  // final String baseUrl = 'http://localhost:3000/api/gl'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiCd;
  final AuthService authService = AuthService();

  // Future<List<BusinessUnit>> fetchBusinessUnitByUserId(int userId) async {
  //   final headers = await authService.getAuthHeader();
  //   final response = await http.get(
  //     Uri.parse('$baseUrl/cd_business_unit/row/$userId'),
  //     headers: headers,
  //   );

  //   if (response.statusCode == 200) {
  //     List jsonResponse = json.decode(response.body);
  //     return jsonResponse.map((account) => BusinessUnit.fromJson(account)).toList();
  //   } else if (response.statusCode == 401) {
  //     // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
  //     // เช่น logout ผู้ใช้และพาไปหน้า Login
  //     authService.logout();
  //     throw Exception('Unauthorized. Please login again.');
  //   } else {
  //     throw Exception('การโหลดเมนูล้มเหลว: ${response.statusCode}');
  //   }
  // }

  // // Fetch account IDs that a specific group has access to
  // Future<List<BusinessUnit>> fetchBusinessUnitByGroupId(String? groupId) async {
  //   final headers = await authService.getAuthHeader();
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/cd_business_unit/group/$groupId'),
  //       headers: headers,
  //     );
  //     if (response.statusCode == 200) {
  //       List jsonResponse = json.decode(response.body);
  //       return jsonResponse.map((account) => BusinessUnit.fromJson(account)).toList();
  //     } else {
  //       throw Exception(
  //           'Failed to load group account: ${response.statusCode} ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error in fetchGroupBusinessUnitById: $e');
  //     // Fallback to mock data or return empty set if backend call fails
  //     // return _mockFetchUserPermissions(groupId); // ถ้าต้องการใช้ mock เป็น fallback
  //     return [];
  //   }
  // }

  Future<List<BusinessUnit>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_business_unit'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((rows) => BusinessUnit.fromJson(rows)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add BusinessUnit ***
  Future<BusinessUnit> addRow(BusinessUnit data) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cd_business_unit'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'bu_code': data.buCode,
        'bu_name_thai': data.buNameThai,
        'bu_name_eng': data.buNameEng,
        'parent_id': data.parentId,
        'is_control_bu': data.isControlBU,
        'is_active': data.isActive,
      }),
    );

    if (response.statusCode == 201) {
      return BusinessUnit.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add row. Please login again.');
    } else {
      throw Exception('Failed to add row: ${response.body}');
    }
  }

  // *** NEW: Update BusinessUnit ***
  Future<BusinessUnit> updateRow(BusinessUnit data) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cd_business_unit/${data.id}'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'bu_code': data.buCode,
        'bu_name_thai': data.buNameThai,
        'bu_name_eng': data.buNameEng,
        'parent_id': data.parentId,
        'is_control_bu': data.isControlBU,
        'is_active': data.isActive,
      }),
    );

    if (response.statusCode == 200) {
      return BusinessUnit.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update row. Please login again.');
    } else {
      throw Exception('Failed to update row: ${response.body}');
    }
  }

  // *** NEW: Delete BusinessUnit ***
  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_business_unit/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete row. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('BusinessUnit not found.');
    } else {
      throw Exception('Failed to delete row: ${response.body}');
    }
  }

  // *** NEW: Delete All BusinessUnits ***
  Future<void> deleteRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_business_unit'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete all rows. Please login again.');
    } else {
      throw Exception('Failed to delete all rows: ${response.body}');
    }
  }

  // *** ปรับปรุง: Import BusinessUnits from Excel ***
  Future<void> importDataExcel(PlatformFile excelPlatformFile) async {
    // เปลี่ยนประเภทพารามิเตอร์
    final headers = await authService.getAuthHeader();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/cd_business_unit/import'),
    );

    request.headers.addAll({
      'Authorization': headers['Authorization'] ?? '',
    });

    // --- Logic แยกสำหรับ Web และ Non-Web ---
    if (kIsWeb) {
      // สำหรับ Web, ใช้ bytes โดยตรงจาก PlatformFile
      request.files.add(http.MultipartFile.fromBytes(
        'excelFile', // นี่คือชื่อ field ที่ Node.js multer คาดหวัง
        excelPlatformFile.bytes!, // เข้าถึง bytes โดยตรง
        filename: excelPlatformFile.name, // ชื่อไฟล์
        contentType: MediaType('application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ));
    } else {
      // สำหรับ Non-Web (Mobile/Desktop), ใช้จาก path
      request.files.add(await http.MultipartFile.fromPath(
        'excelFile',
        excelPlatformFile.path!, // ต้องแน่ใจว่า path ไม่เป็น null บน Non-web
        contentType: MediaType('application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ));
    }
    // --- สิ้นสุด Logic แยก ---

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print('Import successful: ${response.body}');
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to import data. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to import data: ${errorBody['details'] ?? errorBody['message']}');
    }
  }

  // *** ปรับปรุง: Export BusinessUnits to Excel (สำหรับการดาวน์โหลดบน Web) ***
  Future<void> exportDataExcel() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_business_unit/export'),
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
              "accounts_export_${DateTime.now().millisecondsSinceEpoch}.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url); // Clean up
        print('Data exported (web download)');
      } else {
        // สำหรับ Non-Web: บันทึกไฟล์ลงใน Downloads directory (เดิม)
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory.');
        }
        final filePath =
            '${directory.path}/accounts_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Data exported to: $filePath');
      }
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to export data. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to export data: ${errorBody['message'] ?? 'Unknown error'}');
    }
  }

  // *** NEW: Get BusinessUnit Details (for Edit Form) ***
  // เนื่องจาก API /account/:id/content ไม่ได้คืนค่า is_active, parent_id
  // เราอาจจะต้องสร้าง API ใหม่ หรือรวมข้อมูลจาก BusinessUnit Model และ BusinessUnitContent Model ใน Frontend
  // หรือปรับแก้ Backend API ให้คืนค่า account object เต็มๆ
  // สำหรับตอนนี้ ใช้ fetchBusinessUnitContent ซึ่งคืนแค่ content ที่เกี่ยวข้อง
  // ใน BusinessUnitManagementScreen จะต้อง fetch เมนูทั้งหมด แล้วหาจาก list เอา
  // เพื่อให้ง่ายที่สุด เราจะใช้ข้อมูลจาก BusinessUnit object ที่อยู่ใน TreeView อยู่แล้ว
  // แต่ถ้าต้องการข้อมูลครบถ้วนจาก DB จริงๆ ต้องเรียก API แยก
  Future<Map<String, dynamic>> fetchDetailForEdit(int rowId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cd_business_unit/$rowId'),
        headers: headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to fetch account details for edit: ${response.body}');
    }
  }
}
