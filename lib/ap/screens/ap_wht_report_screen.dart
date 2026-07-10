import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../config/app_config.dart';
import '../../sa/models/company.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import '../../sa/utils/menu_scope.dart';

// ---------------------------------------------------------------------------
// Data model (lightweight, only what the screen needs)
// ---------------------------------------------------------------------------
class _WhtRow {
  final String paymentDocNo;
  final DateTime paymentDate;
  final String vendorCode;
  final String vendorNameTh;
  final String? taxId;
  final String? incomeType;
  final String? whtType;
  final double whtRate;
  final double baseAmountLc;
  final double whtAmountLc;
  final String? addressLine;

  _WhtRow({
    required this.paymentDocNo,
    required this.paymentDate,
    required this.vendorCode,
    required this.vendorNameTh,
    this.taxId,
    this.incomeType,
    this.whtType,
    required this.whtRate,
    required this.baseAmountLc,
    required this.whtAmountLc,
    this.addressLine,
  });

  factory _WhtRow.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

    // สร้างที่อยู่จากฟีลด์ต่างๆ
    final parts = <String>[
      if ((j['address_no'] ?? '').toString().isNotEmpty)
        j['address_no'].toString(),
      if ((j['address_building_village'] ?? '').toString().isNotEmpty)
        j['address_building_village'].toString(),
      if ((j['address_alley'] ?? '').toString().isNotEmpty)
        'ซ.${j['address_alley']}',
      if ((j['address_road'] ?? '').toString().isNotEmpty)
        'ถ.${j['address_road']}',
      if ((j['address_sub_district'] ?? '').toString().isNotEmpty)
        j['address_sub_district'].toString(),
      if ((j['address_district'] ?? '').toString().isNotEmpty)
        j['address_district'].toString(),
      if ((j['address_province'] ?? '').toString().isNotEmpty)
        j['address_province'].toString(),
      if ((j['address_zip_code'] ?? '').toString().isNotEmpty)
        j['address_zip_code'].toString(),
    ];

