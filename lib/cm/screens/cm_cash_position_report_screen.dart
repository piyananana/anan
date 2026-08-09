// lib/cm/screens/cm_cash_position_report_screen.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

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

class CmCashPositionReportScreen extends StatefulWidget {
  const CmCashPositionReportScreen({super.key});
  @override
  State<CmCashPositionReportScreen> createState() => _CmCashPositionReportScreenState();
}

class _CmCashPositionReportScreenState extends State<CmCashPositionReportScreen>
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

  CmBankAccount? _accountFrom;
  CmBankAccount? _accountTo;

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  bool _loading = false;

  List<Map<String, dynamic>> _rows = [];
  String? _reportDateFrom;
  String? _reportDateTo;

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

  Future<void> _generateReport() async {
    if (_dateFrom.isAfter(_dateTo)) {
      _showError(_isEnglish ? 'Please specify a valid date range' : 'กรุณาระบุช่วงวันที่ให้ถูกต้อง');
      return;
    }
    setState(() { _loading = true; _rows = []; });
    try {
      final df = formatLocalDate(_dateFrom);
      final dt = formatLocalDate(_dateTo);
      final data = await _rptSvc.getCashPosition(
        accountCodeFrom: _accountFrom?.accountCode,
        accountCodeTo:   _accountTo?.accountCode,
        dateFrom: df, dateTo: dt,
      );
      if (!mounted) return;
      final rows = List<Map<String, dynamic>>.from(data['rows'] as List);
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No data found for the selected conditions' : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _rows = rows;
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

  String _acctName(Map<String, dynamic> r) {
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
    final dateRangeLine =
        '${isEnglish ? 'Date range' : 'ช่วงวันที่'} ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))}'
        ' – ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}';

    final conditions = <String>[];
    final allLabel = isEnglish ? '(All)' : '(ทั้งหมด)';
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
            child: pw.Text(isEnglish ? 'Cash Position Report' : 'รายงานสถานะเงินสด',
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
      0: pw.FlexColumnWidth(4),   // บัญชีธนาคาร
      1: pw.FlexColumnWidth(6),   // ชื่อบัญชี
      2: pw.FlexColumnWidth(3),   // ธนาคาร
      3: pw.FlexColumnWidth(2),   // สกุลเงิน
      4: pw.FlexColumnWidth(3.5), // ยอดเปิด
      5: pw.FlexColumnWidth(3.5), // รับเข้า
      6: pw.FlexColumnWidth(3.5), // จ่ายออก
      7: pw.FlexColumnWidth(3.5), // ยอดปิด
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
        hCell(isEnglish ? 'Account Name' : 'ชื่อบัญชี', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Bank' : 'ธนาคาร'),
        hCell(isEnglish ? 'Currency' : 'สกุลเงิน'),
        hCell(isEnglish ? 'Opening Balance' : 'ยอดเปิด'),
        hCell(isEnglish ? 'Receipts' : 'รับเข้า'),
        hCell(isEnglish ? 'Payments' : 'จ่ายออก'),
        hCell(isEnglish ? 'Closing Balance' : 'ยอดปิด'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];
    double totOpen = 0, totReceipt = 0, totPayment = 0, totClose = 0;

    for (final r in _rows) {
      final opening = _parseD(r['opening_balance']);
      final receipt = _parseD(r['period_receipts']);
      final payment = _parseD(r['period_payments']);
      final closing = _parseD(r['closing_balance']);
      totOpen    += opening;
      totReceipt += receipt;
      totPayment += payment;
      totClose   += closing;

      tableRows.add(pw.TableRow(children: [
        dCell(r['bank_account_code'] as String? ?? '', tBold(9)),
        dCell(_acctName(r), tNormal(9)),
        dCell(r['bank_short_name'] as String? ?? '', tNormal(9)),
        dCell(r['currency_code'] as String? ?? 'THB', tNormal(9)),
        amtCell(opening, tNormal(9)),
        amtCell(receipt, tNormal(9)),
        amtCell(payment, tNormal(9)),
        amtCell(closing, tBold(9)),
      ]));
    }

    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: cTotal),
      children: [
        dCell(isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        amtCell(totOpen, tBold(9)),
        amtCell(totReceipt, tBold(9)),
        amtCell(totPayment, tBold(9)),
        amtCell(totClose, tBold(9)),
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
    setState(() => _isExporting = true);
    try {
      final ex    = Excel.createExcel();
      const sheet = 'CashPosition';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, isEnglish ? 'Cash Position Report' : 'รายงานสถานะเงินสด', bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'Date range' : 'ช่วงวันที่'}: ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Bank Account', 'Account Name', 'Bank', 'Currency', 'Opening Balance', 'Receipts', 'Payments', 'Closing Balance']
          : ['บัญชีธนาคาร', 'ชื่อบัญชี', 'ธนาคาร', 'สกุลเงิน', 'ยอดเปิด', 'รับเข้า', 'จ่ายออก', 'ยอดปิด'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      double totOpen = 0, totReceipt = 0, totPayment = 0, totClose = 0;
      for (final r in _rows) {
        final opening = _parseD(r['opening_balance']);
        final receipt = _parseD(r['period_receipts']);
        final payment = _parseD(r['period_payments']);
        final closing = _parseD(r['closing_balance']);
        totOpen += opening; totReceipt += receipt; totPayment += payment; totClose += closing;

        _xlCell(s, row, 0, r['bank_account_code'] ?? '');
        _xlCell(s, row, 1, _acctName(r));
        _xlCell(s, row, 2, r['bank_short_name'] ?? '');
        _xlCell(s, row, 3, r['currency_code'] ?? 'THB');
        _xlCell(s, row, 4, opening, align: HorizontalAlign.Right);
        _xlCell(s, row, 5, receipt, align: HorizontalAlign.Right);
        _xlCell(s, row, 6, payment, align: HorizontalAlign.Right);
        _xlCell(s, row, 7, closing, align: HorizontalAlign.Right);
        row++;
      }

      _xlCell(s, row, 0, isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', bg: totBg, bold: true);
      _xlCell(s, row, 1, '', bg: totBg);
      _xlCell(s, row, 2, '', bg: totBg);
      _xlCell(s, row, 3, '', bg: totBg);
      _xlCell(s, row, 4, totOpen,    bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 5, totReceipt, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 6, totPayment, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 7, totClose,   bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'Cash_Position_Report' : 'รายงานสถานะเงินสด';
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
                  icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
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
                    maxWidth: _filterPanelWidth,
                    minWidth: _filterPanelWidth,
                    alignment: Alignment.topLeft,
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
              onPressed: _loading ? null : _generateReport,
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
    final name = hasValue
        ? (isEnglish && (value.accountNameEn ?? '').isNotEmpty ? value.accountNameEn! : value.accountNameTh)
        : '';
    final displayText = hasValue ? '${value.accountCode}  $name' : '';
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
              : _rows.isEmpty && _reportDateFrom != null
                  ? Center(child: Text(isEnglish ? 'No data' : 'ไม่มีข้อมูล', style: const TextStyle(color: Colors.grey)))
                  : _reportDateFrom == null
                      ? Center(child: Text(isEnglish ? 'Select conditions and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน', style: const TextStyle(color: Colors.grey)))
                      : _buildTable(isEnglish),
        ),
      ],
    );
  }

  Widget _buildReportHeader(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kTheme.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEnglish ? 'Cash Position Report' : 'รายงานสถานะเงินสด', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
    double totOpen = 0, totReceipt = 0, totPayment = 0, totClose = 0;
    for (final r in _rows) {
      totOpen    += _parseD(r['opening_balance']);
      totReceipt += _parseD(r['period_receipts']);
      totPayment += _parseD(r['period_payments']);
      totClose   += _parseD(r['closing_balance']);
    }

    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87);
    const cellStyle   = TextStyle(fontSize: 12);

    return SingleChildScrollView(
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 44,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        headingTextStyle: headerStyle,
        columns: [
          DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
          DataColumn(label: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี')),
          DataColumn(label: Text(isEnglish ? 'Bank' : 'ธนาคาร')),
          DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
          DataColumn(label: Text(isEnglish ? 'Opening Balance' : 'ยอดเปิด'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Receipts' : 'รับเข้า'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Payments' : 'จ่ายออก'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Closing Balance' : 'ยอดปิด'), numeric: true),
        ],
        rows: [
          ..._rows.map((r) {
            final closing = _parseD(r['closing_balance']);
            return DataRow(cells: [
              DataCell(Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(Text(_acctName(r), style: const TextStyle(fontSize: 12))),
              DataCell(Text(r['bank_short_name'] ?? '', style: cellStyle)),
              DataCell(Text(r['currency_code'] ?? 'THB', style: cellStyle)),
              DataCell(Text(_fmt.format(_parseD(r['opening_balance'])), style: cellStyle)),
              DataCell(Text(_fmt.format(_parseD(r['period_receipts'])), style: cellStyle.copyWith(color: Colors.green.shade700))),
              DataCell(Text(_fmt.format(_parseD(r['period_payments'])), style: cellStyle.copyWith(color: Colors.red.shade700))),
              DataCell(Text(_fmt.format(closing),
                  style: cellStyle.copyWith(fontWeight: FontWeight.bold, color: closing >= 0 ? Colors.black87 : Colors.red.shade700))),
            ]);
          }),
          DataRow(
            color: WidgetStateProperty.all(Colors.blueGrey.shade50),
            cells: [
              DataCell(Text(isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(_fmt.format(totOpen), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Text(_fmt.format(totReceipt), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade700))),
              DataCell(Text(_fmt.format(totPayment), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade700))),
              DataCell(Text(_fmt.format(totClose), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: totClose >= 0 ? Colors.black87 : Colors.red.shade700))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Report tab (PDF) ─────────────────────────────────────────────────────
  Widget _buildReportTab(bool isEnglish, bool canPrint) {
    return Container(
      color: Colors.grey[200],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
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
