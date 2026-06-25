import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class ArFxGainLossReportService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getFxGainLossReport({
    required String dateFrom,
    required String dateTo,
    String? currencyCode,
    List<int>? customerGroupIds,
    int? salespersonId,
    String? customerCodeFrom,
    String? customerCodeTo,
    bool fxOnly = false,
    String sortBy = 'customer', // 'customer' | 'net_desc' | 'net_asc'
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
    if (customerGroupIds != null && customerGroupIds.isNotEmpty)  params['customer_group_id'] = customerGroupIds.join(',');
    if (salespersonId   != null)  params['salesperson_id']    = salespersonId.toString();
    if (customerCodeFrom != null && customerCodeFrom.isNotEmpty) {
      params['customer_code_from'] = customerCodeFrom;
    }
    if (customerCodeTo != null && customerCodeTo.isNotEmpty) {
      params['customer_code_to'] = customerCodeTo;
    }

    final uri = Uri.parse('$baseUrl/ar_fx_gain_loss_report')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      // returns { base_currency_code, rows: [...] }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load AR FX gain/loss report: ${response.body}');
  }
}
