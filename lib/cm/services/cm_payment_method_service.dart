// lib/cm/services/cm_payment_method_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cm_payment_method.dart';

class CmPaymentMethodService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService authService = AuthService();

  Future<List<CmPaymentMethod>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cm_payment_method'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => CmPaymentMethod.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('โหลดข้อมูลล้มเหลว: ${response.statusCode}');
    }
  }

  Future<CmPaymentMethod> addRow(CmPaymentMethod row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cm_payment_method'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) return CmPaymentMethod.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  Future<CmPaymentMethod> updateRow(CmPaymentMethod row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cm_payment_method/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) return CmPaymentMethod.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { authService.logout(); throw Exception('Unauthorized'); }
    final msg = _errorMessage(response.body);
    throw Exception(msg);
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/cm_payment_method/$id'), headers: headers);
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
