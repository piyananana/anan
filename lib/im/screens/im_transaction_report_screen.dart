import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../services/im_transaction_report_service.dart';
import '../../utils/file_download.dart';

// ---------------------------------------------------------------------------
// sys_doc_type family — ตัดสินว่าบรรทัดรายละเอียด item ของเอกสารประเภทนี้ควรมีหัวคอลัมน์แบบไหน และคอลัมน์
// "ผู้ซื้อ/ผู้ขาย" ของหัวเอกสารควรโชว์ vendor หรือ customer (หรือไม่โชว์เลย) — มิเรอร์แนวคิดเดียวกับ
// resolveCounterAccount/_journalSections ที่ตัดสินพฤติกรรมจาก sys_doc_type เสมอ ไม่ใช่ doc_code
// (ดู pattern_sys_doc_type_vs_doc_code) กลุ่ม: generic (AJS/ISS/TRF, ไม่มีคู่ค้า) / purchase (GRN + AP CN/DN,
// โชว์ผู้ขาย+ต้นทุน) / sales (DLN + AR CN/DN, โชว์ลูกค้า+ราคาขาย)
enum _Family { generic, purchase, sales }

_Family _familyOf(String sdt) {
  if (['10', '11', '12', '15', '20', '25'].contains(sdt)) return _Family.purchase;
  if (['30', '31', '32', '35', '40', '45'].contains(sdt)) return _Family.sales;
  return _Family.generic; // '60' ISS, '70' TRF, '80' AJS
}

// ประเภทเอกสารที่มี VAT ต่อบรรทัด (ดู pattern_im_vat_feature) — '10'/'30' ไม่มีเพราะ Post บัญชีของ IM เองแยกจาก AP/AR
bool _isVatType(String sdt) => ['11', '12', '15', '20', '25', '31', '32', '35', '40', '45'].contains(sdt);

class ImTransactionReportScreen extends StatefulWidget {
  const ImTransactionReportScreen({super.key});

  @override
  State<ImTransactionReportScreen> createState() => _ImTransactionReportScreenState();
}

class _ImTransactionReportScreenState extends State<ImTransactionReportScreen> {
  final _reportService  = ImTransactionReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();

  bool   _isEnglish        = false;
  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey           = 0;
  bool   _isExporting      = false;

