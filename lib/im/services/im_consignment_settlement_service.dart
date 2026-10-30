import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ImConsignmentSettlementService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> fetchPending({int? vendorId}) async {
    final headers = await _authService.getAuthHeader();
    final params = <String, String>{};
    if (vendorId != null) params['vendor_id'] = '$vendorId';
    final uri = Uri.parse('$baseUrl/im_consignment_settlement/pending').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load pending consignment settlement rows: ${response.body}');
  }

  // ประเภทเอกสาร AP ตั้งหนี้ที่เปิดใช้งาน — ผู้ใช้เลือกทุกครั้งที่สร้างใบตั้งหนี้
  Future<List<Map<String, dynamic>>> fetchApDocTypes() async {
    final headers = await _authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_consignment_settlement/ap_doc_types'), headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load AP document types: ${response.body}');
  }

  Future<Map<String, dynamic>> postSettlement({
    required int vendorId,
    required int apDocId,
    required List<int> consumptionIds,
    String? refNo,
    String? docDate,
  }) async {
    final headers = await _authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_consignment_settlement');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'vendor_id': vendorId,
        'ap_doc_id': apDocId,
        'consumption_ids': consumptionIds,
        if (refNo != null && refNo.isNotEmpty) 'ref_no': refNo,
        if (docDate != null) 'doc_date': docDate,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Settlement failed');
  }

  Future<List<Map<String, dynamic>>> fetchSettled({required int vendorId}) async {
    final headers = await _authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_consignment_settlement').replace(queryParameters: {'vendor_id': '$vendorId'});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
    }
    throw Exception('Failed to load consignment settlement history: ${response.body}');
  }

  // ถอยเป็นร่าง / ยกเลิก / ลบ ต้องมีเหตุผล — คืนแถวใบตั้งหนี้ล่าสุด (พร้อม block และประวัติ)
  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic> body, String fallback) async {
    final headers = {...await _authService.getAuthHeader(), 'Content-Type': 'application/json'};
    final uri = Uri.parse('$baseUrl/im_consignment_settlement/$path');
    final response = method == 'DELETE'
        ? await http.delete(uri, headers: headers, body: jsonEncode(body))
        : await http.put(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 401) {
      _authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? fallback);
  }

  Future<Map<String, dynamic>> voidSettlement(int id, String reason) =>
      _send('PUT', '$id/void', {'reason': reason}, 'Void failed');

  Future<Map<String, dynamic>> reverseSettlement(int id, String reason) =>
      _send('PUT', '$id/reverse', {'reason': reason}, 'Reverse failed');

  // โพสต์ร่างใหม่ด้วยเลขที่เดิม (เปลี่ยนวันที่ / เลขที่อ้างอิงได้)
  Future<Map<String, dynamic>> repostSettlement(int id, {required String docDate, String? refNo}) =>
      _send('PUT', '$id/post', {'doc_date': docDate, 'ref_no': refNo}, 'Post failed');

  Future<Map<String, dynamic>> deleteSettlement(int id, String reason) =>
      _send('DELETE', '$id', {'reason': reason}, 'Delete failed');
}
