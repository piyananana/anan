import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ฟอนต์หลักของระบบ — ตั้งค่าที่หน้าข้อมูลบริษัท (sa_company.ui_font) ใช้กับทุกหน้าจอ (ไม่รวม PDF)
/// จำค่าล่าสุดไว้ในเครื่อง เพื่อให้หน้า login / ตอนเปิดแอปใช้ฟอนต์เดิมทันที ก่อนโหลดข้อมูลบริษัท
class FontProvider extends ChangeNotifier {
  static final FontProvider _instance = FontProvider._();
  factory FontProvider() => _instance;
  FontProvider._() {
    _loadCached();
  }

  static const String defaultFont = 'tahoma';
  static const String _prefKey = 'app_ui_font';

  /// family ต้องตรงกับ pubspec.yaml และ UI_FONTS ใน backend saCompanyController
  static const Map<String, String> fonts = {
    'tahoma': 'Tahoma',
    'IBMPlexSansThai': 'IBM Plex Sans Thai',
  };

  String _fontFamily = defaultFont;
  String get fontFamily => _fontFamily;

  static String normalize(String? font) =>
      (font != null && fonts.containsKey(font)) ? font : defaultFont;

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = normalize(prefs.getString(_prefKey));
      if (cached != _fontFamily) {
        _fontFamily = cached;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> apply(String? font) async {
    final f = normalize(font);
    if (f != _fontFamily) {
      _fontFamily = f;
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, f);
    } catch (_) {}
  }
}
