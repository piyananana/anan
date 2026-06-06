import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_credit_limit_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/salesperson.dart';
import '../../cd/services/salesperson_service.dart';
import '../../sa/models/company.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';

class ArCreditLimitReportScreen extends StatefulWidget {
  const ArCreditLimitReportScreen({super.key});

  @override
  State<ArCreditLimitReportScreen> createState() =>
      _ArCreditLimitReportScreenState();
}

class _ArCreditLimitReportScreenState
    extends State<ArCreditLimitReportScreen> {
  final _reportService      = ArCreditLimitReportService();
  final _companyService     = CompanyService();
  final _authService        = AuthService();
  final _groupService       = ArCustomerGroupService();
  final _salespersonService = SalespersonService();

  bool   _isLoading         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;

  Company? _company;
  Map<String, String>? _headers;

  List<ArCustomerGroup> _customerGroups = [];
  List<Salesperson>     _salespersons   = [];

  // Filters
  int?    _selectedGroupId;
  int?    _selectedSalespersonId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel    = '';
  String  _toLabel      = '';
  String  _creditStatus = '';          // '' | 'over' | 'remaining' | 'full'
  String  _sortBy       = 'customer'; // 'customer' | 'remaining_asc' | 'remaining_desc'

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
      final raw = await _reportService.getCreditLimitReport(
        customerGroupId:  _selectedGroupId,
        salespersonId:    _selectedSalespersonId,
        customerCodeFrom: _customerCodeFrom,
        customerCodeTo:   _customerCodeTo,
        creditStatus:     _creditStatus,
        sortBy:           _sortBy,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
      }
      setState(() { _reportData = raw; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Conditions line
    final conditions = <String>[];
    if (_selectedGroupId != null) {
      final g = _customerGroups.firstWhere((g) => g.id == _selectedGroupId,
          orElse: () => _customerGroups.first);
      conditions.add('กลุ่ม: ${g.groupCode} ${g.groupNameThai}');
    }
    if (_selectedSalespersonId != null) {
      final s = _salespersons.firstWhere((s) => s.id == _selectedSalespersonId,
          orElse: () => _salespersons.first);
      conditions.add('พนักงานขาย: ${s.salespersonCode} ${s.salespersonNameThai}');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty ||
        (_customerCodeTo   ?? '').isNotEmpty) {
      final f = (_customerCodeFrom ?? '').isEmpty ? '(ทั้งหมด)' : _customerCodeFrom!;
      final t = (_customerCodeTo   ?? '').isEmpty ? '(ทั้งหมด)' : _customerCodeTo!;
      conditions.add('รหัสลูกค้า: $f – $t');
    }
    if (_creditStatus.isNotEmpty) {
      conditions.add('สถานะ: ${_statusLabel(_creditStatus)}');
    }
    switch (_sortBy) {
      case 'remaining_asc':  conditions.add('เรียงวงเงินคงเหลือน้อยไปมาก'); break;
      case 'remaining_desc': conditions.add('เรียงวงเงินคงเหลือมากไปน้อย'); break;
      default:               conditions.add('เรียงรหัสลูกหนี้');
    }
    final conditionLine = conditions.join(' | ');

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3,
            child: pw.Text(companyName,
                style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text('รายงานวงเงินคงเหลือลูกหนี้',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 15,
                    fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3,
            child: pw.Text('หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6,
            child: pw.Text('ณ วันที่ ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(flex: 3,
            child: pw.Text('พิมพ์โดย $userName',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9,
            child: pw.Text('* $conditionLine',
                style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 3,
            child: pw.Text('พิมพ์เมื่อ $printDateStr',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 4),
    ]);

    // ─── Column widths (5 columns, portrait A4) ───────────────────────────────
    // 0: รหัส-ชื่อลูกหนี้  1: วงเงินรวม  2: หนี้คงค้าง
    // 3: วงเงินคงเหลือ      4: สถานะวงเงิน
    const colW = {
      0: pw.FlexColumnWidth(14),
      1: pw.FlexColumnWidth(6),
      2: pw.FlexColumnWidth(6),
      3: pw.FlexColumnWidth(6),
      4: pw.FlexColumnWidth(6),
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font,     fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cRed    = PdfColor(1.0,  0.90, 0.90);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t, style: tBold(9), textAlign: a));

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
        hCell('รหัส – ชื่อลูกหนี้', a: pw.TextAlign.left),
        hCell('วงเงินรวม'),
        hCell('หนี้คงค้าง'),
        hCell('วงเงินคงเหลือ'),
        hCell('สถานะวงเงิน'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    double grandLimit       = 0;
    double grandOutstanding = 0;
    double grandRemaining   = 0;
    int    totalCustomers   = 0;
    int    overCount        = 0;

    for (final row in _reportData) {
      totalCustomers++;
      final code        = row['customer_code']    as String? ?? '';
      final name        = row['customer_name_th'] as String? ?? '';
      final limit       = (row['credit_limit']    as num?)?.toDouble() ?? 0;
      final outstanding = (row['outstanding']     as num?)?.toDouble() ?? 0;
      final remaining   = (row['remaining']       as num?)?.toDouble() ?? 0;
      final status      = row['credit_status']    as String? ?? '';

      grandLimit       += limit;
      grandOutstanding += outstanding;
      grandRemaining   += remaining;
      if (status == 'over') overCount++;

      // สีพื้น row ตามสถานะ
      PdfColor? rowColor;
      if (status == 'over')     rowColor = cRed;
      if (status == 'full')     rowColor = const PdfColor(0.93, 0.98, 0.93);
      if (status == 'no_limit') rowColor = const PdfColor(0.97, 0.97, 0.97);

      final statusStyle = status == 'over'
          ? tBold(9)
          : tNormal(9);

      tableRows.add(pw.TableRow(
        decoration: rowColor != null
            ? pw.BoxDecoration(color: rowColor)
            : null,
        children: [
          dCell('$code  $name', tNormal(9)),
          amtCell(limit,       tNormal(9)),
          amtCell(outstanding, tNormal(9)),
          dCell(
            limit <= 0 ? '–' : fmt.format(remaining),
            remaining < 0 ? tBold(9) : tNormal(9),
            a: pw.TextAlign.right,
          ),
          dCell(_statusLabel(status), statusStyle,
              a: pw.TextAlign.center),
        ],
      ));
    }

    // ─── Grand total row ──────────────────────────────────────────────────────
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
          color: PdfColor(0.75, 0.88, 0.83)),
      children: [
        dCell('รวม $totalCustomers ลูกหนี้'
            '${overCount > 0 ? ' (เกินวงเงิน $overCount ราย)' : ''}',
            tBold(9)),
        amtCellDash(grandLimit,       tBold(9)),
        amtCellDash(grandOutstanding, tBold(9)),
        amtCellDash(grandRemaining,   tBold(9)),
        dCell('', tBold(9)),
      ],
    ));

    // ─── Build page ───────────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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

  static String _statusLabel(String status) {
    switch (status) {
      case 'over':      return 'เกินวงเงิน';
      case 'remaining': return 'ยังเหลือวงเงิน';
      case 'full':      return 'เหลือเต็มวงเงิน';
      case 'no_limit':  return 'ไม่ระบุวงเงิน';
      default:          return status;
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.credit_score, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text('รายงานวงเงินคงเหลือลูกหนี้'),
        ]),
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
              onPressed: _reportData.isEmpty ? null : _exportExcel,
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
                      tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
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
                                    const Text('เงื่อนไขรายงาน',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 16),

                                    // กลุ่มลูกหนี้
                                    DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      value: _selectedGroupId,
                                      decoration: const InputDecoration(
                                          labelText: 'กลุ่มลูกหนี้',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('— ทุกกลุ่ม —')),
                                        ..._customerGroups.map((g) =>
                                            DropdownMenuItem<int?>(
                                              value: g.id,
                                              child: Text(
                                                  '${g.groupCode}  ${g.groupNameThai}',
                                                  overflow: TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _selectedGroupId = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // พนักงานขาย
                                    DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      value: _selectedSalespersonId,
                                      decoration: const InputDecoration(
                                          labelText: 'พนักงานขาย',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('— ทั้งหมด —')),
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
                                        label: 'รหัสลูกหนี้ ตั้งแต่',
                                        displayText: _fromLabel,
                                        onPick: () =>
                                            _pickCustomer(isFrom: true),
                                        onClear: () => setState(() {
                                          _customerCodeFrom = null;
                                          _fromLabel = '';
                                        })),
                                    const SizedBox(height: 8),
                                    _buildCustomerCodeField(
                                        label: 'รหัสลูกหนี้ ถึง',
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

                                    // สถานะวงเงิน
                                    DropdownButtonFormField<String>(
                                      value: _creditStatus,
                                      decoration: const InputDecoration(
                                          labelText: 'สถานะวงเงิน',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: const [
                                        DropdownMenuItem(
                                            value: '',
                                            child: Text('— ทั้งหมด —')),
                                        DropdownMenuItem(
                                            value: 'over',
                                            child: Text('เกินวงเงิน')),
                                        DropdownMenuItem(
                                            value: 'remaining',
                                            child: Text('ยังเหลือวงเงิน')),
                                        DropdownMenuItem(
                                            value: 'full',
                                            child: Text('เหลือเต็มวงเงิน')),
                                        DropdownMenuItem(
                                            value: 'no_limit',
                                            child: Text('ไม่ระบุวงเงิน')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _creditStatus = v);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // จัดเรียงข้อมูล
                                    DropdownButtonFormField<String>(
                                      value: _sortBy,
                                      decoration: const InputDecoration(
                                          labelText: 'จัดเรียงข้อมูล',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'customer',
                                            child: Text('รหัสลูกหนี้')),
                                        DropdownMenuItem(
                                            value: 'remaining_asc',
                                            child: Text('วงเงินคงเหลือ น้อยไปมาก')),
                                        DropdownMenuItem(
                                            value: 'remaining_desc',
                                            child: Text('วงเงินคงเหลือ มากไปน้อย')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _sortBy = v);
                                          _onSettingChanged();
                                        }
                                      },
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
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('ประมวลผลรายงาน'),
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
                              ? const Center(
                                  child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat: PdfPageFormat.a4,
                                  canChangeOrientation: false,
                                  canDebug: false,
                                ),
                    ),
                  ),
                ],
              );
            }),
    );
  }

  // ─── filter helpers ───────────────────────────────────────────────────────

  Future<void> _pickCustomer({required bool isFrom}) async {
    final result = await showDialog<ArCustomer>(
      context: context,
      builder: (_) => const _CreditLimitCustomerSearchDialog(),
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

  // ─── Excel Export ─────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'CreditLimit';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      final _tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'รายงานวงเงินคงเหลือลูกหนี้', bold: true);
      _xlCell(s, 2, 0, 'พิมพ์วันที่: $_tsLabel');

      final hdrs = ['รหัส – ชื่อลูกหนี้', 'วงเงินรวม', 'หนี้คงค้าง', 'วงเงินคงเหลือ', 'สถานะวงเงิน'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      double grandLimit = 0, grandOutstanding = 0, grandRemaining = 0;
      int totalCustomers = 0, overCount = 0;

      for (final r in _reportData) {
        totalCustomers++;
        final code        = r['customer_code']    as String? ?? '';
        final name        = r['customer_name_th'] as String? ?? '';
        final limit       = (r['credit_limit']    as num?)?.toDouble() ?? 0;
        final outstanding = (r['outstanding']     as num?)?.toDouble() ?? 0;
        final remaining   = (r['remaining']       as num?)?.toDouble() ?? 0;
        final status      = r['credit_status']    as String? ?? '';

        grandLimit       += limit;
        grandOutstanding += outstanding;
        grandRemaining   += remaining;
        if (status == 'over') overCount++;

        _xlCell(s, row, 0, '$code  $name');
        _xlCell(s, row, 1, limit,       align: HorizontalAlign.Right);
        _xlCell(s, row, 2, outstanding, align: HorizontalAlign.Right);
        _xlCell(s, row, 3, limit <= 0 ? '-' : remaining, align: HorizontalAlign.Right);
        _xlCell(s, row, 4, _statusLabel(status), align: HorizontalAlign.Center);
        row++;
      }

      final totalLabel = 'รวม $totalCustomers ลูกหนี้'
          '${overCount > 0 ? ' (เกินวงเงิน $overCount ราย)' : ''}';
      _xlCell(s, row, 0, totalLabel,       bg: totBg, bold: true);
      _xlCell(s, row, 1, grandLimit,       bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 2, grandOutstanding, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 3, grandRemaining,   bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 4, '',              bg: totBg);

      final bytes = ex.encode();
      if (bytes == null) return;
      const title = 'รายงานวงเงินคงเหลือลูกหนี้';
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
                  child: Icon(Icons.search, size: 18, color: Colors.teal[800]))),
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
}

// ─── Customer search dialog ────────────────────────────────────────────────────

class _CreditLimitCustomerSearchDialog extends StatefulWidget {
  const _CreditLimitCustomerSearchDialog();

  @override
  State<_CreditLimitCustomerSearchDialog> createState() =>
      _CreditLimitCustomerSearchDialogState();
}

class _CreditLimitCustomerSearchDialogState
    extends State<_CreditLimitCustomerSearchDialog> {
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
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.teal[800],
              child: const Text('ค้นหาลูกหนี้',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'ค้นหาจากรหัสหรือชื่อลูกหนี้',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true),
                onChanged: _search,
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(children: [
                SizedBox(width: 100,
                    child: Text('รหัส',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text('ชื่อลูกหนี้',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? const Center(
                          child: Text('ไม่พบข้อมูล',
                              style: TextStyle(color: Colors.grey)))
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
                                      child: Text(c.customerNameTh,
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
                      child: const Text('ยกเลิก')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
