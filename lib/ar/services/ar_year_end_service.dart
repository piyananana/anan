import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ar_year_end.dart';

class ArYearEndService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _auth = AuthService();

  // ── Setup ──────────────────────────────────────────────────────────────────
  Future<ArYearEndSetup?> fetchSetup() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ar_year_end_setup'), headers: headers);
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j == null) return null;
      return ArYearEndSetup.fromJson(j as Map<String, dynamic>);
    }
    throw Exception('Failed to load setup: ${res.statusCode}');
  }

  Future<void> saveSetup(ArYearEndSetup setup) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(
      Uri.parse('$baseUrl/ar_year_end_setup'),
      headers: headers,
      body: jsonEncode(setup.toJson()),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  // ── Allowance Rules ────────────────────────────────────────────────────────
  Future<List<ArAllowanceRule>> fetchAllowanceRules() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ar_allowance_rule'), headers: headers);
    if (res.statusCode == 200) {
      final List j = jsonDecode(res.body);
      return j.map((e) => ArAllowanceRule.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load rules: ${res.statusCode}');
  }

  Future<void> saveAllowanceRules(List<ArAllowanceRule> rules) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(
      Uri.parse('$baseUrl/ar_allowance_rule'),
      headers: headers,
      body: jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  // ── Pre-Close Check ────────────────────────────────────────────────────────
  Future<ArPreCloseResult> preCloseCheck(int periodYear) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/year_end/pre_close_check?period_year=$periodYear'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      return ArPreCloseResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to check: ${res.statusCode}');
  }

  // ── FX Revaluation ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchOutstandingCurrencies(String revalDate) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/ar_fx_revaluation/outstanding_currencies?reval_date=$revalDate'),
      headers: headers,
    );
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to load outstanding currencies');
  }

  Future<List<ArFxRevaluationHeader>> fetchRevaluations() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ar_fx_revaluation'), headers: headers);
    if (res.statusCode == 200) {
      final List j = jsonDecode(res.body);
      return j.map((e) => ArFxRevaluationHeader.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load revaluations: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> fetchRevaluationDetail(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ar_fx_revaluation/$id'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> previewReval({
    required String revalDate,
    required Map<String, double> yearEndRates,
  }) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/ar_fx_revaluation/preview'),
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
      Uri.parse('$baseUrl/ar_fx_revaluation'),
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
    final res = await http.post(Uri.parse('$baseUrl/ar_fx_revaluation/$id/post'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> voidReval(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/ar_fx_revaluation/$id/void'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> deleteReval(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/ar_fx_revaluation/$id'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  // ── Allowance Run ──────────────────────────────────────────────────────────
  Future<List<ArAllowanceRunHeader>> fetchAllowanceRuns() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ar_allowance_run'), headers: headers);
    if (res.statusCode == 200) {
      final List j = jsonDecode(res.body);
      return j.map((e) => ArAllowanceRunHeader.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> fetchAllowanceRunDetail(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/ar_allowance_run/$id'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> previewAllowanceRun(String runDate) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/ar_allowance_run/preview'),
      headers: headers,
      body: jsonEncode({'run_date': runDate}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<int> createAllowanceRun({
    required String runDate,
    required int periodYear,
    String? note,
  }) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/ar_allowance_run'),
      headers: headers,
      body: jsonEncode({'run_date': runDate, 'period_year': periodYear, 'note': note}),
    );
    if (res.statusCode == 201) return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as int;
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> postAllowanceRun(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/ar_allowance_run/$id/post'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> voidAllowanceRun(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/ar_allowance_run/$id/void'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }

  Future<void> deleteAllowanceRun(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/ar_allowance_run/$id'), headers: headers);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error'] ?? 'Failed');
  }
}
