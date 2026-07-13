import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ap_year_end.dart';

class ApYearEndService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService _auth = AuthService();

  // ── Setup ──────────────────────────────────────────────────────────────────
  Future<ApYearEndSetup?> fetchSetup() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ap_year_end_setup'), headers: headers);
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j == null) return null;
      return ApYearEndSetup.fromJson(j as Map<String, dynamic>);
    }
    throw Exception('Failed to load setup: ${res.statusCode}');
  }

  Future<void> saveSetup(ApYearEndSetup setup) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(
      Uri.parse('$baseUrl/ap_year_end_setup'),
      headers: headers,
      body: jsonEncode(setup.toJson()),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  // ── Pre-Close Check ────────────────────────────────────────────────────────
  Future<ApPreCloseResult> preCloseCheck(int periodYear) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/year_end/pre_close_check?period_year=$periodYear'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      return ApPreCloseResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to check: ${res.statusCode}');
  }

  // ── FX Revaluation ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchOutstandingCurrencies(String revalDate) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/ap_fx_revaluation/outstanding_currencies?reval_date=$revalDate'),
      headers: headers,
    );
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to load outstanding currencies');
  }

  Future<List<ApFxRevaluationHeader>> fetchRevaluations() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ap_fx_revaluation'), headers: headers);
    if (res.statusCode == 200) {
      final List j = jsonDecode(res.body);
      return j.map((e) => ApFxRevaluationHeader.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load revaluations: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> fetchRevaluationDetail(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ap_fx_revaluation/$id'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> previewReval({
    required String revalDate,
    required Map<String, double> yearEndRates,
  }) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/ap_fx_revaluation/preview'),
      headers: headers,
      body: jsonEncode({'reval_date': revalDate, 'year_end_rates': yearEndRates}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<int> createReval({
    required String revalDate,
    required int periodYear,
    required String method,
    String? reversalDate,
    String? note,
    required Map<String, double> yearEndRates,
  }) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/ap_fx_revaluation'),
      headers: headers,
      body: jsonEncode({
        'reval_date': revalDate,
        'period_year': periodYear,
        'method': method,
        'reversal_date': reversalDate,
        'note': note,
        'year_end_rates': yearEndRates,
      }),
    );
    if (res.statusCode == 201) return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> postReval(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/ap_fx_revaluation/$id/post'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> voidReval(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/ap_fx_revaluation/$id/void'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> deleteReval(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/ap_fx_revaluation/$id'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }
}
