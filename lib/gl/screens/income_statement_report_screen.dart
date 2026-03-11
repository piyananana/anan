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
import '../../gl/services/income_statement_report_service.dart';
import '../../sa/services/auth_service.dart';

class IncomeStatementReportScreen extends StatefulWidget {
  const IncomeStatementReportScreen({super.key});

  @override
  State<IncomeStatementReportScreen> createState() =>
      _IncomeStatementReportScreenState();
}

class _IncomeStatementReportScreenState
    extends State<IncomeStatementReportScreen> {
  final CompanyService _companyService = CompanyService();
  final PeriodService _periodService = PeriodService();
  final IncomeStatementReportService _reportService =
      IncomeStatementReportService();
  final AuthService authService = AuthService();
  late Map<String, String> headers;

  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<Map<String, dynamic>> _reportData = [];
  Map<int, int> _accountLevels = {};

  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;
  bool _pageBreakPerType = false;
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
          _selectedYear = _fiscalYears.firstWhere(
            (fy) =>
                now.isAfter(fy.yearStartDate) && now.isBefore(fy.yearEndDate),
          );
        } catch (_) {
          _selectedYear = _fiscalYears.first;
        }
        await _loadPeriods(_selectedYear!.id);
      }
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
    setState(() {
      _isLoading = true;
      _reportData = [];
    });
    try {
      final data = await _reportService.getIncomeStatement(
        fiscalYearId: _selectedYear!.id,
        periodId: _selectedPeriod?.id,
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
      setState(() => _reportData = data);
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
    final Map<int, int?> parentMap = {};
    for (var row in data) {
      if (row['account_id'] != null) {
        parentMap[row['account_id']] = row['parent_id'];
      }
    }
    for (var row in data) {
      final int id = row['account_id'];
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

  (List<Map<String, dynamic>>, Set<int>) _computeDisplayFilter(
      List<Map<String, dynamic>> rows) {
    final Map<int?, List<Map<String, dynamic>>> byParent = {};
    for (var row in rows) {
      final parentId = row['parent_id'] as int?;
      byParent.putIfAbsent(parentId, () => []).add(row);
    }

    final Set<int> shownIds = {};
    for (var row in rows) {
      final id = row['account_id'] as int;
      if (row['is_header'] == true) {
        shownIds.add(id);
      } else {
        final parentId = row['parent_id'] as int?;
        final siblings = byParent[parentId] ?? [];
        if (siblings.any((s) => s['is_header'] == true)) {
          shownIds.add(id);
        }
      }
    }

    final Map<int, List<int>> childIds = {};
    for (var row in rows) {
      final parentId = row['parent_id'] as int?;
      if (parentId != null) {
        childIds.putIfAbsent(parentId, () => []).add(row['account_id'] as int);
      }
    }

    final Set<int> leafIds = {};
    for (var id in shownIds) {
      final children = childIds[id] ?? [];
      if (!children.any((c) => shownIds.contains(c))) {
        leafIds.add(id);
      }
    }

    final List<Map<String, dynamic>> shownRows =
        rows.where((r) => shownIds.contains(r['account_id'] as int)).toList();

    return (shownRows, leafIds);
  }

  // ---- PDF Generation ----

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    final companyName = _company?.thaiName ?? "(ไม่ระบุชื่อบริษัท)";
    final userName = headers['UserName'] ?? "(ไม่ระบุชื่อ)";
    final printDateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String asOfLabel;
    if (_selectedPeriod != null) {
      asOfLabel =
          "ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_selectedPeriod!.periodEndDate)}";
    } else if (_periods.length > 1) {
      asOfLabel =
          "สำหรับปีสิ้นสุด ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_periods.last.periodEndDate)}";
    } else {
      asOfLabel = "ปี ${_selectedYear?.fyCode ?? ''}";
    }

    final fmt = NumberFormat("#,##0.00", "en_US");

    String fmtAmt(dynamic val) {
      final double v = double.tryParse(val.toString()) ?? 0.0;
      if (v.abs() < 0.001) return "";
      if (v < 0) return "(${fmt.format(v.abs())})";
      return fmt.format(v);
    }

    String fmtTotal(double v) {
      if (v < 0) return "(${fmt.format(v.abs())})";
      return fmt.format(v);
    }

    // Group by account type
    final allRevenue =
        _reportData.where((r) => r['account_type'] == 'REVENUE').toList();
    final allExpense =
        _reportData.where((r) => r['account_type'] == 'EXPENSE').toList();

    // rawBal = debit_amount − credit_amount  (ตรงจากตาราง gl_balance_accum)
    // backend ส่ง end_balance = DEBIT_normal ? (dr−cr) : −(dr−cr)
    // ดังนั้น: rawBal = DEBIT ? end_balance : −end_balance
    double rawBal(Map<String, dynamic> row) {
      final bal = double.tryParse(row['end_balance'].toString()) ?? 0.0;
      return row['normal_balance'] == 'DEBIT' ? bal : -bal;
    }

    // REVENUE display = −rawBal  (rawBal < 0 → display บวก = รายได้)
    // EXPENSE display = +rawBal  (rawBal > 0 → display บวก = ค่าใช้จ่าย)
    double revenueDisplay(Map<String, dynamic> row) => -rawBal(row);
    double expenseDisplay(Map<String, dynamic> row) => rawBal(row);

    // Section totals (control accounts only)
    final totalRevenue = allRevenue
        .where((r) => r['is_header'] == false)
        .fold(0.0, (s, r) => s + revenueDisplay(r));
    final totalExpense = allExpense
        .where((r) => r['is_header'] == false)
        .fold(0.0, (s, r) => s + expenseDisplay(r));

    // Net income: Σ rawBal ของทุก P&L account
    // ถ้าลบ = กำไร (แสดงบวก), ถ้าบวก = ขาดทุน (วงเล็บ)
    final netRaw = [...allRevenue, ...allExpense]
        .where((r) => r['is_header'] == false)
        .fold(0.0, (s, r) => s + rawBal(r));
    final netIncome = -netRaw; // บวก = กำไร, ลบ = ขาดทุน (วงเล็บ)

    // Apply display filter per section
    final (revenueRows, revenueLeafs) = _computeDisplayFilter(allRevenue);
    final (expenseRows, expenseLeafs) = _computeDisplayFilter(allExpense);

    // Build account rows — displayFn กำหนดค่าที่แสดงต่อแถว
    List<pw.Widget> buildAccountRows(
        List<Map<String, dynamic>> rows,
        Set<int> showAmountIds,
        double Function(Map<String, dynamic>) displayFn) {
      return rows.map((row) {
        final id = row['account_id'] as int;
        final level = _accountLevels[id] ?? 0;
        final indent = level * 12.0;
        final showAmt = showAmountIds.contains(id);

        return pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(7),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.only(
                      left: indent, top: 3, bottom: 3, right: 4),
                  child: pw.Text(
                    "${row['account_name_thai']}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      showAmt ? fmtAmt(displayFn(row)) : "",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }).toList();
    }

    // Section header widget
    pw.Widget buildSectionHeader(String title) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 5),
        color: PdfColors.grey300,
        child: pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
      );
    }

    // Section total row
    pw.Widget buildSectionTotal(String label, double total) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
        child: pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(7),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(children: [
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(4, 4, 4, 4),
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(top: pw.BorderSide(color: PdfColors.grey700)),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(label,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(4, 4, 0, 4),
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(top: pw.BorderSide(color: PdfColors.grey700)),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(fmtTotal(total),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    // Net income row (thick top border)
    pw.Widget buildNetIncomeRow(double total) {
      final label = total >= 0 ? "กำไรสุทธิ (Net Income)" : "ขาดทุนสุทธิ (Net Loss)";
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(7),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(children: [
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(label,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(4, 5, 0, 5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(fmtTotal(total),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(
              flex: 3,
              child:
                  pw.Text(companyName, style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 7,
              child: pw.Text(
                "งบกำไรขาดทุน (Income Statement)",
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              )),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                "หน้า ${context.pageNumber}/${context.pagesCount}",
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10),
              )),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Text("")),
          pw.Expanded(
              flex: 7,
              child: pw.Text(asOfLabel,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 3,
              child: pw.Text("พิมพ์โดย $userName",
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(
              flex: 10,
              child: pw.Text("ปีบัญชี: ${_selectedYear?.fyCode ?? ''}",
                  style: const pw.TextStyle(fontSize: 8))),
          pw.Expanded(
              flex: 3,
              child: pw.Text("พิมพ์เมื่อ $printDateStr",
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
      ]),
      footer: (context) =>
          pw.Column(children: [pw.Divider(thickness: 0.5)]),
      build: (context) {
        final List<pw.Widget> widgets = [];

        // --- REVENUE section ---
        widgets.add(buildSectionHeader("รายได้ (Revenue)"));
        widgets.addAll(buildAccountRows(revenueRows, revenueLeafs, revenueDisplay));
        widgets.add(buildSectionTotal("รวมรายได้", totalRevenue));

        if (_pageBreakPerType) {
          widgets.add(pw.NewPage());
        } else {
          widgets.add(pw.SizedBox(height: 8));
        }

        // --- EXPENSE section ---
        widgets.add(buildSectionHeader("ค่าใช้จ่าย (Expense)"));
        widgets.addAll(buildAccountRows(expenseRows, expenseLeafs, expenseDisplay));
        widgets.add(buildSectionTotal("รวมค่าใช้จ่าย", totalExpense));

        // --- Net Income ---
        widgets.add(buildNetIncomeRow(netIncome));

        return widgets;
      },
    ));

    return doc.save();
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('งบกำไรขาดทุน (Income Statement)'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: ResizableContainer(
        direction: Axis.horizontal,
        children: [
          // Filter Panel
          ResizableChild(
            size: const ResizableSize.pixels(350),
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เงื่อนไขรายงาน',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    // ปีบัญชี
                    DropdownButtonFormField<FiscalYear>(
                      value: _selectedYear,
                      items: _fiscalYears
                          .map((fy) => DropdownMenuItem(
                              value: fy, child: Text(fy.fyCode)))
                          .toList(),
                      decoration: const InputDecoration(
                          labelText: 'ปีบัญชี',
                          border: OutlineInputBorder()),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _selectedYear = val);
                          await _loadPeriods(val.id);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // งวด
                    DropdownButtonFormField<PostingPeriod>(
                      value: _selectedPeriod,
                      items: [
                        const DropdownMenuItem<PostingPeriod>(
                            value: null, child: Text("ทุกงวด (สิ้นปี)")),
                        ..._periods.skip(1).map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                                "${p.periodNumber} - ${p.periodName}"))),
                      ],
                      decoration: const InputDecoration(
                          labelText: 'งวดเดือน',
                          border: OutlineInputBorder()),
                      onChanged: (val) =>
                          setState(() => _selectedPeriod = val),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Switch: ขึ้นหน้าใหม่ทุกหมวด
                    SwitchListTile(
                      title: const Text('ขึ้นหน้าใหม่ทุกหมวดบัญชี'),
                      subtitle:
                          const Text('แยกรายได้/ค่าใช้จ่ายคนละหน้า'),
                      value: _pageBreakPerType,
                      onChanged: (v) =>
                          setState(() => _pageBreakPerType = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('ประมวลผลรายงาน'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _generateReport,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // PDF Preview Panel
          ResizableChild(
            child: Container(
              color: Colors.grey[200],
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reportData.isEmpty
                      ? const Center(
                          child: Text("กรุณาเลือกเงื่อนไขและกดประมวลผล"))
                      : PdfPreview(
                          build: (format) => _generatePdf(format),
                          initialPageFormat: PdfPageFormat.a4,
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
