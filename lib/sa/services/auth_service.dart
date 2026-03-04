import '../../config/app_config.dart';
// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company.dart';
import '../models/menu.dart';
import '../models/user.dart';
import 'company_service.dart';

class AuthService with ChangeNotifier {
  // static const String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนเป็น IP/Domain ของ Backend ของคุณ
  static const String baseUrl = AppConfig.apiSa;

  static const String _authTokenKey = 'authToken';
  static const String _userKey = 'currentUser';
  static const String _databaseKey = 'currentDatabase';

  String? _token;
  String? _selectedDatabase; // <<< เพิ่มตัวแปรสำหรับเก็บ database name
  User? _currentUser; // *** เพิ่มตัวแปรสำหรับเก็บข้อมูลผู้ใช้ ***
  List<Menu> _userMenus = []; // *** เพิ่มตัวแปรสำหรับเก็บเมนู ***
  Company? _company; // เพิ่มตัวแปรสำหรับเก็บข้อมูลบริษัท

  User? get currentUser => _currentUser;
  Company? get company => _company; // เพิ่ม getter สำหรับบริษัท
  List<Menu> get userMenus => _userMenus;
  String? get selectedDatabase => _selectedDatabase;

  AuthService._internal(); // Private constructor with parameter
  static final AuthService _instance =
      AuthService._internal(); // Provide a default server address

  factory AuthService() {
    return _instance;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  void setToken(String token) {
    _token = token;
    _saveToken(token);
  }

  String? getToken() => _token;

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _token = null;
  }

  // Map<String, String> _getHeaders({bool includeAuth = true}) {
  //   final Map<String, String> headers = {
  //     'Content-Type': 'application/json',
  //   };
  //   if (includeAuth && _token != null) {
  //     headers['Authorization'] = 'Bearer $_token';
  //   }
  //   return headers;
  // }

  // ฟังก์ชันสำหรับเรียกรายชื่อฐานข้อมูลจาก Backend
  Future<List<String>> fetchDatabases() async {
    final response = await http.get(Uri.parse('$baseUrl/databases'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Failed to load databases.');
    }
  }

  // ฟังก์ชันสำหรับบันทึกและโหลดค่า database name ใน SharedPreferences
  Future<void> saveDefaultDatabase(String databaseName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_database', databaseName);
  }

  Future<String?> getDefaultDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_database');
  }

  Future<void> saveSelectedDatabase(String databaseName) async {
    _selectedDatabase = databaseName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_database', databaseName);
  }

  Future<void> getSelectedDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedDatabase = prefs.getString('selected_database');
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      // final databaseName = prefs.getString(_databaseKey);

      // if (token == null || databaseName == null) {
      //   return false;
      // }
      if (token == null) {
        return false;
      }

      // final headers = {
      //   'Content-Type': 'application/json',
      //   'Authorization': 'Bearer $token',
      //   'x-database-name': databaseName,
      // };
      final headers = await getAuthHeader();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/check_token'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        // Token is invalid, remove it
        await prefs.remove(_authTokenKey);
        await prefs.remove(_databaseKey);
        return false;
      }
    } catch (e) {
      // if (kDebugMode) {
        print('Error checking login status: $e');
      // }
      return false;
    }
  }

  // --- Auth API ---
  Future<Map<String, dynamic>> login(
      String userName, String password, String databaseName) async {

    _selectedDatabase = databaseName; // *** บันทึกชื่อฐานข้อมูล ***

    final headers = await getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: headers,
      body: json.encode({
        'userName': userName,
        'password': password,
        'databaseName': databaseName,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final String token = data['token'];
      _currentUser = User.fromJson(data['user']); // *** บันทึกข้อมูลผู้ใช้ ***
      // _selectedDatabase = databaseName; // *** บันทึกชื่อฐานข้อมูล ***

      final CompanyService companyService = CompanyService();
      final company = await companyService.fetchCompany();
      _company = company; // บันทึกข้อมูลบริษัท
      
      // _company = Company.fromJson(data['company']); // บันทึกข้อมูลบริษัท
      // _userMenus = _buildMenuTree(data['menus']); // *** บันทึกเมนู ***

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authTokenKey, token);
      await prefs.setString(_userKey,json.encode(_currentUser!.toJson()));
      await prefs.setString(_databaseKey, databaseName);

      // setToken(data['accessToken']);
      setToken(data['token']);
      await saveDefaultDatabase(databaseName); // <<< บันทึก database ที่เลือก
      await saveSelectedDatabase(databaseName); // <<< บันทึก database ที่เลือก
      notifyListeners(); // *** แจ้งให้ Consumer ทราบว่าข้อมูลเปลี่ยนไป ***
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to login');
    }
  }

  Future<void> changePassword({
    required int? userId,
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final headers = await getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change_password/$userId'),
      // headers: _getHeaders(),
      headers: headers,
      // headers: <String, String>{
      //   'Content-Type': 'application/json; charset=UTF-8',
      //   'X-Database-Name':
      //       selectedDatabase!, // <<< ส่ง databaseName ไปใน header
      // },
      body: json.encode({
        'userId': userId,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      }),
    );

    if (response.statusCode == 200) {
      // Password changed successfully
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to change password');
    }
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userKey);

    await prefs.remove('jwt_token');
    await prefs.remove('selected_database');
    _token = null;
    _currentUser = null;
    _selectedDatabase = null;
    _userMenus = [];
    notifyListeners();
  }

  Future<Map<String, String>> getAuthHeader() async {
    final token = await getAuthToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
      'X-Database-Name': _selectedDatabase!,
      'UserId': currentUser?.id.toString() ?? '',
      'UserName': currentUser?.userName ?? '',
    };
  }

  // ... (คุณอาจมี API อื่นๆ เช่น สำหรับ User, Group, Menu)
  // เมธอดส่วนตัวสำหรับดึงข้อมูลบริษัท
  // Future<void> _fetchCompanyData(String databaseName) async {
  //   try {
  //     final response = await http.get(Uri.parse('$baseUrl/sa_company/profile'),
  //         headers: <String, String>{
  //           'Content-Type': 'application/json; charset=UTF-8',
  //           'X-Database-Name': databaseName,
  //         }
  //     );
  //     if (response.statusCode == 200) {
  //       _company = Company.fromJson(json.decode(response.body));
  //     } else {
  //       // ดึงข้อมูลบริษัทไม่ได้ อาจไม่ต้อง logout แต่ต้องแจ้งเตือน
  //       print('Failed to fetch company data');
  //     }
  //   } catch (e) {
  //     print('Error fetching company data: $e');
  //   }
  // }

  // เมธอดสำหรับสร้าง Tree Structure ของเมนู
  // List<Menu> _buildMenuTree(List<dynamic> jsonList) {
  //   final List<Menu> menus =
  //       jsonList.map((item) => Menu.fromJson(item)).toList();
  //   final Map<int, Menu> menuMap = {for (var menu in menus) menu.id: menu};
  //   final List<Menu> rootMenus = [];
  //   for (var menu in menus) {
  //     if (menu.parentId == null) {
  //       rootMenus.add(menu);
  //     } else {
  //       menuMap[menu.parentId!]?.children.add(menu);
  //     }
  //   }
  //   // เรียงลำดับเมนูตาม sort_order
  //   for (var menu in menus) {
  //     menu.children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  //   }
  //   rootMenus.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  //   return rootMenus;
  // }
}
