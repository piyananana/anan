// lib/sa/services/sa_login_branding_service.dart — ตั้งค่าหน้าล็อกอิน (ใช้ร่วมทุกฐานข้อมูล)
// GET ไม่ต้องล็อกอิน (หน้าล็อกอินเรียกก่อนเลือกฐานข้อมูล), PUT เฉพาะผู้พัฒนาระบบ
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/app_config.dart';
import 'sa_auth_service.dart';
import '../utils/sa_favicon.dart';

class LoginBrandingHistory {
  final DateTime? at;
  final String by;
  final String action;
  const LoginBrandingHistory(this.at, this.by, this.action);
}

class LoginBranding {
  final String layout; // 'A' | 'B'
  final String nameTh, nameEn, taglineTh, taglineEn;
  final String? logoUrl; // URL เต็มพร้อม cache-bust (null = ใช้โลโก้มาตรฐานของแอป)
  final String? backgroundUrl; // null = พื้นหลังไล่สีเขียว-ทอง
  final DateTime? updatedAt;
  final String? updatedBy;
  final List<LoginBrandingHistory> history;

  const LoginBranding({
    this.layout = 'A',
    this.nameTh = 'ANAN System',
    this.nameEn = 'ANAN System',
    this.taglineTh = 'ระบบบริหารบัญชีและการเงินครบวงจร สำหรับธุรกิจไทย',
    this.taglineEn = 'Integrated accounting & finance for Thai businesses',
    this.logoUrl,
    this.backgroundUrl,
    this.updatedAt,
    this.updatedBy,
    this.history = const [],
  });

  String name(bool isEnglish) => isEnglish ? nameEn : nameTh;
  String tagline(bool isEnglish) => isEnglish ? taglineEn : taglineTh;

  factory LoginBranding.fromJson(Map<String, dynamic> j) {
    final updated = DateTime.tryParse(j['updated_at']?.toString() ?? '')?.toLocal();
    final v = updated?.millisecondsSinceEpoch ?? 0;
    String? url(dynamic p) => (p == null || p.toString().isEmpty) ? null : '${AppConfig.baseHost}$p?v=$v';
    return LoginBranding(
      layout: j['layout'] == 'B' ? 'B' : 'A',
      nameTh: j['name_th']?.toString() ?? 'ANAN System',
      nameEn: j['name_en']?.toString() ?? 'ANAN System',
      taglineTh: j['tagline_th']?.toString() ?? '',
      taglineEn: j['tagline_en']?.toString() ?? '',
      logoUrl: url(j['logo_url']),
      backgroundUrl: url(j['background_url']),
      updatedAt: updated,
      updatedBy: j['updated_by']?.toString(),
      history: ((j['history'] as List?) ?? const [])
          .map((h) => LoginBrandingHistory(
                DateTime.tryParse(h['at']?.toString() ?? '')?.toLocal(),
                h['by']?.toString() ?? '',
                h['action']?.toString() ?? '',
              ))
          .toList(),
    );
  }
}

/// ไฟล์รูปที่เลือกจากเครื่อง (ยังไม่อัปโหลด)
class BrandingImage {
  final Uint8List bytes;
  final String name;
  const BrandingImage(this.bytes, this.name);
  String get mime => name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}

class LoginBrandingService {
  static final LoginBrandingService _instance = LoginBrandingService._();
  factory LoginBrandingService() => _instance;
  LoginBrandingService._();

  LoginBranding? cached; // ค่าล่าสุดที่โหลด (หน้าหลักใช้โลโก้ระบบแทนโลโก้บริษัทเมื่อบริษัทไม่มีโลโก้)

  // เก็บค่าล่าสุด + ไอคอนแท็บเบราว์เซอร์ใช้โลโก้ระบบ (ไม่มีโลโก้ = favicon ANAN มาตรฐาน)
  LoginBranding _apply(LoginBranding b) {
    cached = b;
    setFavicon(b.logoUrl);
    return b;
  }

  Future<LoginBranding> fetch() async {
    final res = await http.get(Uri.parse('${AppConfig.apiSa}/login_branding'));
    if (res.statusCode != 200) throw Exception('Failed to load login settings (${res.statusCode})');
    return _apply(LoginBranding.fromJson(jsonDecode(res.body) as Map<String, dynamic>));
  }

  Future<LoginBranding> save({
    required String layout,
    required String nameTh,
    required String nameEn,
    required String taglineTh,
    required String taglineEn,
    BrandingImage? logo,
    BrandingImage? background,
    bool removeLogo = false,
    bool removeBackground = false,
    bool reset = false,
  }) async {
    final req = http.MultipartRequest('PUT', Uri.parse('${AppConfig.apiSa}/login_branding'));
    final headers = await AuthService().getAuthHeader();
    headers.remove('Content-Type'); // ให้ MultipartRequest ใส่ boundary เอง
    req.headers.addAll(headers);
    if (reset) {
      req.fields['reset'] = '1';
    } else {
      req.fields.addAll({
        'layout': layout,
        'name_th': nameTh,
        'name_en': nameEn,
        'tagline_th': taglineTh,
        'tagline_en': taglineEn,
        if (removeLogo) 'remove_logo': '1',
        if (removeBackground) 'remove_background': '1',
      });
      for (final (field, img) in [('logo', logo), ('background', background)]) {
        if (img == null) continue;
        req.files.add(http.MultipartFile.fromBytes(field, img.bytes, filename: img.name, contentType: MediaType.parse(img.mime)));
      }
    }
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        msg = (jsonDecode(body) as Map)['message']?.toString() ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
    return _apply(LoginBranding.fromJson(jsonDecode(body) as Map<String, dynamic>));
  }
}
