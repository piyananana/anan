// lib/sa/utils/sa_menu_theme.dart
// สีธีมของเมนู (user 2026-11-27) — ตั้งที่หน้าจอจัดการเมนู (sa_menu.theme_color) เก็บเป็นรหัสสี ไม่ใช่ hex
// NULL = ตามเมนูแม่ (ไล่ขึ้นไปจนเจอ) · บนสุดไม่ได้ตั้ง = teal (สีเดิมของ IM) — ต้องตรงกับ THEME_KEYS ใน saMenuController.js
// หน้าจอที่ใช้ชุด IM (ImMasterShell / ImMasterKit) อ่านสีจาก ScreenTheme.of(context) อัตโนมัติ
import 'package:flutter/material.dart';
import '../models/sa_menu.dart';
import 'sa_menu_scope.dart';

class ScreenThemeColors {
  final String key;
  final String th, en;
  final String fitTh, fitEn; // เหมาะกับงานแบบไหน
  final Color bar; // AppBar
  final Color strip; // แถบหัวด้านขวา (อ่อนกว่า AppBar ราว 30%)
  final Color soft; // พื้นอ่อน: ตัวเลขสรุป / ลิงก์ข้ามส่วนที่เลือก
  final Color ink; // ตัวอักษร/ปุ่มสีหลักบนพื้นขาว
  const ScreenThemeColors(this.key, this.th, this.en, this.fitTh, this.fitEn, this.bar, this.strip, this.soft, this.ink);

  String name(bool isEnglish) => isEnglish ? en : th;
  String fit(bool isEnglish) => isEnglish ? fitEn : fitTh;
}

class ScreenTheme {
  static const defaultKey = 'teal';

  static const themes = <ScreenThemeColors>[
    ScreenThemeColors('teal', 'เขียวหัวเป็ด', 'Teal', 'สีเดิมของ IM', 'Original IM colour', Color(0xFF0F6E6E), Color(0xFF4DA3A3), Color(0xFFE8F3F2), Color(0xFF0F5C5C)),
    ScreenThemeColors('blue', 'น้ำเงิน', 'Blue', 'ข้อมูลหลัก', 'Master data', Color(0xFF1E3A5F), Color(0xFF4A6A94), Color(0xFFE6EDF6), Color(0xFF1E3A5F)),
    ScreenThemeColors('purple', 'ม่วง', 'Purple', 'ธุรกรรม / เอกสาร', 'Transactions', Color(0xFF4B2E83), Color(0xFF7A5FB0), Color(0xFFEEE8F8), Color(0xFF4B2E83)),
    ScreenThemeColors('slate', 'เทาถ่าน', 'Charcoal', 'รายงาน', 'Reports', Color(0xFF37474F), Color(0xFF66777F), Color(0xFFECEFF1), Color(0xFF37474F)),
    ScreenThemeColors('plum', 'ม่วงแดง', 'Plum', 'ตั้งค่า', 'Setup', Color(0xFF6A2C5A), Color(0xFF9A5A88), Color(0xFFF6E9F2), Color(0xFF6A2C5A)),
    ScreenThemeColors('brown', 'น้ำตาล', 'Brown', 'ประมวลผล', 'Processing', Color(0xFF5D4037), Color(0xFF8D6E63), Color(0xFFF3ECE8), Color(0xFF5D4037)),
    ScreenThemeColors('petrol', 'ฟ้าปิโตรเลียม', 'Petrol blue', 'สอบถาม / แดชบอร์ด', 'Inquiry / dashboards', Color(0xFF0D4F6B), Color(0xFF3F86A6), Color(0xFFE4F0F5), Color(0xFF0D4F6B)),
    ScreenThemeColors('indigo', 'คราม', 'Indigo', 'อนุมัติ', 'Approvals', Color(0xFF283593), Color(0xFF5C6BC0), Color(0xFFE8EAF6), Color(0xFF283593)),
    ScreenThemeColors('wine', 'เลือดหมู', 'Wine', 'ปิดงวด / ล้างข้อมูล', 'Period close / data reset', Color(0xFF7A2E3A), Color(0xFFA85F69), Color(0xFFF7E9EB), Color(0xFF7A2E3A)),
    ScreenThemeColors('forest', 'เขียวป่า', 'Forest green', 'ใกล้สีเมนูหลัก ใช้เท่าที่จำเป็น', 'Close to the main menu green', Color(0xFF2E5E3A), Color(0xFF5E8E6A), Color(0xFFE8F1EA), Color(0xFF2E5E3A)),
  ];

  static ScreenThemeColors byKey(String? key) => themes.firstWhere((t) => t.key == key, orElse: () => themes.first);
  static bool isKey(String? key) => key != null && themes.any((t) => t.key == key);

  // เมนูทั้งหมดที่รู้จัก (หน้าแรกตั้งจากเมนูของผู้ใช้, หน้าจัดการเมนูตั้งจากเมนูทั้งหมด) — ใช้ไล่หาสีของเมนูแม่
  static final Map<int, Menu> _registry = {};
  static void register(Iterable<Menu> menus) {
    for (final m in menus) {
      _registry[m.id] = m;
    }
  }

  /// สีที่ใช้จริงของเมนู + เมนูที่ตั้งสีไว้ (null = ค่าเริ่มต้นระบบ)
  static (ScreenThemeColors, Menu?) resolve(Menu? menu, {Map<int, Menu>? lookup}) {
    final map = lookup ?? _registry;
    var m = menu == null ? null : (map[menu.id] ?? menu);
    final seen = <int>{};
    while (m != null && seen.add(m.id)) {
      if (isKey(m.themeColor)) return (byKey(m.themeColor), m);
      m = m.parentId == null ? null : map[m.parentId];
    }
    return (byKey(defaultKey), null);
  }

  static ScreenThemeColors effectiveFor(Menu? menu) => resolve(menu).$1;

  /// สีของหน้าจอที่กำลังแสดง (จากเมนูที่เปิดหน้านี้) — ไม่ได้เปิดจากเมนู = teal
  static ScreenThemeColors of(BuildContext context) => effectiveFor(MenuScope.of(context));
}
