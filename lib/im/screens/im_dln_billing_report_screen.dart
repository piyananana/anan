// lib/im/screens/im_dln_billing_report_screen.dart
//
// Review report for sys_doc_type='32' (ส่งสินค้า รอตั้งหนี้): shows Delivered documents whose
// COGS has posted but AR revenue has not (accrual gap) and Posted documents showing the actual
// billed revenue. Structure mirrors lib/im/screens/im_gr_billing_report_screen.dart (collapsible/
// draggable filter panel, live PDF preview, Excel export). Unlike the GR billing report, there is
// no "variance" column here — unit_price is a single column, edited in place before Post, so
// there's no separate before/after value preserved once posted.

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../utils/date_utils.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/im_dln_billing_report.dart';
import '../services/im_transaction_service.dart';
import '../models/im_warehouse.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';

class ImDlnBillingReportScreen extends StatefulWidget {
  const ImDlnBillingReportScreen({super.key});

  @override
  State<ImDlnBillingReportScreen> createState() => _ImDlnBillingReportScreenState();
}

class _ImDlnBillingReportScreenState extends State<ImDlnBillingReportScreen> {
  final ImTransactionService _reportService = ImTransactionService();
  final CompanyService       _companyService = CompanyService();
  final AuthService          _authService    = AuthService();

  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;
  bool   _isEnglish         = false;

  Company? _company;
  Map<String, String>? _headers;

  DateTime  _asOfDate  = DateTime.now();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int?      _warehouseId;
  String?   _warehouseLabel;
  int?      _customerId;
  String?   _customerLabel;
  String    _statusFilter = 'all'; // 'all' | 'Delivered' | 'Posted'

