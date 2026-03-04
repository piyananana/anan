import '../../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/auth_service.dart';
import '../models/gl_entry.dart';
import '../../sa/models/module_document.dart'; // Import ModuleDocument model

class GlEntryService {
  // final String baseUrl = 'http://localhost:3000/api/gl'; // ปรับ IP
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  // ดึงรายการ (Search Tab)
  Future<List<GlEntryHeader>> fetchEntries({
    String? fiscalYear, 
    String? periodNo, 
    String? search
  }) async {
    String query = '?';
    if (fiscalYear != null) query += 'fiscal_year=$fiscalYear&';
    if (periodNo != null) query += 'period_number=$periodNo&';
    if (search != null && search.isNotEmpty) query += 'search=$search&';

    final headers = await authService.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/gl_entry$query'),
      headers: headers
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => GlEntryHeader.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load entries');
    }
  }

  // ดึงรายละเอียด (Detail Tab)
  Future<Map<String, dynamic>> fetchEntryDetail(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/gl_entry/$id'), 
      headers: headers
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final header = GlEntryHeader.fromJson(data['header']);
      final details = (data['details'] as List).map((e) => GlEntryDetail.fromJson(e)).toList();
      return {'header': header, 'details': details};
    } else {
      throw Exception('Failed to load entry detail');
    }
  }

  // บันทึก/Post
  Future<void> saveEntry(GlEntryHeader header, List<GlEntryDetail> details, String action) async {
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => {
        'account_id': e.accountId,
        'description': e.description,
        // 'debit': e.debit,
        // 'credit': e.credit,
        // ส่งทั้ง FC และ LC ไปให้ Backend บันทึก (คำนวณจาก Frontend ไปเลยเพื่อความชัวร์เรื่องการแสดงผล)
        'debit_fc': e.debitFc,
        'credit_fc': e.creditFc,
        'debit_lc': e.debitLc,
        'credit_lc': e.creditLc,
        'branch_id': e.branchId,
        'project_id': e.projectId,
        'business_unit_id': e.businessUnitId
      }).toList(),
      'action': action // 'Draft' or 'Post'
    });

    final url = header.id == 0 
        ? '$baseUrl/gl_entry' 
        : '$baseUrl/gl_entry/${header.id}';
    final method = header.id == 0 ? http.post : http.put;

    final headers = await authService.getAuthHeader();
    final res = await method(
      Uri.parse(url),
      headers: headers,
      body: body
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to save: ${res.body}');
    }
  }

  // ลบ (Soft Delete)
  Future<void> deleteEntry(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.delete(
      Uri.parse('$baseUrl/gl_entry/$id'),
      headers: headers
    );
    if (res.statusCode != 200) throw Exception('Failed to delete');
  }

  // Reverse
  Future<void> reverseEntry(int id) async {
    final headers = await authService.getAuthHeader();
    final res = await http.post(
      Uri.parse('$baseUrl/gl_entry/reverse/$id'),
      headers: headers
    );
    if (res.statusCode != 200) throw Exception('Failed to reverse');
  }

  // Master Data: Allowed Doc Types
  // Future<List<ModuleDocument>> fetchAllowedDocTypes(int userId) async {
  //   final headers = await authService.getAuthHeader();
  //   final res = await http.get(
  //     Uri.parse('$baseUrl/doctypes/allowed/$userId'),
  //     headers: headers
  //   );
  //   if (res.statusCode == 200) {
  //     final List data = jsonDecode(res.body);
  //     return data.map((e) => ModuleDocument.fromJson(e)).toList();
  //   } else {
  //     return [];
  //   }
  // }
  Future<List<ModuleDocument>> fetchRowsByModuleUserId() async {
    final String url = AppConfig.apiSa;
    final headers = await authService.getAuthHeader();
    const String module = 'GL';
    int userId = authService.currentUser?.id ?? 0;
    final res = await http.get(
      Uri.parse('$url/sa_module_document/module_user/$module/$userId'),
      headers: headers
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ModuleDocument.fromJson(e)).toList();
    } else {
      return [];
    }
  }

  Future<List<ModuleDocument>> fetchRows() async {
    final String url = AppConfig.apiSa;
    final headers = await authService.getAuthHeader();
    final res = await http.get(
      Uri.parse('$url/sa_module_document'),
      headers: headers
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ModuleDocument.fromJson(e)).toList();
    } else {
      return [];
    }
  }

}