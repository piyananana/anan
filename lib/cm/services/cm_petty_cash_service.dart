// lib/cm/services/cm_petty_cash_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cm_petty_cash.dart';

class CmPettyCashService {
  static final CmPettyCashService _instance = CmPettyCashService._internal();
  CmPettyCashService._internal();
  factory CmPettyCashService() => _instance;

  final _auth = AuthService();
  final _base = AppConfig.apiCm;

  // ── Vouchers ────────────────────────────────────────────────────────────────

  Future<List<CmPettyCashVoucher>> fetchVouchers({
    int? pettyCashAccountId,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (pettyCashAccountId != null) params['petty_cash_account_id'] = pettyCashAccountId.toString();
    if (status != null && status != 'All') params['status'] = status;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final uri = Uri.parse('$_base/cm_petty_cash_voucher').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmPettyCashVoucher.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchVouchers: ${resp.body}');
  }

  Future<CmPettyCashVoucher> createVoucher(Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_petty_cash_voucher'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 201) return CmPettyCashVoucher.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmPettyCashVoucher> updateVoucher(int id, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_petty_cash_voucher/$id'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 200) return CmPettyCashVoucher.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmPettyCashVoucher> approveVoucher(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_petty_cash_voucher/$id/approve'),
      headers: headers,
    );
    if (resp.statusCode == 200) return CmPettyCashVoucher.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmPettyCashVoucher> voidVoucher(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_petty_cash_voucher/$id/void'),
      headers: headers,
    );
    if (resp.statusCode == 200) return CmPettyCashVoucher.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<void> deleteVoucher(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(
      Uri.parse('$_base/cm_petty_cash_voucher/$id'),
      headers: headers,
    );
    if (resp.statusCode != 200) throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  // ── Replenishments ──────────────────────────────────────────────────────────

  Future<List<CmPettyCashReplenishment>> fetchReplenishments({
    int? pettyCashAccountId,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (pettyCashAccountId != null) params['petty_cash_account_id'] = pettyCashAccountId.toString();
    if (status != null && status != 'All') params['status'] = status;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final uri = Uri.parse('$_base/cm_petty_cash_replenishment').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmPettyCashReplenishment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchReplenishments: ${resp.body}');
  }

  Future<List<CmPettyCashVoucher>> fetchPendingVouchers(int pettyCashAccountId) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/cm_petty_cash_replenishment/pending_vouchers')
        .replace(queryParameters: {'petty_cash_account_id': pettyCashAccountId.toString()});
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmPettyCashVoucher.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchPendingVouchers: ${resp.body}');
  }

  Future<List<CmPettyCashVoucher>> fetchReplenishedVouchers(int replenishmentId) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
      Uri.parse('$_base/cm_petty_cash_replenishment/$replenishmentId/vouchers'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((e) => CmPettyCashVoucher.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('fetchReplenishedVouchers: ${resp.body}');
  }

  Future<CmPettyCashReplenishment> createReplenishment(Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/cm_petty_cash_replenishment'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 201) return CmPettyCashReplenishment.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmPettyCashReplenishment> updateReplenishment(int id, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_petty_cash_replenishment/$id'),
      headers: headers,
      body: json.encode(body),
    );
    if (resp.statusCode == 200) return CmPettyCashReplenishment.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<Map<String, dynamic>> postReplenishment(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_petty_cash_replenishment/$id/post'),
      headers: headers,
    );
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }

  Future<CmPettyCashReplenishment> voidReplenishment(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/cm_petty_cash_replenishment/$id/void'),
      headers: headers,
    );
    if (resp.statusCode == 200) return CmPettyCashReplenishment.fromJson(json.decode(resp.body));
    throw Exception(json.decode(resp.body)['error'] ?? resp.body);
  }
}
