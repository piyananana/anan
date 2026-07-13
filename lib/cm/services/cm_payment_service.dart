// lib/cm/services/cm_payment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cm_payment.dart';

class CmPaymentService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService _auth = AuthService();

  String _err(String body) {
    try { final j = jsonDecode(body); return j['error'] ?? j['message'] ?? body; } catch (_) { return body; }
  }

  Future<List<CmPayment>> fetchPayments({
    int?    bankAccountId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? paymentMethodType,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (bankAccountId     != null) params['bank_account_id']     = bankAccountId.toString();
    if (status            != null) params['status']              = status;
    if (dateFrom          != null) params['date_from']           = dateFrom;
    if (dateTo            != null) params['date_to']             = dateTo;
    if (paymentMethodType != null) params['payment_method_type'] = paymentMethodType;
    final uri = Uri.parse('$baseUrl/cm_payment').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) return (jsonDecode(res.body) as List).map((e) => CmPayment.fromJson(e)).toList();
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmPayment> fetchPayment(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/cm_payment/$id'), headers: headers);
    if (res.statusCode == 200) return CmPayment.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmPayment> createPayment(CmPayment payment) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/cm_payment'),
        headers: headers, body: jsonEncode(payment.toJson()));
    if (res.statusCode == 201) return CmPayment.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmPayment> clearPayment(int id, {String? clearingDate, String? clearingNote}) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/cm_payment/$id/clear'),
        headers: headers,
        body: jsonEncode({'clearing_date': clearingDate, 'clearing_note': clearingNote}));
    if (res.statusCode == 200) return CmPayment.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }

  Future<CmPayment> voidPayment(int id, {String? clearingNote}) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/cm_payment/$id/void'),
        headers: headers,
        body: jsonEncode({'clearing_note': clearingNote}));
    if (res.statusCode == 200) return CmPayment.fromJson(jsonDecode(res.body));
    if (res.statusCode == 401) { _auth.logout(); throw Exception('Unauthorized'); }
    throw Exception(_err(res.body));
  }
}
