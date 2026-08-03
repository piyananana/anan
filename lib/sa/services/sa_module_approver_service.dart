// lib/sa/services/sa_module_approver_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../models/sa_module_approver.dart';
import 'sa_auth_service.dart';

class SaModuleApproverService {
  final String _base = AppConfig.apiSa;
  final AuthService _auth = AuthService();

  // ── ผูกกับ menu_id — ใช้โดยหน้าจอตั้งค่าผู้อนุมัติ (เลือกเมนู → ดู/แก้ลำดับผู้อนุมัติ) ──
  // คิวผู้อนุมัติ sync มาจากสิทธิ์ "อนุมัติ" (can_approve) ที่ให้ไว้ในหน้าจอสิทธิ์เมนูผู้ใช้โดยอัตโนมัติ
  // docType ไม่ระบุ = คิวระดับเมนู; ระบุ = คิวเฉพาะประเภทเอกสารนั้น (สำหรับเมนูที่ uses_doc_type)
  Future<List<SaModuleApprover>> fetchByMenu(int menuId, {String? docType}) async {
    final headers = await _auth.getAuthHeader();
    final uri = Uri.parse('$_base/sa_module_approver/by_menu/$menuId')
        .replace(queryParameters: docType != null ? {'doc_type': docType} : null);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List).map((e) => SaModuleApprover.fromJson(e)).toList();
    }
    throw Exception('โหลดรายชื่อผู้อนุมัติล้มเหลว: ${resp.statusCode}');
  }

  // approvers เรียงตามลำดับอนุมัติใหม่ (index 0 = ลำดับที่ 1); isActive ใช้ "งดอนุมัติ" คนนั้นชั่วคราว
  // ส่ง signatureImage/approvalLimit ของแต่ละคนไปบันทึกพร้อมกันด้วย
  Future<void> reorder(int menuId, List<SaModuleApprover> approvers, {String? docType}) async {
    final headers = await _auth.getAuthHeader();
    final resp = await http.put(
      Uri.parse('$_base/sa_module_approver/reorder'),
      headers: headers,
      body: jsonEncode({
        'menu_id': menuId,
        'doc_type': docType,
        'items': approvers
            .map((a) => {
                  'approver_user_id': a.approverUserId,
                  'is_active': a.isActive,
                  'signature_image': a.signatureImage,
                  'approval_limit': a.approvalLimit,
                })
            .toList(),
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  String _extractMessage(String body) {
    try { return jsonDecode(body)['message'] ?? body; } catch (_) { return body; }
  }
}
