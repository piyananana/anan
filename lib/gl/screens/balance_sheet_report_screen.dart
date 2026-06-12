import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:anan/sa/models/company.dart';
import 'package:anan/sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
import '../../gl/services/balance_sheet_report_service.dart';
import '../../sa/models/user_branch.dart';
import '../../sa/services/auth_service.dart';

class BalanceSheetReportScreen extends StatefulWidget {
  const BalanceSheetReportScreen({super.key});

  @override
  State<BalanceSheetReportScreen> createState() =>
      _BalanceSheetReportScreenState();
}

class _BalanceSheetReportScreenState extends State<BalanceSheetReportScreen> {
  final CompanyService _companyService = CompanyService();
  final PeriodService _periodService = PeriodService();
  final BalanceSheetReportService _reportService = BalanceSheetReportService();
  final AuthService authService = AuthService();
  late Map<String, String> headers;

  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<Map<String, dynamic>> _reportData = [];
  Map<int, int> _accountLevels = {};

  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;
  bool _pageBreakPerType = false;
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
      final data = await _reportService.getBalanceSheet(
        fiscalYearId: _selectedYear!.id,
        periodId: _selectedPeriod?.id,
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

  // ---- Display Filter Logic ----

  /// Returns (shownRows, leafIds):
  /// - shownRows: header accounts + control accounts that have at least one
  ///              header sibling (same parent)
  /// - leafIds: shown accounts that have NO shown children
  ///            → these are the ones that display an amount
  (List<Map<String, dynamic>>, Set<int>) _computeDisplayFilter(
      List<Map<String, dynamic>> rows) {
    // Group accounts by parent_id (null = root)
    final Map<int?, List<Map<String, dynamic>>> byParent = {};
    for (var row in rows) {
      final parentId = row['parent_id'] as int?;
      byParent.putIfAbsent(parentId, () => []).add(row);
    }

    // Determine which accounts to show
    final Set<int> shownIds = {};
    for (var row in rows) {
      final id = row['account_id'] as int;
      if (row['is_header'] == true) {
        shownIds.add(id); // always show header accounts
      } else {
        // Control account: show only if at least one sibling is a header
        final parentId = row['parent_id'] as int?;
        final siblings = byParent[parentId] ?? [];
        if (siblings.any((s) => s['is_header'] == true)) {
          shownIds.add(id);
        }
      }
    }

    // Build children map (account_id → list of children ids)
    final Map<int, List<int>> childIds = {};
    for (var row in rows) {
      final parentId = row['parent_id'] as int?;
      if (parentId != null) {
        childIds.putIfAbsent(parentId, () => []).add(row['account_id'] as int);
      }
    }

    // Leaf = shown account with NO shown children → displays amount
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

  // ---- Excel Export ----

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'BalanceSheet');
      final s = ex['BalanceSheet'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final secBg = ExcelColor.fromHexString('#D9E1F2');

      double endBal(Map<String, dynamic> row) =>
          double.tryParse(row['end_balance'].toString()) ?? 0.0;

      final _asOfLabel = _selectedPeriod != null
          ? 'ณ วันที่: ${DateFormat('dd/MM/yyyy').format(_selectedPeriod!.periodEndDate)}'
          : 'ปี: ${_selectedYear?.fyCode ?? ''}';
      final _ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'งบดุล (Balance Sheet)', bold: true);
      _xlCell(s, 2, 0, '$_asOfLabel  |  พิมพ์: $_ts');

      int r = 3;
      _xlCell(s, r, 0, 'รหัส/ชื่อบัญชี', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, 'ยอดคงเหลือ', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      r++;

      final allAsset    = _reportData.where((row) => row['account_type'] == 'ASSET').toList();
      final allLiability = _reportData.where((row) => row['account_type'] == 'LIABILITY').toList();
      final allEquity   = _reportData.where((row) => row['account_type'] == 'EQUITY').toList();

      for (final group in [
        ('สินทรัพย์ (ASSET)', allAsset),
        ('หนี้สิน (LIABILITY)', allLiability),
        ('ส่วนของเจ้าของ (EQUITY)', allEquity),
      ]) {
        final (label, rows) = group;
        _xlCell(s, r, 0, label, bg: secBg, bold: true);
        _xlCell(s, r, 1, '', bg: secBg);
        r++;

        double sectionTotal = 0.0;
        for (final row in rows) {
          final isHeader = row['is_header'] == true;
          final code = row['account_code']?.toString() ?? '';
          final name = row['account_name_thai']?.toString() ?? '';
          final bal  = endBal(row);
          if (!isHeader) sectionTotal += bal;
          _xlCell(s, r, 0, '$code $name', bold: isHeader);
          _xlCell(s, r, 1, bal == 0 ? TextCellValue('') : DoubleCellValue(bal), align: HorizontalAlign.Right, bold: isHeader);
          r++;
        }

        _xlCell(s, r, 0, 'รวม $label', bg: totBg, bold: true);
        _xlCell(s, r, 1, DoubleCellValue(sectionTotal), bg: totBg, bold: true, align: HorizontalAlign.Right);
        r++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'งบดุล_$ts.xlsx');
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

  // ---- PDF Generation ----

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.thaiName ?? "(ไม่ระบุชื่อบริษัท)";
    final userName = headers['UserName'] ?? "(ไม่ระบุชื่อ)";
    final printDateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // "ณ วันที่" label
    String asOfLabel;
    if (_selectedPeriod != null) {
      asOfLabel =
          "ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_selectedPeriod!.periodEndDate)}";
    } else if (_periods.length > 1) {
      asOfLabel =
          "ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_periods.last.periodEndDate)}";
    } else {
      asOfLabel = "ปี ${_selectedYear?.fyCode ?? ''}";
    }

    final fmt = NumberFormat("#,##0.00", "en_US");

    String fmtTotal(double v) {
      if (v < 0) return "(${fmt.format(v.abs())})";
      return fmt.format(v);
    }

    // Group by account type
    final allAsset =
        _reportData.where((r) => r['account_type'] == 'ASSET').toList();
    final allLiability =
        _reportData.where((r) => r['account_type'] == 'LIABILITY').toList();
    final allEquity =
        _reportData.where((r) => r['account_type'] == 'EQUITY').toList();

    // end_balance จาก backend ถูก sign-adjust ตาม normal_balance แล้ว:
    //   DEBIT normal  → end_balance = dr−cr (บวกเมื่อมียอด)
    //   CREDIT normal → end_balance = cr−dr (บวกเมื่อมียอด)
    // ดังนั้นใช้ end_balance ตรงๆ สำหรับทุกหมวด
    double endBal(Map<String, dynamic> row) =>
        double.tryParse(row['end_balance'].toString()) ?? 0.0;

    // section total = sum ของ end_balance ของ control accounts ทั้งหมดในหมวด
    double sumSection(List<Map<String, dynamic>> rows) =>
        rows
            .where((r) => r['is_header'] == false)
            .fold(0.0, (s, r) => s + endBal(r));

    final totalAsset     = sumSection(allAsset);
    final totalLiability = sumSection(allLiability);
    final totalEquity    = sumSection(allEquity);
    // LIABILITY และ EQUITY เป็น credit-normal: ถ้า sum end_balance ติดลบ
    // หมายความว่ามียอด credit อยู่ ต้องแสดงเป็นบวก
    final rawTotalLE = totalLiability + totalEquity;
    final totalLiabilityEquity = rawTotalLE < 0 ? -rawTotalLE : rawTotalLE;

    // Apply display filter per section
    final (assetRows, assetLeafs) = _computeDisplayFilter(allAsset);
    final (liabilityRows, liabilityLeafs) = _computeDisplayFilter(allLiability);
    final (equityRows, equityLeafs) = _computeDisplayFilter(allEquity);

    List<pw.Widget> buildAccountRows(
        List<Map<String, dynamic>> rows,
        Set<int> showAmountIds) {
      return rows.map((row) {
        final id = row['account_id'] as int;
        final level = _accountLevels[id] ?? 0;
        final indent = level * 12.0;
        final showAmt = showAmountIds.contains(id);
        const textStyle = pw.TextStyle(fontSize: 12);

        final displayVal = showAmt ? endBal(row) : 0.0;
        String amtStr = "";
        if (showAmt) {
          if (displayVal.abs() < 0.001) {
            amtStr = "";
          } else if (displayVal < 0) {
            amtStr = "(${fmt.format(displayVal.abs())})";
          } else {
            amtStr = fmt.format(displayVal);
          }
        }

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
                    style: textStyle,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(amtStr, style: textStyle),
                  ),
                ),
              ],
            ),
          ],
        );
      }).toList();
    }

    // Section header widget (colored background)
    pw.Widget buildSectionHeader(String title) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 5),
        color: PdfColors.grey300,
        child: pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
        ),
      );
    }

    // Section total row (top border + bold)
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
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    // Grand total row (double top border)
    pw.Widget buildGrandTotal(double total) {
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
                  child: pw.Text("รวมหนี้สินและส่วนของเจ้าของ",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
                  pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
          pw.Expanded(
              flex: 7,
              child: pw.Text(
                "งบดุล (Balance Sheet)",
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              )),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                "หน้า ${context.pageNumber}/${context.pagesCount}",
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 12),
              )),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Text("")),
          pw.Expanded(
              flex: 7,
              child: pw.Text(asOfLabel,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 12))),
          pw.Expanded(
              flex: 3,
              child: pw.Text("พิมพ์โดย $userName",
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 12))),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(
              flex: 10,
              child: pw.Text("ปีบัญชี: ${_selectedYear?.fyCode ?? ''}",
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 3,
              child: pw.Text("พิมพ์เมื่อ $printDateStr",
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 12))),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
      ]),
      footer: (context) =>
          pw.Column(children: [pw.Divider(thickness: 0.5)]),
      build: (context) {
        final List<pw.Widget> widgets = [];

        // --- ASSET section ---
        widgets.add(buildSectionHeader("สินทรัพย์ (Assets)"));
        widgets.addAll(buildAccountRows(assetRows, assetLeafs));
        widgets.add(buildSectionTotal("รวมสินทรัพย์", totalAsset));

        if (_pageBreakPerType) {
          widgets.add(pw.NewPage());
        } else {
          widgets.add(pw.SizedBox(height: 8));
        }

        // --- LIABILITY section ---
        widgets.add(buildSectionHeader("หนี้สิน (Liabilities)"));
        widgets.addAll(buildAccountRows(liabilityRows, liabilityLeafs));
        widgets.add(buildSectionTotal("รวมหนี้สิน", totalLiability));

        if (_pageBreakPerType) {
          widgets.add(pw.NewPage());
        } else {
          widgets.add(pw.SizedBox(height: 8));
        }

        // --- EQUITY section ---
        widgets.add(buildSectionHeader("ส่วนของเจ้าของ (Equity)"));
        widgets.addAll(buildAccountRows(equityRows, equityLeafs));
        widgets.add(buildSectionTotal("รวมส่วนของเจ้าของ", totalEquity));

        // --- Grand total ---
        widgets.add(buildGrandTotal(totalLiabilityEquity));

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
        title: const Row(children: [Icon(Icons.account_balance, color: Colors.white, size: 20), SizedBox(width: 8), Text('งบดุล (Balance Sheet)')]),
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
                    const Text('เงื่อนไขรายงาน',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    // ปีบัญชี
                    DropdownButtonFormField<FiscalYear>(
                      isExpanded: true,
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
                      isExpanded: true,
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
                    if (_allowedBranches.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        value: _selectedBranchId,
                        decoration: const InputDecoration(
                            labelText: 'สาขา',
                            border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— ทุกสาขา —')),
                          ..._allowedBranches.map((b) => DropdownMenuItem<int?>(
                              value: b.branchId,
                              child: Text('${b.branchCode}  ${b.branchNameThai}',
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) => setState(() => _selectedBranchId = val),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    // Switch: ขึ้นหน้าใหม่ทุกหมวด
                    SwitchListTile(
                      title: const Text('ขึ้นหน้าใหม่ทุกหมวดบัญชี'),
                      subtitle:
                          const Text('แยกสินทรัพย์/หนี้สิน/ทุนคนละหน้า'),
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
                          backgroundColor: Colors.deepOrange[900],
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
          // PDF Preview Panel
          Expanded(
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
      );
        },
      ),
    );
  }
}
