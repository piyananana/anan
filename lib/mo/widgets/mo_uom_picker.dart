// lib/mo/widgets/mo_uom_picker.dart — เลือกหน่วยในสูตรการผลิต/ใบสั่งผลิต
import 'package:flutter/material.dart';

import '../../im/models/im_item.dart';
import '../../im/services/im_item_service.dart';

// หน่วยที่เลือกได้ในสูตรการผลิต/ใบสั่งผลิต = หน่วยของสินค้าที่อนุญาตให้ใช้ผลิต (หน่วยหลัก + หน่วยของสินค้า + อัตรามาตรฐาน)
// จาก GET /im_item/:id/uoms?purpose=PRODUCTION — ไม่ใช่ทุกหน่วยในระบบ (backend ตรวจซ้ำตอนบันทึก)
Future<ImItemUomOption?> pickProductionUom(BuildContext context, int? itemId, bool isEnglish) async {
  final messenger = ScaffoldMessenger.of(context);
  if (itemId == null) {
    messenger.showSnackBar(SnackBar(content: Text(isEnglish ? 'Select the item first' : 'กรุณาเลือกสินค้าก่อน')));
    return null;
  }
  ImItemUoms u;
  try {
    u = await ImItemService().fetchItemUoms(itemId, purpose: 'PRODUCTION');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return null;
  }
  if (!context.mounted) return null;
  final base = u.units.where((o) => o.isBase).map((o) => o.displayName(isEnglish)).firstOrNull ?? '';
  String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  return showDialog<ImItemUomOption>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text(isEnglish ? 'Select unit' : 'เลือกหน่วย'),
      children: [
        for (final o in u.units)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, o),
            child: Text(o.isBase
                ? '${o.uomCode} — ${o.displayName(isEnglish)}'
                : '${o.uomCode} — ${o.displayName(isEnglish)} (= ${fmt(o.factor)} $base)'),
          ),
      ],
    ),
  );
}
