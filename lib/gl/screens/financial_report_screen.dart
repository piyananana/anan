// File: screens/gl/financial_report_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
import '../services/financial_report_service.dart';
import '../../sa/models/company.dart';
import '../../sa/services/company_service.dart';
import '../../sa/services/auth_service.dart';

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

  bool _isLoading = false;
  Company? _company;
  Map<String, String>? _headers;

  List<Map<String, dynamic>> _reportMasters = [];
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];

  Map<String, dynamic>? _selectedReport;
  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;

  Map<String, dynamic>? _reportData;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    try {
      _headers = await _authService.getAuthHeader();
      _company = await _companyService.fetchCompany();

      _reportMasters = await _reportService.fetchReportMasters();
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
          _selectedReport!['id'], _selectedPeriod!.id);
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

  // ฟังก์ชันหลักสำหรับสร้างหน้า PDF
  Future<Uint8List> _generatePdf(PdfPageFormat baseFormat) async {
    final doc = pw.Document();
    final fontNormal = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();
    final fontItalic = await PdfGoogleFonts.sarabunItalic();

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
          title: const Text('รายงานงบการเงิน (Financial Report)'),
          backgroundColor: Colors.deepOrange[900],
          foregroundColor: Colors.white,
        ),
        body: _isLoading && _reportMasters.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ResizableContainer(
                direction: Axis.horizontal,
                children: [
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
                            DropdownButtonFormField<Map<String, dynamic>>(
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
                              isExpanded: true,
                              onChanged: (val) =>
                                  setState(() => _selectedReport = val),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<FiscalYear>(
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
                  ResizableChild(
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
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
