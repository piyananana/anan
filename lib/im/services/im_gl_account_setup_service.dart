import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_gl_account_setup.dart';

class ImGlAccountSetupService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImGlAccountSetup>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_gl_account_setup'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImGlAccountSetup.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลการตั้งค่าบัญชี GL ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImGlAccountSetup> upsertRow(String docCode, ImGlAccountSetup row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_gl_account_setup/$docCode'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImGlAccountSetup.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to save data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }
}
