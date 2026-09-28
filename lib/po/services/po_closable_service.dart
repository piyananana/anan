// lib/po/services/po_closable_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../models/po_closable_row.dart';

class PoClosableService {
  final String baseUrl = AppConfig.apiPo;
  final AuthService authService = AuthService();

  Future<List<PoClosableRow>> fetchClosableList({
    DateTime? poDateFrom,
    DateTime? poDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    List<int>? vendorIds,
    List<String>? statuses,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      if (poDateFrom != null) 'po_date_from': formatLocalDate(poDateFrom),
      if (poDateTo != null) 'po_date_to': formatLocalDate(poDateTo),
      if (dueDateFrom != null) 'due_date_from': formatLocalDate(dueDateFrom),
      if (dueDateTo != null) 'due_date_to': formatLocalDate(dueDateTo),
      if (vendorIds != null && vendorIds.isNotEmpty) 'vendor_ids': vendorIds.join(','),
      if (statuses != null && statuses.isNotEmpty) 'statuses': statuses.join(','),
    };
    final uri = Uri.parse('$baseUrl/po_transaction/closable_list').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => PoClosableRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดรายการใบสั่งซื้อล้มเหลว');
  }
}
