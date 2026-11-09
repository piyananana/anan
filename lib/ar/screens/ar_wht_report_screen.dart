import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../widgets/zoomable_pdf_preview.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/date_utils.dart';

// รายงานภาษีถูกหัก ณ ที่จ่าย (ลูกค้าหักเรา) — ใบเสร็จรับชำระ AR + รายรับ CM ที่ Post แล้ว
// ใช้กระทบยอดบัญชีภาษีถูกหัก ณ ที่จ่าย และติดตามหนังสือรับรอง (50 ทวิ) จากลูกค้า
class _WhtRow {
  final String source; // 'AR' | 'CM'
  final String docNo;
  final DateTime docDate;
  final String customerCode;
  final String customerNameTh;
  final String? customerNameEn;
  final String? taxId;
  final String? incomeType;
  final String? whtType;
  final String? whtTypeEn;
  final double whtRate;
  final double baseAmountLc;
  final double whtAmountLc;
  final String? certificateNo;

  _WhtRow({
    required this.source,
    required this.docNo,
    required this.docDate,
    required this.customerCode,
    required this.customerNameTh,
    this.customerNameEn,
    this.taxId,
    this.incomeType,
    this.whtType,
    this.whtTypeEn,
    required this.whtRate,
    required this.baseAmountLc,
    required this.whtAmountLc,
    this.certificateNo,
  });

  factory _WhtRow.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    String? s(dynamic v) => (v ?? '').toString().isEmpty ? null : v.toString();
    return _WhtRow(
      source:         j['source'] ?? 'AR',
      docNo:          j['doc_no'] ?? '',
      docDate:        parseLocalDate(j['doc_date']),
      customerCode:   j['customer_code'] ?? '',
      customerNameTh: j['customer_name_th'] ?? '',
      customerNameEn: s(j['customer_name_en']),
      taxId:          s(j['tax_id']),
      incomeType:     s(j['income_type']),
      whtType:        s(j['wht_type']),
      whtTypeEn:      s(j['wht_type_en']),
      whtRate:        d(j['wht_rate']),
      baseAmountLc:   d(j['base_amount_lc']),
      whtAmountLc:    d(j['wht_amount_lc']),
      certificateNo:  s(j['certificate_no']),
    );
  }

  String customerName(bool isEnglish) =>
      isEnglish && (customerNameEn ?? '').isNotEmpty ? customerNameEn! : customerNameTh;
}

class ArWhtReportScreen extends StatefulWidget {
  const ArWhtReportScreen({super.key});

  @override
  State<ArWhtReportScreen> createState() => _ArWhtReportScreenState();
}

class _ArWhtReportScreenState extends State<ArWhtReportScreen> {
  final _companySvc = CompanyService();
  final _authSvc    = AuthService();

  bool   _isEnglish         = false;
  bool   _isLoading         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 280.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;

  Company?             _company;
  Map<String, String>? _headers;

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  final _searchCtrl  = TextEditingController();

  List<_WhtRow> _reportData = [];

