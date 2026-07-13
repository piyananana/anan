import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ArBillingStatusReportService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getBillingStatusReport({
    required String dateFrom,
    required String dateTo,
    int? branchId,
    List<int>? customerGroupIds,
    String? customerCodeFrom,
    String? customerCodeTo,
    String statusFilter = 'all',   // 'all' | 'pending' | 'paid' | 'void'
    String sortBy = 'doc_type',    // 'doc_type' | 'customer'
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{
      'date_from':     dateFrom,
      'date_to':       dateTo,
      'status_filter': statusFilter,
      'sort_by':       sortBy,
    };
    if (branchId != null)
      params['branch_id'] = branchId.toString();
    if (customerGroupIds != null && customerGroupIds.isNotEmpty)
      params['customer_group_id'] = customerGroupIds.join(',');
    if (customerCodeFrom != null && customerCodeFrom.isNotEmpty)
      params['customer_code_from'] = customerCodeFrom;
    if (customerCodeTo != null && customerCodeTo.isNotEmpty)
      params['customer_code_to'] = customerCodeTo;

    final uri = Uri.parse('$baseUrl/ar_billing_status_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List);
    }
    throw Exception(
        'Failed to load AR billing status report: ${response.body}');
  }
}
