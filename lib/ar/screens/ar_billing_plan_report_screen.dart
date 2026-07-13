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
import '../models/ar_collector.dart';
import '../services/ar_billing_plan_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../services/ar_collector_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

class ArBillingPlanReportScreen extends StatefulWidget {
  const ArBillingPlanReportScreen({super.key});

  @override
  State<ArBillingPlanReportScreen> createState() =>
      _ArBillingPlanReportScreenState();
}

class _ArBillingPlanReportScreenState
    extends State<ArBillingPlanReportScreen> {
  final ArBillingPlanReportService _reportService =
      ArBillingPlanReportService();
  final CompanyService          _companyService   = CompanyService();
  final AuthService             _authService      = AuthService();
  final ArCustomerGroupService  _groupService     = ArCustomerGroupService();
  final ArCollectorService      _collectorService = ArCollectorService();

  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey      = 0;
  bool   _isExporting = false;

  Company? _company;
  Map<String, String>? _headers;

  // Master data
  List<ArCustomerGroup> _customerGroups = [];
  List<ArCollector>     _collectors     = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<int> _selectedGroupIds = [];
  int?    _selectedCollectorId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';
  bool    _pageBreakPerCollector = false;

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
      _collectorService.fetchRows(),
    ]);
    _company        = results[0] as Company?;
    _customerGroups = results[1] as List<ArCustomerGroup>;
    _collectors     = ((results[2] as List<ArCollector>))
        .where((c) => c.isActive)
        .toList();
    if (mounted) setState(() {});
  }

  // ─── report ───────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getBillingPlanReport(
        dateFrom:           DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:             DateFormat('yyyy-MM-dd').format(_dateTo),
        customerGroupIds:   _selectedGroupIds,
        billingCollectorId: _selectedCollectorId,
        customerCodeFrom:   _customerCodeFrom,
        customerCodeTo:     _customerCodeTo,
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

  // ─── helpers ──────────────────────────────────────────────────────────────

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy')
          .format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
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
        'วันที่วางบิล ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    // Conditions line
    final conditions = <String>[];
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _customerGroups.firstWhere((g) => g.id == id,
            orElse: () => _customerGroups.first);
        return '${g.groupCode} ${g.groupNameThai}';
      }).join(', ');
      conditions.add('กลุ่มลูกค้า: $names');
    }
    if (_selectedCollectorId != null) {
      final c = _collectors.firstWhere((c) => c.id == _selectedCollectorId,
          orElse: () => _collectors.first);
      conditions.add('ผู้วางบิล: ${c.collectorCode} ${c.collectorNameThai}');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty ||
        (_customerCodeTo   ?? '').isNotEmpty) {
      final from = _customerCodeFrom ?? '';
      final to   = _customerCodeTo   ?? '';
      conditions.add(
          'รหัสลูกค้า: ${from.isEmpty ? '(ทั้งหมด)' : from}'
          ' – ${to.isEmpty   ? '(ทั้งหมด)' : to}');
    }
    if (_pageBreakPerCollector) conditions.add('ขึ้นหน้าใหม่ทุกผู้วางบิล');
    final conditionLine =
        conditions.isEmpty ? 'ทุกลูกค้า' : conditions.join(' | ');

    final pageBreak = _pageBreakPerCollector;

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3,
            child: pw.Text(companyName,
                style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text('รายงานกำหนดวางบิล',
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

    // ─── Column widths (10 columns) ───────────────────────────────────────────
    const colW = {
      0: pw.FlexColumnWidth(5),    // วันที่วางบิล
      1: pw.FlexColumnWidth(5),    // ประเภทเอกสาร
      2: pw.FlexColumnWidth(7),    // เลขที่เอกสาร
      3: pw.FlexColumnWidth(5),    // วันแจ้งหนี้
      4: pw.FlexColumnWidth(5),    // วันครบกำหนด
      5: pw.FlexColumnWidth(5),    // วันชำระ(คาดว่า)
      6: pw.FlexColumnWidth(11),   // รหัส-ชื่อลูกหนี้
      7: pw.FlexColumnWidth(5),    // เบอร์โทร
      8: pw.FlexColumnWidth(6),    // ยอดคงค้าง
      9: pw.FlexColumnWidth(5),    // อ้างอิง
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');
    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cYellow = PdfColor(1.0,  0.98, 0.88);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);

    // cell helpers
    final styleNormal = pw.TextStyle(font: font,     fontSize: 9);
    final styleBold   = pw.TextStyle(font: fontBold, fontSize: 9);
    final styleItalic = pw.TextStyle(font: fontItalic, fontSize: 9);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t,
              style: pw.TextStyle(font: fontBold, fontSize: 8.5),
              textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s,
            {pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t, style: s, textAlign: a));

    pw.Widget numCell(double v, pw.TextStyle s) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(fmt.format(v),
              style: s, textAlign: pw.TextAlign.right));

    // ─── Column header row ────────────────────────────────────────────────────
    pw.TableRow headerRow() => pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell('วันที่วางบิล'),
        hCell('ประเภท\nเอกสาร', a: pw.TextAlign.left),
        hCell('เลขที่เอกสาร'),
        hCell('วันแจ้งหนี้'),
        hCell('วันครบ\nกำหนด'),
        hCell('วันชำระ\n(คาดว่า)'),
        hCell('รหัส – ชื่อลูกหนี้', a: pw.TextAlign.left),
        hCell('เบอร์โทร'),
        hCell('ยอดคงค้าง'),
        hCell('อ้างอิง'),
      ],
    );

    // ─── Build content for one collector ─────────────────────────────────────
    List<pw.Widget> buildCollectorContent(Map<String, dynamic> collector) {
      final collCode  = collector['collector_code']      as String? ?? '';
      final collName  = collector['collector_name_thai'] as String? ?? '';
      final invoices  = (collector['invoices'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final totalBal  = (collector['total_balance'] as num?)?.toDouble() ?? 0;

      final rows = <pw.TableRow>[
        headerRow(),
        ...invoices.asMap().entries.map((e) {
          final i   = e.value;
          final bal = (i['balance_amount_lc'] as num?)?.toDouble() ?? 0;
          final custText =
              '${i['customer_code'] ?? ''}  ${i['customer_name_th'] ?? ''}';
          return pw.TableRow(children: [
            dCell(_fmtDate(i['billing_date'] as String?), styleNormal),
            dCell(i['doc_name_thai'] as String? ?? '', styleItalic),
            dCell(i['doc_no'] as String? ?? '', styleNormal),
            dCell(_fmtDate(i['doc_date']              as String?), styleItalic),
            dCell(_fmtDate(i['due_date']              as String?), styleItalic),
            dCell(_fmtDate(i['expected_payment_date'] as String?), styleItalic),
            dCell(custText, styleNormal),
            dCell(i['customer_phone'] as String? ?? '', styleNormal,
                a: pw.TextAlign.center),
            numCell(bal, styleNormal),
            dCell(i['ref_no'] as String? ?? '', styleNormal,
                a: pw.TextAlign.center),
          ]);
        }),
        // Subtotal per collector
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: cYellow),
          children: [
            dCell('', styleBold), dCell('', styleBold), dCell('', styleBold),
            dCell('', styleBold), dCell('', styleBold), dCell('', styleBold),
            dCell('รวม ${invoices.length} รายการ', styleBold),
            dCell('', styleBold),
            numCell(totalBal, styleBold),
            dCell('', styleBold),
          ],
        ),
      ];

      return [
        // Collector header bar
        pw.Container(
          decoration: const pw.BoxDecoration(color: cBlue),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(children: [
            pw.Text(
                collCode.isEmpty
                    ? collName
                    : '$collCode  $collName',
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
          ]),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          columnWidths: colW,
          children: rows,
        ),
        pw.SizedBox(height: 6),
      ];
    }

    // ─── Grand total ──────────────────────────────────────────────────────────
    List<pw.Widget> buildGrandTotal() {
      final grandBal = _reportData.fold(0.0,
          (s, c) => s + ((c['total_balance'] as num?)?.toDouble() ?? 0));
      final grandCnt = _reportData.fold(0,
          (s, c) => s + ((c['invoices'] as List?)?.length ?? 0));
      return [
        pw.Table(
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          columnWidths: colW,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor(0.75, 0.88, 0.83)),
              children: [
                dCell('', styleBold), dCell('', styleBold),
                dCell('', styleBold), dCell('', styleBold),
                dCell('', styleBold), dCell('', styleBold),
                dCell('รวมทุกผู้วางบิล $grandCnt รายการ', styleBold),
                dCell('', styleBold),
                numCell(grandBal, styleBold),
                dCell('', styleBold),
              ],
            ),
          ],
        ),
      ];
    }

    // ─── Add pages ────────────────────────────────────────────────────────────
    if (pageBreak) {
      for (int i = 0; i < _reportData.length; i++) {
        final collector = _reportData[i];
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            theme: pw.ThemeData.withFont(base: font, bold: fontBold),
            margin: const pw.EdgeInsets.all(20),
            header: pageHeader(),
            build: (ctx) {
              final content = buildCollectorContent(collector);
              if (i == _reportData.length - 1) {
                content.addAll(buildGrandTotal());
              }
              return content;
            },
          ),
        );
      }
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.all(20),
          header: pageHeader(),
          build: (ctx) {
            final content = <pw.Widget>[];
            for (final collector in _reportData) {
              content.addAll(buildCollectorContent(collector));
            }
            content.addAll(buildGrandTotal());
            return content;
          },
        ),
      );
    }

    return doc.save();
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
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
                      tooltip:
                          _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
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
                          child: Column(
                            children: [
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

                                      // วันที่วางบิล ตั้งแต่
                                      _buildDateField(
                                        label: 'วันที่วางบิล ตั้งแต่',
                                        date: _dateFrom,
                                        onPick: (d) =>
                                            setState(() => _dateFrom = d),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDateField(
                                        label: 'วันที่วางบิล ถึง',
                                        date: _dateTo,
                                        onPick: (d) =>
                                            setState(() => _dateTo = d),
                                      ),

                                      const SizedBox(height: 16),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),

                                      // กลุ่มลูกค้า
                                      ArCustomerGroupMultiPicker(
                                        groups: _customerGroups,
                                        selectedIds: _selectedGroupIds,
                                        onChanged: (v) => setState(
                                            () => _selectedGroupIds = v),
                                      ),

                                      // ผู้วางบิล
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<int?>(
                                        isExpanded: true,
                                        value: _selectedCollectorId,
                                        decoration: const InputDecoration(
                                            labelText: 'ผู้วางบิล',
                                            border: OutlineInputBorder(),
                                            isDense: true),
                                        items: [
                                          const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('— ทั้งหมด —')),
                                          ..._collectors.map((c) =>
                                              DropdownMenuItem<int?>(
                                                value: c.id,
                                                child: Text(
                                                    '${c.collectorCode}  ${c.collectorNameThai}',
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              )),
                                        ],
                                        onChanged: (v) => setState(
                                            () => _selectedCollectorId = v),
                                      ),

                                      // รหัสลูกค้า ตั้งแต่ / ถึง
                                      const SizedBox(height: 12),
                                      _buildCustomerCodeField(
                                        label: 'รหัสลูกค้า ตั้งแต่',
                                        displayText: _fromLabel,
                                        onPick: () =>
                                            _pickCustomer(isFrom: true),
                                        onClear: () => setState(() {
                                          _customerCodeFrom = null;
                                          _fromLabel = '';
                                        }),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildCustomerCodeField(
                                        label: 'รหัสลูกค้า ถึง',
                                        displayText: _toLabel,
                                        onPick: () =>
                                            _pickCustomer(isFrom: false),
                                        onClear: () => setState(() {
                                          _customerCodeTo = null;
                                          _toLabel = '';
                                        }),
                                      ),

                                      const SizedBox(height: 8),
                                      const Divider(height: 1),

                                      // ขึ้นหน้าใหม่ทุกผู้วางบิล
                                      Row(children: [
                                        const Expanded(
                                          child: Text(
                                              'ขึ้นหน้าใหม่ทุกผู้วางบิล',
                                              style:
                                                  TextStyle(fontSize: 13)),
                                        ),
                                        Switch(
                                          value: _pageBreakPerCollector,
                                          activeColor: Colors.teal[800],
                                          onChanged: (v) {
                                            setState(() =>
                                                _pageBreakPerCollector = v);
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
                            ],
                          ),
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
      builder: (_) => const _BillingPlanCustomerSearchDialog(),
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasValue)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.clear, size: 16, color: Colors.grey),
                ),
              ),
            InkWell(
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.search, size: 18, color: Colors.teal[800]),
              ),
            ),
          ],
        ),
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
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'BillingPlan';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg  = ExcelColor.fromHexString('#92D050');
      final totBg  = ExcelColor.fromHexString('#BDD7EE');
      final grandBg = ExcelColor.fromHexString('#A9D18E');

      final _tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'รายงานกำหนดวางบิล', bold: true);
      _xlCell(s, 2, 0, 'วันที่วางบิล: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  พิมพ์: $_tsLabel');

      final hdrs = ['วันที่วางบิล', 'ประเภทเอกสาร', 'เลขที่เอกสาร',
          'วันแจ้งหนี้', 'วันครบกำหนด', 'วันชำระ (คาดว่า)',
          'รหัส – ชื่อลูกหนี้', 'เบอร์โทร', 'ยอดคงค้าง', 'อ้างอิง'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      double grandBal = 0;
      int grandCnt = 0;

      for (final collector in _reportData) {
        final collCode = collector['collector_code']      as String? ?? '';
        final collName = collector['collector_name_thai'] as String? ?? '';
        final totalBal = (collector['total_balance']      as num?)?.toDouble() ?? 0;
        final invoices = (collector['invoices'] as List? ?? []).cast<Map<String, dynamic>>();

        // Collector header
        final collLabel = collCode.isEmpty ? collName : '$collCode  $collName';
        _xlCell(s, row, 0, collLabel, bold: true);
        for (int i = 1; i < 10; i++) _xlCell(s, row, i, '');
        row++;

        for (final inv in invoices) {
          grandCnt++;
          final bal = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0;
          final custText = '${inv['customer_code'] ?? ''}  ${inv['customer_name_th'] ?? ''}';
          _xlCell(s, row, 0, _fmtDate(inv['billing_date']           as String?), align: HorizontalAlign.Center);
          _xlCell(s, row, 1, inv['doc_name_thai']                   as String? ?? '');
          _xlCell(s, row, 2, inv['doc_no']                          as String? ?? '');
          _xlCell(s, row, 3, _fmtDate(inv['doc_date']              as String?), align: HorizontalAlign.Center);
          _xlCell(s, row, 4, _fmtDate(inv['due_date']              as String?), align: HorizontalAlign.Center);
          _xlCell(s, row, 5, _fmtDate(inv['expected_payment_date'] as String?), align: HorizontalAlign.Center);
          _xlCell(s, row, 6, custText);
          _xlCell(s, row, 7, inv['customer_phone'] as String? ?? '', align: HorizontalAlign.Center);
          _xlCell(s, row, 8, bal,                                    align: HorizontalAlign.Right);
          _xlCell(s, row, 9, inv['ref_no'] as String? ?? '',         align: HorizontalAlign.Center);
          row++;
        }

        // Subtotal per collector
        _xlCell(s, row, 0, '',                           bg: totBg);
        for (int i = 1; i <= 5; i++) _xlCell(s, row, i, '', bg: totBg);
        _xlCell(s, row, 6, 'รวม ${invoices.length} รายการ', bg: totBg, bold: true);
        _xlCell(s, row, 7, '',                           bg: totBg);
        _xlCell(s, row, 8, totalBal, bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, row, 9, '',                           bg: totBg);
        row++;

        grandBal += totalBal;
      }

      // Grand total
      for (int i = 0; i < 6; i++) _xlCell(s, row, i, '', bg: grandBg);
      _xlCell(s, row, 6, 'รวมทุกผู้วางบิล $grandCnt รายการ', bg: grandBg, bold: true);
      _xlCell(s, row, 7, '', bg: grandBg);
      _xlCell(s, row, 8, grandBal, bg: grandBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, row, 9, '', bg: grandBg);

      final bytes = ex.encode();
      if (bytes == null) return;
      const title = 'รายงานกำหนดวางบิล';
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

// ── Customer search dialog ────────────────────────────────────────────────────

class _BillingPlanCustomerSearchDialog extends StatefulWidget {
  const _BillingPlanCustomerSearchDialog();

  @override
  State<_BillingPlanCustomerSearchDialog> createState() =>
      _BillingPlanCustomerSearchDialogState();
}

class _BillingPlanCustomerSearchDialogState
    extends State<_BillingPlanCustomerSearchDialog> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final ArCustomerService _service = ArCustomerService();
  List<ArCustomer> _customers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final list = await _service.fetchRows(
          search: query.trim().isEmpty ? null : query.trim());
      if (mounted) setState(() => _customers = list);
    } catch (_) {
      if (mounted) setState(() => _customers = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาจากรหัสหรือชื่อลูกค้า',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              child: const Row(children: [
                SizedBox(
                    width: 100,
                    child: Text('รหัส',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12))),
                Expanded(
                    child: Text('ชื่อลูกค้า',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? const Center(
                          child: Text('ไม่พบข้อมูล',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: _scrollCtrl,
                          itemCount: _customers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 12),
                          itemBuilder: (ctx, i) {
                            final c = _customers[i];
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, c),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(c.customerCode,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w500)),
                                  ),
                                  Expanded(
                                    child: Text(c.customerNameTh,
                                        style: const TextStyle(
                                            fontSize: 13),
                                        overflow:
                                            TextOverflow.ellipsis),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
