// lib/sa/widgets/sa_doc_appbar_actions.dart — ปุ่มของเอกสารบน AppBar ของหน้าจอเอกสาร (แทนแถบปุ่มด้านล่าง)
//
// ใช้ร่วมกันทุกหน้าจอเอกสารที่เป็นรายการ + รายละเอียด (user-approved 2026-11-22, เริ่มที่ธุรกรรม IM):
//   - หน้าจอแม่สร้าง DocAppBarActions ส่งให้วิดเจ็ตรายละเอียด (พารามิเตอร์ actions:) แล้ววาดใน AppBar
//     ด้วย AnimatedBuilder(animation: actions, builder: (c, _) => actions.build(c, isEnglish)) เฉพาะหน้ารายละเอียด
//   - วิดเจ็ตรายละเอียด implements DocAppBarActionsHost: attach ใน initState/didUpdateWidget, detach ใน dispose,
//     เรียก actions.scheduleRefresh() ทุกครั้งที่ build (สถานะ/กำลังบันทึกเปลี่ยน → ปุ่มบน AppBar วาดใหม่)
//   - ลูกศรย้อนกลับ: actions.isDirty → confirmDiscardChanges() ก่อนกลับหน้ารายการ, ปุ่มรีเฟรชซ่อนในหน้ารายละเอียด
//   - ปุ่มพื้นทึบตัดกับสี AppBar: ปุ่มรองพื้นขาวตัวอักษรสี, ปุ่มหลักพื้นเขียว/แดงขอบขาว, ฟอนต์ตาม theme (หน้าจอบริษัท)
//     จอแคบ (< 900) = ปุ่มหลัก + เมนู ⋮ สำหรับปุ่มรอง
import 'dart:convert';

import 'package:flutter/material.dart';

/// ลายนิ้วมือของข้อมูลที่จะบันทึก (header/บรรทัด ... ที่มี toJson) — เทียบกับค่าตอนโหลดเสร็จเพื่อหาการแก้ไขค้าง
String docFingerprint(Object? value) {
  Object? norm(Object? x) {
    if (x == null || x is num || x is String || x is bool) return x;
    if (x is DateTime) return x.toIso8601String();
    if (x is Iterable) return x.map(norm).toList();
    if (x is Map) return x.map((k, v) => MapEntry('$k', norm(v)));
    try {
      return norm((x as dynamic).toJson());
    } catch (_) {
      return x.toString();
    }
  }

  try {
    return jsonEncode(norm(value));
  } catch (_) {
    return value.toString();
  }
}

abstract class DocAppBarActionsHost {
  bool get mounted;
  /// ปุ่มของเอกสารที่เปิดอยู่ (ใช้ [buildDocBarActions])
  Widget buildAppBarActions(BuildContext context, bool isEnglish);
  /// มีการแก้ไขที่ยังไม่บันทึก
  bool get isDirty;
}

class DocAppBarActions extends ChangeNotifier {
  DocAppBarActionsHost? _host;
  bool _scheduled = false;

  void attach(DocAppBarActionsHost host) => _host = host;
  void detach(DocAppBarActionsHost host) {
    if (identical(_host, host)) _host = null;
  }

  Widget build(BuildContext context, bool isEnglish) =>
      _host?.mounted == true ? _host!.buildAppBarActions(context, isEnglish) : const SizedBox.shrink();

  bool get isDirty => _host?.mounted == true && _host!.isDirty;

  /// เรียกจาก build() ของวิดเจ็ตรายละเอียด — วาดปุ่มบน AppBar ใหม่หลังเฟรมนี้ (ครั้งเดียวต่อเฟรม)
  void scheduleRefresh() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
  }
}

class DocBarAction {
  final String label;
  final VoidCallback? onPressed;
  final Color fg;
  final Color bg;
  final bool primary;
  final String? tooltip;
  const DocBarAction(this.label, this.onPressed, {required this.fg, this.bg = Colors.white, this.primary = false, this.tooltip});

