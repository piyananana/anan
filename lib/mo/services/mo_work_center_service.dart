// lib/mo/services/mo_work_center_service.dart — มิเรอร์ im_price_group_service.dart ทุกประการ
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/mo_work_center.dart';

class MoWorkCenterService {
  final String baseUrl = AppConfig.apiMo;
  final AuthService authService = AuthService();

  Future<List<MoWorkCenter>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_work_center'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoWorkCenter.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลศูนย์งานล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<MoWorkCenter>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_work_center/active'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoWorkCenter.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลศูนย์งานล้มเหลว: ${response.statusCode}');
    }
  }

  Future<MoWorkCenter> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_work_center/$id'), headers: headers);
    if (response.statusCode == 200) {
      return MoWorkCenter.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลศูนย์งานล้มเหลว: ${response.statusCode}');
    }
  }

  Future<MoWorkCenter> addRow(MoWorkCenter row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/mo_work_center'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return MoWorkCenter.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<MoWorkCenter> updateRow(MoWorkCenter row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/mo_work_center/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return MoWorkCenter.fromJson(json.decode(response.body));
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
    final response = await http.delete(Uri.parse('$baseUrl/mo_work_center/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }

  Future<List<MoWorkCenterEfficiencyRow>> fetchEfficiencyReport({
    String? status,
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (warehouseId != null) params['warehouse_id'] = warehouseId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/mo_work_center/report/efficiency').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoWorkCenterEfficiencyRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load work center efficiency report: ${response.body}');
  }
}
