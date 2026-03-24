// lib/cd/services/salesperson_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/salesperson.dart';

class SalespersonService {
  final String _base = AppConfig.apiCd;
  final AuthService _auth = AuthService();

  Future<List<Salesperson>> fetchRows({String? search}) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/cd_salesperson')
        .replace(queryParameters: search != null ? {'search': search} : null);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => Salesperson.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลพนักงานขายล้มเหลว: ${response.statusCode}');
  }

  Future<Salesperson> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
        Uri.parse('$_base/cd_salesperson/$id'), headers: headers);
    if (response.statusCode == 200) {
      return Salesperson.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลพนักงานขายล้มเหลว: ${response.statusCode}');
  }

  Future<Salesperson> addRow(Salesperson row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_base/cd_salesperson'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return Salesperson.fromJson(json.decode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('เพิ่มข้อมูลล้มเหลว: ${response.body}');
  }

  Future<Salesperson> updateRow(Salesperson row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(
      Uri.parse('$_base/cd_salesperson/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return Salesperson.fromJson(json.decode(response.body));
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
    final response = await http.delete(
        Uri.parse('$_base/cd_salesperson/$id'), headers: headers);
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
