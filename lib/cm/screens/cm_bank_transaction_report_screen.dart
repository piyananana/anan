// lib/cm/screens/cm_bank_transaction_report_screen.dart
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

class CmBankTransactionReportScreen extends StatefulWidget {
  const CmBankTransactionReportScreen({super.key});
  @override
  State<CmBankTransactionReportScreen> createState() => _State();
}

class _State extends State<CmBankTransactionReportScreen>
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
  String _recordType = 'All'; // All / RECEIPT / PAYMENT
  bool _loading = false;

  // Report data — one section per bank account
  List<Map<String, dynamic>> _accountSections = [];
  String? _reportDateFrom;
  String? _reportDateTo;

  static const _recordTypes = ['All', 'RECEIPT', 'PAYMENT'];
  static const _recordTypeLabels = {'All': 'ทุกประเภท', 'RECEIPT': 'รับเงิน', 'PAYMENT': 'จ่ายเงิน'};
  static const _recordTypeLabelsEng = {'All': 'All Types', 'RECEIPT': 'Receipt', 'PAYMENT': 'Payment'};

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
    setState(() { _loading = true; _accountSections = []; });
    try {
      final df = formatLocalDate(_dateFrom);
      final dt = formatLocalDate(_dateTo);
      final data = await _rptSvc.getBankTransactions(
        accountCodeFrom: _accountFrom?.accountCode,
        accountCodeTo:   _accountTo?.accountCode,
        dateFrom: df, dateTo: dt,
        recordType: _recordType == 'All' ? null : _recordType,
      );
      if (!mounted) return;
      final sections = List<Map<String, dynamic>>.from(data['accounts'] as List);
      if (sections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No accounts found for the selected conditions' : 'ไม่พบบัญชีตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _accountSections = sections;
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

  String _sectionAcctName(Map<String, dynamic> s) {
    final nameEn = s['bank_account_name_en'] as String?;
    return _isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (s['bank_account_name'] as String? ?? '');
  }

  String _recordTypeLabel(String t, bool isEnglish) =>
      isEnglish ? (_recordTypeLabelsEng[t] ?? t) : (_recordTypeLabels[t] ?? t);

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
    if (_recordType != 'All') {
      conditions.add('${isEnglish ? 'Type' : 'ประเภท'}: ${_recordTypeLabel(_recordType, isEnglish)}');
    }
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
      0: pw.FlexColumnWidth(3),   // วันที่
      1: pw.FlexColumnWidth(3),   // เลขที่เอกสาร
      2: pw.FlexColumnWidth(3),   // เลขที่อ้างอิง
      3: pw.FlexColumnWidth(2.5), // ประเภท
      4: pw.FlexColumnWidth(5),   // คำอธิบาย
      5: pw.FlexColumnWidth(2.5), // เลขที่เช็ค
      6: pw.FlexColumnWidth(3),   // จ่าย
      7: pw.FlexColumnWidth(3),   // รับ
      8: pw.FlexColumnWidth(3),   // ยอดคงเหลือ
    };

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cYellow = PdfColor(1.0, 0.98, 0.88);
    const cTotal  = PdfColor(0.75, 0.88, 0.83);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(t, style: tBold(8.5), textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s, {pw.TextAlign a = pw.TextAlign.left}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(t, style: s, textAlign: a));

    pw.Widget amtCell(double v, pw.TextStyle s, {bool blankZero = true}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(v == 0 && blankZero ? '' : _fmt.format(v), style: s, textAlign: pw.TextAlign.right));

    pw.TableRow buildHeaderRow() => pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Date' : 'วันที่'),
        hCell(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'),
        hCell(isEnglish ? 'Type' : 'ประเภท'),
        hCell(isEnglish ? 'Description' : 'คำอธิบาย', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Check No.' : 'เลขที่เช็ค'),
        hCell(isEnglish ? 'Debit' : 'จ่าย'),
        hCell(isEnglish ? 'Credit' : 'รับ'),
        hCell(isEnglish ? 'Balance' : 'ยอดคงเหลือ'),
      ],
    );

    final pageWidgets = <pw.Widget>[];

    for (final section in _accountSections) {
      final acctLine = '${section['bank_account_code'] ?? ''}  ${_sectionAcctName(section)}'
          '${(section['bank_short_name'] as String? ?? '').isNotEmpty ? ' (${section['bank_short_name']})' : ''}';
      final opening = _parseD(section['opening_balance']);
      final totalDebit  = _parseD(section['total_debit']);
      final totalCredit = _parseD(section['total_credit']);
      final closing = _parseD(section['closing_balance']);
      final txs = List<Map<String, dynamic>>.from(section['transactions'] as List? ?? []);

      final tableRows = <pw.TableRow>[
        buildHeaderRow(),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: cYellow),
          children: [
            dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)),
            dCell(isEnglish ? 'Opening Balance' : 'ยอดยกมา', tBold(9)),
            dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)),
            amtCell(opening, tBold(9), blankZero: false),
          ],
        ),
      ];

      for (final tx in txs) {
        final isReceipt  = tx['record_type'] == 'RECEIPT';
        final recordDate = parseLocalDateNullable(tx['record_date']);
        final debit      = _parseD(tx['debit_amount']);
        final credit     = _parseD(tx['credit_amount']);
        final balance    = _parseD(tx['running_balance']);
        tableRows.add(pw.TableRow(children: [
          dCell(recordDate != null ? _dateFmt.format(recordDate) : '', tNormal(9), a: pw.TextAlign.center),
          dCell(tx['doc_no'] as String? ?? '', tNormal(9)),
          dCell(tx['reference_no'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
          dCell(isReceipt ? (isEnglish ? 'Receipt' : 'รับเงิน') : (isEnglish ? 'Payment' : 'จ่ายเงิน'), tNormal(9), a: pw.TextAlign.center),
          dCell(tx['description'] as String? ?? '', tNormal(9)),
          dCell(tx['check_no'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
          amtCell(debit, tNormal(9)),
          amtCell(credit, tNormal(9)),
          amtCell(balance, tBold(9), blankZero: false),
        ]));
      }

      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: cTotal),
        children: [
          dCell(isEnglish ? 'Total' : 'รวม', tBold(9)),
          dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)),
          amtCell(totalDebit, tBold(9), blankZero: false),
          amtCell(totalCredit, tBold(9), blankZero: false),
          amtCell(closing, tBold(9), blankZero: false),
        ],
      ));

      pageWidgets.add(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4, top: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        color: cBlue,
        child: pw.Text(acctLine, style: tBold(10)),
      ));
      pageWidgets.add(pw.Table(
        border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
        columnWidths: colW,
        children: tableRows,
      ));
      pageWidgets.add(pw.SizedBox(height: 10));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: pageHeader(),
        build: (ctx) => pageWidgets,
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
      const sheet = 'BankTransactions';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final accBg = ExcelColor.fromHexString('#D9E1F2');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'Date range' : 'ช่วงวันที่'}: ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Date', 'Doc No.', 'Reference No.', 'Type', 'Description', 'Check No.', 'Debit', 'Credit', 'Balance']
          : ['วันที่', 'เลขที่เอกสาร', 'เลขที่อ้างอิง', 'ประเภท', 'คำอธิบาย', 'เลขที่เช็ค', 'จ่าย', 'รับ', 'ยอดคงเหลือ'];

      int row = 3;
      for (final section in _accountSections) {
        _xlCell(s, row, 0,
            '${section['bank_account_code'] ?? ''}  ${_sectionAcctName(section)} (${section['bank_short_name'] ?? ''})',
            bg: accBg, bold: true);
        row++;
        for (int i = 0; i < hdrs.length; i++) {
          _xlCell(s, row, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
        }
        row++;
        _xlCell(s, row, 3, isEnglish ? 'Opening Balance' : 'ยอดยกมา', bold: true);
        _xlCell(s, row, 8, _parseD(section['opening_balance']), bold: true, align: HorizontalAlign.Right);
        row++;

        final txs = List<Map<String, dynamic>>.from(section['transactions'] as List? ?? []);
        for (final tx in txs) {
          final isReceipt  = tx['record_type'] == 'RECEIPT';
          final recordDate = parseLocalDateNullable(tx['record_date']);
          _xlCell(s, row, 0, recordDate != null ? _dateFmt.format(recordDate) : '');
          _xlCell(s, row, 1, tx['doc_no'] ?? '');
          _xlCell(s, row, 2, tx['reference_no'] ?? '');
          _xlCell(s, row, 3, isReceipt ? (isEnglish ? 'Receipt' : 'รับเงิน') : (isEnglish ? 'Payment' : 'จ่ายเงิน'));
          _xlCell(s, row, 4, tx['description'] ?? '');
          _xlCell(s, row, 5, tx['check_no'] ?? '');
          _xlCell(s, row, 6, _parseD(tx['debit_amount']), align: HorizontalAlign.Right);
          _xlCell(s, row, 7, _parseD(tx['credit_amount']), align: HorizontalAlign.Right);
          _xlCell(s, row, 8, _parseD(tx['running_balance']), align: HorizontalAlign.Right);
          row++;
        }

        _xlCell(s, row, 0, isEnglish ? 'Total' : 'รวม', bg: totBg, bold: true);
        _xlCell(s, row, 6, _parseD(section['total_debit']),  bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 7, _parseD(section['total_credit']), bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 8, _parseD(section['closing_balance']), bg: totBg, bold: true, align: HorizontalAlign.Right);
        row += 2;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'Bank_Transaction_Report' : 'รายงานธุรกรรมธนาคาร';
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
        : (perm?.menuName ?? (isEnglish ? 'Bank Transaction Report' : 'รายงานธุรกรรมธนาคาร'));

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
                onPressed: (_accountSections.isEmpty || !canExport) ? null : _exportExcel,
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

                // ประเภทรายการ
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _recordType,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Type' : 'ประเภทรายการ',
                      border: const OutlineInputBorder(), isDense: true),
                  items: _recordTypes.map((t) => DropdownMenuItem(
                      value: t, child: Text(_recordTypeLabel(t, isEnglish)))).toList(),
                  onChanged: (v) => setState(() => _recordType = v!),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_reportDateFrom == null) {
      return Center(child: Text(isEnglish ? 'Select conditions and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน', style: const TextStyle(color: Colors.grey)));
    }
    if (_accountSections.isEmpty) {
      return Center(child: Text(isEnglish ? 'No data' : 'ไม่มีข้อมูล', style: const TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in _accountSections) ...[
            _buildSectionHeader(isEnglish, section),
            _buildSectionTable(isEnglish, section),
            _buildSectionFooter(isEnglish, section),
            const Divider(height: 24, thickness: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isEnglish, Map<String, dynamic> section) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: _kTheme.withOpacity(0.08),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${section['bank_account_code'] ?? ''}  ${_sectionAcctName(section)} '
                  '(${section['bank_short_name'] ?? ''})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – '
                  '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(isEnglish ? 'Opening Balance' : 'ยอดยกมา', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(_fmt.format(_parseD(section['opening_balance'])),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: _parseD(section['opening_balance']) >= 0 ? Colors.black87 : Colors.red.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTable(bool isEnglish, Map<String, dynamic> section) {
    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    const cellStyle   = TextStyle(fontSize: 12);
    final txs = List<Map<String, dynamic>>.from(section['transactions'] as List? ?? []);

    if (txs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(isEnglish ? 'No items in this period' : 'ไม่มีรายการในช่วงเวลานี้', style: const TextStyle(color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 38,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        headingTextStyle: headerStyle,
        columns: [
          DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
          DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร')),
          DataColumn(label: Text(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง')),
          DataColumn(label: Text(isEnglish ? 'Type' : 'ประเภท')),
          DataColumn(label: Text(isEnglish ? 'Description' : 'คำอธิบาย')),
          DataColumn(label: Text(isEnglish ? 'Check No.' : 'เลขที่เช็ค')),
          DataColumn(label: Text(isEnglish ? 'Debit' : 'จ่าย'),    numeric: true),
          DataColumn(label: Text(isEnglish ? 'Credit' : 'รับ'),     numeric: true),
          DataColumn(label: Text(isEnglish ? 'Balance' : 'ยอดคงเหลือ'), numeric: true),
        ],
        rows: txs.map((tx) {
          final isReceipt = tx['record_type'] == 'RECEIPT';
          final balance   = _parseD(tx['running_balance']);
          final recordDate = parseLocalDateNullable(tx['record_date']);
          return DataRow(cells: [
            DataCell(Text(
              recordDate != null ? _dateFmt.format(recordDate) : '',
              style: cellStyle,
            )),
            DataCell(Text(tx['doc_no'] ?? '', style: cellStyle)),
            DataCell(Text(tx['reference_no'] ?? '', style: cellStyle)),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isReceipt ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isReceipt ? Colors.green.shade200 : Colors.orange.shade200),
              ),
              child: Text(
                isReceipt ? (isEnglish ? 'Receipt' : 'รับเงิน') : (isEnglish ? 'Payment' : 'จ่ายเงิน'),
                style: TextStyle(fontSize: 11, color: isReceipt ? Colors.green.shade800 : Colors.orange.shade800),
              ),
            )),
            DataCell(SizedBox(
              width: 200,
              child: Text(tx['description'] ?? '', style: cellStyle, overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text(tx['check_no'] ?? '', style: cellStyle)),
            DataCell(Text(
              _parseD(tx['debit_amount']) > 0 ? _fmt.format(_parseD(tx['debit_amount'])) : '',
              style: cellStyle.copyWith(color: Colors.red.shade700),
            )),
            DataCell(Text(
              _parseD(tx['credit_amount']) > 0 ? _fmt.format(_parseD(tx['credit_amount'])) : '',
              style: cellStyle.copyWith(color: Colors.green.shade700),
            )),
            DataCell(Text(
              _fmt.format(balance),
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.black87 : Colors.red.shade700,
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildSectionFooter(bool isEnglish, Map<String, dynamic> section) {
    final totalDebit    = _parseD(section['total_debit']);
    final totalCredit   = _parseD(section['total_credit']);
    final closingBalance = _parseD(section['closing_balance']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _summaryItem(isEnglish ? 'Total Debit' : 'รวมจ่าย', totalDebit,   Colors.red.shade700),
          const SizedBox(width: 24),
          _summaryItem(isEnglish ? 'Total Credit' : 'รวมรับ',  totalCredit, Colors.green.shade700),
          const SizedBox(width: 24),
          _summaryItem(isEnglish ? 'Closing Balance' : 'ยอดปิด', closingBalance,
              closingBalance >= 0 ? Colors.black87 : Colors.red.shade700,
              bold: true),
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
          : _reportDateFrom == null || _accountSections.isEmpty
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
