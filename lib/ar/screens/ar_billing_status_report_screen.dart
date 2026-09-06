import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import 'package:provider/provider.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_billing_status_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

class ArBillingStatusReportScreen extends StatefulWidget {
  const ArBillingStatusReportScreen({super.key});

  @override
  State<ArBillingStatusReportScreen> createState() =>
      _ArBillingStatusReportScreenState();
}

class _ArBillingStatusReportScreenState
    extends State<ArBillingStatusReportScreen> {
  final _reportService  = ArBillingStatusReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();
  final _groupService   = ArCustomerGroupService();
  final _branchService  = BranchService();

  bool   _isLoading         = false;
  bool   _isEnglish         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;

  Company?             _company;
  Map<String, String>? _headers;
  // ชื่อรายงาน — ใช้ชื่อเมนู (จาก AppBar/MenuTitle) แทนข้อความ hardcode เพื่อให้ตรงกับที่ผู้ใช้เห็นบนแท็บเสมอ
  String _reportTitle = '';

  List<Branch>          _branches       = [];
  List<ArCustomerGroup> _customerGroups = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  int?    _selectedBranchId;
  List<int> _selectedGroupIds = [];
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel    = '';
  String  _toLabel      = '';
  String  _statusFilter = 'all';     // 'all' | 'pending' | 'paid' | 'void'
  String  _sortBy       = 'doc_type'; // 'doc_type' | 'customer'
  bool    _showDetail   = false;

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
      _branchService.fetchRows(),
      _groupService.fetchActiveRows(),
    ]);
    _company        = results[0] as Company?;
    _branches       = (results[1] as List<Branch>)
        .where((b) => b.isActive).toList();
    _customerGroups = results[2] as List<ArCustomerGroup>;
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getBillingStatusReport(
        dateFrom:         DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:           DateFormat('yyyy-MM-dd').format(_dateTo),
        branchId:         _selectedBranchId,
        customerGroupIds: _selectedGroupIds,
        customerCodeFrom: _customerCodeFrom,
        customerCodeTo:   _customerCodeTo,
        statusFilter:     _statusFilter,
        sortBy:           _sortBy,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No data found for the selected date range'
                : 'ไม่พบข้อมูลในช่วงวันที่ที่เลือก')));
      }
      setState(() { _reportData = raw; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
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
    final isEnglish       = _isEnglish;
    final reportTitle     = _reportTitle;
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.displayName(isEnglish) ??
        (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine =
        '${isEnglish ? 'Billing date' : 'วันที่วางบิล'} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere((b) => b.id == _selectedBranchId,
          orElse: () => _branches.first);
      final bName = isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai;
      conditions.add('${isEnglish ? 'Branch' : 'สาขา'}: ${b.branchCode} $bName');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _customerGroups.firstWhere((g) => g.id == id,
            orElse: () => _customerGroups.first);
        final gName = isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai;
        return '${g.groupCode} $gName';
      }).join(', ');
      conditions.add('${isEnglish ? 'Group' : 'กลุ่ม'}: $names');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty ||
        (_customerCodeTo ?? '').isNotEmpty) {
      final allLabel = isEnglish ? '(All)' : '(ทั้งหมด)';
      conditions.add(
          '${isEnglish ? 'Customer code' : 'รหัสลูกค้า'}: ${_customerCodeFrom?.isEmpty ?? true ? allLabel : _customerCodeFrom!}'
          ' – ${_customerCodeTo?.isEmpty ?? true ? allLabel : _customerCodeTo!}');
    }
    conditions.add('${isEnglish ? 'Status' : 'สถานะ'}: ${(isEnglish ? const {
      'all': 'All',
      'pending': 'Pending',
      'paid': 'Paid',
      'void': 'Void',
    } : const {
      'all': 'ทั้งหมด',
      'pending': 'รอชำระ',
      'paid': 'ชำระแล้ว',
      'void': 'ยกเลิก',
    })[_statusFilter] ?? (isEnglish ? 'All' : 'ทั้งหมด')}');
    conditions.add(_sortBy == 'customer'
        ? (isEnglish ? 'Sorted by customer code' : 'เรียงตามรหัสลูกค้า')
        : (isEnglish ? 'Sorted by doc type + no.' : 'เรียงตามประเภท+เลขที่'));
    if (_showDetail) conditions.add(isEnglish ? 'Show details' : 'แสดงรายละเอียด');

    final conditionLine = conditions.join(' | ');
    final showDetail    = _showDetail;

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName,
            style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6, child: pw.Text(
            reportTitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 15,
                fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.Text(dateRangeLine,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.Text('* $conditionLine',
            style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Printed: $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 4),
    ]);

    // ─── Column widths (7 columns) ────────────────────────────────────────────
    const colW = {
      0: pw.FlexColumnWidth(9),   // ประเภทเอกสาร (doc_code)
      1: pw.FlexColumnWidth(13),  // เลขที่ใบวางบิล
      2: pw.FlexColumnWidth(9),   // วันที่เอกสาร
      3: pw.FlexColumnWidth(30),  // รหัส-ชื่อลูกค้า
      4: pw.FlexColumnWidth(10),  // วางบิล(รอชำระ)
      5: pw.FlexColumnWidth(10),  // ชำระแล้ว
      6: pw.FlexColumnWidth(8),   // สถานะ
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font,      fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold,  fontSize: fs);
    pw.TextStyle tItalic(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);
    const cGray   = PdfColor(0.96, 0.96, 0.96);
    const cPink   = PdfColor(1.0,  0.92, 0.92);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t, style: tBold(8.5), textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s,
            {pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t, style: s, textAlign: a));

    pw.Widget amtCell(double v, pw.TextStyle s, {bool dash = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 && dash ? '–' : (v == 0 ? '' : fmt.format(v)),
              style: s, textAlign: pw.TextAlign.right));

    // ─── Column header row ────────────────────────────────────────────────────
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Doc\nType' : 'ประเภท\nเอกสาร', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Billing Doc No.' : 'เลขที่ใบวางบิล'),
        hCell(isEnglish ? 'Doc\nDate' : 'วันที่\nเอกสาร'),
        hCell(isEnglish ? 'Code – Customer Name' : 'รหัส – ชื่อลูกค้า', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Billed\n(Pending)' : 'วางบิล\n(รอชำระ)'),
        hCell(isEnglish ? 'Paid' : 'ชำระแล้ว'),
        hCell(isEnglish ? 'Status' : 'สถานะ'),
      ],
    );

    // ─── Build rows ───────────────────────────────────────────────────────────
    final tableRows = <pw.TableRow>[headerRow];

    double grandPending = 0;
    double grandPaid    = 0;
    int    totalBcs     = 0;

    for (final bc in _reportData) {
      totalBcs++;
      final docCode  = bc['doc_code']           as String? ?? '';
      final bcDocNo  = bc['bc_doc_no']           as String? ?? '';
      final bcDate   = _fmtDate(bc['bc_doc_date'] as String?);
      final custCode = bc['customer_code']       as String? ?? '';
      final custName = bc['customer_name_th']    as String? ?? '';
      final total    = (bc['total_amount_lc']    as num?)?.toDouble() ?? 0;
      final balance  = (bc['balance_amount_lc']  as num?)?.toDouble() ?? 0;
      final status   = bc['status'] as String? ?? '';
      final isVoid   = status == 'Void';

      final pending  = isVoid ? 0.0 : balance;
      final paidAmt  = isVoid ? 0.0 : (total - balance);

      final statusLabel = isVoid
          ? (isEnglish ? 'Void' : 'ยกเลิก')
          : (balance > 0
              ? (isEnglish ? 'Pending' : 'รอชำระ')
              : (isEnglish ? 'Paid' : 'ชำระแล้ว'));

      grandPending += pending;
      grandPaid    += paidAmt;

      final PdfColor? rowColor = isVoid ? cPink : null;

      tableRows.add(pw.TableRow(
        decoration: rowColor != null
            ? pw.BoxDecoration(color: rowColor)
            : null,
        children: [
          dCell(docCode,                tNormal(9)),
          dCell(bcDocNo,                tNormal(9), a: pw.TextAlign.center),
          dCell(bcDate,                 tNormal(9), a: pw.TextAlign.center),
          dCell('$custCode  $custName', tNormal(9)),
          amtCell(pending,              tNormal(9)),
          amtCell(paidAmt,              tNormal(9)),
          dCell(statusLabel,            tNormal(9), a: pw.TextAlign.center),
        ],
      ));

      if (!showDetail) continue;

      final invoices = (bc['invoices'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final inv in invoices) {
        final invDocName  = inv['doc_name_thai'] as String? ?? '';
        final invDocNo    = inv['doc_no']         as String? ?? '';
        final invDate     = _fmtDate(inv['doc_date'] as String?);
        final invRef      = inv['ref_doc_no']     as String? ?? '';
        final appliedAmt  = (inv['applied_amount'] as num?)?.toDouble() ?? 0;
        final invBalance  = (inv['inv_balance']    as num?)?.toDouble() ?? 0;

        final label = '     >> $invDocName  $invDocNo  $invDate'
            '${invRef.isNotEmpty ? '  $invRef' : ''}';

        final invPending = invBalance > 0 ? appliedAmt : 0.0;
        final invPaid    = invBalance <= 0 ? appliedAmt : 0.0;

        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: cGray),
          children: [
            dCell('',    tItalic(8.5)),
            dCell('',    tItalic(8.5)),
            dCell('',    tItalic(8.5)),
            dCell(label, tItalic(8.5)),
            amtCell(invPending, tItalic(8.5)),
            amtCell(invPaid,    tItalic(8.5)),
            dCell('',    tItalic(8.5)),
          ],
        ));
      }
    }

    // ─── Grand total ──────────────────────────────────────────────────────────
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
          color: PdfColor(0.75, 0.88, 0.83)),
      children: [
        dCell(isEnglish ? 'Total $totalBcs items' : 'รวม $totalBcs รายการ', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        dCell('', tBold(9)),
        amtCell(grandPending, tBold(9), dash: true),
        amtCell(grandPaid,    tBold(9), dash: true),
        dCell('', tBold(9)),
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
    final l = AppL10n(isEnglish);
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Billing Status Report' : 'รายงานสถานะใบวางบิล'));
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
              tooltip: isEnglish ? 'Export Excel' : 'ส่งออก Excel',
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
                                padding: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(isEnglish ? 'Report Filter' : 'เงื่อนไขรายงาน',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 16),

                                    _buildDateField(
                                        label: isEnglish ? 'Billing date from' : 'วันที่วางบิล ตั้งแต่',
                                        date: _dateFrom,
                                        onPick: (d) =>
                                            setState(() => _dateFrom = d)),
                                    const SizedBox(height: 12),
                                    _buildDateField(
                                        label: isEnglish ? 'Billing date to' : 'วันที่วางบิล ถึง',
                                        date: _dateTo,
                                        onPick: (d) =>
                                            setState(() => _dateTo = d)),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // สาขา
                                    DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      value: _selectedBranchId,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Branch' : 'สาขา',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text(isEnglish ? '— All branches —' : '— ทุกสาขา —')),
                                        ..._branches.map((b) =>
                                            DropdownMenuItem<int?>(
                                              value: b.id,
                                              child: Text(
                                                  '${b.branchCode}  ${isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai}',
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _selectedBranchId = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // กลุ่มลูกหนี้
                                    ArCustomerGroupMultiPicker(
                                      groups: _customerGroups,
                                      selectedIds: _selectedGroupIds,
                                      label: isEnglish ? 'Customer Group' : 'กลุ่มลูกหนี้',
                                      onChanged: (v) => setState(
                                          () => _selectedGroupIds = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // รหัสลูกหนี้ ตั้งแต่ / ถึง
                                    _buildCustomerCodeField(
                                        label: isEnglish ? 'Customer code from' : 'รหัสลูกหนี้ ตั้งแต่',
                                        displayText: _fromLabel,
                                        onPick: () =>
                                            _pickCustomer(isFrom: true),
                                        onClear: () => setState(() {
                                          _customerCodeFrom = null;
                                          _fromLabel = '';
                                        })),
                                    const SizedBox(height: 8),
                                    _buildCustomerCodeField(
                                        label: isEnglish ? 'Customer code to' : 'รหัสลูกหนี้ ถึง',
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

                                    // สถานะ
                                    DropdownButtonFormField<String>(
                                      value: _statusFilter,
                                      decoration: InputDecoration(
                                          labelText: l.status,
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'all',
                                            child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                                        DropdownMenuItem(
                                            value: 'pending',
                                            child: Text(isEnglish ? 'Pending' : 'รอชำระ')),
                                        DropdownMenuItem(
                                            value: 'paid',
                                            child: Text(l.paid)),
                                        DropdownMenuItem(
                                            value: 'void',
                                            child: Text(l.voided)),
                                      ],
                                      onChanged: (v) {
                                        if (v != null)
                                          setState(() => _statusFilter = v);
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // จัดเรียงข้อมูล
                                    DropdownButtonFormField<String>(
                                      value: _sortBy,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Sort by' : 'จัดเรียงข้อมูล',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'doc_type',
                                            child: Text(isEnglish ? 'Doc type + No.' : 'ประเภท+เลขที่')),
                                        DropdownMenuItem(
                                            value: 'customer',
                                            child: Text(isEnglish ? 'Customer code' : 'รหัสลูกค้า')),
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
                                            style:
                                                const TextStyle(fontSize: 13)),
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
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[800],
                                      foregroundColor: Colors.white),
                                  onPressed:
                                      _isLoading ? null : _generateReport,
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
                        child: Container(
                            width: 5, color: Colors.grey[400]),
                      ),
                    ),
                  // PDF preview
                  Expanded(
                    child: Container(
                      color: Colors.grey[200],
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator())
                          : _reportData.isEmpty
                              ? const Center(
                                  child: Text(
                                      'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat:
                                      PdfPageFormat.a4.landscape,
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
      builder: (_) => const _BillingStatusCustomerSearchDialog(),
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
                  child: Icon(Icons.search,
                      size: 18, color: Colors.teal[800]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : '— ทั้งหมด —',
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
    final reportTitle = _reportTitle;
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'BillingStatus';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      final _tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0, 'วันที่วางบิล: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  พิมพ์: $_tsLabel');

      final hdrs = ['ประเภทเอกสาร', 'เลขที่ใบวางบิล', 'วันที่เอกสาร',
          'รหัส – ชื่อลูกค้า', 'วางบิล (รอชำระ)', 'ชำระแล้ว', 'สถานะ'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      double grandPending = 0, grandPaid = 0;
      int totalBcs = 0;

      for (final bc in _reportData) {
        totalBcs++;
        final docCode   = bc['doc_code']          as String? ?? '';
        final bcDocNo   = bc['bc_doc_no']          as String? ?? '';
        final bcDate    = _fmtDate(bc['bc_doc_date'] as String?);
        final custCode  = bc['customer_code']      as String? ?? '';
        final custName  = bc['customer_name_th']   as String? ?? '';
        final total     = (bc['total_amount_lc']   as num?)?.toDouble() ?? 0;
        final balance   = (bc['balance_amount_lc'] as num?)?.toDouble() ?? 0;
        final status    = bc['status'] as String? ?? '';
        final isVoid    = status == 'Void';
        final pending   = isVoid ? 0.0 : balance;
        final paidAmt   = isVoid ? 0.0 : (total - balance);
        final statusLabel = isVoid ? 'ยกเลิก' : (balance > 0 ? 'รอชำระ' : 'ชำระแล้ว');

        grandPending += pending;
        grandPaid    += paidAmt;

        _xlCell(s, row, 0, docCode);
        _xlCell(s, row, 1, bcDocNo,             align: HorizontalAlign.Center);
        _xlCell(s, row, 2, bcDate,              align: HorizontalAlign.Center);
        _xlCell(s, row, 3, '$custCode  $custName');
        _xlCell(s, row, 4, pending,             align: HorizontalAlign.Right);
        _xlCell(s, row, 5, paidAmt,             align: HorizontalAlign.Right);
        _xlCell(s, row, 6, statusLabel,         align: HorizontalAlign.Center);
        row++;

        if (_showDetail) {
          final invoices = (bc['invoices'] as List? ?? []).cast<Map<String, dynamic>>();
          for (final inv in invoices) {
            final invDocName = inv['doc_name_thai'] as String? ?? '';
            final invDocNo   = inv['doc_no']        as String? ?? '';
            final invDate    = _fmtDate(inv['doc_date'] as String?);
            final invRef     = inv['ref_doc_no']    as String? ?? '';
            final applied    = (inv['applied_amount'] as num?)?.toDouble() ?? 0;
            final invBalance = (inv['inv_balance']    as num?)?.toDouble() ?? 0;
            final label = '   >> $invDocName  $invDocNo  $invDate${invRef.isNotEmpty ? '  $invRef' : ''}';
            final invPending = invBalance > 0 ? applied : 0.0;
            final invPaid    = invBalance <= 0 ? applied : 0.0;
            for (int i = 0; i < 7; i++) _xlCell(s, row, i, '', bg: detBg);
            _xlCell(s, row, 3, label,      bg: detBg);
            _xlCell(s, row, 4, invPending, bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, row, 5, invPaid,    bg: detBg, align: HorizontalAlign.Right);
            row++;
          }
        }
      }

      _xlCell(s, row, 0, 'รวม $totalBcs รายการ', bg: totBg, bold: true);
      for (int i = 1; i <= 3; i++) _xlCell(s, row, i, '', bg: totBg);
      _xlCell(s, row, 4, grandPending, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 5, grandPaid,    bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 6, '',           bg: totBg);

      final bytes = ex.encode();
      if (bytes == null) return;
      const title = 'รายงานสถานะใบวางบิล';
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

class _BillingStatusCustomerSearchDialog extends StatefulWidget {
  const _BillingStatusCustomerSearchDialog();

  @override
  State<_BillingStatusCustomerSearchDialog> createState() =>
      _BillingStatusCustomerSearchDialogState();
}

class _BillingStatusCustomerSearchDialogState
    extends State<_BillingStatusCustomerSearchDialog> {
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.teal[800],
              child: Text(l.isEnglish ? 'Search Customer' : 'ค้นหาลูกค้า',
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
                    hintText: l.isEnglish ? 'Search by customer code or name' : 'ค้นหาจากรหัสหรือชื่อลูกค้า',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true),
                onChanged: _search,
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                SizedBox(width: 100,
                    child: Text(l.isEnglish ? 'Code' : 'รหัส',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text(l.isEnglish ? 'Customer Name' : 'ชื่อลูกค้า',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? Center(
                          child: Text(l.isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
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
                                              fontWeight:
                                                  FontWeight.w500))),
                                  Expanded(
                                      child: Text(
                                          l.isEnglish && (c.customerNameEn?.isNotEmpty ?? false)
                                              ? c.customerNameEn!
                                              : c.customerNameTh,
                                          style: const TextStyle(
                                              fontSize: 13),
                                          overflow:
                                              TextOverflow.ellipsis)),
                                ]),
                              ),
                            );
                          }),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
