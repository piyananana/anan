import '../../config/app_config.dart';
// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company.dart';
import '../models/menu.dart';
import '../models/user.dart';
import '../models/user_branch.dart';
import 'company_service.dart';

class AuthService with ChangeNotifier {
  static const String baseUrl = AppConfig.apiSa;

  static const String _authTokenKey = 'authToken';
  static const String _userKey = 'currentUser';
  static const String _databaseKey = 'currentDatabase';
  static const String _branchesKey = 'userBranches';

  String? _token;
  String? _selectedDatabase;
  User? _currentUser;
  List<Menu> _userMenus = [];
  Company? _company;
  List<UserBranch> _allowedBranches = [];
  UserBranch? _defaultBranch;

  User? get currentUser => _currentUser;
  bool get isDeveloper => _currentUser?.isDeveloper ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  Company? get company => _company;
  List<Menu> get userMenus => _userMenus;
  String? get selectedDatabase => _selectedDatabase;
  List<UserBranch> get allowedBranches => _allowedBranches;
  UserBranch? get defaultBranch => _defaultBranch;

  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

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

  Future<List<String>> fetchDatabases() async {
    final response = await http.get(Uri.parse('$baseUrl/databases'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Failed to load databases.');
    }
  }

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
      if (token == null) return false;

      final headers = await getAuthHeader();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/check_token'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Restore in-memory state from cache (needed after app restart)
        if (_currentUser == null) {
          final userJson = prefs.getString(_userKey);
          if (userJson != null) {
            _currentUser = User.fromJson(json.decode(userJson));
          }
        }
        if (_selectedDatabase == null) {
          await getSelectedDatabase();
        }
        if (_allowedBranches.isEmpty) {
          await _loadBranchesFromCache(prefs);
        }
        return true;
      } else {
        await prefs.remove(_authTokenKey);
        await prefs.remove(_databaseKey);
        return false;
      }
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // --- Auth API ---
  Future<Map<String, dynamic>> login(
      String userName, String password, String databaseName) async {
    _selectedDatabase = databaseName;

    final headers = await getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: headers,
      body: json.encode({
        'userName': userName,
        'password': password,
        'databaseName': databaseName,
        'hostname': _getHostname(),
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;

      // มี session เดิม — คืนให้ frontend จัดการ (ไม่มี token/user ใน response นี้)
      if (data['requiresConfirmation'] == true) return data;

      final String token = data['token'];
      _currentUser = User.fromJson(data['user']);

      final CompanyService companyService = CompanyService();
      final company = await companyService.fetchCompany();
      _company = company;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authTokenKey, token);
      await prefs.setString(_userKey, json.encode(_currentUser!.toJson()));
      await prefs.setString(_databaseKey, databaseName);

      setToken(token);
      await saveDefaultDatabase(databaseName);
      await saveSelectedDatabase(databaseName);

      // Load user's allowed branches (use token directly to avoid SharedPreferences race)
      try {
        final authHeaders = {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
          'X-Database-Name': databaseName,
          'UserId': _currentUser!.id.toString(),
          'UserName': _currentUser!.userName,
        };
        final branchRes = await http.get(
          Uri.parse('$baseUrl/sa_user_branch/${_currentUser!.id}'),
          headers: authHeaders,
        );
        if (branchRes.statusCode == 200) {
          _allowedBranches = (json.decode(branchRes.body) as List)
              .map((b) => UserBranch.fromJson(b))
              .toList();
          final defs = _allowedBranches.where((b) => b.isDefault);
          _defaultBranch = defs.isEmpty ? null : defs.first;
          await prefs.setString(_branchesKey,
              json.encode(_allowedBranches.map((b) => b.toJson()).toList()));
        }
      } catch (_) {
        // Branch loading failure is non-fatal; user can still log in
      }

      notifyListeners();
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to login');
    }
  }

  // เรียกหลัง dialog ยืนยัน — forceLogout=true: kick เครื่องเก่า, false: ยกเลิก
  Future<Map<String, dynamic>> confirmLogin(String confirmToken, {required bool forceLogout}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/confirm'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Database-Name': _selectedDatabase ?? '',
      },
      body: json.encode({'confirmToken': confirmToken, 'forceLogout': forceLogout, 'hostname': _getHostname()}),
    );

    if (response.statusCode != 200) {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'เกิดข้อผิดพลาด');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      final String token = data['token'];
      _currentUser = User.fromJson(data['user']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authTokenKey, token);
      await prefs.setString(_userKey, json.encode(_currentUser!.toJson()));
      await prefs.setString(_databaseKey, _selectedDatabase!);
      setToken(token);
      await saveDefaultDatabase(_selectedDatabase!);
      await saveSelectedDatabase(_selectedDatabase!);

      // โหลดข้อมูลบริษัท (เหมือน login ปกติ)
      try {
        final company = await CompanyService().fetchCompany();
        _company = company;
      } catch (_) {}

      // โหลด branches
      try {
        final authHeaders = {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
          'X-Database-Name': _selectedDatabase!,
          'UserId': _currentUser!.id.toString(),
          'UserName': _currentUser!.userName,
        };
        final branchRes = await http.get(
          Uri.parse('$baseUrl/sa_user_branch/${_currentUser!.id}'),
          headers: authHeaders,
        );
        if (branchRes.statusCode == 200) {
          _allowedBranches = (json.decode(branchRes.body) as List)
              .map((b) => UserBranch.fromJson(b))
              .toList();
          final defs = _allowedBranches.where((b) => b.isDefault);
          _defaultBranch = defs.isEmpty ? null : defs.first;
          await prefs.setString(_branchesKey,
              json.encode(_allowedBranches.map((b) => b.toJson()).toList()));
        }
      } catch (_) {}

      notifyListeners();
    }
    return data;
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
      headers: headers,
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
    // แจ้ง backend ลบ session (best-effort)
    try {
      final headers = await getAuthHeader();
      await http.post(Uri.parse('$baseUrl/auth/logout'), headers: headers);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_branchesKey);
    await prefs.remove('jwt_token');
    await prefs.remove('selected_database');
    _token = null;
    _currentUser = null;
    _selectedDatabase = null;
    _userMenus = [];
    _allowedBranches = [];
    _defaultBranch = null;
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

  // Reload allowed branches from API (call after updating user branch assignments)
  Future<void> reloadBranches() async {
    if (_currentUser == null) return;
    try {
      final headers = await getAuthHeader();
      final branchRes = await http.get(
        Uri.parse('$baseUrl/sa_user_branch/${_currentUser!.id}'),
        headers: headers,
      );
      if (branchRes.statusCode == 200) {
        _allowedBranches = (json.decode(branchRes.body) as List)
            .map((b) => UserBranch.fromJson(b))
            .toList();
        final defs = _allowedBranches.where((b) => b.isDefault);
        _defaultBranch = defs.isEmpty ? null : defs.first;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_branchesKey,
            json.encode(_allowedBranches.map((b) => b.toJson()).toList()));
        notifyListeners();
      }
    } catch (_) {}
  }

  static String _getHostname() {
    if (kIsWeb) return 'web';
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _loadBranchesFromCache(SharedPreferences prefs) async {
    final branchesJson = prefs.getString(_branchesKey);
    if (branchesJson != null) {
      _allowedBranches = (json.decode(branchesJson) as List)
          .map((b) => UserBranch.fromJson(b))
          .toList();
      final defs = _allowedBranches.where((b) => b.isDefault);
      _defaultBranch = defs.isEmpty ? null : defs.first;
    }
  }
}
