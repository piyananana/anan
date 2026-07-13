import '../../config/app_config.dart';
// services/sa_user_menu_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sa_auth_service.dart';
import '../models/sa_menu_permission.dart';

// import '../models/sa_menu.dart';

class UserMenuService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  // Future<List<Menu>> getAllMenus() async {
  //   final headers = await authService.getAuthHeader();
  //   final response = await http.get(
  //     Uri.parse('$baseUrl/sa_user_menu'),
  //     headers: headers,
  //   );

  //   if (response.statusCode == 200) {
  //     List jsonResponse = json.decode(response.body);
  //     return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
  //   } else if (response.statusCode == 401) {
  //     throw Exception('Unauthorized. Please login again.');
  //   } else {
  //     throw Exception('การโหลดข้อมูลผู้ใช้ล้มเหลว: ${response.statusCode}');
  //   }
  // }

  // Fetch menu IDs that a specific user has access to
  // Future<List<Menu>> fetchUserMenu(int userId) async {
  //   try {
  //   final headers = await authService.getAuthHeader();
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/sa_user_menu/$userId'),
  //       headers: headers
  //     );
  //     if (response.statusCode == 200) {
  //       List jsonResponse = json.decode(response.body);
  //       return jsonResponse.map((menu) => Menu.fromJson(menu)).toList();
  //     } else {
  //       throw Exception('Failed to load user menu: ${response.statusCode} ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error in fetch User menu: $e');
  //     return [];
  //   }
  // }

  // Update user menu for a user
  Future<void> updateUserMenu(int userId, Map<int, MenuPermission> permissions) async {
    try {
      final headers = await authService.getAuthHeader();
      final menus = permissions.values.map((p) => p.toJson()).toList();
      final requestBody = jsonEncode({'menus': menus});
      final response = await http.put(
        Uri.parse('$baseUrl/sa_user_menu/$userId'),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update user menu: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Network or unknown error during user menu update: $e');
    }
  }

  // Delete all user menu for a user
  Future<void> deleteUserMenu(int userId) async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.delete(
        Uri.parse('$baseUrl/sa_user_menu/$userId'),
        headers: headers,
        body: jsonEncode({'user_id': userId})
      );

      if (response.statusCode == 204) {
        print('All user menu deleted successfully for User $userId');
      } else if (response.statusCode == 404) {
        print('No user menu found for User $userId to delete.');
      } else {
        throw Exception('Failed to delete user menu: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error in delete User menu: $e');
      throw Exception('Failed to delete user menu: $e');
    }
    
  }
}
