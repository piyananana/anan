// lib/cd/services/cd_wht_type_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cd_wht_type.dart';

class CdWhtTypeService {
  final String _base = '${AppConfig.apiCd}/cd_wht_type';
  final AuthService _auth = AuthService();

  Future<List<CdWhtType>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse(_base), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).map((j) => CdWhtType.fromJson(j)).toList();
    } else if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  Future<List<CdWhtType>> fetchActiveRows() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/active'), headers: headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).map((j) => CdWhtType.fromJson(j)).toList();
    } else if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  Future<CdWhtType> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/$id'), headers: headers);
    if (res.statusCode == 200) return CdWhtType.fromJson(json.decode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('โหลดข้อมูลล้มเหลว: ${res.statusCode}');
  }

  Future<CdWhtType> addRow(CdWhtType row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse(_base), headers: headers, body: jsonEncode(row.toJson()));
    if (res.statusCode == 201) return CdWhtType.fromJson(json.decode(res.body));
    if (res.statusCode == 409) throw Exception(json.decode(res.body)['message'] ?? 'รหัสซ้ำ');
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${res.body}');
  }

  Future<CdWhtType> updateRow(CdWhtType row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(Uri.parse('$_base/${row.id}'), headers: headers, body: jsonEncode(row.toJson()));
    if (res.statusCode == 200) return CdWhtType.fromJson(json.decode(res.body));
    if (res.statusCode == 409) throw Exception(json.decode(res.body)['message'] ?? 'รหัสซ้ำ');
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${res.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$_base/$id'), headers: headers);
    if (res.statusCode == 204) return;
    if (res.statusCode == 409) throw Exception(json.decode(res.body)['message'] ?? 'ไม่สามารถลบได้');
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('ลบล้มเหลว: ${res.body}');
  }
}
