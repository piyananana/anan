// lib/ap/services/ap_payment_run_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/ap_payment_run.dart';

class ApPaymentRunService {
  final String _base = AppConfig.apiAp;
  final AuthService _auth = AuthService();

  Future<List<ApPaymentRun>> fetchRows({String? status, String? dateFrom, String? dateTo}) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status != 'All') params['status'] = status;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final uri = Uri.parse('$_base/ap_payment_run').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List)
          .map((e) => ApPaymentRun.fromJson(e))
          .toList();
    }
    throw Exception('โหลดรายการ Payment Run ล้มเหลว: ${resp.statusCode}');
  }

  Future<ApPaymentRun> fetchRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(Uri.parse('$_base/ap_payment_run/$id'), headers: headers);
    if (resp.statusCode == 200) return ApPaymentRun.fromJson(jsonDecode(resp.body));
    throw Exception('โหลด Payment Run ล้มเหลว: ${resp.statusCode}');
  }

  Future<ApPaymentRun> createRun(ApPaymentRun run) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/ap_payment_run'),
      headers: headers,
      body: jsonEncode(run.toJson()),
    );
    if (resp.statusCode == 201) return ApPaymentRun.fromJson(jsonDecode(resp.body));
    throw Exception(_msg(resp.body));
  }

  Future<ApPaymentRun> updateRun(ApPaymentRun run) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/ap_payment_run/${run.id}'),
      headers: headers,
      body: jsonEncode(run.toJson()),
    );
    if (resp.statusCode == 200) return ApPaymentRun.fromJson(jsonDecode(resp.body));
    throw Exception(_msg(resp.body));
  }

  // ถ้าเมนูนี้ไม่มีผู้มีสิทธิ์อนุมัติเลย หรือถูกงดอนุมัติหมดทุกคน backend จะข้ามขั้นตอนอนุมัติให้อัตโนมัติ
  // (ผ่านตรงไป Approved) โดยไม่ต้องแจ้งเตือนใดๆ เพราะถือว่า admin ไม่ต้องการอนุมัติสำหรับเมนูนี้
  Future<void> submitRun(int id, {required int menuId}) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/ap_payment_run/$id/submit'),
      headers: headers,
      body: jsonEncode({'menu_id': menuId}),
    );
    if (resp.statusCode != 200) throw Exception(_msg(resp.body));
  }

  Future<void> voidRun(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(Uri.parse('$_base/ap_payment_run/$id/void'), headers: headers);
    if (resp.statusCode != 200) throw Exception(_msg(resp.body));
  }

  // ส่งชำระ — สร้างธุรกรรมจ่ายชำระ (ap_transaction) จริง 1 ใบต่อ 1 เจ้าหนี้ที่มีอยู่ในใบอนุมัติจ่าย
  // docId = ประเภทเอกสารที่เลือกจาก dialog ค้นหา (sa_module_document, sys_module=21, sys_doc_type=80)
  // post = true บันทึกและ Post GL ทันที, false บันทึกเป็น Draft
  Future<Map<String, dynamic>> finalizeRun(int id, {required int docId, required bool post}) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/ap_payment_run/$id/finalize'),
      headers: headers,
      body: jsonEncode({'doc_id': docId, 'post': post}),
    );
    if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    throw Exception(_msg(resp.body));
  }

  Future<void> approveRun(int id, {String? remarks}) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/ap_payment_run/$id/approve'),
      headers: headers,
      body: jsonEncode({'remarks': remarks}),
    );
    if (resp.statusCode != 200) throw Exception(_msg(resp.body));
  }

  Future<void> rejectRun(int id, {String? remarks}) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/ap_payment_run/$id/reject'),
      headers: headers,
      body: jsonEncode({'remarks': remarks}),
    );
    if (resp.statusCode != 200) throw Exception(_msg(resp.body));
  }

  Future<List<ApPaymentRun>> fetchMyPending() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
        Uri.parse('$_base/ap_payment_run/my_pending'), headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List)
          .map((e) => ApPaymentRun.fromJson(e))
          .toList();
    }
    throw Exception('โหลด pending approvals ล้มเหลว: ${resp.statusCode}');
  }

  Future<List<ApOpenInvoice>> fetchOpenInvoices({
    String? vendorCode,
    String? dateFrom,
    String? dateTo,
    int? paymentMethodId,
    String? dueDateMax,
    String? refNo,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (vendorCode != null && vendorCode.isNotEmpty) params['vendor_code'] = vendorCode;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (paymentMethodId != null) params['payment_method_id'] = paymentMethodId.toString();
    if (dueDateMax != null) params['due_date_max'] = dueDateMax;
    if (refNo != null && refNo.isNotEmpty) params['ref_no'] = refNo;
    final uri = Uri.parse('$_base/ap_payment_run/open_invoices').replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List)
          .map((e) => ApOpenInvoice.fromJson(e))
          .toList();
    }
    throw Exception('โหลดใบแจ้งหนี้ล้มเหลว: ${resp.statusCode}');
  }

  String _msg(String body) {
    try { return jsonDecode(body)['message'] ?? body; } catch (_) { return body; }
  }
}
