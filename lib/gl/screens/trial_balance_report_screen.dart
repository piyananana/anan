import 'dart:typed_data';
import 'package:anan/sa/models/company.dart';
import 'package:anan/sa/services/company_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
import '../../gl/services/trial_balance_report_service.dart';

// Master Data Services
import '../../cd/services/branch_service.dart';
import '../../cd/services/business_unit_service.dart';
import '../../cd/services/project_service.dart';
import '../../sa/services/auth_service.dart';

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
  final BusinessUnitService _buService = BusinessUnitService();
  final ProjectService _projectService = ProjectService();
  final AuthService authService = AuthService();
  late Map<String, String> headers;

  // Data
  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<Map<String, dynamic>> _reportData = [];

  // Master Data Maps
  Map<int, String> _branchMap = {};
  Map<int, String> _buMap = {};
  Map<int, String> _projectMap = {};

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

  @override
  void initState() {
    super.initState();
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
      final bus = await _buService.fetchRows();
      final projects = await _projectService.fetchRows();

      _branchMap = {for (var e in branches) e.id!: e.branchCode};
      _buMap = {for (var e in bus) e.id!: e.buCode};
      _projectMap = {for (var e in projects) e.id!: e.projectCode};
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

  // --- PDF Generation Logic ---
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();

    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

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
      conditions.add("ไม่แสดงสาขา/หน่วยงาน/โครงการ");
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
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
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
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text("งบทดลอง (Trial Balance)",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                        "หน้า ${context.pageNumber}/${context.pagesCount}",
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10)))
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child:
                        pw.Text("", style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text(periodLine,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text("พิมพ์โดย $userName",
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10)))
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
                        style: const pw.TextStyle(fontSize: 8))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text("พิมพ์เมื่อ $printDateStr",
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10)))
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                            _showDimensions ? "สาขา/หน่วยงาน/โครงการ" : "-",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
                                fontSize: 10)))),
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
              ? pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
              : const pw.TextStyle(fontSize: 10);
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
              String brCode =
                  d['branch_code'] ?? _branchMap[d['branch_id']] ?? "";
              String buCode =
                  d['bu_code'] ?? _buMap[d['business_unit_id']] ?? "";
              String pjCode =
                  d['project_code'] ?? _projectMap[d['project_id']] ?? "";

              // แสดงเฉพาะบัญชีที่มีการป้อน dimension อย่างน้อย 1 ตัว
              bool hasDim = brCode.isNotEmpty || buCode.isNotEmpty || pjCode.isNotEmpty;
              // dimension ที่ไม่ได้ป้อนให้แสดง "..."
              String dimText =
                  '${brCode.isNotEmpty ? brCode : " - "} / ${buCode.isNotEmpty ? buCode : " - "} / ${pjCode.isNotEmpty ? pjCode : " - "}';

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
                            style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                fontSize: 8, color: PdfColors.grey700)),
                      ),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['beg_dr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 8, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['beg_cr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 8, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['mvmt_dr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 8, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(d['mvmt_cr']),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 8, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(dEndDr),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 8, color: PdfColors.grey700))),
                      pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(formatNum(dEndCr),
                              style: pw.TextStyle(fontStyle: pw.FontStyle.italic,
                                  fontSize: 8, color: PdfColors.grey700))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
                              fontWeight: pw.FontWeight.bold, fontSize: 10)))),
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
        title: const Text('งบทดลอง (Trial Balance)'),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
      ),
      body: ResizableContainer(
        direction: Axis.horizontal,
        // divider: Container(color: Colors.grey[300], width: 4),
        children: [
          // Filter Panel
          ResizableChild(
            // minSize: 300,
            size: const ResizableSize.pixels(350),
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
                      value: _selectedPeriod,
                      items: [
                        const DropdownMenuItem<PostingPeriod>(value: null, child: Text("ทุกงวด (ตั้งแต่ต้นปี)")),
                        ..._periods.skip(1).map((p) => DropdownMenuItem(value: p, child: Text("${p.periodNumber} - ${p.periodName}"))),
                      ],
                      decoration: const InputDecoration(labelText: 'งวดเดือน', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() => _selectedPeriod = val),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('แสดงสาขา/หน่วยงาน/โครงการ'),
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
          // Preview Panel
          ResizableChild(
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
      ),
    );
  }
}
