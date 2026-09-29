// lib/so/services/so_closable_service.dart — มิเรอร์ po_closable_service.dart ทุกประการ (vendor->customer)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../models/so_closable_row.dart';

class SoClosableService {
  final String baseUrl = AppConfig.apiSo;
  final AuthService authService = AuthService();

  Future<List<SoClosableRow>> fetchClosableList({
    DateTime? soDateFrom,
    DateTime? soDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    List<int>? customerIds,
    List<String>? statuses,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{
      if (soDateFrom != null) 'so_date_from': formatLocalDate(soDateFrom),
      if (soDateTo != null) 'so_date_to': formatLocalDate(soDateTo),
      if (dueDateFrom != null) 'due_date_from': formatLocalDate(dueDateFrom),
      if (dueDateTo != null) 'due_date_to': formatLocalDate(dueDateTo),
      if (customerIds != null && customerIds.isNotEmpty) 'customer_ids': customerIds.join(','),
      if (statuses != null && statuses.isNotEmpty) 'statuses': statuses.join(','),
    };
    final uri = Uri.parse('$baseUrl/so_transaction/closable_list').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => SoClosableRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'โหลดรายการใบสั่งขายล้มเหลว');
  }
}
