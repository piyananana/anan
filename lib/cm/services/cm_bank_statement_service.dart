// lib/cm/services/cm_bank_statement_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cm_bank_statement.dart';

class CmBankStatementService {
  static final CmBankStatementService _instance = CmBankStatementService._internal();
  CmBankStatementService._internal();
  factory CmBankStatementService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  String _err(String body) {
    try { return (json.decode(body) as Map)['error']?.toString() ?? body; } catch (_) { return body; }
  }

  // ── Statements ─────────────────────────────────────────────────────────────

  Future<List<CmBankStatement>> fetchStatements({
    int? bankAccountId,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (bankAccountId != null) params['bank_account_id'] = bankAccountId.toString();
    if (status != null && status != 'All') params['status'] = status;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null)   params['date_to']   = dateTo;
    final uri = Uri.parse('$_base/cm_bank_statement').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmBankStatement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchStatements: ${resp.body}');
  }

  Future<CmBankStatement> createStatement(Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_bank_statement'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 201) return CmBankStatement.fromJson(json.decode(resp.body));
    throw Exception(_err(resp.body));
  }

  Future<CmBankStatement> updateStatement(int id, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_bank_statement/$id'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 200) return CmBankStatement.fromJson(json.decode(resp.body));
    throw Exception(_err(resp.body));
  }

  Future<CmBankStatement> confirmStatement(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(Uri.parse('$_base/cm_bank_statement/$id/confirm'), headers: headers);
    if (resp.statusCode == 200) return CmBankStatement.fromJson(json.decode(resp.body));
    throw Exception(_err(resp.body));
  }

  Future<CmBankStatement> voidStatement(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(Uri.parse('$_base/cm_bank_statement/$id/void'), headers: headers);
    if (resp.statusCode == 200) return CmBankStatement.fromJson(json.decode(resp.body));
    throw Exception(_err(resp.body));
  }

  Future<void> deleteStatement(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(Uri.parse('$_base/cm_bank_statement/$id'), headers: headers);
    if (resp.statusCode != 200) throw Exception(_err(resp.body));
  }

  // ── Lines ──────────────────────────────────────────────────────────────────

  Future<List<CmBankStatementLine>> fetchLines(int statementId) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
      Uri.parse('$_base/cm_bank_statement/$statementId/lines'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmBankStatementLine.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchLines: ${resp.body}');
  }

  Future<CmBankStatementLine> addLine(int statementId, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_bank_statement/$statementId/lines'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 201) return CmBankStatementLine.fromJson(json.decode(resp.body));
    throw Exception(_err(resp.body));
  }

  Future<Map<String, dynamic>> bulkInsertLines(
    int statementId,
    List<Map<String, dynamic>> lines, {
    String? fileName,
  }) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_bank_statement/$statementId/lines/bulk'),
      headers: headers,
      body: json.encode({'lines': lines, if (fileName != null) 'file_name': fileName}),
    );
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(_err(resp.body));
  }

  Future<CmBankStatementLine> updateLine(int lineId, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_bank_statement_line/$lineId'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 200) return CmBankStatementLine.fromJson(json.decode(resp.body));
    throw Exception(_err(resp.body));
  }

  Future<void> deleteLine(int lineId) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(
      Uri.parse('$_base/cm_bank_statement_line/$lineId'),
      headers: headers,
    );
    if (resp.statusCode != 200) throw Exception(_err(resp.body));
  }

  // ── Reconcile ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchReconcileItems({
    required int bankAccountId,
    required String dateFrom,
    required String dateTo,
    bool unreconciledOnly = false,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = {
      'bank_account_id': bankAccountId.toString(),
      'date_from': dateFrom,
      'date_to': dateTo,
      if (unreconciledOnly) 'unreconciled_only': 'true',
    };
    final uri = Uri.parse('$_base/cm_reconcile/items').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception('fetchReconcileItems: ${resp.body}');
  }

  Future<void> reconcilePair({
    required int statementLineId,
    required String cmRecordType,
    required int cmRecordId,
    required String reconcileDate,
  }) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_reconcile/statement_line/$statementLineId/reconcile'),
      headers: headers,
      body: json.encode({
        'cm_record_type': cmRecordType,
        'cm_record_id': cmRecordId,
        'reconcile_date': reconcileDate,
      }),
    );
    if (resp.statusCode != 200) throw Exception(_err(resp.body));
  }

  Future<void> unreconcileStatementLine(int statementLineId) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_reconcile/statement_line/$statementLineId/unreconcile'),
      headers: headers,
    );
    if (resp.statusCode != 200) throw Exception(_err(resp.body));
  }

  Future<Map<String, dynamic>> getReconcileSummary({
    required int bankAccountId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = {
      'bank_account_id': bankAccountId.toString(),
      'date_from': dateFrom,
      'date_to': dateTo,
    };
    final uri = Uri.parse('$_base/cm_reconcile/summary').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception('getReconcileSummary: ${resp.body}');
  }
}
