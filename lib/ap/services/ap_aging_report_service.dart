import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ApAgingReportService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getAgingReport({
    required String asOfDate,
    int? branchId,
    String? vendorCodeFrom,
    String? vendorCodeTo,
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{'as_of_date': asOfDate};
    if (branchId != null) params['branch_id'] = branchId.toString();
    if (vendorCodeFrom != null && vendorCodeFrom.isNotEmpty) params['vendor_code_from'] = vendorCodeFrom;
    if (vendorCodeTo != null && vendorCodeTo.isNotEmpty) params['vendor_code_to'] = vendorCodeTo;
    final uri = Uri.parse('$baseUrl/ap_aging_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load AP aging report: ${response.body}');
  }
}
