import '../../config/app_config.dart';
// services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

import '../models/user.dart';

class UserService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  Future<List<User>> fetchUsers() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/sa_user'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((user) => User.fromJson(user)).toList();
    } else if (response.statusCode == 401) {
      // อาจจะจัดการกรณี Token หมดอายุหรือไม่ถูกต้อง
      // เช่น logout ผู้ใช้และพาไปหน้า Login
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      throw Exception('การโหลดข้อมูลผู้ใช้ล้มเหลว: ${response.statusCode}');
    }
  }

  // *** NEW: Add User ***
  Future<User> addUser(User user) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/sa_user'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'userName': user.userName,
        'password': user.password,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'user_type': user.userType,
        'status': user.status,
        'email': user.email,
      }),
    );

    if (response.statusCode == 201) {
      return User.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to add user. Please login again.');
    } else {
      throw Exception('Failed to add user: ${response.body}');
    }
  }

  // *** NEW: Update User ***
  Future<User> updateUser(User user) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/sa_user/${user.id}'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'userName': user.userName,
        'password': user.password,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'user_type': user.userType,
        'status': user.status,
        'email': user.email,
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to update user. Please login again.');
    } else {
      throw Exception('Failed to update user: ${response.body}');
    }
  }

  // *** NEW: Delete User ***
  Future<void> deleteUser(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/sa_user/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // No content, successful
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      authService.logout();
      throw Exception('Unauthorized to delete user. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('User not found.');
    } else {
      throw Exception('Failed to delete user: ${response.body}');
    }
  }
}
