// lib/utils/dot_matrix_pdf.dart — เลือกเครื่องพิมพ์ Laser / Dot matrix ตอนพิมพ์ฟอร์มและรายงาน (user-approved 2026-11-19)
//
// รายงาน/ฟอร์มทุกตัวสร้าง PDF ของตัวเอง (ขนาด A4 ฯลฯ, มีพื้นสี/เส้นสีเทา) — สำหรับ dot matrix แปลงจาก PDF เดิมโดยตรง
// ไม่ต้องแก้รายงานทีละตัว:
//   1) เรนเดอร์แต่ละหน้าเป็นภาพ 180 dpi (ความละเอียดของหัวพิมพ์ 24 เข็ม)
//   2) แปลงเป็นขาว-ดำล้วน: สีอ่อน (พื้นหัวตาราง/แถบสี) → ขาว, ตัวอักษร/เส้น → ดำ — พิมพ์คม เร็ว ไม่เปลืองผ้าหมึก
//   3) วางบนขนาดกระดาษต่อเนื่องที่เลือก (ย่อให้พอดีเมื่อหน้าเดิมใหญ่กว่า ไม่ขยาย, ชิดบน กึ่งกลางแนวนอน)
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrintTarget { laser, dotMatrix }

/// ขนาดกระดาษสำหรับ dot matrix — mm (0 = ใช้ขนาดหน้าของเอกสารเดิม ไม่ย่อ เช่น ฟอร์มพิมพ์ทับ/เช็ค)
class DotMatrixPaper {
  final String code;
  final String labelTh, labelEn;
  final double widthMm, heightMm;
  const DotMatrixPaper(this.code, this.labelTh, this.labelEn, this.widthMm, this.heightMm);
  bool get sameAsDocument => widthMm <= 0;
  String label(bool isEnglish) => isEnglish ? labelEn : labelTh;

  static const all = <DotMatrixPaper>[
    DotMatrixPaper('DOC', 'ตามเอกสาร (ไม่ย่อ)', 'Same as document', 0, 0),
    DotMatrixPaper('9x11', 'ต่อเนื่อง 9" x 11"', 'Continuous 9" x 11"', 228.6, 279.4),
    DotMatrixPaper('15x11', 'ต่อเนื่อง 15" x 11" (แคร่ยาว)', 'Continuous 15" x 11" (wide)', 381.0, 279.4),
    DotMatrixPaper('9x5.5', 'ต่อเนื่อง 9" x 5.5" (ครึ่งแผ่น)', 'Continuous 9" x 5.5" (half)', 228.6, 139.7),
    DotMatrixPaper('A4', 'A4', 'A4', 210, 297),
  ];
  static DotMatrixPaper byCode(String? c, {String fallback = '9x11'}) =>
      all.firstWhere((p) => p.code == c, orElse: () => all.firstWhere((p) => p.code == fallback));
}

/// ตัวเลือกการพิมพ์ — จำค่าล่าสุดแยกตามรายงาน/ฟอร์ม (key) ในเครื่องนี้
class PrintTargetSetting {
  final PrintTarget target;
  final DotMatrixPaper paper;
  const PrintTargetSetting(this.target, this.paper);
  bool get isDotMatrix => target == PrintTarget.dotMatrix;

  static String _k(String key) => 'print_target_$key';

  static Future<PrintTargetSetting> load(String key, {String defaultPaper = '9x11'}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_k(key)) ?? p.getString(_k('_last'));
      if (v != null) {
        final parts = v.split('|');
        return PrintTargetSetting(parts[0] == 'dot' ? PrintTarget.dotMatrix : PrintTarget.laser,
            DotMatrixPaper.byCode(parts.length > 1 ? parts[1] : null, fallback: defaultPaper));
      }
    } catch (_) {}
    return PrintTargetSetting(PrintTarget.laser, DotMatrixPaper.byCode(defaultPaper));
  }

  Future<void> save(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = '${isDotMatrix ? 'dot' : 'laser'}|${paper.code}';
      await p.setString(_k(key), v);
      await p.setString(_k('_last'), v);
    } catch (_) {}
  }
}

