// lib/im/services/im_transaction_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/im_transaction.dart';
import '../models/im_gl_account_setup.dart';
import '../models/im_gr_billing_report.dart';
import '../models/im_dln_billing_report.dart';

class ImTransactionService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/module_user/IM/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List jsonList = json.decode(response.body);
      return jsonList.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      return [];
    }
  }

  Future<List<ImTransactionHeader>> fetchRows({
    String? docCode,
    String? status,
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{};
    if (docCode != null && docCode.isNotEmpty) queryParams['doc_code'] = docCode;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (warehouseId != null) queryParams['warehouse_id'] = warehouseId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/im_transaction').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ImTransactionHeader.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลธุรกรรมสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImTransaction> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/im_transaction/$id'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลธุรกรรมสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  // ยอดคงเหลือปัจจุบันตาม item/warehouse/location/lot หรือ serial — ใช้ prefill "ยอดระบบ" ตอนเพิ่มบรรทัดนับสต็อก
  Future<double> fetchSystemQty({
    required int itemId,
    required int warehouseId,
    int? locationId,
    String? lotNo,
    String? serialNo,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{
      'item_id': itemId.toString(),
      'warehouse_id': warehouseId.toString(),
      if (locationId != null) 'location_id': locationId.toString(),
      if (lotNo != null && lotNo.isNotEmpty) 'lot_no': lotNo,
      if (serialNo != null && serialNo.isNotEmpty) 'serial_no': serialNo,
    };
    final uri = Uri.parse('$baseUrl/im_transaction/system_qty').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return double.tryParse(body['system_qty']?.toString() ?? '0') ?? 0;
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดยอดคงเหลือระบบล้มเหลว: ${response.statusCode}');
    }
  }

  // เอกสาร GRN/DLN ที่ Post แล้ว ให้เลือกเป็นต้นฉบับสำหรับ '15' (คืนสินค้าผู้ขาย) / '35' (รับคืนจากลูกค้า)
  Future<List<ImReturnableDoc>> fetchReturnableDocs({
    required String family, // 'GRN' | 'DLN'
    int? vendorId,
    int? customerId,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{
      'family': family,
      if (vendorId != null) 'vendor_id': vendorId.toString(),
      if (customerId != null) 'customer_id': customerId.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('$baseUrl/im_transaction/returnable_docs').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ImReturnableDoc.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดรายการเอกสารต้นฉบับล้มเหลว: ${response.statusCode}');
    }
  }

  // บรรทัดของเอกสารต้นฉบับที่เลือก พร้อมจำนวนคงเหลือที่คืนได้ต่อบรรทัด
  Future<List<ImReturnableLine>> fetchReturnableLines(int refImTransactionId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/im_transaction/$refImTransactionId/returnable_lines'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ImReturnableLine.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดบรรทัดเอกสารต้นฉบับล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImTransaction> createTransaction({
    required ImTransactionHeader header,
    required List<ImTransactionDetail> details,
    required String action,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => e.toJson()).toList(),
      'action': action,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/im_transaction'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 201) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<ImTransaction> updateTransaction({
    required int id,
    required ImTransactionHeader header,
    required List<ImTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => e.toJson()).toList(),
    });
    final response = await http.put(
      Uri.parse('$baseUrl/im_transaction/$id'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<ImTransaction> postTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_transaction/$id/post'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Post ล้มเหลว');
    }
  }

  // Post AP/GL สำหรับ '12' (รับสินค้า รอตั้งหนี้) — ครั้งที่สองเมื่อได้ใบกำกับผู้ขายแล้ว บันทึกเลขที่ใบกำกับ +
  // billed cost รายบรรทัดในคำขอเดียวกันได้เลย ไม่บังคับต้อง Save แยกก่อน
  Future<ImTransaction> postBilling({
    required int id,
    required String refNo,
    required List<ImTransactionDetail> details,
  }) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_transaction/$id/post_billing'),
      headers: headers,
      body: jsonEncode({
        'ref_no': refNo,
        'lines': details.map((d) => {'id': d.id, 'billed_unit_cost': d.billedUnitCost, 'vat_type': d.vatType, 'vat_rate': d.vatRate}).toList(),
      }),
    );
    if (response.statusCode == 200) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Post AP/GL ล้มเหลว');
    }
  }

  // Post AR/GL สำหรับ '32' (ส่งสินค้า รอตั้งหนี้) — ครั้งที่สองเมื่อจะออกใบแจ้งหนี้จริงให้ลูกค้า บันทึกเลขที่อ้างอิง +
  // ราคาขายรายบรรทัดในคำขอเดียวกันได้เลย ไม่บังคับต้อง Save แยกก่อน (ต้นทุนขายถูก Post ไปแล้วตอน Post IM)
  Future<ImTransaction> postBillingDln({
    required int id,
    required String refNo,
    required List<ImTransactionDetail> details,
  }) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_transaction/$id/post_billing_ar'),
      headers: headers,
      body: jsonEncode({
        'ref_no': refNo,
        'lines': details.map((d) => {'id': d.id, 'unit_price': d.unitPrice, 'vat_type': d.vatType, 'vat_rate': d.vatRate}).toList(),
      }),
    );
    if (response.statusCode == 200) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Post AR/GL ล้มเหลว');
    }
  }

  Future<ImTransaction> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_transaction/$id/void'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ImTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Void ล้มเหลว');
    }
  }

  Future<void> deleteTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/im_transaction/$id'),
      headers: headers,
    );
    if (response.statusCode == 204) return;
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }

  Future<ImGlAccountSetup?> fetchSetupByDocCode(String docCode) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/im_gl_account_setup/$docCode'),
      headers: headers,
    );
    if (res.statusCode == 200) return ImGlAccountSetup.fromJson(json.decode(res.body));
    return null;
  }

  // Review report for sys_doc_type='12' (GR รอตั้งหนี้) — Received docs with no GL backing yet
  // (accrual gap) and Posted docs whose billed cost differs from the cost that valued the stock
  // (price variance). See imGrBillingReportController.js.
  Future<List<ImGrBillingReportVendor>> fetchGrBillingReport({
    String? asOfDate,
    int? warehouseId,
    int? vendorId,
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{
      if (asOfDate != null && asOfDate.isNotEmpty) 'as_of_date': asOfDate,
      if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
      if (vendorId != null) 'vendor_id': vendorId.toString(),
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final uri = Uri.parse('$baseUrl/im_transaction/gr_billing_report').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ImGrBillingReportVendor.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดรายงาน GR รอตั้งหนี้ล้มเหลว: ${response.statusCode}');
    }
  }

  // Review report for sys_doc_type='32' (DLN รอตั้งหนี้) — Delivered docs (COGS posted, revenue not yet) and Posted
  // docs (revenue booked). See imDlnBillingReportController.js.
  Future<List<ImDlnBillingReportCustomer>> fetchDlnBillingReport({
    String? asOfDate,
    int? warehouseId,
    int? customerId,
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{
      if (asOfDate != null && asOfDate.isNotEmpty) 'as_of_date': asOfDate,
      if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
      if (customerId != null) 'customer_id': customerId.toString(),
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final uri = Uri.parse('$baseUrl/im_transaction/dln_billing_report').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ImDlnBillingReportCustomer.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดรายงาน DLN รอตั้งหนี้ล้มเหลว: ${response.statusCode}');
    }
  }
}
