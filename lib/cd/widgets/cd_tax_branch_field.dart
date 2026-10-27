import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// รหัสสาขาตามทะเบียนภาษีมูลค่าเพิ่ม (ลูกค้า / ผู้ขาย) — 5 หลัก, '00000' = สำนักงานใหญ่, ว่าง = ไม่ระบุ
// (บุคคลธรรมดา / ไม่ได้จด VAT — ฟอร์มไม่พิมพ์ข้อความสาขา) — backend: utils/taxBranch.js

// ข้อความสำหรับพิมพ์ต่อท้ายเลขประจำตัวผู้เสียภาษี เช่น "สำนักงานใหญ่" / "สาขาที่ 00001" ('' = ไม่พิมพ์)
String taxBranchLabel(String? code, bool isEnglish) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '';
  if (c == '00000') return isEnglish ? 'Head Office' : 'สำนักงานใหญ่';
  return isEnglish ? 'Branch $c' : 'สาขาที่ $c';
}

// ค่าที่จะบันทึก — เติมศูนย์นำหน้าให้ครบ 5 หลัก ('' → null)
String? normalizeTaxBranch(String text) {
  final t = text.trim();
  return t.isEmpty ? null : t.padLeft(5, '0');
}

// ช่องกรอกรหัสสาขา: ตัวเลขไม่เกิน 5 หลัก + ปุ่มลัด "สำนักงานใหญ่" + แสดงข้อความที่จะพิมพ์ใต้ช่อง
class TaxBranchField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final bool isEnglish;

  const TaxBranchField({
    super.key,
    required this.controller,
    required this.isEnglish,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final label = taxBranchLabel(normalizeTaxBranch(value.text), isEnglish);
          return TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: InputDecoration(
              labelText: isEnglish ? 'Tax Branch No.' : 'รหัสสาขา (ภาษี)',
              hintText: isEnglish ? '00000 (blank = not specified)' : '00000 (ว่าง = ไม่ระบุ)',
              helperText: label.isEmpty ? null : label,
              border: const OutlineInputBorder(),
              suffixIcon: readOnly
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.home_work_outlined, size: 18),
                      tooltip: isEnglish ? 'Head Office (00000)' : 'สำนักงานใหญ่ (00000)',
                      onPressed: () => controller.text = '00000',
                    ),
            ),
          );
        },
      ),
    );
  }
}
