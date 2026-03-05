import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/auth_service.dart';

class FinancialReportBuilderService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  // --- gl_fin_report ---

  Future<List<Map<String, dynamic>>> fetchReports() async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/gl_fin_report'), headers: headers);
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load reports');
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/gl_fin_report'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('Failed to create report: ${res.body}');
  }

  Future<Map<String, dynamic>> updateReport(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report/$id'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update report: ${res.body}');
  }

  Future<void> deleteReport(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/gl_fin_report/$id'), headers: headers);
    if (res.statusCode != 204) throw Exception('Failed to delete report');
  }

  // --- gl_fin_report_row ---

  Future<List<Map<String, dynamic>>> fetchRows(int reportId) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/gl_fin_report_row/$reportId'), headers: headers);
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load rows');
  }

  Future<Map<String, dynamic>> createRow(Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/gl_fin_report_row'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('Failed to create row: ${res.body}');
  }

  Future<Map<String, dynamic>> updateRow(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report_row/$id'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update row: ${res.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/gl_fin_report_row/$id'), headers: headers);
    if (res.statusCode != 204) throw Exception('Failed to delete row');
  }

  // --- gl_fin_report_column ---

  Future<Map<String, dynamic>> createColumn(Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/gl_fin_report_column'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('Failed to create column: ${res.body}');
  }

  Future<Map<String, dynamic>> updateColumn(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report_column/$id'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update column: ${res.body}');
  }

  Future<void> deleteColumn(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/gl_fin_report_column/$id'), headers: headers);
    if (res.statusCode != 204) throw Exception('Failed to delete column');
  }
}
