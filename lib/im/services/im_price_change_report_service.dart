import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/im_item_category.dart';
import '../models/im_price_change_report.dart';

class ImPriceChangeReportService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<List<ImItemCategory>> fetchCategories({List<int>? priceListIds}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_price_change_report/categories').replace(
      queryParameters: {
        if (priceListIds != null && priceListIds.isNotEmpty) 'price_list_ids': priceListIds.join(','),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImItemCategory.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดหมวดหมู่สินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImPriceChangeReportItem>> searchItems({List<int>? priceListIds, String? search}) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/im_price_change_report/items').replace(
      queryParameters: {
        if (priceListIds != null && priceListIds.isNotEmpty) 'price_list_ids': priceListIds.join(','),
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceChangeReportItem.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('ค้นหาสินค้าล้มเหลว: ${response.statusCode}');
    }
  }

  Future<List<ImPriceChangeReportRow>> fetchReport({
    List<int>? priceGroupIds,
    List<int>? priceListIds,
    List<int>? categoryIds,
    String? itemCodeFrom,
    String? itemCodeTo,
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String>? changeStatuses,
    String? activeStatus,
  }) async {
    final headers = await authService.getAuthHeader();
    String fmt(DateTime d) => d.toIso8601String().substring(0, 10);
    final uri = Uri.parse('$baseUrl/im_price_change_report').replace(
      queryParameters: {
        if (priceGroupIds != null && priceGroupIds.isNotEmpty) 'price_group_ids': priceGroupIds.join(','),
        if (priceListIds != null && priceListIds.isNotEmpty) 'price_list_ids': priceListIds.join(','),
        if (categoryIds != null && categoryIds.isNotEmpty) 'category_ids': categoryIds.join(','),
        if (itemCodeFrom != null && itemCodeFrom.isNotEmpty) 'item_code_from': itemCodeFrom,
        if (itemCodeTo != null && itemCodeTo.isNotEmpty) 'item_code_to': itemCodeTo,
        if (dateFrom != null) 'date_from': fmt(dateFrom),
        if (dateTo != null) 'date_to': fmt(dateTo),
        if (changeStatuses != null && changeStatuses.isNotEmpty) 'change_statuses': changeStatuses.join(','),
        if (activeStatus != null && activeStatus != 'ALL') 'active_status': activeStatus,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => ImPriceChangeReportRow.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('โหลดรายงานล้มเหลว: ${response.statusCode}');
    }
  }
}
