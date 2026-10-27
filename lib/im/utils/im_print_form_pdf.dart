// lib/im/utils/im_print_form_pdf.dart — ตัวสร้าง PDF กลางของแบบฟอร์มพิมพ์ (ใช้ทั้งดูตัวอย่างในหน้าจอออกแบบและหน้าจอพิมพ์)
// ลำดับแผ่น: ทีละเอกสาร -> LASER: ทีละสำเนา (ทุกหน้าของสำเนาที่ 1 แล้วจึงสำเนาที่ 2 ...) / PREPRINTED: ชุดเดียว
// ตารางรายการเกินจำนวนแถวต่อหน้า = ขึ้นหน้าใหม่ (ชิ้นงาน pages = first/last แสดงเฉพาะหน้าแรก/หน้าสุดท้าย)
// ฟอนต์ THSarabun ไม่มีสัญลักษณ์พิเศษหลายตัว (ดู unsupportedGlyphs) — หน้าจอออกแบบเตือนเมื่อข้อความคงที่มีอักขระเหล่านี้
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/im_print_form.dart';

const _thMonths = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
const _thMonthsShort = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
const _enMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

// รูปแบบวันที่ / ตัวเลขที่เลือกได้ต่อชิ้นงาน (คีย์ → [ไทย, อังกฤษ])
const Map<String, List<String>> printDateFormats = {
  '': ['31/12/2026 (ค.ศ.)', '31/12/2026 (AD)'],
  'dmy_be': ['31/12/2569 (พ.ศ.)', '31/12/2569 (BE)'],
  'd_mmmm_be': ['31 ธันวาคม 2569', '31 ธันวาคม 2569 (Thai)'],
  'd_mmm_be': ['31 ธ.ค. 69', '31 ธ.ค. 69 (Thai short)'],
  'd_mmmm_en': ['31 December 2026', '31 December 2026'],
  'ymd': ['2026-12-31', '2026-12-31'],
};
const Map<String, List<String>> printNumberFormats = {
  '': ['ตามชนิดฟิลด์', 'By field type'],
  '0': ['1,235', '1,235'],
  '1': ['1,234.6', '1,234.6'],
  '2': ['1,234.56', '1,234.56'],
  '3': ['1,234.560', '1,234.560'],
  '4': ['1,234.5600', '1,234.5600'],
  'nc': ['1234 (ไม่มีจุลภาค)', '1234 (no comma)'],
};

// อักขระที่ THSarabun พิมพ์ได้: ASCII + ไทย (+ เว้นวรรค/ขึ้นบรรทัด)
List<String> unsupportedGlyphs(String text) {
  final bad = <String>{};
  for (final r in text.runes) {
    final ok = r == 10 || r == 13 || (r >= 0x20 && r <= 0x7E) || (r >= 0x0E00 && r <= 0x0E7F) || r == 0xA0;
    if (!ok) bad.add(String.fromCharCode(r));
  }
  return bad.toList();
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m != null) return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return DateTime.tryParse(s);
}

