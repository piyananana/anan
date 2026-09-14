import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ImConsignmentSettlementService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> fetchPending({int? vendorId}) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{};
    if (vendorId != null) params['vendor_id'] = '$vendorId';
    final uri = Uri.parse('$baseUrl/im_consignment_settlement/pending').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load pending consignment settlement rows: ${response.body}');
  }

  Future<Map<String, dynamic>> postSettlement({
    required int vendorId,
    required List<int> consumptionIds,
    String? refNo,
    String? docDate,
  }) async {
    final headers = await _authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_consignment_settlement');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'vendor_id': vendorId,
        'consumption_ids': consumptionIds,
        if (refNo != null && refNo.isNotEmpty) 'ref_no': refNo,
        if (docDate != null) 'doc_date': docDate,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Settlement failed');
  }

  Future<List<Map<String, dynamic>>> fetchSettled({required int vendorId}) async {
    final headers = await _authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_consignment_settlement').replace(queryParameters: {'vendor_id': '$vendorId'});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load consignment settlement history: ${response.body}');
  }

  Future<Map<String, dynamic>> voidSettlement(int id) async {
    final headers = await _authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_consignment_settlement/$id/void');
    final response = await http.put(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Void failed');
  }
}
