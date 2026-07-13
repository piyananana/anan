// lib/cm/services/cm_period_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';

class CmPeriodService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  /// Returns period info for [date], or null if no period found.
  /// Map keys: id, period_name, cm_status, period_start_date, period_end_date
  static Future<Map<String, dynamic>?> getPeriodStatus(DateTime date) async {
    try {
      final headers = await AuthService().getAuthHeader();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final resp = await http.get(
        Uri.parse('${AppConfig.apiGl}/gl_posting_period/cm_check')
            .replace(queryParameters: {'date': dateStr}),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (data['cm_status'] == null) return null;
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Returns true if CM posting is allowed (period cm_status == 'OPEN').
  /// Shows a SnackBar on [context] if not allowed.
  static Future<bool> canPost(BuildContext context, DateTime date) async {
    Map<String, dynamic>? period;
    try {
      period = await getPeriodStatus(date);
    } catch (_) {
      return true; // network error: don't block
    }

    if (period == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ไม่พบงวดบัญชีสำหรับวันที่ ${_dateFmt.format(date)}'),
          backgroundColor: Colors.red.shade700,
        ));
      }
      return false;
    }

    final cmStatus = period['cm_status'] as String? ?? 'OPEN';
    if (cmStatus == 'OPEN') return true;

    final label = cmStatus == 'LOCKED' ? 'ล็อค (LOCKED)' : 'ปิด (CLOSED)';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('งวดบัญชี CM "${period['period_name']}" มีสถานะ$label — ไม่สามารถบันทึกรายการได้'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ));
    }
    return false;
  }
}
