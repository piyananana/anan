import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sa_credit_approval.dart';
import 'sa_auth_service.dart';

// endpoint ขออนุมัติเกินวงเงินเครดิต — base = AppConfig.apiAr / apiIm, path = 'ar_transaction' / 'im_transaction'
class CreditApprovalService {
  final String base;
  final String path;
  final AuthService _auth = AuthService();
  CreditApprovalService(this.base, this.path);

  String _err(http.Response r) {
    try {
      final j = json.decode(r.body);
      return (j['message'] ?? j['error'] ?? r.body).toString();
    } catch (_) {
      return r.body;
    }
  }

  Future<CreditInfo> info(int customerId, {int? excludeId}) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$base/$path/credit_info').replace(queryParameters: {
      'customer_id': '$customerId',
      if (excludeId != null) 'exclude_id': '$excludeId',
    });
    final r = await http.get(uri, headers: headers);
    if (r.statusCode == 200) return CreditInfo.fromJson(json.decode(r.body));
    throw Exception(_err(r));
  }

  Future<String> _put(int id, String action, Map<String, dynamic> body) async {
    final headers = await _auth.getAuthHeader();
    final r = await http.put(Uri.parse('$base/$path/$id/$action'), headers: headers, body: json.encode(body));
    if (r.statusCode == 200) return (json.decode(r.body)['message'] ?? '').toString();
    throw Exception(_err(r));
  }

  Future<String> request(int id, {required int menuId}) => _put(id, 'credit_request', {'menu_id': menuId});
  Future<String> approve(int id, {String? remarks}) => _put(id, 'credit_approve', {'remarks': remarks});
  Future<String> reject(int id, {String? remarks}) => _put(id, 'credit_reject', {'remarks': remarks});
  Future<String> withdraw(int id) => _put(id, 'credit_withdraw', {});

  Future<List<Map<String, dynamic>>> myPending() async {
    final headers = await _auth.getAuthHeader();
    final r = await http.get(Uri.parse('$base/$path/credit_my_pending'), headers: headers);
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(r.body));
    throw Exception(_err(r));
  }
}
