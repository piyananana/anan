// lib/cm/screens/cm_check_report_screen.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../models/cm_bank_account.dart';
import '../widgets/cm_bank_account_list_widget.dart';
import '../services/cm_report_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_download.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmCheckReportScreen extends StatefulWidget {
  const CmCheckReportScreen({super.key});
  @override
  State<CmCheckReportScreen> createState() => _State();
}

class _State extends State<CmCheckReportScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _rptSvc     = CmReportService();
  final _companySvc = CompanyService();
  final _authSvc    = AuthService();

  bool _isEnglish = false;
  bool _isFilterExpanded  = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider  = false;
  int  _pdfKey = 0;
  bool _isExporting = false;

  Company? _company;
  Map<String, String>? _headers;
  // ชื่อรายงาน — ใช้ชื่อเมนู (จาก AppBar/MenuTitle) แทนข้อความ hardcode เพื่อให้ตรงกับที่ผู้ใช้เห็นบนแท็บเสมอ
  String _reportTitle = '';

  CmBankAccount? _accountFrom;
  CmBankAccount? _accountTo;

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  String _checkType = 'All'; // All / RECEIVED / ISSUED
  String _status    = 'All'; // All / Pending / Cleared / Bounced / Voided
  bool _loading = false;

  List<Map<String, dynamic>> _checks = [];
  double _totalIssued   = 0;
  double _totalReceived = 0;
  String? _reportDateFrom;
  String? _reportDateTo;

  static const _checkTypes     = ['All', 'RECEIVED', 'ISSUED'];
  static const _checkLabels    = {'All': 'ทุกประเภท', 'RECEIVED': 'รับเช็ค', 'ISSUED': 'จ่ายเช็ค'};
  static const _checkLabelsEng = {'All': 'All Types', 'RECEIVED': 'Received', 'ISSUED': 'Issued'};
  static const _statusOptions  = ['All', 'Pending', 'Cleared', 'Bounced', 'Voided'];
  static const _statusLabels   = {
    'All': 'ทุกสถานะ', 'Pending': 'รอเรียกเก็บ',
    'Cleared': 'ผ่านเรียบร้อย', 'Bounced': 'เช็คคืน', 'Voided': 'ยกเลิก',
  };
  static const _statusLabelsEng = {
    'All': 'All Statuses', 'Pending': 'Pending',
    'Cleared': 'Cleared', 'Bounced': 'Bounced', 'Voided': 'Voided',
  };

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    _headers = await _authSvc.getAuthHeader();
    _company = await _companySvc.fetchCompany();
    if (mounted) setState(() {});
  }

  Future<void> _loadReport() async {
    if (_dateFrom.isAfter(_dateTo)) {
      _showError(_isEnglish ? 'Please specify a valid date range' : 'กรุณาระบุช่วงวันที่ให้ถูกต้อง');
      return;
    }
    setState(() { _loading = true; _checks = []; });
    try {
      final df = formatLocalDate(_dateFrom);
      final dt = formatLocalDate(_dateTo);
      final data = await _rptSvc.getCheckRegister(
        accountCodeFrom: _accountFrom?.accountCode,
        accountCodeTo:   _accountTo?.accountCode,
        dateFrom: df, dateTo: dt,
        checkType: _checkType == 'All' ? null : _checkType,
        status:    _status    == 'All' ? null : _status,
      );
      if (!mounted) return;
      final checks = List<Map<String, dynamic>>.from(data['checks'] as List);
      if (checks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No checks found for the selected conditions' : 'ไม่พบเช็คตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _checks        = checks;
        _totalIssued   = _parseD(data['total_issued']);
        _totalReceived = _parseD(data['total_received']);
        _reportDateFrom = df;
        _reportDateTo   = dt;
        _loading = false;
        _pdfKey++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  double _parseD(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  String _acctName(CmBankAccount a) =>
      _isEnglish && (a.accountNameEn ?? '').isNotEmpty ? a.accountNameEn! : a.accountNameTh;

  String _rowAcctName(Map<String, dynamic> c) {
    final nameEn = c['bank_account_name_en'] as String?;
    return _isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (c['bank_account_name'] as String? ?? '');
  }

  String _checkTypeLabel(String t, bool isEnglish) =>
      isEnglish ? (_checkLabelsEng[t] ?? t) : (_checkLabels[t] ?? t);

  String _statusLabel(String s, bool isEnglish) =>
      isEnglish ? (_statusLabelsEng[s] ?? s) : (_statusLabels[s] ?? s);

  // ─── PDF ──────────────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ??
        (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine =
        '${isEnglish ? 'Date range' : 'ช่วงวันที่'} ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))}'
        ' – ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}';

    final allLabel = isEnglish ? '(All)' : '(ทั้งหมด)';
    final conditions = <String>[];
    if (_accountFrom != null || _accountTo != null) {
      conditions.add(
          '${isEnglish ? 'Account code' : 'รหัสบัญชี'}: ${_accountFrom?.accountCode ?? allLabel}'
          ' – ${_accountTo?.accountCode ?? allLabel}');
    }
    if (_checkType != 'All') conditions.add('${isEnglish ? 'Type' : 'ประเภท'}: ${_checkTypeLabel(_checkType, isEnglish)}');
    if (_status != 'All')    conditions.add('${isEnglish ? 'Status' : 'สถานะ'}: ${_statusLabel(_status, isEnglish)}');
    final conditionLine = conditions.isEmpty ? '' : conditions.join(' | ');

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text(reportTitle,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3,
            child: pw.Text(
                isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6,
            child: pw.Text(dateRangeLine, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(flex: 3,
            child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
                textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
      ]),
      if (conditionLine.isNotEmpty) ...[
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.Text('* $conditionLine', style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 3,
              child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
        ]),
      ] else ...[
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.SizedBox()),
          pw.Expanded(flex: 3,
              child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
        ]),
      ],
      pw.SizedBox(height: 4),
    ]);

    const colW = {
      0: pw.FlexColumnWidth(2.5), // ประเภท
      1: pw.FlexColumnWidth(2.5), // วันที่
      2: pw.FlexColumnWidth(2.5), // เลขที่เช็ค
      3: pw.FlexColumnWidth(2.5), // วันที่เช็ค
      4: pw.FlexColumnWidth(2.5), // เลขที่อ้างอิง
      5: pw.FlexColumnWidth(2.5), // บัญชีธนาคาร
      6: pw.FlexColumnWidth(4),   // ชื่อบัญชี
      7: pw.FlexColumnWidth(4),   // คู่ค้า
      8: pw.FlexColumnWidth(3),   // จำนวนเงิน
      9: pw.FlexColumnWidth(2.5), // เลขที่เอกสาร
      10: pw.FlexColumnWidth(2.5),// สถานะ
    };

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cTotal = PdfColor(0.75, 0.88, 0.83);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(t, style: tBold(8.5), textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s, {pw.TextAlign a = pw.TextAlign.left}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(t, style: s, textAlign: a));

    pw.Widget amtCell(double v, pw.TextStyle s) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(_fmt.format(v), style: s, textAlign: pw.TextAlign.right));

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Type' : 'ประเภท'),
        hCell(isEnglish ? 'Date' : 'วันที่'),
        hCell(isEnglish ? 'Check No.' : 'เลขที่เช็ค'),
        hCell(isEnglish ? 'Check Date' : 'วันที่เช็ค'),
        hCell(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'),
        hCell(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Account Name' : 'ชื่อบัญชี', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Counterparty' : 'คู่ค้า', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Amount' : 'จำนวนเงิน'),
        hCell(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร'),
        hCell(isEnglish ? 'Status' : 'สถานะ'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    for (final c in _checks) {
      final isReceived = c['check_type'] == 'RECEIVED';
      final recordDate = parseLocalDateNullable(c['record_date']);
      final checkDate  = parseLocalDateNullable(c['check_date']);
      tableRows.add(pw.TableRow(children: [
        dCell(isReceived ? (isEnglish ? 'Received' : 'รับเช็ค') : (isEnglish ? 'Issued' : 'จ่ายเช็ค'), tNormal(9), a: pw.TextAlign.center),
        dCell(recordDate != null ? _dateFmt.format(recordDate) : '', tNormal(9), a: pw.TextAlign.center),
        dCell(c['check_no'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
        dCell(checkDate != null ? _dateFmt.format(checkDate) : '', tNormal(9), a: pw.TextAlign.center),
        dCell(c['reference_no'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
        dCell(c['bank_account_code'] as String? ?? '', tNormal(9)),
        dCell(_rowAcctName(c), tNormal(9)),
        dCell(c['party_name'] as String? ?? '', tNormal(9)),
        amtCell(_parseD(c['amount_lc']), tNormal(9)),
        dCell(c['doc_no'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
        dCell(_statusLabel(c['status'] as String? ?? '', isEnglish), tNormal(9), a: pw.TextAlign.center),
      ]));
    }

    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: cTotal),
      children: [
        dCell(isEnglish ? 'Total' : 'รวม', tBold(9)),
        dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)),
        dCell(isEnglish ? 'Received ${_fmt.format(_totalReceived)} / Issued ${_fmt.format(_totalIssued)}'
            : 'รับ ${_fmt.format(_totalReceived)} / จ่าย ${_fmt.format(_totalIssued)}', tBold(9)),
        dCell('', tBold(9)), dCell('', tBold(9)),
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

  // ─── Excel Export ─────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    setState(() => _isExporting = true);
    try {
      final ex    = Excel.createExcel();
      const sheet = 'CheckRegister';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'Date range' : 'ช่วงวันที่'}: ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Type', 'Date', 'Check No.', 'Check Date', 'Reference No.', 'Bank Account', 'Account Name', 'Counterparty', 'Amount', 'Doc No.', 'Status']
          : ['ประเภท', 'วันที่', 'เลขที่เช็ค', 'วันที่เช็ค', 'เลขที่อ้างอิง', 'บัญชีธนาคาร', 'ชื่อบัญชี', 'คู่ค้า', 'จำนวนเงิน', 'เลขที่เอกสาร', 'สถานะ'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      for (final c in _checks) {
        final isReceived = c['check_type'] == 'RECEIVED';
        final recordDate = parseLocalDateNullable(c['record_date']);
        final checkDate  = parseLocalDateNullable(c['check_date']);
        _xlCell(s, row, 0, isReceived ? (isEnglish ? 'Received' : 'รับเช็ค') : (isEnglish ? 'Issued' : 'จ่ายเช็ค'));
        _xlCell(s, row, 1, recordDate != null ? _dateFmt.format(recordDate) : '');
        _xlCell(s, row, 2, c['check_no'] ?? '');
        _xlCell(s, row, 3, checkDate != null ? _dateFmt.format(checkDate) : '');
        _xlCell(s, row, 4, c['reference_no'] ?? '');
        _xlCell(s, row, 5, c['bank_account_code'] ?? '');
        _xlCell(s, row, 6, _rowAcctName(c));
        _xlCell(s, row, 7, c['party_name'] ?? '');
        _xlCell(s, row, 8, _parseD(c['amount_lc']), align: HorizontalAlign.Right);
        _xlCell(s, row, 9, c['doc_no'] ?? '');
        _xlCell(s, row, 10, _statusLabel(c['status'] as String? ?? '', isEnglish));
        row++;
      }

      _xlCell(s, row, 0, isEnglish ? 'Total' : 'รวม', bg: totBg, bold: true);
      _xlCell(s, row, 7, isEnglish ? 'Received' : 'รับ', bg: totBg, bold: true);
      _xlCell(s, row, 8, _totalReceived, bg: totBg, bold: true, align: HorizontalAlign.Right);
      row++;
      _xlCell(s, row, 7, isEnglish ? 'Issued' : 'จ่าย', bg: totBg, bold: true);
      _xlCell(s, row, 8, _totalIssued, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'Check_Register_Report' : 'รายงานทะเบียนเช็ค';
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

  // ─── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canPrint = perm?.canPrint ?? true;
    final canExport = perm?.canExport ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Check Register Report' : 'รายงานทะเบียนเช็ค'));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _kTheme,
          foregroundColor: Colors.white,
          title: const MenuTitle(),
          toolbarHeight: 40,
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
                onPressed: (_checks.isEmpty || !canExport) ? null : _exportExcel,
              ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: isEnglish ? 'Data' : 'ข้อมูล'),
              Tab(text: isEnglish ? 'Report' : 'รายงาน'),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (_, constraints) {
            final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toggle strip
                Container(
                  width: 36,
                  color: _kTheme,
                  child: IconButton(
                    padding: EdgeInsets.zero, iconSize: 20, color: Colors.white,
                    icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list),
                    tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse Filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand Filter' : 'ขยายเงื่อนไข'),
                    onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                  ),
                ),
                // Filter panel
                AnimatedContainer(
                  duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                  width: _isFilterExpanded ? _filterPanelWidth : 0.0,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: _filterPanelWidth, minWidth: _filterPanelWidth,
                      child: _buildFilterPanel(isEnglish),
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
                // Right panel — Data / Report tabs
                Expanded(
                  child: TabBarView(children: [
                    _buildDataTab(isEnglish),
                    _buildReportTab(isEnglish, canPrint),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterPanel(bool isEnglish) {
    return Card(
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

                // บัญชีธนาคาร จาก / ถึง — search dialog picker (bilingual)
                _buildAccountField(
                  label: isEnglish ? 'Bank Account From' : 'บัญชีธนาคาร จาก',
                  value: _accountFrom,
                  onPick: () => CmBankAccountListWidget.search(context,
                      onSelected: (a) => setState(() => _accountFrom = a)),
                  onClear: () => setState(() => _accountFrom = null),
                ),
                const SizedBox(height: 12),
                _buildAccountField(
                  label: isEnglish ? 'Bank Account To' : 'บัญชีธนาคาร ถึง',
                  value: _accountTo,
                  onPick: () => CmBankAccountListWidget.search(context,
                      onSelected: (a) => setState(() => _accountTo = a)),
                  onClear: () => setState(() => _accountTo = null),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // วันที่ ตั้งแต่ / ถึง
                _buildDateField(
                    label: isEnglish ? 'Date From' : 'วันที่ ตั้งแต่',
                    date: _dateFrom, onPick: (d) => setState(() => _dateFrom = d)),
                const SizedBox(height: 12),
                _buildDateField(
                    label: isEnglish ? 'Date To' : 'วันที่ ถึง',
                    date: _dateTo, onPick: (d) => setState(() => _dateTo = d)),
                const SizedBox(height: 12),

                // ประเภทเช็ค
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _checkType,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Check Type' : 'ประเภทเช็ค',
                      border: const OutlineInputBorder(), isDense: true),
                  items: _checkTypes.map((t) => DropdownMenuItem(
                      value: t, child: Text(_checkTypeLabel(t, isEnglish)))).toList(),
                  onChanged: (v) => setState(() => _checkType = v!),
                ),
                const SizedBox(height: 12),

                // สถานะ
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _status,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Status' : 'สถานะ',
                      border: const OutlineInputBorder(), isDense: true),
                  items: _statusOptions.map((s) => DropdownMenuItem(
                      value: s, child: Text(_statusLabel(s, isEnglish)))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
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
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.assessment),
              label: Text(isEnglish ? 'Process Report' : 'ประมวลผลรายงาน'),
              style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
              onPressed: _loading ? null : _loadReport,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAccountField({
    required String label,
    required CmBankAccount? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final isEnglish = _isEnglish;
    final hasValue = value != null;
    final displayText = hasValue ? '${value.accountCode}  ${_acctName(value)}' : '';
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
                  child: Icon(Icons.search, size: 18, color: _kTheme))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (isEnglish ? '— All —' : '— ทั้งหมด —'),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, required DateTime date, required void Function(DateTime) onPick}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder(), isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 16)),
        child: Text(_dateFmt.format(date)),
      ),
    );
  }

  // ─── Data tab ─────────────────────────────────────────────────────────────
  Widget _buildDataTab(bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reportDateFrom != null) _buildReportHeader(isEnglish),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reportDateFrom == null
                  ? Center(child: Text(isEnglish ? 'Select conditions and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน', style: const TextStyle(color: Colors.grey)))
                  : _checks.isEmpty
                      ? Center(child: Text(isEnglish ? 'No checks in this period' : 'ไม่มีเช็คในช่วงเวลานี้', style: const TextStyle(color: Colors.grey)))
                      : _buildTable(isEnglish),
        ),
        if (_reportDateFrom != null && !_loading) _buildSummaryFooter(isEnglish),
      ],
    );
  }

  Widget _buildReportHeader(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: _kTheme.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_reportTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – '
            '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isEnglish) {
    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    const cellStyle   = TextStyle(fontSize: 12);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 38,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: headerStyle,
          columns: [
            DataColumn(label: Text(isEnglish ? 'Type' : 'ประเภท')),
            DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
            DataColumn(label: Text(isEnglish ? 'Check No.' : 'เลขที่เช็ค')),
            DataColumn(label: Text(isEnglish ? 'Check Date' : 'วันที่เช็ค')),
            DataColumn(label: Text(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง')),
            DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
            DataColumn(label: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี')),
            DataColumn(label: Text(isEnglish ? 'Counterparty' : 'คู่ค้า')),
            DataColumn(label: Text(isEnglish ? 'Amount' : 'จำนวนเงิน'), numeric: true),
            DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร')),
            DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
          ],
          rows: _checks.map((c) {
            final isReceived = c['check_type'] == 'RECEIVED';
            final amount = _parseD(c['amount_lc']);
            final status = c['status']?.toString() ?? '';
            final recordDate = parseLocalDateNullable(c['record_date']);
            final checkDate  = parseLocalDateNullable(c['check_date']);
            return DataRow(cells: [
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isReceived ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isReceived ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Text(
                  isReceived ? (isEnglish ? 'Received' : 'รับเช็ค') : (isEnglish ? 'Issued' : 'จ่ายเช็ค'),
                  style: TextStyle(fontSize: 11, color: isReceived ? Colors.green.shade800 : Colors.orange.shade800),
                ),
              )),
              DataCell(Text(
                recordDate != null ? _dateFmt.format(recordDate) : '',
                style: cellStyle,
              )),
              DataCell(Text(c['check_no'] ?? '', style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
              DataCell(Text(
                checkDate != null ? _dateFmt.format(checkDate) : '—',
                style: cellStyle,
              )),
              DataCell(Text(c['reference_no'] ?? '', style: cellStyle)),
              DataCell(Text(c['bank_account_code'] ?? '', style: cellStyle)),
              DataCell(SizedBox(
                width: 140,
                child: Text(_rowAcctName(c), style: cellStyle, overflow: TextOverflow.ellipsis),
              )),
              DataCell(SizedBox(
                width: 180,
                child: Text(c['party_name'] ?? '', style: cellStyle, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Text(_fmt.format(amount),
                  style: cellStyle.copyWith(fontWeight: FontWeight.w600,
                      color: isReceived ? Colors.green.shade700 : Colors.red.shade700))),
              DataCell(Text(c['doc_no'] ?? '', style: cellStyle)),
              DataCell(_buildStatusChip(status)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isEnglish = _isEnglish;
    Color bg, fg;
    String label;
    switch (status) {
      case 'Cleared':
        bg = Colors.green.shade100; fg = Colors.green.shade800; label = isEnglish ? 'Cleared' : 'ผ่านแล้ว';
      case 'Bounced':
        bg = Colors.red.shade100;   fg = Colors.red.shade800;   label = isEnglish ? 'Bounced' : 'เช็คคืน';
      case 'Voided':
        bg = Colors.grey.shade200;  fg = Colors.grey.shade700;  label = isEnglish ? 'Voided' : 'ยกเลิก';
      default:
        bg = Colors.blue.shade50;   fg = Colors.blue.shade800;  label = isEnglish ? 'Pending' : 'รอเรียกเก็บ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  Widget _buildSummaryFooter(bool isEnglish) {
    final issuedCount   = _checks.where((c) => c['check_type'] == 'ISSUED').length;
    final receivedCount = _checks.where((c) => c['check_type'] == 'RECEIVED').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        children: [
          Text(isEnglish ? 'Received: $receivedCount items' : 'รับเช็ค: $receivedCount รายการ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 16),
          Text(isEnglish ? 'Issued: $issuedCount items' : 'จ่ายเช็ค: $issuedCount รายการ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          _summaryItem(isEnglish ? 'Total Received' : 'รวมรับเช็ค', _totalReceived, Colors.green.shade700),
          const SizedBox(width: 24),
          _summaryItem(isEnglish ? 'Total Issued' : 'รวมจ่ายเช็ค', _totalIssued, Colors.red.shade700, bold: true),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(_fmt.format(value),
            style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  // ─── Report tab (PDF) ─────────────────────────────────────────────────────
  Widget _buildReportTab(bool isEnglish, bool canPrint) {
    return Container(
      color: Colors.grey[200],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reportDateFrom == null || _checks.isEmpty
              ? Center(child: Text(isEnglish ? 'Select conditions and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน'))
              : PdfPreview(
                  key: ValueKey(_pdfKey),
                  build: (fmt) => _generatePdf(fmt),
                  initialPageFormat: PdfPageFormat.a4.landscape,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: canPrint,
                  allowSharing: canPrint,
                ),
    );
  }
}
