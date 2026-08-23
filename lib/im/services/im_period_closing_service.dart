import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class ImPeriodClosingPreview {
  final int periodId;
  final double beginningValue;
  final double purchasesValue;
  final double endingValue;
  final double cogsValue;
  final bool alreadyPosted;

  const ImPeriodClosingPreview({
    required this.periodId,
    required this.beginningValue,
    required this.purchasesValue,
    required this.endingValue,
    required this.cogsValue,
    required this.alreadyPosted,
  });

  factory ImPeriodClosingPreview.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return ImPeriodClosingPreview(
      periodId: json['period_id'],
      beginningValue: toDouble(json['beginning_value']),
      purchasesValue: toDouble(json['purchases_value']),
      endingValue: toDouble(json['ending_value']),
      cogsValue: toDouble(json['cogs_value']),
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
