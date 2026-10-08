import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/im_price_change.dart';

class ImPriceChangeService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  // ประเภทเอกสารที่ผู้ใช้คนนี้มีสิทธิ์ใช้ได้ภายใต้โมดูล IM ('31') — กรอง sys_doc_type='85' (เปลี่ยนแปลงราคา)
  // ที่หน้าจอเอง เพราะ endpoint นี้คืนทุกประเภทเอกสารของ IM มาให้ (ใช้ร่วมกับ im_transaction_service.dart)
  Future<List<ModuleDocument>> fetchDocTypesByUser() async {
    final headers = await authService.getAuthHeader();
    final userId = authService.currentUser?.id ?? 0;
    final response = await http.get(
      Uri.parse('${AppConfig.apiSa}/sa_module_document/sys_module_user/31/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ModuleDocument.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดประเภทเอกสารล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImPriceChangeHeader>> fetchRows({String? status, int? priceListId}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_price_change').replace(
      queryParameters: {
        if (status != null) 'status': status,
        if (priceListId != null) 'price_list_id': '$priceListId',
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceChangeHeader.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดรายการธุรกรรมเปลี่ยนแปลงราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImPriceChangeHeader> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_price_change/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImPriceChangeHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลธุรกรรมเปลี่ยนแปลงราคาล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImPriceChangeDetail>> previewLines({
    required int priceListId,
    List<int>? categoryIds,
    String? itemCodeFrom,
    String? itemCodeTo,
  }) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_price_change/preview_lines').replace(
      queryParameters: {
        'price_list_id': '$priceListId',
        if (categoryIds != null && categoryIds.isNotEmpty) 'category_ids': categoryIds.join(','),
        if (itemCodeFrom != null && itemCodeFrom.isNotEmpty) 'item_code_from': itemCodeFrom,
        if (itemCodeTo != null && itemCodeTo.isNotEmpty) 'item_code_to': itemCodeTo,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceChangeDetail.fromPreviewJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('ดึงข้อมูลสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImPriceChangeHeader> addRow(ImPriceChangeHeader row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_price_change'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 201) {
      return ImPriceChangeHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<ImPriceChangeHeader> updateRow(ImPriceChangeHeader row) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/im_price_change/${row.id}'),
      headers: headers,
      body: jsonEncode(row.toJson()),
    );
    if (response.statusCode == 200) {
      return ImPriceChangeHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update data.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลล้มเหลว');
    }
  }

  Future<ImPriceChangeHeader> _putAction(int id, String action) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_price_change/$id/$action'), headers: headers);
    if (response.statusCode == 200) {
      return ImPriceChangeHeader.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ดำเนินการล้มเหลว');
    }
  }

  Future<ImPriceChangeHeader> submit(int id) => _putAction(id, 'submit');
  Future<ImPriceChangeHeader> approve(int id) => _putAction(id, 'approve');
  Future<ImPriceChangeHeader> reject(int id) => _putAction(id, 'reject');
  Future<ImPriceChangeHeader> voidChange(int id) => _putAction(id, 'void');
}
