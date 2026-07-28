import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_receipt_payment_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/cd_salesperson.dart';
import '../../cd/services/cd_salesperson_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_language_provider.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';
import '../../utils/file_download.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

class ArReceiptPaymentReportScreen extends StatefulWidget {
  const ArReceiptPaymentReportScreen({super.key});

  @override
  State<ArReceiptPaymentReportScreen> createState() =>
      _ArReceiptPaymentReportScreenState();
}

class _ArReceiptPaymentReportScreenState
    extends State<ArReceiptPaymentReportScreen> {
  final _reportService      = ArReceiptPaymentReportService();
  final _companyService     = CompanyService();
  final _authService        = AuthService();
  final _groupService       = ArCustomerGroupService();
  final _salespersonService = SalespersonService();

  bool   _isLoading         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;

  Company? _company;
  Map<String, String>? _headers;

  List<ArCustomerGroup> _customerGroups = [];
  List<Salesperson>     _salespersons   = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<int> _selectedGroupIds = [];
  int?    _selectedSalespersonId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';
  String  _sortBy    = 'customer'; // 'customer' | 'amount_desc' | 'amount_asc'
  bool    _showDetail  = false;
  bool    _isExporting = false;
  bool    _isEnglish   = false;

  List<Map<String, dynamic>> _reportData = [];

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
    ]);
    _company        = results[0] as Company?;
    _customerGroups = results[1] as List<ArCustomerGroup>;
    _salespersons   = (results[2] as List<Salesperson>)
        .where((s) => s.isActive).toList();
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getReceiptPaymentReport(
        dateFrom:          DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:            DateFormat('yyyy-MM-dd').format(_dateTo),
        customerGroupIds:  _selectedGroupIds,
        salespersonId:     _selectedSalespersonId,
        customerCodeFrom:  _customerCodeFrom,
        customerCodeTo:    _customerCodeTo,
        sortBy:            _sortBy,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'No data found for the selected date range' : 'ไม่พบข้อมูลในช่วงวันที่ที่เลือก')));
      }
      setState(() { _reportData = raw; _pdfKey++; });
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
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
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
        '${isEnglish ? 'Payment date' : 'วันที่ชำระ'} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
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
        (_customerCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      conditions.add(
          '${isEnglish ? 'Customer code' : 'รหัสลูกค้า'}: ${_customerCodeFrom?.isEmpty ?? true ? all : _customerCodeFrom!}'
          ' – ${_customerCodeTo?.isEmpty ?? true ? all : _customerCodeTo!}');
    }
    switch (_sortBy) {
      case 'amount_desc': conditions.add(isEnglish ? 'Sort by total amount, high to low' : 'เรียงยอดชำระรวมมากไปน้อย'); break;
      case 'amount_asc':  conditions.add(isEnglish ? 'Sort by total amount, low to high' : 'เรียงยอดชำระรวมน้อยไปมาก'); break;
      default:            conditions.add(isEnglish ? 'Sort by customer code' : 'เรียงรหัสลูกหนี้');
    }
    if (_showDetail) conditions.add(isEnglish ? 'Show details' : 'แสดงรายละเอียด');
    final conditionLine = conditions.join(' | ');
    final showDetail    = _showDetail;

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3,
            child: pw.Text(companyName,
                style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text(isEnglish ? 'Receipt/Payment Report' : 'รายงานการรับชำระ',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 15,
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
            child: pw.Text('* $conditionLine',
                style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 3,
            child: pw.Text(isEnglish ? 'Printed: $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 4),
    ]);

    // ─── Column widths (9 columns) ────────────────────────────────────────────
    // 0: รหัส-ชื่อลูกหนี้  1: ยอดชำระรวม  2: เงินสด  3: เช็ค
    // 4: บัตรเครดิต/เดบิต  5: เงินโอน  6: อินเตอร์เน็ตแบงกิ้ง
    // 7: ตั๋วแลกเงิน  8: อื่นๆ
    const colW = {
      0: pw.FlexColumnWidth(14),
      1: pw.FlexColumnWidth(6),
      2: pw.FlexColumnWidth(5),
      3: pw.FlexColumnWidth(5),
      4: pw.FlexColumnWidth(6),
      5: pw.FlexColumnWidth(5),
      6: pw.FlexColumnWidth(7),
      7: pw.FlexColumnWidth(5),
      8: pw.FlexColumnWidth(4),
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);
    pw.TextStyle tItalic(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);
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

    pw.Widget amtCell(double v, pw.TextStyle s) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 ? '' : fmt.format(v),
              style: s, textAlign: pw.TextAlign.right));

    pw.Widget amtCellDash(double v, pw.TextStyle s) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 ? '–' : fmt.format(v),
              style: s, textAlign: pw.TextAlign.right));

    // ─── Column header row ────────────────────────────────────────────────────
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Code – Customer Name' : 'รหัส – ชื่อลูกหนี้', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Total Payment' : 'ยอดชำระรวม'),
        hCell(isEnglish ? 'Cash' : 'เงินสด'),
        hCell(isEnglish ? 'Check' : 'เช็ค'),
        hCell(isEnglish ? 'Credit/Debit Card' : 'บัตรเครดิต/เดบิต'),
        hCell(isEnglish ? 'Transfer' : 'เงินโอน'),
        hCell(isEnglish ? 'Internet Banking' : 'อินเตอร์เน็ตแบงกิ้ง'),
        hCell(isEnglish ? 'Bill of Exchange' : 'ตั๋วแลกเงิน'),
        hCell(isEnglish ? 'Other' : 'อื่นๆ'),
      ],
    );

    // ─── Build rows per customer ───────────────────────────────────────────────
    final tableRows = <pw.TableRow>[headerRow];

    double grandTotal    = 0;
    double grandCash     = 0;
    double grandCheck    = 0;
    double grandCard     = 0;
    double grandTransfer = 0;
    double grandInternet = 0;
    double grandBoe      = 0;
    double grandOther    = 0;
    int    totalCustomers = 0;

    for (final cust in _reportData) {
      totalCustomers++;
      final code    = cust['customer_code'] as String? ?? '';
      final name    = cust['customer_name_th'] as String? ?? '';
      final total   = (cust['total_amount']    as num?)?.toDouble() ?? 0;
      final cash    = (cust['cash_amount']     as num?)?.toDouble() ?? 0;
      final check   = (cust['check_amount']    as num?)?.toDouble() ?? 0;
      final card    = (cust['card_amount']     as num?)?.toDouble() ?? 0;
      final trans   = (cust['transfer_amount'] as num?)?.toDouble() ?? 0;
      final inet    = (cust['internet_amount'] as num?)?.toDouble() ?? 0;
      final boe     = (cust['boe_amount']      as num?)?.toDouble() ?? 0;
      final other   = (cust['other_amount']    as num?)?.toDouble() ?? 0;

      grandTotal    += total;
      grandCash     += cash;
      grandCheck    += check;
      grandCard     += card;
      grandTransfer += trans;
      grandInternet += inet;
      grandBoe      += boe;
      grandOther    += other;

      // Customer summary row
      tableRows.add(pw.TableRow(
        decoration: showDetail
            ? const pw.BoxDecoration(color: cBlue)
            : null,
        children: [
          dCell('$code  $name',
              showDetail ? tBold(9) : tNormal(9)),
          amtCell(total,   showDetail ? tBold(9) : tNormal(9)),
          amtCell(cash,    showDetail ? tBold(9) : tNormal(9)),
          amtCell(check,   showDetail ? tBold(9) : tNormal(9)),
          amtCell(card,    showDetail ? tBold(9) : tNormal(9)),
          amtCell(trans,   showDetail ? tBold(9) : tNormal(9)),
          amtCell(inet,    showDetail ? tBold(9) : tNormal(9)),
          amtCell(boe,     showDetail ? tBold(9) : tNormal(9)),
          amtCell(other,   showDetail ? tBold(9) : tNormal(9)),
        ],
      ));

      if (!showDetail) continue;

      // Detail rows (receipt documents)
      final receipts = (cust['receipts'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final r in receipts) {
        final docNo   = r['doc_no'] as String? ?? '';
        final docDate = _fmtDate(r['doc_date'] as String?);
        final refNo   = r['ref_doc_no'] as String? ?? '';
        final label   = '$docNo  $docDate${refNo.isNotEmpty ? '  ${isEnglish ? 'Ref' : 'อ้างอิง'}: $refNo' : ''}';

        final rTotal   = (r['total_amount_lc'] as num?)?.toDouble() ?? 0;
        final rCash    = (r['cash_amount']     as num?)?.toDouble() ?? 0;
        final rCheck   = (r['check_amount']    as num?)?.toDouble() ?? 0;
        final rCard    = (r['card_amount']     as num?)?.toDouble() ?? 0;
        final rTrans   = (r['transfer_amount'] as num?)?.toDouble() ?? 0;
        final rInet    = (r['internet_amount'] as num?)?.toDouble() ?? 0;
        final rBoe     = (r['boe_amount']      as num?)?.toDouble() ?? 0;
        final rOther   = (r['other_amount']    as num?)?.toDouble() ?? 0;

        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: cGray),
          children: [
            dCell('     $label', tItalic(8.5)),
            amtCell(rTotal,   tItalic(8.5)),
            amtCell(rCash,    tItalic(8.5)),
            amtCell(rCheck,   tItalic(8.5)),
            amtCell(rCard,    tItalic(8.5)),
            amtCell(rTrans,   tItalic(8.5)),
            amtCell(rInet,    tItalic(8.5)),
            amtCell(rBoe,     tItalic(8.5)),
            amtCell(rOther,   tItalic(8.5)),
          ],
        ));
      }
    }

    // ─── Grand total row ──────────────────────────────────────────────────────
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
          color: PdfColor(0.75, 0.88, 0.83)),
      children: [
        dCell(isEnglish ? 'Total $totalCustomers customers' : 'รวม $totalCustomers ลูกหนี้', tBold(9)),
        amtCellDash(grandTotal,    tBold(9)),
        amtCellDash(grandCash,     tBold(9)),
        amtCellDash(grandCheck,    tBold(9)),
        amtCellDash(grandCard,     tBold(9)),
        amtCellDash(grandTransfer, tBold(9)),
        amtCellDash(grandInternet, tBold(9)),
        amtCellDash(grandBoe,      tBold(9)),
        amtCellDash(grandOther,    tBold(9)),
      ],
    ));

    // ─── Build page ───────────────────────────────────────────────────────────
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
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: (_reportData.isEmpty || !canExport) ? null : _exportExcel,
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

                                    // วันที่ชำระ ตั้งแต่ / ถึง
                                    _buildDateField(
                                        label: isEnglish ? 'Payment Date From' : 'วันที่ชำระ ตั้งแต่',
                                        date: _dateFrom,
                                        onPick: (d) =>
                                            setState(() => _dateFrom = d)),
                                    const SizedBox(height: 12),
                                    _buildDateField(
                                        label: isEnglish ? 'Payment Date To' : 'วันที่ชำระ ถึง',
                                        date: _dateTo,
                                        onPick: (d) =>
                                            setState(() => _dateTo = d)),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // กลุ่มลูกหนี้
                                    ArCustomerGroupMultiPicker(
                                      groups: _customerGroups,
                                      selectedIds: _selectedGroupIds,
                                      label: isEnglish ? 'Customer Groups' : 'กลุ่มลูกหนี้',
                                      onChanged: (v) => setState(
                                          () => _selectedGroupIds = v),
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
                                      onChanged: (v) => setState(
                                          () => _selectedSalespersonId = v),
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
                                            value: 'amount_desc',
                                            child: Text(isEnglish ? 'Total Amount, High to Low' : 'ยอดชำระรวม มากไปน้อย')),
                                        DropdownMenuItem(
                                            value: 'amount_asc',
                                            child: Text(isEnglish ? 'Total Amount, Low to High' : 'ยอดชำระรวม น้อยไปมาก')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _sortBy = v);
                                          _onSettingChanged();
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 8),

                                    // แสดงรายละเอียด
                                    Row(children: [
                                      Expanded(
                                        child: Text(isEnglish ? 'Show details' : 'แสดงรายละเอียด',
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                      Switch(
                                        value: _showDetail,
                                        activeColor: Colors.teal[800],
                                        onChanged: (v) {
                                          setState(() => _showDetail = v);
                                          _onSettingChanged();
                                        },
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
                          : _reportData.isEmpty
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
      builder: (_) => const _RecPayCustomerSearchDialog(),
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

  // ─── Excel Export ─────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'ReceiptPayment';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      final _tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, isEnglish ? 'Receipt/Payment Report' : 'รายงานการรับชำระ', bold: true);
      _xlCell(s, 2, 0, '${isEnglish ? 'Payment date' : 'วันที่ชำระ'}: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $_tsLabel');

      final hdrs = isEnglish
          ? ['Code – Customer Name', 'Total Payment', 'Cash', 'Check',
              'Credit/Debit Card', 'Transfer', 'Internet Banking', 'Bill of Exchange', 'Other']
          : ['รหัส – ชื่อลูกหนี้', 'ยอดชำระรวม', 'เงินสด', 'เช็ค',
          'บัตรเครดิต/เดบิต', 'เงินโอน', 'อินเตอร์เน็ตแบงกิ้ง', 'ตั๋วแลกเงิน', 'อื่นๆ'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      double grandTotal = 0, grandCash = 0, grandCheck = 0, grandCard = 0;
      double grandTransfer = 0, grandInternet = 0, grandBoe = 0, grandOther = 0;
      int totalCustomers = 0;

      for (final cust in _reportData) {
        totalCustomers++;
        final code  = cust['customer_code']    as String? ?? '';
        final name  = cust['customer_name_th'] as String? ?? '';
        final total = (cust['total_amount']    as num?)?.toDouble() ?? 0;
        final cash  = (cust['cash_amount']     as num?)?.toDouble() ?? 0;
        final check = (cust['check_amount']    as num?)?.toDouble() ?? 0;
        final card  = (cust['card_amount']     as num?)?.toDouble() ?? 0;
        final trans = (cust['transfer_amount'] as num?)?.toDouble() ?? 0;
        final inet  = (cust['internet_amount'] as num?)?.toDouble() ?? 0;
        final boe   = (cust['boe_amount']      as num?)?.toDouble() ?? 0;
        final other = (cust['other_amount']    as num?)?.toDouble() ?? 0;

        grandTotal    += total;  grandCash     += cash;
        grandCheck    += check;  grandCard     += card;
        grandTransfer += trans;  grandInternet += inet;
        grandBoe      += boe;    grandOther    += other;

        final bg = _showDetail ? ExcelColor.fromHexString('#BDD7EE') : null;
        _xlCell(s, row, 0, '$code  $name', bg: bg, bold: _showDetail);
        for (final pair in [total, cash, check, card, trans, inet, boe, other].asMap().entries) {
          _xlCell(s, row, pair.key + 1, pair.value, bg: bg,
              bold: _showDetail, align: HorizontalAlign.Right);
        }
        row++;

        if (_showDetail) {
          final receipts = (cust['receipts'] as List? ?? []).cast<Map<String, dynamic>>();
          for (final r in receipts) {
            final docNo  = r['doc_no']      as String? ?? '';
            final docDate = _fmtDate(r['doc_date'] as String?);
            final refNo  = r['ref_doc_no']  as String? ?? '';
            final label  = '   $docNo  $docDate${refNo.isNotEmpty ? '  ${isEnglish ? 'Ref' : 'อ้างอิง'}: $refNo' : ''}';
            final rTotal = (r['total_amount_lc'] as num?)?.toDouble() ?? 0;
            final rCash  = (r['cash_amount']     as num?)?.toDouble() ?? 0;
            final rCheck = (r['check_amount']    as num?)?.toDouble() ?? 0;
            final rCard  = (r['card_amount']     as num?)?.toDouble() ?? 0;
            final rTrans = (r['transfer_amount'] as num?)?.toDouble() ?? 0;
            final rInet  = (r['internet_amount'] as num?)?.toDouble() ?? 0;
            final rBoe   = (r['boe_amount']      as num?)?.toDouble() ?? 0;
            final rOther = (r['other_amount']    as num?)?.toDouble() ?? 0;
            _xlCell(s, row, 0, label, bg: detBg);
            for (final pair in [rTotal, rCash, rCheck, rCard, rTrans, rInet, rBoe, rOther].asMap().entries) {
              _xlCell(s, row, pair.key + 1, pair.value, bg: detBg, align: HorizontalAlign.Right);
            }
            row++;
          }
        }
      }

      _xlCell(s, row, 0, isEnglish ? 'Total $totalCustomers customers' : 'รวม $totalCustomers ลูกหนี้', bg: totBg, bold: true);
      for (final pair in [grandTotal, grandCash, grandCheck, grandCard,
          grandTransfer, grandInternet, grandBoe, grandOther].asMap().entries) {
        _xlCell(s, row, pair.key + 1, pair.value, bg: totBg, bold: true, align: HorizontalAlign.Right);
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'AR_Receipt_Payment_Report' : 'รายงานการรับชำระ';
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
}

// ─── Customer search dialog ────────────────────────────────────────────────────

class _RecPayCustomerSearchDialog extends StatefulWidget {
  const _RecPayCustomerSearchDialog();

  @override
  State<_RecPayCustomerSearchDialog> createState() =>
      _RecPayCustomerSearchDialogState();
}

class _RecPayCustomerSearchDialogState
    extends State<_RecPayCustomerSearchDialog> {
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
