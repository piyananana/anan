import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_credit_limit_report_service.dart';
import '../services/ap_vendor_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ap_vendor_group_multi_picker.dart';

class ApCreditLimitReportScreen extends StatefulWidget {
  const ApCreditLimitReportScreen({super.key});

  @override
  State<ApCreditLimitReportScreen> createState() =>
      _ApCreditLimitReportScreenState();
}

class _ApCreditLimitReportScreenState
    extends State<ApCreditLimitReportScreen> {
  final _reportService  = ApCreditLimitReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();
  final _groupService   = ApVendorGroupService();

  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey           = 0;
  bool   _isExporting      = false;
  bool   _isEnglish        = false;

  Company? _company;
  Map<String, String>? _headers;

  List<ApVendorGroup> _vendorGroups = [];

  // Filters
  List<int> _selectedGroupIds = [];
  String? _vendorCodeFrom;
  String? _vendorCodeTo;
  String  _fromNameTh   = '';
  String  _fromNameEn   = '';
  String  _toNameTh     = '';
  String  _toNameEn     = '';
  String  _creditStatus = '';             // '' | 'over' | 'remaining' | 'full' | 'no_limit'
  String  _sortBy       = 'vendor';      // 'vendor' | 'remaining_asc' | 'remaining_desc'

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
    ]);
    _company      = results[0] as Company?;
    _vendorGroups = results[1] as List<ApVendorGroup>;
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getCreditLimitReport(
        vendorGroupIds:  _selectedGroupIds,
        vendorCodeFrom:  _vendorCodeFrom,
        vendorCodeTo:    _vendorCodeTo,
        creditStatus:    _creditStatus,
        sortBy:          _sortBy,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish
                ? 'No data found for the selected conditions'
                : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
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
    final isEnglish    = _isEnglish;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.displayName(isEnglish) ??
        (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Conditions line
    final conditions = <String>[];
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _vendorGroups.firstWhere((g) => g.id == id,
            orElse: () => _vendorGroups.first);
        final gName = isEnglish && g.groupNameEng.isNotEmpty
            ? g.groupNameEng : g.groupNameThai;
        return '${g.groupCode} $gName';
      }).join(', ');
      conditions.add('${isEnglish ? 'Group' : 'กลุ่ม'}: $names');
    }
    if ((_vendorCodeFrom ?? '').isNotEmpty || (_vendorCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final f = (_vendorCodeFrom ?? '').isEmpty ? all : _vendorCodeFrom!;
      final t = (_vendorCodeTo   ?? '').isEmpty ? all : _vendorCodeTo!;
      conditions.add('${isEnglish ? 'Vendor code' : 'รหัสผู้ขาย'}: $f – $t');
    }
    if (_creditStatus.isNotEmpty) {
      conditions.add('${isEnglish ? 'Status' : 'สถานะ'}: ${_statusLabel(_creditStatus, isEnglish)}');
    }
    switch (_sortBy) {
      case 'remaining_asc':
        conditions.add(isEnglish ? 'Sort by remaining limit, low to high' : 'เรียงวงเงินคงเหลือน้อยไปมาก');
        break;
      case 'remaining_desc':
        conditions.add(isEnglish ? 'Sort by remaining limit, high to low' : 'เรียงวงเงินคงเหลือมากไปน้อย');
        break;
      default:
        conditions.add(isEnglish ? 'Sort by vendor code' : 'เรียงรหัสผู้ขาย');
    }
    final conditionLine = conditions.join(' | ');

    // ─── Page header ─────────────────────────────────────────────────────────
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3,
            child: pw.Text(companyName,
                style: const pw.TextStyle(fontSize: 11))),
        pw.Expanded(flex: 6,
            child: pw.Text(isEnglish ? 'AP Credit Limit Report' : 'รายงานวงเงินคงเหลือผู้ขาย',
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
            child: pw.Text(
                '${isEnglish ? 'As of' : 'ณ วันที่'} ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
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
            child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10))),
      ]),
      pw.SizedBox(height: 4),
    ]);

    // ─── Column widths (5 columns, portrait A4) ───────────────────────────────
    // 0: รหัส-ชื่อผู้ขาย  1: วงเงินรวม  2: หนี้คงค้าง
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

    const cHeader = PdfColor(0.82, 0.87, 0.90);
    const cTotal  = PdfColor(0.75, 0.85, 0.88);
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
      decoration: const pw.BoxDecoration(color: cHeader),
      children: [
        hCell(isEnglish ? 'Code – Vendor Name' : 'รหัส – ชื่อผู้ขาย', a: pw.TextAlign.left),
        hCell(isEnglish ? 'Credit Limit' : 'วงเงินรวม'),
        hCell(isEnglish ? 'Outstanding' : 'หนี้คงค้าง'),
        hCell(isEnglish ? 'Remaining Limit' : 'วงเงินคงเหลือ'),
        hCell(isEnglish ? 'Status' : 'สถานะวงเงิน'),
      ],
    );

    final tableRows = <pw.TableRow>[headerRow];

    double grandLimit       = 0;
    double grandOutstanding = 0;
    double grandRemaining   = 0;
    int    totalVendors     = 0;
    int    overCount        = 0;

    for (final row in _reportData) {
      totalVendors++;
      final code        = row['vendor_code']    as String? ?? '';
      final nameTh      = row['vendor_name_th'] as String? ?? '';
      final nameEn      = row['vendor_name_en'] as String?;
      final name        = isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
      final limit       = (row['credit_limit']  as num?)?.toDouble() ?? 0;
      final outstanding = (row['outstanding']   as num?)?.toDouble() ?? 0;
      final remaining   = (row['remaining']     as num?)?.toDouble() ?? 0;
      final status      = row['credit_status']  as String? ?? '';

      grandLimit       += limit;
      grandOutstanding += outstanding;
      grandRemaining   += remaining;
      if (status == 'over') overCount++;

      PdfColor? rowColor;
      if (status == 'over')     rowColor = cRed;
      if (status == 'full')     rowColor = const PdfColor(0.93, 0.98, 0.93);
      if (status == 'no_limit') rowColor = const PdfColor(0.97, 0.97, 0.97);

      final statusStyle = status == 'over' ? tBold(9) : tNormal(9);

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
          dCell(_statusLabel(status, isEnglish), statusStyle, a: pw.TextAlign.center),
        ],
      ));
    }

    // ─── Grand total row ──────────────────────────────────────────────────────
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: cTotal),
      children: [
        dCell(isEnglish
            ? 'Total $totalVendors vendors${overCount > 0 ? ' (over limit: $overCount)' : ''}'
            : 'รวม $totalVendors ผู้ขาย'
                '${overCount > 0 ? ' (เกินวงเงิน $overCount ราย)' : ''}',
            tBold(9)),
        amtCellDash(grandLimit,       tBold(9)),
        amtCellDash(grandOutstanding, tBold(9)),
        amtCellDash(grandRemaining,   tBold(9)),
        dCell('', tBold(9)),
      ],
    ));

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

  static String _statusLabel(String status, bool isEnglish) {
    if (isEnglish) {
      switch (status) {
        case 'over':      return 'Over Limit';
        case 'remaining': return 'Within Limit';
        case 'full':      return 'Full Limit Remaining';
        case 'no_limit':  return 'No Limit Specified';
        default:          return status;
      }
    }
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
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
                    color: Colors.blueGrey[800],
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

                                    // กลุ่มผู้ขาย
                                    ApVendorGroupMultiPicker(
                                      groups: _vendorGroups,
                                      selectedIds: _selectedGroupIds,
                                      onChanged: (v) =>
                                          setState(() => _selectedGroupIds = v),
                                    ),
                                    const SizedBox(height: 12),

                                    // รหัสผู้ขาย ตั้งแต่ / ถึง
                                    _buildVendorCodeField(
                                        label: isEnglish ? 'Vendor Code From' : 'รหัสผู้ขาย ตั้งแต่',
                                        displayText: _fromLabelText(isEnglish),
                                        onPick: () => _pickVendor(isFrom: true),
                                        onClear: () => setState(() {
                                          _vendorCodeFrom = null;
                                          _fromNameTh     = '';
                                          _fromNameEn     = '';
                                        })),
                                    const SizedBox(height: 8),
                                    _buildVendorCodeField(
                                        label: isEnglish ? 'Vendor Code To' : 'รหัสผู้ขาย ถึง',
                                        displayText: _toLabelText(isEnglish),
                                        onPick: () => _pickVendor(isFrom: false),
                                        onClear: () => setState(() {
                                          _vendorCodeTo = null;
                                          _toNameTh     = '';
                                          _toNameEn     = '';
                                        })),

                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // สถานะวงเงิน
                                    DropdownButtonFormField<String>(
                                      value: _creditStatus,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Credit Status' : 'สถานะวงเงิน',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(
                                            value: '',
                                            child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                                        DropdownMenuItem(
                                            value: 'over',
                                            child: Text(isEnglish ? 'Over Limit' : 'เกินวงเงิน')),
                                        DropdownMenuItem(
                                            value: 'remaining',
                                            child: Text(isEnglish ? 'Within Limit' : 'ยังเหลือวงเงิน')),
                                        DropdownMenuItem(
                                            value: 'full',
                                            child: Text(isEnglish ? 'Full Limit Remaining' : 'เหลือเต็มวงเงิน')),
                                        DropdownMenuItem(
                                            value: 'no_limit',
                                            child: Text(isEnglish ? 'No Limit Specified' : 'ไม่ระบุวงเงิน')),
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
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Sort By' : 'จัดเรียงข้อมูล',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'vendor',
                                            child: Text(isEnglish ? 'Vendor Code' : 'รหัสผู้ขาย')),
                                        DropdownMenuItem(
                                            value: 'remaining_asc',
                                            child: Text(isEnglish ? 'Remaining Limit, Low to High' : 'วงเงินคงเหลือ น้อยไปมาก')),
                                        DropdownMenuItem(
                                            value: 'remaining_desc',
                                            child: Text(isEnglish ? 'Remaining Limit, High to Low' : 'วงเงินคงเหลือ มากไปน้อย')),
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
                                  label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey[800],
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
                                  child: Text(isEnglish
                                      ? 'Please select conditions and click Generate Report'
                                      : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat: PdfPageFormat.a4,
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

  Future<void> _pickVendor({required bool isFrom}) async {
    final result = await showDialog<ApVendor>(
      context: context,
      builder: (_) => const _CreditLimitVendorSearchDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        if (isFrom) {
          _vendorCodeFrom = result.vendorCode;
          _fromNameTh     = result.vendorNameTh;
          _fromNameEn     = result.vendorNameEn ?? '';
        } else {
          _vendorCodeTo = result.vendorCode;
          _toNameTh     = result.vendorNameTh;
          _toNameEn     = result.vendorNameEn ?? '';
        }
      });
    }
  }

  // แสดงชื่อผู้ขายตามภาษาที่เลือกปัจจุบัน (ไม่ใช้ label ที่ถูกแช่แข็งไว้ตอนเลือก)
  String _fromLabelText(bool isEnglish) {
    if ((_vendorCodeFrom ?? '').isEmpty) return '';
    final name = isEnglish && _fromNameEn.isNotEmpty ? _fromNameEn : _fromNameTh;
    return '$_vendorCodeFrom  $name';
  }

  String _toLabelText(bool isEnglish) {
    if ((_vendorCodeTo ?? '').isEmpty) return '';
    final name = isEnglish && _toNameEn.isNotEmpty ? _toNameEn : _toNameTh;
    return '$_vendorCodeTo  $name';
  }

  // ─── Excel Export ─────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    _isExporting = true;
    setState(() {});
    try {
      final ex    = Excel.createExcel();
      const sheet = 'CreditLimit';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#82AFBE');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, isEnglish ? 'AP Credit Limit Report' : 'รายงานวงเงินคงเหลือผู้ขาย', bold: true);
      _xlCell(s, 2, 0, '${isEnglish ? 'Printed: ' : 'พิมพ์วันที่: '}$tsLabel');

      final hdrs = isEnglish
          ? ['Code – Vendor Name', 'Credit Limit', 'Outstanding', 'Remaining Limit', 'Status']
          : ['รหัส – ชื่อผู้ขาย', 'วงเงินรวม', 'หนี้คงค้าง', 'วงเงินคงเหลือ', 'สถานะวงเงิน'];
      for (int i = 0; i < hdrs.length; i++) {
        _xlCell(s, 3, i, hdrs[i],
            bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int    row              = 4;
      double grandLimit       = 0;
      double grandOutstanding = 0;
      double grandRemaining   = 0;
      int    totalVendors     = 0;
      int    overCount        = 0;

      for (final r in _reportData) {
        totalVendors++;
        final code        = r['vendor_code']    as String? ?? '';
        final nameTh      = r['vendor_name_th'] as String? ?? '';
        final nameEn      = r['vendor_name_en'] as String?;
        final name        = isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
        final limit       = (r['credit_limit']  as num?)?.toDouble() ?? 0;
        final outstanding = (r['outstanding']   as num?)?.toDouble() ?? 0;
        final remaining   = (r['remaining']     as num?)?.toDouble() ?? 0;
        final status      = r['credit_status']  as String? ?? '';

        grandLimit       += limit;
        grandOutstanding += outstanding;
        grandRemaining   += remaining;
        if (status == 'over') overCount++;

        _xlCell(s, row, 0, '$code  $name');
        _xlCell(s, row, 1, limit,       align: HorizontalAlign.Right);
        _xlCell(s, row, 2, outstanding, align: HorizontalAlign.Right);
        _xlCell(s, row, 3, limit <= 0 ? '-' : remaining,
            align: HorizontalAlign.Right);
        _xlCell(s, row, 4, _statusLabel(status, isEnglish), align: HorizontalAlign.Center);
        row++;
      }

      final totalLabel = isEnglish
          ? 'Total $totalVendors vendors${overCount > 0 ? ' (over limit: $overCount)' : ''}'
          : 'รวม $totalVendors ผู้ขาย'
              '${overCount > 0 ? ' (เกินวงเงิน $overCount ราย)' : ''}';
      _xlCell(s, row, 0, totalLabel,        bg: totBg, bold: true);
      _xlCell(s, row, 1, grandLimit,        bg: totBg, bold: true,
          align: HorizontalAlign.Right);
      _xlCell(s, row, 2, grandOutstanding,  bg: totBg, bold: true,
          align: HorizontalAlign.Right);
      _xlCell(s, row, 3, grandRemaining,    bg: totBg, bold: true,
          align: HorizontalAlign.Right);
      _xlCell(s, row, 4, '',               bg: totBg);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'AP_Credit_Limit_Report' : 'รายงานวงเงินคงเหลือผู้ขาย';
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

  Widget _buildVendorCodeField({
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
                  child: Icon(Icons.search, size: 18,
                      color: Colors.blueGrey[800]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Vendor search dialog ──────────────────────────────────────────────────────

class _CreditLimitVendorSearchDialog extends StatefulWidget {
  const _CreditLimitVendorSearchDialog();

  @override
  State<_CreditLimitVendorSearchDialog> createState() =>
      _CreditLimitVendorSearchDialogState();
}

class _CreditLimitVendorSearchDialogState
    extends State<_CreditLimitVendorSearchDialog> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _svc    = ApVendorService();
  List<ApVendor> _list    = [];
  bool           _loading = false;

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
              color: Colors.blueGrey[800],
              child: Text(isEnglish ? 'Search Vendor' : 'ค้นหาผู้ขาย',
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
                    hintText: isEnglish ? 'Search by vendor code or name' : 'ค้นหาจากรหัสหรือชื่อผู้ขาย',
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text(isEnglish ? 'Vendor Name' : 'ชื่อผู้ขาย',
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
                          child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                              style: const TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: _scroll,
                          itemCount: _list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 12),
                          itemBuilder: (ctx, i) {
                            final v = _list[i];
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, v),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(children: [
                                  SizedBox(width: 100,
                                      child: Text(v.vendorCode,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500))),
                                  Expanded(
                                      child: Text(
                                          isEnglish && (v.vendorNameEn ?? '').isNotEmpty
                                              ? v.vendorNameEn!
                                              : v.vendorNameTh,
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
