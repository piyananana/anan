import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class ApPaymentReportService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getPaymentReport({
    required String dateFrom,
    required String dateTo,
    List<int>? vendorGroupIds,
    String? vendorCodeFrom,
    String? vendorCodeTo,
    String sortBy = 'vendor',
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{
      'date_from': dateFrom,
      'date_to':   dateTo,
      'sort_by':   sortBy,
    };
    if (vendorGroupIds != null && vendorGroupIds.isNotEmpty)  params['vendor_group_id'] = vendorGroupIds.join(',');
    if (vendorCodeFrom != null && vendorCodeFrom.isNotEmpty) {
      params['vendor_code_from'] = vendorCodeFrom;
    }
    if (vendorCodeTo != null && vendorCodeTo.isNotEmpty) {
      params['vendor_code_to'] = vendorCodeTo;
    }

    final uri = Uri.parse('$baseUrl/ap_payment_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
          jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load AP payment report: ${response.body}');
  }
}
