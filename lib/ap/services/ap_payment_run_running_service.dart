import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ap_payment_run_running.dart';

class ApPaymentRunRunningService {
  final String _baseUrl = AppConfig.apiAp;
  final AuthService _auth = AuthService();

  Future<ApPaymentRunRunning> fetchConfig() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/ap_payment_run_running'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ApPaymentRunRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return const ApPaymentRunRunning(
        isAutoNumbering: true,
        formatPrefix: 'PR',
        formatSeparator: '-',
        formatSuffixDate: 'YYYYMM',
        runningLength: 4,
        nextRunningNumber: 1,
      );
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('โหลดการตั้งค่าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ApPaymentRunRunning> saveConfig(ApPaymentRunRunning config) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_baseUrl/ap_payment_run_running'),
      headers: headers,
      body: jsonEncode(config.toJson()),
    );
    if (response.statusCode == 200) {
      return ApPaymentRunRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('บันทึกการตั้งค่าล้มเหลว: ${response.body}');
    }
  }

  Future<String> previewCode() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/ap_payment_run_running/preview_code'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['run_number'] as String;
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('ไม่สามารถดึงเลขที่อัตโนมัติได้: ${response.statusCode}');
    }
  }
}
