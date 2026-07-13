// services/business_type_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/business_type.dart';

class BusinessTypeService {
  final String baseUrl = AppConfig.apiCd;
  final AuthService authService = AuthService();

  Future<List<BusinessType>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_business_type'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((item) => BusinessType.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลประเภทธุรกิจล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<BusinessType>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_business_type/active'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((item) => BusinessType.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลประเภทธุรกิจล้มเหลว: ${response.statusCode}');
    }
  }

  Future<BusinessType> addRow(BusinessType row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cd_business_type'),
      headers: headers,
      body: jsonEncode({
        'business_type_code': row.businessTypeCode,
        'business_type_name_thai': row.businessTypeNameThai,
        'business_type_name_eng': row.businessTypeNameEng,
        'description': row.description,
        'is_active': row.isActive,
      }),
    );

    if (response.statusCode == 201) {
      return BusinessType.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data. Please login again.');
    } else {
      throw Exception('Failed to add data: ${response.body}');
    }
  }

  Future<BusinessType> updateRow(BusinessType row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cd_business_type/${row.id}'),
      headers: headers,
      body: jsonEncode({
        'business_type_code': row.businessTypeCode,
        'business_type_name_thai': row.businessTypeNameThai,
        'business_type_name_eng': row.businessTypeNameEng,
        'description': row.description,
        'is_active': row.isActive,
      }),
    );

    if (response.statusCode == 200) {
      return BusinessType.fromJson(json.decode(response.body));
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
      Uri.parse('$baseUrl/cd_business_type/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Business type not found.');
    } else {
      throw Exception('Failed to delete data: ${response.body}');
    }
  }

  Future<void> deleteRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_business_type'),
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
