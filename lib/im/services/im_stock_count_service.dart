// lib/im/services/im_stock_count_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_download.dart';
import '../models/im_stock_count.dart';

class ImStockCountService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImStockCountHeader>> fetchRows({
    int? warehouseId,
    String? status,
    String? dateFrom,
    String? dateTo,
    bool excludeClosedVoid = false,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{
      if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (excludeClosedVoid) 'exclude_closed_void': 'true',
    };
    final uri = Uri.parse('$baseUrl/im_stock_count').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImStockCountHeader.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลใบตรวจนับล้มเหลว: ${response.statusCode}');
    }
  }

  Future<ImStockCount> fetchRow(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_stock_count/$id'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดข้อมูลใบตรวจนับล้มเหลว: ${response.statusCode}');
    }
  }

  // สร้างใบตรวจนับใหม่ — backend จะดึงรายการสินค้า+location จากยอดคงเหลือของคลังที่เลือกให้อัตโนมัติ
  Future<ImStockCount> createCount({
    required int warehouseId,
    required DateTime countDate,
    String? description,
  }) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode({
      'warehouse_id': warehouseId,
      'count_date': formatLocalDate(countDate),
      if (description != null) 'description': description,
    });
    final response = await http.post(Uri.parse('$baseUrl/im_stock_count'), headers: headers, body: body);
    if (response.statusCode == 201) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'สร้างใบตรวจนับล้มเหลว');
    }
  }

  Future<ImStockCount> updateHeader({
    required int id,
    required int warehouseId,
    required DateTime countDate,
    String? description,
  }) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode({
      'warehouse_id': warehouseId,
      'count_date': formatLocalDate(countDate),
      if (description != null) 'description': description,
    });
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id'), headers: headers, body: body);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกข้อมูลเอกสารล้มเหลว');
    }
  }

  // "โหลดผังใหม่" — Draft only, ดึงยอดคงเหลือปัจจุบันมาแทนที่รายการเดิมทั้งหมด
  Future<ImStockCount> resyncLines(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/resync'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'โหลดผังใหม่ล้มเหลว');
    }
  }

  // "บันทึกใบตรวจนับ" — Draft -> Posted, freeze system_qty
  Future<ImStockCount> postCount(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/post'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกใบตรวจนับล้มเหลว');
    }
  }

  Future<ImStockCount> voidCount(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/void'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ยกเลิกเอกสารล้มเหลว');
    }
  }

  Future<int> incrementPrintCount(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/print_count'), headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body)['print_count'] as num).toInt();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'อัปเดตครั้งที่พิมพ์ล้มเหลว');
    }
  }

  // รายการสินค้าทั้งหมดภายใต้ location subtree ที่เลือก — ใช้โดยหน้าบันทึกรายการตรวจนับ
  Future<List<ImStockCountDetail>> fetchLinesForRecording({required int id, required int locationId}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_stock_count/$id/lines').replace(queryParameters: {'location_id': locationId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImStockCountDetail.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'โหลดรายการสินค้าล้มเหลว');
    }
  }

  Future<ImStockCount> updateCounts({required int id, required List<Map<String, dynamic>> lines}) async {
    final headers = await authService.getAuthHeader();
    final body = jsonEncode({'lines': lines});
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/counts'), headers: headers, body: body);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกยอดตรวจนับล้มเหลว');
    }
  }

  Future<ImStockCountCheckResult> checkResults(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_stock_count/$id/check'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCountCheckResult.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ตรวจผลล้มเหลว');
    }
  }

  Future<ImStockCount> approveCount(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/approve'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'อนุมัติล้มเหลว');
    }
  }

  Future<ImStockCount> closeCount(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(Uri.parse('$baseUrl/im_stock_count/$id/close'), headers: headers);
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'บันทึกปรับยอดล้มเหลว');
    }
  }

  Future<List<ImStockCountVarianceRow>> fetchVarianceReport({
    int? countId,
    int? warehouseId,
    int? locationId,
    String? dateFrom,
    String? dateTo,
    bool varianceOnly = false,
  }) async {
    final headers = await authService.getAuthHeader();
    final queryParams = <String, String>{
      if (countId != null) 'count_id': countId.toString(),
      if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
      if (locationId != null) 'location_id': locationId.toString(),
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (varianceOnly) 'variance_only': 'true',
    };
    final uri = Uri.parse('$baseUrl/im_stock_count/variance_report').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImStockCountVarianceRow.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      throw Exception('โหลดรายงานเปรียบเทียบล้มเหลว: ${response.statusCode}');
    }
  }

  // ดาวน์โหลดไฟล์ Excel ของรายการภายใต้ location subtree ที่เลือก (ล็อคทุกคอลัมน์ยกเว้นยอดตรวจนับ/ต้นทุน/หมายเหตุ)
  Future<void> exportExcel({required int id, required int locationId}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_stock_count/$id/export').replace(queryParameters: {'location_id': locationId.toString()});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      await downloadFile(response.bodyBytes, 'stock_count_$id.xlsx');
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Export ล้มเหลว');
    }
  }

  Future<Map<String, dynamic>> importValidate({
    required int id,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final authHeaders = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_stock_count/$id/import/validate');
    final request = http.MultipartRequest('POST', uri)..headers.addAll(authHeaders);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ตรวจสอบไฟล์ล้มเหลว');
    }
  }

  Future<ImStockCount> importConfirm({required int id, required List<Map<String, dynamic>> rows}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/im_stock_count/$id/import/confirm'),
      headers: headers,
      body: jsonEncode({'rows': rows}),
    );
    if (response.statusCode == 200) {
      return ImStockCount.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'นำเข้าไฟล์ล้มเหลว');
    }
  }
}
