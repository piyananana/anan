import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_price_list.dart';

class ImPriceListService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImPriceListHeader>> fetchRows({String? listType, List<int>? priceGroupIds}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_price_list').replace(
      queryParameters: {
        if (listType != null) 'list_type': listType,
        if (priceGroupIds != null && priceGroupIds.isNotEmpty) 'price_group_ids': priceGroupIds.join(','),
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

  // ── เครื่องมือหน้าจอตารางราคา (user 2026-11-25) ──
  /// สินค้าขาย/ซื้อที่ยังไม่มีราคาในตารางนี้ (id 0 = ตารางใหม่ = ทุกสินค้า)
  Future<List<ImPriceMissingItem>> fetchMissingItems(int id, String listType) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_list/$id/missing_items?list_type=$listType'), headers: headers);
    if (response.statusCode == 200) {
      final j = json.decode(response.body) as Map<String, dynamic>;
      return (j['items'] as List<dynamic>? ?? []).map((e) => ImPriceMissingItem.fromJson(e)).toList();
    }
    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    }
    throw Exception('โหลดสินค้าที่ยังไม่มีราคาล้มเหลว: ${response.statusCode}');
  }

  Future<List<int>> downloadImportTemplate({required bool english}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_list/import/template/download?lang=${english ? 'en' : 'th'}'), headers: headers);
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('ดาวน์โหลดเทมเพลตไม่สำเร็จ (${response.statusCode})');
  }

  Future<ImPriceImportResult> parseImport(List<int> bytes, String filename, String listType) async {
    final headers = await authService.getAuthHeader();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/im_price_list/import/parse'))
      ..headers.addAll(headers)
      ..fields['list_type'] = listType
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename,
          contentType: MediaType.parse(filename.toLowerCase().endsWith('.csv')
              ? 'text/csv'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) return ImPriceImportResult.fromJson(json.decode(response.body));
    String msg = 'อ่านไฟล์ไม่สำเร็จ (${response.statusCode})';
    try { msg = (json.decode(response.body) as Map<String, dynamic>)['message'] ?? msg; } catch (_) {}
    throw Exception(msg);
  }
}
