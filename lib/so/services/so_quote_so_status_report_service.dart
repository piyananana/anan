// lib/so/services/so_quote_so_status_report_service.dart — มิเรอร์ po_pr_po_status_report_service.dart ทุกประการ
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../models/so_quote_so_status_report.dart';

class QuoteSoStatusReportService {
  final String baseUrl = AppConfig.apiSo;
  final AuthService authService = AuthService();

  Future<List<QuoteSoStatusReportRow>> fetchReport({
    DateTime? quoteDateFrom,
    DateTime? quoteDateTo,
    DateTime? soDateFrom,
    DateTime? soDateTo,
    List<String>? quoteStatuses,
    List<String>? soStatuses,
    bool showQuote = true,
    bool showSo = true,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      if (quoteDateFrom != null) 'quote_date_from': formatLocalDate(quoteDateFrom),
      if (quoteDateTo != null) 'quote_date_to': formatLocalDate(quoteDateTo),
      if (soDateFrom != null) 'so_date_from': formatLocalDate(soDateFrom),
      if (soDateTo != null) 'so_date_to': formatLocalDate(soDateTo),
      if (quoteStatuses != null && quoteStatuses.isNotEmpty) 'quote_statuses': quoteStatuses.join(','),
      if (soStatuses != null && soStatuses.isNotEmpty) 'so_statuses': soStatuses.join(','),
      'show_quote': showQuote.toString(),
      'show_so': showSo.toString(),
    };
    final uri = Uri.parse('$baseUrl/quote_so_status_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => QuoteSoStatusReportRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดรายงานล้มเหลว');
  }
}
