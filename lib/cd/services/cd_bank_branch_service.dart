// lib/cd/services/cd_bank_branch_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cd_bank_branch.dart';

class BankBranchService {
  final String _baseUrl = AppConfig.apiCd;
  final AuthService _auth = AuthService();

  Future<List<BankBranch>> fetchRows({int? bankId}) async {
    final headers = await _auth.getAuthHeader();
    final uri = bankId != null
        ? Uri.parse('$_baseUrl/cd_bank_branch?bank_id=$bankId')
        : Uri.parse('$_baseUrl/cd_bank_branch');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => BankBranch.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลสาขาธนาคารล้มเหลว: ${response.statusCode}');
  }

  Future<BankBranch> addRow(BankBranch row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(Uri.parse('$_baseUrl/cd_bank_branch'),
        headers: headers, body: jsonEncode(row.toJson()));
    if (response.statusCode == 201) return BankBranch.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${response.body}');
  }

  Future<BankBranch> updateRow(BankBranch row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(Uri.parse('$_baseUrl/cd_bank_branch/${row.id}'),
        headers: headers, body: jsonEncode(row.toJson()));
    if (response.statusCode == 200) return BankBranch.fromJson(json.decode(response.body));
    if (response.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${response.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.delete(
        Uri.parse('$_baseUrl/cd_bank_branch/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('ลบล้มเหลว: ${response.statusCode}');
  }
}
