// lib/po/screens/po_pr_po_status_report_screen.dart — ติดตามสถานะใบขอซื้อ(PR)/ใบสั่งซื้อ(PO) คู่กัน
// เงื่อนไข PR และ PO กรองอิสระจากกัน — PR ที่ตรงเงื่อนไขจะพา PO ที่แปลงมาจากมันมาแสดงด้วยเสมอไม่ว่า PO จะสถานะ
// อะไร ส่วนเงื่อนไข PO ใช้เลือกเฉพาะ PO ที่ไม่มีใบขอซื้ออ้างอิง (สั่งซื้อตรงไม่ผ่าน PR) เท่านั้น — ดู
// poPrPoStatusReportController.js สำหรับรายละเอียด query เต็ม รายงานนี้อ่านอย่างเดียว
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import '../widgets/po_search_multi_picker.dart';
import '../models/po_pr_po_status_report.dart';
import '../services/po_pr_po_status_report_service.dart';
import '../../utils/file_download.dart';

class _StatusOption {
  final int id;
  final String value;
  final String labelTh;
  final String labelEn;
  const _StatusOption(this.id, this.value, this.labelTh, this.labelEn);
}

const _prStatusOptions = [
  _StatusOption(0, 'Draft', 'ร่าง', 'Draft'),
  _StatusOption(1, 'Submitted', 'รออนุมัติ', 'Pending Approval'),
  _StatusOption(2, 'Approved', 'อนุมัติแล้ว', 'Approved'),
  _StatusOption(3, 'Rejected', 'ถูกปฏิเสธ', 'Rejected'),
  _StatusOption(4, 'PartiallyConverted', 'แปลงเป็นใบสั่งซื้อบางส่วน', 'Partially Converted'),
  _StatusOption(5, 'FullyConverted', 'แปลงเป็นใบสั่งซื้อครบแล้ว', 'Fully Converted'),
  _StatusOption(6, 'Closed', 'ปิดแล้ว', 'Closed'),
  _StatusOption(7, 'Void', 'ยกเลิก', 'Void'),
];

const _poStatusOptions = [
  _StatusOption(0, 'Draft', 'ร่าง', 'Draft'),
  _StatusOption(1, 'Approved', 'อนุมัติแล้ว', 'Approved'),
  _StatusOption(2, 'PartiallyReceived', 'รับสินค้าบางส่วน', 'Partially Received'),
  _StatusOption(3, 'FullyReceived', 'รับสินค้าครบแล้ว', 'Fully Received'),
  _StatusOption(4, 'Closed', 'ปิดแล้ว', 'Closed'),
  _StatusOption(5, 'Void', 'ยกเลิก', 'Void'),
];

String _statusLabel(List<_StatusOption> options, String? value, bool isEnglish) {
  if (value == null) return '-';
  final opt = options.where((o) => o.value == value);
  if (opt.isEmpty) return value;
  return isEnglish ? opt.first.labelEn : opt.first.labelTh;
}

class PrPoStatusReportScreen extends StatefulWidget {
  const PrPoStatusReportScreen({super.key});

  @override
  State<PrPoStatusReportScreen> createState() => _PrPoStatusReportScreenState();
}

class _PrPoStatusReportScreenState extends State<PrPoStatusReportScreen> {
  final _service = PrPoStatusReportService();
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

  DateTime? _prDateFrom;
  DateTime? _prDateTo;
  DateTime? _poDateFrom;
  DateTime? _poDateTo;
  List<int> _selectedPrStatusIds = [];
  List<int> _selectedPoStatusIds = [];
  bool _showPrItems = true;
  bool _showPoItems = true;

