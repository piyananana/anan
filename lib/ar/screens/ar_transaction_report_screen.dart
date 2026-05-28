import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_transaction_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/branch.dart';
import '../../cd/models/salesperson.dart';
import '../../cd/services/branch_service.dart';
import '../../cd/services/salesperson_service.dart';
import '../../sa/models/company.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';

// ─── sys_doc_type → column index mapping ──────────────────────────────────────
// 0=แจ้งหนี้(10)  1=เพิ่มหนี้(30/35)  2=ลดหนี้(50/55)
// 3=รับมัดจำ(60)  4=คืนมัดจำ(65)       5=รับชำระ(80)
int? _colIdx(String sdt) {
  switch (sdt) {
    case '10': return 0;
    case '30':
    case '35': return 1;
    case '50':
    case '55': return 2;
    case '60': return 3;
    case '65': return 4;
    case '80': return 5;
    default:   return null;
  }
}

class ArTransactionReportScreen extends StatefulWidget {
  const ArTransactionReportScreen({super.key});

  @override
  State<ArTransactionReportScreen> createState() =>
      _ArTransactionReportScreenState();
}

class _ArTransactionReportScreenState
    extends State<ArTransactionReportScreen> {
  final _reportService   = ArTransactionReportService();
  final _companyService  = CompanyService();
  final _authService     = AuthService();
  final _groupService    = ArCustomerGroupService();
  final _branchService   = BranchService();
  final _salespersonService = SalespersonService();

  bool _isLoading        = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider  = false;
  int  _pdfKey = 0;

  Company? _company;
  Map<String, String>? _headers;

  // Master data
  List<Branch>          _branches      = [];
  List<ArCustomerGroup> _customerGroups = [];
  List<Salesperson>     _salespersons  = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  int?    _selectedBranchId;
  int?    _selectedGroupId;
  int?    _selectedSalespersonId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';
  String  _sortBy    = 'customer'; // 'customer' | 'doc_type'
  bool    _showDetail = false;

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
      _salespersonService.fetchRows(),
    ]);
    _company        = results[0] as Company?;
    _branches       = (results[1] as List<Branch>)
        .where((b) => b.isActive).toList();
    _customerGroups = results[2] as List<ArCustomerGroup>;
    _salespersons   = (results[3] as List<Salesperson>)
        .where((s) => s.isActive).toList();
    if (mounted) setState(() {});
  }

  // ─── report ───────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getTransactionReport(
        dateFrom:          DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:            DateFormat('yyyy-MM-dd').format(_dateTo),
        branchId:          _selectedBranchId,
        customerGroupId:   _selectedGroupId,
        salespersonId:     _selectedSalespersonId,
        customerCodeFrom:  _customerCodeFrom,
        customerCodeTo:    _customerCodeTo,
        sortBy:            _sortBy,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่พบข้อมูลในช่วงวันที่ที่เลือก')));
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
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine =
        'ช่วงวันที่ ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    // Conditions line
    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere((b) => b.id == _selectedBranchId,
          orElse: () => _branches.first);
      conditions.add('สาขา: ${b.branchCode} ${b.branchNameThai}');
    }
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
        (_customerCodeTo ?? '').isNotEmpty) {
      conditions.add(
          'รหัสลูกค้า: ${_customerCodeFrom?.isEmpty ?? true ? '(ทั้งหมด)' : _customerCodeFrom!}'
          ' – ${_customerCodeTo?.isEmpty ?? true ? '(ทั้งหมด)' : _customerCodeTo!}');
    }
    conditions.add(_sortBy == 'doc_type'
        ? 'เรียงตามประเภทเอกสาร' : 'เรียงตามรหัสลูกหนี้');
    if (_showDetail) conditions.add('แสดงรายละเอียด');

    final conditionLine = conditions.join(' | ');
    final showDetail    = _showDetail;

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3,
            child: pw.Text(companyName,
                style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text('รายงานธุรกรรมลูกหนี้',
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
            child: pw.Text(dateRangeLine,
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

    // ─── Column widths (7 columns) ────────────────────────────────────────────
    const colW = {
      0: pw.FlexColumnWidth(13),  // รหัส-ชื่อลูกค้า
      1: pw.FlexColumnWidth(7),   // แจ้งหนี้
      2: pw.FlexColumnWidth(7),   // เพิ่มหนี้
      3: pw.FlexColumnWidth(7),   // ลดหนี้
      4: pw.FlexColumnWidth(6),   // รับมัดจำ
      5: pw.FlexColumnWidth(6),   // คืนมัดจำ
      6: pw.FlexColumnWidth(7),   // รับชำระ
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');

    // ─── Style shortcuts ──────────────────────────────────────────────────────
    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold, fontSize: fs);
    pw.TextStyle tItalic(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cYellow = PdfColor(1.0,  0.98, 0.88);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);
    const cGray   = PdfColor(0.96, 0.96, 0.96);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t,
              style: tBold(8.5), textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s,
            {pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t, style: s, textAlign: a));

    pw.Widget amtCell(double v, pw.TextStyle s,
            {bool dash = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
              v == 0 && dash ? '–' : (v == 0 ? '' : fmt.format(v)),
              style: s, textAlign: pw.TextAlign.right));

    // ─── Column header row ────────────────────────────────────────────────────
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell('รหัส – ชื่อลูกค้า', a: pw.TextAlign.left),
        hCell('แจ้งหนี้'),
        hCell('เพิ่มหนี้'),
        hCell('ลดหนี้'),
        hCell('รับมัดจำ'),
        hCell('คืนมัดจำ'),
        hCell('รับชำระ'),
      ],
    );

    // ─── Build rows per customer ───────────────────────────────────────────────
    final tableRows = <pw.TableRow>[headerRow];

    // Grand totals accumulators
    final grandAmts   = List<double>.filled(6, 0.0);
    final grandCounts = List<int>.filled(6, 0);
    int totalCustomers = 0;

    for (final cust in _reportData) {
      totalCustomers++;
      final code = cust['customer_code'] as String? ?? '';
      final name = cust['customer_name_th'] as String? ?? '';
      final amts = [
        (cust['inv_amount'] as num?)?.toDouble() ?? 0,
        (cust['dn_amount']  as num?)?.toDouble() ?? 0,
        (cust['cn_amount']  as num?)?.toDouble() ?? 0,
        (cust['adv_amount'] as num?)?.toDouble() ?? 0,
        (cust['ret_amount'] as num?)?.toDouble() ?? 0,
        (cust['rec_amount'] as num?)?.toDouble() ?? 0,
      ];

      for (int i = 0; i < 6; i++) grandAmts[i] += amts[i];

      // Customer summary row
      tableRows.add(pw.TableRow(
        decoration: showDetail
            ? const pw.BoxDecoration(color: cBlue)
            : null,
        children: [
          dCell('$code  $name',
              showDetail ? tBold(9) : tNormal(9)),
          ...List.generate(6, (i) =>
              amtCell(amts[i], showDetail ? tBold(9) : tNormal(9))),
        ],
      ));

      if (!showDetail) continue;

      // Detail rows (italic)
      final txns = (cust['transactions'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final t in txns) {
        final sdt   = t['sys_doc_type'] as String? ?? '';
        final ci    = _colIdx(sdt);
        final tAmt  = (t['total_amount_lc'] as num?)?.toDouble() ?? 0;
        final cols  = List<double>.filled(6, 0.0);
        if (ci != null) {
          cols[ci] = tAmt;
          grandCounts[ci]++;
        }

        final docDate = _fmtDate(t['doc_date'] as String?);
        final refNo   = t['ref_doc_no'] as String? ?? '';
        final label   =
            '${t['doc_name_thai'] ?? ''}  ${t['doc_no'] ?? ''}  $docDate'
            '${refNo.isNotEmpty ? '  $refNo' : ''}';

        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: cGray),
          children: [
            dCell('     $label', tItalic(8.5)),
            ...List.generate(6, (i) =>
                amtCell(cols[i], tItalic(8.5))),
          ],
        ));
      }
    }

    // ─── Grand total rows (2 rows) ────────────────────────────────────────────
    // Row 1: document count per type
    if (showDetail) {
      final totalDocs = grandCounts.fold(0, (s, c) => s + c);
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: cYellow),
        children: [
          dCell('รวม $totalCustomers ลูกค้า / $totalDocs เอกสาร',
              tBold(9)),
          ...List.generate(6, (i) => grandCounts[i] > 0
              ? dCell('${grandCounts[i]} ใบ', tBold(9),
                  a: pw.TextAlign.right)
              : dCell('', tBold(9))),
        ],
      ));
    }

    // Row 2 (or only row when !showDetail): amount totals
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
          color: PdfColor(0.75, 0.88, 0.83)),
      children: [
        dCell(showDetail ? 'ยอดเงินรวมทุกประเภท' : 'รวม $totalCustomers ลูกค้า',
            tBold(9)),
        ...List.generate(6, (i) =>
            amtCell(grandAmts[i], tBold(9), dash: true)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.assessment, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text('รายงานธุรกรรมลูกหนี้'),
        ]),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
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
                          ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
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
                                    const Text('เงื่อนไขรายงาน',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 16),

                                    // วันที่ ตั้งแต่ / ถึง
                                    _buildDateField(
                                        label: 'วันที่เอกสาร ตั้งแต่',
                                        date: _dateFrom,
                                        onPick: (d) =>
                                            setState(() => _dateFrom = d)),
                                    const SizedBox(height: 12),
                                    _buildDateField(
                                        label: 'วันที่เอกสาร ถึง',
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
                                      decoration: const InputDecoration(
                                          labelText: 'สาขา',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('— ทุกสาขา —')),
                                        ..._branches.map((b) =>
                                            DropdownMenuItem<int?>(
                                              value: b.id,
                                              child: Text(
                                                  '${b.branchCode}  ${b.branchNameThai}',
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _selectedBranchId = v),
                                    ),
                                    const SizedBox(height: 12),

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
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _selectedGroupId = v),
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
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            )),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _selectedSalespersonId = v),
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
                                            value: 'doc_type',
                                            child: Text('ประเภทเอกสาร')),
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
                                      const Expanded(
                                        child: Text('แสดงรายละเอียด',
                                            style:
                                                TextStyle(fontSize: 13)),
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
                                  label: const Text('ประมวลผลรายงาน'),
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
      builder: (_) => const _TxnRptCustomerSearchDialog(),
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
}

// ─── Customer search dialog ────────────────────────────────────────────────────

class _TxnRptCustomerSearchDialog extends StatefulWidget {
  const _TxnRptCustomerSearchDialog();

  @override
  State<_TxnRptCustomerSearchDialog> createState() =>
      _TxnRptCustomerSearchDialogState();
}

class _TxnRptCustomerSearchDialogState
    extends State<_TxnRptCustomerSearchDialog> {
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
              child: const Text('ค้นหาลูกค้า',
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
                    hintText: 'ค้นหาจากรหัสหรือชื่อลูกค้า',
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
                Expanded(child: Text('ชื่อลูกค้า',
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
