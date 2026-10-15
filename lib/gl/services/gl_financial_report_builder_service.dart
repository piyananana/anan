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

  // --- export / import / แม่แบบ (ย้ายแบบงบข้ามฐานข้อมูล) ---

  /// แบบงบทั้งชุดเป็น JSON (ไม่มี id — สาขา/มิติเป็นรหัส)
  Future<Map<String, dynamic>> exportReport(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/gl_fin_report/$id/export'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to export report: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/gl_fin_report_templates'), headers: headers);
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load templates');
  }

  /// สร้างงบจากไฟล์ที่ export มา ([data]) หรือจากแม่แบบ ([templateId])
  /// คืน { report, warnings, empty_account_rows }
  Future<Map<String, dynamic>> importReport({
    Map<String, dynamic>? data,
    String? templateId,
    required String reportCode,
    String? reportNameThai,
    String? reportNameEng,
  }) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(Uri.parse('$baseUrl/gl_fin_report_import'), headers: headers, body: jsonEncode({
      if (data != null) 'data': data,
      if (templateId != null) 'template': templateId,
      'report_code': reportCode,
      if (reportNameThai != null && reportNameThai.isNotEmpty) 'report_name_thai': reportNameThai,
      if (reportNameEng != null && reportNameEng.isNotEmpty) 'report_name_eng': reportNameEng,
    }));
    if (res.statusCode == 201) return jsonDecode(res.body);
    _throwIfValidationError(res);
    throw Exception('Failed to import report: ${res.body}');
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
    _throwIfValidationError(res);
    throw Exception('Failed to create row: ${res.body}');
  }

  Future<Map<String, dynamic>> updateRow(int id, Map<String, dynamic> data) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report_row/$id'), headers: headers, body: jsonEncode(data));
    if (res.statusCode == 200) return jsonDecode(res.body);
    _throwIfValidationError(res);
    throw Exception('Failed to update row: ${res.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(Uri.parse('$baseUrl/gl_fin_report_row/$id'), headers: headers);
    if (res.statusCode == 204) return;
    _throwIfValidationError(res);
    throw Exception('Failed to delete row');
  }

  /// เรียงบรรทัดใหม่ตาม [rowIds] (ทุกบรรทัดของรายงาน) — คืน { rows, formulas_updated }
  Future<Map<String, dynamic>> reorderRows(int reportId, List<int> rowIds) async {
    final headers = await authService.getAuthHeader();
    final res = await http.put(Uri.parse('$baseUrl/gl_fin_report/$reportId/reorder_rows'),
        headers: headers, body: jsonEncode({'row_ids': rowIds}));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to reorder rows: ${res.body}');
  }

  /// ตรวจผังบัญชี: บัญชีลงรายการแต่ละบัญชีอยู่ในบรรทัด ACCOUNTS ใดบ้าง (rows ว่าง = ไม่อยู่ในงบ, >1 = นับซ้ำ)
  Future<List<Map<String, dynamic>>> fetchAccountMapping(int reportId) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(Uri.parse('$baseUrl/gl_fin_report/$reportId/account_mapping'), headers: headers);
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load account mapping');
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
///       | DUPLICATE_LABEL | CODE_REQUIRED | UNKNOWN_ACCOUNT | INVALID_RANGE
class FinReportValidationException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> detail;
  FinReportValidationException(this.code, this.message, this.detail);

  /// ข้อความสำหรับผู้ใช้ (ไทย/อังกฤษ) — message จาก backend เป็นภาษาอังกฤษ ใช้เป็นรายละเอียดของ SYNTAX
  /// [forRow] = ข้อผิดพลาดจากการบันทึกบรรทัด (ใช้คำว่า "บรรทัด" แทน "คอลัมน์")
  String localized(bool isEnglish, {bool forRow = false}) {
    final isRowRef = detail['row_code'] != null;
    final ref = isRowRef ? '${detail['row_code']}' : (detail['code'] != null ? '[${detail['code']}]' : '');
    final what = isRowRef ? (isEnglish ? 'Row' : 'บรรทัด') : (isEnglish ? 'Column' : 'คอลัมน์');
    final usages = (detail['usages'] as List?)?.join(', ') ?? '';
    switch (code) {
      case 'UNKNOWN_REF':
        return isEnglish ? '$what $ref not found in this report' : 'ไม่พบ$what $ref ในรายงานนี้';
      case 'CIRCULAR':
        return isEnglish ? '$what $ref refers back to itself' : '$what $ref อ้างอิงวนกลับมาที่ตัวเอง';
      case 'INVALID_CODE':
        return forRow
            ? (isEnglish
                ? 'Row code must start with a letter, use only A-Z, 0-9, _ (max 30) and not be a function name (ABS, ROUND, MIN, MAX)'
                : 'รหัสบรรทัดต้องขึ้นต้นด้วยตัวอักษร ใช้ได้เฉพาะ A-Z, 0-9, _ (ไม่เกิน 30 ตัว) และห้ามซ้ำชื่อฟังก์ชัน (ABS, ROUND, MIN, MAX)')
            : (isEnglish
                ? 'Column code must start with a letter and use only A-Z, 0-9, _ (max 20)'
                : 'รหัสคอลัมน์ต้องขึ้นต้นด้วยตัวอักษร และใช้ได้เฉพาะ A-Z, 0-9, _ (ไม่เกิน 20 ตัว)');
      case 'INVALID_SEQ':
        return isEnglish ? 'Sequence is required' : 'กรุณาระบุลำดับ';
      case 'DUPLICATE_CODE':
        return forRow
            ? (isEnglish ? 'This row code already exists in the report' : 'รหัสบรรทัดนี้มีอยู่แล้วในรายงาน')
            : (isEnglish ? 'This column code already exists in the report' : 'รหัสคอลัมน์นี้มีอยู่แล้วในรายงาน');
      case 'DUPLICATE_SEQ':
        return isEnglish ? 'This sequence already exists in the report' : 'ลำดับนี้มีอยู่แล้วในรายงาน';
      case 'DUPLICATE_LABEL':
        return isEnglish ? 'This report already has a LABEL column' : 'รายงานนี้มีคอลัมน์ชื่อบรรทัด (LABEL) แล้ว';
      case 'CODE_REQUIRED':
        return isEnglish
            ? 'A TOTAL row needs a row code so other rows can be added into it'
            : 'บรรทัดยอดรวม (TOTAL) ต้องมีรหัสบรรทัด เพื่อให้บรรทัดอื่นเลือกรวมเข้ามาได้';
      case 'UNKNOWN_ACCOUNT':
        return isEnglish
            ? 'Account condition ${_line()}: account ${detail['account_code']} not found'
            : 'เงื่อนไขบัญชี${_line()}: ไม่พบบัญชี ${detail['account_code']}';
      case 'INVALID_RANGE':
        return isEnglish
            ? 'Account condition ${_line()}: select both From and To, with From not after To'
            : 'เงื่อนไขบัญชี${_line()}: ต้องเลือกทั้ง "ตั้งแต่" และ "ถึง" และ "ตั้งแต่" ต้องไม่มากกว่า "ถึง"';
      case 'REF_IN_USE':
        return isEnglish ? '$ref is used by $usages' : '$ref ถูกใช้อยู่ใน $usages';
      default:
        return isEnglish ? 'Invalid formula: $message' : 'สูตรคำนวณไม่ถูกต้อง: $message';
    }
  }

  /// ลำดับเงื่อนไขบัญชีที่ผิด (detail.index เริ่ม 0) แสดงเป็น " #1"
  String _line() => detail['index'] is int ? ' #${(detail['index'] as int) + 1}' : '';

  @override
  String toString() => message;
}
