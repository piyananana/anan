// services/ar_customer_group_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/ar_customer_group.dart';

class ArCustomerGroupService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService authService = AuthService();

  Future<List<ArCustomerGroup>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_customer_group'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((item) => ArCustomerGroup.fromJson(item))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลกลุ่มลูกค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ArCustomerGroup>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_customer_group/active'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((item) => ArCustomerGroup.fromJson(item))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลกลุ่มลูกค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ArCustomerGroup> addRow(ArCustomerGroup row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/ar_customer_group'),
      headers: headers,
      body: jsonEncode({
        'group_code': row.groupCode,
        'group_name_thai': row.groupNameThai,
        'group_name_eng': row.groupNameEng,
        'description': row.description,
        'credit_days': row.creditDays,
        'credit_limit': row.creditLimit,
        'discount_percent': row.discountPercent,
        'gl_account_id': row.glAccountId,
        'is_active': row.isActive,
      }),
    );

    if (response.statusCode == 201) {
      return ArCustomerGroup.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data. Please login again.');
    } else {
      throw Exception('Failed to add data: ${response.body}');
    }
  }

  Future<ArCustomerGroup> updateRow(ArCustomerGroup row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/ar_customer_group/${row.id}'),
      headers: headers,
      body: jsonEncode({
        'group_code': row.groupCode,
        'group_name_thai': row.groupNameThai,
        'group_name_eng': row.groupNameEng,
        'description': row.description,
        'credit_days': row.creditDays,
        'credit_limit': row.creditLimit,
        'discount_percent': row.discountPercent,
        'gl_account_id': row.glAccountId,
        'is_active': row.isActive,
      }),
    );

    if (response.statusCode == 200) {
      return ArCustomerGroup.fromJson(json.decode(response.body));
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
      Uri.parse('$baseUrl/ar_customer_group/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Customer group not found.');
    } else if (response.statusCode == 409) {
      final body = json.decode(response.body);
      throw Exception(body['error'] ?? 'ไม่สามารถลบได้ เนื่องจากมีลูกค้าอ้างอิง');
    } else {
      throw Exception('Failed to delete data: ${response.body}');
    }
  }

  Future<void> deleteRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/ar_customer_group'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete all data. Please login again.');
    } else {
      throw Exception('Failed to delete all data: ${response.body}');
    }
  }
}
