// lib/gl/services/year_end_closing_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/year_end_closing.dart';

class YearEndClosingService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  // ─── Closing Config ────────────────────────────────────────────────────────

  Future<ClosingConfig> fetchConfig() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/gl_closing_config'), headers: headers);
    if (response.statusCode == 200) {
      return ClosingConfig.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load config');
  }

  Future<void> saveConfig(ClosingConfig config) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_closing_config'),
      headers: headers,
      body: jsonEncode(config.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to save config');
    }
  }

  // ─── Adjusting Templates ───────────────────────────────────────────────────

  Future<List<AdjustingTemplate>> fetchTemplates() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/gl_adjusting_template'), headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => AdjustingTemplate.fromJson(j)).toList();
    }
    throw Exception('Failed to load templates');
  }

  Future<AdjustingTemplate> addTemplate(AdjustingTemplate t) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_adjusting_template'),
      headers: headers,
      body: jsonEncode(t.toJson()),
    );
    if (response.statusCode == 201) return AdjustingTemplate.fromJson(jsonDecode(response.body));
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to add template');
  }

  Future<AdjustingTemplate> updateTemplate(AdjustingTemplate t) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/gl_adjusting_template/${t.id}'),
      headers: headers,
      body: jsonEncode(t.toJson()),
    );
    if (response.statusCode == 200) return AdjustingTemplate.fromJson(jsonDecode(response.body));
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to update template');
  }

  Future<void> deleteTemplate(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/gl_adjusting_template/$id'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete template');
  }

  // ─── Year-End Closing Wizard ───────────────────────────────────────────────

  Future<YearEndClosing> getOrInitClosing(int fiscalYearId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_year_end_closing/$fiscalYearId'),
      headers: headers,
    );
    if (response.statusCode == 200) return YearEndClosing.fromJson(jsonDecode(response.body));
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load closing');
  }

  Future<void> confirmStep2(int closingId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step2/confirm'),
      headers: headers,
      body: '{}',
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Step 2 failed');
    }
  }

  Future<Map<String, dynamic>> runStep1(int closingId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step1'),
      headers: headers,
      body: '{}',
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(response.body)['message'] ?? 'Step 1 failed');
  }

  Future<List<ClosingPreviewLine>> previewStep3(int closingId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step3/preview'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => ClosingPreviewLine.fromJson(j)).toList();
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Preview step 3 failed');
  }

  Future<Map<String, dynamic>> confirmStep3(int closingId, String docDate, int createdBy) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step3/confirm'),
      headers: headers,
      body: jsonEncode({'doc_date': docDate, 'created_by': createdBy}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(response.body)['message'] ?? 'Confirm step 3 failed');
  }

  Future<Map<String, dynamic>> previewStep4(int closingId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step4/preview'),
      headers: headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(response.body)['message'] ?? 'Preview step 4 failed');
  }

  Future<Map<String, dynamic>> confirmStep4(int closingId, String docDate, int createdBy) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step4/confirm'),
      headers: headers,
      body: jsonEncode({'doc_date': docDate, 'created_by': createdBy}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(response.body)['message'] ?? 'Confirm step 4 failed');
  }

  Future<List<ClosingPreviewLine>> previewStep5(int closingId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step5/preview'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => ClosingPreviewLine.fromJson(j)).toList();
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Preview step 5 failed');
  }

  Future<Map<String, dynamic>> confirmStep5(
      int closingId, String docDate, int nextFiscalYearId, int createdBy) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step5/confirm'),
      headers: headers,
      body: jsonEncode({
        'doc_date': docDate,
        'next_fiscal_year_id': nextFiscalYearId,
        'created_by': createdBy,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(jsonDecode(response.body)['message'] ?? 'Confirm step 5 failed');
  }

  Future<void> confirmStep6(int closingId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_year_end_closing/$closingId/step6/confirm'),
      headers: headers,
      body: '{}',
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Confirm step 6 failed');
    }
  }
}
