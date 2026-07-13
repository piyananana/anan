// lib/cd/services/cd_bank_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cd_bank.dart';

class BankService {
  final String _baseUrl = AppConfig.apiCd;
  final AuthService _auth = AuthService();

  Future<List<Bank>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final response =
        await http.get(Uri.parse('$_baseUrl/cd_bank'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => Bank.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลธนาคารล้มเหลว: ${response.statusCode}');
  }

  Future<List<Bank>> fetchActiveRows() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
        Uri.parse('$_baseUrl/cd_bank/active'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => Bank.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลธนาคารล้มเหลว: ${response.statusCode}');
  }

  Future<Bank> addRow(Bank row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(Uri.parse('$_baseUrl/cd_bank'),
        headers: headers, body: jsonEncode(row.toJson()));
    if (response.statusCode == 201) return Bank.fromJson(json.decode(response.body));
    if (response.statusCode == 409)
      throw Exception(json.decode(response.body)['error']);
    if (response.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${response.body}');
  }

  Future<Bank> updateRow(Bank row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(Uri.parse('$_baseUrl/cd_bank/${row.id}'),
        headers: headers, body: jsonEncode(row.toJson()));
    if (response.statusCode == 200) return Bank.fromJson(json.decode(response.body));
    if (response.statusCode == 409)
      throw Exception(json.decode(response.body)['error']);
    if (response.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('บันทึกล้มเหลว: ${response.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.delete(
        Uri.parse('$_baseUrl/cd_bank/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception('ลบล้มเหลว: ${response.statusCode}');
  }
}
