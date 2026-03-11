import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class IncomeStatementReportService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getIncomeStatement({
    required int fiscalYearId,
    int? periodId,
  }) async {
    final headers = await _authService.getAuthHeader();
    String query = 'fiscal_year_id=$fiscalYearId';
    if (periodId != null) query += '&period_id=$periodId';

    final response = await http.get(
      Uri.parse('$baseUrl/gl_income_statement?$query'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final dynamic raw = json.decode(response.body);
      if (raw is! List) {
        throw Exception('Unexpected response format from server');
      }
      return List<Map<String, dynamic>>.from(raw);
    }
    throw Exception('Failed to load income statement: ${response.body}');
  }
}
