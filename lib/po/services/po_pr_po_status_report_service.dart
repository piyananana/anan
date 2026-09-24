// lib/po/services/po_pr_po_status_report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../models/po_pr_po_status_report.dart';

class PrPoStatusReportService {
  final String baseUrl = AppConfig.apiPo;
  final AuthService authService = AuthService();

  Future<List<PrPoStatusReportRow>> fetchReport({
    DateTime? prDateFrom,
    DateTime? prDateTo,
    DateTime? poDateFrom,
    DateTime? poDateTo,
    List<String>? prStatuses,
    List<String>? poStatuses,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      if (prDateFrom != null) 'pr_date_from': formatLocalDate(prDateFrom),
      if (prDateTo != null) 'pr_date_to': formatLocalDate(prDateTo),
      if (poDateFrom != null) 'po_date_from': formatLocalDate(poDateFrom),
      if (poDateTo != null) 'po_date_to': formatLocalDate(poDateTo),
      if (prStatuses != null && prStatuses.isNotEmpty) 'pr_statuses': prStatuses.join(','),
      if (poStatuses != null && poStatuses.isNotEmpty) 'po_statuses': poStatuses.join(','),
    };
    final uri = Uri.parse('$baseUrl/pr_po_status_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => PrPoStatusReportRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดรายงานล้มเหลว');
  }
}
