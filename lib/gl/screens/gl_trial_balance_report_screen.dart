import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:anan/sa/models/sa_company.dart';
import 'package:anan/sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../../gl/services/gl_trial_balance_report_service.dart';

// Master Data Services
import '../../cd/services/cd_branch_service.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';

class TrialBalanceReportScreen extends StatefulWidget {
  const TrialBalanceReportScreen({super.key});

  @override
  State<TrialBalanceReportScreen> createState() =>
      _TrialBalanceReportScreenState();
}

class _TrialBalanceReportScreenState extends State<TrialBalanceReportScreen> {
  // Services
  final CompanyService _companyService = CompanyService();
  final PeriodService _periodService = PeriodService();
  final TrialBalanceReportService _reportService = TrialBalanceReportService();
  final BranchService _branchService = BranchService();
  final GlDimensionService _dimService = GlDimensionService();
  final AuthService authService = AuthService();
  late Map<String, String> headers;

  // Data
  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<Map<String, dynamic>> _reportData = [];
  List<dynamic> _branchList = [];
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;

  // Master Data Maps
  Map<int, String> _branchMap = {};
  List<GlDimensionType> _activeDimTypes = [];

  // Hierarchy Helper
  Map<int, int> _accountLevels = {};

  // Filter States
  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;

  bool _showDimensions = false;
  bool _hideZero = true;
  bool _showHierarchy = false;
  bool _showHeaderTotals = false;
  bool _showOnlyHeaders = false;

