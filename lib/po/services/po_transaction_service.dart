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

  // คิวผู้อนุมัติ: ส่งอนุมัติ (menu_id = เมนูนี้) / อนุมัติ / ปฏิเสธ
  Future<PoTransactionHeader> _approvalPut(int id, String action, Map<String, dynamic> body, String failMsg) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/$action'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: json.encode(body));
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? failMsg);
  }

  Future<PoTransactionHeader> submitTransaction(int id, {required int menuId}) =>
      _approvalPut(id, 'submit', {'menu_id': menuId}, 'ส่งอนุมัติล้มเหลว');

  Future<PoTransactionHeader> approveTransaction(int id, {String? remarks}) =>
      _approvalPut(id, 'approve', {'remarks': remarks}, 'อนุมัติล้มเหลว');

  Future<PoTransactionHeader> rejectTransaction(int id, {String? remarks}) =>
      _approvalPut(id, 'reject', {'remarks': remarks}, 'ปฏิเสธล้มเหลว');

  Future<PoTransactionHeader> closeTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปิดใบสั่งซื้อล้มเหลว');
  }

  Future<PoTransactionHeader> voidTransaction(int id, String reason) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/void'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'reason': reason}));
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ยกเลิกใบสั่งซื้อล้มเหลว');
  }

  // ถอย: อนุมัติแล้ว → ร่าง หรือ ปิดแล้ว → เปิดใหม่
  Future<PoTransactionHeader> reverseTransaction(int id, String reason) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/po_transaction/$id/reverse'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'reason': reason}));
    if (response.statusCode == 200) {
      return PoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ถอยใบสั่งซื้อล้มเหลว');
  }

  // ลบร่าง (เก็บไว้ด้วยสถานะ Deleted)
  Future<void> deleteTransaction(int id, String reason) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/po_transaction/$id'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'reason': reason}));
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ลบใบสั่งซื้อล้มเหลว');
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

  // ราคาแนะนำจาก im_price_list — ลำดับความเจาะจง 2 ชั้น (PURCHASE): ตารางราคาที่ผู้ขายรายนี้ผูกตรง
  // (ap_vendor.price_list_id) > ลิสต์กลาง (is_default=true) — im_price_group เป็นแค่ป้ายกำกับ/หมวดหมู่ของตาราง
  // ราคา ไม่มีผลต่อการเลือกลิสต์เลย ภายในลิสต์ที่เลือกได้ยังกรองด้วย uomId (ถ้าระบุ) และ min_qty tier ตาม qty ด้วย
  // คืน map ว่างถ้าไม่พบ (ผู้เรียกต้องรองรับการกรอกราคาเองได้เสมอ ไม่ใช่ error)
  Future<Map<String, dynamic>> resolvePrice({
    required int itemId,
    required int vendorId,
    required double qty,
    required String docDate,
    int? uomId,
  }) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('${AppConfig.apiIm}/im_price_list/resolve_price').replace(queryParameters: {
      'item_id': itemId.toString(),
      'list_type': 'PURCHASE',
      'vendor_id': vendorId.toString(),
      'qty': qty.toString(),
      'doc_date': docDate,
      if (uomId != null) 'uom_id': uomId.toString(),
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    return {};
  }
}
