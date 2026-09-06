// lib/cm/screens/cm_bank_gl_reconcile_report_screen.dart
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

class CmBankGlReconcileReportScreen extends StatefulWidget {
  const CmBankGlReconcileReportScreen({super.key});
  @override
  State<CmBankGlReconcileReportScreen> createState() => _State();
}

class _State extends State<CmBankGlReconcileReportScreen>
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

  DateTime _asOfDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  bool _loading = false;

  List<Map<String, dynamic>> _rows = [];
  String? _reportDate;
  int _totalMatched   = 0;
  int _totalUnmatched = 0;

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
    setState(() { _loading = true; _rows = []; });
    try {
      final d = formatLocalDate(_asOfDate);
      final data = await _rptSvc.getBankGlReconcile(
        accountCodeFrom: _accountFrom?.accountCode,
        accountCodeTo:   _accountTo?.accountCode,
        asOfDate: d,
      );
      if (!mounted) return;
      final rows = List<Map<String, dynamic>>.from(data['rows'] as List);
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No accounts with a GL Account configured' : 'ไม่พบบัญชีที่มี GL Account กำหนดไว้ตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _rows           = rows;
        _totalMatched   = data['total_matched'] as int? ?? 0;
        _totalUnmatched = data['total_unmatched'] as int? ?? 0;
        _reportDate     = d;
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

  String _rowAcctName(Map<String, dynamic> r) {
    final nameEn = r['bank_account_name_en'] as String?;
    return _isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (r['bank_account_name'] as String? ?? '');
  }

  String _rowGlName(Map<String, dynamic> r) {
    final nameEn = r['gl_account_name_en'] as String?;
    return _isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (r['gl_account_name'] as String? ?? '');
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
    final asOfLine = '${isEnglish ? 'As of' : 'ณ วันที่'} ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDate!))}';

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
            child: pw.Text(asOfLine, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
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
      1: pw.FlexColumnWidth(5),   // บัญชี GL
      2: pw.FlexColumnWidth(2.5), // สกุลเงิน
      3: pw.FlexColumnWidth(3.5), // ยอด CM
      4: pw.FlexColumnWidth(3.5), // ยอด GL
      5: pw.FlexColumnWidth(3.5), // ส่วนต่าง
      6: pw.FlexColumnWidth(3),   // สถานะ
    };

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cRed   = PdfColor(0.98, 0.90, 0.90);

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
        hCell(isEnglish ? 'GL Account' : 'บัญชี GL', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Currency' : 'สกุลเงิน'),
        hCell(isEnglish ? 'CM Balance' : 'ยอด CM'),
        hCell(isEnglish ? 'GL Balance' : 'ยอด GL'),
        hCell(isEnglish ? 'Difference' : 'ส่วนต่าง'),
        hCell(isEnglish ? 'Status' : 'สถานะ'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    for (final r in _rows) {
      final isMatched = r['is_matched'] == true;
      final diff = _parseD(r['difference']);
      tableRows.add(pw.TableRow(
        decoration: isMatched ? null : const pw.BoxDecoration(color: cRed),
        children: [
          dCell('${r['bank_account_code'] ?? ''}  ${_rowAcctName(r)}', tNormal(9)),
          dCell('${r['gl_account_code'] ?? ''}  ${_rowGlName(r)}', tNormal(9)),
          dCell(r['currency_code'] as String? ?? 'THB', tNormal(9), a: pw.TextAlign.center),
          amtCell(_parseD(r['cm_balance']), tNormal(9)),
          amtCell(_parseD(r['gl_balance']), tNormal(9)),
          amtCell(diff, diff == 0 ? tNormal(9) : tBold(9)),
          dCell(isMatched ? (isEnglish ? 'Matched' : 'ตรงกัน') : (isEnglish ? 'Unmatched' : 'ไม่ตรงกัน'),
              tBold(9), a: pw.TextAlign.center),
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
          pw.SizedBox(height: 8),
          pw.Text(
              isEnglish
                  ? 'Matched: $_totalMatched  |  Unmatched: $_totalUnmatched'
                  : 'ตรงกัน: $_totalMatched  |  ไม่ตรงกัน: $_totalUnmatched',
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
      const sheet = 'BankGlReconcile';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'As of' : 'ณ วันที่'}: ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDate!))}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Bank Account', 'GL Account', 'Currency', 'CM Balance', 'GL Balance', 'Difference', 'Status']
          : ['บัญชีธนาคาร', 'บัญชี GL', 'สกุลเงิน', 'ยอด CM', 'ยอด GL', 'ส่วนต่าง', 'สถานะ'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      for (final r in _rows) {
        final isMatched = r['is_matched'] == true;
        _xlCell(s, row, 0, '${r['bank_account_code'] ?? ''}  ${_rowAcctName(r)}');
        _xlCell(s, row, 1, '${r['gl_account_code'] ?? ''}  ${_rowGlName(r)}');
        _xlCell(s, row, 2, r['currency_code'] ?? 'THB');
        _xlCell(s, row, 3, _parseD(r['cm_balance']), align: HorizontalAlign.Right);
        _xlCell(s, row, 4, _parseD(r['gl_balance']), align: HorizontalAlign.Right);
        _xlCell(s, row, 5, _parseD(r['difference']), align: HorizontalAlign.Right);
        _xlCell(s, row, 6, isMatched ? (isEnglish ? 'Matched' : 'ตรงกัน') : (isEnglish ? 'Unmatched' : 'ไม่ตรงกัน'));
        row++;
      }

      _xlCell(s, row, 0, isEnglish ? 'Matched' : 'ตรงกัน', bg: totBg, bold: true);
      _xlCell(s, row, 1, _totalMatched, bg: totBg, bold: true, align: HorizontalAlign.Right);
      row++;
      _xlCell(s, row, 0, isEnglish ? 'Unmatched' : 'ไม่ตรงกัน', bg: totBg, bold: true);
      _xlCell(s, row, 1, _totalUnmatched, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'Bank_GL_Reconcile_Report' : 'รายงานกระทบยอด_CM_GL';
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
        : (v is int ? IntCellValue(v) : TextCellValue(v?.toString() ?? ''));
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
        : (perm?.menuName ?? (isEnglish ? 'CM vs GL Reconciliation Report' : 'รายงานกระทบยอด CM vs GL'));

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

                // ณ วันที่
                _buildDateField(
                    label: isEnglish ? 'As of Date' : 'ณ วันที่',
                    date: _asOfDate, onPick: (d) => setState(() => _asOfDate = d)),

                if (_reportDate != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _statCard(isEnglish ? 'Matched' : 'ตรงกัน',     _totalMatched,   Colors.green.shade700),
                  const SizedBox(height: 8),
                  _statCard(isEnglish ? 'Unmatched' : 'ไม่ตรงกัน', _totalUnmatched, Colors.red.shade700),
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

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color))),
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
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
        if (_reportDate != null) _buildReportHeader(isEnglish),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reportDate == null
                  ? Center(child: Text(isEnglish ? 'Select conditions and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน', style: const TextStyle(color: Colors.grey)))
                  : _rows.isEmpty
                      ? Center(child: Text(isEnglish ? 'No accounts with a GL Account configured' : 'ไม่มีบัญชีที่มี GL Account กำหนดไว้',
                          style: const TextStyle(color: Colors.grey)))
                      : _buildTable(isEnglish),
        ),
      ],
    );
  }

  Widget _buildReportHeader(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kTheme.withOpacity(0.08),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_reportTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text('${isEnglish ? 'As of' : 'ณ วันที่'} ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDate!))}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }

  Widget _buildTable(bool isEnglish) {
    const hStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    const cStyle = TextStyle(fontSize: 12);
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38, dataRowMinHeight: 36, dataRowMaxHeight: 44,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: hStyle,
          columns: [
            DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
            DataColumn(label: Text(isEnglish ? 'GL Account' : 'บัญชี GL')),
            DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
            DataColumn(label: Text(isEnglish ? 'CM Balance' : 'ยอด CM'),   numeric: true),
            DataColumn(label: Text(isEnglish ? 'GL Balance' : 'ยอด GL'),   numeric: true),
            DataColumn(label: Text(isEnglish ? 'Difference' : 'ส่วนต่าง'), numeric: true),
            DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
          ],
          rows: _rows.map((r) {
            final isMatched = r['is_matched'] == true;
            final diff = _parseD(r['difference']);
            return DataRow(
              color: WidgetStateProperty.resolveWith((_) =>
                  isMatched ? null : Colors.red.shade50),
              cells: [
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${_rowAcctName(r)} (${r['bank_short_name'] ?? ''})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r['gl_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(_rowGlName(r), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                DataCell(Text(r['currency_code'] ?? 'THB', style: cStyle)),
                DataCell(Text(_fmt.format(_parseD(r['cm_balance'])), style: cStyle)),
                DataCell(Text(_fmt.format(_parseD(r['gl_balance'])), style: cStyle)),
                DataCell(Text(_fmt.format(diff),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: diff == 0 ? Colors.black87 : Colors.red.shade700))),
                DataCell(isMatched
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(isEnglish ? 'Matched' : 'ตรงกัน', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 4),
                        Text(isEnglish ? 'Unmatched' : 'ไม่ตรงกัน', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ])),
              ],
            );
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
          : _reportDate == null || _rows.isEmpty
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
