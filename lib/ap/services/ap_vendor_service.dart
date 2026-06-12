import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/ap_vendor.dart';

class ApVendorService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService authService = AuthService();

  Future<List<ApVendor>> fetchRows({String? search}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ap_vendor').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApVendor.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลเจ้าหนี้ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ApVendor>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ap_vendor/active'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApVendor.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลเจ้าหนี้ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ApVendor> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ap_vendor/$id'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ApVendor.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลเจ้าหนี้ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ApVendor> addRow(ApVendor row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/ap_vendor'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ApVendor.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ApVendor> updateRow(ApVendor row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/ap_vendor/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ApVendor.fromJson(json.decode(response.body));
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
    final response = await http.delete(
      Uri.parse('$baseUrl/ap_vendor/$id'),
      headers: headers,
    );
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
