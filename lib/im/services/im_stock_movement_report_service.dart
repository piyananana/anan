import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ImStockMovementReportService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getReport({
    required String dateFrom,
    required String dateTo,
    List<int>? warehouseIds,
    List<int>? categoryIds,
    String? itemCodeFrom,
    String? itemCodeTo,
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{
      'date_from': dateFrom,
      'date_to': dateTo,
    };
    if (warehouseIds != null && warehouseIds.isNotEmpty) {
      params['warehouse_ids'] = warehouseIds.join(',');
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['category_ids'] = categoryIds.join(',');
    }
    if (itemCodeFrom != null && itemCodeFrom.isNotEmpty) {
      params['item_code_from'] = itemCodeFrom;
    }
    if (itemCodeTo != null && itemCodeTo.isNotEmpty) {
      params['item_code_to'] = itemCodeTo;
    }
    final uri = Uri.parse('$baseUrl/im_stock_movement_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load IM stock movement report: ${response.body}');
  }
}
