import '../../../config/app_config.dart';
// services/cd_branch_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import '../../sa/services/sa_auth_service.dart';

import '../models/cd_branch.dart';

class BranchService {
  // final String baseUrl = 'http://localhost:3000/api/cd'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiCd;
  final AuthService authService = AuthService();

  Future<List<Branch>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_branch'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lists) => Branch.fromJson(lists)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลโครงการล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<Branch>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_branch/active'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lists) => Branch.fromJson(lists)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลโครงการล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add Branch ***
  Future<Branch> addRow(Branch row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cd_branch'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'branch_code': row.branchCode,
        'branch_name_thai': row.branchNameThai,
        'branch_name_eng': row.branchNameEng,
        'is_active': row.isActive,
        'address_no':  row.addressNo,
        'address_building_village':  row.addressBuildingVillage,
        'address_soi':  row.addressSoi,
        'address_road':  row.addressRoad,
        'address_sub_district':  row.addressSubDistrict,
        'address_district':  row.addressDistrict,
        'address_province':  row.addressProvince,
        'address_country':  row.addressCountry,
        'address_zip_code':  row.addressZipCode,
        'phone_number':  row.phoneNumber,
        'fax_number':  row.faxNumber,
        'primary_contact_person':  row.primaryContactPerson,
      }),
    );

    if (response.statusCode == 201) {
      return Branch.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data. Please login again.');
    } else {
      throw Exception('Failed to add data: ${response.body}');
    }
  }

  // *** NEW: Update Branch ***
  Future<Branch> updateRow(Branch row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cd_branch/${row.id}'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'branch_code': row.branchCode,
        'branch_name_thai': row.branchNameThai,
        'branch_name_eng': row.branchNameEng,
        'is_active': row.isActive,
        'address_no':  row.addressNo,
        'address_building_village':  row.addressBuildingVillage,
        'address_soi':  row.addressSoi,
        'address_road':  row.addressRoad,
        'address_sub_district':  row.addressSubDistrict,
        'address_district':  row.addressDistrict,
        'address_province':  row.addressProvince,
        'address_country':  row.addressCountry,
        'address_zip_code':  row.addressZipCode,
        'phone_number':  row.phoneNumber,
        'fax_number':  row.faxNumber,
        'primary_contact_person':  row.primaryContactPerson,
      }),
    );

    if (response.statusCode == 200) {
      return Branch.fromJson(json.decode(response.body));
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
      Uri.parse('$baseUrl/cd_branch/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Branch not found.');
    } else {
      throw Exception('Failed to delete data: ${response.body}');
    }
  }

  Future<void> deleteRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_branch'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete all data Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Branch not found.');
    } else {
      throw Exception('Failed to delete all data: ${response.body}');
    }
  }

  // *** ปรับปรุง: Export Menus to Excel (สำหรับการดาวน์โหลดบน Web) ***
  Future<void> exportDataExcel() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_branch/export'),
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
              "branch_export_${DateTime.now().millisecondsSinceEpoch}.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url); // Clean up
        print('Branch exported (web download)');
      } else {
        // สำหรับ Non-Web: บันทึกไฟล์ลงใน Downloads directory (เดิม)
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory.');
        }
        final filePath =
            '${directory.path}/branch_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Branch exported to: $filePath');
      }
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to export cd_branch. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to export cd_branch: ${errorBody['message'] ?? 'Unknown error'}');
    }
  }

}
