import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/gl_dimension.dart';

class GlDimensionService {
  final String _base = AppConfig.apiGl;
  final AuthService _auth = AuthService();

  // ── Dimension Types ──────────────────────────────────────────────────────

  Future<List<GlDimensionType>> fetchActiveTypes() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/gl_dimension_type/active'), headers: headers);
    if (res.statusCode == 200) {
      final List json = jsonDecode(res.body);
      return json.map((e) => GlDimensionType.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<GlDimensionType>> fetchAllTypes() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/gl_dimension_type'), headers: headers);
    if (res.statusCode == 200) {
      final List json = jsonDecode(res.body);
      return json.map((e) => GlDimensionType.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<GlDimensionType?> upsertType(GlDimensionType type) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$_base/gl_dimension_type'),
      headers: headers,
      body: jsonEncode(type.toJson()),
    );
    if (res.statusCode == 200) {
      return GlDimensionType.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to save dimension type');
  }

  // ── Dimension Values ─────────────────────────────────────────────────────

  Future<List<GlDimensionValue>> fetchValuesByType(String typeCode, {bool includeInactive = false}) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/gl_dimension_value').replace(queryParameters: {
      'type_code': typeCode,
      if (includeInactive) 'include_inactive': 'true',
    });
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final List json = jsonDecode(res.body);
      return json.map((e) => GlDimensionValue.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<GlDimensionValue> addValue(GlDimensionValue value) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.post(
      Uri.parse('$_base/gl_dimension_value'),
      headers: headers,
      body: jsonEncode(value.toJson()),
    );
    if (res.statusCode == 201) {
      return GlDimensionValue.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to add dimension value');
  }

  Future<GlDimensionValue> updateValue(int id, GlDimensionValue value) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(
      Uri.parse('$_base/gl_dimension_value/$id'),
      headers: headers,
      body: jsonEncode(value.toJson()),
    );
    if (res.statusCode == 200) {
      return GlDimensionValue.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to update dimension value');
  }

  Future<void> deleteValue(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.delete(Uri.parse('$_base/gl_dimension_value/$id'), headers: headers);
    if (res.statusCode == 200) return;
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to delete dimension value');
  }

  // ── สรุปของหน้าจอประเภทมิติ / ค่ามิติ (2026-11-28) ──
  String _msg(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is Map && (j['error'] ?? j['message']) != null) return (j['error'] ?? j['message']).toString();
    } catch (_) {}
    return 'HTTP ${r.statusCode}';
  }

  Future<Map<int, GlDimTypeUsage>> fetchTypeUsage() async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/gl_dimension_type/usage'), headers: headers);
    if (res.statusCode != 200) throw Exception(_msg(res));
    final List rows = jsonDecode(res.body);
    return {for (final r in rows) (r['slot_no'] as num).toInt(): GlDimTypeUsage.fromJson(r as Map<String, dynamic>)};
  }

  Future<GlDimTypeSummary> fetchTypeSummary(int slotNo) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/gl_dimension_type/$slotNo/summary'), headers: headers);
    if (res.statusCode != 200) throw Exception(_msg(res));
    return GlDimTypeSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<int, GlDimValueLineCount>> fetchValueUsage(String typeCode) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/gl_dimension_value/usage').replace(queryParameters: {'type_code': typeCode});
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) throw Exception(_msg(res));
    final List rows = jsonDecode(res.body);
    return {
      for (final r in rows) (r['id'] as num).toInt(): GlDimValueLineCount((r['lines_year'] as num?)?.toInt() ?? 0, (r['lines_all'] as num?)?.toInt() ?? 0),
    };
  }

  Future<GlDimValueSummary> fetchValueSummary(int id) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.get(Uri.parse('$_base/gl_dimension_value/$id/summary'), headers: headers);
    if (res.statusCode != 200) throw Exception(_msg(res));
    return GlDimValueSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// ย้ายไปอยู่ใต้ค่าอื่นในประเภทเดียวกัน (null = ระดับบนสุด)
  Future<void> moveValue(int id, int? parentId) async {
    final headers = await _auth.getAuthHeader();
    final res = await http.put(Uri.parse('$_base/gl_dimension_value/$id/move'), headers: headers, body: jsonEncode({'parent_id': parentId}));
    if (res.statusCode != 200) throw Exception(_msg(res));
  }
}
