import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_item_category.dart';

class ImItemCategoryService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImItemCategory>> fetchRows({bool withUsage = false}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_item_category${withUsage ? '?with_usage=1' : ''}'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImItemCategory.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลหมวดหมู่สินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImItemCategory>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_item_category/active'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImItemCategory.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลหมวดหมู่สินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImItemCategory> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_item_category/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImItemCategory.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลหมวดหมู่สินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImItemCategory> addRow(ImItemCategory row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_item_category'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImItemCategory.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ImItemCategory> updateRow(ImItemCategory row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_item_category/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImItemCategory.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/im_item_category/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }

  // ── หน้าจอหมวดหมู่ (user 2026-11-25) ──
  Future<ImCategorySummary> fetchSummary(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_item_category/$id/summary'), headers: headers);
    if (response.statusCode == 200) return ImCategorySummary.fromJson(json.decode(response.body));
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    }
    throw Exception('โหลดสรุปหมวดหมู่ล้มเหลว: ${response.statusCode}');
  }

  /// ย้ายไปอยู่ใต้ parentId (null = ระดับบนสุด)
  Future<void> moveNode(int id, int? parentId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_item_category/$id/move'), headers: headers, body: jsonEncode({'parent_id': parentId}));
    if (response.statusCode == 200) return;
    String msg = 'ย้ายหมวดหมู่ไม่สำเร็จ (${response.statusCode})';
    try { msg = (json.decode(response.body) as Map<String, dynamic>)['message'] ?? msg; } catch (_) {}
    throw Exception(msg);
  }
}
