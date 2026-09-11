import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ImStockBalanceByItemReportService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getReport({
    required String dateTo,
    List<int>? categoryIds,
    String? itemCodeFrom,
    String? itemCodeTo,
    String? costingMethod,
    List<int>? warehouseIds,
    String? locationCodeFrom,
    String? locationCodeTo,
    String? balanceFilter,
    String? sort,
    String? sortDir,
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{'date_to': dateTo};
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['category_ids'] = categoryIds.join(',');
    }
    if (itemCodeFrom != null && itemCodeFrom.isNotEmpty) params['item_code_from'] = itemCodeFrom;
    if (itemCodeTo != null && itemCodeTo.isNotEmpty) params['item_code_to'] = itemCodeTo;
    if (costingMethod != null && costingMethod.isNotEmpty) params['costing_method'] = costingMethod;
    if (warehouseIds != null && warehouseIds.isNotEmpty) {
      params['warehouse_ids'] = warehouseIds.join(',');
    }
    if (locationCodeFrom != null && locationCodeFrom.isNotEmpty) params['location_code_from'] = locationCodeFrom;
    if (locationCodeTo != null && locationCodeTo.isNotEmpty) params['location_code_to'] = locationCodeTo;
    if (balanceFilter != null && balanceFilter.isNotEmpty) params['balance_filter'] = balanceFilter;
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    if (sortDir != null && sortDir.isNotEmpty) params['sort_dir'] = sortDir;

    final uri = Uri.parse('$baseUrl/im_stock_balance_by_item_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load IM stock balance by item report: ${response.body}');
  }
}
