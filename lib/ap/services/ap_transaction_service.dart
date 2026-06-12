import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/models/module_document.dart';
import '../models/ap_transaction.dart';
import '../models/ap_gl_account_setup.dart';

class ApTransactionService {
  final String baseUrl = AppConfig.apiAp;
  final AuthService authService = AuthService();

  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/module_user/AP/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List jsonList = json.decode(response.body);
      return jsonList.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      return [];
    }
  }

  Future<List<ApTransactionHeader>> fetchRows({
    int? vendorId,
    String? docType,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? search,
    int? branchId,
    int? dim1Id,
    int? dim2Id,
    int? dim3Id,
    int? dim4Id,
    int? dim5Id,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{};
    if (vendorId != null) queryParams['vendor_id'] = vendorId.toString();
    if (docType != null && docType.isNotEmpty) queryParams['doc_type'] = docType;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (branchId != null) queryParams['branch_id'] = branchId.toString();
    if (dim1Id != null) queryParams['dim1_id'] = dim1Id.toString();
    if (dim2Id != null) queryParams['dim2_id'] = dim2Id.toString();
    if (dim3Id != null) queryParams['dim3_id'] = dim3Id.toString();
    if (dim4Id != null) queryParams['dim4_id'] = dim4Id.toString();
    if (dim5Id != null) queryParams['dim5_id'] = dim5Id.toString();

    final uri = Uri.parse('$baseUrl/ap_transaction').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApTransactionHeader.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูล AP transaction ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ApTransaction> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ap_transaction/$id'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ApTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูล AP transaction ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ApOpenInvoice>> fetchOpenInvoices(int vendorId) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ap_transaction/open_invoices')
        .replace(queryParameters: {'vendor_id': vendorId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApOpenInvoice.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลด open invoices ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ApOpenInvoice>> fetchOpenAdvances(int vendorId) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ap_transaction/open_advances')
        .replace(queryParameters: {'vendor_id': vendorId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApOpenInvoice.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลด open advances ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ApOpenInvoice>> fetchOpenRemittanceAdvices(int vendorId) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ap_transaction/open_remittance_advices')
        .replace(queryParameters: {'vendor_id': vendorId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApOpenInvoice.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลด open RA ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ApOpenInvoice>> fetchRaInvoices(int raId) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ap_transaction/ra_invoices')
        .replace(queryParameters: {'ra_id': raId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ApOpenInvoice.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลด RA invoices ล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ApTransaction> createTransaction({
    required ApTransactionHeader header,
    required List<ApTransactionDetail> details,
    required List<ApTransactionApply> applies,
    required List<ApTransactionPayment> payments,
    required List<ApTransactionWht> whts,
    required String action,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => e.toJson()).toList(),
      'applies': applies.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
      'whts': whts.map((e) => e.toJson()).toList(),
      'action': action,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/ap_transaction'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 201) {
      return ApTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<ApTransaction> updateTransaction({
    required int id,
    required ApTransactionHeader header,
    required List<ApTransactionDetail> details,
    required List<ApTransactionApply> applies,
    required List<ApTransactionPayment> payments,
    required List<ApTransactionWht> whts,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((e) => e.toJson()).toList(),
      'applies': applies.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
      'whts': whts.map((e) => e.toJson()).toList(),
    });
    final response = await http.put(
      Uri.parse('$baseUrl/ap_transaction/$id'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) {
      return ApTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<ApTransaction> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/ap_transaction/$id/void'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ApTransaction.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Void ล้มเหลว');
    }
  }

  Future<ApGlAccountSetup?> fetchSetupByDocCode(String docCode) async {
    final headers = await authService.getAuthHeader();
    final res = await http.get(
      Uri.parse('$baseUrl/ap_gl_account_setup/$docCode'),
      headers: headers,
    );
    if (res.statusCode == 200) return ApGlAccountSetup.fromJson(json.decode(res.body));
    return null;
  }

  Future<void> deleteTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/ap_transaction/$id'),
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
}
