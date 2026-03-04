import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/auth_service.dart';
import '../models/gl_beginning_balance.dart';

class GlBeginningBalanceService {
  // final String baseUrl = "http://your-api-url/api/gl/beginning-balance"; // แก้ไข URL
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  Future<List<GlBeginningBalance>> fetchByYearId(int yearId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_beginning_balance/year/$yearId'),
      headers: headers,
      );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => GlBeginningBalance.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load balances');
    }
  }

  Future<List<GlBeginningBalance>> fetchByPeriodId(int postingPeriodId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_beginning_balance/period/$postingPeriodId'),
      headers: headers,
      );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => GlBeginningBalance.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load balances');
    }
  }

  Future<void> saveBeginningBalances(int postingPeriodId, List<GlBeginningBalance> balances) async {
    final headers = await authService.getAuthHeader();
    final body = json.encode({
      'posting_period_id': postingPeriodId,
      'balances': balances.map((e) => e.toJson()).toList(),
    });

    final response = await http.post(
      Uri.parse('$baseUrl/gl_beginning_balance/save'),
      // headers: {'Content-Type': 'application/json'},
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save balances');
    }
  }
}