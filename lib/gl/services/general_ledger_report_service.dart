import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/auth_service.dart';

class GeneralLedgerReportService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  Future<List<Map<String, dynamic>>> getGlTransactions({
    required int periodId,
    String? accountFrom,
    String? accountTo,
  }) async {
    final headers = await authService.getAuthHeader();
    
    // สร้าง Query Parameters
    List<String> queryParams = ['period_id=$periodId'];
    if (accountFrom != null && accountFrom.isNotEmpty) {
      queryParams.add('account_from=$accountFrom');
    }
    if (accountTo != null && accountTo.isNotEmpty) {
      queryParams.add('account_to=$accountTo');
    }
    
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
}