// lib/mo/services/mo_header_service.dart — มิเรอร์ po_transaction_service.dart ทุกประการ
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/mo_header.dart';

class MoHeaderService {
  final String baseUrl = AppConfig.apiMo;
  final AuthService authService = AuthService();

  // sys_module='61' (สั่งผลิต - Manufacturing Order, ดู sysModules ใน sa_anan_module.dart)
  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/sys_module_user/61/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List jsonList = json.decode(response.body);
      return jsonList.map((e) => ModuleDocument.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<MoHeader>> fetchRows({
    String? status,
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (warehouseId != null) params['warehouse_id'] = warehouseId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/mo_header').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoHeader.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load MO list: ${response.body}');
  }

  Future<MoHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_header/$id'), headers: headers);
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load MO: ${response.body}');
  }

  Future<MoHeader> createTransaction({
    required MoHeader header,
    required List<MoComponentDetail> components,
    required List<MoOutputDetail> outputs,
    required List<MoOperationDetail> operations,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'components': components.map((e) => e.toJson()).toList(),
      'outputs': outputs.map((e) => e.toJson()).toList(),
      'operations': operations.map((e) => e.toJson()).toList(),
    });
    final response = await http.post(Uri.parse('$baseUrl/mo_header'), headers: authHeaders, body: body);
    if (response.statusCode == 201) {
      return MoHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'บันทึกใบสั่งผลิตล้มเหลว');
  }

  Future<MoHeader> updateTransaction({
    required int id,
    required MoHeader header,
    required List<MoComponentDetail> components,
    required List<MoOutputDetail> outputs,
    required List<MoOperationDetail> operations,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final body = jsonEncode({
      'header': header.toJson(),
      'components': components.map((e) => e.toJson()).toList(),
      'outputs': outputs.map((e) => e.toJson()).toList(),
      'operations': operations.map((e) => e.toJson()).toList(),
    });
    final response = await http.put(Uri.parse('$baseUrl/mo_header/$id'), headers: authHeaders, body: body);
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'แก้ไขใบสั่งผลิตล้มเหลว');
  }

  Future<MoHeader> releaseTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/mo_header/$id/release'), headers: headers);
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปล่อยใบสั่งผลิตล้มเหลว');
  }

  Future<MoHeader> cancelTransaction(int id, String reason) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/mo_header/$id/cancel'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'reason': reason}));
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ยกเลิกใบสั่งผลิตล้มเหลว');
  }

  // ถอยสถานะ: ปล่อยแล้ว → ร่าง หรือ ปิดแล้ว → ผลิตครบแล้ว
  Future<MoHeader> reverseTransaction(int id, String reason) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/mo_header/$id/reverse'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'reason': reason}));
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ถอยใบสั่งผลิตล้มเหลว');
  }

  // ลบร่าง (เก็บไว้ด้วยสถานะ Deleted)
  Future<void> deleteTransaction(int id, String reason) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/mo_header/$id'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'reason': reason}));
    if (response.statusCode == 200 || response.statusCode == 204) return;
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ลบใบสั่งผลิตล้มเหลว');
  }

  Future<MoHeader> logOperationTime({
    required int moId,
    required int operationId,
    double laborHours = 0,
    double machineHours = 0,
    bool markDone = false,
  }) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode({
      'labor_hours': laborHours,
      'machine_hours': machineHours,
      'mark_done': markDone,
    });
    final response = await http.put(
      Uri.parse('$baseUrl/mo_header/$moId/operations/$operationId/log_time'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'บันทึกเวลาปฏิบัติงานล้มเหลว');
  }

  Future<MoHeader> closeTransaction(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/mo_header/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return MoHeader.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ปิดใบสั่งผลิตล้มเหลว');
  }

  Future<MoMaterialAvailability> checkMaterialAvailability(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_header/$id/availability'), headers: headers);
    if (response.statusCode == 200) {
      return MoMaterialAvailability.fromJson(json.decode(response.body));
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ตรวจสอบวัตถุดิบพร้อมผลิตล้มเหลว');
  }

  Future<List<MoStatusReportRow>> fetchStatusReport({
    String? status,
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (warehouseId != null) params['warehouse_id'] = warehouseId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/mo_header/report/status').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoStatusReportRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load MO status report: ${response.body}');
  }

  Future<List<MoCostVarianceReportRow>> fetchCostVarianceReport({
    String? status,
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (warehouseId != null) params['warehouse_id'] = warehouseId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/mo_header/report/cost_variance').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => MoCostVarianceReportRow.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load MO cost/variance report: ${response.body}');
  }

  Future<MoWipValuationReport> fetchWipValuationReport({
    int? warehouseId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final headers = await authService.getAuthHeader();
    final params = <String, String>{};
    if (warehouseId != null) params['warehouse_id'] = warehouseId.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/mo_header/report/wip_valuation').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return MoWipValuationReport.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    throw Exception('Failed to load MO WIP valuation report: ${response.body}');
  }

  Future<List<MoExplosionCandidate>> fetchExplosionCandidates(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/mo_header/$id/explosion_candidates'), headers: headers);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return (body['lines'] as List<dynamic>? ?? [])
          .map((e) => MoExplosionCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'ดึงรายการที่สร้างใบสั่งผลิตย่อยได้ล้มเหลว');
  }

  Future<MoHeader> explodeSubAssembly({required int moId, required int componentDetailId}) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode({'component_detail_id': componentDetailId});
    final response = await http.post(Uri.parse('$baseUrl/mo_header/$moId/explode'), headers: headers, body: body);
    if (response.statusCode == 201) {
      return MoHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    }
    final err = json.decode(response.body);
    throw Exception(err['message'] ?? 'สร้างใบสั่งผลิตย่อยล้มเหลว');
  }
}