    return _WhtRow(
      paymentDocNo: j['payment_doc_no'] ?? '',
      paymentDate:  DateTime.tryParse(j['payment_date']?.toString() ?? '') ?? DateTime.now(),
      vendorCode:   j['vendor_code']   ?? '',
      vendorNameTh: j['vendor_name_th'] ?? '',
      taxId:        j['tax_id'],
      incomeType:   j['income_type'],
      whtType:      j['wht_type'],
      whtRate:      d(j['wht_rate']),
      baseAmountLc: d(j['base_amount_lc']),
      whtAmountLc:  d(j['wht_amount_lc']),
      addressLine:  parts.isEmpty ? null : parts.join(' '),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ApWhtReportScreen extends StatefulWidget {
  const ApWhtReportScreen({super.key});

  @override
  State<ApWhtReportScreen> createState() => _ApWhtReportScreenState();
}

class _ApWhtReportScreenState extends State<ApWhtReportScreen> {
  final _companySvc = CompanyService();
  final _authSvc    = AuthService();

  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth = 280.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey           = 0;

  Company?             _company;
  Map<String, String>? _headers;

  // Filters
  int    _month   = DateTime.now().month;
  int    _year    = DateTime.now().year;
  String _pndForm = 'pnd53';   // 'pnd3' | 'pnd53'

  List<_WhtRow> _reportData = [];

  static const _monthNames = [
    '', 'มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน',
    'กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม',
  ];

  final _fmt    = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    _headers = await _authSvc.getAuthHeader();
    _company = await _companySvc.fetchCompany();
    if (mounted) setState(() {});
  }

  // ─── fetch ─────────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final uri = Uri.parse('${AppConfig.apiAp}/ap_wht_report').replace(
        queryParameters: {
          'month':    '$_month',
          'year':     '$_year',
          'pnd_form': _pndForm,
        },
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final rows = (json.decode(res.body) as List)
            .map((j) => _WhtRow.fromJson(j as Map<String, dynamic>))
            .toList();
        if (rows.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไม่พบรายการภาษีหัก ณ ที่จ่ายในเดือน/ปีที่เลือก')));
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

  String get _formTitle =>
      _pndForm == 'pnd3' ? 'ภ.ง.ด.3  (บุคคลธรรมดา)' : 'ภ.ง.ด.53  (นิติบุคคล)';

  String get _periodLabel =>
      '${_monthNames[_month]}  พ.ศ. ${_year + 543}';

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font         = pw.Font.ttf(fontData);
    final fontBold     = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.thaiName ?? '';
    final userName     = _headers?['UserName'] ?? '';
    final printDate    = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font,     fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const mg   = 16.0;
    const hp   = 3.0;
    const vp   = 2.5;
    const cHdr = PdfColor(0.82, 0.91, 0.96);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal  = PdfColor(0.65, 0.81, 0.93);
    const cBorder = PdfColors.grey400;

    final pageW = PdfPageFormat.a4.landscape.width - mg * 2;

    // คอลัมน์ (เป็น flex fraction)
    final wNo       = pageW * 0.04;
    final wName     = pageW * 0.18;
    final wTaxId    = pageW * 0.12;
    final wDate     = pageW * 0.08;
    final wIncome   = pageW * 0.15;
    final wRate     = pageW * 0.07;
    final wBase     = pageW * 0.16;
    final wWht      = pageW * 0.12;
    final wDoc      = pageW * 0.08;

    pw.Widget cell(double w, String t, pw.TextStyle s,
        {pw.TextAlign a = pw.TextAlign.left, PdfColor? bg}) =>
        pw.Container(
          width: w,
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: vp),
          child: pw.Text(t, style: s, textAlign: a, softWrap: true, maxLines: 3),
        );

    pw.Widget hdrRow() => pw.Container(
      color: cHdr,
      child: pw.Row(children: [
        cell(wNo,     'ลำดับ',              tB(8), a: pw.TextAlign.center),
        cell(wName,   'ชื่อ-ที่อยู่',        tB(8)),
        cell(wTaxId,  'เลขผู้เสียภาษี',      tB(8), a: pw.TextAlign.center),
        cell(wDate,   'วันที่จ่าย',           tB(8), a: pw.TextAlign.center),
        cell(wIncome, 'ประเภทเงินได้',        tB(8)),
        cell(wRate,   'อัตรา\nภาษี (%)',      tB(8), a: pw.TextAlign.center),
        cell(wBase,   'จำนวนเงินที่จ่าย',     tB(8), a: pw.TextAlign.right),
        cell(wWht,    'ภาษีที่หัก\nและนำส่ง', tB(8), a: pw.TextAlign.right),
        cell(wDoc,    'เลขที่เอกสาร',          tB(8)),
      ]),
    );

    double totalBase = 0, totalWht = 0;
    final rows = <pw.Widget>[];

    for (int i = 0; i < _reportData.length; i++) {
      final r  = _reportData[i];
      final bg = i.isOdd ? cStripe : null;
      totalBase += r.baseAmountLc;
      totalWht  += r.whtAmountLc;

      final nameAddr = r.addressLine != null
          ? '${r.vendorNameTh}\n${r.addressLine}'
          : r.vendorNameTh;
      final incomeLabel = r.incomeType != null
          ? '${r.incomeType}${(r.whtType ?? '').isNotEmpty ? "\n${r.whtType}" : ""}'
          : (r.whtType ?? '');

      rows.add(pw.Container(
        color: bg,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3)),
        ),
        child: pw.Row(children: [
          cell(wNo,     '${i + 1}',                         tN(8), a: pw.TextAlign.center),
          cell(wName,   nameAddr,                             tN(8)),
          cell(wTaxId,  r.taxId ?? '—',                      tN(8), a: pw.TextAlign.center),
          cell(wDate,   _dateFmt.format(r.paymentDate),       tN(8), a: pw.TextAlign.center),
          cell(wIncome, incomeLabel,                           tN(8)),
          cell(wRate,   r.whtRate > 0 ? '${r.whtRate.toStringAsFixed(0)}%' : '—',
                                                               tN(8), a: pw.TextAlign.center),
          cell(wBase,   _fmt.format(r.baseAmountLc),           tN(8), a: pw.TextAlign.right),
          cell(wWht,    _fmt.format(r.whtAmountLc),            tN(8), a: pw.TextAlign.right),
          cell(wDoc,    r.paymentDocNo,                         tN(8)),
        ]),
      ));
    }

    // แถวรวม
    rows.add(pw.Container(
      color: cTotal,
      child: pw.Row(children: [
        cell(wNo + wName + wTaxId + wDate + wIncome + wRate, 'รวมทั้งสิ้น  ${_reportData.length} รายการ',
            tB(8), a: pw.TextAlign.right),
        cell(wBase, _fmt.format(totalBase), tB(8), a: pw.TextAlign.right),
        cell(wWht,  _fmt.format(totalWht),  tB(8), a: pw.TextAlign.right),
        cell(wDoc,  '',                     tN(8)),
      ]),
    ));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(mg),
      header: (ctx) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
          pw.Expanded(flex: 6, child: pw.Text(
            'หนังสือรับรองการหักภาษี ณ ที่จ่าย  $_formTitle\nเดือน: $_periodLabel',
            textAlign: pw.TextAlign.center,
            style: tB(13),
          )),
          pw.Expanded(flex: 3, child: pw.Text(
            'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: tN(10),
          )),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Text('พิมพ์โดย $userName  |  พิมพ์เมื่อ $printDate', style: tN(9)),
        ]),
        pw.SizedBox(height: 4),
        hdrRow(),
      ]),
      build: (_) => rows,
    ));

    return doc.save();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(6, (i) => currentYear - 3 + i); // -3 to +2

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFW = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── toggle button ──────────────────────────────────────────────────
          Container(
            width: 36, color: Colors.blue[900],
            child: IconButton(
              icon: Icon(
                _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.white, size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
            ),
          ),

          // ── filter panel ───────────────────────────────────────────────────
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
                        const Text('เงื่อนไขรายงาน',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),

                        // เดือน
                        DropdownButtonFormField<int>(
                          value: _month,
                          decoration: const InputDecoration(
                            labelText: 'เดือน',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(12, (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}  ${_monthNames[i + 1]}'),
                          )),
                          onChanged: (v) => setState(() => _month = v ?? _month),
                        ),
                        const SizedBox(height: 16),

                        // ปี
                        DropdownButtonFormField<int>(
                          value: _year,
                          decoration: const InputDecoration(
                            labelText: 'ปี (ค.ศ.)',
                            border: OutlineInputBorder(),
                          ),
                          items: years.map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('$y  (พ.ศ. ${y + 543})'),
                          )).toList(),
                          onChanged: (v) => setState(() => _year = v ?? _year),
                        ),
                        const SizedBox(height: 16),

                        // แบบฟอร์ม
                        DropdownButtonFormField<String>(
                          value: _pndForm,
                          decoration: const InputDecoration(
                            labelText: 'แบบฟอร์ม',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'pnd53', child: Text('ภ.ง.ด.53  (นิติบุคคล)')),
                            DropdownMenuItem(value: 'pnd3',  child: Text('ภ.ง.ด.3   (บุคคลธรรมดา)')),
                          ],
                          onChanged: (v) => setState(() => _pndForm = v ?? _pndForm),
                        ),

                        const Spacer(),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('ประมวลผลรายงาน'),
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

          // ── drag divider ───────────────────────────────────────────────────
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

          // ── PDF preview ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: _reportData.isEmpty
                  ? const Center(child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                  : PdfPreview(
                      key: ValueKey(_pdfKey),
                      build: _generatePdf,
                      initialPageFormat: PdfPageFormat.a4.landscape,
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
            ),
          ),
        ]);
      }),
    );
  }
}
