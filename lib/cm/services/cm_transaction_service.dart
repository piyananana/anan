import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/cm_transaction.dart';

class CmTransactionService {
  final String baseUrl = AppConfig.apiCm;
  final AuthService authService = AuthService();

  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/module_user/CM/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List jsonList = json.decode(response.body);
      return jsonList.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<CmTransactionHeader>> fetchRows({
    String? docType,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{};
    if (docType != null && docType.isNotEmpty) queryParams['doc_type'] = docType;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/cm_transaction').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => CmTransactionHeader.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลธุรกรรม CM ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<CmTransaction> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cm_transaction/$id'), headers: headers);
    if (response.statusCode == 200) {
      return CmTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลธุรกรรม CM ล้มเหลว: ${response.statusCode}');
    }
  }

  // ดึงข้อมูล read-only ของ cm_receipt (doc type 15 — รายรับจาก AR)
  Future<CmLegacyMirrorRow> fetchReceiptView(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cm_transaction/receipt_view/$id'), headers: headers);
    if (response.statusCode == 200) {
      return CmLegacyMirrorRow.fromJson(json.decode(response.body), isReceipt: true);
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดข้อมูลรายรับล้มเหลว: ${response.statusCode}');
    }
  }

  // ดึงข้อมูล read-only ของ cm_payment (doc type 25 — รายจ่ายจาก AP)
  Future<CmLegacyMirrorRow> fetchPaymentView(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/cm_transaction/payment_view/$id'), headers: headers);
    if (response.statusCode == 200) {
      return CmLegacyMirrorRow.fromJson(json.decode(response.body), isReceipt: false);
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดข้อมูลรายจ่ายล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<CmOpenVoucher>> fetchOpenVouchers({int? bankAccountId}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (bankAccountId != null) params['bank_account_id'] = bankAccountId.toString();
    final uri = Uri.parse('$baseUrl/cm_transaction/open_vouchers').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => CmOpenVoucher.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดใบเบิกเงินสดย่อยที่เปิดอยู่ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<CmTransaction> createTransaction({
    required CmTransactionHeader header,
    required List<CmTransactionDetail> details,
    required List<CmTransactionApply> applies,
    required List<CmTransactionPayment> payments,
    required String action,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => e.toJson()).toList(),
      'applies': applies.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
      'action': action,
    });
    final response = await http.post(Uri.parse('$baseUrl/cm_transaction'), headers: authHeaders, body: body);
    if (response.statusCode == 201) {
      return CmTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<CmTransaction> updateTransaction({
    required int id,
    required CmTransactionHeader header,
    required List<CmTransactionDetail> details,
    required List<CmTransactionApply> applies,
    required List<CmTransactionPayment> payments,
    required String action,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => e.toJson()).toList(),
      'applies': applies.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
      'action': action,
    });
    final response = await http.put(Uri.parse('$baseUrl/cm_transaction/$id'), headers: authHeaders, body: body);
    if (response.statusCode == 200) {
      return CmTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<CmTransaction> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/cm_transaction/$id/void'), headers: headers);
    if (response.statusCode == 200) {
      return CmTransaction.fromJson(json.decode(response.body));
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
    final response = await http.delete(Uri.parse('$baseUrl/cm_transaction/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }
}
