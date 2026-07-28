import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/file_download.dart';

import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_fx_gain_loss_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/models/cd_salesperson.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../cd/services/cd_salesperson_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_language_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

class ArFxGainLossReportScreen extends StatefulWidget {
  const ArFxGainLossReportScreen({super.key});

  @override
  State<ArFxGainLossReportScreen> createState() =>
      _ArFxGainLossReportScreenState();
}

class _ArFxGainLossReportScreenState
    extends State<ArFxGainLossReportScreen> {
  final _reportService      = ArFxGainLossReportService();
  final _companyService     = CompanyService();
  final _authService        = AuthService();
  final _groupService       = ArCustomerGroupService();
  final _salespersonService = SalespersonService();
  final _currencyService    = CurrencyService();

  bool   _isLoading         = false;
  bool   _isExporting       = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isEnglish         = false;

  Company? _company;
  Map<String, String>? _headers;
  String _baseCurrencyCode  = '';

  List<ArCustomerGroup> _customerGroups  = [];
  List<Salesperson>     _salespersons    = [];
  List<Currency>        _foreignCurrencies = []; // active, non-base

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  String? _selectedCurrencyCode;
  List<int> _selectedGroupIds = [];
  int?    _selectedSalespersonId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel  = '';
  String  _toLabel    = '';
  bool    _fxOnly     = false;
  String  _sortBy     = 'customer'; // 'customer' | 'net_desc' | 'net_asc'

  // Report data
  List<Map<String, dynamic>> _reportRows = [];
  String _reportBaseCurrency             = '';

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    _headers = await _authService.getAuthHeader();
    final results = await Future.wait([
      _companyService.fetchCompany(),
      _groupService.fetchActiveRows(),
      _salespersonService.fetchRows(),
      _currencyService.fetchActiveRows(),
    ]);
    _company        = results[0] as Company?;
    _customerGroups = results[1] as List<ArCustomerGroup>;
    _salespersons   = (results[2] as List<Salesperson>)
        .where((s) => s.isActive).toList();
    final allCurrencies = results[3] as List<Currency>;
    _baseCurrencyCode   = allCurrencies
        .firstWhere((c) => c.baseCurrencyFlag,
            orElse: () => allCurrencies.first)
        .currencyCode;
    _foreignCurrencies  = allCurrencies
        .where((c) => !c.baseCurrencyFlag && c.isActive)
        .toList();
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportRows = []; });
    try {
      final raw = await _reportService.getFxGainLossReport(
        dateFrom:          DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:            DateFormat('yyyy-MM-dd').format(_dateTo),
        currencyCode:      _selectedCurrencyCode,
        customerGroupIds:  _selectedGroupIds,
        salespersonId:     _selectedSalespersonId,
        customerCodeFrom:  _customerCodeFrom,
        customerCodeTo:    _customerCodeTo,
        fxOnly:            _fxOnly,
        sortBy:            _sortBy,
      );
      final rows = List<Map<String, dynamic>>.from(raw['rows'] as List? ?? []);
      _reportBaseCurrency = raw['base_currency_code'] as String? ?? _baseCurrencyCode;
      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEnglish ? 'No data found for the selected date range' : 'ไม่พบข้อมูลในช่วงวันที่ที่เลือก')));
      }
      setState(() { _reportRows = rows; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSettingChanged() {
    if (_reportRows.isNotEmpty) setState(() => _pdfKey++);
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
    final dateRangeLine =
        '${isEnglish ? 'Receipt date' : 'วันที่รับชำระ'} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
    if (_selectedCurrencyCode != null) {
      conditions.add('${isEnglish ? 'Currency' : 'สกุลเงิน'}: $_selectedCurrencyCode');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _customerGroups.firstWhere((g) => g.id == id,
            orElse: () => _customerGroups.first);
        return '${g.groupCode} ${isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai}';
      }).join(', ');
      conditions.add('${isEnglish ? 'Group' : 'กลุ่ม'}: $names');
    }
    if (_selectedSalespersonId != null) {
      final s = _salespersons.firstWhere((s) => s.id == _selectedSalespersonId,
          orElse: () => _salespersons.first);
      conditions.add('${isEnglish ? 'Salesperson' : 'พนักงานขาย'}: ${s.salespersonCode} ${s.salespersonNameThai}');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty ||
        (_customerCodeTo   ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final f = (_customerCodeFrom ?? '').isEmpty ? all : _customerCodeFrom!;
      final t = (_customerCodeTo   ?? '').isEmpty ? all : _customerCodeTo!;
      conditions.add('${isEnglish ? 'Customer code' : 'รหัสลูกค้า'}: $f – $t');
    }
    if (_fxOnly) conditions.add(isEnglish ? 'Only with FX difference' : 'เฉพาะที่มีผลต่าง');
    switch (_sortBy) {
      case 'net_desc': conditions.add(isEnglish ? 'Sort by net gain, high to low' : 'เรียงกำไรสุทธิมากไปน้อย'); break;
      case 'net_asc':  conditions.add(isEnglish ? 'Sort by net gain, low to high' : 'เรียงกำไรสุทธิน้อยไปมาก'); break;
      default:         conditions.add(isEnglish ? 'Sort by customer code' : 'เรียงรหัสลูกหนี้');
    }
    final conditionLine = conditions.join(' | ');
    final showDetail    = _showDetail;

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3,
            child: pw.Text(companyName,
                style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text(isEnglish ? 'FX Gain/Loss Report' : 'รายงานกำไร/ขาดทุนจากอัตราแลกเปลี่ยน',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 14,
                    fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3,
            child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6,
            child: pw.Text(dateRangeLine,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(flex: 3,
            child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9,
            child: pw.Text(
                '* $conditionLine  [${isEnglish ? 'Base currency' : 'สกุลเงินหลัก'}: $_reportBaseCurrency]',
                style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 3,
            child: pw.Text(isEnglish ? 'Printed: $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 4),
    ]);

    // ─── Column widths (8 cols, landscape) ────────────────────────────────────
    // 0:รหัส-ชื่อ  1:สกุลเงิน  2:ยอด FC  3:อัตราใบแจ้งหนี้  4:อัตรารับชำระ
    // 5:กำไร FX    6:ขาดทุน FX  7:สุทธิ FX
    const colW = {
      0: pw.FlexColumnWidth(13),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(6),
      3: pw.FlexColumnWidth(5),
      4: pw.FlexColumnWidth(5),
      5: pw.FlexColumnWidth(6),
      6: pw.FlexColumnWidth(6),
      7: pw.FlexColumnWidth(6),
    };

    final fmtAmt  = NumberFormat('#,##0.00', 'en_US');
    final fmtRate = NumberFormat('#,##0.0000', 'en_US');

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font,     fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);
    pw.TextStyle tItalic(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);
    const cRed    = PdfColor(1.0,  0.90, 0.90);
    const cGray   = PdfColor(0.96, 0.96, 0.96);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t, style: tBold(8.5), textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s,
            {pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t, style: s, textAlign: a));

    pw.Widget amtCell(double v, pw.TextStyle s, {bool showZero = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 && !showZero ? '' : fmtAmt.format(v.abs()),
              style: s, textAlign: pw.TextAlign.right));

    pw.Widget netCell(double v, pw.TextStyle s) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 ? '–' : (v < 0 ? '(${fmtAmt.format(v.abs())})' : fmtAmt.format(v)),
              style: v < 0 ? pw.TextStyle(font: fontBold, fontSize: s.fontSize,
                  color: PdfColors.red700) : s,
              textAlign: pw.TextAlign.right));

    pw.Widget rateCell(double v, pw.TextStyle s) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 ? '' : fmtRate.format(v),
              style: s, textAlign: pw.TextAlign.right));

    // ─── Column header ────────────────────────────────────────────────────────
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Code – Customer Name' : 'รหัส – ชื่อลูกหนี้',        a: pw.TextAlign.left),
        hCell(isEnglish ? 'Currency' : 'สกุลเงิน'),
        hCell(isEnglish ? 'FC Amount' : 'ยอดเงินตปท.'),
        hCell(isEnglish ? 'Invoice Rate' : 'อัตราใบแจ้งหนี้'),
        hCell(isEnglish ? 'Receipt Rate' : 'อัตรารับชำระ'),
        hCell(isEnglish ? 'FX Gain' : 'กำไร FX'),
        hCell(isEnglish ? 'FX Loss' : 'ขาดทุน FX'),
        hCell(isEnglish ? 'FX Net' : 'สุทธิ FX'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    double grandGain = 0;
    double grandLoss = 0;
    double grandNet  = 0;
    int    totalGroups = 0;

    for (final grp in _reportRows) {
      totalGroups++;
      final code    = grp['customer_code']    as String? ?? '';
      final name    = grp['customer_name_th'] as String? ?? '';
      final cur     = grp['currency_code']    as String? ?? '';
      final totalFc = (grp['total_fc']           as num?)?.toDouble() ?? 0;
      final invRate = (grp['weighted_inv_rate']  as num?)?.toDouble() ?? 0;
      final recRate = (grp['weighted_rec_rate']  as num?)?.toDouble() ?? 0;
      final fxGain  = (grp['fx_gain']            as num?)?.toDouble() ?? 0;
      final fxLoss  = (grp['fx_loss']            as num?)?.toDouble() ?? 0;
      final fxNet   = (grp['fx_net']             as num?)?.toDouble() ?? 0;

      grandGain += fxGain;
      grandLoss += fxLoss;
      grandNet  += fxNet;

      final rowDec = fxNet < -0.005
          ? const pw.BoxDecoration(color: cRed)
          : showDetail
              ? const pw.BoxDecoration(color: cBlue)
              : null;

      tableRows.add(pw.TableRow(
        decoration: rowDec,
        children: [
          dCell('$code  $name', showDetail ? tBold(9) : tNormal(9)),
          dCell(cur,            showDetail ? tBold(9) : tNormal(9),
              a: pw.TextAlign.center),
          amtCell(totalFc,  showDetail ? tBold(9) : tNormal(9), showZero: true),
          rateCell(invRate, showDetail ? tBold(9) : tNormal(9)),
          rateCell(recRate, showDetail ? tBold(9) : tNormal(9)),
          amtCell(fxGain,   showDetail ? tBold(9) : tNormal(9)),
          amtCell(fxLoss,   showDetail ? tBold(9) : tNormal(9)),
          netCell(fxNet,    showDetail ? tBold(9) : tNormal(9)),
        ],
      ));

      if (!showDetail) continue;

      final details = (grp['details'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final d in details) {
        final recNo    = d['receipt_no']   as String? ?? '';
        final recDate  = _fmtDate(d['receipt_date'] as String?);
        final invNo    = d['invoice_no']   as String? ?? '';
        final fc       = (d['applied_fc']  as num?)?.toDouble() ?? 0;
        final dInvRate = (d['invoice_rate'] as num?)?.toDouble() ?? 0;
        final dRecRate = (d['receipt_rate'] as num?)?.toDouble() ?? 0;
        final fxAmt    = (d['fx_amount']   as num?)?.toDouble() ?? 0;
        final dGain    = fxAmt > 0 ? fxAmt : 0.0;
        final dLoss    = fxAmt < 0 ? fxAmt.abs() : 0.0;
        final label    = '     $recNo  $recDate  <<  $invNo';

        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: cGray),
          children: [
            dCell(label,     tItalic(8.5)),
            dCell(cur,       tItalic(8.5), a: pw.TextAlign.center),
            amtCell(fc,      tItalic(8.5), showZero: true),
            rateCell(dInvRate, tItalic(8.5)),
            rateCell(dRecRate, tItalic(8.5)),
            amtCell(dGain,   tItalic(8.5)),
            amtCell(dLoss,   tItalic(8.5)),
            netCell(fxAmt,   tItalic(8.5)),
          ],
        ));
      }
    }

    // ─── Grand total ──────────────────────────────────────────────────────────
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
          color: PdfColor(0.75, 0.88, 0.83)),
      children: [
        dCell(isEnglish ? 'Total ($totalGroups groups)' : 'รวมทั้งหมด ($totalGroups กลุ่ม)', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        amtCell(grandGain, tBold(9), showZero: true),
        amtCell(grandLoss, tBold(9), showZero: true),
        netCell(grandNet,  tBold(9)),
      ],
    ));

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
            children: tableRows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // showDetail ต้องเข้าถึงได้จาก _generatePdf ซึ่งอยู่ใน closure
  bool get _showDetail => __showDetail;
  bool __showDetail = false;

  // ─── Excel Export ────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    if (_reportRows.isEmpty || _isExporting) return;
    final isEnglish = _isEnglish;
    _isExporting = true; // synchronous — ป้องกัน re-entry ก่อน setState rebuild
    setState(() {});

    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = '${isEnglish ? 'AR_FX_Gain_Loss_Report' : 'รายงานกำไร-ขาดทุนจากอัตราแลกเปลี่ยน'}_$ts.xlsx';
    try {
      final ex = Excel.createExcel();
      final sh = ex['FX_GainLoss'];
      ex.delete('Sheet1');

      final hdrBg  = ExcelColor.fromHexString('#92D050'); // green header
      final totBg  = ExcelColor.fromHexString('#BDD7EE'); // blue totals
      final detBg  = ExcelColor.fromHexString('#F2F2F2'); // gray detail

      // ── Title block ──────────────────────────────────────────────────────
      final _tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(sh, 0, 0, TextCellValue(_company?.displayName(isEnglish) ?? ''), bold: true);
      _xlCell(sh, 1, 0, TextCellValue('${isEnglish ? 'FX Gain/Loss Report' : 'รายงานกำไร/ขาดทุนจากอัตราแลกเปลี่ยน'}  [${isEnglish ? 'Base currency' : 'สกุลเงินหลัก'}: $_reportBaseCurrency]'), bold: true);
      _xlCell(sh, 2, 0, TextCellValue('${isEnglish ? 'Receipt date' : 'วันที่รับชำระ'}: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $_tsLabel'));

      int row = 3;

      // ── Column headers ───────────────────────────────────────────────────
      final cols = isEnglish
          ? ['Code – Customer Name', 'Currency', 'FC Amount',
              'Invoice Rate', 'Receipt Rate', 'FX Gain', 'FX Loss', 'FX Net']
          : ['รหัส – ชื่อลูกหนี้', 'สกุลเงิน', 'ยอดเงินตปท.',
        'อัตราใบแจ้งหนี้', 'อัตรารับชำระ', 'กำไร FX', 'ขาดทุน FX', 'สุทธิ FX'];
      for (var i = 0; i < cols.length; i++) {
        _xlCell(sh, row, i, TextCellValue(cols[i]),
            bold: true, bg: hdrBg,
            align: i == 0 ? HorizontalAlign.Left : HorizontalAlign.Center);
      }
      row++;

      // ── Data rows ────────────────────────────────────────────────────────
      double grandGain = 0, grandLoss = 0, grandNet = 0;
      for (final grp in _reportRows) {
        final code    = grp['customer_code']    as String? ?? '';
        final name    = grp['customer_name_th'] as String? ?? '';
        final cur     = grp['currency_code']    as String? ?? '';
        final totalFc = (grp['total_fc']          as num?)?.toDouble() ?? 0;
        final invRate = (grp['weighted_inv_rate'] as num?)?.toDouble() ?? 0;
        final recRate = (grp['weighted_rec_rate'] as num?)?.toDouble() ?? 0;
        final fxGain  = (grp['fx_gain']           as num?)?.toDouble() ?? 0;
        final fxLoss  = (grp['fx_loss']           as num?)?.toDouble() ?? 0;
        final fxNet   = (grp['fx_net']            as num?)?.toDouble() ?? 0;

        grandGain += fxGain;
        grandLoss += fxLoss;
        grandNet  += fxNet;

        _xlCell(sh, row, 0, TextCellValue('$code  $name'));
        _xlCell(sh, row, 1, TextCellValue(cur), align: HorizontalAlign.Center);
        _xlCell(sh, row, 2, DoubleCellValue(totalFc), align: HorizontalAlign.Right);
        _xlCell(sh, row, 3, DoubleCellValue(invRate),  align: HorizontalAlign.Right);
        _xlCell(sh, row, 4, DoubleCellValue(recRate),  align: HorizontalAlign.Right);
        _xlCell(sh, row, 5, DoubleCellValue(fxGain),   align: HorizontalAlign.Right);
        _xlCell(sh, row, 6, DoubleCellValue(fxLoss),   align: HorizontalAlign.Right);
        _xlCell(sh, row, 7, DoubleCellValue(fxNet),    align: HorizontalAlign.Right);
        row++;

        if (_showDetail) {
          for (final d in (grp['details'] as List? ?? []).cast<Map<String, dynamic>>()) {
            final recNo    = d['receipt_no']   as String? ?? '';
            final recDate  = _fmtDate(d['receipt_date'] as String?);
            final invNo    = d['invoice_no']   as String? ?? '';
            final fc       = (d['applied_fc']  as num?)?.toDouble() ?? 0;
            final dInvRate = (d['invoice_rate'] as num?)?.toDouble() ?? 0;
            final dRecRate = (d['receipt_rate'] as num?)?.toDouble() ?? 0;
            final fxAmt    = (d['fx_amount']   as num?)?.toDouble() ?? 0;
            final dGain    = fxAmt > 0 ? fxAmt : 0.0;
            final dLoss    = fxAmt < 0 ? fxAmt.abs() : 0.0;

            _xlCell(sh, row, 0, TextCellValue('     $recNo  $recDate  <<  $invNo'), bg: detBg, italic: true);
            _xlCell(sh, row, 1, TextCellValue(cur), bg: detBg, italic: true, align: HorizontalAlign.Center);
            _xlCell(sh, row, 2, DoubleCellValue(fc),       bg: detBg, italic: true, align: HorizontalAlign.Right);
            _xlCell(sh, row, 3, DoubleCellValue(dInvRate), bg: detBg, italic: true, align: HorizontalAlign.Right);
            _xlCell(sh, row, 4, DoubleCellValue(dRecRate), bg: detBg, italic: true, align: HorizontalAlign.Right);
            _xlCell(sh, row, 5, DoubleCellValue(dGain),    bg: detBg, italic: true, align: HorizontalAlign.Right);
            _xlCell(sh, row, 6, DoubleCellValue(dLoss),    bg: detBg, italic: true, align: HorizontalAlign.Right);
            _xlCell(sh, row, 7, DoubleCellValue(fxAmt),    bg: detBg, italic: true, align: HorizontalAlign.Right);
            row++;
          }
        }
      }

      // ── Grand total ──────────────────────────────────────────────────────
      _xlCell(sh, row, 0, TextCellValue(isEnglish ? 'Total (${_reportRows.length} groups)' : 'รวมทั้งหมด (${_reportRows.length} กลุ่ม)'), bold: true, bg: totBg);
      for (var i = 1; i <= 4; i++) {
        _xlCell(sh, row, i, TextCellValue(''), bg: totBg);
      }
      _xlCell(sh, row, 5, DoubleCellValue(grandGain), bold: true, bg: totBg, align: HorizontalAlign.Right);
      _xlCell(sh, row, 6, DoubleCellValue(grandLoss), bold: true, bg: totBg, align: HorizontalAlign.Right);
      _xlCell(sh, row, 7, DoubleCellValue(grandNet),  bold: true, bg: totBg, align: HorizontalAlign.Right);

      // ── Column widths ────────────────────────────────────────────────────
      sh.setColumnWidth(0, 38);
      sh.setColumnWidth(1, 10);
      sh.setColumnWidth(2, 15);
      sh.setColumnWidth(3, 15);
      sh.setColumnWidth(4, 15);
      sh.setColumnWidth(5, 15);
      sh.setColumnWidth(6, 15);
      sh.setColumnWidth(7, 15);

      final bytes = ex.encode();
      if (bytes == null) return;

      final savedPath = await downloadFile(bytes, filename);
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'File saved: $savedPath' : 'บันทึกไฟล์แล้ว: $savedPath'),
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(isEnglish ? 'Export failed: $e' : 'Export ล้มเหลว: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(
    Sheet sh, int row, int col, CellValue value, {
    bool bold = false,
    bool italic = false,
    ExcelColor? bg,
    HorizontalAlign? align,
    int? fontSize,
  }) {
    final cell = sh.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    cell.cellStyle = CellStyle(
      bold: bold,
      italic: italic,
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      fontSize: fontSize,
    );
  }

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy')
          .format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: (_reportRows.isEmpty || _isExporting || !canExport) ? null : _exportExcel,
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
                      tooltip: _isFilterExpanded
                          ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                          : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
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
                          child: Column(children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 16),

                                    // วันที่รับชำระ
                                    _buildDateField(
                                        label: isEnglish ? 'Receipt Date From' : 'วันที่รับชำระ ตั้งแต่',
                                        date: _dateFrom,
                                        onPick: (d) =>
                                            setState(() => _dateFrom = d)),
                                    const SizedBox(height: 12),
                                    _buildDateField(
                                        label: isEnglish ? 'Receipt Date To' : 'วันที่รับชำระ ถึง',
                                        date: _dateTo,
                                        onPick: (d) =>
                                            setState(() => _dateTo = d)),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // สกุลเงิน (เฉพาะสกุลเงินต่างประเทศ)
                                    DropdownButtonFormField<String?>(
                                      isExpanded: true,
                                      value: _selectedCurrencyCode,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Currency' : 'สกุลเงิน',
                                          hintText: _baseCurrencyCode.isNotEmpty
                                              ? (isEnglish ? '(Except $_baseCurrencyCode)' : '(ยกเว้น $_baseCurrencyCode)')
                                              : null,
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(isEnglish ? '— All Currencies —' : '— ทุกสกุลเงิน —')),
                                        ..._foreignCurrencies.map((c) =>
                                            DropdownMenuItem<String?>(
                                              value: c.currencyCode,
                                              child: Text(
                                                  '${c.currencyCode}  ${isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai}',
                                                  overflow: TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _selectedCurrencyCode = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // กลุ่มลูกหนี้
                                    ArCustomerGroupMultiPicker(
                                      groups: _customerGroups,
                                      selectedIds: _selectedGroupIds,
                                      label: isEnglish ? 'Customer Groups' : 'กลุ่มลูกหนี้',
                                      onChanged: (v) =>
                                          setState(() => _selectedGroupIds = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // พนักงานขาย
                                    DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      value: _selectedSalespersonId,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Salesperson' : 'พนักงานขาย',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                                        ..._salespersons.map((s) =>
                                            DropdownMenuItem<int?>(
                                              value: s.id,
                                              child: Text(
                                                  '${s.salespersonCode}  ${s.salespersonNameThai}',
                                                  overflow: TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _selectedSalespersonId = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // รหัสลูกหนี้ ตั้งแต่ / ถึง
                                    _buildCustomerCodeField(
                                        label: isEnglish ? 'Customer Code From' : 'รหัสลูกหนี้ ตั้งแต่',
                                        displayText: _fromLabel,
                                        onPick: () =>
                                            _pickCustomer(isFrom: true),
                                        onClear: () => setState(() {
                                          _customerCodeFrom = null;
                                          _fromLabel = '';
                                        })),
                                    const SizedBox(height: 8),
                                    _buildCustomerCodeField(
                                        label: isEnglish ? 'Customer Code To' : 'รหัสลูกหนี้ ถึง',
                                        displayText: _toLabel,
                                        onPick: () =>
                                            _pickCustomer(isFrom: false),
                                        onClear: () => setState(() {
                                          _customerCodeTo = null;
                                          _toLabel = '';
                                        })),

                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // จัดเรียงข้อมูล
                                    DropdownButtonFormField<String>(
                                      value: _sortBy,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Sort By' : 'จัดเรียงข้อมูล',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'customer',
                                            child: Text(isEnglish ? 'Customer Code' : 'รหัสลูกหนี้')),
                                        DropdownMenuItem(
                                            value: 'net_desc',
                                            child: Text(isEnglish ? 'Net Gain, High to Low' : 'กำไรสุทธิ มากไปน้อย')),
                                        DropdownMenuItem(
                                            value: 'net_asc',
                                            child: Text(isEnglish ? 'Net Gain, Low to High' : 'กำไรสุทธิ น้อยไปมาก')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _sortBy = v);
                                          _onSettingChanged();
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 8),

                                    // แสดงรายละเอียดใบแจ้งหนี้
                                    Row(children: [
                                      Expanded(
                                        child: Text(isEnglish ? 'Show invoice details' : 'แสดงรายละเอียดใบแจ้งหนี้',
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                      Switch(
                                        value: __showDetail,
                                        activeColor: Colors.teal[800],
                                        onChanged: (v) {
                                          setState(() => __showDetail = v);
                                          _onSettingChanged();
                                        },
                                      ),
                                    ]),

                                    // แสดงเฉพาะที่มีผลต่าง
                                    Row(children: [
                                      Expanded(
                                        child: Text(isEnglish ? 'Show only those with FX difference' : 'แสดงเฉพาะที่มีผลต่าง',
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                      Switch(
                                        value: _fxOnly,
                                        activeColor: Colors.teal[800],
                                        onChanged: (v) =>
                                            setState(() => _fxOnly = v),
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
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[800],
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
                              (_filterPanelWidth + d.delta.dx)
                                  .clamp(200.0, maxFilterWidth);
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
                          : _reportRows.isEmpty
                              ? Center(
                                  child: Text(isEnglish ? 'Please select filter conditions and click Generate Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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

  // ─── filter helpers ───────────────────────────────────────────────────────

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

  Future<void> _pickCustomer({required bool isFrom}) async {
    final result = await showDialog<ArCustomer>(
      context: context,
      builder: (_) => const _FxCustomerSearchDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        final label = '${result.customerCode}  ${result.customerNameTh}';
        if (isFrom) {
          _customerCodeFrom = result.customerCode;
          _fromLabel        = label;
        } else {
          _customerCodeTo = result.customerCode;
          _toLabel        = label;
        }
      });
    }
  }

  Widget _buildCustomerCodeField({
    required String label,
    required String displayText,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final isEnglish = _isEnglish;
    final hasValue = displayText.isNotEmpty;
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
                    child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(
              onTap: onPick,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.search, size: 18, color: Colors.teal[800]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (isEnglish ? '— All —' : '— ทั้งหมด —'),
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Customer search dialog ────────────────────────────────────────────────────

class _FxCustomerSearchDialog extends StatefulWidget {
  const _FxCustomerSearchDialog();

  @override
  State<_FxCustomerSearchDialog> createState() =>
      _FxCustomerSearchDialogState();
}

class _FxCustomerSearchDialogState extends State<_FxCustomerSearchDialog> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _svc    = ArCustomerService();
  List<ArCustomer> _list = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchRows(
          search: q.trim().isEmpty ? null : q.trim());
      if (mounted) setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.teal[800],
              child: Text(isEnglish ? 'Search Customer' : 'ค้นหาลูกหนี้',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: isEnglish ? 'Search by customer code or name' : 'ค้นหาจากรหัสหรือชื่อลูกหนี้',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true),
                onChanged: _search,
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                SizedBox(width: 100,
                    child: Text(isEnglish ? 'Code' : 'รหัส',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text(isEnglish ? 'Customer Name' : 'ชื่อลูกหนี้',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? Center(
                          child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                              style: const TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: _scroll,
                          itemCount: _list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 12),
                          itemBuilder: (ctx, i) {
                            final c = _list[i];
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, c),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(children: [
                                  SizedBox(width: 100,
                                      child: Text(c.customerCode,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500))),
                                  Expanded(
                                      child: Text(
                                          isEnglish && (c.customerNameEn?.isNotEmpty ?? false)
                                              ? c.customerNameEn!
                                              : c.customerNameTh,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis)),
                                ]),
                              ),
                            );
                          }),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
