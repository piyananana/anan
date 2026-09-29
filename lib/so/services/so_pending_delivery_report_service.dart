// lib/so/services/so_pending_delivery_report_service.dart — มิเรอร์ po_pending_receipt_report_service.dart ทุกประการ
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../models/so_pending_delivery_report.dart';

class SoPendingDeliveryReportService {
  final String baseUrl = AppConfig.apiSo;
  final AuthService authService = AuthService();

  Future<List<SoPendingDeliveryReportRow>> fetchReport({
    DateTime? soDateFrom,
    DateTime? soDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    List<int>? customerIds,
    List<int>? itemIds,
    bool sortDueDateAsc = true,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      if (soDateFrom != null) 'so_date_from': formatLocalDate(soDateFrom),
      if (soDateTo != null) 'so_date_to': formatLocalDate(soDateTo),
      if (dueDateFrom != null) 'due_date_from': formatLocalDate(dueDateFrom),
      if (dueDateTo != null) 'due_date_to': formatLocalDate(dueDateTo),
      if (customerIds != null && customerIds.isNotEmpty) 'customer_ids': customerIds.join(','),
      if (itemIds != null && itemIds.isNotEmpty) 'item_ids': itemIds.join(','),
      'sort_due_date': sortDueDateAsc ? 'asc' : 'desc',
    };
    final uri = Uri.parse('$baseUrl/so_pending_delivery_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => SoPendingDeliveryReportRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดรายงานล้มเหลว');
  }
}
