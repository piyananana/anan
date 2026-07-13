import '../../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sa_auth_service.dart';
import '../models/sa_group.dart';

class GroupService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  Future<List<Group>> fetchDataById(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_group/$id'),
      headers: headers
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((menu) => Group.fromJson(menu)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      // _authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลล้มเหลว: ${response.statusCode}');
    }
  }
  
  Future<List<Group>> fetchData() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_group'),
      headers: headers
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Group.fromJson(data)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      // _authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add Group ***
  Future<Group> createData(Group org) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/sa_group'),
      headers: headers,
      body: jsonEncode(org.toJson()),
    );
    if (response.statusCode == 201) {
      return Group.fromJson(jsonDecode(response.body)['rowResult']);
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  // *** NEW: Update Group ***
  Future<Group> updateData(Group org) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/sa_group/${org.id}'),
      headers: headers,
      body: jsonEncode(org.toJson()),
    );
    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body)['rowResult']);
    } else {
      throw Exception('Failed to update group: ${response.body}');
    }
  }

  // *** NEW: Delete Group ***
  Future<void> deleteData(String? id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/sa_group/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
  }

}
