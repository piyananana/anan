import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_transaction_report_service.dart';
import '../services/ap_vendor_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ap_vendor_group_multi_picker.dart';

// ─── sys_doc_type → column index mapping ──────────────────────────────────────
// 0=PI(10)  1=CN(30)  2=DN(50)
// 3=จ่ายมัดจำ(60)  4=คืนมัดจำ(65)  5=ชำระ(80)
int? _apColIdx(String sdt) {
  switch (sdt) {
    case '10': return 0;
    case '30': return 1;
    case '50': return 2;
    case '60': return 3;
    case '65': return 4;
    case '80': return 5;
    default:   return null;
  }
}

class ApTransactionReportScreen extends StatefulWidget {
  const ApTransactionReportScreen({super.key});

  @override
  State<ApTransactionReportScreen> createState() =>
      _ApTransactionReportScreenState();
}

class _ApTransactionReportScreenState
    extends State<ApTransactionReportScreen> {
  final _reportService  = ApTransactionReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();
  final _groupService   = ApVendorGroupService();
  final _branchService  = BranchService();
  final _vendorService  = ApVendorService();

  bool   _isEnglish        = false;
  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;

  Company? _company;
  Map<String, String>? _headers;

  List<Branch>       _branches     = [];
  List<ApVendorGroup> _vendorGroups = [];

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  int?    _selectedBranchId;
  List<int> _selectedGroupIds = [];
  String? _vendorCodeFrom;
  String? _vendorCodeTo;
  String  _fromLabel  = '';
  String  _toLabel    = '';
  String  _sortBy     = 'vendor';
  bool    _showDetail  = false;
  bool    _isExporting = false;

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
    _company      = results[0] as Company?;
    _branches     = (results[1] as List<Branch>).where((b) => b.isActive).toList();
    _vendorGroups = results[2] as List<ApVendorGroup>;
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getTransactionReport(
        dateFrom:       DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:         DateFormat('yyyy-MM-dd').format(_dateTo),
        branchId:       _selectedBranchId,
        vendorGroupIds: _selectedGroupIds,
        vendorCodeFrom: _vendorCodeFrom,
        vendorCodeTo:   _vendorCodeTo,
        sortBy:         _sortBy,
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

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish       = _isEnglish;
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
        '${isEnglish ? 'Date range' : 'ช่วงวันที่'} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere((b) => b.id == _selectedBranchId,
          orElse: () => _branches.first);
      conditions.add('${isEnglish ? 'Branch' : 'สาขา'}: ${b.branchCode} ${isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai}');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _vendorGroups.firstWhere((g) => g.id == id,
            orElse: () => _vendorGroups.first);
        return '${g.groupCode} ${isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai}';
      }).join(', ');
      conditions.add('${isEnglish ? 'Group' : 'กลุ่ม'}: $names');
    }
    if ((_vendorCodeFrom ?? '').isNotEmpty || (_vendorCodeTo ?? '').isNotEmpty) {
      final allLabel = isEnglish ? '(All)' : '(ทั้งหมด)';
      conditions.add(
          '${isEnglish ? 'Vendor code' : 'รหัสผู้ขาย'}: ${_vendorCodeFrom?.isEmpty ?? true ? allLabel : _vendorCodeFrom!}'
          ' – ${_vendorCodeTo?.isEmpty ?? true ? allLabel : _vendorCodeTo!}');
    }
    conditions.add(_sortBy == 'doc_type'
        ? (isEnglish ? 'Sorted by document type' : 'เรียงตามประเภทเอกสาร')
        : (isEnglish ? 'Sorted by vendor code' : 'เรียงตามรหัสผู้ขาย'));
    if (_showDetail) conditions.add(isEnglish ? 'Show details' : 'แสดงรายละเอียด');

    final conditionLine = conditions.join(' | ');
    final showDetail    = _showDetail;

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6, child: pw.Text(isEnglish ? 'AP Transaction Report' : 'รายงานธุรกรรมเจ้าหนี้',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.Text(dateRangeLine, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.Text('* $conditionLine', style: const pw.TextStyle(fontSize: 9))),
        pw.Expanded(flex: 3, child: pw.Text(
            isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 4),
    ]);

    // 0: รหัส-ชื่อผู้ขาย  1: PI(10)  2: CN(30)  3: DN(50)
    // 4: จ่ายมัดจำ(60)    5: คืนมัดจำ(65)  6: ชำระ(80)
    const colW = {
      0: pw.FlexColumnWidth(13),
      1: pw.FlexColumnWidth(7),
      2: pw.FlexColumnWidth(7),
      3: pw.FlexColumnWidth(7),
      4: pw.FlexColumnWidth(6),
      5: pw.FlexColumnWidth(6),
      6: pw.FlexColumnWidth(7),
    };

    final fmt = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tNormal(double fs) => pw.TextStyle(font: font,      fontSize: fs);
    pw.TextStyle tBold(double fs)   => pw.TextStyle(font: fontBold,  fontSize: fs);
    pw.TextStyle tItalic(double fs) => pw.TextStyle(font: fontItalic, fontSize: fs);

    const cGreen  = PdfColor(0.82, 0.87, 0.90);
    const cYellow = PdfColor(0.95, 0.95, 0.85);
    const cBlue   = PdfColor(0.85, 0.91, 0.97);
    const cGray   = PdfColor(0.96, 0.96, 0.96);

    pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
        pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: tBold(8.5), textAlign: a));

    pw.Widget dCell(String t, pw.TextStyle s, {pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(t, style: s, textAlign: a));

    pw.Widget amtCell(double v, pw.TextStyle s, {bool dash = false}) =>
        pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(
                v == 0 && dash ? '–' : (v == 0 ? '' : fmt.format(v)),
                style: s, textAlign: pw.TextAlign.right));

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: cGreen),
      children: [
        hCell(isEnglish ? 'Code – Vendor Name' : 'รหัส – ชื่อผู้ขาย', a: pw.TextAlign.left),
        hCell(isEnglish ? 'PI' : 'ใบสั่งซื้อ/PI'),
        hCell(isEnglish ? 'CN' : 'ลดหนี้/CN'),
        hCell(isEnglish ? 'DN' : 'เพิ่มหนี้/DN'),
        hCell(isEnglish ? 'Advance' : 'จ่ายมัดจำ'),
        hCell(isEnglish ? 'Advance Return' : 'คืนมัดจำ'),
        hCell(isEnglish ? 'Payment' : 'ชำระ'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    final grandAmts   = List<double>.filled(6, 0.0);
    final grandCounts = List<int>.filled(6, 0);
    int totalVendors = 0;

    for (final vend in _reportData) {
      totalVendors++;
      final code = vend['vendor_code']    as String? ?? '';
      final nameTh = vend['vendor_name_th'] as String? ?? '';
      final nameEn = vend['vendor_name_en'] as String?;
      final name = isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
      final amts = [
        (vend['pi_amount']  as num?)?.toDouble() ?? 0,
        (vend['cn_amount']  as num?)?.toDouble() ?? 0,
        (vend['dn_amount']  as num?)?.toDouble() ?? 0,
        (vend['adv_amount'] as num?)?.toDouble() ?? 0,
        (vend['ret_amount'] as num?)?.toDouble() ?? 0,
        (vend['pay_amount'] as num?)?.toDouble() ?? 0,
      ];

      for (int i = 0; i < 6; i++) grandAmts[i] += amts[i];

      tableRows.add(pw.TableRow(
        decoration: showDetail ? const pw.BoxDecoration(color: cBlue) : null,
        children: [
          dCell('$code  $name', showDetail ? tBold(9) : tNormal(9)),
          ...List.generate(6, (i) => amtCell(amts[i], showDetail ? tBold(9) : tNormal(9))),
        ],
      ));

      if (!showDetail) continue;

      final txns = (vend['transactions'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final t in txns) {
        final sdt  = t['sys_doc_type'] as String? ?? '';
        final ci   = _apColIdx(sdt);
        final tAmt = (t['total_amount_lc'] as num?)?.toDouble() ?? 0;
        final cols = List<double>.filled(6, 0.0);
        if (ci != null) { cols[ci] = tAmt; grandCounts[ci]++; }

        final docDate = _fmtDate(t['doc_date'] as String?);
        final refNo   = t['ref_doc_no'] as String? ?? '';
        final label   =
            '${t['doc_name_thai'] ?? ''}  ${t['doc_no'] ?? ''}  $docDate'
            '${refNo.isNotEmpty ? '  $refNo' : ''}';

        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: cGray),
          children: [
            dCell('     $label', tItalic(8.5)),
            ...List.generate(6, (i) => amtCell(cols[i], tItalic(8.5))),
          ],
        ));
      }
    }

    if (showDetail) {
      final totalDocs = grandCounts.fold(0, (s, c) => s + c);
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: cYellow),
        children: [
          dCell(
              isEnglish
                  ? 'Total $totalVendors vendors / $totalDocs documents'
                  : 'รวม $totalVendors ผู้ขาย / $totalDocs เอกสาร',
              tBold(9)),
          ...List.generate(6, (i) => grandCounts[i] > 0
              ? dCell(
                  isEnglish ? '${grandCounts[i]} docs' : '${grandCounts[i]} ใบ',
                  tBold(9), a: pw.TextAlign.right)
              : dCell('', tBold(9))),
        ],
      ));
    }

    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor(0.75, 0.85, 0.88)),
      children: [
        dCell(
            showDetail
                ? (isEnglish ? 'Total amount – all types' : 'ยอดเงินรวมทุกประเภท')
                : (isEnglish ? 'Total $totalVendors vendors' : 'รวม $totalVendors ผู้ขาย'),
            tBold(9)),
        ...List.generate(6, (i) => amtCell(grandAmts[i], tBold(9), dash: true)),
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
      return DateFormat('dd/MM/yyyy').format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blueGrey[800],
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
                  (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // toggle
                  Container(
                    width: 36,
                    color: Colors.blueGrey[800],
                    child: IconButton(
                      icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded
                          ? (isEnglish ? 'Collapse Filter' : 'ย่อเงื่อนไข')
                          : (isEnglish ? 'Expand Filter' : 'ขยายเงื่อนไข'),
                      onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                    ),
                  ),
                  // filter panel
                  AnimatedContainer(
                    duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                    width: _isFilterExpanded ? _filterPanelWidth : 0.0,
                    child: ClipRect(
                      child: OverflowBox(
                        maxWidth: _filterPanelWidth, minWidth: _filterPanelWidth,
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 16),

                                    _buildDateField(
                                        label: isEnglish ? 'Document Date From' : 'วันที่เอกสาร ตั้งแต่',
                                        date: _dateFrom, onPick: (d) => setState(() => _dateFrom = d)),
                                    const SizedBox(height: 12),
                                    _buildDateField(
                                        label: isEnglish ? 'Document Date To' : 'วันที่เอกสาร ถึง',
                                        date: _dateTo, onPick: (d) => setState(() => _dateTo = d)),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

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
                                            child: Text(isEnglish ? '— All Branches —' : '— ทุกสาขา —')),
                                        ..._branches.map((b) => DropdownMenuItem<int?>(
                                            value: b.id,
                                            child: Text(
                                                '${b.branchCode}  ${isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai}',
                                                overflow: TextOverflow.ellipsis))),
                                      ],
                                      onChanged: (v) => setState(() => _selectedBranchId = v),
                                    ),
                                    const SizedBox(height: 12),

                                    ApVendorGroupMultiPicker(
                                      groups: _vendorGroups,
                                      selectedIds: _selectedGroupIds,
                                      onChanged: (v) => setState(() => _selectedGroupIds = v),
                                    ),
                                    const SizedBox(height: 12),

                                    _buildVendorCodeField(
                                        label: isEnglish ? 'Vendor Code From' : 'รหัสผู้ขาย ตั้งแต่',
                                        displayText: _fromLabel,
                                        onPick: () => _pickVendor(isFrom: true),
                                        onClear: () => setState(() { _vendorCodeFrom = null; _fromLabel = ''; })),
                                    const SizedBox(height: 8),
                                    _buildVendorCodeField(
                                        label: isEnglish ? 'Vendor Code To' : 'รหัสผู้ขาย ถึง',
                                        displayText: _toLabel,
                                        onPick: () => _pickVendor(isFrom: false),
                                        onClear: () => setState(() { _vendorCodeTo = null; _toLabel = ''; })),

                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    DropdownButtonFormField<String>(
                                      value: _sortBy,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Sort By' : 'จัดเรียงข้อมูล',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(value: 'vendor', child: Text(isEnglish ? 'Vendor Code' : 'รหัสผู้ขาย')),
                                        DropdownMenuItem(value: 'doc_type', child: Text(isEnglish ? 'Document Type' : 'ประเภทเอกสาร')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) { setState(() => _sortBy = v); _onSettingChanged(); }
                                      },
                                    ),
                                    const SizedBox(height: 8),

                                    Row(children: [
                                      Expanded(child: Text(isEnglish ? 'Show Details' : 'แสดงรายละเอียด', style: const TextStyle(fontSize: 13))),
                                      Switch(
                                        value: _showDetail,
                                        activeColor: Colors.blueGrey[800],
                                        onChanged: (v) { setState(() => _showDetail = v); _onSettingChanged(); },
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SizedBox(
                                width: double.infinity, height: 50,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
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
                        onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                        onHorizontalDragUpdate: (d) => setState(() {
                          _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth);
                        }),
                        onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
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
                              ? Center(child: Text(isEnglish
                                  ? 'Select conditions and click Generate Report'
                                  : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat: PdfPageFormat.a4.landscape,
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

  Widget _buildDateField({required String label, required DateTime date, required void Function(DateTime) onPick}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.calendar_today, size: 16)),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }

  Future<void> _pickVendor({required bool isFrom}) async {
    final result = await showDialog<ApVendor>(
      context: context,
      builder: (_) => _TxnRptVendorSearchDialog(vendorService: _vendorService),
    );
    if (result != null && mounted) {
      final isEnglish = _isEnglish;
      setState(() {
        final name = isEnglish && (result.vendorNameEn ?? '').isNotEmpty
            ? result.vendorNameEn!
            : result.vendorNameTh;
        final label = '${result.vendorCode}  $name';
        if (isFrom) { _vendorCodeFrom = result.vendorCode; _fromLabel = label; }
        else        { _vendorCodeTo   = result.vendorCode; _toLabel   = label; }
      });
    }
  }

  Widget _buildVendorCodeField({required String label, required String displayText, required VoidCallback onPick, required VoidCallback onClear}) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onPick, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.search, size: 18, color: Colors.blueGrey[800]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(hasValue ? displayText : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
            style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'Transaction';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, isEnglish ? 'AP Transaction Report' : 'รายงานธุรกรรมเจ้าหนี้', bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? 'Date range' : 'ช่วงวันที่'}: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  ${isEnglish ? 'Printed' : 'พิมพ์'}: $tsLabel');

      final hdrs = isEnglish
          ? ['Code – Vendor Name', 'PI', 'CN', 'DN', 'Advance', 'Advance Return', 'Payment']
          : ['รหัส – ชื่อผู้ขาย', 'ใบสั่งซื้อ/PI', 'ลดหนี้/CN', 'เพิ่มหนี้/DN', 'จ่ายมัดจำ', 'คืนมัดจำ', 'ชำระ'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      final grandAmts   = List<double>.filled(6, 0.0);
      final grandCounts = List<int>.filled(6, 0);
      int totalVendors = 0;

      for (final vend in _reportData) {
        totalVendors++;
        final code = vend['vendor_code']    as String? ?? '';
        final nameTh = vend['vendor_name_th'] as String? ?? '';
        final nameEn = vend['vendor_name_en'] as String?;
        final name = isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
        final amts = [
          (vend['pi_amount']  as num?)?.toDouble() ?? 0,
          (vend['cn_amount']  as num?)?.toDouble() ?? 0,
          (vend['dn_amount']  as num?)?.toDouble() ?? 0,
          (vend['adv_amount'] as num?)?.toDouble() ?? 0,
          (vend['ret_amount'] as num?)?.toDouble() ?? 0,
          (vend['pay_amount'] as num?)?.toDouble() ?? 0,
        ];
        for (int i = 0; i < 6; i++) grandAmts[i] += amts[i];

        _xlCell(s, row, 0, '$code  $name', bold: _showDetail);
        for (int i = 0; i < 6; i++) {
          _xlCell(s, row, i + 1, amts[i], align: HorizontalAlign.Right, bold: _showDetail);
        }
        row++;

        if (_showDetail) {
          final txns = (vend['transactions'] as List? ?? []).cast<Map<String, dynamic>>();
          for (final t in txns) {
            final sdt  = t['sys_doc_type'] as String? ?? '';
            final ci   = _apColIdx(sdt);
            final tAmt = (t['total_amount_lc'] as num?)?.toDouble() ?? 0;
            final cols = List<double>.filled(6, 0.0);
            if (ci != null) { cols[ci] = tAmt; grandCounts[ci]++; }
            final docDate = _fmtDate(t['doc_date'] as String?);
            final refNo   = t['ref_doc_no'] as String? ?? '';
            final label   = '   ${t['doc_name_thai'] ?? ''}  ${t['doc_no'] ?? ''}  $docDate'
                '${refNo.isNotEmpty ? '  $refNo' : ''}';
            _xlCell(s, row, 0, label, bg: detBg);
            for (int i = 0; i < 6; i++) {
              _xlCell(s, row, i + 1, cols[i], bg: detBg, align: HorizontalAlign.Right);
            }
            row++;
          }
        }
      }

      if (_showDetail) {
        final totalDocs = grandCounts.fold(0, (a, b) => a + b);
        _xlCell(s, row, 0,
            isEnglish
                ? 'Total $totalVendors vendors / $totalDocs documents'
                : 'รวม $totalVendors ผู้ขาย / $totalDocs เอกสาร',
            bg: totBg, bold: true);
        for (int i = 0; i < 6; i++) {
          _xlCell(s, row, i + 1,
              grandCounts[i] > 0
                  ? (isEnglish ? '${grandCounts[i]} docs' : '${grandCounts[i]} ใบ')
                  : '',
              bg: totBg, bold: true, align: HorizontalAlign.Right);
        }
        row++;
      }

      _xlCell(s, row, 0,
          _showDetail
              ? (isEnglish ? 'Total amount – all types' : 'ยอดเงินรวมทุกประเภท')
              : (isEnglish ? 'Total $totalVendors vendors' : 'รวม $totalVendors ผู้ขาย'),
          bg: totBg, bold: true);
      for (int i = 0; i < 6; i++) {
        _xlCell(s, row, i + 1, grandAmts[i], bg: totBg, bold: true, align: HorizontalAlign.Right);
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'AP_Transaction_Report' : 'รายงานธุรกรรมเจ้าหนี้';
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${title}_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }
}

class _TxnRptVendorSearchDialog extends StatefulWidget {
  final ApVendorService vendorService;
  const _TxnRptVendorSearchDialog({required this.vendorService});

  @override
  State<_TxnRptVendorSearchDialog> createState() => _TxnRptVendorSearchDialogState();
}

class _TxnRptVendorSearchDialogState extends State<_TxnRptVendorSearchDialog> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  List<ApVendor> _list    = [];
  bool           _loading = false;

  @override
  void initState() { super.initState(); _search(''); }

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await widget.vendorService.fetchRows(search: q.trim().isEmpty ? null : q.trim());
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
    final isEnglish = l.isEnglish;
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blueGrey[800],
            child: Text(isEnglish ? 'Search Vendor' : 'ค้นหาผู้ขาย',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl, autofocus: true,
              decoration: InputDecoration(
                  hintText: isEnglish ? 'Search by vendor code or name' : 'ค้นหาจากรหัสหรือชื่อผู้ขาย',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: const OutlineInputBorder(), isDense: true),
              onChanged: _search,
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              SizedBox(width: 100, child: Text(isEnglish ? 'Code' : 'รหัส', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text(isEnglish ? 'Vendor Name' : 'ชื่อผู้ขาย', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: _scroll,
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 12),
                        itemBuilder: (ctx, i) {
                          final v = _list[i];
                          final name = isEnglish && (v.vendorNameEn ?? '').isNotEmpty
                              ? v.vendorNameEn!
                              : v.vendorNameTh;
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, v),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 100, child: Text(v.vendorCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Expanded(child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          );
                        }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
            ]),
          ),
        ]),
      ),
    );
  }
}
