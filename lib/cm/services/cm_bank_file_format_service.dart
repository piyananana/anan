// lib/cm/services/cm_bank_file_format_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cm_bank_file_format.dart';

class CmBankFileFormatService {
  final String _base = AppConfig.apiCm;
  final AuthService _auth = AuthService();

  Future<List<CmBankFileFormat>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
        Uri.parse('$_base/cm_bank_file_format'), headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List)
          .map((e) => CmBankFileFormat.fromJson(e))
          .toList();
    }
    throw Exception('โหลดรูปแบบไฟล์ล้มเหลว: ${resp.statusCode}');
  }

  Future<CmBankFileFormat> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
        Uri.parse('$_base/cm_bank_file_format/$id'), headers: headers);
    if (resp.statusCode == 200) {
      return CmBankFileFormat.fromJson(jsonDecode(resp.body));
    }
    throw Exception('โหลดรูปแบบไฟล์ล้มเหลว: ${resp.statusCode}');
  }

  Future<CmBankFileFormat> addRow(CmBankFileFormat row) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_bank_file_format'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (resp.statusCode == 201) {
      return CmBankFileFormat.fromJson(jsonDecode(resp.body));
    }
    throw Exception(_extractMessage(resp.body));
  }

  Future<CmBankFileFormat> updateRow(CmBankFileFormat row) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_bank_file_format/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (resp.statusCode == 200) {
      return CmBankFileFormat.fromJson(jsonDecode(resp.body));
    }
    throw Exception(_extractMessage(resp.body));
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(
        Uri.parse('$_base/cm_bank_file_format/$id'), headers: headers);
    if (resp.statusCode != 204) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  String _extractMessage(String body) {
    try {
      return jsonDecode(body)['message'] ?? body;
    } catch (_) {
      return body;
    }
  }
}
