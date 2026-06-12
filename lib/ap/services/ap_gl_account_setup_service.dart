import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/ap_gl_account_setup.dart';

class ApGlAccountSetupService {
  final String _base = '${AppConfig.apiAp}/ap_gl_account_setup';
  final AuthService _auth = AuthService();

  Future<List<ApGlAccountSetup>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse(_base), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List)
          .map((j) => ApGlAccountSetup.fromJson(j)).toList();
    }
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  Future<ApGlAccountSetup> fetchRow(String docCode) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/$docCode'), headers: headers);
    if (res.statusCode == 200) return ApGlAccountSetup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  Future<ApGlAccountSetup> upsertRow(ApGlAccountSetup row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$_base/${row.docCode}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (res.statusCode == 200) return ApGlAccountSetup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${res.body}');
  }
}
