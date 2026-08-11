import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_price_list.dart';

class ImPriceListService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImPriceListHeader>> fetchRows({String? listType}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_price_list').replace(
      queryParameters: {
        if (listType != null) 'list_type': listType,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceListHeader.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลตารางราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImPriceListHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_list/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImPriceListHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลตารางราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImItemPriceRow>> fetchByItem(int itemId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_list_detail/by_item/$itemId'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImItemPriceRow.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดราคาของสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImPriceListHeader> addRow(ImPriceListHeader row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_price_list'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImPriceListHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เพิ่มข้อมูลล้มเหลว');
    }
  }

  Future<ImPriceListHeader> updateRow(ImPriceListHeader row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_price_list/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImPriceListHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<void> deleteRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/im_price_list/$id'), headers: headers);
    if (response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ลบข้อมูลล้มเหลว');
    }
  }
}
