import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ImTransactionReportService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getTransactionReport({
    required String dateFrom,
    required String dateTo,
    List<String>? sysDocTypes,
    String sort = 'asc', // 'asc' | 'desc' — เรียงตามวันที่เอกสาร
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{
      'date_from': dateFrom,
      'date_to': dateTo,
      'sort': sort,
    };
    if (sysDocTypes != null && sysDocTypes.isNotEmpty) {
      params['sys_doc_types'] = sysDocTypes.join(',');
    }
    final uri = Uri.parse('$baseUrl/im_transaction_report').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load IM transaction report: ${response.body}');
  }
}