  List<ImDlnBillingReportCustomer> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  // ─── data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadMasterData() async {
    _headers = await _authService.getAuthHeader();
    _company = await _companyService.fetchCompany();
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final data = await _reportService.fetchDlnBillingReport(
        asOfDate:    formatLocalDate(_asOfDate),
        warehouseId: _warehouseId,
        customerId:  _customerId,
        dateFrom:    _dateFrom != null ? formatLocalDate(_dateFrom!) : null,
        dateTo:      _dateTo   != null ? formatLocalDate(_dateTo!)   : null,
        status:      _statusFilter == 'all' ? null : _statusFilter,
      );
      final filtered = data.where((c) => c.documents.isNotEmpty).toList();

      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No DLN documents found for the selected conditions'
                : 'ไม่พบเอกสารส่งสินค้าตามเงื่อนไขที่เลือก')));
      }

      setState(() {
        _reportData = filtered;
        _pdfKey++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── shared totals ────────────────────────────────────────────────────────────

  (double, double, double) _customerTotals(ImDlnBillingReportCustomer c) {
    double cogs = 0, estRevenue = 0, billedRevenue = 0;
    for (final d in c.documents) {
      cogs          += d.cogsValue;
      estRevenue    += d.estimatedRevenue ?? 0;
      billedRevenue += d.billedRevenue ?? 0;
    }
    return (cogs, estRevenue, billedRevenue);
  }

  (double, double, double) _grandTotals() {
    double cogs = 0, estRevenue = 0, billedRevenue = 0;
    for (final c in _reportData) {
      final (co, er, br) = _customerTotals(c);
      cogs += co; estRevenue += er; billedRevenue += br;
    }
    return (cogs, estRevenue, billedRevenue);
  }

  String _statusLabel(String status, bool isEnglish) {
    if (status == 'Delivered') return isEnglish ? 'Delivered' : 'ส่งสินค้าแล้ว';
    if (status == 'Posted')    return isEnglish ? 'Posted'     : 'Post AR/GL แล้ว';
    return status;
  }

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      final sheetName = isEnglish ? 'DLN Billing' : 'DLN รอตั้งหนี้';
      ex.rename('Sheet1', sheetName);
      final s     = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final grpBg = ExcelColor.fromHexString('#DDEBF7');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0,
          isEnglish ? 'DLN Pending AR Billing Report' : 'รายงานส่งสินค้ารอตั้งหนี้ (DLN)',
          bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? "As of" : "ณ วันที่"}: ${DateFormat('dd/MM/yyyy').format(_asOfDate)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $ts');

      int r = 3;
      final headers = [
        isEnglish ? 'Customer' : 'ลูกค้า',
        isEnglish ? 'Doc No.' : 'เลขที่เอกสาร',
        isEnglish ? 'Doc Date' : 'วันที่เอกสาร',
        isEnglish ? 'Warehouse' : 'คลังสินค้า',
        isEnglish ? 'Ref. No.' : 'เลขที่อ้างอิง',
        isEnglish ? 'Status' : 'สถานะ',
        isEnglish ? 'Days Outstanding' : 'ค้างกี่วัน',
        isEnglish ? 'COGS' : 'ต้นทุนขาย',
        isEnglish ? 'Est. Revenue' : 'รายได้โดยประมาณ',
        isEnglish ? 'Billed Revenue' : 'รายได้ตามใบแจ้งหนี้',
      ];
      for (int c = 0; c < headers.length; c++) {
        _xlCell(s, r, c, headers[c], bg: hdrBg, bold: true,
            align: c >= 6 ? HorizontalAlign.Right : HorizontalAlign.Left);
      }
      r++;

      double grandCogs = 0, grandEst = 0, grandBilled = 0;

      for (final cus in _reportData) {
        final customerName = cus.customerNameTh;
        final (cCogs, cEst, cBilled) = _customerTotals(cus);

        _xlCell(s, r, 0, '${cus.customerCode}  $customerName', bg: grpBg, bold: true);
        for (int c = 1; c < headers.length; c++) {
          _xlCell(s, r, c, '', bg: grpBg);
        }
        r++;

        for (final d in cus.documents) {
          _xlCell(s, r, 0, '');
          _xlCell(s, r, 1, d.docNo);
          _xlCell(s, r, 2, DateFormat('dd/MM/yyyy').format(d.docDate));
          _xlCell(s, r, 3, '${d.warehouseCode ?? ''} ${d.warehouseNameTh ?? ''}'.trim());
          _xlCell(s, r, 4, d.refNo ?? '');
          _xlCell(s, r, 5, _statusLabel(d.status, isEnglish));
          _xlCell(s, r, 6, d.daysOutstanding?.toString() ?? '-', align: HorizontalAlign.Right);
          _xlCell(s, r, 7, DoubleCellValue(d.cogsValue), align: HorizontalAlign.Right);
          _xlCell(s, r, 8,
              d.estimatedRevenue == null ? TextCellValue('-') : DoubleCellValue(d.estimatedRevenue!),
              align: HorizontalAlign.Right);
          _xlCell(s, r, 9,
              d.billedRevenue == null ? TextCellValue('-') : DoubleCellValue(d.billedRevenue!),
              align: HorizontalAlign.Right);
          r++;
        }

        _xlCell(s, r, 0, isEnglish ? 'Customer Subtotal' : 'รวมลูกค้า', bold: true);
        for (int c = 1; c < 7; c++) {
          _xlCell(s, r, c, '');
        }
        _xlCell(s, r, 7, DoubleCellValue(cCogs), align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 8, DoubleCellValue(cEst), align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 9, DoubleCellValue(cBilled), align: HorizontalAlign.Right, bold: true);
        r++;

        grandCogs += cCogs; grandEst += cEst; grandBilled += cBilled;
      }

      _xlCell(s, r, 0, isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', bg: totBg, bold: true);
      for (int c = 1; c < 7; c++) {
        _xlCell(s, r, c, '', bg: totBg);
      }
      _xlCell(s, r, 7, DoubleCellValue(grandCogs), bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 8, DoubleCellValue(grandEst), bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 9, DoubleCellValue(grandBilled), bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final fileTs = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes,
          isEnglish ? 'DLN_Billing_Report_$fileTs.xlsx' : 'รายงานส่งสินค้ารอตั้งหนี้_$fileTs.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue
        ? v
        : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish       = _isEnglish;
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? (isEnglish ? '(No name)' : '(ไม่ระบุชื่อ)');
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final asOfLine     = '${isEnglish ? "As of" : "ณ วันที่"} ${DateFormat('dd/MM/yyyy').format(_asOfDate)}';

    final conditions = <String>[];
    if (_warehouseId != null) {
      conditions.add('${isEnglish ? "Warehouse" : "คลังสินค้า"}: ${_warehouseLabel ?? ''}');
    }
    if (_customerId != null) {
      conditions.add('${isEnglish ? "Customer" : "ลูกค้า"}: ${_customerLabel ?? ''}');
    }
    if (_dateFrom != null || _dateTo != null) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final from = _dateFrom != null ? DateFormat('dd/MM/yyyy').format(_dateFrom!) : all;
      final to   = _dateTo   != null ? DateFormat('dd/MM/yyyy').format(_dateTo!)   : all;
      conditions.add('${isEnglish ? "Doc Date" : "วันที่เอกสาร"}: $from – $to');
    }
    conditions.add('${isEnglish ? "Status" : "สถานะ"}: ${_statusFilter == 'all' ? (isEnglish ? 'All' : 'ทั้งหมด') : _statusLabel(_statusFilter, isEnglish)}');
    final conditionLine = conditions.isEmpty ? '' : '* ${conditions.join(' | ')}';

    final numFmt = NumberFormat('#,##0.00', 'en_US');
    String fmtAmt(double v) => numFmt.format(v);

    final grand = _grandTotals();

    final colW = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(13), // customer
      1: const pw.FlexColumnWidth(9),  // doc no
      2: const pw.FlexColumnWidth(8),  // doc date
      3: const pw.FlexColumnWidth(11), // warehouse
      4: const pw.FlexColumnWidth(9),  // ref no
      5: const pw.FlexColumnWidth(8),  // status
      6: const pw.FlexColumnWidth(7),  // days outstanding
      7: const pw.FlexColumnWidth(9),  // cogs
      8: const pw.FlexColumnWidth(9),  // est revenue
      9: const pw.FlexColumnWidth(9),  // billed revenue
    };

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text(
                  isEnglish ? 'DLN Pending AR Billing Report' : 'รายงานส่งสินค้ารอตั้งหนี้ (DLN)',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Page" : "หน้า"} ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 3, child: pw.Text('', style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text(asOfLine,
                  textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed by" : "พิมพ์โดย"} $userName',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 10, child: pw.Text(conditionLine,
                  textAlign: pw.TextAlign.left, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed" : "พิมพ์เมื่อ"} $printDateStr',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) {
          final hdrStyle  = pw.TextStyle(font: fontBold, fontSize: 9);
          final cellStyle = pw.TextStyle(font: font,     fontSize: 9);
          final boldStyle = pw.TextStyle(font: fontBold, fontSize: 9);
          const edg = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2);

          pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
              pw.Container(padding: edg, child: pw.Text(t, style: hdrStyle, textAlign: a));

          pw.Widget dCell(String t, {pw.TextAlign a = pw.TextAlign.left, pw.TextStyle? s}) =>
              pw.Container(padding: edg, child: pw.Text(t, style: s ?? cellStyle, textAlign: a));

          pw.Widget amtCell(String t, {bool bold = false}) =>
              pw.Container(padding: edg,
                  child: pw.Text(t, style: bold ? boldStyle : cellStyle, textAlign: pw.TextAlign.right));

          const cHeader = PdfColor(0.82, 0.87, 0.90);
          const cGroup  = PdfColor(0.90, 0.94, 0.98);
          const cTotal  = PdfColor(0.75, 0.85, 0.88);

          final tableRows = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: cHeader),
              children: [
                hCell(isEnglish ? 'Customer' : 'ลูกค้า', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Doc Date' : 'วันที่เอกสาร'),
                hCell(isEnglish ? 'Warehouse' : 'คลังสินค้า', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Ref. No.' : 'เลขที่อ้างอิง', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Status' : 'สถานะ'),
                hCell(isEnglish ? 'Days\nOutstanding' : 'ค้างกี่วัน'),
                hCell(isEnglish ? 'COGS' : 'ต้นทุนขาย'),
                hCell(isEnglish ? 'Est. Revenue' : 'รายได้โดยประมาณ'),
                hCell(isEnglish ? 'Billed Revenue' : 'รายได้ตามใบแจ้งหนี้'),
              ],
            ),
          ];

          for (final cus in _reportData) {
            final customerName = cus.customerNameTh;
            final (cCogs, cEst, cBilled) = _customerTotals(cus);

            tableRows.add(pw.TableRow(
              decoration: const pw.BoxDecoration(color: cGroup),
              children: [
                pw.Container(
                  padding: edg,
                  child: pw.Text('${cus.customerCode}  $customerName', style: boldStyle),
                ),
                dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''),
              ],
            ));

            for (final d in cus.documents) {
              tableRows.add(pw.TableRow(children: [
                dCell(''),
                dCell(d.docNo),
                dCell(DateFormat('dd/MM/yyyy').format(d.docDate), a: pw.TextAlign.center),
                dCell('${d.warehouseCode ?? ''} ${d.warehouseNameTh ?? ''}'.trim()),
                dCell(d.refNo ?? ''),
                dCell(_statusLabel(d.status, isEnglish), a: pw.TextAlign.center),
                dCell(d.daysOutstanding?.toString() ?? '-', a: pw.TextAlign.center),
                amtCell(fmtAmt(d.cogsValue)),
                amtCell(d.estimatedRevenue == null ? '-' : fmtAmt(d.estimatedRevenue!)),
                amtCell(d.billedRevenue == null ? '-' : fmtAmt(d.billedRevenue!)),
              ]));
            }

            tableRows.add(pw.TableRow(children: [
              dCell(isEnglish ? 'Customer Subtotal' : 'รวมลูกค้า', s: boldStyle),
              dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''),
              amtCell(fmtAmt(cCogs), bold: true),
              amtCell(fmtAmt(cEst), bold: true),
              amtCell(fmtAmt(cBilled), bold: true),
            ]));
          }

          tableRows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(color: cTotal),
            children: [
              dCell(isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', s: boldStyle),
              dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''),
              amtCell(fmtAmt(grand.$1), bold: true),
              amtCell(fmtAmt(grand.$2), bold: true),
              amtCell(fmtAmt(grand.$3), bold: true),
            ],
          ));

          return [
            pw.Table(
              border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
              columnWidths: colW,
              children: tableRows,
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  // ─── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blueGrey[800],
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
        final maxFilterWidth =
            (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // toggle
            Container(
              width: 36,
              color: Colors.blueGrey[800],
              child: IconButton(
                icon: Icon(
                    _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded
                    ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                    : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                onPressed: () =>
                    setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            // filter panel
            AnimatedContainer(
              duration: _isDraggingDivider
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),

                              // ณ วันที่
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _asOfDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => _asOfDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: isEnglish ? 'As of' : 'ณ วันที่',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                  ),
                                  child: Text(DateFormat('dd/MM/yyyy').format(_asOfDate)),
                                ),
                              ),

                              const SizedBox(height: 12),
                              _buildPickerField(
                                label: isEnglish ? 'Warehouse' : 'คลังสินค้า',
                                displayText: _warehouseLabel,
                                onPick: () => ImWarehouseListWidget.search(context, onSelected: (ImWarehouse w) {
                                  setState(() {
                                    _warehouseId = w.id;
                                    _warehouseLabel = '${w.warehouseCode}  ${w.warehouseNameTh}';
                                  });
                                }),
                                onClear: () => setState(() {
                                  _warehouseId = null;
                                  _warehouseLabel = null;
                                }),
                              ),

                              const SizedBox(height: 12),
                              _buildPickerField(
                                label: isEnglish ? 'Customer' : 'ลูกค้า',
                                displayText: _customerLabel,
                                onPick: () => ArCustomerListWidget.search(context, onSelected: (ArCustomer c) {
                                  setState(() {
                                    _customerId = c.id;
                                    _customerLabel = '${c.customerCode}  ${c.customerNameTh}';
                                  });
                                }),
                                onClear: () => setState(() {
                                  _customerId = null;
                                  _customerLabel = null;
                                }),
                              ),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildDateField(
                                label: isEnglish ? 'Doc Date From' : 'วันที่เอกสาร ตั้งแต่',
                                value: _dateFrom,
                                onPick: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dateFrom ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) setState(() => _dateFrom = picked);
                                },
                                onClear: () => setState(() => _dateFrom = null),
                              ),
                              const SizedBox(height: 8),
                              _buildDateField(
                                label: isEnglish ? 'Doc Date To' : 'วันที่เอกสาร ถึง',
                                value: _dateTo,
                                onPick: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dateTo ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) setState(() => _dateTo = picked);
                                },
                                onClear: () => setState(() => _dateTo = null),
                              ),

                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _statusFilter,
                                decoration: InputDecoration(
                                    labelText: isEnglish ? 'Status' : 'สถานะ',
                                    border: const OutlineInputBorder(),
                                    isDense: true),
                                items: [
                                  DropdownMenuItem(value: 'all', child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                                  DropdownMenuItem(value: 'Delivered', child: Text(isEnglish ? 'Delivered only (accrual gap)' : 'ส่งสินค้าแล้วเท่านั้น (ยังไม่มี GL)')),
                                  DropdownMenuItem(value: 'Posted', child: Text(isEnglish ? 'Posted only (billed revenue)' : 'Post AR/GL แล้วเท่านั้น (รายได้ตามใบแจ้งหนี้)')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _statusFilter = v);
                                },
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
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey[800],
                                foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _generateReport,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            // draggable divider
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) =>
                      setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _filterPanelWidth =
                        (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth);
                  }),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _isDraggingDivider = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            // PDF preview
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportData.isEmpty
                        ? Center(
                            child: Text(isEnglish
                                ? 'Please select conditions and click Generate'
                                : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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

  Widget _buildPickerField({
    required String label,
    required String? displayText,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasValue = (displayText ?? '').isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.clear, size: 16, color: Colors.grey),
              ),
            ),
          InkWell(
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.search, size: 18, color: Colors.blueGrey[800]),
            ),
          ),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText! : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (value != null)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.clear, size: 16, color: Colors.grey),
                ),
              ),
            const Icon(Icons.calendar_today, size: 16),
          ]),
        ),
        child: Text(
          value != null ? DateFormat('dd/MM/yyyy').format(value) : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
          style: TextStyle(fontSize: 13, color: value != null ? Colors.black87 : Colors.black38),
        ),
      ),
    );
  }
}
