// lib/ap/services/ap_vendor_group_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ap_vendor_group.dart';

class ApVendorGroupService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService _auth = AuthService();

  Future<List<ApVendorGroup>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ap_vendor_group'), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).map((e) => ApVendorGroup.fromJson(e)).toList();
    }
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดกลุ่มผู้ขายล้มเหลว: ${res.statusCode}');
  }

  Future<List<ApVendorGroup>> fetchActiveRows() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ap_vendor_group/active'), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).map((e) => ApVendorGroup.fromJson(e)).toList();
    }
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดกลุ่มผู้ขายล้มเหลว: ${res.statusCode}');
  }

  Future<ApVendorGroup> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ap_vendor_group/$id'), headers: headers);
    if (res.statusCode == 200) return ApVendorGroup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดกลุ่มผู้ขายล้มเหลว: ${res.statusCode}');
  }

  Future<ApVendorGroup> addRow(ApVendorGroup row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/ap_vendor_group'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (res.statusCode == 201) return ApVendorGroup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('เพิ่มกลุ่มผู้ขายล้มเหลว: ${res.body}');
  }

  Future<ApVendorGroup> updateRow(ApVendorGroup row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(
      Uri.parse('$baseUrl/ap_vendor_group/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (res.statusCode == 200) return ApVendorGroup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('แก้ไขกลุ่มผู้ขายล้มเหลว: ${res.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/ap_vendor_group/$id'), headers: headers);
    if (res.statusCode == 204) return;
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    if (res.statusCode == 409) {
      final body = json.decode(res.body);
      throw Exception(body['error'] ?? 'ไม่สามารถลบได้ เนื่องจากมีผู้ขายอ้างอิง');
    }
    throw Exception('ลบกลุ่มผู้ขายล้มเหลว: ${res.statusCode}');
  }
}