String formatPrintDate(dynamic v, String fmt) {
  final d = _parseDate(v);
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  switch (fmt) {
    case 'dmy_be':
      return '${two(d.day)}/${two(d.month)}/${d.year + 543}';
    case 'd_mmmm_be':
      return '${d.day} ${_thMonths[d.month - 1]} ${d.year + 543}';
    case 'd_mmm_be':
      return '${d.day} ${_thMonthsShort[d.month - 1]} ${two((d.year + 543) % 100)}';
    case 'd_mmmm_en':
      return '${d.day} ${_enMonths[d.month - 1]} ${d.year}';
    case 'ymd':
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    default:
      return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

String formatPrintNumber(dynamic v, String type, String fmt, {bool blankZero = false}) {
  if (v == null || v == '') return '';
  final n = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (n == null) return v.toString();
  if (blankZero && n.abs() < 0.0000001) return '';
  if (fmt == 'nc') return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  final dec = int.tryParse(fmt);
  if (dec != null) return NumberFormat('#,##0${dec > 0 ? '.${'0' * dec}' : ''}').format(n);
  if (type == 'money') return NumberFormat('#,##0.00').format(n);
  return NumberFormat('#,##0.####').format(n);
}

// จัดรูปค่าตามชนิดฟิลด์ (fmt ว่าง = ค่าเริ่มต้นของชนิด)
String formatPrintValue(dynamic v, String type, String fmt, {bool blankZero = false}) {
  switch (type) {
    case 'date':
      return formatPrintDate(v, fmt);
    case 'money':
    case 'qty':
    case 'number':
      return formatPrintNumber(v, type, fmt, blankZero: blankZero);
    case 'image':
      return '';
    default:
      return v?.toString() ?? '';
  }
}

Uint8List? decodeDataUrl(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  try {
    final i = dataUrl.indexOf(',');
    return base64Decode(i >= 0 ? dataUrl.substring(i + 1) : dataUrl);
  } catch (_) {
    return null;
  }
}

// ค่าที่คำนวณตอนพิมพ์ (scope P)
class PrintPageContext {
  final int pageNo;
  final int pageCount;
  final PrintFormCopy? copy;
  final DateTime printedAt;
  final String printedBy;

  const PrintPageContext({required this.pageNo, required this.pageCount, this.copy, required this.printedAt, required this.printedBy});

  dynamic value(String key) {
    switch (key) {
      case 'page_no':
        return pageNo;
      case 'page_count':
        return pageCount;
      case 'page_label':
        return 'หน้า $pageNo/$pageCount';
      case 'page_label_en':
        return 'Page $pageNo/$pageCount';
      case 'copy_name':
        return copy?.nameTh ?? '';
      case 'copy_name_en':
        return copy == null ? '' : (copy!.nameEn.isNotEmpty ? copy!.nameEn : copy!.nameTh);
      case 'print_date':
        return printedAt;
      case 'print_time':
        return DateFormat('HH:mm').format(printedAt);
      case 'printed_by':
        return printedBy;
    }
    return null;
  }
}

// ตัวช่วยดึง/จัดรูปค่าของเอกสาร — ใช้ร่วมกับ canvas ของหน้าจอออกแบบ
class PrintValueResolver {
  final PrintDataSource source;
  final Map<String, dynamic> company;
  final PrintDoc doc;
  final PrintPageContext ctx;

  PrintValueResolver({required this.source, required this.company, required this.doc, required this.ctx});

  dynamic raw(String key) {
    final f = source.field(key);
    if (f?.scope == 'P') return ctx.value(key);
    if (doc.header.containsKey(key)) return doc.header[key];
    return company[key];
  }

  String header(String key, {String fmt = '', bool blankZero = false}) {
    final f = source.field(key);
    return formatPrintValue(raw(key), f?.type ?? 'text', fmt, blankZero: blankZero);
  }

  String line(Map<String, dynamic> line, String key, {String fmt = '', bool blankZero = false}) {
    final f = source.field(key, line: true);
    return formatPrintValue(line[key], f?.type ?? 'text', fmt, blankZero: blankZero);
  }

  // ข้อความคงที่ — แทน {key} ด้วยค่าฟิลด์หัวเอกสาร
  String template(String text) =>
      text.replaceAllMapped(RegExp(r'\{([a-z0-9_]+)\}'), (m) => source.field(m[1]) == null ? m[0]! : header(m[1]!));

  String elementText(PrintElement e) {
    if (e.type == 'text') return template(e.text);
    final v = header(e.field ?? '', fmt: e.fmt, blankZero: e.blankZero);
    if (v.isEmpty) return '';
    return '${template(e.prefix)}$v${template(e.suffix)}';
  }
}

// ข้อมูลตัวอย่างสำหรับดูตัวอย่างในหน้าจอออกแบบ (ไม่ได้เลือกเอกสารจริง)
PrintDoc samplePrintDoc(PrintDataSource source, bool isEnglish, {int lineCount = 3}) {
  dynamic sample(PrintField f, int i) {
    switch (f.type) {
      case 'money':
        return 1234.5 * (i + 1);
      case 'qty':
        return 10.0 * (i + 1);
      case 'number':
        return f.key == 'line_no' ? i + 1 : 7;
      case 'date':
        return DateTime.now();
      case 'image':
        return '';
      default:
        return '[${f.label(isEnglish)}]';
    }
  }

  final header = <String, dynamic>{for (final f in source.headerFields.where((f) => f.scope == 'H')) f.key: sample(f, 0)};
  final lines = List.generate(lineCount, (i) => <String, dynamic>{for (final f in source.lineFields) f.key: sample(f, i)});
  return PrintDoc(key: 'SAMPLE', header: header, lines: lines);
}

class PrintFormPdf {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _loadFonts() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/THSarabun.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/THSarabun Bold.ttf'));
  }

  static int pageCountFor(PrintForm form, PrintDoc doc) {
    final tables = form.elements.where((e) => e.type == 'table').toList();
    if (tables.isEmpty) return 1;
    final rows = tables.map((t) => t.rowsPerPage).reduce(math.min);
    if (rows <= 0 || doc.lines.isEmpty) return 1;
    return (doc.lines.length / rows).ceil();
  }

  /// copyNos = เลขสำเนาที่จะพิมพ์ (1-based, LASER เท่านั้น; null = ทุกสำเนา)
  /// showBackground = แสดงรูปพื้นหลังแม้เป็น PREPRINTED (ดูตัวอย่างในหน้าจอออกแบบ)
  /// guide = วาดกรอบของทุกชิ้นงาน (พิมพ์ทดสอบตำแหน่งลงกระดาษเปล่าแล้ววางทาบฟอร์มจริง)
  static Future<Uint8List> build({
    required PrintForm form,
    required PrintDataSource source,
    required PrintData data,
    required String printedBy,
    List<int>? copyNos,
    bool showBackground = false,
    bool guide = false,
  }) async {
    await _loadFonts();
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!));
    final pageFormat = PdfPageFormat(form.paperWidth * PdfPageFormat.mm, form.paperHeight * PdfPageFormat.mm, marginAll: 0);
    final now = DateTime.now();

    // รูปที่ใช้ซ้ำทุกหน้า — decode ครั้งเดียว
    final bgImages = <int, pw.MemoryImage?>{};
    for (var i = 0; i < form.copies.length; i++) {
      final b = decodeDataUrl(form.copies[i].bgImage);
      bgImages[i + 1] = b == null ? null : pw.MemoryImage(b);
    }
    final logoBytes = decodeDataUrl(data.company['company_logo']?.toString());
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final elementImages = <String, pw.MemoryImage?>{};
    for (final e in form.elements.where((e) => e.type == 'image' && e.field == null)) {
      final b = decodeDataUrl(e.imageData);
      elementImages[e.id] = b == null ? null : pw.MemoryImage(b);
    }

    // สำเนาที่พิมพ์: LASER = ตามที่เลือก (ค่าเริ่มต้นทุกสำเนา), PREPRINTED = ชุดเดียว (ใช้สำเนาที่ 1 เป็นชื่อ/พื้นหลังตัวอย่าง)
    final copyList = form.isPreprinted
        ? [1]
        : [for (var i = 1; i <= form.copies.length; i++) if (copyNos == null || copyNos.contains(i)) i];
    if (copyList.isEmpty) copyList.add(1);

    for (final doc in data.docs) {
      final pages = pageCountFor(form, doc);
      for (final copyNo in copyList) {
        final copy = copyNo <= form.copies.length ? form.copies[copyNo - 1] : null;
        for (var p = 1; p <= pages; p++) {
          final r = PrintValueResolver(
            source: source,
            company: data.company,
            doc: doc,
            ctx: PrintPageContext(pageNo: p, pageCount: pages, copy: form.isPreprinted ? null : copy, printedAt: now, printedBy: printedBy),
          );
          final children = <pw.Widget>[];
          final bg = bgImages[copyNo];
          if (bg != null && copy != null && (!form.isPreprinted || showBackground)) {
            children.add(_background(form, copy, bg));
          }
          for (final e in form.elements) {
            if (e.pages == 'first' && p != 1) continue;
            if (e.pages == 'last' && p != pages) continue;
            if (!form.isPreprinted && !e.visibleOnCopy(copyNo)) continue;
            final w = _element(form, e, r, doc, p, logo, elementImages[e.id]);
            if (w != null) children.add(w);
            if (guide) children.add(_guideBox(form, e));
          }
          pdf.addPage(pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.SizedBox(
              width: pageFormat.width,
              height: pageFormat.height,
              child: pw.Stack(overflow: pw.Overflow.clip, children: children),
            ),
          ));
        }
      }
    }
    if (data.docs.isEmpty) {
      pdf.addPage(pw.Page(pageFormat: pageFormat, build: (_) => pw.SizedBox()));
    }
    return pdf.save();
  }

  static const double _mm = PdfPageFormat.mm;

  static pw.Widget _background(PrintForm form, PrintFormCopy copy, pw.MemoryImage img) {
    final w = form.paperWidth * copy.bgScale * _mm;
    final h = form.paperHeight * copy.bgScale * _mm;
    pw.Widget child = pw.Image(img, width: w, height: h, fit: pw.BoxFit.fill);
    // หมุนตามเข็มนาฬิกาเมื่อค่าเป็นบวก (แกน y ของ PDF ชี้ขึ้น จึงกลับเครื่องหมาย)
    if (copy.bgRotate != 0) child = pw.Transform.rotate(angle: -copy.bgRotate * math.pi / 180, child: child);
    return pw.Positioned(
      left: (form.offsetX + copy.bgOffsetX) * _mm,
      top: (form.offsetY + copy.bgOffsetY) * _mm,
      child: pw.SizedBox(width: w, height: h, child: child),
    );
  }

  static pw.Alignment _align(String a) =>
      a == 'R' ? pw.Alignment.topRight : (a == 'C' ? pw.Alignment.topCenter : pw.Alignment.topLeft);
  static pw.TextAlign _textAlign(String a) => a == 'R' ? pw.TextAlign.right : (a == 'C' ? pw.TextAlign.center : pw.TextAlign.left);

  static pw.Widget _text(String s, PrintElement e, {double? fontSize, bool? bold, String? align, int? maxLines}) {
    final al = align ?? e.align;
    final ml = maxLines ?? e.maxLines;
    return pw.Text(
      s,
      textAlign: _textAlign(al),
      maxLines: ml <= 0 ? null : ml,
      softWrap: ml != 1,
      overflow: pw.TextOverflow.clip,
      style: pw.TextStyle(fontSize: fontSize ?? e.fontSize, fontWeight: (bold ?? e.bold) ? pw.FontWeight.bold : pw.FontWeight.normal, lineSpacing: 0),
    );
  }

  static pw.Widget? _element(PrintForm form, PrintElement e, PrintValueResolver r, PrintDoc doc, int page,
      pw.MemoryImage? logo, pw.MemoryImage? uploaded) {
    final left = (form.offsetX + e.x) * _mm;
    final top = (form.offsetY + e.y) * _mm;
    final w = math.max(e.w, 0.1) * _mm;
    final h = math.max(e.h, 0.1) * _mm;
    switch (e.type) {
      case 'field':
      case 'text':
        final s = r.elementText(e);
        if (s.isEmpty) return null;
        return pw.Positioned(
          left: left,
          top: top,
          child: pw.SizedBox(width: w, height: h, child: pw.Align(alignment: _align(e.align), child: _text(s, e))),
        );
      case 'line':
        return pw.Positioned(
          left: left,
          top: top,
          child: pw.SizedBox(
            width: math.max(e.w * _mm, 0.1),
            height: math.max(e.h * _mm, 0.1),
            child: pw.CustomPaint(painter: (canvas, size) {
              canvas
                ..setStrokeColor(PdfColors.black)
                ..setLineWidth(e.strokeWidth)
                ..moveTo(0, e.h <= 0 ? 0 : size.y)
                ..lineTo(e.w <= 0 ? 0 : size.x, 0)
                ..strokePath();
            }),
          ),
        );
      case 'rect':
        if (e.fillColor.isEmpty && e.strokeWidth <= 0) return null;
        return pw.Positioned(
          left: left,
          top: top,
          child: pw.SizedBox(
            width: w,
            height: h,
            child: pw.Stack(children: [
              // สีพื้นแยกชั้นจากเส้นขอบ — ความโปร่งใสมีผลเฉพาะสีพื้น
              if (e.fillColor.isNotEmpty)
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: e.fillOpacity.clamp(0.0, 1.0),
                    child: pw.Container(color: PdfColor.fromInt(0xFF000000 | (int.tryParse(e.fillColor, radix: 16) ?? 0))),
                  ),
                ),
              if (e.strokeWidth > 0)
                pw.Positioned.fill(
                  child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: e.strokeWidth, color: PdfColors.black))),
                ),
            ]),
          ),
        );
      case 'image':
        final img = e.field == 'company_logo' ? logo : uploaded;
        if (img == null) return null;
        return pw.Positioned(left: left, top: top, child: pw.SizedBox(width: w, height: h, child: pw.Image(img, fit: pw.BoxFit.contain)));
      case 'table':
        return pw.Positioned(left: left, top: top, child: _table(e, r, doc, page));
    }
    return null;
  }

  static pw.Widget _table(PrintElement e, PrintValueResolver r, PrintDoc doc, int page) {
    final rows = e.rowsPerPage;
    final start = (page - 1) * rows;
    final lines = start >= doc.lines.length ? <Map<String, dynamic>>[] : doc.lines.sublist(start, math.min(start + rows, doc.lines.length));
    final w = e.w * _mm;
    final h = e.h * _mm;
    final headH = e.showHeader ? e.headerHeight * _mm : 0.0;
    final rowH = e.rowHeight * _mm;
    pw.Widget cell(String s, PrintColumn c, double height, {bool bold = false}) => pw.Container(
          width: c.w * _mm,
          height: height,
          padding: const pw.EdgeInsets.symmetric(horizontal: 1 * PdfPageFormat.mm),
          alignment: c.align == 'R' ? pw.Alignment.centerRight : (c.align == 'C' ? pw.Alignment.center : pw.Alignment.centerLeft),
          child: _text(s, e, align: c.align, maxLines: 1, bold: bold),
        );
    final content = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (e.showHeader) pw.Row(children: [for (final c in e.columns) cell(c.title, c, headH, bold: true)]),
      for (final l in lines)
        pw.Row(children: [for (final c in e.columns) cell(r.line(l, c.field, fmt: c.fmt, blankZero: c.blankZero), c, rowH, bold: e.bold)]),
    ]);
    return pw.SizedBox(
      width: w,
      height: h,
      child: pw.Stack(overflow: pw.Overflow.clip, children: [
        content,
        if (e.border != 'none')
          pw.Positioned.fill(
            child: pw.CustomPaint(painter: (canvas, size) {
              canvas
                ..setStrokeColor(PdfColors.black)
                ..setLineWidth(e.strokeWidth);
              // พิกัด PDF: y = 0 ด้านล่าง
              double yAt(double fromTop) => size.y - fromTop;
              if (e.border == 'grid' || e.border == 'box') {
                canvas.drawRect(0, 0, size.x, size.y);
                if (e.showHeader) canvas..moveTo(0, yAt(headH))..lineTo(size.x, yAt(headH));
                var x = 0.0;
                for (var i = 0; i < e.columns.length - 1; i++) {
                  x += e.columns[i].w * _mm;
                  if (x >= size.x) break;
                  canvas..moveTo(x, 0)..lineTo(x, size.y);
                }
              }
              if (e.border == 'grid' || e.border == 'rows') {
                for (var i = 1; i <= rows; i++) {
                  final y = headH + rowH * i;
                  if (y >= size.y - 0.01) break;
                  canvas..moveTo(0, yAt(y))..lineTo(size.x, yAt(y));
                }
                if (e.border == 'rows' && e.showHeader) canvas..moveTo(0, yAt(headH))..lineTo(size.x, yAt(headH));
              }
              canvas.strokePath();
            }),
          ),
      ]),
    );
  }

  static pw.Widget _guideBox(PrintForm form, PrintElement e) {
    return pw.Positioned(
      left: (form.offsetX + e.x) * _mm,
      top: (form.offsetY + e.y) * _mm,
      child: pw.Container(
        width: math.max(e.w, 0.5) * _mm,
        height: math.max(e.h, 0.5) * _mm,
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.3, color: PdfColors.red)),
      ),
    );
  }
}
