// lib/im/services/im_stock_count_running_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_stock_count_running.dart';

class ImStockCountRunningService {
  final String _baseUrl = AppConfig.apiIm;
  final AuthService _auth = AuthService();

  Future<ImStockCountRunning> fetchConfig() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/im_stock_count_running'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ImStockCountRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return const ImStockCountRunning(
        isAutoNumbering: true,
        formatPrefix: 'CNT',
        formatSeparator: '-',
        formatSuffixDate: '',
        runningLength: 6,
        nextRunningNumber: 1,
      );
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('โหลดการตั้งค่าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImStockCountRunning> saveConfig(ImStockCountRunning config) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_baseUrl/im_stock_count_running'),
      headers: headers,
      body: jsonEncode(config.toJson()),
    );
    if (response.statusCode == 200) {
      return ImStockCountRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('บันทึกการตั้งค่าล้มเหลว: ${response.body}');
    }
  }

  /// ดึงตัวอย่างเลขที่ถัดไป (ไม่เพิ่มเลขรัน)
  Future<String> previewCode() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/im_stock_count_running/preview_code'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['count_no'] as String;
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('ไม่สามารถดึงเลขที่อัตโนมัติได้: ${response.statusCode}');
    }
  }
}
