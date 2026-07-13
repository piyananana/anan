import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ApFxGainLossReportService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getFxGainLossReport({
    required String dateFrom,
    required String dateTo,
    String? currencyCode,
    List<int>? vendorGroupIds,
    String? vendorCodeFrom,
    String? vendorCodeTo,
    bool fxOnly = false,
    String sortBy = 'vendor',
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{
      'date_from': dateFrom,
      'date_to':   dateTo,
      'sort_by':   sortBy,
      if (fxOnly) 'fx_only': 'true',
    };
    if (currencyCode != null && currencyCode.isNotEmpty) {
      params['currency_code'] = currencyCode;
    }
    if (vendorGroupIds != null && vendorGroupIds.isNotEmpty) params['vendor_group_id'] = vendorGroupIds.join(',');
    if (vendorCodeFrom != null && vendorCodeFrom.isNotEmpty) {
      params['vendor_code_from'] = vendorCodeFrom;
    }
    if (vendorCodeTo != null && vendorCodeTo.isNotEmpty) {
      params['vendor_code_to'] = vendorCodeTo;
    }

    final uri = Uri.parse('$baseUrl/ap_fx_gain_loss_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load AP FX gain/loss report: ${response.body}');
  }
}
