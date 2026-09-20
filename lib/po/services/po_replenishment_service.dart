// lib/po/services/po_replenishment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/po_replenishment.dart';

class PoReplenishmentService {
  final String baseUrl = AppConfig.apiPo;
  final AuthService authService = AuthService();

  Future<List<ReplenishmentSuggestion>> fetchSuggestions({
    required List<int> warehouseIds,
    required String asOf,
    required int lookbackDays,
    required int coverageDays,
    List<int>? categoryIds,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      'warehouse_ids': warehouseIds.join(','),
      'as_of': asOf,
      'lookback_days': lookbackDays.toString(),
      'coverage_days': coverageDays.toString(),
      if (categoryIds != null && categoryIds.isNotEmpty) 'category_ids': categoryIds.join(','),
    };
    final uri = Uri.parse('$baseUrl/po_replenishment/suggestions').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ReplenishmentSuggestion.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดใบแนะนำสั่งซื้อล้มเหลว');
  }
}
