import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_item_running.dart';

class ImItemRunningService {
  final String _baseUrl = AppConfig.apiIm;
  final AuthService _auth = AuthService();

  Future<ImItemRunning> fetchConfig() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(Uri.parse('$_baseUrl/im_item_running'), headers: headers);
    if (response.statusCode == 200) {
      return ImItemRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return const ImItemRunning(
        isAutoNumbering: false,
        formatPrefix: 'ITEM',
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

  Future<ImItemRunning> saveConfig(ImItemRunning config) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_baseUrl/im_item_running'),
      headers: headers,
      body: jsonEncode(config.toJson()),
    );
    if (response.statusCode == 200) {
      return ImItemRunning.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('บันทึกการตั้งค่าล้มเหลว: ${response.body}');
    }
  }

  Future<String> previewCode() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(Uri.parse('$_baseUrl/im_item_running/preview_code'), headers: headers);
    if (response.statusCode == 200) {
      return json.decode(response.body)['item_code'] as String;
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('ไม่สามารถดึงรหัสอัตโนมัติได้: ${response.statusCode}');
    }
  }
}
