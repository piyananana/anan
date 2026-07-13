import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../models/sa_module_document.dart';
import 'sa_auth_service.dart';
import '../models/sa_doc_number_branch.dart';

class DocNumberBranchService {
  final String _baseUrl = AppConfig.apiSa;
  final AuthService _auth = AuthService();

  DocNumberBranchService._internal();
  static final DocNumberBranchService _instance = DocNumberBranchService._internal();
  factory DocNumberBranchService() => _instance;

  /// Fetch all auto-numbering doc types with branch config overlay
  Future<List<DocNumberBranchConfig>> fetchByBranch(int branchId) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/sa_doc_number_branch?branch_id=$branchId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => DocNumberBranchConfig.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load configs: ${response.statusCode}');
  }

  /// Fetch ALL module_document items (for tree building — includes parent nodes)
  Future<List<ModuleDocument>> fetchAllDocTypes() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/sa_module_document'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load doc types: ${response.statusCode}');
  }

  /// Upsert single branch config for one doc type
  Future<void> upsertSingle({
    required int branchId,
    required int docId,
    String? formatPrefix,
    String? formatSeparator,
    String? formatSuffixDate,
    int? runningLength,
    required int nextRunningNumber,
  }) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(
      Uri.parse('$_baseUrl/sa_doc_number_branch/$branchId/$docId'),
      headers: headers,
      body: json.encode({
        'format_prefix':      formatPrefix?.isEmpty == true ? null : formatPrefix,
        'format_separator':   formatSeparator?.isEmpty == true ? null : formatSeparator,
        'format_suffix_date': formatSuffixDate?.isEmpty == true ? null : formatSuffixDate,
        'running_length':     runningLength,
        'next_running_number': nextRunningNumber,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save config: ${response.statusCode}');
    }
  }

  /// Delete branch config for one doc type (falls back to global counter)
  Future<void> deleteSingle({required int branchId, required int docId}) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$_baseUrl/sa_doc_number_branch/$branchId/$docId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete config: ${response.statusCode}');
    }
  }

  Future<void> upsertByBranch(int branchId, List<DocNumberBranchConfig> configs) async {
    final headers = await _auth.getAuthHeader();
    final enabled = configs.where((c) => c.hasConfig).toList();
    final response = await http.put(
      Uri.parse('$_baseUrl/sa_doc_number_branch/$branchId'),
      headers: headers,
      body: json.encode({
        'configs': enabled.map((c) => c.toSaveJson()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save configs: ${response.statusCode}');
    }
  }

  Future<void> resetCounter({int? branchId, required int docId, required int newValue}) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_baseUrl/sa_doc_number_branch/reset'),
      headers: headers,
      body: json.encode({
        'branch_id': branchId,
        'doc_id': docId,
        'new_value': newValue,
      }),
    );
    if (response.statusCode != 200) {
      final body = json.decode(response.body);
      throw Exception(body['error'] ?? 'Failed to reset counter');
    }
  }
}
