import '../../../config/app_config.dart';
// File: services/report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/auth_service.dart';

class FinancialReportService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  Future<List<Map<String, dynamic>>> fetchReportMasters() async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/gl_financial_report_master_list'), 
      headers: headers
    );

    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } else {
      throw Exception('Failed to load report master list');
    }
  }

  Future<Map<String, dynamic>> generateReport(int reportId, int basePeriodId) async {
    final headers = await authService.getAuthHeader();
    headers['Content-Type'] = 'application/json';

    final res = await http.post(
      Uri.parse('$baseUrl/gl_financial_report_engine'), // ผูก Route นี้เข้ากับ Controller ด้วยนะครับ
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'report_id': reportId,
        'base_period_id': basePeriodId,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to generate report: ${res.body}');
    }
  }
}