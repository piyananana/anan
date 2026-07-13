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
}
