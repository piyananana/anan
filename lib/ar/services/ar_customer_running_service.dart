// lib/ar/services/ar_customer_running_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ar_customer_running.dart';

class ArCustomerRunningService {
  final String _baseUrl = AppConfig.apiAr;
  final AuthService _auth = AuthService();

  Future<ArCustomerRunning> fetchConfig() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/ar_customer_running'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ArCustomerRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      // ยังไม่มีข้อมูล → ใช้ค่า default
      return const ArCustomerRunning(
        isAutoNumbering: false,
        formatPrefix: 'CUST',
        formatSeparator: '-',
        formatSuffixDate: '',
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

  Future<ArCustomerRunning> saveConfig(ArCustomerRunning config) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_baseUrl/ar_customer_running'),
      headers: headers,
      body: jsonEncode(config.toJson()),
    );
    if (response.statusCode == 200) {
      return ArCustomerRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('บันทึกการตั้งค่าล้มเหลว: ${response.body}');
    }
  }

  /// ดึงตัวอย่างรหัสถัดไป (ไม่เพิ่มเลขรัน)
  Future<String> previewCode() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/ar_customer_running/preview_code'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['customer_code'] as String;
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('ไม่สามารถดึงรหัสอัตโนมัติได้: ${response.statusCode}');
    }
  }
}
