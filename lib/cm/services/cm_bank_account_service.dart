// lib/cm/services/cm_bank_account_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cm_bank_account.dart';

class CmBankAccountService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService authService = AuthService();

  Future<List<CmBankAccount>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cm_bank_account'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => CmBankAccount.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('โหลดข้อมูลล้มเหลว: ${response.statusCode}');
    }
  }

  Future<CmBankAccount> addRow(CmBankAccount row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cm_bank_account'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) return CmBankAccount.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  Future<CmBankAccount> updateRow(CmBankAccount row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cm_bank_account/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) return CmBankAccount.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/cm_bank_account/$id'), headers: headers);
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
