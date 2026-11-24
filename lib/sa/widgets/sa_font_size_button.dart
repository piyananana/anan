import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sa_font_provider.dart';

/// ปุ่ม Aa เลือกขนาดตัวอักษร (ค่าของเครื่องผู้ใช้ จำไว้ใน FontProvider) — แบบเดียวกับแถบด้านบนของหน้าหลัก
class FontSizeButton extends StatelessWidget {
  final bool isEnglish;
  final Color color;
  const FontSizeButton({super.key, required this.isEnglish, this.color = Colors.orange});

  String _label(double s) {
    final name = s == 0.9
        ? (isEnglish ? 'Small' : 'เล็ก')
        : s == 1.0
            ? (isEnglish ? 'Normal' : 'ปกติ')
            : s == 1.1
                ? (isEnglish ? 'Large' : 'ใหญ่')
                : (isEnglish ? 'Extra large' : 'ใหญ่มาก');
    return '$name (${(s * 100).round()}%)';
  }

  @override
  Widget build(BuildContext context) {
    final font = context.watch<FontProvider>();
    return PopupMenuButton<double>(
      tooltip: isEnglish ? 'Font size' : 'ขนาดตัวอักษร',
      initialValue: font.textScale,
      onSelected: font.setTextScale,
      itemBuilder: (_) => [
        for (final s in FontProvider.scales)
          CheckedPopupMenuItem<double>(value: s, checked: s == font.textScale, child: Text(_label(s))),
      ],
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Text(
          font.textScale == 1.0 ? 'Aa' : 'Aa ${(font.textScale * 100).round()}%',
          style: TextStyle(color: color, fontSize: 16),
        ),
      ),
    );
  }
}
