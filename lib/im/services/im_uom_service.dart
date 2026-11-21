import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_uom.dart';
import '../models/im_uom_standard_conversion.dart';

class ImUomService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImUom>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_uom'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImUom.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลหน่วยนับล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImUom>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_uom/active'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImUom.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลหน่วยนับล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImUom> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_uom/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImUom.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลหน่วยนับล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImUom> addRow(ImUom row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_uom'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImUom.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ImUom> updateRow(ImUom row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_uom/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImUom.fromJson(json.decode(response.body));
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
    final response = await http.delete(Uri.parse('$baseUrl/im_uom/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }

  // ── อัตราแปลงมาตรฐาน (ไม่ขึ้นกับสินค้า) ──────────────────────────────
  Never _fail(http.Response r, String fallback) {
    if (r.statusCode == 401 || r.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    }
    String? msg;
    try { msg = (json.decode(r.body) as Map)['message']?.toString(); } catch (_) {}
    throw Exception(msg ?? '$fallback: ${r.statusCode}');
  }

  Future<List<ImUomStandardConversion>> fetchStdConversions({int? uomId}) async {
    final headers = await authService.getAuthHeader();
    final q = uomId != null ? '?uom_id=$uomId' : '';
    final r = await http.get(Uri.parse('$baseUrl/im_uom_standard_conversion$q'), headers: headers);
    if (r.statusCode == 200) {
      return (json.decode(r.body) as List).map((e) => ImUomStandardConversion.fromJson(e)).toList();
    }
    _fail(r, 'โหลดอัตราแปลงมาตรฐานล้มเหลว');
  }

  Future<ImUomStandardConversion> saveStdConversion(ImUomStandardConversion row) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode(row.toJson());
    final r = row.id == 0
        ? await http.post(Uri.parse('$baseUrl/im_uom_standard_conversion'), headers: headers, body: body)
        : await http.put(Uri.parse('$baseUrl/im_uom_standard_conversion/${row.id}'), headers: headers, body: body);
    if (r.statusCode == 200 || r.statusCode == 201) {
      return ImUomStandardConversion.fromJson(json.decode(r.body));
    }
    _fail(r, 'บันทึกอัตราแปลงมาตรฐานล้มเหลว');
  }

  Future<void> deleteStdConversion(int id) async {
    final headers = await authService.getAuthHeader();
    final r = await http.delete(Uri.parse('$baseUrl/im_uom_standard_conversion/$id'), headers: headers);
    if (r.statusCode == 204) return;
    _fail(r, 'ลบอัตราแปลงมาตรฐานล้มเหลว');
  }
}
