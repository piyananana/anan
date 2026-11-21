// lib/im/widgets/im_report_uom_mode_field.dart — หน่วยแสดงผลของรายงานสต็อก (ส่งเป็น uom_mode ให้ backend)
// base = หน่วยหลัก, report = หน่วยรายงานที่ตั้งไว้ที่สินค้า (ไม่ได้ตั้ง = หน่วยหลัก), doc = หน่วยที่กรอกในเอกสาร (เฉพาะรายงานระดับบรรทัด)
import 'package:flutter/material.dart';

class ImReportUomModeField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool isEnglish;
  final bool allowDocUnit;

  const ImReportUomModeField({super.key, required this.value, required this.onChanged, required this.isEnglish, this.allowDocUnit = false});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(labelText: isEnglish ? 'Display Unit' : 'หน่วยแสดงผล', border: const OutlineInputBorder(), isDense: true),
      items: [
        DropdownMenuItem(value: 'base', child: Text(isEnglish ? 'Base unit' : 'หน่วยหลัก')),
        DropdownMenuItem(value: 'report', child: Text(isEnglish ? 'Report unit of the item' : 'หน่วยรายงานของสินค้า')),
        if (allowDocUnit) DropdownMenuItem(value: 'doc', child: Text(isEnglish ? 'Unit entered in the document' : 'หน่วยที่กรอกในเอกสาร')),
      ],
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}
