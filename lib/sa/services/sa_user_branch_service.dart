import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'sa_auth_service.dart';
import '../models/sa_user_branch.dart';

class UserBranchService {
  final String _baseUrl = AppConfig.apiSa;
  final AuthService _auth = AuthService();

  UserBranchService._internal();
  static final UserBranchService _instance = UserBranchService._internal();
  factory UserBranchService() => _instance;

  Future<List<UserBranch>> fetchByUserId(int userId) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.get(
      Uri.parse('$_baseUrl/sa_user_branch/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((e) => UserBranch.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load user branches: ${response.statusCode}');
  }

  Future<void> updateByUserId(int userId, List<UserBranch> branches) async {
    final headers = await _auth.getAuthHeader();
    final response = await http.put(
      Uri.parse('$_baseUrl/sa_user_branch/$userId'),
      headers: headers,
      body: json.encode({
        'branches': branches
            .map((b) => {'branch_id': b.branchId, 'is_default': b.isDefault})
            .toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user branches: ${response.statusCode}');
    }
  }
}
