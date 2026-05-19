import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/ar_aging_report_service.dart';
import '../../sa/models/company.dart';
import '../../sa/models/user_branch.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';

// ─── aging bucket helper ──────────────────────────────────────────────────────
const _bucketLabels = [
  'ยังไม่ครบกำหนด', '1-30 วัน', '31-60 วัน',
  '61-90 วัน', '91-120 วัน', 'เกิน 120 วัน',
];
const _bucketCount = 6;

int _bucket(num days) {
  if (days <= 0)   return 0;
  if (days <= 30)  return 1;
  if (days <= 60)  return 2;
  if (days <= 90)  return 3;
  if (days <= 120) return 4;
  return 5;
}

// ─── screen ───────────────────────────────────────────────────────────────────
class ArAgingReportScreen extends StatefulWidget {
  const ArAgingReportScreen({super.key});

  @override
  State<ArAgingReportScreen> createState() => _ArAgingReportScreenState();
}

class _ArAgingReportScreenState extends State<ArAgingReportScreen> {
  final ArAgingReportService _reportService = ArAgingReportService();
  final CompanyService _companyService = CompanyService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 300.0;
  bool _isDraggingDivider = false;

  Company? _company;
  Map<String, String>? _headers;

  DateTime _asOfDate = DateTime.now();
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;

