import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ArBulkBillingService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getBcDocTypes() async {
    final headers = await _authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ar_bc_document_types');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load BC doc types: ${response.body}');
  }

  Future<Map<String, dynamic>> createBulkBilling({
    required String billingDate,
    required int bcDocId,
    required List<Map<String, dynamic>> customerGroups,
  }) async {
    final headers = await _authService.getAuthHeader();
    final body = jsonEncode({
      'billing_date':    billingDate,
      'bc_doc_id':       bcDocId,
      'customer_groups': customerGroups,
    });
    final uri = Uri.parse('$baseUrl/ar_bulk_billing');
    final response = await http.post(uri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create bulk billing: ${response.body}');
  }
}
