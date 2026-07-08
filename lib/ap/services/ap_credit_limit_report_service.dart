import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class ApCreditLimitReportService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getCreditLimitReport({
    List<int>? vendorGroupIds,
    String? vendorCodeFrom,
    String? vendorCodeTo,
    String creditStatus = '',    // '' | 'over' | 'remaining' | 'full' | 'no_limit'
    String sortBy = 'vendor',   // 'vendor' | 'remaining_asc' | 'remaining_desc'
  }) async {
    final headers = await _authService.getAuthHeader();
    final params  = <String, String>{'sort_by': sortBy};
    if (vendorGroupIds != null && vendorGroupIds.isNotEmpty) {
      params['vendor_group_id'] = vendorGroupIds.join(',');
    }
    if (vendorCodeFrom != null && vendorCodeFrom.isNotEmpty) {
      params['vendor_code_from'] = vendorCodeFrom;
    }
    if (vendorCodeTo != null && vendorCodeTo.isNotEmpty) {
      params['vendor_code_to'] = vendorCodeTo;
    }
    if (creditStatus.isNotEmpty) params['credit_status'] = creditStatus;

    final uri = Uri.parse('$baseUrl/ap_credit_limit_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load AP credit limit report: ${response.body}');
  }
}
