// lib/po/services/po_transaction_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/po_transaction.dart';

class PoTransactionService {
  final String baseUrl = AppConfig.apiPo;
  final AuthService authService = AuthService();

  // sys_module='51' (สั่งซื้อ - Purchase Order, ดู sysModules ใน sa_anan_module.dart) — ใช้ sys_module แทนการ
  // ผูกกับ doc_code ของโหนดแม่ตัวใดตัวหนึ่งตายตัว (ต่างจาก ImTransactionService ที่ hardcode 'IM') เพื่อให้ผู้ใช้
  // สร้างโหนดแม่/ประเภทเอกสารได้หลายชุดภายใต้โมดูลนี้ (เช่น แยกตามประเภทการบันทึกบัญชี) แล้วยังค้นพบได้ทั้งหมด
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

  Future<List<PoTransactionHeader>> fetchRows({
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
    final uri = Uri.parse('$baseUrl/po_transaction').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => PoTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load PO list: ${response.body}');
  }

  Future<PoTransactionHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/po_transaction/$id'), headers: headers);
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load PO: ${response.body}');
  }

  Future<PoTransactionHeader> createTransaction({
    required PoTransactionHeader header,
    required List<PoTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.post(Uri.parse('$baseUrl/po_transaction'), headers: authHeaders, body: body);
    if (response.statusCode == 201) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'บันทึกใบสั่งซื้อล้มเหลว');
  }

  Future<PoTransactionHeader> updateTransaction({
    required int id,
    required PoTransactionHeader header,
    required List<PoTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id'), headers: authHeaders, body: body);
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'แก้ไขใบสั่งซื้อล้มเหลว');
  }

  Future<PoTransactionHeader> approveTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/approve'), headers: headers);
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'อนุมัติล้มเหลว');
  }

  Future<PoTransactionHeader> closeTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปิดใบสั่งซื้อล้มเหลว');
  }

  Future<PoTransactionHeader> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/void'), headers: headers);
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ยกเลิกใบสั่งซื้อล้มเหลว');
  }

  Future<void> deleteTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/po_transaction/$id'), headers: headers);
    if (response.statusCode != 204) {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบใบสั่งซื้อล้มเหลว');
    }
  }

  // สำหรับ document picker ในหน้าจอ GRN (อ้างอิง PO)
  Future<List<Map<String, dynamic>>> fetchReceivableLines({int? vendorId, String? search}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (vendorId != null) params['vendor_id'] = vendorId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/po_transaction/receivable_lines').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
    }
    throw Exception('Failed to load PO receivable lines: ${response.body}');
  }

  // ราคาแนะนำจาก im_price_list (PURCHASE, ผูกผู้ขายเจาะจงก่อน fallback ราคากลาง) — คืน map ว่างถ้าไม่พบ
  Future<Map<String, dynamic>> resolvePrice({
    required int itemId,
    required int vendorId,
    required double qty,
    required String docDate,
  }) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('${AppConfig.apiIm}/im_price_list/resolve_price').replace(queryParameters: {
      'item_id': itemId.toString(),
      'list_type': 'PURCHASE',
      'vendor_id': vendorId.toString(),
      'qty': qty.toString(),
      'doc_date': docDate,
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    return {};
  }
}
