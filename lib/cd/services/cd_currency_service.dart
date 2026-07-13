import '../../../config/app_config.dart';
// services/cd_currency_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import '../../sa/services/sa_auth_service.dart';

import '../models/cd_currency.dart';

class CurrencyService {
  // final String baseUrl = 'http://localhost:3000/api/cd'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiCd;
  final AuthService authService = AuthService();

  // Cache สกุลเงินหลัก (base currency) — โหลดครั้งเดียว
  String? _cachedBaseCurrencyCode;

  /// คืนรหัสสกุลเงินหลัก (baseCurrencyFlag = true) พร้อม cache
  Future<String> getBaseCurrencyCode() async {
    if (_cachedBaseCurrencyCode != null) return _cachedBaseCurrencyCode!;
    try {
      final currencies = await fetchActiveRows();
      _cachedBaseCurrencyCode = currencies
          .cast<Currency?>()
          .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
          ?.currencyCode;
    } catch (_) {}
    return _cachedBaseCurrencyCode ?? 'THB';
  }

  /// ล้าง cache เมื่อมีการแก้ไขข้อมูลสกุลเงิน
  void clearBaseCurrencyCache() => _cachedBaseCurrencyCode = null;

  Future<List<Currency>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_currency'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lists) => Currency.fromJson(lists)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลสกุลเงินล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<Currency>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_currency/active'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lists) => Currency.fromJson(lists)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลสกุลเงินล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add Currency ***
  Future<Currency> addRow(Currency row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cd_currency'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'currency_code': row.currencyCode,
        'currency_name_th': row.currencyNameThai,
        'currency_name_en': row.currencyNameEng,
        'base_rate': row.baseRate,
        'base_currency_flag': row.baseCurrencyFlag,
        'symbol': row.symbol,
        'num_of_decimal': row.numOfDecimal,
        'is_active': row.isActive,
      }),
    );

    if (response.statusCode == 201) {
      clearBaseCurrencyCache();
      return Currency.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data. Please login again.');
    } else {
      throw Exception('Failed to add data: ${response.body}');
    }
  }

  // *** NEW: Update Currency ***
  Future<Currency> updateRow(Currency row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cd_currency/${row.id}'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'currency_code': row.currencyCode,
        'currency_name_th': row.currencyNameThai,
        'currency_name_en': row.currencyNameEng,
        'base_rate': row.baseRate,
        'base_currency_flag': row.baseCurrencyFlag,
        'symbol': row.symbol,
        'num_of_decimal': row.numOfDecimal,
        'is_active': row.isActive,
      }),
    );

    if (response.statusCode == 200) {
      clearBaseCurrencyCache();
      return Currency.fromJson(json.decode(response.body));
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
      Uri.parse('$baseUrl/cd_currency/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Currency not found.');
    } else {
      throw Exception('Failed to delete data: ${response.body}');
    }
  }

  Future<void> deleteRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_currency'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete all data Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Currency not found.');
    } else {
      throw Exception('Failed to delete all data: ${response.body}');
    }
  }

  Future<void> importDataExcel(PlatformFile excelPlatformFile) async {
    final headers = await authService.getAuthHeader();
    var request = http.MultipartRequest('POST',
      Uri.parse('$baseUrl/cd_currency/import'),
    );
    request.headers.addAll(headers);

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
  Future<void> exportDataExcel() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_currency/export'),
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
              "currency_export_${DateTime.now().millisecondsSinceEpoch}.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url); // Clean up
        print('Currency exported (web download)');
      } else {
        // สำหรับ Non-Web: บันทึกไฟล์ลงใน Downloads directory (เดิม)
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory.');
        }
        final filePath =
            '${directory.path}/currency_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Currency exported to: $filePath');
      }
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to export cd_currency. Please login again.');
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to export cd_currency: ${errorBody['message'] ?? 'Unknown error'}');
    }
  }

}