  List<PrPoStatusReportRow> _reportData = [];
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
        prDateFrom: _prDateFrom, prDateTo: _prDateTo,
        poDateFrom: _poDateFrom, poDateTo: _poDateTo,
        prStatuses: _selectedPrStatusIds.isEmpty ? null : _selectedPrStatusIds.map((i) => _prStatusOptions[i].value).toList(),
        poStatuses: _selectedPoStatusIds.isEmpty ? null : _selectedPoStatusIds.map((i) => _poStatusOptions[i].value).toList(),
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
      final sheetName = isEnglish ? 'PR-PO Status' : 'ติดตามสถานะ';
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
        isEnglish ? 'PR No.' : 'ใบขอซื้อ', isEnglish ? 'PR Date' : 'วันที่ขอ',
        isEnglish ? 'Requester' : 'ผู้ขอ', isEnglish ? 'Approver' : 'ผู้อนุมัติ', isEnglish ? 'PR Status' : 'สถานะใบขอซื้อ',
        isEnglish ? 'PO No.' : 'ใบสั่งซื้อ', isEnglish ? 'PO Date' : 'วันที่สั่ง',
        isEnglish ? 'Requester' : 'ผู้ขอ', isEnglish ? 'Approver' : 'ผู้อนุมัติ', isEnglish ? 'PO Status' : 'สถานะใบสั่งซื้อ',
      ];
      for (int c = 0; c < headers.length; c++) {
        _xlCell(s, r, c, headers[c], bg: hdrBg, bold: true);
      }
      r++;

      for (final row in _reportData) {
        _xlCell(s, r, 0, row.prDocNo ?? '-');
        _xlCell(s, r, 1, row.prDocDate != null ? _dateFmt.format(row.prDocDate!) : '-');
        _xlCell(s, r, 2, row.prRequestedByName ?? '-');
        _xlCell(s, r, 3, row.prApproverName ?? '-');
        _xlCell(s, r, 4, _statusLabel(_prStatusOptions, row.prStatus, isEnglish));
        _xlCell(s, r, 5, row.poDocNo ?? '-');
        _xlCell(s, r, 6, row.poDocDate != null ? _dateFmt.format(row.poDocDate!) : '-');
        _xlCell(s, r, 7, row.poCreatedBy ?? '-');
        _xlCell(s, r, 8, row.poApproverName ?? '-');
        _xlCell(s, r, 9, _statusLabel(_poStatusOptions, row.poStatus, isEnglish));
        r++;
        if (_showPrItems) {
          for (final it in row.prItems) {
            _xlCell(s, r, 0, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', bg: detBg);
            _xlCell(s, r, 1, DoubleCellValue(it.qty), bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, r, 2, DoubleCellValue(it.price), bg: detBg, align: HorizontalAlign.Right);
            for (int c = 3; c < headers.length; c++) { _xlCell(s, r, c, '', bg: detBg); }
            r++;
          }
        }
        if (_showPoItems) {
          for (final it in row.poItems) {
            for (int c = 0; c < 5; c++) { _xlCell(s, r, c, '', bg: detBg); }
            _xlCell(s, r, 5, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', bg: detBg);
            _xlCell(s, r, 6, DoubleCellValue(it.qty), bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, r, 7, DoubleCellValue(it.price), bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, r, 8, '', bg: detBg);
            _xlCell(s, r, 9, '', bg: detBg);
            r++;
          }
        }
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final fileTs = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, isEnglish ? 'PR_PO_Status_Report_$fileTs.xlsx' : 'รายงานติดตามสถานะใบขอซื้อใบสั่งซื้อ_$fileTs.xlsx');
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
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final reportTitle = _reportTitle.isNotEmpty ? _reportTitle : (isEnglish ? 'PR / PO Status Report' : 'รายงานติดตามสถานะใบขอซื้อ/ใบสั่งซื้อ');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    pw.TextStyle tI(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);
    const mg = 20.0;
    final pageW = format.width - mg * 2;
    const cHeader = PdfColor(0.87, 0.94, 0.92);
    const cDetail = PdfColor(0.96, 0.96, 0.96);
    const cBorder = PdfColors.grey400;

    final cw = {
      'prNo': pageW * 0.12, 'prDate': pageW * 0.07, 'prReq': pageW * 0.095, 'prAppr': pageW * 0.095, 'prStatus': pageW * 0.08,
      'poNo': pageW * 0.12, 'poDate': pageW * 0.07, 'poReq': pageW * 0.095, 'poAppr': pageW * 0.095, 'poStatus': pageW * 0.08,
    };
    const divider = 4.0;
    final prHalfW = cw['prNo']! + cw['prDate']! + cw['prReq']! + cw['prAppr']! + cw['prStatus']!;
    final poHalfW = cw['poNo']! + cw['poDate']! + cw['poReq']! + cw['poAppr']! + cw['poStatus']!;

    pw.Widget cell(double w, String t, {bool bold = false, bool italic = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: bold ? tB(8) : (italic ? tI(8) : tN(8)), textAlign: a),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cHeader, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['prNo']!, isEnglish ? 'PR No.' : 'ใบขอซื้อ', bold: true),
        cell(cw['prDate']!, isEnglish ? 'PR Date' : 'วันที่ขอ', bold: true),
        cell(cw['prReq']!, isEnglish ? 'Requester' : 'ผู้ขอ', bold: true),
        cell(cw['prAppr']!, isEnglish ? 'Approver' : 'ผู้อนุมัติ', bold: true),
        cell(cw['prStatus']!, isEnglish ? 'Status' : 'สถานะ', bold: true),
        pw.SizedBox(width: divider),
        cell(cw['poNo']!, isEnglish ? 'PO No.' : 'ใบสั่งซื้อ', bold: true),
        cell(cw['poDate']!, isEnglish ? 'PO Date' : 'วันที่สั่ง', bold: true),
        cell(cw['poReq']!, isEnglish ? 'Requester' : 'ผู้ขอ', bold: true),
        cell(cw['poAppr']!, isEnglish ? 'Approver' : 'ผู้อนุมัติ', bold: true),
        cell(cw['poStatus']!, isEnglish ? 'Status' : 'สถานะ', bold: true),
      ]),
    );

    pw.Widget prItemRow(PrPoStatusReportItem it) => pw.Container(
          color: cDetail,
          child: pw.Row(children: [
            cell(cw['prNo']! + cw['prDate']!, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', italic: true),
            cell(cw['prReq']!, _fmtQty.format(it.qty), italic: true, a: pw.TextAlign.right),
            cell(cw['prAppr']! + cw['prStatus']!, _fmtValue.format(it.price), italic: true, a: pw.TextAlign.right),
            pw.SizedBox(width: divider),
            pw.SizedBox(width: poHalfW),
          ]),
        );

    pw.Widget poItemRow(PrPoStatusReportItem it) => pw.Container(
          color: cDetail,
          child: pw.Row(children: [
            pw.SizedBox(width: prHalfW),
            pw.SizedBox(width: divider),
            cell(cw['poNo']! + cw['poDate']!, '   ${it.itemCode ?? ''} ${it.itemName ?? ''}', italic: true),
            cell(cw['poReq']!, _fmtQty.format(it.qty), italic: true, a: pw.TextAlign.right),
            cell(cw['poAppr']! + cw['poStatus']!, _fmtValue.format(it.price), italic: true, a: pw.TextAlign.right),
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
      ]),
      build: (ctx) => _reportData.asMap().entries.expand((entry) {
        final i = entry.key;
        final row = entry.value;
        final widgets = <pw.Widget>[
          pw.Container(
            decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : const PdfColor(0.98, 0.98, 0.98)),
            child: pw.Row(children: [
              cell(cw['prNo']!, row.prDocNo ?? '-'),
              cell(cw['prDate']!, row.prDocDate != null ? _dateFmt.format(row.prDocDate!) : '-'),
              cell(cw['prReq']!, row.prRequestedByName ?? '-'),
              cell(cw['prAppr']!, row.prApproverName ?? '-'),
              cell(cw['prStatus']!, _statusLabel(_prStatusOptions, row.prStatus, isEnglish)),
              pw.SizedBox(width: divider),
              cell(cw['poNo']!, row.poDocNo ?? '-'),
              cell(cw['poDate']!, row.poDocDate != null ? _dateFmt.format(row.poDocDate!) : '-'),
              cell(cw['poReq']!, row.poCreatedBy ?? '-'),
              cell(cw['poAppr']!, row.poApproverName ?? '-'),
              cell(cw['poStatus']!, _statusLabel(_poStatusOptions, row.poStatus, isEnglish)),
            ]),
          ),
        ];
        if (_showPrItems) widgets.addAll(row.prItems.map(prItemRow));
        if (_showPoItems) widgets.addAll(row.poItems.map(poItemRow));
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
        : (perm?.menuName ?? (isEnglish ? 'PR / PO Status Report' : 'รายงานติดตามสถานะใบขอซื้อ/ใบสั่งซื้อ'));

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

                              Text(isEnglish ? 'Purchase Requisition (PR)' : 'ใบขอซื้อ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal[800])),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _dateField(isEnglish ? 'From' : 'ตั้งแต่', _prDateFrom, (d) => setState(() => _prDateFrom = d))),
                                const SizedBox(width: 8),
                                Expanded(child: _dateField(isEnglish ? 'To' : 'ถึง', _prDateTo, (d) => setState(() => _prDateTo = d))),
                              ]),
                              const SizedBox(height: 12),
                              SearchMultiPicker<_StatusOption>(
                                items: _prStatusOptions,
                                selectedIds: _selectedPrStatusIds,
                                idOf: (o) => o.id,
                                labelOf: (o, en) => en ? o.labelEn : o.labelTh,
                                searchTextOf: (o) => '${o.labelTh} ${o.labelEn} ${o.value}',
                                onChanged: (v) => setState(() => _selectedPrStatusIds = v),
                                labelTh: 'สถานะใบขอซื้อ', labelEn: 'PR Status',
                                allLabelTh: '— ทั้งหมด —', allLabelEn: '— All —',
                              ),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              Text(isEnglish ? 'Purchase Order (PO)' : 'ใบสั่งซื้อ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal[800])),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _dateField(isEnglish ? 'From' : 'ตั้งแต่', _poDateFrom, (d) => setState(() => _poDateFrom = d))),
                                const SizedBox(width: 8),
                                Expanded(child: _dateField(isEnglish ? 'To' : 'ถึง', _poDateTo, (d) => setState(() => _poDateTo = d))),
                              ]),
                              const SizedBox(height: 12),
                              SearchMultiPicker<_StatusOption>(
                                items: _poStatusOptions,
                                selectedIds: _selectedPoStatusIds,
                                idOf: (o) => o.id,
                                labelOf: (o, en) => en ? o.labelEn : o.labelTh,
                                searchTextOf: (o) => '${o.labelTh} ${o.labelEn} ${o.value}',
                                onChanged: (v) => setState(() => _selectedPoStatusIds = v),
                                labelTh: 'สถานะใบสั่งซื้อ', labelEn: 'PO Status',
                                allLabelTh: '— ทั้งหมด —', allLabelEn: '— All —',
                              ),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              Row(children: [
                                Expanded(child: Text(isEnglish ? 'Show PR item details' : 'แสดงรายละเอียดสินค้าใบขอซื้อ', style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showPrItems,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) { setState(() => _showPrItems = v); _onSettingChanged(); },
                                ),
                              ]),
                              Row(children: [
                                Expanded(child: Text(isEnglish ? 'Show PO item details' : 'แสดงรายละเอียดสินค้าใบสั่งซื้อ', style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showPoItems,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) { setState(() => _showPoItems = v); _onSettingChanged(); },
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