  bool _isLoading = false;
  bool _isExporting = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 350.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
    _allowedBranches = authService.allowedBranches;
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);

    headers = await authService.getAuthHeader();
    _company = await _companyService.fetchCompany();

    try {
      _fiscalYears = await _periodService.fetchActiveFiscalYears();
      if (_fiscalYears.isNotEmpty) {
        final now = DateTime.now();
        try {
          _selectedYear = _fiscalYears.firstWhere((fy) =>
              now.isAfter(fy.yearStartDate) && now.isBefore(fy.yearEndDate));
        } catch (_) {
          _selectedYear = _fiscalYears.first;
        }
        await _loadPeriods(_selectedYear!.id);
      }

      final branches = await _branchService.fetchRows();
      _branchList = branches
          .map((b) => {'id': b.id, 'code': b.branchCode, 'name': b.branchNameThai})
          .toList()
        ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
      _branchMap = {for (var e in branches) e.id!: e.branchCode};

      // โหลด Dimension Types (แสดง _showDimensions เฉพาะเมื่อมีการตั้งค่า)
      _activeDimTypes = await _dimService.fetchActiveTypes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading master: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPeriods(int yearId) async {
    final ps = await _periodService.fetchPostingPeriodsByFiscalYearId(yearId);
    setState(() {
      _periods = ps;
      _selectedPeriod = null;
    });
  }

  Future<void> _generateReport() async {
    if (_selectedYear == null) return;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final data = await _reportService.getTrialBalance(
        fiscalYearId: _selectedYear!.id,
        periodId: _selectedPeriod?.id,
        showDimensions: _showDimensions,
        hideZero: _hideZero,
        showHeaderTotals: _showHeaderTotals,
        branchId: _selectedBranchId,
      );

      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลในปีบัญชีที่เลือก')),
          );
        }
        return;
      }

      _calculateAccountLevels(data);

      setState(() {
        _reportData = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateAccountLevels(List<Map<String, dynamic>> data) {
    _accountLevels.clear();
    Map<int, int?> parentMap = {};
    for (var row in data) {
      if (row['account_id'] != null) {
        parentMap[row['account_id']] = row['parent_id'];
      }
    }

    for (var row in data) {
      int id = row['account_id'];
      int level = 0;
      int? currentId = id;
      int safeguard = 0;
      while (parentMap[currentId] != null && safeguard < 10) {
        level++;
        currentId = parentMap[currentId];
        safeguard++;
      }
      _accountLevels[id] = level;
    }
  }

  // --- Excel Export ---

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'TrialBalance');
      final s = ex['TrialBalance'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      final _periodLabel = _selectedPeriod != null
          ? 'งวด ${_selectedPeriod!.periodNumber} - ${_selectedPeriod!.periodName}'
          : 'ปี ${_selectedYear?.fyCode ?? ''}';
      final _ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'งบทดลอง (Trial Balance)', bold: true);
      _xlCell(s, 2, 0, '$_periodLabel  |  พิมพ์: $_ts');

      int r = 3;
      _xlCell(s, r, 0, 'รหัส/ชื่อบัญชี', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, 'ยอดยกมา-Dr', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 2, 'ยอดยกมา-Cr', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 3, 'ยอดในงวด-Dr', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 4, 'ยอดในงวด-Cr', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 5, 'ยอดยกไป-Dr', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 6, 'ยอดยกไป-Cr', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      r++;

      double sumBegDr = 0, sumBegCr = 0;
      double sumMvmtDr = 0, sumMvmtCr = 0;
      double sumEndDr = 0, sumEndCr = 0;

      for (final row in _reportData) {
        final isHeader = row['is_header'] == true;
        final code = row['account_code']?.toString() ?? '';
        final name = row['account_name_thai']?.toString() ?? '';
        final begDr  = double.tryParse(row['beg_dr'].toString())  ?? 0;
        final begCr  = double.tryParse(row['beg_cr'].toString())  ?? 0;
        final mvmtDr = double.tryParse(row['mvmt_dr'].toString()) ?? 0;
        final mvmtCr = double.tryParse(row['mvmt_cr'].toString()) ?? 0;
        final endDr  = double.tryParse(row['end_dr'].toString())  ?? 0;
        final endCr  = double.tryParse(row['end_cr'].toString())  ?? 0;

        if (!isHeader) {
          sumBegDr += begDr; sumBegCr += begCr;
          sumMvmtDr += mvmtDr; sumMvmtCr += mvmtCr;
          sumEndDr += endDr; sumEndCr += endCr;
        }

        _xlCell(s, r, 0, '$code $name', bold: isHeader);
        _xlCell(s, r, 1, begDr  == 0 ? TextCellValue('') : DoubleCellValue(begDr),  align: HorizontalAlign.Right, bold: isHeader);
        _xlCell(s, r, 2, begCr  == 0 ? TextCellValue('') : DoubleCellValue(begCr),  align: HorizontalAlign.Right, bold: isHeader);
        _xlCell(s, r, 3, mvmtDr == 0 ? TextCellValue('') : DoubleCellValue(mvmtDr), align: HorizontalAlign.Right, bold: isHeader);
        _xlCell(s, r, 4, mvmtCr == 0 ? TextCellValue('') : DoubleCellValue(mvmtCr), align: HorizontalAlign.Right, bold: isHeader);
        _xlCell(s, r, 5, endDr  == 0 ? TextCellValue('') : DoubleCellValue(endDr),  align: HorizontalAlign.Right, bold: isHeader);
        _xlCell(s, r, 6, endCr  == 0 ? TextCellValue('') : DoubleCellValue(endCr),  align: HorizontalAlign.Right, bold: isHeader);
        r++;
      }

      // Grand total row
      _xlCell(s, r, 0, 'รวมทั้งสิ้น', bg: totBg, bold: true);
      _xlCell(s, r, 1, DoubleCellValue(sumBegDr),  bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 2, DoubleCellValue(sumBegCr),  bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 3, DoubleCellValue(sumMvmtDr), bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 4, DoubleCellValue(sumMvmtCr), bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 5, DoubleCellValue(sumEndDr),  bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 6, DoubleCellValue(sumEndCr),  bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'งบทดลอง_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue ? v : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // --- PDF Generation Logic ---
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    String companyName =
        _company != null ? _company!.thaiName : "(ไม่ระบุชื่อบริษัท)";
    final String userName = headers['UserName'] ?? "(ไม่ระบุชื่อ)";
    final String printDateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String periodLine = _selectedPeriod != null
        ? "วันที่ ${_selectedPeriod!.periodEndDate.day} ${_selectedPeriod!.periodName} ${_selectedYear!.fyCode}"
        : "ปี ${_selectedYear?.fyCode}";

    List<String> conditions = [];
    if (!_showDimensions) {
      conditions.add("ไม่แสดงสาขา/มิติ");
    }
    if (_hideZero) {
      conditions.add("ซ่อนบัญชีที่ยอดเป็นศูนย์");
    }
    if (_showHierarchy) {
      conditions.add("แสดงแบบโครงสร้างบัญชี");
    } else {
      conditions.add("แสดงเฉพาะบัญชีที่ใช้ทำรายการ");
    } 
    if (_showHierarchy && _showOnlyHeaders) conditions.add("เฉพาะหัวบัญชี");
    if (_showHierarchy && _showHeaderTotals) conditions.add("ยอดรวมหัวบัญชี");

    String conditionLine = "* ${conditions.join(", ")}";

    final fmt = NumberFormat("#,##0.00", "en_US");
    String formatNum(dynamic val) {
      double v = double.tryParse(val.toString()) ?? 0.0;
      if (v == 0) return "";
      return fmt.format(v);
    }

    // 1. Prepare Display Data (Apply Filters)
    List<Map<String, dynamic>> displayData = [];

    if (_showHierarchy) {
      if (_showOnlyHeaders) {
        displayData =
            _reportData.where((row) => row['is_header'] == true).toList();
      } else {
        displayData = List.from(_reportData);
      }
    } else {
      // Flat (Details only)
      displayData =
          _reportData.where((row) => row['is_header'] == false).toList();
    }

    // 2. Apply Hide Zero Filter
    if (_hideZero) {
      displayData = displayData.where((row) {
        double begDr = double.tryParse(row['beg_dr'].toString()) ?? 0;
        double begCr = double.tryParse(row['beg_cr'].toString()) ?? 0;
        double mvmtDr = double.tryParse(row['mvmt_dr'].toString()) ?? 0;
        double mvmtCr = double.tryParse(row['mvmt_cr'].toString()) ?? 0;
        double endDr = double.tryParse(row['end_dr'].toString()) ?? 0;
        double endCr = double.tryParse(row['end_cr'].toString()) ?? 0;

        bool isZero = (begDr.abs() < 0.001 &&
            begCr.abs() < 0.001 &&
            mvmtDr.abs() < 0.001 &&
            mvmtCr.abs() < 0.001 &&
            endDr.abs() < 0.001 &&
            endCr.abs() < 0.001);

        return !isZero;
      }).toList();
    }

    // Calculate Grand Total
    double sumBegDr = 0, sumBegCr = 0;
    double sumMvmtDr = 0, sumMvmtCr = 0;
    double sumEndDr = 0, sumEndCr = 0;

    for (var row in _reportData) {
      if (row['is_header'] == false) {
        sumBegDr += double.tryParse(row['beg_dr'].toString()) ?? 0;
        sumBegCr += double.tryParse(row['beg_cr'].toString()) ?? 0;
        sumMvmtDr += double.tryParse(row['mvmt_dr'].toString()) ?? 0;
        sumMvmtCr += double.tryParse(row['mvmt_cr'].toString()) ?? 0;
        sumEndDr += double.tryParse(row['end_dr'].toString()) ?? 0;
        sumEndCr += double.tryParse(row['end_cr'].toString()) ?? 0;
      }
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold, italic: fontItalic),
      margin: const pw.EdgeInsets.all(20),
      header: (context) {
        return pw.Column(
          children: [
            // Top Details
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(companyName,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text("งบทดลอง (Trial Balance)",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                        "หน้า ${context.pageNumber}/${context.pagesCount}",
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12)))
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child:
                        pw.Text("", style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text(periodLine,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text("พิมพ์โดย $userName",
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12)))
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 10,
                    child: pw.Text(conditionLine,
                        textAlign: pw.TextAlign.left,
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text("พิมพ์เมื่อ $printDateStr",
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12)))
              ],
            ),
            pw.SizedBox(height: 4),

            // Table Header 
            pw.Table(columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(3),
            }, children: [
              pw.TableRow(children: [
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("รหัส/ชื่อบัญชี",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("ยอดยกมา",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("ยอดในงวด",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                                top: pw.BorderSide(color: PdfColors.grey800),
                                left: pw.BorderSide(color: PdfColors.grey800),
                                right:
                                    pw.BorderSide(color: PdfColors.grey800))),
                        alignment: pw.Alignment.center,
                        child: pw.Text("ยอดยกไป",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
              ]),
            ]),

            // Table Sub-Header (Dr/Cr)
            pw.Table(columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(1.5),
            }, children: [
              pw.TableRow(children: [
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          left: pw.BorderSide(color: PdfColors.grey800),
                          bottom: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                            _showDimensions ? "สาขา/มิติ" : "-",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                          bottom: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("เดบิต",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                          bottom: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("เครดิต",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                          bottom: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("เดบิต",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                          bottom: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("เครดิต",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey800),
                          left: pw.BorderSide(color: PdfColors.grey800),
                          bottom: pw.BorderSide(color: PdfColors.grey800),
                        )),
                        alignment: pw.Alignment.center,
                        child: pw.Text("เดบิต",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
                pw.Expanded(
                    child: pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                                top: pw.BorderSide(color: PdfColors.grey800),
                                left: pw.BorderSide(color: PdfColors.grey800),
                                bottom: pw.BorderSide(color: PdfColors.grey800),
                                right:
                                    pw.BorderSide(color: PdfColors.grey800))),
                        alignment: pw.Alignment.center,
                        child: pw.Text("เครดิต",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12)))),
              ]),
            ]),
            pw.SizedBox(height: 8),
          ],
        );
      },

      footer: (context) {
        return pw.Column(children: [
          pw.Divider(thickness: 0.5),
        ]);
      },

      build: (context) {
        // Prepare list of table rows (Data rows)
        List<pw.Widget> rows = [];
        
        rows.addAll(displayData.map((row) {
          final isHeader = row['is_header'] == true;
          final showValue = !isHeader || _showHeaderTotals || _showOnlyHeaders;
          final textStyle = isHeader
              ? pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)
              : const pw.TextStyle(fontSize: 12);
          final int level = _accountLevels[row['account_id']] ?? 0;
          final double indent = level * 12.0;

          final mainRow = pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.only(
                      left: indent, right: 8, top: 4, bottom: 4),
                  child: pw.Text(
                      "${row['account_code']} ${row['account_name_thai']}",
                      style: textStyle),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                            showValue ? formatNum(row['beg_dr']) : "",
                            style: textStyle))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                            showValue ? formatNum(row['beg_cr']) : "",
                            style: textStyle))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                            showValue ? formatNum(row['mvmt_dr']) : "",
                            style: textStyle))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                            showValue ? formatNum(row['mvmt_cr']) : "",
                            style: textStyle))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                            showValue ? formatNum(row['end_dr']) : "",
                            style: textStyle))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                            showValue ? formatNum(row['end_cr']) : "",
                            style: textStyle))),
              ]);

          List<pw.TableRow> dimRows = [];
          if (_showDimensions &&
              row['dimension_rows'] != null &&
              row['dimension_rows'].isNotEmpty &&
              !isHeader &&
              !_showOnlyHeaders) {
            final dims = row['dimension_rows'] as List;
            for (var d in dims) {
              final String brCode = d['branch_code'] as String? ?? '';
              final dimParts = <String>[];
              if (brCode.isNotEmpty) dimParts.add(brCode);
              // backend ส่ง dim1_code, dim2_code กลับมา
              for (int slot = 1; slot <= 2; slot++) {
                final code = d['dim${slot}_code'] as String? ?? '';
                if (code.isNotEmpty) dimParts.add(code);
              }
              bool hasDim = dimParts.isNotEmpty;
              String dimText = dimParts.join(' / ');

              if (hasDim) {
                double dEnd = (double.tryParse(d['beg_dr'].toString()) ?? 0) -
                    (double.tryParse(d['beg_cr'].toString()) ?? 0) +
                    (double.tryParse(d['mvmt_dr'].toString()) ?? 0) -
                    (double.tryParse(d['mvmt_cr'].toString()) ?? 0);
                double dEndDr = dEnd > 0 ? dEnd : 0;
                double dEndCr = dEnd < 0 ? dEnd.abs() : 0;

                dimRows.add(pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.only(left: indent + 20),
                        child: pw.Text(dimText,
                            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 12)),
                      ),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['beg_dr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 10, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['beg_cr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 10, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['mvmt_dr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 10, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['mvmt_cr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 10, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(dEndDr),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 10, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(dEndCr),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 10, color: PdfColors.grey700))),
                    ]));
              }
            }
          }
          
          return pw.Table(columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
            6: const pw.FlexColumnWidth(1.5),
          }, children: [
            mainRow,
            ...dimRows
          ]);
        }).toList());

        // Add Grand Total Row at the end of the list
        rows.add(pw.Column(children: [
          // pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Table(columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
            6: const pw.FlexColumnWidth(1.5),
          }, children: [
            pw.TableRow(children: [
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey800),
                        left: pw.BorderSide(color: PdfColors.grey800),
                        bottom: pw.BorderSide(color: PdfColors.grey800),
                      )),
                      alignment: pw.Alignment.center,
                      child: pw.Text("ยอดรวม",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey800),
                        left: pw.BorderSide(color: PdfColors.grey800),
                        bottom: pw.BorderSide(color: PdfColors.grey800),
                      )),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(sumBegDr),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey800),
                        left: pw.BorderSide(color: PdfColors.grey800),
                        bottom: pw.BorderSide(color: PdfColors.grey800),
                      )),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(sumBegCr),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey800),
                        left: pw.BorderSide(color: PdfColors.grey800),
                        bottom: pw.BorderSide(color: PdfColors.grey800),
                      )),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(sumMvmtDr),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey800),
                        left: pw.BorderSide(color: PdfColors.grey800),
                        bottom: pw.BorderSide(color: PdfColors.grey800),
                      )),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(sumMvmtCr),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey800),
                        left: pw.BorderSide(color: PdfColors.grey800),
                        bottom: pw.BorderSide(color: PdfColors.grey800),
                      )),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(sumEndDr),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
              pw.Expanded(
                  child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(1, 3, 1, 3),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                              top: pw.BorderSide(color: PdfColors.grey800),
                              left: pw.BorderSide(color: PdfColors.grey800),
                              bottom: pw.BorderSide(color: PdfColors.grey800),
                              right: pw.BorderSide(color: PdfColors.grey800))),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(sumEndCr),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)))),
            ])
          ]),
          // pw.Divider(thickness: 0.5),
        ]));

        return rows;
      },
    ));

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _loadMasterData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxFilterWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 36,
            color: Colors.deepOrange[900],
            child: IconButton(
              icon: Icon(
                _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
            ),
          ),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เงื่อนไขรายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<FiscalYear>(
                      isExpanded: true,
                      value: _selectedYear,
                      items: _fiscalYears.map((fy) => DropdownMenuItem(value: fy, child: Text(fy.fyCode))).toList(),
                      decoration: const InputDecoration(labelText: 'ปีบัญชี', border: OutlineInputBorder()),
                      onChanged: (val) async {
                        if (val != null) {
                           setState(() => _selectedYear = val);
                           await _loadPeriods(val.id);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PostingPeriod>(
                      isExpanded: true,
                      value: _selectedPeriod,
                      items: [
                        const DropdownMenuItem<PostingPeriod>(value: null, child: Text("ทุกงวด (ตั้งแต่ต้นปี)")),
                        ..._periods.skip(1).map((p) => DropdownMenuItem(value: p, child: Text("${p.periodNumber} - ${p.periodName}"))),
                      ],
                      decoration: const InputDecoration(labelText: 'งวดเดือน', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() => _selectedPeriod = val),
                    ),
                    if (_allowedBranches.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        value: _selectedBranchId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'สาขา', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— ทุกสาขา —')),
                          ..._allowedBranches.map((b) => DropdownMenuItem<int?>(
                            value: b.branchId,
                            child: Text('${b.branchCode}  ${b.branchNameThai}', overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (val) => setState(() => _selectedBranchId = val),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // แสดงเฉพาะเมื่อมี dimension type ที่ active
                    if (_activeDimTypes.isNotEmpty)
                      SwitchListTile(
                        title: const Text('แสดงสาขา/มิติ'),
                        value: _showDimensions,
                        onChanged: (v) => setState(() => _showDimensions = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    SwitchListTile(
                      title: const Text('ซ่อนบัญชีที่ยอดเป็นศูนย์'),
                      value: _hideZero,
                      onChanged: (v) => setState(() => _hideZero = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(),
                    SwitchListTile(
                      title: const Text('แสดงแบบผังบัญชี (Hierarchy)'),
                      subtitle: const Text('แสดงบัญชีคุมและย่อหน้า'),
                      value: _showHierarchy,
                      onChanged: (v) {
                        setState(() {
                          _showHierarchy = v;
                          if (!v) {
                            _showHeaderTotals = false;
                            _showOnlyHeaders = false;
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    // [NEW] Show Only Headers
                    SwitchListTile(
                      title: const Text('แสดงเฉพาะหัวบัญชี'),
                      value: _showOnlyHeaders,
                      onChanged: _showHierarchy
                        ? (v) => setState(() => _showOnlyHeaders = v)
                        : null,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('แสดงยอดรวมที่หัวบัญชี'),
                      value: _showHeaderTotals,
                      onChanged: _showHierarchy
                        ? (v) => setState(() => _showHeaderTotals = v)
                        : null, // Disabled if Hierarchy OFF or ShowOnlyHeaders ON (because logic forces it ON)
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('ประมวลผลรายงาน'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
                        onPressed: _generateReport,
                      ),
                    ),
                  ],
                ),
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
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _filterPanelWidth =
                        (_filterPanelWidth + details.delta.dx)
                            .clamp(200.0, maxFilterWidth);
                  });
                },
                onHorizontalDragEnd: (_) =>
                    setState(() => _isDraggingDivider = false),
                child: Container(
                  width: 5,
                  color: Colors.grey[400],
                ),
              ),
            ),
          // Preview Panel
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: _reportData.isEmpty
                  ? const Center(child: Text("กรุณาเลือกเงื่อนไขและกดประมวลผล"))
                  : PdfPreview(
                      build: (format) => _generatePdf(format),
                      initialPageFormat: PdfPageFormat.a4.landscape,
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}
