import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/sa_auth_service.dart';

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
    _throwIfValidationError(res);
    throw Exception('Failed to create column: ${res.body}');
  }

  Future<Map<String, dynamic>> updateColumn(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report_column/$id'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 200) return jsonDecode(res.body);
    _throwIfValidationError(res);
    throw Exception('Failed to update column: ${res.body}');
  }

  // 400/409 ที่มี code = ข้อมูลไม่ผ่านการตรวจ (สูตร, รหัสคอลัมน์ซ้ำ, รหัสที่ถูกอ้างอิงอยู่ ฯลฯ)
  void _throwIfValidationError(http.Response res) {
    if (res.statusCode != 400 && res.statusCode != 409) return;
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } on FormatException {
      return;
    }
    if (body is Map && body['code'] != null) {
      throw FinReportValidationException(
        body['code'].toString(),
        body['error']?.toString() ?? '',
        Map<String, dynamic>.from((body['detail'] as Map?) ?? const {}),
      );
    }
  }

  Future<void> deleteColumn(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/gl_fin_report_column/$id'), headers: headers);
    if (res.statusCode != 204) throw Exception('Failed to delete column');
  }

  // --- gl_fin_report_col (คอลัมน์ระดับรายงาน ใช้กับทุกบรรทัด) ---

  Future<List<Map<String, dynamic>>> fetchReportCols(int reportId) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/gl_fin_report_col/$reportId'), headers: headers);
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load report columns');
  }

  Future<Map<String, dynamic>> createReportCol(Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/gl_fin_report_col'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 201) return jsonDecode(res.body);
    _throwIfValidationError(res);
    throw Exception('Failed to create report column: ${res.body}');
  }

  Future<Map<String, dynamic>> updateReportCol(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report_col/$id'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 200) return jsonDecode(res.body);
    _throwIfValidationError(res);
    throw Exception('Failed to update report column: ${res.body}');
  }

  Future<void> deleteReportCol(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/gl_fin_report_col/$id'), headers: headers);
    if (res.statusCode == 204) return;
    _throwIfValidationError(res);
    throw Exception('Failed to delete report column');
  }
}

/// ข้อมูลรายงานงบการเงินไม่ผ่านการตรวจที่ backend
/// code: SYNTAX | UNKNOWN_REF | CIRCULAR | INVALID_CODE | INVALID_SEQ | INVALID_KIND | DUPLICATE_CODE | DUPLICATE_SEQ | REF_IN_USE
class FinReportValidationException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> detail;
  FinReportValidationException(this.code, this.message, this.detail);

  /// ข้อความสำหรับผู้ใช้ (ไทย/อังกฤษ) — message จาก backend เป็นภาษาอังกฤษ ใช้เป็นรายละเอียดของ SYNTAX
  String localized(bool isEnglish) {
    final ref = detail['code'] != null ? '[${detail['code']}]' : '';
    final usages = (detail['usages'] as List?)?.join(', ') ?? '';
    switch (code) {
      case 'UNKNOWN_REF':
        return isEnglish ? 'Column $ref not found in this report' : 'ไม่พบคอลัมน์ $ref ในรายงานนี้';
      case 'CIRCULAR':
        return isEnglish ? 'Column $ref cannot reference itself' : 'คอลัมน์ $ref อ้างอิงตัวเองไม่ได้';
      case 'INVALID_CODE':
        return isEnglish
            ? 'Column code must start with a letter and use only A-Z, 0-9, _ (max 20)'
            : 'รหัสคอลัมน์ต้องขึ้นต้นด้วยตัวอักษร และใช้ได้เฉพาะ A-Z, 0-9, _ (ไม่เกิน 20 ตัว)';
      case 'INVALID_SEQ':
        return isEnglish ? 'Sequence is required' : 'กรุณาระบุลำดับ';
      case 'DUPLICATE_CODE':
        return isEnglish ? 'This column code already exists in the report' : 'รหัสคอลัมน์นี้มีอยู่แล้วในรายงาน';
      case 'DUPLICATE_SEQ':
        return isEnglish ? 'This sequence already exists in the report' : 'ลำดับนี้มีอยู่แล้วในรายงาน';
      case 'REF_IN_USE':
        return isEnglish ? '$ref is used by $usages' : '$ref ถูกใช้อยู่ใน $usages';
      default:
        return isEnglish ? 'Invalid formula: $message' : 'สูตรคำนวณไม่ถูกต้อง: $message';
    }
  }

  @override
  String toString() => message;
}
