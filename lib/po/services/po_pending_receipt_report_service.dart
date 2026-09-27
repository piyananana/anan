// lib/po/services/po_pending_receipt_report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../models/po_pending_receipt_report.dart';

class PoPendingReceiptReportService {
  final String baseUrl = AppConfig.apiPo;
  final AuthService authService = AuthService();

  Future<List<PoPendingReceiptReportRow>> fetchReport({
    DateTime? poDateFrom,
    DateTime? poDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    List<int>? vendorIds,
    List<int>? itemIds,
    bool sortDueDateAsc = true,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      if (poDateFrom != null) 'po_date_from': formatLocalDate(poDateFrom),
      if (poDateTo != null) 'po_date_to': formatLocalDate(poDateTo),
      if (dueDateFrom != null) 'due_date_from': formatLocalDate(dueDateFrom),
      if (dueDateTo != null) 'due_date_to': formatLocalDate(dueDateTo),
      if (vendorIds != null && vendorIds.isNotEmpty) 'vendor_ids': vendorIds.join(','),
      if (itemIds != null && itemIds.isNotEmpty) 'item_ids': itemIds.join(','),
      'sort_due_date': sortDueDateAsc ? 'asc' : 'desc',
    };
    final uri = Uri.parse('$baseUrl/po_pending_receipt_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => PoPendingReceiptReportRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดรายงานล้มเหลว');
  }
}
