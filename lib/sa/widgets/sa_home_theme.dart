// lib/sa/widgets/sa_home_theme.dart — สีและส่วนประกอบที่ใช้ร่วมกันของหน้าหลัก (แถบเมนูซ้าย, แถบบน, หน้าแรก)
// แบบ A ที่ผู้ใช้เลือก 2026-11-24: แถบซ้ายเขียวเข้ม + ทอง, พื้นที่ทำงานสีอ่อน
import 'package:flutter/material.dart';
import '../models/sa_menu.dart';

class HomeColors {
  static const brand = Color(0xFF0F4A36);
  static const brand2 = Color(0xFF0B3A2A); // พื้นแถบซ้าย
  static const brandInk = Color(0xFFE8F3EC); // ตัวอักษรบนแถบซ้าย
  static const brandDim = Color(0xFF9FC0B0); // ตัวอักษรรองบนแถบซ้าย
  static const brandGroup = Color(0xFF79A08E); // หัวกลุ่มเมนูย่อย
  static const gold = Color(0xFFE0A526);
  static const goldSoft = Color(0xFFFFF4DA);
  static const goldLine = Color(0xFFF1D58F);
  static const selText = Color(0xFFFFE2A3); // เมนูที่เปิดอยู่
  static const appBg = Color(0xFFF3F5F4);
  static const card = Colors.white;
  static const line = Color(0xFFE1E6E3);
  static const ink = Color(0xFF1B2420);
  static const ink2 = Color(0xFF55625B);
  static const ink3 = Color(0xFF8B968F);
  static const hover = Color(0xFFEAF2ED);
  static const amber = Color(0xFF8A5A00);
  static const amberSoft = Color(0xFFFFF3C4);
  static const red = Color(0xFFC62828);
}

/// รหัสโมดูลสั้นของเมนู — จากวงเล็บในชื่ออังกฤษ "(GL)" ก่อน, ไม่มีใช้ตัวแรกของคำภาษาอังกฤษ, ไม่มีชื่ออังกฤษใช้ 2 ตัวแรกของชื่อไทย
String homeModuleCode(Menu m) {
  final re = RegExp(r'\(([A-Z]{2,4})\)');
  final hit = re.firstMatch(m.menuNameEn) ?? re.firstMatch(m.menuName);
  if (hit != null) return hit.group(1)!;
  // ไม่มีชื่ออังกฤษ: ใช้ข้อความอังกฤษในวงเล็บของชื่อไทย เช่น "ระบบจัดการเงินมัดจำ (Deposit Management)"
  var en = m.menuNameEn.trim();
  if (en.isEmpty) en = RegExp(r'\(([A-Za-z][A-Za-z ,&]+)\)').firstMatch(m.menuName)?.group(1) ?? '';
  final lower = en.toLowerCase();
  if (lower.startsWith('procurement') || lower.startsWith('purchase order')) return 'PO';
  if (lower.startsWith('sale management') || lower.startsWith('sales management')) return 'SO';
  if (lower.startsWith('manufacturing')) return 'MO';
  const skip = {'and', 'of', 'the', '&', 'management', 'system'};
  final words = en.split(RegExp(r'[\s,]+')).where((w) => w.isNotEmpty && !skip.contains(w.toLowerCase())).toList();
  if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase();
  if (words.length == 1) return words[0].substring(0, words[0].length.clamp(1, 2)).toUpperCase();
  return m.menuName.characters.take(2).toString();
}

/// สีป้ายรหัสโมดูล (ตัวอักษร, พื้น)
(Color, Color) homeModuleColors(String code) {
  switch (code) {
    case 'GL':
      return (const Color(0xFF1E4F8F), const Color(0xFFE3EEFA));
    case 'AR':
      return (const Color(0xFF1E6B3A), const Color(0xFFE6F4EA));
    case 'AP':
      return (const Color(0xFFB23A2C), const Color(0xFFFDECEA));
    case 'CM':
      return (const Color(0xFF0F5C5C), const Color(0xFFE8F3F2));
    case 'IM':
      return (const Color(0xFF8A5A00), const Color(0xFFFFF3C4));
    case 'PO':
    case 'PM':
      return (const Color(0xFF5B3B9A), const Color(0xFFEFE8FB));
    case 'SO':
    case 'SM':
      return (const Color(0xFF9A2F62), const Color(0xFFFDE9F2));
    case 'MO':
    case 'MOM':
      return (const Color(0xFF37474F), const Color(0xFFECEFF1));
    default:
      return (HomeColors.brand, HomeColors.hover);
  }
}

/// ป้ายรหัสโมดูลสี่เหลี่ยมมุมมน
class HomeModuleBadge extends StatelessWidget {
  final String code;
  final double width;
  final double height;
  final double fontSize;
  const HomeModuleBadge(this.code, {super.key, this.width = 30, this.height = 30, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = homeModuleColors(code);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 4)),
      child: Text(code, style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700)),
    );
  }
}

/// ตัวช่วยโครงสร้างเมนู: รายการแบน (_allMenus) → ลูกของแต่ละ id, เส้นทาง, โมดูล
class HomeMenuIndex {
  final Map<int, Menu> byId = {};
  final Map<int?, List<Menu>> children = {};
  late final List<Menu> modules;
  int? rootId; // โฟลเดอร์รากเดียว (เช่น "ANAN System") — ไม่แสดงในเส้นทาง

  HomeMenuIndex(List<Menu> menus) {
    for (final m in menus) {
      byId[m.id] = m;
      (children[m.parentId] ??= []).add(m);
    }
    for (final l in children.values) {
      l.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final top = children[null] ?? const <Menu>[];
    if (top.length == 1 && top.first.menuType == 'folder') {
      rootId = top.first.id;
      modules = children[rootId] ?? const <Menu>[];
    } else {
      modules = top;
    }
  }

  List<Menu> childrenOf(int? id) => children[id] ?? const <Menu>[];

  /// เมนูต้นทางจากโมดูลลงไป (ไม่รวมโฟลเดอร์ราก)
  List<Menu> pathOf(Menu m) {
    final path = <Menu>[];
    Menu? cur = m;
    while (cur != null && cur.id != rootId) {
      path.insert(0, cur);
      cur = cur.parentId == null ? null : byId[cur.parentId];
    }
    return path;
  }

  /// โมดูล (ชั้นบนสุดใต้ราก) ของเมนู
  Menu? moduleOf(Menu m) {
    final p = pathOf(m);
    return p.isEmpty ? null : p.first;
  }

  bool isLeaf(Menu m) => m.menuType != 'folder';

  Iterable<Menu> get leaves => byId.values.where(isLeaf);
}
