// lib/cm/services/cm_bank_fx_revaluation_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cm_bank_fx_revaluation.dart';

class CmBankFxRevaluationService {
  static final CmBankFxRevaluationService _instance = CmBankFxRevaluationService._internal();
  CmBankFxRevaluationService._internal();
  factory CmBankFxRevaluationService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  Future<List<CmBankFxRevaluation>> fetchRows({
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status != 'All') params['status']    = status;
    if (dateFrom != null)                  params['date_from'] = dateFrom;
    if (dateTo   != null)                  params['date_to']   = dateTo;
    final uri = Uri.parse('$_base/cm_bank_fx_revaluation').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmBankFxRevaluation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchRows: ${resp.body}');
  }

  Future<CmBankFxRevaluation> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(Uri.parse('$_base/cm_bank_fx_revaluation/$id'), headers: headers);
    if (resp.statusCode == 200) return CmBankFxRevaluation.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<List<Map<String, dynamic>>> fetchOutstandingCurrencies(String asOfDate) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/cm_bank_fx_revaluation/outstanding_currencies')
        .replace(queryParameters: {'as_of_date': asOfDate});
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
    }
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<List<CmFxPreviewLine>> previewLines({
    required String revaluationDate,
    required Map<String, double> rates,
  }) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_bank_fx_revaluation/preview'),
      headers: headers,
      body: json.encode({'revaluation_date': revaluationDate, 'rates': rates}),
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      return (data['lines'] as List)
          .map((e) => CmFxPreviewLine.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmBankFxRevaluation> createRow(Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_bank_fx_revaluation'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 201) return CmBankFxRevaluation.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmBankFxRevaluation> updateRow(int id, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_bank_fx_revaluation/$id'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 200) return CmBankFxRevaluation.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<Map<String, dynamic>> postRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_bank_fx_revaluation/$id/post'),
      headers: headers,
    );
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmBankFxRevaluation> voidRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_bank_fx_revaluation/$id/void'),
      headers: headers,
    );
    if (resp.statusCode == 200) return CmBankFxRevaluation.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(
      Uri.parse('$_base/cm_bank_fx_revaluation/$id'),
      headers: headers,
    );
    if (resp.statusCode != 200) throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
