// lib/cm/services/cm_report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class CmReportService {
  static final CmReportService _instance = CmReportService._internal();
  CmReportService._internal();
  factory CmReportService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  Future<Map<String, dynamic>> getCashPosition({
    int? bankAccountId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = {'date_from': dateFrom, 'date_to': dateTo};
    if (bankAccountId != null) params['bank_account_id'] = bankAccountId.toString();
    final uri = Uri.parse('$_base/cm_report/cash_position').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<Map<String, dynamic>> getBankTransactions({
    required int bankAccountId,
    required String dateFrom,
    required String dateTo,
    String? recordType,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = {
      'bank_account_id': bankAccountId.toString(),
      'date_from': dateFrom,
      'date_to': dateTo,
      if (recordType != null && recordType != 'All') 'record_type': recordType,
    };
    final uri = Uri.parse('$_base/cm_report/bank_transactions').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<Map<String, dynamic>> getCheckRegister({
    int? bankAccountId,
    required String dateFrom,
    required String dateTo,
    String? checkType,
    String? status,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{'date_from': dateFrom, 'date_to': dateTo};
    if (bankAccountId != null) params['bank_account_id'] = bankAccountId.toString();
    if (checkType != null && checkType != 'All') params['check_type'] = checkType;
    if (status     != null && status     != 'All') params['status']     = status;
    final uri = Uri.parse('$_base/cm_report/check_register').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
