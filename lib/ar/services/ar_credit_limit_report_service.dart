import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ArCreditLimitReportService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getCreditLimitReport({
    List<int>? customerGroupIds,
    int? salespersonId,
    String? customerCodeFrom,
    String? customerCodeTo,
    String creditStatus = '',      // '' | 'over' | 'remaining' | 'full'
    String sortBy = 'customer',   // 'customer' | 'remaining_asc' | 'remaining_desc'
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{'sort_by': sortBy};
    if (customerGroupIds != null && customerGroupIds.isNotEmpty) params['customer_group_id'] = customerGroupIds.join(',');
    if (salespersonId   != null) params['salesperson_id']    = salespersonId.toString();
    if (customerCodeFrom != null && customerCodeFrom.isNotEmpty) {
      params['customer_code_from'] = customerCodeFrom;
    }
    if (customerCodeTo != null && customerCodeTo.isNotEmpty) {
      params['customer_code_to'] = customerCodeTo;
    }
    if (creditStatus.isNotEmpty) params['credit_status'] = creditStatus;

    final uri = Uri.parse('$baseUrl/ar_credit_limit_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load AR credit limit report: ${response.body}');
  }
}
