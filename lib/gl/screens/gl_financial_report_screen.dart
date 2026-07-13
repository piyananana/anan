// File: screens/gl/gl_financial_report_screen.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../gl/models/gl_period.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_period_service.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../services/gl_financial_report_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final FinancialReportService _reportService = FinancialReportService();
  final PeriodService _periodService = PeriodService();
  final CompanyService _companyService = CompanyService();
  final AuthService _authService = AuthService();
  final GlDimensionService _dimService = GlDimensionService();

  bool _isLoading = false;
  bool _isExporting = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 350.0;
  bool _isDraggingDivider = false;
  Company? _company;
  Map<String, String>? _headers;

  List<Map<String, dynamic>> _reportMasters = [];
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];

  // Branch + Dimension filters
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {}; // slotNo → selected dimValueId

  Map<String, dynamic>? _selectedReport;
  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;

  Map<String, dynamic>? _reportData;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _allowedBranches = _authService.allowedBranches;
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    try {
      _headers = await _authService.getAuthHeader();
      _company = await _companyService.fetchCompany();

      _reportMasters = await _reportService.fetchReportMasters();

      // โหลด dimension types + values
      final types = await _dimService.fetchActiveTypes();
      final valResults = await Future.wait(
        types.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      setState(() {
        _dimTypes = types;
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
      });
      if (_reportMasters.isNotEmpty) {
        _selectedReport = _reportMasters.first;
      }

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
      _selectedPeriod = ps.isNotEmpty ? ps.last : null;
    });
  }

  Future<void> _runReport() async {
    if (_selectedReport == null || _selectedPeriod == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _reportService.generateReport(
        _selectedReport!['id'],
        _selectedPeriod!.id,
        branchId: _selectedBranchId,
        dim1Id: _dimSelections[1],
        dim2Id: _dimSelections[2],
        dim3Id: _dimSelections[3],
        dim4Id: _dimSelections[4],
        dim5Id: _dimSelections[5],
      );
      setState(() => _reportData = data);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // HELPER: แปลงข้อมูลจาก Database เป็น PDF Styles
  // =========================================================================
  // pw.TextAlign _getPdfTextAlign(String align) {
  //   switch (align.toUpperCase()) {
  //     case 'CENTER':
  //       return pw.TextAlign.center;
  //     case 'RIGHT':
  //       return pw.TextAlign.right;
  //     default:
  //       return pw.TextAlign.left;
  //   }
  // }

  // pw.Alignment _getPdfAlignment(String align) {
  //   switch (align.toUpperCase()) {
  //     case 'CENTER':
  //       return pw.Alignment.center;
  //     case 'RIGHT':
  //       return pw.Alignment.centerRight;
  //     default:
  //       return pw.Alignment.centerLeft;
  //   }
  // }

// ฟังก์ชันแทนที่ตัวแปร ($)
String _replaceVars(String text, pw.Context? context) {
    if (text.isEmpty) return "";
    
    final String companyName = _company?.thaiName ?? "";
    final String reportName = _reportData?['report_name']?.toString() ?? "";
    final String periodName = _selectedPeriod?.periodName ?? "";
    final String fiscalYear = _selectedYear?.fyCode ?? "";
    final String userName = _headers?['UserName'] ?? "System";
    final String printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String result = text
        .replaceAll(r'$companyName', companyName)
        .replaceAll(r'$reportName', reportName)
        .replaceAll(r'$periodName', periodName)
        .replaceAll(r'$fiscalYear', fiscalYear)
        .replaceAll(r'$userName', userName)
        .replaceAll(r'$printDate', printDateStr);

    if (context != null) {
      try {
        result = result
            .replaceAll(r'$pageNumber', context.pageNumber.toString())
            .replaceAll(r'$pageCount', context.pagesCount.toString());
      } catch (_) {}
    }
    return result;
  }

  // ฟังก์ชันย่อยสำหรับวาด Row ใน PDF
  // pw.Widget _buildPdfRow(Map<String, dynamic> rowData, pw.Context context, pw.Font fontNormal, pw.Font fontBold, pw.Font fontItalic) {
  //   final List<dynamic> columns = rowData['columns'] ?? [];

  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.symmetric(vertical: 2),
  //     child: pw.Row(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: columns.map((col) {
  //         final int flex = col['flex'] ?? 1;
  //         final String type = col['type'] ?? 'TEXT';
  //         final String dataType = col['data_type']?.toString() ?? '-'; // ดึงค่า data_type
  //         final style = col['style'] ?? {};
  //         final dynamic rawValue = col['value'];
          
  //         final int indent = int.tryParse(col['indent_level']?.toString() ?? '0') ?? 0;

  //         // ==========================================
  //         // 1. กรณีเป็นเส้นคั่น (DIVIDER) รองรับเส้นคู่
  //         // ==========================================
  //         if (type == 'DIVIDER') {
  //           return pw.Expanded(
  //             flex: flex,
  //             child: pw.Padding(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 4),
  //               child: dataType == '=' 
  //                 ? pw.Column(
  //                     mainAxisSize: pw.MainAxisSize.min,
  //                     children: [
  //                       pw.Divider(thickness: 0.5, height: 1),
  //                       pw.SizedBox(height: 1.5), // ระยะห่างระหว่างเส้นคู่
  //                       pw.Divider(thickness: 0.5, height: 1),
  //                     ],
  //                   )
  //                 : pw.Divider(thickness: 0.5, height: 1), // เส้นเดี่ยวปกติ
  //             ),
  //           );
  //         }

  //         String displayVal = "";
  //         if (type == 'TEXT') {
  //           displayVal = _replaceVars(rawValue?.toString() ?? "", context);
  //         } else {
  //           double val = double.tryParse(rawValue?.toString() ?? '0') ?? 0;
  //           displayVal = val == 0 ? '-' : _currencyFormat.format(val);
  //         }

  //         pw.TextAlign align = pw.TextAlign.left;
  //         if (style['textAlign'] == 'CENTER') align = pw.TextAlign.center;
  //         if (style['textAlign'] == 'RIGHT') align = pw.TextAlign.right;

  //         return pw.Expanded(
  //           flex: flex,
  //           child: pw.Padding(
  //             padding: pw.EdgeInsets.only(left: indent * 20.0),
  //             child: pw.Text(
  //               displayVal,
  //               textAlign: align,
  //               style: pw.TextStyle(
  //                 font: (style['fontWeight'] == 'BOLD' ? fontBold 
  //                           : (style['fontWeight'] == 'ITALIC' ? fontItalic 
  //                               : fontNormal)),
  //                 fontSize: (style['fontSize'] ?? 10).toDouble(),
  //               ),
  //             ),
  //           ),
  //         );
  //       }).toList(),
  //     ),
  //   );
  // }

  pw.Widget _buildPdfRow(Map<String, dynamic> rowData, pw.Context context, pw.Font fontNormal, pw.Font fontBold, pw.Font fontItalic) {
    final List<dynamic> columns = rowData['columns'] ?? [];
    
    // ดึงค่าตั้งค่าการแสดงผลวงเล็บ (ถ้าไม่มีให้ default เป็น true)
    final bool useParenthesis = _reportData?['parenthesis_for_minus'] ?? true;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: columns.map((col) {
          final int flex = col['flex'] ?? 1;
          final String type = col['type'] ?? 'TEXT';
          final String dataType = col['data_type']?.toString() ?? '-';
          final style = col['style'] ?? {};
          final dynamic rawValue = col['value'];
          
          final int indent = int.tryParse(col['indent_level']?.toString() ?? '0') ?? 0;

          if (type == 'DIVIDER') {
            return pw.Expanded(
              flex: flex,
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: dataType == '=' 
                  ? pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Divider(thickness: 0.5, height: 0.5),
                        pw.SizedBox(height: 0.5),
                        pw.Divider(thickness: 2, height: 2),
                      ],
                    )
                  : pw.Divider(thickness: 0.5, height: 1),
              ),
            );
          }

          String displayVal = "";
          if (type == 'TEXT') {
            displayVal = _replaceVars(rawValue?.toString() ?? "", context);
          } else {
            // จัดการตัวเลขและการแสดงผลค่าติดลบ
            double val = double.tryParse(rawValue?.toString() ?? '0') ?? 0;
            if (val == 0) {
              displayVal = '-';
            } else if (val < 0 && useParenthesis) {
              // ถ้าค่าน้อยกว่า 0 และตั้งให้ใส่วงเล็บ ให้ใช้ .abs() เอาเครื่องหมายลบออกก่อนแล้วครอบด้วย ()
              displayVal = '(${_currencyFormat.format(val.abs())})';
            } else {
              // กรณีปกติ (ยอดบวก หรือ ยอดติดลบที่ต้องการให้โชว์เครื่องหมายลบ)
              displayVal = _currencyFormat.format(val);
            }
          }

          pw.TextAlign align = pw.TextAlign.left;
          if (style['textAlign'] == 'CENTER') align = pw.TextAlign.center;
          if (style['textAlign'] == 'RIGHT') align = pw.TextAlign.right;

          return pw.Expanded(
            flex: flex,
            child: pw.Padding(
              padding: pw.EdgeInsets.only(left: indent * 20.0),
              child: pw.Text(
                displayVal,
                textAlign: align,
                style: pw.TextStyle(
                  font: (style['fontWeight'] == 'BOLD' ? fontBold 
                            : (style['fontWeight'] == 'ITALIC' ? fontItalic 
                                : fontNormal)),
                  fontSize: (style['fontSize'] ?? 10).toDouble(),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Excel Export ────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    if (_reportData == null) return;
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'Financial');
      final s = ex['Financial'];

      final List<dynamic> allRows = _reportData!['data'] ?? [];
      final bodyRows = allRows.where((r) => r['row_type'] == 'BODY').toList();
      final reportName = _reportData?['report_name']?.toString() ?? 'รายงานงบการเงิน';

      final _periodLabel = _selectedPeriod?.periodName ?? _selectedYear?.fyCode ?? '';
      final _ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, reportName, bold: true);
      _xlCell(s, 2, 0, '$_periodLabel  |  พิมพ์: $_ts');

      int r = 3;
      for (final rowData in bodyRows) {
        final List<dynamic> columns = (rowData['columns'] as List?) ?? [];
        int c = 0;
        for (final col in columns) {
          final String type = col['type']?.toString() ?? 'TEXT';
          final style = col['style'] ?? {};
          final dynamic rawValue = col['value'];
          final bool bold = style['fontWeight'] == 'BOLD';
          final String textAlign = style['textAlign']?.toString() ?? 'LEFT';
          final HorizontalAlign align = textAlign == 'RIGHT'
              ? HorizontalAlign.Right
              : (textAlign == 'CENTER' ? HorizontalAlign.Center : HorizontalAlign.Left);

          if (type == 'DIVIDER') {
            c++;
            continue;
          }

          if (type == 'TEXT') {
            _xlCell(s, r, c, rawValue?.toString() ?? '', bold: bold, align: align);
          } else {
            final double val = double.tryParse(rawValue?.toString() ?? '0') ?? 0;
            _xlCell(s, r, c, val == 0 ? TextCellValue('') : DoubleCellValue(val), bold: bold, align: HorizontalAlign.Right);
          }
          c++;
        }
        r++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${reportName}_$ts.xlsx');
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

  // ฟังก์ชันหลักสำหรับสร้างหน้า PDF
  Future<Uint8List> _generatePdf(PdfPageFormat baseFormat) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final fontNormal = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final config = _reportData!['page_config'] ?? {};
    final isLandscape = config['orientation'] == 'LANDSCAPE';
    final List<dynamic> margins = config['margins'] ?? [30, 30, 30, 30]; 

    final pageFormat = (isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4.portrait).copyWith(
      marginTop: margins[0].toDouble(),
      marginRight: margins[1].toDouble(),
      marginBottom: margins[2].toDouble(),
      marginLeft: margins[3].toDouble(),
    );

    final List<dynamic> allRows = _reportData!['data'] ?? [];
    final headerRows = allRows.where((r) => r['row_type'] == 'HEADER').toList();
    final bodyRows = allRows.where((r) => r['row_type'] == 'BODY').toList();
    final footerRows = allRows.where((r) => r['row_type'] == 'FOOTER').toList();

    doc.addPage(pw.MultiPage(
      pageFormat: pageFormat,
      theme: pw.ThemeData.withFont(base: fontNormal, bold: fontBold),
      header: (context) => pw.Column(
        children: headerRows.map((row) => _buildPdfRow(row, context, fontNormal, fontBold, fontItalic)).toList(),
      ),
      footer: (context) => pw.Column(
        children: footerRows.map((row) => _buildPdfRow(row, context, fontNormal, fontBold, fontItalic)).toList(),
      ),
      build: (context) {
        return bodyRows.map((row) => _buildPdfRow(row, context, fontNormal, fontBold, fontItalic)).toList();
      },
    ));

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                onPressed: _reportData == null ? null : _exportExcel,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'รีเฟรชรายการ',
              onPressed: _loadMasterData,
            ),
          ],
        ),
        body: _isLoading && _reportMasters.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
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
                            DropdownButtonFormField<Map<String, dynamic>>(
                              isExpanded: true,
                              value: _selectedReport,
                              items: _reportMasters
                                  .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(
                                          "${r['report_code']} - ${r['report_name_thai']}",
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              decoration: const InputDecoration(
                                  labelText: 'งบการเงิน',
                                  border: OutlineInputBorder(),
                                  isDense: true),
                              onChanged: (val) =>
                                  setState(() => _selectedReport = val),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<FiscalYear>(
                              isExpanded: true,
                              value: _selectedYear,
                              items: _fiscalYears
                                  .map((fy) => DropdownMenuItem(
                                      value: fy, child: Text(fy.fyCode)))
                                  .toList(),
                              decoration: const InputDecoration(
                                  labelText: 'ปีบัญชี',
                                  border: OutlineInputBorder(),
                                  isDense: true),
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
                              items: _periods
                                  .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                          "${p.periodNumber} - ${p.periodName}")))
                                  .toList(),
                              decoration: const InputDecoration(
                                  labelText: 'งวดเดือน',
                                  border: OutlineInputBorder(),
                                  isDense: true),
                              onChanged: (val) =>
                                  setState(() => _selectedPeriod = val),
                            ),
                            if (_allowedBranches.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int?>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'สาขา',
                                    border: OutlineInputBorder(),
                                    isDense: true),
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
                            ..._dimTypes.map((t) {
                              final vals = _dimValues[t.typeCode] ?? [];
                              final selectedId = _dimSelections[t.slotNo];
                              final selectedVal = vals.cast<GlDimensionValue?>()
                                  .firstWhere((v) => v?.id == selectedId, orElse: () => null);
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: GlDimensionPickerField(
                                  dimType: t,
                                  values: vals,
                                  selected: selectedVal,
                                  isDense: false,
                                  onSelected: (val) => setState(() =>
                                      _dimSelections[t.slotNo] = val?.id),
                                ),
                              );
                            }),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.analytics),
                                label: const Text('ประมวลผลรายงาน'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange[900],
                                    foregroundColor: Colors.white),
                                onPressed: _runReport,
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
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: Colors.deepOrange[900],
                            indicatorColor: Colors.deepOrange[900],
                            tabs: const [
                              Tab(text: "ตัวอย่างก่อนพิมพ์ (PDF)"),
                              Tab(text: "ตารางข้อมูล"),
                            ],
                          ),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _reportData == null
                                    ? const Center(
                                        child: Text(
                                            'กรุณาเลือกเงื่อนไขและกด "ประมวลผลรายงาน"'))
                                    : TabBarView(
                                        children: [
                                          _buildPdfTab(),
                                          _buildTableTab(),
                                        ],
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
                },
              ),
      ),
    );
  }

  // Widget _buildTableTab() {
  //   final List<dynamic> rows = _reportData!['data'] ?? [];

  //   return Container(
  //     color: Colors.white,
  //     child: ListView.builder(
  //       padding: const EdgeInsets.all(16.0),
  //       itemCount: rows.length,
  //       itemBuilder: (context, index) {
  //         final row = rows[index];
  //         final List<dynamic> cols = row['columns'] ?? [];
  //         final bool isHeaderOrFooter = row['row_type'] == 'HEADER' || row['row_type'] == 'FOOTER';

  //         return Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 4.0),
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: cols.map((col) {
  //               final int flex = col['flex'] ?? 1;
  //               final String type = col['type'] ?? 'TEXT';
  //               final String dataType = col['data_type']?.toString() ?? '-'; // ดึงค่า data_type
  //               final style = col['style'] ?? {};
  //               final dynamic rawValue = col['value'];

  //               final int indent = int.tryParse(col['indent_level']?.toString() ?? '0') ?? 0;

  //               // ==========================================
  //               // 1. กรณีเป็นเส้นคั่น (DIVIDER) รองรับเส้นคู่
  //               // ==========================================
  //               if (type == 'DIVIDER') {
  //                 return Expanded(
  //                   flex: flex,
  //                   child: Padding(
  //                     padding: const EdgeInsets.symmetric(vertical: 8.0),
  //                     child: dataType == '='
  //                       ? const Column(
  //                           mainAxisSize: MainAxisSize.min,
  //                           children: [
  //                             Divider(thickness: 1, color: Colors.black87, height: 2),
  //                             SizedBox(height: 1), // ระยะห่างระหว่างเส้นคู่
  //                             Divider(thickness: 2, color: Colors.black87, height: 2),
  //                           ],
  //                         )
  //                       : const Divider(thickness: 1, color: Colors.black87, height: 2), // เส้นเดี่ยวปกติ
  //                   ),
  //                 );
  //               }

  //               // 2. กรณีเป็นข้อความหรือตัวเลข
  //               String displayVal = "";
  //               if (type == 'TEXT') {
  //                 displayVal = _replaceVars(rawValue?.toString() ?? "", null);
  //               } else {
  //                 double val = double.tryParse(rawValue?.toString() ?? '0') ?? 0;
  //                 displayVal = val == 0 ? '-' : _currencyFormat.format(val);
  //               }

  //               TextAlign align = TextAlign.left;
  //               if (style['textAlign'] == 'CENTER') align = TextAlign.center;
  //               if (style['textAlign'] == 'RIGHT') align = TextAlign.right;

  //               FontWeight weight = (style['fontWeight'] == 'BOLD' || isHeaderOrFooter)
  //                   ? FontWeight.bold
  //                   : FontWeight.normal;

  //               return Expanded(
  //                 flex: flex,
  //                 child: Padding(
  //                   padding: EdgeInsets.only(left: indent * 20.0),
  //                   child: Text(
  //                     displayVal,
  //                     textAlign: align,
  //                     style: TextStyle(
  //                       fontSize: (style['fontSize'] ?? 11).toDouble(),
  //                       fontWeight: weight,
  //                     ),
  //                   ),
  //                 ),
  //               );
  //             }).toList().cast<Widget>(),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

Widget _buildTableTab() {
    final List<dynamic> rows = _reportData!['data'] ?? [];
    
    // ดึงค่าตั้งค่าการแสดงผลวงเล็บ
    final bool useParenthesis = _reportData?['parenthesis_for_minus'] ?? true;

    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final List<dynamic> cols = row['columns'] ?? [];
          final bool isHeaderOrFooter = row['row_type'] == 'HEADER' || row['row_type'] == 'FOOTER';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cols.map((col) {
                final int flex = col['flex'] ?? 1;
                final String type = col['type'] ?? 'TEXT';
                final String dataType = col['data_type']?.toString() ?? '-';
                final style = col['style'] ?? {};
                final dynamic rawValue = col['value'];

                final int indent = int.tryParse(col['indent_level']?.toString() ?? '0') ?? 0;

                if (type == 'DIVIDER') {
                  return Expanded(
                    flex: flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: dataType == '='
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(thickness: 0.5, color: Colors.black87, height: 0.5),
                              SizedBox(height: 0.5),
                              Divider(thickness: 2, color: Colors.black87, height: 2),
                            ],
                          )
                        : const Divider(thickness: 1, color: Colors.black87, height: 2),
                    ),
                  );
                }

                String displayVal = "";
                if (type == 'TEXT') {
                  displayVal = _replaceVars(rawValue?.toString() ?? "", null);
                } else {
                  // จัดการตัวเลขและการแสดงผลค่าติดลบ
                  double val = double.tryParse(rawValue?.toString() ?? '0') ?? 0;
                  if (val == 0) {
                    displayVal = '-';
                  } else if (val < 0 && useParenthesis) {
                    // ครอบวงเล็บสำหรับค่าติดลบ
                    displayVal = '(${_currencyFormat.format(val.abs())})';
                  } else {
                    displayVal = _currencyFormat.format(val);
                  }
                }

                TextAlign align = TextAlign.left;
                if (style['textAlign'] == 'CENTER') align = TextAlign.center;
                if (style['textAlign'] == 'RIGHT') align = TextAlign.right;

                FontWeight weight = (style['fontWeight'] == 'BOLD' || isHeaderOrFooter)
                    ? FontWeight.bold
                    : FontWeight.normal;

                return Expanded(
                  flex: flex,
                  child: Padding(
                    padding: EdgeInsets.only(left: indent * 20.0),
                    child: Text(
                      displayVal,
                      textAlign: align,
                      style: TextStyle(
                        fontSize: (style['fontSize'] ?? 11).toDouble(),
                        fontWeight: weight,
                      ),
                    ),
                  ),
                );
              }).toList().cast<Widget>(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPdfTab() {
    return Container(
      color: Colors.grey[200],
      child: PdfPreview(
        build: (format) => _generatePdf(format),
        initialPageFormat: PdfPageFormat.a4,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
