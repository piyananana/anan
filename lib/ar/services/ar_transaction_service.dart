import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/models/module_document.dart';
import '../models/ar_transaction.dart';

class BcAlreadyPaidException implements Exception {
  final String receiptDocNo;
  const BcAlreadyPaidException(this.receiptDocNo);
}

// แปลง error message แบบ multiline → single line
String _formatApiError(String rawBody) {
  try {
    final err = jsonDecode(rawBody) as Map<String, dynamic>;
    final raw = (err['error'] as String? ?? '').trim();
    if (raw.isEmpty) return rawBody;
    if (raw.contains('\n')) {
      final parts = raw.split('\n');
      final head = parts.first.replaceFirst(RegExp(r':$'), '').trim();
      final detail = parts.skip(1)
          .map((l) => l.replaceAll(': ต้องระบุ', ' ต้องระบุ').replaceAll(RegExp(r':$'), '').trim())
          .join(', ');
      return detail.isNotEmpty ? '$head: $detail' : head;
    }
    return raw;
  } catch (_) {
    return rawBody;
  }
}

class ArTransactionService {
  final String baseUrl = AppConfig.apiAr;
  final AuthService authService = AuthService();

  // Fetch allowed doc types for current user (sys_module=11 = AR)
  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/module_user/AR/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List json = jsonDecode(response.body);
      return json.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      return [];
    }
  }

  // Fetch list of transactions
  Future<List<ArTransactionHeader>> fetchRows({
    String? search,
    String? status,
    String? docType,
    int? customerId,
    String? dateFrom,
    String? dateTo,
    int? branchId,
    int? dim1Id,
    int? dim2Id,
    int? dim3Id,
    int? dim4Id,
    int? dim5Id,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (docType != null && docType.isNotEmpty) queryParams['doc_type'] = docType;
    if (customerId != null) queryParams['customer_id'] = customerId.toString();
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    if (branchId != null) queryParams['branch_id'] = branchId.toString();
    if (dim1Id != null) queryParams['dim1_id'] = dim1Id.toString();
    if (dim2Id != null) queryParams['dim2_id'] = dim2Id.toString();
    if (dim3Id != null) queryParams['dim3_id'] = dim3Id.toString();
    if (dim4Id != null) queryParams['dim4_id'] = dim4Id.toString();
    if (dim5Id != null) queryParams['dim5_id'] = dim5Id.toString();

    final uri = Uri.parse('$baseUrl/ar_transaction').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final List json = jsonDecode(response.body);
      return json.map((e) => ArTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load transactions: ${response.statusCode}');
    }
  }

  // Fetch single transaction (header + details + applies)
  Future<ArTransaction> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_transaction/$id'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return ArTransaction.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load transaction: ${response.statusCode}');
    }
  }

  // Create transaction
  Future<Map<String, dynamic>> createTransaction({
    required ArTransactionHeader header,
    required List<ArTransactionDetail> details,
    required List<ArTransactionApply> applies,
    required String action, // 'Draft' | 'Post'
    List<ArTransactionPayment> payments = const [],
  }) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((d) => d.toJson()).toList(),
      'applies': applies.map((a) => a.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'action': action,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/ar_transaction'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception(_formatApiError(response.body));
    }
  }

  // Update transaction (Draft only)
  Future<void> updateTransaction({
    required int id,
    required ArTransactionHeader header,
    required List<ArTransactionDetail> details,
    required List<ArTransactionApply> applies,
    required String action,
    List<ArTransactionPayment> payments = const [],
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'details': details.map((d) => d.toJson()).toList(),
      'applies': applies.map((a) => a.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'action': action,
    });
    final response = await http.put(
      Uri.parse('$baseUrl/ar_transaction/$id'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    }
    throw Exception(_formatApiError(response.body));
  }

  // Void transaction
  Future<void> voidTransaction(int id, {String? voidReason}) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'void_reason': voidReason ?? '',
      'updated_by': authHeaders['UserName'] ?? '',
    });
    final response = await http.put(
      Uri.parse('$baseUrl/ar_transaction/$id/void'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to void transaction');
  }

  // Delete draft
  Future<void> deleteTransaction(int id) async {
    final authHeaders = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/ar_transaction/$id'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to delete transaction');
  }

  // Fetch open advance receipts for a customer (for advance deduction in Receipt)
  Future<List<ArTransactionHeader>> fetchOpenAdvances(int customerId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_transaction/open_advances?customer_id=$customerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List json = jsonDecode(response.body);
      return json.map((e) => ArTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load open advances: ${response.statusCode}');
    }
  }

  // Fetch open credit notes for a customer (for CN deduction in Receipt)
  Future<List<ArTransactionHeader>> fetchOpenCreditNotes(int customerId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_transaction/open_credit_notes?customer_id=$customerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List json = jsonDecode(response.body);
      return json.map((e) => ArTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load open credit notes: ${response.statusCode}');
    }
  }

  // Fetch open advance receipts for refund (for RDP-65)
  Future<List<ArTransactionHeader>> fetchOpenAdvancesForRefund(int customerId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_transaction/open_advances_for_refund?customer_id=$customerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List json = jsonDecode(response.body);
      return json.map((e) => ArTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load open advances for refund: ${response.statusCode}');
    }
  }

  // ดึงข้อมูลวางบิลของแต่ละ invoice สำหรับลูกค้า (invoice_id → bc info)
  Future<Map<int, Map<String, dynamic>>> fetchInvoiceBillingSummary(int customerId) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/ar_transaction/invoice_billing_summary')
        .replace(queryParameters: {'customer_id': customerId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final List rows = jsonDecode(response.body);
      return {
        for (final r in rows)
          (r['invoice_id'] as num).toInt(): Map<String, dynamic>.from(r as Map)
      };
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load billing summary: ${response.statusCode}');
    }
  }

  // Fetch Bill Collection document by doc_no (for Receipt auto-fill)
  // throws BcAlreadyPaidException (409) ถ้า BC ถูกชำระแล้ว (เมื่อ viewOnly=false)
  // viewOnly=true: ข้ามการตรวจสอบสถานะชำระ ใช้สำหรับแสดงข้อมูลใน view mode
  Future<ArTransaction?> fetchBillCollectionByDocNo(String docNo, {bool viewOnly = false}) async {
    final headers = await authService.getAuthHeader();
    final params = {'doc_no': docNo, if (viewOnly) 'view': 'true'};
    final uri = Uri.parse('$baseUrl/ar_transaction/bill_collection_by_doc_no')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json == null) return null;
      return ArTransaction.fromJson(json as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      return null;
    } else if (response.statusCode == 409) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw BcAlreadyPaidException(body['receipt_doc_no'] as String? ?? '');
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to fetch bill collection: ${response.statusCode}');
    }
  }

  // Fetch open invoices for a customer (for Receipt application)
  Future<List<ArTransactionHeader>> fetchOpenInvoices(int customerId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/ar_transaction/open_invoices?customer_id=$customerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List json = jsonDecode(response.body);
      return json.map((e) => ArTransactionHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load open invoices: ${response.statusCode}');
    }
  }
}