  Company? _company;
  Map<String, String>? _headers;

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<String> _selectedSysDocTypes = [];
  String _sort = 'asc'; // 'asc' | 'desc' — เรียงตามวันที่เอกสาร
  bool   _showDetail = false;

  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    _headers = await _authService.getAuthHeader();
    _company = await _companyService.fetchCompany();
    if (mounted) setState(() {});
  }

  // ─── report ───────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getTransactionReport(
        dateFrom:    DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:      DateFormat('yyyy-MM-dd').format(_dateTo),
        sysDocTypes: _selectedSysDocTypes,
        sort:        _sort,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No data found for the selected date range'
                : 'ไม่พบข้อมูลในช่วงวันที่ที่เลือก')));
      }
      setState(() { _reportData = raw; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSettingChanged() {
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
  }

  // ─── shared value helpers ─────────────────────────────────────────────────

  String _docTypeName(Map<String, dynamic> h, bool isEnglish) {
    final en = h['doc_name_eng'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (h['doc_name_thai'] as String? ?? '');
  }

  String _partyName(Map<String, dynamic> h) {
    final sdt = h['sys_doc_type'] as String? ?? '';
    switch (_familyOf(sdt)) {
      case _Family.purchase:
        final code = h['vendor_code'] as String? ?? '';
        final name = h['vendor_name_th'] as String? ?? '';
        return [code, name].where((s) => s.isNotEmpty).join('  ');
      case _Family.sales:
        final code = h['customer_code'] as String? ?? '';
        final name = h['customer_name_th'] as String? ?? '';
        return [code, name].where((s) => s.isNotEmpty).join('  ');
      case _Family.generic:
        return '';
    }
  }

  String _refNo(Map<String, dynamic> h) {
    final r = (h['ref_no'] as String? ?? '').trim();
    if (r.isNotEmpty) return r;
    return (h['ref_doc_no'] as String? ?? '').trim();
  }

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy').format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine = '${isEnglish ? "Date range" : "ช่วงวันที่"} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
    if (_selectedSysDocTypes.isNotEmpty) {
      final names = _selectedSysDocTypes.map((sdt) => imSysDocType[sdt] ?? sdt).join(', ');
      conditions.add('${isEnglish ? "Document Types" : "ประเภทเอกสาร"}: $names');
    } else {
      conditions.add(isEnglish ? 'Document Types: All' : 'ประเภทเอกสาร: ทั้งหมด');
    }
    conditions.add(_sort == 'desc'
        ? (isEnglish ? 'Sorted: newest first' : 'เรียง: ล่าสุด-เก่าสุด')
        : (isEnglish ? 'Sorted: oldest first' : 'เรียง: เก่าสุด-ล่าสุด'));
    if (_showDetail) conditions.add(isEnglish ? 'Show item details' : 'แสดงรายละเอียดสินค้า');
    final conditionLine = conditions.join(' | ');

    const mg = 20.0;
    final pageW = format.width - mg * 2;

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    pw.TextStyle tI(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cDetail = PdfColor(0.94, 0.94, 0.94);
    const cTotal  = PdfColor(0.75, 0.88, 0.96);
    const cBorder = PdfColors.grey400;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final fmtQty = NumberFormat('#,##0.####', 'en_US');

    // ─── หัวเอกสาร: 6 คอลัมน์ตามที่ผู้ใช้กำหนด ─────────────────────────────────
    final hw = {
      'date':   pageW * 0.09,
      'type':   pageW * 0.16,
      'docNo':  pageW * 0.13,
      'refNo':  pageW * 0.13,
      'party':  pageW * 0.28,
      'amount': pageW * 0.21,
    };

    pw.Widget hBox(double w, String t, pw.TextAlign a) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: tB(9), textAlign: a),
          ),
        );

    final headerRowWidget = pw.Container(
      decoration: const pw.BoxDecoration(color: cGreen, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        hBox(hw['date']!,   isEnglish ? 'Date'          : 'วันที่เอกสาร',   pw.TextAlign.left),
        hBox(hw['type']!,   isEnglish ? 'Document Type' : 'ประเภท/ชื่อเอกสาร', pw.TextAlign.left),
        hBox(hw['docNo']!,  isEnglish ? 'Doc No.'       : 'เลขที่เอกสาร',   pw.TextAlign.left),
        hBox(hw['refNo']!,  isEnglish ? 'Ref No.'       : 'เลขที่อ้างอิง',   pw.TextAlign.left),
        hBox(hw['party']!,  isEnglish ? 'Vendor/Customer' : 'ผู้ซื้อ/ผู้ขาย', pw.TextAlign.left),
        hBox(hw['amount']!, isEnglish ? 'Amount'        : 'ยอดรวม',       pw.TextAlign.right),
      ]),
    );

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
        pw.Expanded(flex: 6, child: pw.Text(isEnglish ? 'IM Transaction Report' : 'รายงานธุรกรรมสินค้าคงคลัง',
            textAlign: pw.TextAlign.center, style: tB(15))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.Text(dateRangeLine, textAlign: pw.TextAlign.center, style: tN(10))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.Text('* $conditionLine', style: tN(9))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 4),
      headerRowWidget,
    ]);

    // ─── รายละเอียด item ต่อบรรทัด — หัวคอลัมน์ต่างกันตาม family ของ sys_doc_type เอกสารนั้นๆ ────────
    List<MapEntry<String, double>> detailCols(_Family fam, bool vat) {
      switch (fam) {
        case _Family.generic:
          return [
            MapEntry(isEnglish ? 'Item' : 'สินค้า', 0.32),
            MapEntry(isEnglish ? 'Unit' : 'หน่วย', 0.10),
            MapEntry(isEnglish ? 'Qty' : 'จำนวน', 0.14),
            MapEntry(isEnglish ? 'Unit Cost' : 'ต้นทุน/หน่วย', 0.14),
            MapEntry(isEnglish ? 'Value' : 'มูลค่า', 0.15),
            MapEntry(isEnglish ? 'Location' : 'ตำแหน่ง', 0.15),
          ];
        case _Family.purchase:
          return [
            MapEntry(isEnglish ? 'Item' : 'สินค้า', 0.28),
            MapEntry(isEnglish ? 'Unit' : 'หน่วย', 0.08),
            MapEntry(isEnglish ? 'Qty' : 'จำนวน', 0.12),
            MapEntry(isEnglish ? 'Unit Cost' : 'ต้นทุน/หน่วย', 0.13),
            MapEntry(isEnglish ? 'Billed Cost' : 'ต้นทุนตามใบกำกับ', 0.13),
            if (vat) MapEntry('VAT', 0.12),
            MapEntry(isEnglish ? 'Value' : 'มูลค่า', vat ? 0.14 : 0.26),
          ];
        case _Family.sales:
          return [
            MapEntry(isEnglish ? 'Item' : 'สินค้า', 0.30),
            MapEntry(isEnglish ? 'Unit' : 'หน่วย', 0.08),
            MapEntry(isEnglish ? 'Qty' : 'จำนวน', 0.14),
            MapEntry(isEnglish ? 'Unit Price' : 'ราคาขาย/หน่วย', 0.16),
            if (vat) MapEntry('VAT', 0.14),
            MapEntry(isEnglish ? 'Value' : 'มูลค่า', vat ? 0.18 : 0.32),
          ];
      }
    }

    List<String> detailValues(_Family fam, bool vat, Map<String, dynamic> l) {
      final itemLabel = '${l['item_code'] ?? ''} ${l['item_name'] ?? ''}';
      final uom = l['uom_code']?.toString() ?? '';
      final qty = fmtQty.format((l['qty'] as num?) ?? 0);
      final value = fmt.format((l['total_value_lc'] as num?) ?? 0);
      final vatCell = (l['vat_type'] == null || l['vat_type'] == 'NOVAT')
          ? '-'
          : '${l['vat_type']}  ${l['vat_rate']}%';
      switch (fam) {
        case _Family.generic:
          final loc = l['location_code']?.toString() ?? '';
          final toLoc = l['to_location_code']?.toString() ?? '';
          final locCell = toLoc.isNotEmpty ? '$loc → $toLoc' : loc;
          return [itemLabel, uom, qty, fmt.format((l['unit_cost'] as num?) ?? 0), value, locCell];
        case _Family.purchase:
          final billed = l['billed_unit_cost'] != null ? fmt.format((l['billed_unit_cost'] as num?) ?? 0) : '';
          return [
            itemLabel, uom, qty, fmt.format((l['unit_cost'] as num?) ?? 0), billed,
            if (vat) vatCell,
            value,
          ];
        case _Family.sales:
          return [
            itemLabel, uom, qty, fmt.format((l['unit_price'] as num?) ?? 0),
            if (vat) vatCell,
            value,
          ];
      }
    }

    pw.Widget buildDetailTable(String sdt, List<dynamic> lines) {
      final fam = _familyOf(sdt);
      final vat = _isVatType(sdt);
      final cols = detailCols(fam, vat);
      final detailW = pageW - 24; // เยื้องซ้ายเล็กน้อยให้เห็นว่าเป็นรายละเอียดของเอกสารด้านบน

      pw.Widget cell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
            width: w,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
              child: pw.Text(t, style: bold ? tB(8) : tI(8), textAlign: a),
            ),
          );

      final rows = <pw.Widget>[
        pw.Container(
          color: cDetail,
          child: pw.Row(children: [
            for (final c in cols) cell(detailW * c.value, c.key, bold: true, a: c.key == (isEnglish ? 'Qty' : 'จำนวน') || c.key.contains('Value') || c.key.contains('มูลค่า') || c.key.contains('Cost') || c.key.contains('Price') || c.key.contains('ต้นทุน') || c.key.contains('ราคา') ? pw.TextAlign.right : pw.TextAlign.left),
          ]),
        ),
      ];
      for (final raw in lines) {
        final l = raw as Map<String, dynamic>;
        final vals = detailValues(fam, vat, l);
        rows.add(pw.Row(children: [
          for (int i = 0; i < cols.length; i++)
            cell(detailW * cols[i].value, vals[i], a: i == 0 ? pw.TextAlign.left : pw.TextAlign.right),
        ]));
      }
      return pw.Container(
        margin: const pw.EdgeInsets.only(left: 24, bottom: 3),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows),
      );
    }

    // ─── Build content ────────────────────────────────────────────────────────
    final content = <pw.Widget>[];
    int idx = 0;
    for (final h in _reportData) {
      final sdt = h['sys_doc_type'] as String? ?? '';
      final bg = idx.isOdd ? cStripe : null;
      final desc = (h['description'] as String? ?? '').trim();
      final amount = (h['total_value_lc'] as num?)?.toDouble() ?? 0;

      content.add(pw.Container(
        color: bg,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [
            hBox(hw['date']!,   _fmtDate(h['doc_date'] as String?), pw.TextAlign.left),
            hBox(hw['type']!,   '${h['doc_code'] ?? ''}  ${_docTypeName(h, isEnglish)}', pw.TextAlign.left),
            hBox(hw['docNo']!,  h['doc_no'] as String? ?? '', pw.TextAlign.left),
            hBox(hw['refNo']!,  _refNo(h), pw.TextAlign.left),
            hBox(hw['party']!,  _partyName(h), pw.TextAlign.left),
            hBox(hw['amount']!, fmt.format(amount), pw.TextAlign.right),
          ]),
          if (desc.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 3, bottom: 2),
              child: pw.Text('${isEnglish ? "Remark" : "หมายเหตุ"}: $desc', style: tI(8.5)),
            ),
        ]),
      ));

      if (_showDetail) {
        final lines = h['lines'] as List? ?? [];
        if (lines.isNotEmpty) content.add(buildDetailTable(sdt, lines));
      }
      idx++;
    }

    // Grand total — นับจำนวนเอกสารเท่านั้น ไม่รวมมูลค่าสุทธิ เพราะ total_value_lc มีเครื่องหมายต่างกันไปตาม
    // ทิศทางการเคลื่อนไหวของแต่ละประเภทเอกสาร (รับเข้า=บวก, จ่ายออก=ลบ) รวมกันแล้วไม่สื่อความหมายเป็นยอดเดียว
    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: pw.Text(
          isEnglish ? 'Grand total ${_reportData.length} document(s)' : 'รวมทั้งสิ้น ${_reportData.length} เอกสาร',
          style: tB(9)),
    ));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(mg),
        header: pageHeader(),
        build: (ctx) => content,
      ),
    );

    return doc.save();
  }

  // ─── Excel ────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      const sheet = 'Transaction';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, isEnglish ? 'IM Transaction Report' : 'รายงานธุรกรรมสินค้าคงคลัง', bold: true);
      _xl(s, 2, 0,
          '${isEnglish ? "Date range" : "ช่วงวันที่"}: ${DateFormat("dd/MM/yyyy").format(_dateFrom)} – ${DateFormat("dd/MM/yyyy").format(_dateTo)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      final hdrs = isEnglish
          ? ['Date', 'Document Type', 'Doc No.', 'Ref No.', 'Vendor/Customer', 'Amount']
          : ['วันที่เอกสาร', 'ประเภท/ชื่อเอกสาร', 'เลขที่เอกสาร', 'เลขที่อ้างอิง', 'ผู้ซื้อ/ผู้ขาย', 'ยอดรวม'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      for (final h in _reportData) {
        final amount = (h['total_value_lc'] as num?)?.toDouble() ?? 0;
        _xl(s, row, 0, _fmtDate(h['doc_date'] as String?));
        _xl(s, row, 1, '${h['doc_code'] ?? ''}  ${_docTypeName(h, isEnglish)}');
        _xl(s, row, 2, h['doc_no'] as String? ?? '');
        _xl(s, row, 3, _refNo(h));
        _xl(s, row, 4, _partyName(h));
        _xl(s, row, 5, amount, align: HorizontalAlign.Right);
        row++;

        final desc = (h['description'] as String? ?? '').trim();
        if (desc.isNotEmpty) {
          _xl(s, row, 0, '${isEnglish ? "Remark" : "หมายเหตุ"}: $desc');
          row++;
        }

        if (_showDetail) {
          final lines = (h['lines'] as List? ?? []).cast<Map<String, dynamic>>();
          final fam = _familyOf(h['sys_doc_type'] as String? ?? '');
          for (final l in lines) {
            final unitVal = fam == _Family.sales ? (l['unit_price'] as num?) : (l['unit_cost'] as num?);
            _xl(s, row, 0, '   ${l['item_code'] ?? ''} ${l['item_name'] ?? ''}', bg: detBg);
            _xl(s, row, 1, l['uom_code']?.toString() ?? '', bg: detBg);
            _xl(s, row, 2, (l['qty'] as num?)?.toDouble() ?? 0, bg: detBg, align: HorizontalAlign.Right);
            _xl(s, row, 3, unitVal?.toDouble() ?? 0, bg: detBg, align: HorizontalAlign.Right);
            _xl(s, row, 4, (l['vat_type'] == null || l['vat_type'] == 'NOVAT') ? '' : '${l['vat_type']} ${l['vat_rate']}%', bg: detBg);
            _xl(s, row, 5, (l['total_value_lc'] as num?)?.toDouble() ?? 0, bg: detBg, align: HorizontalAlign.Right);
            row++;
          }
        }
      }

      _xl(s, row, 0,
          isEnglish ? 'Grand total ${_reportData.length} document(s)' : 'รวมทั้งสิ้น ${_reportData.length} เอกสาร',
          bg: totBg, bold: true);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'IM_Transaction_Report' : 'รายงานธุรกรรมสินค้าคงคลัง';
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${title}_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xl(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  Widget _buildDateField({required String label, required DateTime date, required void Function(DateTime) onPick}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.calendar_today, size: 16)),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }

  Future<void> _pickSysDocTypes() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiPickerDialog<MapEntry<String, String>>(
        title: isEnglish ? 'Select Document Types' : 'เลือกประเภทเอกสาร',
        items: imSysDocType.entries.toList(),
        selected: _selectedSysDocTypes,
        idOf: (e) => e.key,
        labelOf: (e) => e.value,
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedSysDocTypes = result);
  }

  Widget _buildMultiField({required String label, required int count, required String allLabel, required VoidCallback onTap, required VoidCallback onClear}) {
    final hasValue = count > 0;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onTap, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_drop_down, size: 20))),
        ]),
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          hasValue ? (_isEnglish ? '$count selected' : 'เลือก $count รายการ') : allLabel,
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
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
                tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse Filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand Filter' : 'ขยายเงื่อนไข'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            AnimatedContainer(
              duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
              width: _isFilterExpanded ? _filterPanelWidth : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: _filterPanelWidth, minWidth: _filterPanelWidth,
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
                              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),

                              _buildDateField(label: isEnglish ? 'Document Date From' : 'วันที่เอกสาร ตั้งแต่', date: _dateFrom, onPick: (d) => setState(() => _dateFrom = d)),
                              const SizedBox(height: 12),
                              _buildDateField(label: isEnglish ? 'Document Date To' : 'วันที่เอกสาร ถึง', date: _dateTo, onPick: (d) => setState(() => _dateTo = d)),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildMultiField(
                                label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
                                count: _selectedSysDocTypes.length,
                                allLabel: isEnglish ? '— All Types —' : '— ทุกประเภท —',
                                onTap: _pickSysDocTypes,
                                onClear: () => setState(() => _selectedSysDocTypes = []),
                              ),
                              if (_selectedSysDocTypes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4, runSpacing: 2,
                                  children: _selectedSysDocTypes.map((sdt) => Chip(
                                    label: Text(imSysDocType[sdt] ?? sdt, style: const TextStyle(fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.teal[50],
                                    side: BorderSide(color: Colors.teal[200]!),
                                  )).toList(),
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                value: _sort,
                                decoration: InputDecoration(labelText: isEnglish ? 'Sort By Document Date' : 'การจัดเรียง (วันที่เอกสาร)', border: const OutlineInputBorder(), isDense: true),
                                items: [
                                  DropdownMenuItem(value: 'asc', child: Text(isEnglish ? 'Oldest → Newest' : 'เก่าสุด → ล่าสุด')),
                                  DropdownMenuItem(value: 'desc', child: Text(isEnglish ? 'Newest → Oldest' : 'ล่าสุด → เก่าสุด')),
                                ],
                                onChanged: (v) { if (v != null) { setState(() => _sort = v); _onSettingChanged(); } },
                              ),
                              const SizedBox(height: 8),

                              Row(children: [
                                Expanded(child: Text(isEnglish ? 'Show Item Details' : 'แสดงรายละเอียดสินค้า', style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showDetail,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) { setState(() => _showDetail = v); _onSettingChanged(); },
                                ),
                              ]),
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
                            onPressed: _isLoading ? null : _generateReport,
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
                  onHorizontalDragUpdate: (d) => setState(() => _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth)),
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
                        ? Center(child: Text(isEnglish ? 'Select conditions and click Generate Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                        : PdfPreview(
                            key: ValueKey(_pdfKey),
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
}

// ---------------------------------------------------------------------------
// Generic multi-select picker dialog — มิเรอร์ตัวเดียวกับ im_item_report_screen.dart (ทำซ้ำในไฟล์นี้ตาม
// convention เดิม ไม่ใช้ shared widget — ดู pattern_master_report_screen)
// ---------------------------------------------------------------------------
class _MultiPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<String> selected;
  final String Function(T) idOf;
  final String Function(T) labelOf;
  final bool isEnglish;

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.isEnglish,
  });

  @override
  State<_MultiPickerDialog<T>> createState() => _MultiPickerDialogState<T>();
}

class _MultiPickerDialogState<T> extends State<_MultiPickerDialog<T>> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: ListView(
              children: widget.items.map((item) {
                final id = widget.idOf(item);
                return CheckboxListTile(
                  dense: true,
                  title: Text(widget.labelOf(item), style: const TextStyle(fontSize: 13)),
                  value: _selected.contains(id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == widget.items.length) {
                      _selected = [];
                    } else {
                      _selected = widget.items.map((e) => widget.idOf(e)).toList();
                    }
                  });
                },
                child: Text(_selected.length == widget.items.length
                    ? (widget.isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด')
                    : (widget.isEnglish ? 'Select All' : 'เลือกทั้งหมด')),
              ),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isEnglish ? 'Cancel' : 'ยกเลิก')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                  child: Text(widget.isEnglish ? 'OK' : 'ตกลง'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
