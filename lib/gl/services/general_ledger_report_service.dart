import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/sa_auth_service.dart';

class GeneralLedgerReportService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  Future<List<Map<String, dynamic>>> getGlTransactions({
    int? periodId,
    required int fiscalYearId,
    String? accountFrom,
    String? accountTo,
    int? branchId,
  }) async {
    final headers = await authService.getAuthHeader();

    // สร้าง Query Parameters
    List<String> queryParams = ['fiscal_year_id=$fiscalYearId'];
    if (periodId != null) queryParams.add('period_id=$periodId');
    if (accountFrom != null && accountFrom.isNotEmpty) {
      queryParams.add('account_from=$accountFrom');
    }
    if (accountTo != null && accountTo.isNotEmpty) {
      queryParams.add('account_to=$accountTo');
    }
    if (branchId != null) queryParams.add('branch_id=$branchId');
    
    final String queryString = queryParams.join('&');
    final response = await http.get(
      Uri.parse('$baseUrl/gl_general_ledger?$queryString'), // ปรับ URL ตาม Route ของคุณ
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load GL transactions: ${response.body}');
    }
  }

  /// ยอดยกมา = สะสม gl_balance_accum ทุกงวดที่มี period_number < งวดที่เลือก
  Future<List<Map<String, dynamic>>> fetchBeginningBalance({
    required int fiscalYearId,
    int? periodId,
    int? branchId,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = ['fiscal_year_id=$fiscalYearId'];
    if (periodId != null) params.add('period_id=$periodId');
    if (branchId != null) params.add('branch_id=$branchId');
    final response = await http.get(
      Uri.parse('$baseUrl/gl_report_beginning_balance?${params.join('&')}'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load beginning balance: ${response.body}');
    }
  }
}