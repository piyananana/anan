// lib/cm/utils/cm_check_pdf.dart — สร้าง PDF เช็คตามตำแหน่งพิมพ์ (cm_check_print_config)
// ใช้ร่วมกันระหว่างหน้าพิมพ์เช็คจ่าย (CmCheckPrintScreen) และปุ่มพิมพ์ทดสอบในหน้าสร้างแบบพิมพ์เช็ค
// เพื่อให้ภาพที่ทดสอบตรงกับเช็คที่พิมพ์จริง (user 2026-11-28)
// ตำแหน่ง X, Y = มิลลิเมตรจากมุมซ้ายบนของกระดาษ (ค่าต้นขั้วยังไม่ถูกใช้ในการพิมพ์)
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../utils/thai_amount_words.dart';
import '../../utils/date_utils.dart';

final _fmt = NumberFormat('#,##0.00', 'en_US');

double cmMmToPt(double mm) => mm * 72 / 25.4;

/// checks: แถวที่มี payee_name_th, amount_lc, check_date / payment_date; cfg: แถว cm_check_print_config (JSON)
Future<Uint8List> buildCheckPdf(List<Map<String, dynamic>> checks, Map<String, dynamic> cfg) async {
  final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
  final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
  final font = pw.Font.ttf(fontData);
  final fontBold = pw.Font.ttf(fontBoldData);
  final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

  double mm(String k, double def) => cmMmToPt(double.tryParse(cfg[k]?.toString() ?? '') ?? def);
  final pageFormat = PdfPageFormat(mm('paper_width_mm', 210), mm('paper_height_mm', 99), marginAll: 0);
  final dateX = mm('date_x', 150), dateY = mm('date_y', 18);
  final payeeX = mm('payee_x', 35), payeeY = mm('payee_y', 38);
  final amtNumX = mm('amount_num_x', 155), amtNumY = mm('amount_num_y', 38);
  final amtTxtX = mm('amount_text_x', 20), amtTxtY = mm('amount_text_y', 55);
  final dateFmtStr = (cfg['date_format'] as String?)?.trim().isNotEmpty == true ? cfg['date_format'] as String : 'dd/MM/yyyy';

  final doc = pw.Document(theme: theme);
  for (final c in checks) {
    final payee = c['payee_name_th'] as String? ?? '';
    final amount = double.tryParse(c['amount_lc']?.toString() ?? '0') ?? 0;
    final amtTxt = thaiAmountToWords(amount);
    String dateStr = '';
    try {
      final checkDate = c['check_date'] != null
          ? parseLocalDate(c['check_date'])
          : (c['payment_date'] != null ? parseLocalDate(c['payment_date']) : DateTime.now());
      dateStr = DateFormat(dateFmtStr).format(checkDate);
    } catch (_) {
      dateStr = c['check_date']?.toString() ?? '';
    }
    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(children: [
        pw.Positioned(left: dateX, top: dateY, child: pw.Text(dateStr, style: pw.TextStyle(font: fontBold, fontSize: 11))),
        pw.Positioned(left: payeeX, top: payeeY, child: pw.Text(payee, style: pw.TextStyle(font: fontBold, fontSize: 12))),
        pw.Positioned(left: amtNumX, top: amtNumY, child: pw.Text(_fmt.format(amount), style: pw.TextStyle(font: fontBold, fontSize: 12))),
        pw.Positioned(left: amtTxtX, top: amtTxtY, child: pw.Text(amtTxt, style: pw.TextStyle(font: font, fontSize: 11))),
      ]),
    ));
  }
  return doc.save();
}
