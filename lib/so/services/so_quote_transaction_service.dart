// lib/so/services/so_quote_transaction_service.dart — มิเรอร์ po_pr_transaction_service.dart ทุกประการ (sys_module='41')
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/so_quote_transaction.dart';

class QuoteTransactionService {
  final String baseUrl = AppConfig.apiSo;
  final AuthService authService = AuthService();

  // sys_module='41' (สั่งขาย - Sale Order/Quote, ดู sysModules ใน sa_anan_module.dart)
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

  Future<List<QuoteTransactionHeader>> fetchRows({
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
    final uri = Uri.parse('$baseUrl/quote_transaction').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => QuoteTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load Quote list: ${response.body}');
  }

  Future<QuoteTransactionHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/quote_transaction/$id'), headers: headers);
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load Quote: ${response.body}');
  }

  Future<QuoteTransactionHeader> createTransaction({
    required QuoteTransactionHeader header,
    required List<QuoteTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.post(Uri.parse('$baseUrl/quote_transaction'), headers: authHeaders, body: body);
    if (response.statusCode == 201) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'บันทึกใบเสนอราคาล้มเหลว');
  }

  Future<QuoteTransactionHeader> updateTransaction({
    required int id,
    required QuoteTransactionHeader header,
    required List<QuoteTransactionDetail> details,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({'header': header.toJson(), 'details': details.map((e) => e.toJson()).toList()});
    final response = await http.put(Uri.parse('$baseUrl/quote_transaction/$id'), headers: authHeaders, body: body);
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'แก้ไขใบเสนอราคาล้มเหลว');
  }

  Future<QuoteTransactionHeader> submitTransaction(int id, {required int menuId}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/quote_transaction/$id/submit'),
      headers: headers,
      body: jsonEncode({'menu_id': menuId}),
    );
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ส่งอนุมัติล้มเหลว');
  }

  Future<QuoteTransactionHeader> approveTransaction(int id, {String? remarks}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/quote_transaction/$id/approve'),
      headers: headers,
      body: jsonEncode({'remarks': remarks}),
    );
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'อนุมัติล้มเหลว');
  }

  Future<QuoteTransactionHeader> rejectTransaction(int id, {String? remarks}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/quote_transaction/$id/reject'),
      headers: headers,
      body: jsonEncode({'remarks': remarks}),
    );
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปฏิเสธล้มเหลว');
  }

  Future<QuoteTransactionHeader> closeTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/quote_transaction/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปิดใบเสนอราคาล้มเหลว');
  }

  Future<QuoteTransactionHeader> voidTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/quote_transaction/$id/void'), headers: headers);
    if (response.statusCode == 200) {
      return QuoteTransactionHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ยกเลิกใบเสนอราคาล้มเหลว');
  }

  Future<void> deleteTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/quote_transaction/$id'), headers: headers);
    if (response.statusCode != 204) {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบใบเสนอราคาล้มเหลว');
    }
  }

  // สำหรับ document picker ในหน้าจอ SO (อ้างอิง Quote)
  Future<List<Map<String, dynamic>>> fetchConvertibleLines({String? search}) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/quote_transaction/convertible_lines').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
    }
    throw Exception('Failed to load Quote convertible lines: ${response.body}');
  }
}
