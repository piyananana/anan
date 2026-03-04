import '../../config/app_config.dart';
// services/organization_menu_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'auth_service.dart';

class GroupMenuService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  // Future<List<Menu>> getAllGroupMenus() async {
  //   final response = await http.get(Uri.parse('$baseUrl/sa_group_menu'));
  //   if (response.statusCode == 200) {
  //     List jsonResponse = json.decode(response.body);
  //     return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
  //   } else if (response.statusCode == 401) {
  //     throw Exception('Unauthorized. Please login again.');
  //   } else {
  //     throw Exception('การโหลดข้อมูลล้มเหลว: ${response.statusCode}');
  //   }
  // }

  // // Fetch menu IDs that a specific group has access to
  // Future<List<Menu>> fetchGroupMenuById(String? groupId) async {
  //   try {
  //     final response = await http.get(Uri.parse('$baseUrl/sa_menu/$groupId'));
  //     if (response.statusCode == 200) {
  //     List jsonResponse = json.decode(response.body);
  //     return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
  //     } else {
  //       throw Exception('Failed to load group menu: ${response.statusCode} ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error in fetchGroupMenuById: $e');
  //     // Fallback to mock data or return empty set if backend call fails
  //     // return _mockFetchUserPermissions(groupId); // ถ้าต้องการใช้ mock เป็น fallback
  //     return [];
  //   }
  // }

  // Update permissions for an organization
  Future<void> updateGroupMenu(String? groupId, Set<int> newMenuIds) async {
    try {
      final headers = await authService.getAuthHeader();
      final requestBody = jsonEncode({'menuIds': newMenuIds.toList()});
      final response = await http.put(
        Uri.parse('$baseUrl/sa_group_menu/$groupId'),
        headers: headers,
        body: requestBody
      );

      if (response.statusCode == 200) {
        // print('Updated successfully for Group menu $groupId');
        // print('Node.js Response Body: ${response.body}');
      } else {
        print('Failed to update group menu: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to update group menu: Status ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error in updateGroupMenu catch block: $e');
      throw Exception('Network or unknown error during permission update: $e');
    }
  }

  // Delete all permissions for a user
  Future<void> deleteGroupMenu(String? groupId) async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.delete(
        Uri.parse('$baseUrl/sa_group_menu/$groupId'),
        headers: headers,
        body: jsonEncode({'group_id': groupId}));

      if (response.statusCode == 204) {
        // print('All permissions deleted successfully for group $groupId');
      } else if (response.statusCode == 404) {
        print('No permissions found for group $groupId to delete.');
      } else {
        throw Exception('Failed to delete group menu: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error in deleteGroupMenu: $e');
      throw Exception('Failed to delete group: $e');
    }
  }
}