  /// ปุ่มรอง: พื้นขาว ตัวอักษรสี
  factory DocBarAction.secondary(String label, VoidCallback? onPressed, Color fg, {String? tooltip}) =>
      DocBarAction(label, onPressed, fg: fg, tooltip: tooltip);

  /// ปุ่มหลัก: พื้นทึบ (เขียว = บันทึก/Post/อนุมัติ, แดง = ยกเลิก) ตัวอักษรขาว
  factory DocBarAction.primary(String label, VoidCallback? onPressed, Color bg, {String? tooltip}) =>
      DocBarAction(label, onPressed, fg: Colors.white, bg: bg, primary: true, tooltip: tooltip);
}

/// สีมาตรฐานของปุ่มบน AppBar
class DocBarColors {
  static Color get save => Colors.teal[800]!;
  static Color get delete => Colors.red[700]!;
  static Color get reverse => Colors.orange[800]!;
  static Color get neutral => Colors.blueGrey[800]!;
  static Color get post => Colors.green[600]!;
  static Color get voidBg => Colors.red[600]!;
  static Color get submit => Colors.blue[700]!;
}

/// วาดชุดปุ่มบน AppBar — busy = กำลังบันทึก (วงหมุนสีขาว)
Widget buildDocBarActions(BuildContext context, List<DocBarAction> acts, {bool busy = false, required bool isEnglish}) {
  final narrow = MediaQuery.sizeOf(context).width < 900;
  final shown = narrow ? acts.where((x) => x.primary).toList() : acts;
  final menu = narrow ? acts.where((x) => !x.primary).toList() : <DocBarAction>[];
  final menuStyle = Theme.of(context).textTheme.bodyMedium;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    if (busy)
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      ),
    for (final x in shown) Padding(padding: const EdgeInsets.only(left: 6), child: _docBarButton(context, x)),
    if (menu.isNotEmpty)
      PopupMenuButton<int>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        tooltip: isEnglish ? 'More actions' : 'คำสั่งอื่น',
        onSelected: (i) => menu[i].onPressed?.call(),
        itemBuilder: (_) => [
          for (var i = 0; i < menu.length; i++)
            PopupMenuItem<int>(
              value: i,
              enabled: menu[i].onPressed != null,
              child: Text(menu[i].tooltip == null ? menu[i].label : '${menu[i].label} — ${menu[i].tooltip}',
                  style: menuStyle?.copyWith(color: menu[i].onPressed == null ? Colors.grey : menu[i].fg)),
            ),
        ],
      ),
    if (acts.isNotEmpty) const SizedBox(width: 8),
  ]);
}

Widget _docBarButton(BuildContext context, DocBarAction x) {
  final filled = x.bg != Colors.white;
  final btn = ElevatedButton(
    onPressed: x.onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: x.bg,
      foregroundColor: x.fg,
      disabledBackgroundColor: Colors.white24,
      disabledForegroundColor: Colors.white70,
      elevation: 0,
      side: filled ? const BorderSide(color: Colors.white70) : null,
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      visualDensity: VisualDensity.compact,
      // ฟอนต์ตามที่ตั้งไว้ในหน้าจอองค์กร/บริษัท (theme) — TextStyle เปล่าจะตกไปใช้ฟอนต์ระบบ
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    child: Text(x.label),
  );
  return x.tooltip == null ? btn : Tooltip(message: x.tooltip!, child: btn);
}

/// ถามยืนยันก่อนออกจากหน้ารายละเอียดที่มีการแก้ไขค้าง — true = ออกได้
Future<bool> confirmDiscardChanges(BuildContext context, bool isEnglish) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEnglish ? 'Discard changes?' : 'ยกเลิกการแก้ไข?'),
      content: Text(isEnglish
          ? 'This document has unsaved changes. Going back to the list will discard them.'
          : 'เอกสารนี้มีการแก้ไขที่ยังไม่ได้บันทึก ถ้ากลับไปหน้ารายการ การแก้ไขจะหายไป'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Keep editing' : 'แก้ไขต่อ')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
          child: Text(isEnglish ? 'Discard and go back' : 'ไม่บันทึก และกลับ'),
        ),
      ],
    ),
  );
  return ok == true;
}
