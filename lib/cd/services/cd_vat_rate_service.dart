import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/cd_vat_rate.dart';

class VatRateService {
  final String baseUrl = AppConfig.apiCd;
  final AuthService authService = AuthService();

  Future<List<VatRate>> fetchRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_vat_rate'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((item) => VatRate.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลอัตราภาษีล้มเหลว: ${response.statusCode}');
    }
  }

  /// ดึงอัตราภาษีที่มีผลบังคับ ณ วันที่ที่ระบุ
  Future<VatRate?> fetchEffectiveRate(String vatCode, DateTime date) async {
    final headers = await authService.getAuthHeader();
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await http.get(
      Uri.parse('$baseUrl/cd_vat_rate/effective?vat_code=$vatCode&date=$dateStr'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return VatRate.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดอัตราภาษีล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchVatCodes() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/cd_vat_rate/codes'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.cast<Map<String, dynamic>>();
    } else {
      throw Exception('โหลดรหัสภาษีล้มเหลว: ${response.statusCode}');
    }
  }

  Future<VatRate> addRow(VatRate row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/cd_vat_rate'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return VatRate.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data. Please login again.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<VatRate> updateRow(VatRate row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/cd_vat_rate/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return VatRate.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update data. Please login again.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/cd_vat_rate/$id'),
      headers: headers,
    );
    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('ไม่พบข้อมูล');
    } else {
      throw Exception('ลบข้อมูลล้มเหลว: ${response.body}');
    }
  }
}
