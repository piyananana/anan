import '../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:path_provider/path_provider.dart'; // For getDownloadsDirectory
import 'dart:io'; // For File
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:file_picker/file_picker.dart'; // Import FilePicker for PlatformFile
import 'dart:html' as html;

import '../models/menu.dart';
import 'auth_service.dart';

class MenuService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  Future<List<Menu>> fetchMenuByUserId(int userId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_menu/user/$userId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดเมนูล้มเหลว: ${response.statusCode}');
    }
  }

  // Fetch menu IDs that a specific group has access to
  Future<List<Menu>> fetchMenuByGroupId(String? groupId) async {
    final headers = await authService.getAuthHeader();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sa_menu/group/$groupId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
      } else {
        throw Exception(
            'Failed to load group menu: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error in fetchGroupMenuById: $e');
      // Fallback to mock data or return empty set if backend call fails
      // return _mockFetchUserPermissions(groupId); // ถ้าต้องการใช้ mock เป็น fallback
      return [];
    }
  }

  Future<List<Menu>> fetchMenus() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_menu'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดเมนูล้มเหลว: ${response.statusCode}');
    }
  }

  Future<MenuContent> fetchMenuContent(int menuId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_menu/content/$menuId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return MenuContent.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('ไม่พบเนื้อหาสำหรับเมนู ID: $menuId');
    } else {
      throw Exception('การโหลดเนื้อหาเมนูล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add Menu ***
  Future<Menu> addMenu({
    int? parentId,
    required String menuName,
    required String menuType,
    String? targetPath,
    int? sortOrder,
    bool isSystem = false,
    String? contentType,
    String? contentData,
  }) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/sa_menu'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'parent_id': parentId,
        'menu_name': menuName,
        'menu_type': menuType,
        'target_path': targetPath,
        'sort_order': sortOrder,
        'is_system': isSystem,
        'content_type': contentType,
        'content_data': contentData,
      }),
    );

    if (response.statusCode == 201) {
      return Menu.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add menu. Please login again.');
    } else {
      throw Exception('Failed to add menu: ${response.body}');
    }
  }

  // *** NEW: Update Menu ***
  Future<Menu> updateMenu(
    int id, {
    required String menuName,
    required String menuType,
    String? targetPath,
    required int sortOrder,
    required bool isActive,
    bool isSystem = false,
    String? contentType,
    String? contentData,
  }) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/sa_menu/$id'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'menu_name': menuName,
        'menu_type': menuType,
        'target_path': targetPath,
        'sort_order': sortOrder,
        'is_active': isActive,
        'is_system': isSystem,
        'content_type': contentType,
        'content_data': contentData,
      }),
    );

    if (response.statusCode == 200) {
      return Menu.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update menu. Please login again.');
    } else {
      throw Exception('Failed to update menu: ${response.body}');
    }
  }

  // *** NEW: Delete Menu ***
  Future<void> deleteMenu(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/sa_menu/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete menu. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Menu not found.');
    } else {
      throw Exception('Failed to delete menu: ${response.body}');
    }
  }

  // *** NEW: Delete All Menus ***
  Future<void> deleteAllMenu() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/sa_menu/all'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception(
          'Unauthorized to delete all sa_menu. Please login again.');
    } else {
      throw Exception('Failed to delete all sa_menu: ${response.body}');
    }
  }

  // *** ปรับปรุง: Import Menus from Excel ***
  Future<void> importMenu(PlatformFile excelPlatformFile) async {
    // เปลี่ยนประเภทพารามิเตอร์
    final headers = await authService.getAuthHeader();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/sa_menu/import'),
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
      throw Exception('Unauthorized to import sa_menu. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to import sa_menu: ${errorBody['details'] ?? errorBody['message']}');
    }
  }

  // *** ปรับปรุง: Export Menus to Excel (สำหรับการดาวน์โหลดบน Web) ***
  Future<void> exportMenu() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_menu/export'),
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
              "menus_export_${DateTime.now().millisecondsSinceEpoch}.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url); // Clean up
        print('Menus exported (web download)');
      } else {
        // สำหรับ Non-Web: บันทึกไฟล์ลงใน Downloads directory (เดิม)
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory.');
        }
        final filePath =
            '${directory.path}/menus_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Menus exported to: $filePath');
      }
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to export sa_menu. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to export sa_menu: ${errorBody['message'] ?? 'Unknown error'}');
    }
  }

  // *** NEW: Get Menu Details (for Edit Form) ***
  // เนื่องจาก API /menu/:id/content ไม่ได้คืนค่า is_active, parent_id
  // เราอาจจะต้องสร้าง API ใหม่ หรือรวมข้อมูลจาก Menu Model และ MenuContent Model ใน Frontend
  // หรือปรับแก้ Backend API ให้คืนค่า menu object เต็มๆ
  // สำหรับตอนนี้ ใช้ fetchMenuContent ซึ่งคืนแค่ content ที่เกี่ยวข้อง
  // ใน MenuManagementScreen จะต้อง fetch เมนูทั้งหมด แล้วหาจาก list เอา
  // เพื่อให้ง่ายที่สุด เราจะใช้ข้อมูลจาก Menu object ที่อยู่ใน TreeView อยู่แล้ว
  // แต่ถ้าต้องการข้อมูลครบถ้วนจาก DB จริงๆ ต้องเรียก API แยก
  Future<Map<String, dynamic>> fetchMenuDetailForEdit(int menuId) async {
    final headers = await authService.getAuthHeader();
    final menuResponse = await http.get(
      Uri.parse('$baseUrl/sa_menu/$menuId'),
      headers: headers
    );
    if (menuResponse.statusCode == 200) {
      return json.decode(menuResponse.body);
    } else {
      throw Exception(
          'Failed to fetch menu details for edit: ${menuResponse.body}');
    }
  }
}
