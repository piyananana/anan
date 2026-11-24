import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'sa_auth_service.dart';

class UserStats {
  final int total;
  final int active;
  final int inactive;
  final int online;
  final int activeOffline;

  const UserStats({
    required this.total,
    required this.active,
    required this.inactive,
    required this.online,
    required this.activeOffline,
  });

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
        total:         j['total']          ?? 0,
        active:        j['active']         ?? 0,
        inactive:      j['inactive']       ?? 0,
        online:        j['online']         ?? 0,
        activeOffline: j['active_offline'] ?? 0,
      );
}

class ModuleSize {
  final String module;
  final int sizeBytes;

  const ModuleSize({required this.module, required this.sizeBytes});

  factory ModuleSize.fromJson(Map<String, dynamic> j) => ModuleSize(
        module:    j['module']     ?? '',
        sizeBytes: j['size_bytes'] ?? 0,
      );
}

class DbSizeInfo {
  final List<ModuleSize> modules;
  final int modulesTotalBytes;
  final int dbTotalBytes;

  const DbSizeInfo({
    required this.modules,
    required this.modulesTotalBytes,
    required this.dbTotalBytes,
  });

  factory DbSizeInfo.fromJson(Map<String, dynamic> j) => DbSizeInfo(
        modules: (j['modules'] as List? ?? [])
            .map((e) => ModuleSize.fromJson(e as Map<String, dynamic>))
            .toList(),
        modulesTotalBytes: j['modules_total_bytes'] ?? 0,
        dbTotalBytes:      j['db_total_bytes']      ?? 0,
      );
}

class SaDashboardService {
  static final SaDashboardService _instance = SaDashboardService._internal();
  factory SaDashboardService() => _instance;
  SaDashboardService._internal();

  final _auth = AuthService();

  Future<UserStats> fetchUserStats() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
      Uri.parse('${AppConfig.apiSa}/dashboard/stats'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return UserStats.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('fetchUserStats: ${resp.statusCode}');
  }

  Future<DbSizeInfo> fetchDbSize() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(
      Uri.parse('${AppConfig.apiSa}/dashboard/db_size'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return DbSizeInfo.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('fetchDbSize: ${resp.statusCode}');
  }

  Future<HomeKpi> fetchHomeKpi() async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.get(Uri.parse('${AppConfig.apiSa}/dashboard/home_kpi'), headers: headers);
    if (resp.statusCode == 200) {
      return HomeKpi.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('fetchHomeKpi: ${resp.statusCode}');
  }
}

/// ตัวเลขสรุปบนหน้าแรก (งานรออนุมัตินับจากรายการกระดิ่งฝั่ง Flutter)
class HomeKpi {
  final int myDrafts;
  final Map<String, int> myDraftsByModule;
  final int soPending, soPartial;
  final int poPending, poPartial;
  final int moActive, moInProgress, moReleased;

  const HomeKpi({
    required this.myDrafts,
    required this.myDraftsByModule,
    required this.soPending,
    required this.soPartial,
    required this.poPending,
    required this.poPartial,
    required this.moActive,
    required this.moInProgress,
    required this.moReleased,
  });

  factory HomeKpi.fromJson(Map<String, dynamic> j) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    final d = (j['my_drafts'] as Map?) ?? const {};
    final so = (j['so_pending'] as Map?) ?? const {};
    final po = (j['po_pending'] as Map?) ?? const {};
    final mo = (j['mo_active'] as Map?) ?? const {};
    return HomeKpi(
      myDrafts: n(d['total']),
      myDraftsByModule: ((d['by_module'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), n(v))),
      soPending: n(so['total']),
      soPartial: n(so['partial']),
      poPending: n(po['total']),
      poPartial: n(po['partial']),
      moActive: n(mo['total']),
      moInProgress: n(mo['in_progress']),
      moReleased: n(mo['released']),
    );
  }
}
