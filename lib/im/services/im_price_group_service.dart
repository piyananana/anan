// lib/im/services/im_price_group_service.dart — มิเรอร์ im_uom_service.dart ทุกประการ
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_price_group.dart';

class ImPriceGroupService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImPriceGroup>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_group'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceGroup.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลกลุ่มราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImPriceGroup>> fetchActiveRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_group/active'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceGroup.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลกลุ่มราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImPriceGroup> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_group/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImPriceGroup.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลกลุ่มราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImPriceGroup> addRow(ImPriceGroup row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_price_group'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImPriceGroup.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ImPriceGroup> updateRow(ImPriceGroup row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_price_group/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImPriceGroup.fromJson(json.decode(response.body));
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
    final response = await http.delete(Uri.parse('$baseUrl/im_price_group/$id'), headers: headers);
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
