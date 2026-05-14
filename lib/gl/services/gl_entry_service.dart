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
    int? periodId,
    int? fiscalYearId,
    int? dim1Id,
    int? dim2Id,
    int? dim3Id,
    int? dim4Id,
    int? dim5Id,
  }) async {
    String query = '?';
    if (periodId != null) query += 'period_id=$periodId&';
    else if (fiscalYearId != null) query += 'fiscal_year_id=$fiscalYearId&';
    if (dim1Id != null) query += 'dim1_id=$dim1Id&';
    if (dim2Id != null) query += 'dim2_id=$dim2Id&';
    if (dim3Id != null) query += 'dim3_id=$dim3Id&';
    if (dim4Id != null) query += 'dim4_id=$dim4Id&';
    if (dim5Id != null) query += 'dim5_id=$dim5Id&';

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
        'dim1_id': e.dim1Id,
        'dim2_id': e.dim2Id,
        'dim3_id': e.dim3Id,
        'dim4_id': e.dim4Id,
        'dim5_id': e.dim5Id,
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
      String msg;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = (err['error'] as String? ?? '').trim();
        if (raw.contains('\n')) {
          // "Dimension ไม่ครบ:\nบรรทัดที่ 1: ต้องระบุ X\n..." → "Dimension ไม่ครบ: บรรทัดที่ 1 ต้องระบุ X, ..."
          final parts = raw.split('\n');
          final head = parts.first.replaceFirst(RegExp(r':$'), '').trim();
          final body = parts.skip(1)
              .map((l) => l.replaceAll(': ต้องระบุ', ' ต้องระบุ').replaceFirst(RegExp(r':$'), '').trim())
              .join(', ');
          msg = body.isNotEmpty ? '$head: $body' : head;
        } else {
          msg = raw.isNotEmpty ? raw : res.body;
        }
      } catch (_) {
        msg = res.body;
      }
      throw Exception(msg);
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