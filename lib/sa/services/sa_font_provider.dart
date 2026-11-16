import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ฟอนต์หลักของระบบ — ตั้งค่าที่หน้าข้อมูลบริษัท (sa_company.ui_font) ใช้กับทุกหน้าจอ (ไม่รวม PDF)
/// จำค่าล่าสุดไว้ในเครื่อง เพื่อให้หน้า login / ตอนเปิดแอปใช้ฟอนต์เดิมทันที ก่อนโหลดข้อมูลบริษัท
/// ขนาดตัวอักษร (textScale) เป็นค่าของผู้ใช้แต่ละเครื่อง ไม่ใช่ค่าของบริษัท — เลือกที่ปุ่ม Aa บนแถบด้านบน
class FontProvider extends ChangeNotifier {
  static final FontProvider _instance = FontProvider._();
  factory FontProvider() => _instance;
  FontProvider._() {
    _loadCached();
  }

  static const String defaultFont = 'tahoma';
  static const String _prefKey = 'app_ui_font';
  static const String _scaleKey = 'app_ui_text_scale';

  /// ขนาดตัวอักษรที่เลือกได้ (เท่าของขนาดปกติ)
  static const List<double> scales = [0.9, 1.0, 1.1, 1.25];

  double _textScale = 1.0;
  double get textScale => _textScale;

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
      final scale = prefs.getDouble(_scaleKey) ?? 1.0;
      final s = scales.contains(scale) ? scale : 1.0;
      if (cached != _fontFamily || s != _textScale) {
        _fontFamily = cached;
        _textScale = s;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setTextScale(double scale) async {
    if (!scales.contains(scale) || scale == _textScale) return;
    _textScale = scale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_scaleKey, scale);
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
