// lib/ar/services/ar_gl_account_setup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ar_gl_account_setup.dart';

class ArGlAccountSetupService {
  final String _base = '${AppConfig.apiAr}/ar_gl_account_setup';
  final AuthService _auth = AuthService();

  /// โหลด AR doc_codes ทั้งหมด (LEFT JOIN กับ setup)
  Future<List<ArGlAccountSetup>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse(_base), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List)
          .map((j) => ArGlAccountSetup.fromJson(j))
          .toList();
    }
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  /// โหลด 1 doc_code
  Future<ArGlAccountSetup> fetchRow(String docCode) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/$docCode'), headers: headers);
    if (res.statusCode == 200) return ArGlAccountSetup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  /// Upsert (สร้างใหม่หรืออัปเดต)
  Future<ArGlAccountSetup> upsertRow(ArGlAccountSetup row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$_base/${row.docCode}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (res.statusCode == 200) return ArGlAccountSetup.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${res.body}');
  }
}