/// แปลง PDF เดิมเป็น PDF สำหรับ dot matrix (ขาว-ดำ, ขนาดกระดาษที่เลือก)
Future<Uint8List> toDotMatrixPdf(Uint8List src, DotMatrixPaper paper, {double dpi = 180, double threshold = 0.8}) async {
  final doc = pw.Document();
  final cut = (threshold * 255).round();
  await for (final page in Printing.raster(src, dpi: dpi)) {
    final px = page.pixels;
    // 3 ช่องสี (R=G=B) — ภาพช่องเดียว encodeJpg อ่านเป็น R อย่างเดียว ทำให้พื้นขาวกลายเป็นสีแดง
    final gray = Uint8List(page.width * page.height * 3);
    for (var i = 0, j = 0; i < px.length; i += 4, j += 3) {
      final a = px[i + 3];
      // ทับบนพื้นขาว แล้วตัดเป็นขาว/ดำ ตามความสว่าง
      final lum = (px[i] * 299 + px[i + 1] * 587 + px[i + 2] * 114) ~/ 1000;
      final l = (lum * a + 255 * (255 - a)) ~/ 255;
      final v = l < cut ? 0 : 255;
      gray[j] = v;
      gray[j + 1] = v;
      gray[j + 2] = v;
    }
    final srcW = page.width / dpi * PdfPageFormat.inch;
    final srcH = page.height / dpi * PdfPageFormat.inch;
    final pw0 = paper.sameAsDocument ? srcW : paper.widthMm * PdfPageFormat.mm;
    final ph0 = paper.sameAsDocument ? srcH : paper.heightMm * PdfPageFormat.mm;
    // พอดีกระดาษ (รายงานที่ใช้ dotMatrixPage() แบ่งหน้าตามสัดส่วนกระดาษแล้ว → เต็มหน้าพอดี); ตามเอกสาร = ไม่ย่อ/ขยาย
    var scale = paper.sameAsDocument ? 1.0 : pw0 / srcW;
    if (srcH * scale > ph0) scale = ph0 / srcH;
    // ฝังเป็น JPEG (ไฟล์เล็ก, ไม่ต้องบีบอัดซ้ำ — ภาพดิบ RGBA หน้าละ ~13MB ช้ามากบนเว็บ)
    final jpg = img.encodeJpg(
        img.Image.fromBytes(width: page.width, height: page.height, bytes: gray.buffer, numChannels: 3),
        quality: 90);
    final image = pw.MemoryImage(jpg);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(pw0, ph0, marginAll: 0),
      build: (_) => pw.Align(
        alignment: pw.Alignment.topCenter,
        child: pw.SizedBox(width: srcW * scale, height: srcH * scale, child: pw.Image(image, fit: pw.BoxFit.fill)),
      ),
    ));
  }
  return doc.save();
}

/// กระดาษ dot matrix ที่กำลังสร้างรายงานอยู่ (ZoomablePdfPreview ตั้งระหว่างเรียก build) — null = เลเซอร์/ตามเอกสาร
DotMatrixPaper? dotMatrixLayoutPaper;

/// ขนาดหน้าสำหรับรายงาน: เลเซอร์ = ตามเดิม / dot matrix = กว้างเท่าเดิม (ผังคอลัมน์ไม่เปลี่ยน) แต่ยาวตามสัดส่วนกระดาษ
/// เพื่อให้แบ่งหน้าตามความยาวกระดาษจริง แล้ว toDotMatrixPdf ย่อ/ขยายทั้งหน้าให้พอดีความกว้างกระดาษ
PdfPageFormat dotMatrixPage(PdfPageFormat base) {
  final p = dotMatrixLayoutPaper;
  if (p == null || p.sameAsDocument) return base;
  return PdfPageFormat(base.width, base.width * p.heightMm / p.widthMm,
      marginLeft: base.marginLeft, marginTop: base.marginTop, marginRight: base.marginRight, marginBottom: base.marginBottom);
}

