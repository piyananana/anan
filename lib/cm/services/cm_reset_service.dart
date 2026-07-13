// lib/cm/services/cm_reset_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class CmResetService {
  static final _instance = CmResetService._internal();
  CmResetService._internal();
  factory CmResetService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  Future<List<Map<String, dynamic>>> resetData(String confirmText) async {
    final headers = await _auth.getAuthHeader();
    headers['Content-Type'] = 'application/json';
    final resp = await http.post(Uri.parse('$_base/cm_reset'),
        headers: headers, body: json.encode({'confirm_text': confirmText}));
    if (resp.statusCode == 200)
      return List<Map<String, dynamic>>.from(json.decode(resp.body)['result'] as List);
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
