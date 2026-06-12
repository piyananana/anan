import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/vat_report_service.dart';
import '../../sa/models/company.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';

// ─── ประเภทภาษีที่แสดงใน dropdown ────────────────────────────────────────────
enum _VatChoice { output, input }

extension _VatChoiceX on _VatChoice {
  String get apiValue => this == _VatChoice.output ? 'OUTPUT_VAT' : 'INPUT_VAT';
  String get label    => this == _VatChoice.output ? 'ภาษีขาย' : 'ภาษีซื้อ';
  String get reportTitle =>
      this == _VatChoice.output ? 'รายงานภาษีขาย' : 'รายงานภาษีซื้อ';
  String get entityLabel =>
      this == _VatChoice.output ? 'ชื่อผู้ซื้อสินค้าหรือผู้รับบริการ'
                                : 'ชื่อผู้ขายสินค้าหรือผู้ให้บริการ';
  String get amountLabel =>
      this == _VatChoice.output ? 'จำนวนเงินภาษีขาย' : 'จำนวนเงินภาษีซื้อ';
}

class VatReportScreen extends StatefulWidget {
  const VatReportScreen({super.key});

  @override
  State<VatReportScreen> createState() => _VatReportScreenState();
}

class _VatReportScreenState extends State<VatReportScreen> {
  final VatReportService _reportService = VatReportService();
  final CompanyService   _companyService = CompanyService();
  final AuthService      _authService   = AuthService();

  bool _isLoading        = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 280.0;
  bool _isDraggingDivider = false;
  int  _pdfKey      = 0;
  bool _isExporting = false;

  Company? _company;
  Map<String, String>? _headers;

