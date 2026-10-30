// lib/mo/services/mo_gl_account_setup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/mo_gl_account_setup.dart';

class MoGlAccountSetupService {
  final String baseUrl = AppConfig.apiMo;
  final AuthService authService = AuthService();

  Future<List<MoGlAccountSetup>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_gl_account_setup'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoGlAccountSetup.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดการตั้งค่าบัญชีใบสั่งผลิตล้มเหลว: ${response.statusCode}');
    }
  }

  Future<MoGlAccountSetup> upsertRow(String docCode, MoGlAccountSetup row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(Uri.parse('$baseUrl/mo_gl_account_setup/$docCode'),
        headers: headers, body: json.encode(row.toJson()));
    if (response.statusCode == 200) return MoGlAccountSetup.fromJson(json.decode(response.body));
    final body = json.decode(response.body);
    throw Exception(body['message'] ?? body['error'] ?? 'บันทึกล้มเหลว');
  }
}
