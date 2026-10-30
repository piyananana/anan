import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

// บรรทัดที่มีบัญชี (กระทบยอด / ซื้อ / ต้นทุน / รายการบัญชี) จาก computeClosing ฝั่ง backend
class ImClosingAccountLine {
  final int accountId;
  final String accountCode;
  final String accountNameTh;
  final String accountNameEn;
  final Map<String, dynamic> raw;
  const ImClosingAccountLine({required this.accountId, required this.accountCode, required this.accountNameTh, required this.accountNameEn, required this.raw});

  factory ImClosingAccountLine.fromJson(Map<String, dynamic> j) => ImClosingAccountLine(
        accountId: j['account_id'] as int,
        accountCode: j['account_code'] ?? '',
        accountNameTh: j['account_name_th'] ?? '',
        accountNameEn: j['account_name_en'] ?? '',
        raw: j,
      );

  String name(bool isEnglish) => isEnglish && accountNameEn.isNotEmpty ? accountNameEn : accountNameTh;
  double num(String key) => _toDouble(raw[key]);
}

// ตัวอย่างการปิดงวดแบบปรับยอดให้ตรง — beginning = ยอด GL บัญชีสต็อกก่อนปรับ, ending = มูลค่าสต็อก ณ วันสิ้นงวด
class ImPeriodClosingPreview {
  final int periodId;
  final double beginningValue;
  final double purchasesValue;
  final double endingValue;
  final double cogsValue;
  final double inventoryAdjustment;
  final double subledgerCogs;
  final double residualCogs;
  final List<ImClosingAccountLine> reconciliation;
  final List<ImClosingAccountLine> journal;
  final List<String> errors;
  final List<String> warnings;
  final bool alreadyPosted;

  const ImPeriodClosingPreview({
    required this.periodId,
    required this.beginningValue,
    required this.purchasesValue,
    required this.endingValue,
    required this.cogsValue,
    required this.inventoryAdjustment,
    required this.subledgerCogs,
    required this.residualCogs,
    required this.reconciliation,
    required this.journal,
    required this.errors,
    required this.warnings,
    required this.alreadyPosted,
  });

  factory ImPeriodClosingPreview.fromJson(Map<String, dynamic> json) {
    List<ImClosingAccountLine> lines(String k) =>
        ((json[k] ?? []) as List).map((e) => ImClosingAccountLine.fromJson(e as Map<String, dynamic>)).toList();
    return ImPeriodClosingPreview(
      periodId: json['period_id'],
      beginningValue: _toDouble(json['beginning_value']),
      purchasesValue: _toDouble(json['purchases_value']),
      endingValue: _toDouble(json['ending_value']),
      cogsValue: _toDouble(json['cogs_value']),
      inventoryAdjustment: _toDouble(json['inventory_adjustment']),
      subledgerCogs: _toDouble(json['subledger_cogs']),
      residualCogs: _toDouble(json['residual_cogs']),
      reconciliation: lines('reconciliation'),
      journal: lines('journal'),
      errors: ((json['errors'] ?? []) as List).map((e) => e.toString()).toList(),
      warnings: ((json['warnings'] ?? []) as List).map((e) => e.toString()).toList(),
      alreadyPosted: json['already_posted'] ?? false,
    );
  }
}

class ImPeriodClosingService {
  final String baseUrl = AppConfig.apiIm;
  final AuthService authService = AuthService();

  Future<ImPeriodClosingPreview> fetchPreview(int periodId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(Uri.parse('$baseUrl/im_period_closing/$periodId/preview'), headers: headers);
    if (response.statusCode == 200) {
      return ImPeriodClosingPreview.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Unauthorized. Please login again.');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'โหลดตัวอย่างการปิดงวดล้มเหลว');
    }
  }

  Future<void> confirmClose(int periodId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(Uri.parse('$baseUrl/im_period_closing/$periodId/confirm'), headers: headers);
    if (response.statusCode != 200) {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'ปิดงวดสต็อกล้มเหลว');
    }
  }
}
