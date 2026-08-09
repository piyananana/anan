import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cm_transaction_gl_setup.dart';

class CmTransactionGlSetupService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService authService = AuthService();

  Future<List<CmTransactionGlSetup>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/cm_transaction_gl_setup'), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).map((e) => CmTransactionGlSetup.fromJson(e)).toList();
    } else if (res.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดข้อมูลการตั้งค่าบัญชี CM ล้มเหลว: ${res.statusCode}');
    }
  }

  Future<CmTransactionGlSetup?> fetchRow(String docCode) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/cm_transaction_gl_setup/$docCode'), headers: headers);
    if (res.statusCode == 200) return CmTransactionGlSetup.fromJson(json.decode(res.body));
    return null;
  }

  Future<CmTransactionGlSetup> upsertRow(String docCode, CmTransactionGlSetup setup) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/cm_transaction_gl_setup/$docCode'),
      headers: headers,
      body: jsonEncode(setup.toJson()),
    );
    if (res.statusCode == 200) return CmTransactionGlSetup.fromJson(json.decode(res.body));
    else if (res.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(res.body);
      throw Exception(err['message'] ?? 'บันทึกการตั้งค่าล้มเหลว');
    }
  }
}
