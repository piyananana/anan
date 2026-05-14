import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class ArAgingReportService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getAgingReport({
    required String asOfDate,
    int? branchId,
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{'as_of_date': asOfDate};
    if (branchId != null) params['branch_id'] = branchId.toString();
    final uri = Uri.parse('$baseUrl/ar_aging_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load aging report: ${response.body}');
  }
}
