// lib/sa/services/sa_pending_approval_service.dart — รวมรายการรออนุมัติจากทุกโมดูลที่มี workflow คิวจริง เรียก
// endpoint my_pending ของแต่ละโมดูลพร้อมกัน แล้ว normalize เป็น PendingApprovalItem เดียวกันสำหรับกระดิ่งแจ้งเตือน
// ที่ home screen — โมดูลไหน fetch ไม่สำเร็จ (เช่น ไม่มีสิทธิ์) ให้ข้ามไปเงียบๆ ไม่ทำให้รายการโมดูลอื่นหาย
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'sa_auth_service.dart';
import '../models/sa_pending_approval.dart';
import '../../utils/date_utils.dart';

class PendingApprovalService {
  final AuthService _auth = AuthService();

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<List<PendingApprovalItem>> fetchAll() async {
    final results = await Future.wait([
      _fetchApPaymentRun(),
      _fetchApTransaction(),
      _fetchPrTransaction(),
    ]);
    final items = results.expand((x) => x).toList();
    items.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return items;
  }

  Future<List<PendingApprovalItem>> _fetchApPaymentRun() async {
    try {
      final headers = await _auth.getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiAp}/ap_payment_run/my_pending'), headers: headers);
      if (resp.statusCode != 200) return [];
      return (jsonDecode(resp.body) as List).map((e) {
        final m = e as Map<String, dynamic>;
        final runNo = m['run_number'] ?? '';
        return PendingApprovalItem(
          module: 'ap_payment_run',
          id: m['id'],
          docNo: runNo,
          date: parseLocalDateNullable(m['run_date']),
          titleTh: 'ขออนุมัติจ่าย $runNo',
          titleEn: 'Payment Run Approval $runNo',
          submittedBy: m['created_by'],
          amount: _toDouble(m['total_amount_lc']),
          targetPath: 'ApPaymentRunScreen',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PendingApprovalItem>> _fetchApTransaction() async {
    try {
      final headers = await _auth.getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiAp}/ap_transaction/my_pending'), headers: headers);
      if (resp.statusCode != 200) return [];
      return (jsonDecode(resp.body) as List).map((e) {
        final m = e as Map<String, dynamic>;
        final docNo = m['doc_no'] ?? '';
        final docNameTh = m['doc_name_thai'] ?? 'เอกสารเจ้าหนี้';
        final docNameEn = m['doc_name_eng'] ?? 'AP Document';
        final vendorName = (m['vendor_name_th'] ?? '').toString();
        return PendingApprovalItem(
          module: 'ap_transaction',
          id: m['id'],
          docNo: docNo,
          date: parseLocalDateNullable(m['doc_date']),
          titleTh: '$docNameTh $docNo${vendorName.isNotEmpty ? ' — $vendorName' : ''}',
          titleEn: '$docNameEn $docNo',
          submittedBy: m['submitted_by'],
          amount: _toDouble(m['total_amount_lc']),
          targetPath: 'ApTransactionScreen',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PendingApprovalItem>> _fetchPrTransaction() async {
    try {
      final headers = await _auth.getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiPo}/pr_transaction/my_pending'), headers: headers);
      if (resp.statusCode != 200) return [];
      return (jsonDecode(resp.body) as List).map((e) {
        final m = e as Map<String, dynamic>;
        final docNo = m['doc_no'] ?? '';
        return PendingApprovalItem(
          module: 'pr_transaction',
          id: m['id'],
          docNo: docNo,
          date: parseLocalDateNullable(m['doc_date']),
          titleTh: 'ใบขอซื้อ $docNo',
          titleEn: 'Purchase Requisition $docNo',
          submittedBy: m['submitted_by'],
          amount: _toDouble(m['total_value_lc']),
          targetPath: 'PrTransactionScreen',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
