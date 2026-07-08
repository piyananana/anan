// lib/cm/services/cm_gl_account_setup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class CmGlAccountSetupService {
  static final _instance = CmGlAccountSetupService._internal();
  CmGlAccountSetupService._internal();
  factory CmGlAccountSetupService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  Future<List<Map<String, dynamic>>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(Uri.parse('$_base/cm_gl_account_setup'), headers: headers);
    if (resp.statusCode == 200)
      return List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<void> upsertRow(String setupKey, {int? glAccountId, int? glDocId}) async {
    final headers = await _auth.getAuthHeader();
    headers['Content-Type'] = 'application/json';
    final body = <String, dynamic>{'setup_key': setupKey};
    if (glAccountId != null) body['gl_account_id'] = glAccountId;
    if (glDocId     != null) body['gl_doc_id']     = glDocId;
    final resp = await http.put(Uri.parse('$_base/cm_gl_account_setup'),
        headers: headers, body: json.encode(body));
    if (resp.statusCode != 200) throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
