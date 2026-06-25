import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class ArBillingPlanReportService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getBillingPlanReport({
    required String dateFrom,
    required String dateTo,
    List<int>? customerGroupIds,
    int? billingCollectorId,
    String? customerCodeFrom,
    String? customerCodeTo,
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{
      'date_from': dateFrom,
      'date_to':   dateTo,
    };
    if (customerGroupIds != null && customerGroupIds.isNotEmpty) {
      params['customer_group_id'] = customerGroupIds.join(',');
    }
    if (billingCollectorId != null) {
      params['billing_collector_id'] = billingCollectorId.toString();
    }
    if (customerCodeFrom != null && customerCodeFrom.isNotEmpty) {
      params['customer_code_from'] = customerCodeFrom;
    }
    if (customerCodeTo != null && customerCodeTo.isNotEmpty) {
      params['customer_code_to'] = customerCodeTo;
    }
    final uri = Uri.parse('$baseUrl/ar_billing_plan_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load billing plan report: ${response.body}');
  }
}
