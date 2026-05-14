import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class DailyTransactionReportService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getDailyTransactions({
    required int fiscalYearId,
    int? periodId,
    String? docDateFrom,
    String? docDateTo,
    List<String>? docCodes,
    String? docNoFrom,
    String? docNoTo,
    List<String>? refDocCodes,
    String? refDocNoFrom,
    String? refDocNoTo,
    String? refDocDateFrom,
    String? refDocDateTo,
    int? branchId,
  }) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{'fiscal_year_id': fiscalYearId.toString()};

    if (periodId != null) params['period_id'] = periodId.toString();
    if (docDateFrom != null) params['doc_date_from'] = docDateFrom;
    if (docDateTo != null) params['doc_date_to'] = docDateTo;
    if (docCodes != null && docCodes.isNotEmpty) params['doc_codes'] = docCodes.join(',');
    if (docNoFrom != null && docNoFrom.isNotEmpty) params['doc_no_from'] = docNoFrom;
    if (docNoTo != null && docNoTo.isNotEmpty) params['doc_no_to'] = docNoTo;
    if (refDocCodes != null && refDocCodes.isNotEmpty) params['ref_doc_codes'] = refDocCodes.join(',');
    if (refDocNoFrom != null && refDocNoFrom.isNotEmpty) params['ref_doc_no_from'] = refDocNoFrom;
    if (refDocNoTo != null && refDocNoTo.isNotEmpty) params['ref_doc_no_to'] = refDocNoTo;
    if (refDocDateFrom != null) params['ref_doc_date_from'] = refDocDateFrom;
    if (refDocDateTo != null) params['ref_doc_date_to'] = refDocDateTo;
    if (branchId != null) params['branch_id'] = branchId.toString();

    final uri = Uri.parse('$baseUrl/gl_daily_transaction').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final raw = json.decode(response.body);
      if (raw is! List) throw Exception('Unexpected response format');
      return List<Map<String, dynamic>>.from(raw);
    }
    throw Exception('Failed to load daily transactions: ${response.body}');
  }

  Future<List<Map<String, dynamic>>> getDocTypes() async {
    final headers = await _authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_daily_transaction/doc_types'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final raw = json.decode(response.body);
      return List<Map<String, dynamic>>.from(raw);
    }
    throw Exception('Failed to load doc types: ${response.body}');
  }
}
