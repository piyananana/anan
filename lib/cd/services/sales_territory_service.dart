// lib/cd/services/sales_territory_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/sales_territory.dart';

class SalesTerritoryService {
  final String _base = AppConfig.apiCd;
  final AuthService _auth = AuthService();

  Future<List<SalesTerritory>> fetchRows() async {
    final headers = await _auth.getAuthHeader();
    final response =
        await http.get(Uri.parse('$_base/cd_sales_territory'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => SalesTerritory.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลเขตการขายล้มเหลว: ${response.statusCode}');
  }

  Future<List<SalesTerritory>> fetchActiveRows() async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
        Uri.parse('$_base/cd_sales_territory/active'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => SalesTerritory.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลเขตการขายล้มเหลว: ${response.statusCode}');
  }

  Future<List<TerritoryMember>> fetchMembers(int territoryId) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
        Uri.parse('${AppConfig.apiCd}/cd_salesperson/by_territory/$territoryId'),
        headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => TerritoryMember.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('โหลดข้อมูลพนักงานขายล้มเหลว: ${response.statusCode}');
  }

  Future<SalesTerritory> addRow(SalesTerritory row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.post(
      Uri.parse('$_base/cd_sales_territory'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return SalesTerritory.fromJson(json.decode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('เพิ่มข้อมูลล้มเหลว: ${response.body}');
  }

  Future<SalesTerritory> updateRow(SalesTerritory row) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(
      Uri.parse('$_base/cd_sales_territory/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return SalesTerritory.fromJson(json.decode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('บันทึกข้อมูลล้มเหลว: ${response.body}');
  }

  Future<void> deleteRow(int id) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.delete(
        Uri.parse('$_base/cd_sales_territory/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 409) {
      throw Exception(json.decode(response.body)['message']);
    } else if (response.statusCode == 401) {
      _auth.logout();
      throw Exception('Unauthorized');
    }
    throw Exception('ลบข้อมูลล้มเหลว: ${response.body}');
  }
}
