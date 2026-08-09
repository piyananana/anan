// lib/cm/screens/cm_cash_flow_statement_screen.dart
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

class CmCashFlowStatementScreen extends StatefulWidget {
  const CmCashFlowStatementScreen({super.key});
  @override
  State<CmCashFlowStatementScreen> createState() => _State();
}

class _State extends State<CmCashFlowStatementScreen> with AutomaticKeepAliveClientMixin {
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

  CmBankAccount? _accountFrom;
  CmBankAccount? _accountTo;

  DateTime _dateFrom = DateTime(DateTime.now().year, 1, 1);
  DateTime _dateTo   = DateTime.now();
  bool _loading = false;

  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _totals;
  bool _hasReport = false;

  double _parseD(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

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
    setState(() { _loading = true; _rows = []; _totals = null; _hasReport = false; });
    try {
      final data = await _rptSvc.getCashFlowStatement(
        accountCodeFrom: _accountFrom?.accountCode,
        accountCodeTo:   _accountTo?.accountCode,
        dateFrom: formatLocalDate(_dateFrom),
        dateTo:   formatLocalDate(_dateTo),
      );
      if (!mounted) return;
      final rows = List<Map<String, dynamic>>.from(data['rows'] as List);
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No bank accounts found for the selected conditions' : 'ไม่พบบัญชีธนาคารตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _rows      = rows;
        _totals    = data['totals'] as Map<String, dynamic>?;
        _hasReport = true;
        _loading   = false;
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

  String _acctName(CmBankAccount a) =>
      _isEnglish && (a.accountNameEn ?? '').isNotEmpty ? a.accountNameEn! : a.accountNameTh;

  String _rowAcctName(Map<String, dynamic> r) {
    final nameEn = r['bank_account_name_en'] as String?;
    return _isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (r['bank_account_name'] as String? ?? '');
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ??
        (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine = '${isEnglish ? 'Date range' : 'ช่วงวันที่'} ${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}';

    final allLabel = isEnglish ? '(All)' : '(ทั้งหมด)';
    final conditions = <String>[];
    if (_accountFrom != null || _accountTo != null) {
      conditions.add(
          '${isEnglish ? 'Account code' : 'รหัสบัญชี'}: ${_accountFrom?.accountCode ?? allLabel}'
          ' – ${_accountTo?.accountCode ?? allLabel}');
    }
    final conditionLine = conditions.isEmpty ? '' : conditions.join(' | ');

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text(isEnglish ? 'Cash Flow Statement' : 'งบกระแสเงินสด',
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
      0: pw.FlexColumnWidth(5),   // บัญชีธนาคาร
      1: pw.FlexColumnWidth(2),   // สกุลเงิน
      2: pw.FlexColumnWidth(3),   // ยอดต้นงวด
      3: pw.FlexColumnWidth(3),   // รับเงิน
      4: pw.FlexColumnWidth(3),   // จ่ายเงิน
      5: pw.FlexColumnWidth(3),   // โอนเข้า
      6: pw.FlexColumnWidth(3),   // โอนออก
      7: pw.FlexColumnWidth(3),   // FX ปรับ
      8: pw.FlexColumnWidth(3),   // ยอดปลายงวด
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
        hCell(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Currency' : 'สกุลเงิน'),
        hCell(isEnglish ? 'Opening Balance' : 'ยอดต้นงวด'),
        hCell(isEnglish ? 'Receipts' : 'รับเงิน'),
        hCell(isEnglish ? 'Payments' : 'จ่ายเงิน'),
        hCell(isEnglish ? 'Transfer In' : 'โอนเข้า'),
        hCell(isEnglish ? 'Transfer Out' : 'โอนออก'),
        hCell(isEnglish ? 'FX Adjustment' : 'FX ปรับ'),
        hCell(isEnglish ? 'Closing Balance' : 'ยอดปลายงวด'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    for (final r in _rows) {
      final closing = _parseD(r['closing']);
      tableRows.add(pw.TableRow(children: [
        dCell('${r['bank_account_code'] ?? ''}  ${_rowAcctName(r)}', tNormal(9)),
        dCell(r['currency_code'] as String? ?? 'THB', tNormal(9), a: pw.TextAlign.center),
        amtCell(_parseD(r['opening']), tNormal(9)),
        amtCell(_parseD(r['receipts']), tNormal(9)),
        amtCell(_parseD(r['payments']), tNormal(9)),
        amtCell(_parseD(r['transfer_in']), tNormal(9)),
        amtCell(_parseD(r['transfer_out']), tNormal(9)),
        amtCell(_parseD(r['fx_adj']), tNormal(9)),
        amtCell(closing, tBold(9)),
      ]));
    }

    if (_totals != null) {
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: cTotal),
        children: [
          dCell(isEnglish ? 'Total' : 'รวมทั้งหมด', tBold(9)),
          dCell('', tBold(9)),
          amtCell(_parseD(_totals!['opening']), tBold(9)),
          amtCell(_parseD(_totals!['receipts']), tBold(9)),
          amtCell(_parseD(_totals!['payments']), tBold(9)),
          amtCell(_parseD(_totals!['transfer_in']), tBold(9)),
          amtCell(_parseD(_totals!['transfer_out']), tBold(9)),
          amtCell(_parseD(_totals!['fx_adj']), tBold(9)),
          amtCell(_parseD(_totals!['closing']), tBold(9)),
        ],
      ));
    }

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
    setState(() => _isExporting = true);
    try {
      final ex    = Excel.createExcel();
      const sheet = 'CashFlow';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, isEnglish ? 'Cash Flow Statement' : 'งบกระแสเงินสด', bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'Date range' : 'ช่วงวันที่'}: ${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Bank Account', 'Currency', 'Opening Balance', 'Receipts', 'Payments', 'Transfer In', 'Transfer Out', 'FX Adjustment', 'Closing Balance']
          : ['บัญชีธนาคาร', 'สกุลเงิน', 'ยอดต้นงวด', 'รับเงิน', 'จ่ายเงิน', 'โอนเข้า', 'โอนออก', 'FX ปรับ', 'ยอดปลายงวด'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      for (final r in _rows) {
        _xlCell(s, row, 0, '${r['bank_account_code'] ?? ''}  ${_rowAcctName(r)}');
        _xlCell(s, row, 1, r['currency_code'] ?? 'THB');
        _xlCell(s, row, 2, _parseD(r['opening']), align: HorizontalAlign.Right);
        _xlCell(s, row, 3, _parseD(r['receipts']), align: HorizontalAlign.Right);
        _xlCell(s, row, 4, _parseD(r['payments']), align: HorizontalAlign.Right);
        _xlCell(s, row, 5, _parseD(r['transfer_in']), align: HorizontalAlign.Right);
        _xlCell(s, row, 6, _parseD(r['transfer_out']), align: HorizontalAlign.Right);
        _xlCell(s, row, 7, _parseD(r['fx_adj']), align: HorizontalAlign.Right);
        _xlCell(s, row, 8, _parseD(r['closing']), align: HorizontalAlign.Right);
        row++;
      }

      if (_totals != null) {
        _xlCell(s, row, 0, isEnglish ? 'Total' : 'รวมทั้งหมด', bg: totBg, bold: true);
        _xlCell(s, row, 1, '', bg: totBg);
        _xlCell(s, row, 2, _parseD(_totals!['opening']),      bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 3, _parseD(_totals!['receipts']),     bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 4, _parseD(_totals!['payments']),     bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 5, _parseD(_totals!['transfer_in']),  bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 6, _parseD(_totals!['transfer_out']), bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 7, _parseD(_totals!['fx_adj']),       bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 8, _parseD(_totals!['closing']),      bg: totBg, bold: true, align: HorizontalAlign.Right);
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'Cash_Flow_Statement' : 'งบกระแสเงินสด';
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
                onPressed: (_rows.isEmpty || !canExport) ? null : _exportExcel,
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
        body: LayoutBuilder(builder: (_, constraints) {
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
        }),
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

                if (_hasReport && _totals != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _summaryItem(isEnglish ? 'Opening Balance' : 'ยอดต้นงวด',   _parseD(_totals!['opening']),  Colors.blueGrey.shade700),
                  _summaryItem(isEnglish ? 'Receipts' : 'รับเงิน',      _parseD(_totals!['receipts']),  Colors.green.shade700),
                  _summaryItem(isEnglish ? 'Payments' : 'จ่ายเงิน',    _parseD(_totals!['payments']),  Colors.red.shade700),
                  _summaryItem(isEnglish ? 'FX Adjustment' : 'FX ปรับ',     _parseD(_totals!['fx_adj']),
                      _parseD(_totals!['fx_adj']) >= 0 ? Colors.teal.shade700 : Colors.orange.shade700),
                  const Divider(),
                  _summaryItem(isEnglish ? 'Closing Balance' : 'ยอดปลายงวด', _parseD(_totals!['closing']),
                      _parseD(_totals!['closing']) >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
                      bold: true),
                ],
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

  Widget _summaryItem(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.black54,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        Text(_fmt.format(value), style: TextStyle(fontSize: 12, color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_hasReport) _buildReportHeader(isEnglish),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasReport
              ? Center(child: Text(isEnglish ? 'Select conditions and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน', style: const TextStyle(color: Colors.grey)))
              : _rows.isEmpty
                  ? Center(child: Text(isEnglish ? 'No bank accounts' : 'ไม่มีบัญชีธนาคาร', style: const TextStyle(color: Colors.grey)))
                  : _buildTable(isEnglish)),
    ]);
  }

  Widget _buildReportHeader(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kTheme.withOpacity(0.07),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEnglish ? 'Cash Flow Statement' : 'งบกระแสเงินสด (Cash Flow Statement)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text('${_dateFmt.format(_dateFrom)} — ${_dateFmt.format(_dateTo)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }

  Widget _buildTable(bool isEnglish) {
    const hStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 42,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: hStyle,
          columns: [
            DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
            DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
            DataColumn(label: Text(isEnglish ? 'Opening Balance' : 'ยอดต้นงวด'),      numeric: true),
            DataColumn(label: Text(isEnglish ? 'Receipts' : 'รับเงิน'),          numeric: true),
            DataColumn(label: Text(isEnglish ? 'Payments' : 'จ่ายเงิน'),         numeric: true),
            DataColumn(label: Text(isEnglish ? 'Transfer In' : 'โอนเข้า'),          numeric: true),
            DataColumn(label: Text(isEnglish ? 'Transfer Out' : 'โอนออก'),           numeric: true),
            DataColumn(label: Text(isEnglish ? 'FX Adjustment' : 'FX ปรับ'),          numeric: true),
            DataColumn(label: Text(isEnglish ? 'Closing Balance' : 'ยอดปลายงวด'),      numeric: true),
          ],
          rows: [
            ..._rows.map((r) {
              final closing = _parseD(r['closing']);
              final fxAdj   = _parseD(r['fx_adj']);
              return DataRow(cells: [
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${_rowAcctName(r)} (${r['bank_short_name'] ?? ''})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                DataCell(Text(r['currency_code'] ?? 'THB', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(_parseD(r['opening'])),      style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(_parseD(r['receipts'])),     style: TextStyle(fontSize: 12, color: Colors.green.shade700))),
                DataCell(Text(_fmt.format(_parseD(r['payments'])),     style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                DataCell(Text(_fmt.format(_parseD(r['transfer_in'])),  style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(_parseD(r['transfer_out'])), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(fxAdj), style: TextStyle(fontSize: 12,
                    color: fxAdj > 0 ? Colors.teal.shade700 : fxAdj < 0 ? Colors.orange.shade700 : Colors.black87))),
                DataCell(Text(_fmt.format(closing), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: closing >= 0 ? Colors.black87 : Colors.red.shade700))),
              ]);
            }),
            // Totals row
            if (_totals != null) ...[
              DataRow(
                color: WidgetStateProperty.all(Colors.blueGrey.shade50),
                cells: [
                  DataCell(Text(isEnglish ? 'Total' : 'รวมทั้งหมด', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  DataCell(Text(_fmt.format(_parseD(_totals!['opening'])),      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['receipts'])),     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['payments'])),     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['transfer_in'])),  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['transfer_out'])), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['fx_adj'])),       style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['closing'])),      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: _parseD(_totals!['closing']) >= 0 ? _kTheme : Colors.red.shade700))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Report tab (PDF) ─────────────────────────────────────────────────────
  Widget _buildReportTab(bool isEnglish, bool canPrint) {
    return Container(
      color: Colors.grey[200],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasReport || _rows.isEmpty
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
