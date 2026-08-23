import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_accounting_setting.dart';

class ImAccountingSettingService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<ImAccountingSetting?> fetchSetting() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_accounting_setting'), headers: headers);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return body == null ? null : ImAccountingSetting.fromJson(body);
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลตั้งค่าบัญชีสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImAccountingSetting> upsertSetting(ImAccountingSetting setting) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_accounting_setting'),
      headers: headers,
      body: jsonEncode(setting.toJson()),
    );
    if (response.statusCode == 200) {
      return ImAccountingSetting.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to save data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }
}
