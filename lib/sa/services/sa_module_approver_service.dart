// lib/sa/services/sa_module_approver_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../models/sa_module_approver.dart';
import 'sa_auth_service.dart';

class SaModuleApproverService {
  final String _base = AppConfig.apiSa;
  final AuthService _auth = AuthService();

  Future<List<SaModuleApprover>> fetchRows({String? moduleCode, String? docCategory}) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{};
    if (moduleCode != null)   params['module_code']   = moduleCode;
    if (docCategory != null)  params['doc_category']  = docCategory;
    final uri = Uri.parse('$_base/sa_module_approver').replace(queryParameters: params.isEmpty ? null : params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List).map((e) => SaModuleApprover.fromJson(e)).toList();
    }
    throw Exception('โหลดข้อมูลผู้อนุมัติล้มเหลว: ${resp.statusCode}');
  }

  Future<List<SaModuleApprover>> fetchByModuleCategory(String moduleCode, String docCategory) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/sa_module_approver/by_module/$moduleCode/$docCategory');
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List).map((e) => SaModuleApprover.fromJson(e)).toList();
    }
    throw Exception('โหลดข้อมูลผู้อนุมัติล้มเหลว: ${resp.statusCode}');
  }

  Future<SaModuleApprover> addRow(SaModuleApprover row) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.post(
      Uri.parse('$_base/sa_module_approver'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (resp.statusCode == 201) return SaModuleApprover.fromJson(jsonDecode(resp.body));
    final msg = _extractMessage(resp.body);
    throw Exception(msg);
  }

  Future<SaModuleApprover> updateRow(SaModuleApprover row) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/sa_module_approver/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (resp.statusCode == 200) return SaModuleApprover.fromJson(jsonDecode(resp.body));
    final msg = _extractMessage(resp.body);
    throw Exception(msg);
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.delete(Uri.parse('$_base/sa_module_approver/$id'), headers: headers);
    if (resp.statusCode != 204) {
      final msg = _extractMessage(resp.body);
      throw Exception(msg);
    }
  }

  String _extractMessage(String body) {
    try { return jsonDecode(body)['message'] ?? body; } catch (_) { return body; }
  }
}
