// lib/cm/services/cm_bank_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cm_bank.dart';

class CmBankService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService authService = AuthService();

  Future<List<CmBank>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cm_bank'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => CmBank.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('โหลดข้อมูลล้มเหลว: ${response.statusCode}');
    }
  }

  Future<CmBank> addRow(CmBank row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cm_bank'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) return CmBank.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  Future<CmBank> updateRow(CmBank row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cm_bank/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) return CmBank.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/cm_bank/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  String _errorMessage(String body) {
    try {
      final j = json.decode(body);
      return j['error'] ?? j['message'] ?? body;
    } catch (_) {
      return body;
    }
  }
}
