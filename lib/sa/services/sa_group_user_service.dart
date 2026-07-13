import '../../config/app_config.dart';
// lib/services/sa_group_user_service.dart (NEW)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sa_auth_service.dart';
import '../models/sa_user.dart';

class GroupUserService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  // ดึงผู้ใช้ทั้งหมดที่เป็น Active (พร้อมสถานะว่าสังกัดหน่วยงานหรือไม่)
  Future<List<User>> getGroupUser(String groupId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_group_user/$groupId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<User>.from(l.map((model) => User.fromJson(model)));
    } else {
      throw Exception('Failed to load all active users for group $groupId');
    }
  }

  // ดึงผู้ใช้ที่สังกัดหน่วยงานนั้นๆ เท่านั้น (สำหรับโหมด "ดู")
  Future<List<User>> getGroupOnlyUsers(String groupId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_group_user/only/$groupId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      if (response.body.length == 2) {
        return []; // ถ้าไม่มีผู้ใช้ในหน่วยงานนั้นๆ ให้คืนค่าเป็นลิสต์ว่าง
      } else {
        Iterable l = json.decode(response.body);
        return List<User>.from(l.map((model) => User.fromJson(model)));
      }
    } else {
      throw Exception('Failed to load members of group $groupId');
    }
  }

  // เพิ่มผู้ใช้เข้ากลุ่ม
  Future<void> createGroupUserByUserId(String groupId, int userId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/sa_group_user/$groupId/$userId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add user into group: ${response.body}');
    }
  }

// // อัปเดตสมาชิกของหน่วยงาน
//   Future<void> updateGroupMembers(String groupId, List<int> userIds) async {
//     final response = await http.put(
//       Uri.parse('$baseUrl/sa_group_user/$groupId'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({'userIds': userIds}),
//     );
//     if (response.statusCode != 200) {
//       throw Exception('Failed to update group members: ${response.body}');
//     }
//   }

  // ลบผู้ใช้ทั้งหมดออกจากหน่วยงาน
  Future<void> deleteGroupUsers(String groupId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/sa_group_user/$groupId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete all users from group: ${response.body}');
    }
  }

  // ลบผู้ใช้ทั้งหมดออกจากหน่วยงาน
  Future<void> deleteGroupUserByUserId(String groupId, int userId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/sa_group_user/$groupId/$userId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user $userId from group: ${response.body}');
    }
  }

  // คัดลอกสิทธิ์จาก group_menus ไปยัง permissions ของ user
  Future<void> copyGroupMenuToUser(String groupId, int userId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/sa_group_user/copy/$groupId/$userId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to copy group menu to user: ${response.body}');
    }
  }
}