  // Filters
  _VatChoice _vatChoice = _VatChoice.output;
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();

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
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getVatReport(
        vatType:  _vatChoice.apiValue,
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:   DateFormat('yyyy-MM-dd').format(_dateTo),
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่พบข้อมูลในช่วงวันที่ที่เลือก')));
      }
      setState(() { _reportData = raw; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  /// จัดรูปแบบเลขประจำตัวผู้เสียภาษี 13 หลัก → X-XXXX-XXXXX-XX-X
  static String _fmtTaxId(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 13) {
      return '${d[0]}-${d.substring(1, 5)}-${d.substring(5, 10)}'
             '-${d.substring(10, 12)}-${d[12]}';
    }
    return raw;
  }

  /// สาขา: '00000' → 'สนญ.' ไม่งั้นแสดงเลขสาขา
  static String _fmtBranch(String? code) {
    if (code == null || code.isEmpty || code == '00000') return 'สนญ.';
    return code;
  }

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy')
          .format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final companyTaxId = _fmtTaxId(_company?.taxIdNumber);
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine =
        'ช่วงวันที่ ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';
    final vatChoice = _vatChoice;

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 4,
              child: pw.Text(companyName,
                  style: const pw.TextStyle(fontSize: 11))),
          pw.Expanded(flex: 6,
              child: pw.Text(vatChoice.reportTitle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 15,
                      fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 4,
              child: pw.Text('หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 4,
              child: pw.Text('เลขประจำตัวผู้เสียภาษี: $companyTaxId',
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(flex: 6,
              child: pw.Text(dateRangeLine,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(flex: 4,
              child: pw.Text('พิมพ์โดย $userName',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(flex: 10, child: pw.SizedBox()),
          pw.Expanded(flex: 4,
              child: pw.Text('พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 4),
      ],
    );

    // ─── Column widths ────────────────────────────────────────────────────────
    // 8 columns: seq | date | invoice_no | name | tax_id | branch | base | vat
    const colW = {
      0: pw.FlexColumnWidth(2),    // ลำดับ
      1: pw.FlexColumnWidth(5),    // วันที่
      2: pw.FlexColumnWidth(7),    // เลขที่ใบกำกับ
      3: pw.FlexColumnWidth(11),   // ชื่อ
      4: pw.FlexColumnWidth(8),    // เลขผู้เสียภาษี
      5: pw.FlexColumnWidth(3),    // สาขา
      6: pw.FlexColumnWidth(6),    // มูลค่าสินค้า
      7: pw.FlexColumnWidth(5),    // จำนวนเงินภาษี
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t,
              style: pw.TextStyle(font: fontBold, fontSize: 8.5),
              textAlign: a));

    pw.Widget dCell(String t, {pw.TextAlign a = pw.TextAlign.left,
        pw.Font? f, double fs = 9}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t,
              style: pw.TextStyle(font: f ?? font, fontSize: fs),
              textAlign: a));

    pw.Widget numCell(double v, {pw.Font? f}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(fmt.format(v),
              style: pw.TextStyle(font: f ?? font, fontSize: 9),
              textAlign: pw.TextAlign.right));

    // ─── Table header row ─────────────────────────────────────────────────────
    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cYellow = PdfColor(1.0,  0.98, 0.88);

    pw.TableRow headerRow() => pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell('ลำดับที่'),
        hCell('วัน เดือน ปี'),
        hCell('เลขที่ใบกำกับภาษี'),
        hCell(vatChoice.entityLabel, a: pw.TextAlign.left),
        hCell('เลขประจำตัว\nผู้เสียภาษีอากร'),
        hCell('สาขา\nที่'),
        hCell('มูลค่าสินค้า\nหรือบริการ'),
        hCell(vatChoice.amountLabel),
      ],
    );

    // ─── Data rows ────────────────────────────────────────────────────────────
    double totalBase = 0;
    double totalVat  = 0;

    final dataRows = _reportData.map((r) {
      final base = (r['base_amount'] as num?)?.toDouble() ?? 0;
      final vat  = (r['vat_amount']  as num?)?.toDouble() ?? 0;
      totalBase += base;
      totalVat  += vat;
      return pw.TableRow(children: [
        dCell('${r['seq'] ?? ''}', a: pw.TextAlign.center),
        dCell(_fmtDate(r['tax_invoice_date'] as String?)),
        dCell(r['tax_invoice_no'] as String? ?? ''),
        dCell(r['entity_name']   as String? ?? ''),
        dCell(_fmtTaxId(r['entity_tax_id']      as String?)),
        dCell(_fmtBranch(r['entity_branch_code'] as String?),
            a: pw.TextAlign.center),
        numCell(base),
        numCell(vat),
      ]);
    }).toList();

    // ─── Total / summary rows ─────────────────────────────────────────────────
    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cYellow),
      children: [
        dCell('', f: fontBold), dCell('', f: fontBold), dCell('', f: fontBold),
        dCell('ยอดรวม', f: fontBold),
        dCell('', f: fontBold), dCell('', f: fontBold),
        numCell(totalBase, f: fontBold),
        numCell(totalVat,  f: fontBold),
      ],
    );

    final summaryRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor(0.75, 0.88, 0.83)),
      children: [
        dCell('', f: fontBold), dCell('', f: fontBold),
        dCell('จำนวน ${_reportData.length} รายการ',
            f: fontBold, a: pw.TextAlign.left),
        dCell('', f: fontBold), dCell('', f: fontBold), dCell('', f: fontBold),
        numCell(totalBase, f: fontBold),
        numCell(totalVat,  f: fontBold),
      ],
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: pageHeader(),
        build: (ctx) => [
          pw.Table(
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
            columnWidths: colW,
            children: [headerRow(), ...dataRows, totalRow, summaryRow],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.receipt_long, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text('รายงานภาษีซื้อ / ภาษีขาย'),
        ]),
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
              tooltip: 'Export Excel',
              onPressed: _reportData.isEmpty ? null : _exportExcel,
            ),
        ],
      ),
      body: _isLoading && _company == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxFilterWidth =
                  (constraints.maxWidth - 36 - 5 - 300)
                      .clamp(100.0, double.infinity);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // toggle
                  Container(
                    width: 36,
                    color: Colors.teal[800],
                    child: IconButton(
                      icon: Icon(
                          _isFilterExpanded
                              ? Icons.filter_list_off
                              : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip:
                          _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
                      onPressed: () => setState(
                          () => _isFilterExpanded = !_isFilterExpanded),
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
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('เงื่อนไขรายงาน',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 16),

                                      // ประเภทภาษี
                                      DropdownButtonFormField<_VatChoice>(
                                        value: _vatChoice,
                                        decoration: const InputDecoration(
                                            labelText: 'ประเภทภาษี',
                                            border: OutlineInputBorder(),
                                            isDense: true),
                                        items: _VatChoice.values
                                            .map((v) => DropdownMenuItem(
                                                  value: v,
                                                  child: Text(v.label),
                                                ))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _vatChoice  = v;
                                              _reportData = [];
                                            });
                                          }
                                        },
                                      ),

                                      const SizedBox(height: 12),

                                      _buildDateField(
                                        label: 'วันที่ ตั้งแต่',
                                        date: _dateFrom,
                                        onPick: (d) =>
                                            setState(() => _dateFrom = d),
                                      ),
                                      const SizedBox(height: 12),

                                      _buildDateField(
                                        label: 'วันที่ ถึง',
                                        date: _dateTo,
                                        onPick: (d) =>
                                            setState(() => _dateTo = d),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('ประมวลผลรายงาน'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[800],
                                        foregroundColor: Colors.white),
                                    onPressed:
                                        _isLoading ? null : _generateReport,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                              (_filterPanelWidth + d.delta.dx)
                                  .clamp(200.0, maxFilterWidth);
                        }),
                        onHorizontalDragEnd: (_) =>
                            setState(() => _isDraggingDivider = false),
                        child: Container(
                            width: 5, color: Colors.grey[400]),
                      ),
                    ),
                  // PDF preview
                  Expanded(
                    child: Container(
                      color: Colors.grey[200],
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _reportData.isEmpty
                              ? const Center(
                                  child: Text(
                                      'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat:
                                      PdfPageFormat.a4.landscape,
                                  canChangeOrientation: false,
                                  canDebug: false,
                                ),
                    ),
                  ),
                ],
              );
            }),
    );
  }

  // ─── Excel Export ─────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'VAT';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      final vatChoice = _vatChoice;
      final _tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, vatChoice.reportTitle, bold: true);
      _xlCell(s, 2, 0, 'ช่วงวันที่: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  พิมพ์: $_tsLabel');

      final hdrs = ['ลำดับที่', 'วัน เดือน ปี', 'เลขที่ใบกำกับภาษี',
          vatChoice.entityLabel, 'เลขประจำตัวผู้เสียภาษีอากร',
          'สาขาที่', 'มูลค่าสินค้าหรือบริการ', vatChoice.amountLabel];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      double totalBase = 0, totalVat = 0;

      for (final r in _reportData) {
        final base = (r['base_amount'] as num?)?.toDouble() ?? 0;
        final vat  = (r['vat_amount']  as num?)?.toDouble() ?? 0;
        totalBase += base;
        totalVat  += vat;

        _xlCell(s, row, 0, '${r['seq'] ?? ''}',                    align: HorizontalAlign.Center);
        _xlCell(s, row, 1, _fmtDate(r['tax_invoice_date'] as String?));
        _xlCell(s, row, 2, r['tax_invoice_no'] as String? ?? '');
        _xlCell(s, row, 3, r['entity_name']    as String? ?? '');
        _xlCell(s, row, 4, _fmtTaxId(r['entity_tax_id']       as String?));
        _xlCell(s, row, 5, _fmtBranch(r['entity_branch_code'] as String?), align: HorizontalAlign.Center);
        _xlCell(s, row, 6, base, align: HorizontalAlign.Right);
        _xlCell(s, row, 7, vat,  align: HorizontalAlign.Right);
        row++;
      }

      // Total row
      _xlCell(s, row, 0, '');
      _xlCell(s, row, 1, '');
      _xlCell(s, row, 2, '');
      _xlCell(s, row, 3, 'ยอดรวม', bg: totBg, bold: true);
      _xlCell(s, row, 4, '', bg: totBg);
      _xlCell(s, row, 5, '', bg: totBg);
      _xlCell(s, row, 6, totalBase, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 7, totalVat,  bg: totBg, bold: true, align: HorizontalAlign.Right);
      row++;

      // Summary row
      _xlCell(s, row, 0, '');
      _xlCell(s, row, 1, '');
      _xlCell(s, row, 2, 'จำนวน ${_reportData.length} รายการ', bg: totBg, bold: true);
      for (int i = 3; i <= 5; i++) _xlCell(s, row, i, '', bg: totBg);
      _xlCell(s, row, 6, totalBase, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 7, totalVat,  bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = vatChoice.reportTitle;
      final ts    = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${title}_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double
        ? DoubleCellValue(v)
        : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required void Function(DateTime) onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }
}
