import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'sa_auth_service.dart';

class AuditLogRow {
  final int id;
  final int userId;
  final String username;
  final String fullName;
  final String dbName;
  final String? ipAddress;
  final String? hostname;
  final String loginAtStr;
  final String? logoutAtStr;
  final String? logoutType;
  final int? durationSecondsDisplay;
  final bool isActive;

  const AuditLogRow({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.dbName,
    this.ipAddress,
    this.hostname,
    required this.loginAtStr,
    this.logoutAtStr,
    this.logoutType,
    this.durationSecondsDisplay,
    required this.isActive,
  });

  factory AuditLogRow.fromJson(Map<String, dynamic> j) => AuditLogRow(
        id:                      j['id']       ?? 0,
        userId:                  j['user_id']  ?? 0,
        username:                j['username'] ?? '',
        fullName:                j['full_name'] ?? '',
        dbName:                  j['db_name']  ?? '',
        ipAddress:               j['ip_address'],
        hostname:                j['hostname'],
        loginAtStr:              j['login_at_str']  ?? '',
        logoutAtStr:             j['logout_at_str'],
        logoutType:              j['logout_type'],
        durationSecondsDisplay:  j['duration_seconds_display'] != null
            ? (j['duration_seconds_display'] as num).toInt()
            : null,
        isActive: j['is_active'] ?? false,
      );
}

class AuditLogResult {
  final List<AuditLogRow> rows;
  final int total;
  final int page;
  final int limit;

  const AuditLogResult({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

class SaUserAuditLogService {
  static final _instance = SaUserAuditLogService._();
  factory SaUserAuditLogService() => _instance;
  SaUserAuditLogService._();

  final _auth = AuthService();

  Future<AuditLogResult> fetchRows({
    int? userId,
    String? dateFrom,
    String? dateTo,
    String logoutType = 'all',
    String sortBy = 'login_desc',
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await _auth.getAuthHeader();
    final params = <String, String>{
      if (userId != null) 'user_id': userId.toString(),
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (logoutType != 'all') 'logout_type': logoutType,
      'sort_by': sortBy,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse('${AppConfig.apiSa}/user_audit_log')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return AuditLogResult(
        rows: (data['rows'] as List)
            .map((e) => AuditLogRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: data['total'] ?? 0,
        page:  data['page']  ?? page,
        limit: data['limit'] ?? limit,
      );
    }
    throw Exception('fetchRows: ${resp.statusCode}');
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
        Uri.parse('${AppConfig.apiSa}/user_audit_log/users'),
        headers: headers);
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
    }
    throw Exception('fetchUsers: ${resp.statusCode}');
  }
}
