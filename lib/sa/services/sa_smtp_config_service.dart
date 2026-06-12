// lib/sa/services/sa_smtp_config_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'auth_service.dart';
import '../models/sa_smtp_config.dart';

class SaSmtpConfigService {
  final String _base = AppConfig.apiSa;
  final AuthService _auth = AuthService();

  Future<SaSmtpConfig?> getConfig() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(Uri.parse('$_base/sa_smtp_config'), headers: headers);
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body == null) return null;
      return SaSmtpConfig.fromJson(body);
    }
    throw Exception('โหลดตั้งค่า SMTP ล้มเหลว: ${resp.statusCode}');
  }

  Future<SaSmtpConfig> upsertConfig(SaSmtpConfig config, {String? newPassword}) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/sa_smtp_config'),
      headers: headers,
      body: jsonEncode(config.toJson(newPassword: newPassword)),
    );
    if (resp.statusCode == 200) return SaSmtpConfig.fromJson(jsonDecode(resp.body));
    final msg = _extractMessage(resp.body);
    throw Exception(msg);
  }

  String _extractMessage(String body) {
    try {
      return jsonDecode(body)['message'] ?? body;
    } catch (_) {
      return body;
    }
  }
}
