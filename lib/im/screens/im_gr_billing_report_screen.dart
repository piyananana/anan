// lib/im/screens/im_gr_billing_report_screen.dart
//
// Review report for sys_doc_type='12' (GR รอตั้งหนี้): shows Received documents whose stock
// value has no GL backing yet (accrual gap) and Posted documents where the billed cost differs
// from the cost that valued the stock (price variance). Structure mirrors
// lib/ap/screens/ap_aging_report_screen.dart (collapsible/draggable filter panel, live PDF
// preview, Excel export).

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
import '../models/im_gr_billing_report.dart';
import '../services/im_transaction_service.dart';
import '../models/im_warehouse.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';

class ImGrBillingReportScreen extends StatefulWidget {
  const ImGrBillingReportScreen({super.key});

  @override
  State<ImGrBillingReportScreen> createState() => _ImGrBillingReportScreenState();
}

class _ImGrBillingReportScreenState extends State<ImGrBillingReportScreen> {
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
  int?      _vendorId;
  String?   _vendorLabel;
  String    _statusFilter = 'all'; // 'all' | 'Received' | 'Posted'

  List<ImGrBillingReportVendor> _reportData = [];

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
      final data = await _reportService.fetchGrBillingReport(
        asOfDate:    formatLocalDate(_asOfDate),
        warehouseId: _warehouseId,
        vendorId:    _vendorId,
        dateFrom:    _dateFrom != null ? formatLocalDate(_dateFrom!) : null,
        dateTo:      _dateTo   != null ? formatLocalDate(_dateTo!)   : null,
        status:      _statusFilter == 'all' ? null : _statusFilter,
      );
      final filtered = data.where((v) => v.documents.isNotEmpty).toList();

      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No GR documents found for the selected conditions'
                : 'ไม่พบเอกสาร GR ตามเงื่อนไขที่เลือก')));
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

  (double, double, double) _vendorTotals(ImGrBillingReportVendor v) {
    double stock = 0, billed = 0, variance = 0;
    for (final d in v.documents) {
      stock    += d.stockValue;
      billed   += d.billedValue ?? 0;
      variance += d.varianceValue;
    }
    return (stock, billed, variance);
  }

  (double, double, double) _grandTotals() {
    double stock = 0, billed = 0, variance = 0;
    for (final v in _reportData) {
      final (s, b, va) = _vendorTotals(v);
      stock += s; billed += b; variance += va;
    }
    return (stock, billed, variance);
  }

  String _statusLabel(String status, bool isEnglish) {
    if (status == 'Received') return isEnglish ? 'Received' : 'รับสินค้าแล้ว';
    if (status == 'Posted')   return isEnglish ? 'Posted'    : 'Post AP/GL แล้ว';
    return status;
  }

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      final sheetName = isEnglish ? 'GR Billing' : 'GR รอตั้งหนี้';
      ex.rename('Sheet1', sheetName);
      final s     = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final grpBg = ExcelColor.fromHexString('#DDEBF7');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0,
          isEnglish ? 'GR Pending AP/GL Posting Report' : 'รายงานตรวจสอบรับสินค้ารอโพสต์ AP/GL',
          bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? "As of" : "ณ วันที่"}: ${DateFormat('dd/MM/yyyy').format(_asOfDate)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $ts');

      int r = 3;
      final headers = [
        isEnglish ? 'Vendor' : 'ผู้ขาย',
        isEnglish ? 'Doc No.' : 'เลขที่เอกสาร',
        isEnglish ? 'Doc Date' : 'วันที่เอกสาร',
        isEnglish ? 'Warehouse' : 'คลังสินค้า',
        isEnglish ? 'Status' : 'สถานะ',
        isEnglish ? 'Days Outstanding' : 'ค้างกี่วัน',
        isEnglish ? 'Stock Value' : 'มูลค่าสต็อก',
        isEnglish ? 'Billed Value' : 'มูลค่าตามใบกำกับ',
        isEnglish ? 'Variance' : 'ส่วนต่าง',
      ];
      for (int c = 0; c < headers.length; c++) {
        _xlCell(s, r, c, headers[c], bg: hdrBg, bold: true,
            align: c >= 5 ? HorizontalAlign.Right : HorizontalAlign.Left);
      }
      r++;

      double grandStock = 0, grandBilled = 0, grandVariance = 0;

      for (final v in _reportData) {
        final vendorName = v.vendorNameTh;
        final (vStock, vBilled, vVariance) = _vendorTotals(v);

        _xlCell(s, r, 0, '${v.vendorCode}  $vendorName', bg: grpBg, bold: true);
        for (int c = 1; c < headers.length; c++) {
          _xlCell(s, r, c, '', bg: grpBg);
        }
        r++;

        for (final d in v.documents) {
          _xlCell(s, r, 0, '');
          _xlCell(s, r, 1, d.docNo);
          _xlCell(s, r, 2, DateFormat('dd/MM/yyyy').format(d.docDate));
          _xlCell(s, r, 3, '${d.warehouseCode ?? ''} ${d.warehouseNameTh ?? ''}'.trim());
          _xlCell(s, r, 4, _statusLabel(d.status, isEnglish));
          _xlCell(s, r, 5, d.daysOutstanding?.toString() ?? '-', align: HorizontalAlign.Right);
          _xlCell(s, r, 6, DoubleCellValue(d.stockValue), align: HorizontalAlign.Right);
          _xlCell(s, r, 7,
              d.billedValue == null ? TextCellValue('-') : DoubleCellValue(d.billedValue!),
              align: HorizontalAlign.Right);
          _xlCell(s, r, 8, DoubleCellValue(d.varianceValue), align: HorizontalAlign.Right);
          r++;
        }

        _xlCell(s, r, 0, isEnglish ? 'Vendor Subtotal' : 'รวมผู้ขาย', bold: true);
        for (int c = 1; c < 6; c++) {
          _xlCell(s, r, c, '');
        }
        _xlCell(s, r, 6, DoubleCellValue(vStock), align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 7, DoubleCellValue(vBilled), align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 8, DoubleCellValue(vVariance), align: HorizontalAlign.Right, bold: true);
        r++;

        grandStock += vStock; grandBilled += vBilled; grandVariance += vVariance;
      }

      _xlCell(s, r, 0, isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', bg: totBg, bold: true);
      for (int c = 1; c < 6; c++) {
        _xlCell(s, r, c, '', bg: totBg);
      }
      _xlCell(s, r, 6, DoubleCellValue(grandStock), bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 7, DoubleCellValue(grandBilled), bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 8, DoubleCellValue(grandVariance), bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final fileTs = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes,
          isEnglish ? 'GR_Billing_Report_$fileTs.xlsx' : 'รายงานตรวจสอบรับสินค้ารอโพสต์_$fileTs.xlsx');
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
    if (_vendorId != null) {
      conditions.add('${isEnglish ? "Vendor" : "ผู้ขาย"}: ${_vendorLabel ?? ''}');
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
      0: const pw.FlexColumnWidth(14), // vendor
      1: const pw.FlexColumnWidth(10), // doc no
      2: const pw.FlexColumnWidth(8),  // doc date
      3: const pw.FlexColumnWidth(12), // warehouse
      4: const pw.FlexColumnWidth(8),  // status
      5: const pw.FlexColumnWidth(7),  // days outstanding
      6: const pw.FlexColumnWidth(9),  // stock value
      7: const pw.FlexColumnWidth(9),  // billed value
      8: const pw.FlexColumnWidth(9),  // variance
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
                  isEnglish ? 'GR Pending AP/GL Posting Report' : 'รายงานตรวจสอบรับสินค้ารอโพสต์ AP/GL',
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
                hCell(isEnglish ? 'Vendor' : 'ผู้ขาย', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Doc Date' : 'วันที่เอกสาร'),
                hCell(isEnglish ? 'Warehouse' : 'คลังสินค้า', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Status' : 'สถานะ'),
                hCell(isEnglish ? 'Days\nOutstanding' : 'ค้างกี่วัน'),
                hCell(isEnglish ? 'Stock Value' : 'มูลค่าสต็อก'),
                hCell(isEnglish ? 'Billed Value' : 'มูลค่าตามใบกำกับ'),
                hCell(isEnglish ? 'Variance' : 'ส่วนต่าง'),
              ],
            ),
          ];

          for (final v in _reportData) {
            final vendorName = v.vendorNameTh;
            final (vStock, vBilled, vVariance) = _vendorTotals(v);

            tableRows.add(pw.TableRow(
              decoration: const pw.BoxDecoration(color: cGroup),
              children: [
                pw.Container(
                  padding: edg,
                  child: pw.Text('${v.vendorCode}  $vendorName', style: boldStyle),
                ),
                dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''), dCell(''),
              ],
            ));

            for (final d in v.documents) {
              tableRows.add(pw.TableRow(children: [
                dCell(''),
                dCell(d.docNo),
                dCell(DateFormat('dd/MM/yyyy').format(d.docDate), a: pw.TextAlign.center),
                dCell('${d.warehouseCode ?? ''} ${d.warehouseNameTh ?? ''}'.trim()),
                dCell(_statusLabel(d.status, isEnglish), a: pw.TextAlign.center),
                dCell(d.daysOutstanding?.toString() ?? '-', a: pw.TextAlign.center),
                amtCell(fmtAmt(d.stockValue)),
                amtCell(d.billedValue == null ? '-' : fmtAmt(d.billedValue!)),
                amtCell(fmtAmt(d.varianceValue)),
              ]));
            }

            tableRows.add(pw.TableRow(children: [
              dCell(isEnglish ? 'Vendor Subtotal' : 'รวมผู้ขาย', s: boldStyle),
              dCell(''), dCell(''), dCell(''), dCell(''), dCell(''),
              amtCell(fmtAmt(vStock), bold: true),
              amtCell(fmtAmt(vBilled), bold: true),
              amtCell(fmtAmt(vVariance), bold: true),
            ]));
          }

          tableRows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(color: cTotal),
            children: [
              dCell(isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', s: boldStyle),
              dCell(''), dCell(''), dCell(''), dCell(''), dCell(''),
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
                                label: isEnglish ? 'Vendor' : 'ผู้ขาย',
                                displayText: _vendorLabel,
                                onPick: () => ApVendorListWidget.search(context, onSelected: (ApVendor v) {
                                  setState(() {
                                    _vendorId = v.id;
                                    _vendorLabel = '${v.vendorCode}  ${v.vendorNameTh}';
                                  });
                                }),
                                onClear: () => setState(() {
                                  _vendorId = null;
                                  _vendorLabel = null;
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
                                  DropdownMenuItem(value: 'Received', child: Text(isEnglish ? 'Received only (accrual gap)' : 'รับสินค้าแล้วเท่านั้น (ยังไม่มี GL)')),
                                  DropdownMenuItem(value: 'Posted', child: Text(isEnglish ? 'Posted only (price variance)' : 'Post AP/GL แล้วเท่านั้น (ส่วนต่างราคา)')),
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
