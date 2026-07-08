// lib/cm/services/cm_inter_bank_transfer_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cm_inter_bank_transfer.dart';

class CmInterBankTransferService {
  static final _instance = CmInterBankTransferService._internal();
  CmInterBankTransferService._internal();
  factory CmInterBankTransferService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  Future<List<CmInterBankTransfer>> fetchRows({
    String? dateFrom, String? dateTo, int? bankAccountId, String? status,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (dateFrom      != null) params['date_from']       = dateFrom;
    if (dateTo        != null) params['date_to']         = dateTo;
    if (bankAccountId != null) params['bank_account_id'] = bankAccountId.toString();
    if (status        != null) params['status']          = status;
    final uri = Uri.parse('$_base/cm_inter_bank_transfer').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200)
      return (json.decode(resp.body) as List).map((e) => CmInterBankTransfer.fromJson(e)).toList();
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmInterBankTransfer> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(Uri.parse('$_base/cm_inter_bank_transfer/$id'), headers: headers);
    if (resp.statusCode == 200) return CmInterBankTransfer.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<int> createRow(Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    headers['Content-Type'] = 'application/json';
    final resp = await http.post(Uri.parse('$_base/cm_inter_bank_transfer'),
        headers: headers, body: json.encode(body));
    if (resp.statusCode == 200) return json.decode(resp.body)['id'];
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<void> updateRow(int id, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    headers['Content-Type'] = 'application/json';
    final resp = await http.put(Uri.parse('$_base/cm_inter_bank_transfer/$id'),
        headers: headers, body: json.encode(body));
    if (resp.statusCode != 200) throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<String> postRow(int id, {int? glDocId, String? glDocCode}) async {
    final headers = await _auth.getAuthHeader();
    headers['Content-Type'] = 'application/json';
    final body = <String, dynamic>{};
    if (glDocId   != null) body['gl_doc_id']   = glDocId;
    if (glDocCode != null) body['gl_doc_code']  = glDocCode;
    final resp = await http.put(Uri.parse('$_base/cm_inter_bank_transfer/$id/post'),
        headers: headers, body: json.encode(body));
    if (resp.statusCode == 200) return json.decode(resp.body)['gl_doc_no'] ?? '';
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<void> voidRow(int id) async {
    final headers = await _auth.getAuthHeader();
    headers['Content-Type'] = 'application/json';
    final resp = await http.put(Uri.parse('$_base/cm_inter_bank_transfer/$id/void'),
        headers: headers, body: '{}');
    if (resp.statusCode != 200) throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(Uri.parse('$_base/cm_inter_bank_transfer/$id'), headers: headers);
    if (resp.statusCode != 200) throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
