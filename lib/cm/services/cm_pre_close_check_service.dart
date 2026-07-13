// lib/cm/services/cm_pre_close_check_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class CmPreCloseCheckService {
  static final _instance = CmPreCloseCheckService._internal();
  CmPreCloseCheckService._internal();
  factory CmPreCloseCheckService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  Future<Map<String, dynamic>> runChecks(String periodDate) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/cm_pre_close_check')
        .replace(queryParameters: {'period_date': periodDate});
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
