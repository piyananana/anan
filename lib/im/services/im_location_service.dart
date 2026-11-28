import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_location.dart';

class ImLocationService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImLocation>> fetchRows({int? warehouseId, bool? active, bool withUsage = false}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (warehouseId != null) params['warehouse_id'] = '$warehouseId';
    if (withUsage) params['with_usage'] = '1';
    if (active != null) params['active'] = '$active';
    final uri = Uri.parse('$baseUrl/im_location').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImLocation.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลผังตำแหน่งจัดเก็บล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImLocation>> fetchActiveRows({int? warehouseId}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (warehouseId != null) params['warehouse_id'] = '$warehouseId';
    final uri = Uri.parse('$baseUrl/im_location/active').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImLocation.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลผังตำแหน่งจัดเก็บล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImLocation> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_location/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImLocation.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลตำแหน่งจัดเก็บล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImLocation> addRow(ImLocation row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_location'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImLocation.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ImLocation> updateRow(ImLocation row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_location/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImLocation.fromJson(json.decode(response.body));
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
    final response = await http.delete(Uri.parse('$baseUrl/im_location/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }

  // ── หน้าจอตำแหน่งจัดเก็บ (user 2026-11-25) ──
  Future<ImLocationSummary> fetchSummary(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_location/$id/summary'), headers: headers);
    if (response.statusCode == 200) return ImLocationSummary.fromJson(json.decode(response.body));
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    }
    throw Exception('โหลดสรุปตำแหน่งจัดเก็บล้มเหลว: ${response.statusCode}');
  }

  /// ย้ายไปอยู่ใต้กลุ่ม parentId (null = ระดับบนสุด) ในคลังเดียวกัน
  Future<void> moveNode(int id, int? parentId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_location/$id/move'), headers: headers, body: jsonEncode({'parent_id': parentId}));
    if (response.statusCode == 200) return;
    String msg = 'ย้ายตำแหน่งไม่สำเร็จ (${response.statusCode})';
    try { msg = (json.decode(response.body) as Map<String, dynamic>)['message'] ?? msg; } catch (_) {}
    throw Exception(msg);
  }
}
