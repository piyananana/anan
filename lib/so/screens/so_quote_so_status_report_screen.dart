// lib/so/screens/so_quote_so_status_report_screen.dart — ติดตามสถานะใบเสนอราคา(Quote)/ใบสั่งขาย(SO) คู่กัน
// เงื่อนไข Quote และ SO กรองอิสระจากกัน — Quote ที่ตรงเงื่อนไขจะพา SO ที่แปลงมาจากมันมาแสดงด้วยเสมอไม่ว่า SO จะ
// สถานะอะไร ส่วนเงื่อนไข SO ใช้เลือกเฉพาะ SO ที่ไม่มีใบเสนอราคาอ้างอิง (สั่งขายตรงไม่ผ่าน Quote) เท่านั้น — ดู
// soQuoteSoStatusReportController.js สำหรับรายละเอียด query เต็ม รายงานนี้อ่านอย่างเดียว — มิเรอร์
// po_pr_po_status_report_screen.dart ทุกประการ (PR->Quote, PO->SO)
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../widgets/zoomable_pdf_preview.dart';
import '../../po/widgets/po_search_multi_picker.dart';
import '../models/so_quote_so_status_report.dart';
import '../services/so_quote_so_status_report_service.dart';
import '../../utils/file_download.dart';

class _StatusOption {
  final int id;
  final String value;
  final String labelTh;
  final String labelEn;
  const _StatusOption(this.id, this.value, this.labelTh, this.labelEn);
}

const _quoteStatusOptions = [
  _StatusOption(0, 'Draft', 'ร่าง', 'Draft'),
  _StatusOption(1, 'Submitted', 'รออนุมัติ', 'Pending Approval'),
  _StatusOption(2, 'Approved', 'อนุมัติแล้ว', 'Approved'),
  _StatusOption(3, 'Rejected', 'ถูกปฏิเสธ', 'Rejected'),
  _StatusOption(4, 'Void', 'ยกเลิก', 'Void'),
];

const _soStatusOptions = [
  _StatusOption(0, 'Draft', 'ร่าง', 'Draft'),
  _StatusOption(1, 'Approved', 'อนุมัติแล้ว', 'Approved'),
  _StatusOption(2, 'Void', 'ยกเลิก', 'Void'),
];

String _statusLabel(List<_StatusOption> options, String? value, bool isEnglish) {
  if (value == null) return '-';
  final opt = options.where((o) => o.value == value);
  if (opt.isEmpty) return value;
  return isEnglish ? opt.first.labelEn : opt.first.labelTh;
}

// ป้ายกำกับสถานะ "หลังอนุมัติ" — ตัดออกจาก dialog เลือกสถานะหลักแล้ว (เหลือแค่ ร่าง/อนุมัติแล้ว/ยกเลิก) จึงต้องมี
// ป้ายกำกับแยกไว้ใช้เฉพาะคอลัมน์ "สถานะหลังอนุมัติ" ในรายงานเท่านั้น ไม่เกี่ยวกับ dialog กรอง
const _afterApprovalStatusLabels = {
  'PartiallyDelivered': ('ส่งสินค้าบางส่วน', 'Partially Delivered'),
  'FullyDelivered': ('ส่งสินค้าครบแล้ว', 'Fully Delivered'),
  'PartiallyConverted': ('แปลงเป็นใบสั่งขายบางส่วน', 'Partially Converted'),
  'FullyConverted': ('แปลงเป็นใบสั่งขายครบแล้ว', 'Fully Converted'),
  'Closed': ('ปิดแล้ว', 'Closed'),
};

String _afterApprovalLabel(String? status, bool isEnglish) {
  if (status == null) return '-';
  final pair = _afterApprovalStatusLabels[status];
  if (pair == null) return status;
  return isEnglish ? pair.$2 : pair.$1;
}

class QuoteSoStatusReportScreen extends StatefulWidget {
  const QuoteSoStatusReportScreen({super.key});

  @override
  State<QuoteSoStatusReportScreen> createState() => _QuoteSoStatusReportScreenState();
}

