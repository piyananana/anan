// lib/sa/services/sa_favorite_menu_service.dart — เมนูโปรดของผู้ใช้ที่ login อยู่ (หน้าหลัก)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'sa_auth_service.dart';

class FavoriteMenuService {
  final AuthService _auth = AuthService();

  /// รหัสเมนูโปรดตามลำดับ
  Future<List<int>> fetch() async {
    final res = await http.get(Uri.parse('${AppConfig.apiSa}/sa_favorite_menu'), headers: await _auth.getAuthHeader());
    if (res.statusCode != 200) throw Exception('Failed to load favorite menus (${res.statusCode})');
    return (jsonDecode(res.body) as List).map((e) => (e as num).toInt()).toList();
  }

  /// แทนที่รายการเมนูโปรดทั้งหมด (ลำดับตามที่ส่ง)
  Future<void> save(List<int> menuIds) async {
    final res = await http.put(
      Uri.parse('${AppConfig.apiSa}/sa_favorite_menu'),
      headers: await _auth.getAuthHeader(),
      body: jsonEncode({'menu_ids': menuIds}),
    );
    if (res.statusCode != 200) throw Exception('Failed to save favorite menus (${res.statusCode})');
  }
}
