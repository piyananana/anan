import 'package:flutter/material.dart';

// โหมดบัญชีสินค้าระดับสินค้า/หมวดสินค้า/คลัง — null = ตามระดับถัดไป (สินค้า → หมวดสินค้า → คลัง → ค่าเริ่มต้นของบริษัท)
// ดู project_im_mixed_accounting_mode และ backend utils/imAccountingMode.js
class ImAccountingModeField extends StatelessWidget {
  final String? value;
  final bool isEnglish;
  final bool readOnly;
  final String inheritLabelTh;
  final String inheritLabelEn;
  final ValueChanged<String?> onChanged;

  const ImAccountingModeField({
    super.key,
    required this.value,
    required this.isEnglish,
    required this.readOnly,
    required this.inheritLabelTh,
    required this.inheritLabelEn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isEnglish ? 'Inventory accounting mode' : 'โหมดบัญชีสินค้า',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(isEnglish ? inheritLabelEn : inheritLabelTh, overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(value: 'PERPETUAL', child: Text(isEnglish ? 'Perpetual' : 'Perpetual (โพสต์บัญชีทันที)')),
          DropdownMenuItem<String?>(value: 'PERIODIC', child: Text(isEnglish ? 'Periodic' : 'Periodic (ปิดงวดครั้งเดียว)')),
        ],
        onChanged: readOnly ? null : onChanged,
      ),
    );
  }

  // ช่องบัญชีที่ไม่ใช้ในโหมดที่เลือก — ปิดไว้แต่คงค่าเดิม (โหมด "ตามระดับถัดไป" เปิดทุกช่อง เพราะโหมดจริงอาจต่างกันตามคลัง)
  static Widget gate({required bool enabled, required bool isEnglish, required Widget child}) {
    if (enabled) return child;
    return Tooltip(
      message: isEnglish ? 'Not used in the selected mode' : 'ไม่ใช้ในโหมดที่เลือก',
      child: IgnorePointer(child: Opacity(opacity: 0.45, child: child)),
    );
  }
}
