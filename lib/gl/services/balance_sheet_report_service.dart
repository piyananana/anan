import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class BalanceSheetReportService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getBalanceSheet({
    required int fiscalYearId,
    int? periodId,
    int? branchId,
  }) async {
    final headers = await _authService.getAuthHeader();
    String query = 'fiscal_year_id=$fiscalYearId';
    if (periodId != null) query += '&period_id=$periodId';
    if (branchId != null) query += '&branch_id=$branchId';

    final response = await http.get(
      Uri.parse('$baseUrl/gl_balance_sheet?$query'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final dynamic raw = json.decode(response.body);
      if (raw is! List) {
        throw Exception('Unexpected response format from server');
      }
      return List<Map<String, dynamic>>.from(raw);
    }
    throw Exception('Failed to load balance sheet: ${response.body}');
  }
}