/// แปลงตามตัวเลือก (Laser = คืนเอกสารเดิม)
Future<Uint8List> applyPrintTarget(Uint8List src, PrintTargetSetting s) =>
    s.isDotMatrix ? toDotMatrixPdf(src, s.paper) : Future.value(src);

/// แถบเลือก Laser / Dot matrix + ขนาดกระดาษ (ใช้ในหน้าแสดงตัวอย่าง และในกล่องเลือกก่อนสั่งพิมพ์)
class PrintTargetSelector extends StatelessWidget {
  const PrintTargetSelector({super.key, required this.value, required this.onChanged, required this.isEnglish});
  final PrintTargetSetting value;
  final ValueChanged<PrintTargetSetting> onChanged;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Icon(Icons.print_outlined, size: 18, color: Colors.grey[700]),
      SegmentedButton<PrintTarget>(
        style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: PrintTarget.laser, label: Text(isEnglish ? 'Laser' : 'เลเซอร์', style: const TextStyle(fontSize: 12))),
          ButtonSegment(value: PrintTarget.dotMatrix, label: Text(isEnglish ? 'Dot matrix' : 'ดอทเมทริกซ์', style: const TextStyle(fontSize: 12))),
        ],
        selected: {value.target},
        onSelectionChanged: (s) => onChanged(PrintTargetSetting(s.first, value.paper)),
      ),
      if (value.isDotMatrix)
        DropdownButton<String>(
          value: value.paper.code,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: [
            for (final p in DotMatrixPaper.all) DropdownMenuItem(value: p.code, child: Text(p.label(isEnglish))),
          ],
          onChanged: (c) => onChanged(PrintTargetSetting(value.target, DotMatrixPaper.byCode(c))),
        ),
      if (value.isDotMatrix)
        Tooltip(
          message: isEnglish
              ? 'Black & white, fitted to the paper. In the print dialog pick the dot-matrix printer, the same paper size and scale 100%.'
              : 'พิมพ์ขาว-ดำ ย่อให้พอดีกระดาษ — ในหน้าต่างพิมพ์ให้เลือกเครื่อง dot matrix ขนาดกระดาษเดียวกัน และสเกล 100%',
          child: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
        ),
    ]);
  }
}

/// กล่องเลือกก่อนสั่งพิมพ์ (สำหรับปุ่มที่สั่งพิมพ์ตรงโดยไม่มีหน้าตัวอย่าง) — คืน null เมื่อยกเลิก
Future<PrintTargetSetting?> showPrintTargetDialog(BuildContext context, String key,
    {required bool isEnglish, String defaultPaper = '9x11'}) async {
  var s = await PrintTargetSetting.load(key, defaultPaper: defaultPaper);
  if (!context.mounted) return null;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(isEnglish ? 'Print to' : 'พิมพ์ด้วยเครื่องพิมพ์', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: PrintTargetSelector(value: s, isEnglish: isEnglish, onChanged: (v) => setD(() => s = v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Print' : 'พิมพ์')),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  await s.save(key);
  return s;
}

/// สั่งพิมพ์ PDF โดยถามเครื่องพิมพ์ก่อน (Laser = เหมือนเดิม, Dot matrix = แปลงขาว-ดำ/ขนาดกระดาษ)
Future<void> printPdfWithTarget(BuildContext context, String key, Uint8List bytes,
    {required bool isEnglish, String? name, PdfPageFormat? format, String defaultPaper = '9x11'}) async {
  final s = await showPrintTargetDialog(context, key, isEnglish: isEnglish, defaultPaper: defaultPaper);
  if (s == null) return;
  final out = await applyPrintTarget(bytes, s);
  await Printing.layoutPdf(onLayout: (_) async => out, name: name ?? 'document', format: format ?? PdfPageFormat.standard);
}
