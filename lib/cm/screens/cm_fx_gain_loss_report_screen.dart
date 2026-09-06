// lib/cm/screens/cm_fx_gain_loss_report_screen.dart
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
final _rateFmt = NumberFormat('#,##0.000000', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmFxGainLossReportScreen extends StatefulWidget {
  const CmFxGainLossReportScreen({super.key});
  @override
  State<CmFxGainLossReportScreen> createState() => _State();
}

class _State extends State<CmFxGainLossReportScreen> with AutomaticKeepAliveClientMixin {
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

  DateTime _dateFrom = DateTime(DateTime.now().year, 1, 1);
  DateTime _dateTo   = DateTime.now();
  bool _loading = false;

  List<Map<String, dynamic>> _rows = [];
  double _totalGain    = 0;
  double _totalLoss    = 0;
  double _netGainLoss  = 0;
  bool _hasReport = false;

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
    setState(() { _loading = true; _rows = []; _hasReport = false; });
    try {
      final data = await _rptSvc.getFxGainLossReport(
        accountCodeFrom: _accountFrom?.accountCode,
        accountCodeTo:   _accountTo?.accountCode,
        dateFrom: formatLocalDate(_dateFrom),
        dateTo:   formatLocalDate(_dateTo),
      );
      if (!mounted) return;
      final rows = List<Map<String, dynamic>>.from(data['rows'] as List);
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No FX Revaluation data in the selected conditions' : 'ไม่มีข้อมูล FX Revaluation ตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _rows        = rows;
        _totalGain   = _parseD(data['total_gain']);
        _totalLoss   = _parseD(data['total_loss']);
        _netGainLoss = _parseD(data['net_gain_loss']);
        _hasReport   = true;
        _loading     = false;
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

  String _rowAcctName(Map<String, dynamic> r) {
    final nameEn = r['bank_account_name_en'] as String?;
    return _isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (r['bank_account_name'] as String? ?? '');
  }

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
      0: pw.FlexColumnWidth(2.5), // วันที่ Reval
      1: pw.FlexColumnWidth(2.5), // เลขที่
      2: pw.FlexColumnWidth(5),   // บัญชีธนาคาร
      3: pw.FlexColumnWidth(2),   // สกุลเงิน
      4: pw.FlexColumnWidth(3),   // ยอด FC
      5: pw.FlexColumnWidth(3),   // ยอด LC (เดิม)
      6: pw.FlexColumnWidth(3),   // อัตราใหม่
      7: pw.FlexColumnWidth(3),   // ยอด LC (ใหม่)
      8: pw.FlexColumnWidth(3),   // FX Gain/Loss
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

    pw.Widget amtCell(double v, pw.TextStyle s, {String? formatted}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(formatted ?? _fmt.format(v), style: s, textAlign: pw.TextAlign.right));

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Reval Date' : 'วันที่ Reval'),
        hCell(isEnglish ? 'Doc No.' : 'เลขที่'),
        hCell(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Currency' : 'สกุลเงิน'),
        hCell(isEnglish ? 'FC Balance' : 'ยอด FC'),
        hCell(isEnglish ? 'LC Balance (Old)' : 'ยอด LC (เดิม)'),
        hCell(isEnglish ? 'New Rate' : 'อัตราใหม่'),
        hCell(isEnglish ? 'LC Balance (New)' : 'ยอด LC (ใหม่)'),
        hCell('FX Gain/Loss'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    for (final r in _rows) {
      final fxGL = _parseD(r['fx_gain_loss']);
      final dt = parseLocalDateNullable(r['revaluation_date']);
      tableRows.add(pw.TableRow(children: [
        dCell(dt != null ? _dateFmt.format(dt) : '', tNormal(9), a: pw.TextAlign.center),
        dCell(r['gl_doc_no'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
        dCell('${r['bank_account_code'] ?? ''}  ${_rowAcctName(r)}', tNormal(9)),
        dCell(r['currency_code'] as String? ?? '', tNormal(9), a: pw.TextAlign.center),
        amtCell(_parseD(r['balance_fc']), tNormal(9)),
        amtCell(_parseD(r['balance_lc_book']), tNormal(9)),
        amtCell(_parseD(r['new_rate']), tNormal(9), formatted: _rateFmt.format(_parseD(r['new_rate']))),
        amtCell(_parseD(r['balance_lc_new']), tNormal(9)),
        amtCell(fxGL, tBold(9)),
      ]));
    }

    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: cTotal),
      children: [
        dCell(isEnglish ? 'Total' : 'รวม', tBold(9)),
        dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)), dCell('', tBold(9)),
        dCell(isEnglish ? 'Net' : 'สุทธิ', tBold(9), a: pw.TextAlign.right),
        amtCell(_netGainLoss, tBold(9)),
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
          pw.SizedBox(height: 8),
          pw.Text(
              isEnglish
                  ? 'Gain ${_fmt.format(_totalGain)}  |  Loss ${_fmt.format(_totalLoss)}  |  Net ${_fmt.format(_netGainLoss)}'
                  : 'กำไร ${_fmt.format(_totalGain)}  |  ขาดทุน ${_fmt.format(_totalLoss)}  |  สุทธิ ${_fmt.format(_netGainLoss)}',
              style: tBold(10)),
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
      const sheet = 'FxGainLoss';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'Date range' : 'ช่วงวันที่'}: ${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Reval Date', 'Doc No.', 'Bank Account', 'Currency', 'FC Balance', 'LC Balance (Old)', 'New Rate', 'LC Balance (New)', 'FX Gain/Loss']
          : ['วันที่ Reval', 'เลขที่', 'บัญชีธนาคาร', 'สกุลเงิน', 'ยอด FC', 'ยอด LC (เดิม)', 'อัตราใหม่', 'ยอด LC (ใหม่)', 'FX Gain/Loss'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      for (final r in _rows) {
        final dt = parseLocalDateNullable(r['revaluation_date']);
        _xlCell(s, row, 0, dt != null ? _dateFmt.format(dt) : '');
        _xlCell(s, row, 1, r['gl_doc_no'] ?? '');
        _xlCell(s, row, 2, '${r['bank_account_code'] ?? ''}  ${_rowAcctName(r)}');
        _xlCell(s, row, 3, r['currency_code'] ?? '');
        _xlCell(s, row, 4, _parseD(r['balance_fc']), align: HorizontalAlign.Right);
        _xlCell(s, row, 5, _parseD(r['balance_lc_book']), align: HorizontalAlign.Right);
        _xlCell(s, row, 6, _parseD(r['new_rate']), align: HorizontalAlign.Right);
        _xlCell(s, row, 7, _parseD(r['balance_lc_new']), align: HorizontalAlign.Right);
        _xlCell(s, row, 8, _parseD(r['fx_gain_loss']), align: HorizontalAlign.Right);
        row++;
      }

      _xlCell(s, row, 0, isEnglish ? 'Gain' : 'กำไร', bg: totBg, bold: true);
      _xlCell(s, row, 8, _totalGain, bg: totBg, bold: true, align: HorizontalAlign.Right);
      row++;
      _xlCell(s, row, 0, isEnglish ? 'Loss' : 'ขาดทุน', bg: totBg, bold: true);
      _xlCell(s, row, 8, _totalLoss, bg: totBg, bold: true, align: HorizontalAlign.Right);
      row++;
      _xlCell(s, row, 0, isEnglish ? 'Net' : 'สุทธิ', bg: totBg, bold: true);
      _xlCell(s, row, 8, _netGainLoss, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'FX_Gain_Loss_Report' : 'รายงาน_FX_Gain_Loss';
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
        : (perm?.menuName ?? (isEnglish ? 'FX Gain/Loss Report' : 'รายงาน FX Gain/Loss'));

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

                if (_hasReport) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _statCard('FX Gain', _totalGain, Colors.green.shade700),
                  const SizedBox(height: 8),
                  _statCard('FX Loss', _totalLoss, Colors.red.shade700),
                  const SizedBox(height: 8),
                  _statCard(isEnglish ? 'Net' : 'สุทธิ', _netGainLoss,
                      _netGainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700),
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

  Widget _statCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(_fmt.format(value),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
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
                  ? Center(child: Text(isEnglish ? 'No FX Revaluation data in the selected range' : 'ไม่มีข้อมูล FX Revaluation ในช่วงที่เลือก',
                      style: const TextStyle(color: Colors.grey)))
                  : _buildTable(isEnglish)),
    ]);
  }

  Widget _buildReportHeader(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kTheme.withOpacity(0.07),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEnglish ? 'FX Gain/Loss Report from Revaluation' : 'รายงาน FX Gain/Loss จากการ Revaluation',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text('${_dateFmt.format(_dateFrom)} — ${_dateFmt.format(_dateTo)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }

  Widget _buildTable(bool isEnglish) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 42,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          columns: [
            DataColumn(label: Text(isEnglish ? 'Reval Date' : 'วันที่ Reval')),
            DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่')),
            DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
            DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
            DataColumn(label: Text(isEnglish ? 'FC Balance' : 'ยอด FC'),       numeric: true),
            DataColumn(label: Text(isEnglish ? 'LC Balance (Old)' : 'ยอด LC (เดิม)'), numeric: true),
            DataColumn(label: Text(isEnglish ? 'New Rate' : 'อัตราใหม่'),    numeric: true),
            DataColumn(label: Text(isEnglish ? 'LC Balance (New)' : 'ยอด LC (ใหม่)'), numeric: true),
            DataColumn(label: Text('FX Gain/Loss'),  numeric: true),
          ],
          rows: _rows.map((r) {
            final fxGL = _parseD(r['fx_gain_loss']);
            Color glColor;
            if (fxGL > 0) {
              glColor = Colors.green.shade700;
            } else if (fxGL < 0) {
              glColor = Colors.red.shade700;
            } else {
              glColor = Colors.black87;
            }
            final dt = parseLocalDateNullable(r['revaluation_date']);
            return DataRow(cells: [
              DataCell(Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 12))),
              DataCell(Text(r['gl_doc_no'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${_rowAcctName(r)} (${r['bank_short_name'] ?? ''})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              DataCell(Text(r['currency_code'] ?? '', style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(_parseD(r['balance_fc'])),      style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(_parseD(r['balance_lc_book'])), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_rateFmt.format(_parseD(r['new_rate'])), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(_parseD(r['balance_lc_new'])),  style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(fxGL), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glColor))),
            ]);
          }).toList(),
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
