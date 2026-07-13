import '../../../config/app_config.dart';
// File: services/report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/sa_auth_service.dart';

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

  Future<Map<String, dynamic>> generateReport(
    int reportId,
    int basePeriodId, {
    int? branchId,
    int? dim1Id,
    int? dim2Id,
    int? dim3Id,
    int? dim4Id,
    int? dim5Id,
  }) async {
    final headers = await authService.getAuthHeader();
    headers['Content-Type'] = 'application/json';

    final res = await http.post(
      Uri.parse('$baseUrl/gl_financial_report_engine'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'report_id': reportId,
        'base_period_id': basePeriodId,
        if (branchId != null) 'branch_id': branchId,
        if (dim1Id != null) 'dim1_id': dim1Id,
        if (dim2Id != null) 'dim2_id': dim2Id,
        if (dim3Id != null) 'dim3_id': dim3Id,
        if (dim4Id != null) 'dim4_id': dim4Id,
        if (dim5Id != null) 'dim5_id': dim5Id,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to generate report: ${res.body}');
    }
  }
}