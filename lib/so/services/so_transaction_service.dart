// lib/so/services/so_transaction_service.dart — มิเรอร์ po_transaction_service.dart ทุกประการ (sys_module='41')
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/so_transaction.dart';

class SoTransactionService {
  final String baseUrl = AppConfig.apiSo;
  final AuthService authService = AuthService();

  // sys_module='41' (สั่งขาย - Sale Order, ดู sysModules ใน sa_anan_module.dart)
  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/sys_module_user/41/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List jsonList = json.decode(response.body);
      return jsonList.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<SoTransactionHeader>> fetchRows({
    String? status,
    int? customerId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (customerId != null) params['customer_id'] = customerId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/so_transaction').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => SoTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load SO list: ${response.body}');
  }

  Future<SoTransactionHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/so_transaction/$id'), headers: headers);
    if (response.statusCode == 200) {
      return SoTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load SO: ${response.body}');
  }

  Future<SoTransactionHeader> createTransaction({
    required SoTransactionHeader header,
    required List<SoTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.post(Uri.parse('$baseUrl/so_transaction'), headers: authHeaders, body: body);
    if (response.statusCode == 201) {
      return SoTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'บันทึกใบสั่งขายล้มเหลว');
  }

  Future<SoTransactionHeader> updateTransaction({
    required int id,
    required SoTransactionHeader header,
    required List<SoTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.put(Uri.parse('$baseUrl/so_transaction/$id'), headers: authHeaders, body: body);
    if (response.statusCode == 200) {
      return SoTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'แก้ไขใบสั่งขายล้มเหลว');
  }

  Future<SoTransactionHeader> approveTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/so_transaction/$id/approve'), headers: headers);
    if (response.statusCode == 200) {
      return SoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'อนุมัติล้มเหลว');
  }

  Future<SoTransactionHeader> closeTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/so_transaction/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return SoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปิดใบสั่งขายล้มเหลว');
  }

  Future<SoTransactionHeader> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/so_transaction/$id/void'), headers: headers);
    if (response.statusCode == 200) {
      return SoTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ยกเลิกใบสั่งขายล้มเหลว');
  }

  Future<void> deleteTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/so_transaction/$id'), headers: headers);
    if (response.statusCode != 204) {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบใบสั่งขายล้มเหลว');
    }
  }

  // สำหรับ document picker ในหน้าจอ DLN (อ้างอิง SO)
  Future<List<Map<String, dynamic>>> fetchDeliverableLines({int? customerId, String? search}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (customerId != null) params['customer_id'] = customerId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/so_transaction/deliverable_lines').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
    }
    throw Exception('Failed to load SO deliverable lines: ${response.body}');
  }

  // ราคาแนะนำจาก im_price_list — ลำดับความเจาะจง 3 ชั้น (SALES): ลูกค้ารายนี้โดยตรง > กลุ่มราคาที่ลูกค้าสังกัด
  // > ลิสต์กลาง — ภายในลิสต์ที่เลือกได้ยังกรองด้วย uomId (ถ้าระบุ) และ min_qty tier ตาม qty ด้วย คืน map ว่างถ้า
  // ไม่พบ (ผู้เรียกต้องรองรับการกรอกราคาเองได้เสมอ ไม่ใช่ error)
  Future<Map<String, dynamic>> resolvePrice({
    required int itemId,
    required int customerId,
    required double qty,
    required String docDate,
    int? uomId,
  }) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('${AppConfig.apiIm}/im_price_list/resolve_price').replace(queryParameters: {
      'item_id': itemId.toString(),
      'list_type': 'SALES',
      'customer_id': customerId.toString(),
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
