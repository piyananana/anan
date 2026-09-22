// lib/sa/services/sa_attachment_service.dart — ไฟล์แนบท้ายรายการแบบ generic ใช้ร่วมกันได้ทุกโมดูล
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/app_config.dart';
import 'sa_auth_service.dart';
import '../models/sa_attachment.dart';

const _mimeTypeByExt = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'pdf': 'application/pdf',
};

class AttachmentService {
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  Future<List<SaAttachment>> fetchByEntity(String moduleCode, int entityId) async {
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/attachment').replace(queryParameters: {
      'module_code': moduleCode,
      'entity_id': entityId.toString(),
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).map((e) => SaAttachment.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('โหลดไฟล์แนบล้มเหลว: ${response.statusCode}');
  }

  Future<Map<int, List<SaAttachment>>> fetchByEntities(String moduleCode, List<int> entityIds) async {
    if (entityIds.isEmpty) return {};
    final headers = await authService.getAuthHeader();
    final uri = Uri.parse('$baseUrl/attachment/batch').replace(queryParameters: {
      'module_code': moduleCode,
      'entity_ids': entityIds.join(','),
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) throw Exception('โหลดไฟล์แนบล้มเหลว: ${response.statusCode}');
    final rows = (json.decode(response.body) as List).map((e) => SaAttachment.fromJson(e as Map<String, dynamic>)).toList();
    final grouped = <int, List<SaAttachment>>{};
    for (final r in rows) {
      grouped.putIfAbsent(r.entityId, () => []).add(r);
    }
    return grouped;
  }

  Future<SaAttachment> upload(String moduleCode, int entityId, PlatformFile file) async {
    if (file.bytes == null) throw Exception('ไม่พบข้อมูลไฟล์');
    final headers = await authService.getAuthHeader();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/attachment'));
    request.headers.addAll(headers);
    request.fields['module_code'] = moduleCode;
    request.fields['entity_id'] = entityId.toString();
    final ext = (file.extension ?? '').toLowerCase();
    request.files.add(http.MultipartFile.fromBytes(
      'file', file.bytes!,
      filename: file.name,
      contentType: MediaType.parse(_mimeTypeByExt[ext] ?? 'application/octet-stream'),
    ));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 201) return SaAttachment.fromJson(json.decode(body));
    final err = json.decode(body);
    throw Exception(err['message'] ?? 'อัปโหลดไฟล์แนบล้มเหลว');
  }

  Future<void> delete(int id) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(Uri.parse('$baseUrl/attachment/$id'), headers: headers);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('ลบไฟล์แนบล้มเหลว: ${response.statusCode}');
    }
  }
}
