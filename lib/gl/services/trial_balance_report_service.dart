import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/auth_service.dart';

class TrialBalanceReportService {
  final String baseUrl = AppConfig.apiGl; // Adjust as needed
  final AuthService authService = AuthService();

  Future<List<Map<String, dynamic>>> getTrialBalance({
    required int fiscalYearId,
    int? periodId,
    bool showDimensions = false,
    bool hideZero = false,
    bool showHeaderTotals = false, // เพิ่ม parameter
  }) async {
    final headers = await authService.getAuthHeader();
    String query = 'fiscal_year_id=$fiscalYearId';
    if (periodId != null) query += '&period_id=$periodId';
    query += '&show_dimensions=$showDimensions';
    query += '&hide_zero=$hideZero';
    query += '&show_header_totals=$showHeaderTotals'; // ส่งไป Backend

    final response = await http.get(
      Uri.parse('$baseUrl/gl_trial_balance?$query'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load report: ${response.body}');
    }
  }
}