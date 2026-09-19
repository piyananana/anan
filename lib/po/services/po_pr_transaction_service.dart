// lib/po/services/po_pr_transaction_service.dart — ย้ายมารวมกับโฟลเดอร์ po (เดิมอยู่ lib/pr/) เพราะ PR เป็นส่วน
// หนึ่งของ workflow จัดซื้อเดียวกับ PO — endpoint ย้ายไปอยู่ใต้ /api/po ด้วย (ดู routes/po.js) จึงใช้ AppConfig.apiPo
// แทน AppConfig.apiPr เดิม (ลบทิ้งแล้ว) — ชื่อ class/method ทั้งหมดยังคงเดิมทุกประการ
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/po_pr_transaction.dart';

class PrTransactionService {
  final String baseUrl = AppConfig.apiPo;
  final AuthService authService = AuthService();

  // sys_module='51' (สั่งซื้อ - Purchase Order/Requisition, ดู sysModules ใน sa_anan_module.dart) — ใช้ sys_module
  // แทนการผูกกับ doc_code ของโหนดแม่ตัวใดตัวหนึ่งตายตัว เพื่อให้ผู้ใช้สร้างโหนดแม่/ประเภทเอกสารได้หลายชุด (มิเรอร์
  // การแก้ไขเดียวกันที่ทำใน PoTransactionService)
  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/sys_module_user/51/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List jsonList = json.decode(response.body);
      return jsonList.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<PrTransactionHeader>> fetchRows({
    String? status,
    int? vendorId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (vendorId != null) params['vendor_id'] = vendorId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/pr_transaction').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => PrTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load PR list: ${response.body}');
  }

  Future<PrTransactionHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/pr_transaction/$id'), headers: headers);
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load PR: ${response.body}');
  }

  Future<PrTransactionHeader> createTransaction({
    required PrTransactionHeader header,
    required List<PrTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.post(Uri.parse('$baseUrl/pr_transaction'), headers: authHeaders, body: body);
    if (response.statusCode == 201) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'บันทึกใบขอซื้อล้มเหลว');
  }

  Future<PrTransactionHeader> updateTransaction({
    required int id,
    required PrTransactionHeader header,
    required List<PrTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.put(Uri.parse('$baseUrl/pr_transaction/$id'), headers: authHeaders, body: body);
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'แก้ไขใบขอซื้อล้มเหลว');
  }

  Future<PrTransactionHeader> submitTransaction(int id, {required int menuId}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/pr_transaction/$id/submit'),
      headers: headers,
      body: jsonEncode({'menu_id': menuId}),
    );
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ส่งอนุมัติล้มเหลว');
  }

  Future<PrTransactionHeader> approveTransaction(int id, {String? remarks}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/pr_transaction/$id/approve'),
      headers: headers,
      body: jsonEncode({'remarks': remarks}),
    );
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'อนุมัติล้มเหลว');
  }

  Future<PrTransactionHeader> rejectTransaction(int id, {String? remarks}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/pr_transaction/$id/reject'),
      headers: headers,
      body: jsonEncode({'remarks': remarks}),
    );
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปฏิเสธล้มเหลว');
  }

  Future<PrTransactionHeader> closeTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/pr_transaction/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปิดใบขอซื้อล้มเหลว');
  }

  Future<PrTransactionHeader> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/pr_transaction/$id/void'), headers: headers);
    if (response.statusCode == 200) {
      return PrTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ยกเลิกใบขอซื้อล้มเหลว');
  }

  Future<void> deleteTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/pr_transaction/$id'), headers: headers);
    if (response.statusCode != 204) {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบใบขอซื้อล้มเหลว');
    }
  }

  // สำหรับ document picker ในหน้าจอ PO (อ้างอิง PR)
  Future<List<Map<String, dynamic>>> fetchConvertibleLines({String? search}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/pr_transaction/convertible_lines').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
    }
    throw Exception('Failed to load PR convertible lines: ${response.body}');
  }
}