  final _fmt     = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    _headers = await _authSvc.getAuthHeader();
    _company = await _companySvc.fetchCompany();
    if (mounted) setState(() {});
  }

  // ─── fetch ─────────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    if (_dateTo.isBefore(_dateFrom)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
          ? 'The end date must not be before the start date'
          : 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่มต้น')));
      return;
    }
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final uri = Uri.parse('${AppConfig.apiAr}/ar_wht_report').replace(
        queryParameters: {
          'date_from': formatLocalDate(_dateFrom),
          'date_to':   formatLocalDate(_dateTo),
          if (_searchCtrl.text.trim().isNotEmpty) 'search': _searchCtrl.text.trim(),
        },
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final rows = (json.decode(res.body) as List)
            .map((j) => _WhtRow.fromJson(j as Map<String, dynamic>))
            .toList();
        if (rows.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
              ? 'No withholding tax records found for the selected conditions'
              : 'ไม่พบรายการภาษีถูกหัก ณ ที่จ่ายตามเงื่อนไขที่เลือก')));
        }
        if (mounted) setState(() { _reportData = rows; _pdfKey++; });
      } else {
        throw Exception('${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── PDF ───────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish    = _isEnglish;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font         = pw.Font.ttf(fontData);
    final fontBold     = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName    = _headers?['UserName'] ?? '';
    final printDate   = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font,     fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const mg      = 16.0;
    const hp      = 3.0;
    const vp      = 2.5;
    const cHdr    = PdfColor(0.82, 0.91, 0.96);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal  = PdfColor(0.65, 0.81, 0.93);
    const cBorder = PdfColors.grey400;

    final pageW = PdfPageFormat.a4.landscape.width - mg * 2;
    final wNo     = pageW * 0.04;
    final wDate   = pageW * 0.08;
    final wDoc    = pageW * 0.10;
    final wName   = pageW * 0.20;
    final wTaxId  = pageW * 0.11;
    final wCert   = pageW * 0.09;
    final wIncome = pageW * 0.13;
    final wRate   = pageW * 0.06;
    final wBase   = pageW * 0.10;
    final wWht    = pageW * 0.09;

    pw.Widget cell(double w, String t, pw.TextStyle s, {pw.TextAlign a = pw.TextAlign.left}) => pw.Container(
          width: w,
          padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: vp),
          child: pw.Text(t, style: s, textAlign: a, softWrap: true, maxLines: 3),
        );

    pw.Widget hdrRow() => pw.Container(
          color: cHdr,
          child: pw.Row(children: [
            cell(wNo,     isEnglish ? 'No.'            : 'ลำดับ',               tB(8), a: pw.TextAlign.center),
            cell(wDate,   isEnglish ? 'Date'           : 'วันที่',              tB(8), a: pw.TextAlign.center),
            cell(wDoc,    isEnglish ? 'Document No.'   : 'เลขที่เอกสาร',        tB(8)),
            cell(wName,   isEnglish ? 'Withheld by'    : 'ผู้หักภาษี',          tB(8)),
            cell(wTaxId,  isEnglish ? 'Tax ID'         : 'เลขผู้เสียภาษี',      tB(8), a: pw.TextAlign.center),
            cell(wCert,   isEnglish ? 'Certificate No.' : 'เลขที่หนังสือรับรอง', tB(8)),
            cell(wIncome, isEnglish ? 'Income Type'    : 'ประเภทเงินได้',        tB(8)),
            cell(wRate,   isEnglish ? 'Rate (%)'       : 'อัตรา (%)',           tB(8), a: pw.TextAlign.center),
            cell(wBase,   isEnglish ? 'Tax Base'       : 'ฐานภาษี',             tB(8), a: pw.TextAlign.right),
            cell(wWht,    isEnglish ? 'Tax Withheld'   : 'ภาษีถูกหัก',          tB(8), a: pw.TextAlign.right),
          ]),
        );

    double totalBase = 0, totalWht = 0;
    final rows = <pw.Widget>[];
    for (int i = 0; i < _reportData.length; i++) {
      final r = _reportData[i];
      totalBase += r.baseAmountLc;
      totalWht  += r.whtAmountLc;
      final whtTypeName = isEnglish && (r.whtTypeEn ?? '').isNotEmpty ? r.whtTypeEn! : (r.whtType ?? '');
      final incomeLabel = r.incomeType != null
          ? '${r.incomeType}${whtTypeName.isNotEmpty ? "\n$whtTypeName" : ""}'
          : whtTypeName;
      final name = r.customerCode.isNotEmpty ? '${r.customerCode}  ${r.customerName(isEnglish)}' : r.customerName(isEnglish);
      rows.add(pw.Container(
        decoration: pw.BoxDecoration(
          color: i.isOdd ? cStripe : null,
          border: const pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3)),
        ),
        child: pw.Row(children: [
          cell(wNo,     '${i + 1}',                     tN(8), a: pw.TextAlign.center),
          cell(wDate,   _dateFmt.format(r.docDate),     tN(8), a: pw.TextAlign.center),
          cell(wDoc,    r.source == 'CM' ? '${r.docNo} (CM)' : r.docNo, tN(8)),
          cell(wName,   name,                           tN(8)),
          cell(wTaxId,  r.taxId ?? '-',                 tN(8), a: pw.TextAlign.center),
          cell(wCert,   r.certificateNo ?? '-',         tN(8)),
          cell(wIncome, incomeLabel,                    tN(8)),
          cell(wRate,   r.whtRate > 0 ? '${_fmt.format(r.whtRate)}%' : '-', tN(8), a: pw.TextAlign.center),
          cell(wBase,   _fmt.format(r.baseAmountLc),    tN(8), a: pw.TextAlign.right),
          cell(wWht,    _fmt.format(r.whtAmountLc),     tN(8), a: pw.TextAlign.right),
        ]),
      ));
    }
    rows.add(pw.Container(
      color: cTotal,
      child: pw.Row(children: [
        cell(wNo + wDate + wDoc + wName + wTaxId + wCert + wIncome + wRate,
            isEnglish ? 'Grand Total  ${_reportData.length} items' : 'รวมทั้งสิ้น  ${_reportData.length} รายการ',
            tB(8), a: pw.TextAlign.right),
        cell(wBase, _fmt.format(totalBase), tB(8), a: pw.TextAlign.right),
        cell(wWht,  _fmt.format(totalWht),  tB(8), a: pw.TextAlign.right),
      ]),
    ));

    final period = '${_dateFmt.format(_dateFrom)} - ${_dateFmt.format(_dateTo)}';
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(mg),
      header: (ctx) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
          pw.Expanded(flex: 6, child: pw.Text(
            isEnglish
                ? 'Withholding Tax Deducted by Customers\nDate: $period'
                : 'รายงานภาษีถูกหัก ณ ที่จ่าย\nวันที่: $period',
            textAlign: pw.TextAlign.center,
            style: tB(13),
          )),
          pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: tN(10),
          )),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Text(
              isEnglish ? 'Printed by $userName  |  Printed $printDate' : 'พิมพ์โดย $userName  |  พิมพ์เมื่อ $printDate',
              style: tN(9)),
        ]),
        pw.SizedBox(height: 4),
        hdrRow(),
      ]),
      build: (_) => rows,
    ));
    return doc.save();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  Widget _buildDateField({required String label, required DateTime date, required void Function(DateTime) onPick}) {
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
        child: Text(_dateFmt.format(date)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canPrint = perm?.canPrint ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFW = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 36, color: Colors.blue[900],
            child: IconButton(
              icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              tooltip: _isFilterExpanded
                  ? (isEnglish ? 'Collapse conditions' : 'ย่อเงื่อนไข')
                  : (isEnglish ? 'Expand conditions' : 'ขยายเงื่อนไข'),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        _buildDateField(
                          label: isEnglish ? 'From date' : 'ตั้งแต่วันที่',
                          date: _dateFrom,
                          onPick: (d) => setState(() => _dateFrom = d),
                        ),
                        const SizedBox(height: 12),
                        _buildDateField(
                          label: isEnglish ? 'To date' : 'ถึงวันที่',
                          date: _dateTo,
                          onPick: (d) => setState(() => _dateTo = d),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Search' : 'ค้นหา',
                            helperText: isEnglish
                                ? 'Customer, tax ID, certificate or document no.'
                                : 'ลูกค้า เลขผู้เสียภาษี เลขที่หนังสือรับรอง/เอกสาร',
                            helperMaxLines: 2,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _generateReport(),
                        ),
                        const Spacer(),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[900],
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _generateReport,
                            ),
                          ),
                      ],
                    ),
                  ),
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
                  _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFW);
                }),
                onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: _reportData.isEmpty
                  ? Center(child: Text(isEnglish
                      ? 'Please select conditions and click Generate'
                      : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                  : ZoomablePdfPreview(
                      documentVersion: _pdfKey,
                      build: _generatePdf,
                      initialPageFormat: PdfPageFormat.a4.landscape,
                      canChangeOrientation: false,
                      canDebug: false,
                      allowPrinting: canPrint,
                      allowSharing: canPrint,
                    ),
            ),
          ),
        ]);
      }),
    );
  }
}
