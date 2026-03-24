// lib/ar/services/ar_collector_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/ar_collector.dart';

class ArCollectorService {
  final String _base = AppConfig.apiAr;
  final AuthService _auth = AuthService();

  Future<List<ArCollector>> fetchRows({String? search, bool? activeOnly}) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (activeOnly == true) params['active_only'] = 'true';
    final uri = Uri.parse('$_base/ar_collector')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ArCollector.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลผู้วางบิล/รับชำระล้มเหลว: ${response.statusCode}');
  }

  Future<ArCollector> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final response =
        await http.get(Uri.parse('$_base/ar_collector/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ArCollector.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลล้มเหลว: ${response.statusCode}');
  }

  Future<ArCollector> addRow(ArCollector row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_base/ar_collector'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ArCollector.fromJson(json.decode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('เพิ่มข้อมูลล้มเหลว: ${response.body}');
  }

  Future<ArCollector> updateRow(ArCollector row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(
      Uri.parse('$_base/ar_collector/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ArCollector.fromJson(json.decode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('บันทึกข้อมูลล้มเหลว: ${response.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final response =
        await http.delete(Uri.parse('$_base/ar_collector/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('ลบข้อมูลล้มเหลว: ${response.body}');
  }
}