class _QuoteSoStatusReportScreenState extends State<QuoteSoStatusReportScreen> {
  final _service = QuoteSoStatusReportService();
  final _companyService = CompanyService();
  final _authService = AuthService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isExporting = false;

  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;

  bool _showQuote = true;
  bool _showSo = true;
  DateTime? _quoteDateFrom;
  DateTime? _quoteDateTo;
  DateTime? _soDateFrom;
  DateTime? _soDateTo;
  List<int> _selectedQuoteStatusIds = [];
  List<int> _selectedSoStatusIds = [];
  bool _showQuoteItems = false;
  bool _showSoItems = false;

  List<QuoteSoStatusReportRow> _reportData = [];
  bool _hasGenerated = false;

  Company? _company;
  Map<String, String>? _headers;
  String _reportTitle = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _headers = await _authService.getAuthHeader();
    final company = await _companyService.fetchCompany();
    if (!mounted) return;
    setState(() => _company = company);
  }

  Future<void> _generate() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchReport(
        showQuote: _showQuote, showSo: _showSo,
        quoteDateFrom: _quoteDateFrom, quoteDateTo: _quoteDateTo,
        soDateFrom: _soDateFrom, soDateTo: _soDateTo,
        quoteStatuses: _selectedQuoteStatusIds.isEmpty ? null : _selectedQuoteStatusIds.map((i) => _quoteStatusOptions[i].value).toList(),
        soStatuses: _selectedSoStatusIds.isEmpty ? null : _selectedSoStatusIds.map((i) => _soStatusOptions[i].value).toList(),
      );
      setState(() {
        _reportData = rows;
        _hasGenerated = true;
        _pdfKey++;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSettingChanged() {
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
  }

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      final sheetName = isEnglish ? 'Quote-SO Status' : 'ติดตามสถานะ';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, _reportTitle, bold: true);
      _xlCell(s, 2, 0, '${isEnglish ? "Printed" : "พิมพ์"}: $ts');

      int r = 3;
      final headers = [
        isEnglish ? 'Quote No.' : 'ใบเสนอราคา', isEnglish ? 'Quote Date' : 'วันที่เสนอ',
        isEnglish ? 'Preparer' : 'ผู้จัดทำ', isEnglish ? 'Approver' : 'ผู้อนุมัติ', isEnglish ? 'Quote Status' : 'สถานะเสนอราคา',
        isEnglish ? 'SO No.' : 'ใบสั่งขาย', isEnglish ? 'SO Date' : 'วันที่สั่งขาย',
        isEnglish ? 'Preparer' : 'ผู้จัดทำ', isEnglish ? 'Approver' : 'ผู้อนุมัติ', isEnglish ? 'Order Status' : 'สถานะสั่งขาย',
        isEnglish ? 'Approved/Rejected Date' : 'วันที่อนุมัติ/ปฏิเสธ',
        isEnglish ? 'Quote to Order (days)' : 'เสนอราคาถึงสั่งขาย(วัน)',
        isEnglish ? 'Status After Approval' : 'สถานะหลังอนุมัติ',
        isEnglish ? 'Status Date' : 'วันที่สถานะ',
        isEnglish ? 'Quote to Latest Status (days)' : 'เสนอราคาถึงสถานะล่าสุด(วัน)',
      ];
      for (int c = 0; c < headers.length; c++) {
        _xlCell(s, r, c, headers[c], bg: hdrBg, bold: true);
      }
      r++;

      for (final row in _reportData) {
        final duration = row.durationDays;
        final decided = row.approvalOrRejectionDate;
        final afterStatus = row.afterApprovalStatus;
        final afterDate = row.afterApprovalStatusDate;
        final durationLatest = row.durationToLatestStatusDays;
        _xlCell(s, r, 0, row.quoteDocNo ?? '-');
        _xlCell(s, r, 1, row.quoteDocDate != null ? _dateFmt.format(row.quoteDocDate!) : '-');
        _xlCell(s, r, 2, row.quotePreparedByName ?? '-');
        _xlCell(s, r, 3, row.quoteApproverName ?? '-');
        _xlCell(s, r, 4, _statusLabel(_quoteStatusOptions, row.displayQuoteStatus, isEnglish));
        _xlCell(s, r, 5, row.soDocNo ?? '-');
        _xlCell(s, r, 6, row.soDocDate != null ? _dateFmt.format(row.soDocDate!) : '-');
        _xlCell(s, r, 7, row.soCreatedBy ?? '-');
        _xlCell(s, r, 8, row.soApproverName ?? '-');
        _xlCell(s, r, 9, _statusLabel(_soStatusOptions, row.displaySoStatus, isEnglish));
        _xlCell(s, r, 10, decided != null ? _dateFmt.format(decided) : '-');
        _xlCell(s, r, 11, duration == null ? '-' : DoubleCellValue(duration.toDouble()), align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 12, _afterApprovalLabel(afterStatus, isEnglish));
        _xlCell(s, r, 13, afterDate != null ? _dateFmt.format(afterDate) : '-');
        _xlCell(s, r, 14, durationLatest == null ? '-' : DoubleCellValue(durationLatest.toDouble()), align: HorizontalAlign.Right, bold: true);
        r++;
        if (_showQuoteItems) {
          for (final it in row.quoteItems) {
            _xlCell(s, r, 0, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', bg: detBg);
            _xlCell(s, r, 1, DoubleCellValue(it.qty), bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, r, 2, DoubleCellValue(it.price), bg: detBg, align: HorizontalAlign.Right);
            for (int c = 3; c < headers.length; c++) { _xlCell(s, r, c, '', bg: detBg); }
            r++;
          }
        }
        if (_showSoItems) {
          for (final it in row.soItems) {
            for (int c = 0; c < 5; c++) { _xlCell(s, r, c, '', bg: detBg); }
            _xlCell(s, r, 5, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', bg: detBg);
            _xlCell(s, r, 6, DoubleCellValue(it.qty), bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, r, 7, DoubleCellValue(it.price), bg: detBg, align: HorizontalAlign.Right);
            for (int c = 8; c < headers.length; c++) { _xlCell(s, r, c, '', bg: detBg); }
            r++;
          }
        }
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final fileTs = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, isEnglish ? 'Quote_SO_Status_Report_$fileTs.xlsx' : 'รายงานติดตามสถานะใบเสนอราคาใบสั่งขาย_$fileTs.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue ? v : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(backgroundColorHex: bg ?? ExcelColor.none, horizontalAlign: align ?? HorizontalAlign.Left, bold: bold);
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final reportTitle = _reportTitle.isNotEmpty ? _reportTitle : (isEnglish ? 'Quote / SO Status Report' : 'รายงานติดตามสถานะใบเสนอราคา/ใบสั่งขาย');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    // หมายเหตุ: เดิมใช้ fontItalic (THSarabun Italic) สำหรับบรรทัดรายละเอียดสินค้า แต่ฟอนต์ตัวเอียงไม่ครอบคลุม
    // สระ/วรรณยุกต์ไทยบางตัว ทำให้ชื่อสินค้าบางรายการแสดงเป็นสัญลักษณ์ผิด (เช่น "X") — เปลี่ยนมาใช้ฟอนต์ปกติ
    // สีเทาแทนเพื่อให้ยังดูแตกต่างจากแถวหลักแต่ไม่เสี่ยงกับฟอนต์ไม่ครบ
    pw.TextStyle tGrey(double fs) => pw.TextStyle(font: font, fontSize: fs, color: PdfColors.grey700);
    const mg = 20.0;
    final pageW = format.width - mg * 2;
    const cHeader = PdfColor(0.87, 0.94, 0.92);
    const cSubHeader = PdfColor(0.93, 0.93, 0.93);
    const cDetail = PdfColor(0.96, 0.96, 0.96);
    const cBorder = PdfColors.grey400;

    final cw = {
      'quoteNo': pageW * 0.085, 'quoteDate': pageW * 0.05, 'quotePrep': pageW * 0.07, 'quoteAppr': pageW * 0.07, 'quoteStatus': pageW * 0.06,
      'soNo': pageW * 0.085, 'soDate': pageW * 0.05, 'soPrep': pageW * 0.07, 'soAppr': pageW * 0.07, 'soStatus': pageW * 0.06,
      'decided': pageW * 0.065, 'duration': pageW * 0.055,
      'afterStatus': pageW * 0.075, 'afterDate': pageW * 0.06, 'durationLatest': pageW * 0.06,
    };
    const divider = 4.0;
    final quoteHalfW = cw['quoteNo']! + cw['quoteDate']! + cw['quotePrep']! + cw['quoteAppr']! + cw['quoteStatus']!;
    final soHalfW = cw['soNo']! + cw['soDate']! + cw['soPrep']! + cw['soAppr']! + cw['soStatus']!;

    pw.Widget cell(double w, String t, {bool bold = false, bool grey = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: bold ? tB(8) : (grey ? tGrey(8) : tN(8)), textAlign: a),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cHeader, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['quoteNo']!, isEnglish ? 'Quote No.' : 'ใบเสนอราคา', bold: true),
        cell(cw['quoteDate']!, isEnglish ? 'Quote Date' : 'วันที่เสนอ', bold: true),
        cell(cw['quotePrep']!, isEnglish ? 'Preparer' : 'ผู้จัดทำ', bold: true),
        cell(cw['quoteAppr']!, isEnglish ? 'Approver' : 'ผู้อนุมัติ', bold: true),
        cell(cw['quoteStatus']!, isEnglish ? 'Quote Status' : 'สถานะเสนอราคา', bold: true),
        pw.SizedBox(width: divider),
        cell(cw['soNo']!, isEnglish ? 'SO No.' : 'ใบสั่งขาย', bold: true),
        cell(cw['soDate']!, isEnglish ? 'SO Date' : 'วันที่สั่งขาย', bold: true),
        cell(cw['soPrep']!, isEnglish ? 'Preparer' : 'ผู้จัดทำ', bold: true),
        cell(cw['soAppr']!, isEnglish ? 'Approver' : 'ผู้อนุมัติ', bold: true),
        cell(cw['soStatus']!, isEnglish ? 'Order Status' : 'สถานะสั่งขาย', bold: true),
        cell(cw['decided']!, isEnglish ? 'Approved/\nRejected Date' : 'วันที่อนุมัติ/\nปฏิเสธ', bold: true, a: pw.TextAlign.right),
        cell(cw['duration']!, isEnglish ? 'Quote to\nOrder (days)' : 'เสนอราคาถึง\nสั่งขาย(วัน)', bold: true, a: pw.TextAlign.right),
        cell(cw['afterStatus']!, isEnglish ? 'Status After\nApproval' : 'สถานะ\nหลังอนุมัติ', bold: true),
        cell(cw['afterDate']!, isEnglish ? 'Status\nDate' : 'วันที่\nสถานะ', bold: true, a: pw.TextAlign.right),
        cell(cw['durationLatest']!, isEnglish ? 'Quote to Latest\nStatus (days)' : 'เสนอราคาถึงสถานะ\nล่าสุด(วัน)', bold: true, a: pw.TextAlign.right),
      ]),
    );

    // หัวคอลัมน์ของส่วนรายละเอียดสินค้า — แสดงเฉพาะตอนมีสวิตช์ฝั่งใดฝั่งหนึ่งเปิดอยู่ เพื่อบอกความหมายของ
    // คอลัมน์ที่ยุบรวมมาจากคอลัมน์หลัก (รหัส/ชื่อสินค้า, จำนวน, ราคา)
    final detailHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cSubHeader, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['quoteNo']! + cw['quoteDate']!, isEnglish ? 'Item Code / Name' : 'รหัส/ชื่อสินค้า', bold: true),
        cell(cw['quotePrep']!, isEnglish ? 'Qty' : 'จำนวน', bold: true, a: pw.TextAlign.right),
        cell(cw['quoteAppr']! + cw['quoteStatus']!, isEnglish ? 'Price' : 'ราคา', bold: true, a: pw.TextAlign.right),
        pw.SizedBox(width: divider),
        cell(cw['soNo']! + cw['soDate']!, isEnglish ? 'Item Code / Name' : 'รหัส/ชื่อสินค้า', bold: true),
        cell(cw['soPrep']!, isEnglish ? 'Qty' : 'จำนวน', bold: true, a: pw.TextAlign.right),
        cell(cw['soAppr']! + cw['soStatus']!, isEnglish ? 'Price' : 'ราคา', bold: true, a: pw.TextAlign.right),
        cell(cw['decided']!, '', bold: true),
        cell(cw['duration']!, '', bold: true),
        cell(cw['afterStatus']!, '', bold: true),
        cell(cw['afterDate']!, '', bold: true),
        cell(cw['durationLatest']!, '', bold: true),
      ]),
    );

    pw.Widget quoteItemRow(QuoteSoStatusReportItem it) => pw.Container(
          color: cDetail,
          child: pw.Row(children: [
            cell(cw['quoteNo']! + cw['quoteDate']!, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', grey: true),
            cell(cw['quotePrep']!, _fmtQty.format(it.qty), grey: true, a: pw.TextAlign.right),
            cell(cw['quoteAppr']! + cw['quoteStatus']!, _fmtValue.format(it.price), grey: true, a: pw.TextAlign.right),
            pw.SizedBox(width: divider),
            pw.SizedBox(width: soHalfW),
            pw.SizedBox(width: cw['decided']!),
            pw.SizedBox(width: cw['duration']!),
            pw.SizedBox(width: cw['afterStatus']!),
            pw.SizedBox(width: cw['afterDate']!),
            pw.SizedBox(width: cw['durationLatest']!),
          ]),
        );

    pw.Widget soItemRow(QuoteSoStatusReportItem it) => pw.Container(
          color: cDetail,
          child: pw.Row(children: [
            pw.SizedBox(width: quoteHalfW),
            pw.SizedBox(width: divider),
            cell(cw['soNo']! + cw['soDate']!, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', grey: true),
            cell(cw['soPrep']!, _fmtQty.format(it.qty), grey: true, a: pw.TextAlign.right),
            cell(cw['soAppr']! + cw['soStatus']!, _fmtValue.format(it.price), grey: true, a: pw.TextAlign.right),
            cell(cw['decided']!, ''),
            cell(cw['duration']!, ''),
            cell(cw['afterStatus']!, ''),
            cell(cw['afterDate']!, ''),
            cell(cw['durationLatest']!, ''),
          ]),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(mg),
      header: (ctx) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
          pw.Expanded(flex: 6, child: pw.Text(reportTitle, textAlign: pw.TextAlign.center, style: tB(15))),
          pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}', textAlign: pw.TextAlign.right, style: tN(10))),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.SizedBox()),
          pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName', textAlign: pw.TextAlign.right, style: tN(10))),
        ]),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.SizedBox()),
          pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr', textAlign: pw.TextAlign.right, style: tN(10))),
        ]),
        pw.SizedBox(height: 4),
        tableHeader,
        if (_showQuoteItems || _showSoItems) detailHeader,
      ]),
      build: (ctx) => _reportData.asMap().entries.expand((entry) {
        final i = entry.key;
        final row = entry.value;
        final duration = row.durationDays;
        final durationText = duration == null ? '-' : (isEnglish ? '$duration d' : '$duration วัน');
        final decided = row.approvalOrRejectionDate;
        final decidedText = decided != null ? _dateFmt.format(decided) : '-';
        final afterStatus = row.afterApprovalStatus;
        final afterDate = row.afterApprovalStatusDate;
        final durationLatest = row.durationToLatestStatusDays;
        final afterStatusText = _afterApprovalLabel(afterStatus, isEnglish);
        final afterDateText = afterDate != null ? _dateFmt.format(afterDate) : '-';
        final durationLatestText = durationLatest == null ? '-' : (isEnglish ? '$durationLatest d' : '$durationLatest วัน');
        final widgets = <pw.Widget>[
          pw.Container(
            decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : const PdfColor(0.98, 0.98, 0.98)),
            child: pw.Row(children: [
              cell(cw['quoteNo']!, row.quoteDocNo ?? '-'),
              cell(cw['quoteDate']!, row.quoteDocDate != null ? _dateFmt.format(row.quoteDocDate!) : '-'),
              cell(cw['quotePrep']!, row.quotePreparedByName ?? '-'),
              cell(cw['quoteAppr']!, row.quoteApproverName ?? '-'),
              cell(cw['quoteStatus']!, _statusLabel(_quoteStatusOptions, row.displayQuoteStatus, isEnglish)),
              pw.SizedBox(width: divider),
              cell(cw['soNo']!, row.soDocNo ?? '-'),
              cell(cw['soDate']!, row.soDocDate != null ? _dateFmt.format(row.soDocDate!) : '-'),
              cell(cw['soPrep']!, row.soCreatedBy ?? '-'),
              cell(cw['soAppr']!, row.soApproverName ?? '-'),
              cell(cw['soStatus']!, _statusLabel(_soStatusOptions, row.displaySoStatus, isEnglish)),
              cell(cw['decided']!, decidedText, a: pw.TextAlign.right),
              cell(cw['duration']!, durationText, bold: true, a: pw.TextAlign.right),
              cell(cw['afterStatus']!, afterStatusText),
              cell(cw['afterDate']!, afterDateText, a: pw.TextAlign.right),
              cell(cw['durationLatest']!, durationLatestText, bold: true, a: pw.TextAlign.right),
            ]),
          ),
        ];
        if (_showQuoteItems) widgets.addAll(row.quoteItems.map(quoteItemRow));
        if (_showSoItems) widgets.addAll(row.soItems.map(soItemRow));
        return widgets;
      }).toList(),
    ));
    return doc.save();
  }

  // ─── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Quote / SO Status Report' : 'รายงานติดตามสถานะใบเสนอราคา/ใบสั่งขาย'));

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: isEnglish ? 'Export Excel' : 'ส่งออก Excel',
              onPressed: (_reportData.isEmpty || !canExport) ? null : _exportExcel,
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              color: Colors.teal[800],
              child: IconButton(
                icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            AnimatedContainer(
              duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
              width: _isFilterExpanded ? _filterPanelWidth : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: _filterPanelWidth,
                  minWidth: _filterPanelWidth,
                  alignment: Alignment.topLeft,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),

                              Text(isEnglish ? 'Sale Quote' : 'ใบเสนอราคา',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal[800])),
                              Row(children: [
                                Expanded(child: Text(isEnglish ? 'Show Quote' : 'แสดงใบเสนอราคา', style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showQuote,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) => setState(() => _showQuote = v),
                                ),
                              ]),
                              Opacity(
                                opacity: _showQuote ? 1.0 : 0.4,
                                child: IgnorePointer(
                                  ignoring: !_showQuote,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Expanded(child: _dateField(isEnglish ? 'From' : 'ตั้งแต่', _quoteDateFrom, (d) => setState(() => _quoteDateFrom = d))),
                                      const SizedBox(width: 8),
                                      Expanded(child: _dateField(isEnglish ? 'To' : 'ถึง', _quoteDateTo, (d) => setState(() => _quoteDateTo = d))),
                                    ]),
                                    const SizedBox(height: 12),
                                    SearchMultiPicker<_StatusOption>(
                                      items: _quoteStatusOptions,
                                      selectedIds: _selectedQuoteStatusIds,
                                      idOf: (o) => o.id,
                                      labelOf: (o, en) => en ? o.labelEn : o.labelTh,
                                      searchTextOf: (o) => '${o.labelTh} ${o.labelEn} ${o.value}',
                                      onChanged: (v) => setState(() => _selectedQuoteStatusIds = v),
                                      labelTh: 'สถานะใบเสนอราคา', labelEn: 'Quote Status',
                                      allLabelTh: '— ทั้งหมด —', allLabelEn: '— All —',
                                    ),
                                    Row(children: [
                                      Expanded(child: Text(isEnglish ? 'Show Quote item details' : 'แสดงรายละเอียดสินค้าใบเสนอราคา', style: const TextStyle(fontSize: 13))),
                                      Switch(
                                        value: _showQuoteItems,
                                        activeColor: Colors.teal[800],
                                        onChanged: (v) { setState(() => _showQuoteItems = v); _onSettingChanged(); },
                                      ),
                                    ]),
                                  ]),
                                ),
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              Text(isEnglish ? 'Sale Order (SO)' : 'ใบสั่งขาย',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal[800])),
                              Row(children: [
                                Expanded(child: Text(isEnglish ? 'Show SO' : 'แสดงใบสั่งขาย', style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showSo,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) => setState(() => _showSo = v),
                                ),
                              ]),
                              Opacity(
                                opacity: _showSo ? 1.0 : 0.4,
                                child: IgnorePointer(
                                  ignoring: !_showSo,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Expanded(child: _dateField(isEnglish ? 'From' : 'ตั้งแต่', _soDateFrom, (d) => setState(() => _soDateFrom = d))),
                                      const SizedBox(width: 8),
                                      Expanded(child: _dateField(isEnglish ? 'To' : 'ถึง', _soDateTo, (d) => setState(() => _soDateTo = d))),
                                    ]),
                                    const SizedBox(height: 12),
                                    SearchMultiPicker<_StatusOption>(
                                      items: _soStatusOptions,
                                      selectedIds: _selectedSoStatusIds,
                                      idOf: (o) => o.id,
                                      labelOf: (o, en) => en ? o.labelEn : o.labelTh,
                                      searchTextOf: (o) => '${o.labelTh} ${o.labelEn} ${o.value}',
                                      onChanged: (v) => setState(() => _selectedSoStatusIds = v),
                                      labelTh: 'สถานะใบสั่งขาย', labelEn: 'SO Status',
                                      allLabelTh: '— ทั้งหมด —', allLabelEn: '— All —',
                                    ),
                                    Row(children: [
                                      Expanded(child: Text(isEnglish ? 'Show SO item details' : 'แสดงรายละเอียดสินค้าใบสั่งขาย', style: const TextStyle(fontSize: 13))),
                                      Switch(
                                        value: _showSoItems,
                                        activeColor: Colors.teal[800],
                                        onChanged: (v) { setState(() => _showSoItems = v); _onSettingChanged(); },
                                      ),
                                    ]),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _generate,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth);
                  }),
                  onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportData.isEmpty
                        ? Center(child: Text(
                            _hasGenerated
                                ? (isEnglish ? 'No data found for the selected conditions' : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก')
                                : (isEnglish ? 'Please select conditions and click Generate' : 'กรุณาเลือกเงื่อนไขและกดประมวลผล')))
                        : ZoomablePdfPreview(
                            documentVersion: _pdfKey,
                            build: (fmt) => _generatePdf(fmt),
                            initialPageFormat: PdfPageFormat.a4.landscape,
                            canChangeOrientation: false,
                            canDebug: false,
                            allowPrinting: canPrint,
                            allowSharing: canPrint,
                          ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null)
            InkWell(
              onTap: () => onPicked(null),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.clear, size: 14, color: Colors.grey)),
            ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) onPicked(picked);
            },
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.calendar_today, size: 14)),
          ),
        ]),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) onPicked(picked);
        },
        child: Text(value != null ? _dateFmt.format(value) : (_isEnglish ? '— Any —' : '— ไม่ระบุ —'),
            style: TextStyle(fontSize: 13, color: value != null ? Colors.black87 : Colors.black38)),
      ),
    );
  }
}
