import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_item.dart';

class ImItemService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImItem>> fetchRows({String? keyword, bool withStock = false}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_item').replace(
      queryParameters: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (withStock) 'with_stock': '1',
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImItem.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImItem> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_item/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImItem.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  // สรุปสต็อก/บัญชีของสินค้า (หน้าจอข้อมูลสินค้า)
  Future<ImItemSummary> fetchSummary(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_item/$id/summary'), headers: headers);
    if (response.statusCode == 200) return ImItemSummary.fromJson(json.decode(response.body));
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    }
    throw Exception('โหลดสรุปสินค้าล้มเหลว: ${response.statusCode}');
  }

  // หน่วยที่เลือกได้ในบรรทัดเอกสาร — purpose: PURCHASE | SALES | PRODUCTION | COUNT | REPORT (null = ทุกหน่วยที่เปิดใช้งาน)
  Future<ImItemUoms> fetchItemUoms(int itemId, {String? purpose}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_item/$itemId/uoms').replace(queryParameters: purpose == null ? null : {'purpose': purpose});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) return ImItemUoms.fromJson(json.decode(response.body));
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    }
    throw Exception('โหลดหน่วยของสินค้าล้มเหลว: ${response.statusCode}');
  }

  Future<ImItem> addRow(ImItem row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_item'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImItem.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ImItem> updateRow(ImItem row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_item/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImItem.fromJson(json.decode(response.body));
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
    final response = await http.delete(Uri.parse('$baseUrl/im_item/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }
}
