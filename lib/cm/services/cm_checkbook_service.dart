// lib/cm/services/cm_checkbook_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cm_checkbook.dart';

class CmCheckbookService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService _auth = AuthService();

  String _err(String body) {
    try { final j = jsonDecode(body); return j['error'] ?? j['message'] ?? body; } catch (_) { return body; }
  }

  // ── Checkbook ──────────────────────────────────────────────────────────────

  Future<List<CmCheckbook>> fetchCheckbooks({int? bankAccountId}) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$baseUrl/cm_checkbook${bankAccountId != null ? '?bank_account_id=$bankAccountId' : ''}');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) return (jsonDecode(res.body) as List).map((e) => CmCheckbook.fromJson(e)).toList();
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmCheckbook> addCheckbook(CmCheckbook row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/cm_checkbook'), headers: headers, body: jsonEncode(row.toJson()));
    if (res.statusCode == 201) return CmCheckbook.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmCheckbook> updateCheckbook(CmCheckbook row) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/cm_checkbook/${row.id}'), headers: headers, body: jsonEncode(row.toJson()));
    if (res.statusCode == 200) return CmCheckbook.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<void> deleteCheckbook(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/cm_checkbook/$id'), headers: headers);
    if (res.statusCode == 204) return;
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  // ── Print Config ───────────────────────────────────────────────────────────

  Future<List<CmCheckPrintConfig>> fetchPrintConfigs({int? bankAccountId}) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$baseUrl/cm_check_print_config${bankAccountId != null ? '?bank_account_id=$bankAccountId' : ''}');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) return (jsonDecode(res.body) as List).map((e) => CmCheckPrintConfig.fromJson(e)).toList();
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmCheckPrintConfig> addPrintConfig(CmCheckPrintConfig cfg) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/cm_check_print_config'), headers: headers, body: jsonEncode(cfg.toJson()));
    if (res.statusCode == 201) return CmCheckPrintConfig.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmCheckPrintConfig> updatePrintConfig(CmCheckPrintConfig cfg) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/cm_check_print_config/${cfg.id}'), headers: headers, body: jsonEncode(cfg.toJson()));
    if (res.statusCode == 200) return CmCheckPrintConfig.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<void> deletePrintConfig(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/cm_check_print_config/$id'), headers: headers);
    if (res.statusCode == 204) return;
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }
}