  // รายงานที่สร้างแล้ว (list of customer map พร้อม invoices)
  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _allowedBranches = _authService.allowedBranches;
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    _headers = await _authService.getAuthHeader();
    _company = await _companyService.fetchCompany();
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getAgingReport(
        asOfDate: DateFormat('yyyy-MM-dd').format(_asOfDate),
        branchId: _selectedBranchId,
      );
      // กรองเฉพาะลูกค้าที่มียอดคงเหลือจริง
      final filtered = raw.where((c) {
        final invoices = (c['invoices'] as List?) ?? [];
        return invoices.isNotEmpty;
      }).toList();
      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลลูกหนี้คงค้าง ณ วันที่ที่เลือก')));
      }
      setState(() => _reportData = filtered);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PDF builder ──────────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc      = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName    = _headers?['UserName'] ?? '(ไม่ระบุชื่อ)';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final asOfLine    = 'ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_asOfDate)}';

    // เงื่อนไขรายงาน (แถวที่ 3 ซ้าย)
    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _allowedBranches.firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _allowedBranches.first);
      conditions.add('สาขา: ${b.branchCode} ${b.branchNameThai}');
    }
    final conditionLine = conditions.isNotEmpty ? '* ${conditions.join(', ')}' : '';

    final fmt = NumberFormat('#,##0.00', 'en_US');
    String fmtAmt(double v) => v == 0 ? '-' : fmt.format(v);

    // คำนวณ buckets ต่อลูกค้า
    final rows = _reportData.map((c) {
      final buckets = List<double>.filled(_bucketCount, 0);
      for (final inv in (c['invoices'] as List? ?? [])) {
        final days = (inv['days_overdue'] as num?) ?? 0;
        final bal  = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
        buckets[_bucket(days)] += bal;
      }
      return (
        code:    c['customer_code'] as String? ?? '',
        name:    c['customer_name_th'] as String? ?? '',
        buckets: buckets,
        total:   buckets.fold(0.0, (s, v) => s + v),
      );
    }).toList();

    // grand total
    final grand = List<double>.filled(_bucketCount, 0);
    for (final r in rows) {
      for (int i = 0; i < _bucketCount; i++) grand[i] += r.buckets[i];
    }
    final grandTotal = grand.fold(0.0, (s, v) => s + v);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          children: [
            // แถว 1: บริษัท | ชื่อรายงาน bold | หน้า X/Y
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(companyName,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text('รายงานลูกหนี้คงค้างตามอายุ',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                        'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            // แถว 2: ว่าง | ณ วันที่ | พิมพ์โดย
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(flex: 3,
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(flex: 7,
                    child: pw.Text(asOfLine,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(flex: 3,
                    child: pw.Text('พิมพ์โดย $userName',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            // แถว 3: เงื่อนไข | พิมพ์เมื่อ
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(flex: 10,
                    child: pw.Text(conditionLine,
                        textAlign: pw.TextAlign.left,
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 3,
                    child: pw.Text('พิมพ์เมื่อ $printDateStr',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) {
          final hdrStyle  = pw.TextStyle(font: fontBold, fontSize: 9);
          final cellStyle = pw.TextStyle(font: font, fontSize: 9);
          final boldStyle = pw.TextStyle(font: fontBold, fontSize: 9);

          const edg = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3);

          pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
              pw.Container(
                padding: edg,
                child: pw.Text(t, style: hdrStyle, textAlign: a),
              );

          pw.Widget dCell(String t, {pw.TextAlign a = pw.TextAlign.left, pw.TextStyle? s}) =>
              pw.Container(padding: edg,
                  child: pw.Text(t, style: s ?? cellStyle, textAlign: a));

          pw.Widget amtCell(double v, {bool bold = false}) =>
              pw.Container(padding: edg,
                  child: pw.Text(fmtAmt(v),
                      style: bold ? boldStyle : cellStyle,
                      textAlign: pw.TextAlign.right));

          // column widths (relative flex)
          final colW = {
            0: const pw.FlexColumnWidth(6),   // รหัส
            1: const pw.FlexColumnWidth(16),  // ชื่อ
            2: const pw.FlexColumnWidth(9),   // bucket ×6
            3: const pw.FlexColumnWidth(9),
            4: const pw.FlexColumnWidth(9),
            5: const pw.FlexColumnWidth(9),
            6: const pw.FlexColumnWidth(9),
            7: const pw.FlexColumnWidth(9),
            8: const pw.FlexColumnWidth(10),  // รวม
          };

          pw.TableRow dataRow(
              String code, String name, List<double> bks, double tot,
              {bool isTotal = false, PdfColor? bg}) {
            final s = isTotal ? boldStyle : cellStyle;
            return pw.TableRow(
              decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
              children: [
                dCell(code, s: s),
                dCell(name, s: s),
                ...bks.map((v) => amtCell(v, bold: isTotal)),
                amtCell(tot, bold: isTotal),
              ],
            );
          }

          return [
            pw.Table(
              border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
              columnWidths: colW,
              children: [
                // header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor(0.87, 0.94, 0.92)),
                  children: [
                    hCell('รหัส', a: pw.TextAlign.left),
                    hCell('ชื่อลูกค้า', a: pw.TextAlign.left),
                    ..._bucketLabels.map((l) => hCell(l)),
                    hCell('รวม'),
                  ],
                ),
                // data rows
                ...rows.map((r) => dataRow(r.code, r.name, r.buckets, r.total)),
                // grand total
                dataRow('', 'รวมทั้งหมด', grand, grandTotal,
                    isTotal: true,
                    bg: const PdfColor(0.87, 0.94, 0.92)),
              ],
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.account_balance_wallet, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text('รายงานลูกหนี้คงค้างตามอายุ'),
        ]),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _company == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxFilterWidth =
                  (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── toggle button ──
                  Container(
                    width: 36,
                    color: Colors.teal[800],
                    child: IconButton(
                      icon: Icon(
                        _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                        color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
                      onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                    ),
                  ),
                  // ── filter panel ──
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
                                // ── ณ วันที่ ──
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _asOfDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) setState(() => _asOfDate = picked);
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'ณ วันที่',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                                    ),
                                    child: Text(DateFormat('dd/MM/yyyy').format(_asOfDate)),
                                  ),
                                ),
                                // ── สาขา ──
                                if (_allowedBranches.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<int?>(
                                    isExpanded: true,
                                    value: _selectedBranchId,
                                    decoration: const InputDecoration(
                                        labelText: 'สาขา',
                                        border: OutlineInputBorder(),
                                        isDense: true),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                          value: null, child: Text('— ทุกสาขา —')),
                                      ..._allowedBranches.map((b) =>
                                          DropdownMenuItem<int?>(
                                            value: b.branchId,
                                            child: Text(
                                                '${b.branchCode}  ${b.branchNameThai}',
                                                overflow: TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (v) => setState(() => _selectedBranchId = v),
                                  ),
                                ],
                                const Spacer(),
                                // ── ปุ่มเดียว ──
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('ประมวลผลรายงาน'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[800],
                                        foregroundColor: Colors.white),
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
                  // ── draggable divider ──
                  if (_isFilterExpanded)
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        onHorizontalDragStart: (_) =>
                            setState(() => _isDraggingDivider = true),
                        onHorizontalDragUpdate: (d) => setState(() {
                          _filterPanelWidth = (_filterPanelWidth + d.delta.dx)
                              .clamp(200.0, maxFilterWidth);
                        }),
                        onHorizontalDragEnd: (_) =>
                            setState(() => _isDraggingDivider = false),
                        child: Container(width: 5, color: Colors.grey[400]),
                      ),
                    ),
                  // ── PDF preview panel ──
                  Expanded(
                    child: Container(
                      color: Colors.grey[200],
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _reportData.isEmpty
                              ? const Center(
                                  child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
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
}
