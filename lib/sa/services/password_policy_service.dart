import '../../config/app_config.dart';
// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
import '../models/password_policy.dart';
import 'auth_service.dart';
// import '../models/password_status.dart';
// import '../models/user.dart'; // import PasswordStatus

class PasswordPolicyService {
  // static const String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนเป็น IP/Domain ของ Backend ของคุณ
  static const String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  // String? _token;

  // PasswordPolicyService._internal(); // Private constructor
  // static final PasswordPolicyService _instance = PasswordPolicyService._internal(); // Singleton instance

  // factory PasswordPolicyService() {
  //   return _instance;
  // }

  // Future<void> init() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   _token = prefs.getString('jwt_token');
  // }

  // void setToken(String token) {
  //   _token = token;
  //   _saveToken(token);
  // }

  // String? getToken() => _token;

  // Future<void> _saveToken(String token) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('jwt_token', token);
  // }

  // Future<void> clearToken() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove('jwt_token');
  //   _token = null;
  // }

  // Map<String, String> _getHeaders({bool includeAuth = true}) {
  //   final Map<String, String> headers = {
  //     'Content-Type': 'application/json',
  //   };
  //   if (includeAuth && _token != null) {
  //     headers['Authorization'] = 'Bearer $_token';
  //   }
  //   return headers;
  // }

  // --- Auth API ---
  
  // Future<Map<String, dynamic>> login(String userName, String password) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/sa_password_policy/login'),
  //     headers: <String, String>{
  //       'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: jsonEncode(<String, String>{
  //       'userName': userName,
  //       'password': password,
  //     }),
  //   );
  //   if (response.statusCode == 200) {
  //     final responseBody = json.decode(response.body);
  //     final String token = responseBody['token'];
  //     final User user = User.fromJson(responseBody['user']);
  //     // final prefs = await SharedPreferences.getInstance();
  //     // await prefs.setString(_authTokenKey, token);
  //     // await prefs.setString(_userKey, json.encode(user.toJson())); // เก็บ user info เป็น JSON string
  //     return user.toJson(); // คืนค่า user info
  //   } else {
  //     final errorBody = json.decode(response.body);
  //     throw Exception(errorBody['message'] ?? 'Failed to login');
  //   }
  //   // final response = await http.post(
  //   //   Uri.parse('$baseUrl/sa_password_policy/login'),
  //   //   headers: _getHeaders(includeAuth: false),
  //   //   body: json.encode({'userName': username, 'password': password}),
  //   // );
  //   // if (response.statusCode == 200) {
  //   //   final data = json.decode(response.body);
  //   //   setToken(data['accessToken']);
  //   //   return data;
  //   // } else {
  //   //   final errorData = json.decode(response.body);
  //   //   throw Exception(errorData['message'] ?? 'Failed to login');
  //   // }
  // }

  // Future<void> changePassword({
  //   required String oldPassword,
  //   required String newPassword,
  //   required String confirmNewPassword,
  // }) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/auth/change-password'),
  //     headers: _getHeaders(),
  //     body: json.encode({
  //       'oldPassword': oldPassword,
  //       'newPassword': newPassword,
  //       'confirmNewPassword': confirmNewPassword,
  //     }),
  //   );
  //   if (response.statusCode == 200) {
  //     // Password changed successfully
  //   } else {
  //     final errorData = json.decode(response.body);
  //     throw Exception(errorData['message'] ?? 'Failed to change password');
  //   }
  // }

  // --- Password Policy API ---
  Future<PasswordPolicy> getPasswordPolicy() async {
    final headers = await authService.getAuthHeader();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sa_password_policy'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return PasswordPolicy.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        print('errorData: $errorData'); // พิมพ์ข้อผิดพลาดลงใน Console
        throw Exception(
            errorData['message'] ?? 'Failed to fetch password policy');
      }
    } catch (e) {
      rethrow; // โยนข้อผิดพลาดต่อไปเพื่อให้หน้าจอจัดการ
    }
  }

  Future<void> updatePasswordPolicy(PasswordPolicy policy) async {
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/sa_password_policy/$policy'),
      headers: headers,
      body: json.encode(policy.toJson()),
    );

    if (response.statusCode == 200) {
      // Success
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
          errorData['message'] ?? 'Failed to update SA password policy');
    }
  }

  // ... (คุณอาจมี API อื่นๆ เช่น สำหรับ User, Group, Menu)
}
