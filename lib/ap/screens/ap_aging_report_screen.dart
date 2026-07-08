import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_aging_report_service.dart';
import '../services/ap_vendor_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../../sa/models/company.dart';
import '../../sa/models/user_branch.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ap_vendor_group_multi_picker.dart';

class ApAgingReportScreen extends StatefulWidget {
  const ApAgingReportScreen({super.key});

  @override
  State<ApAgingReportScreen> createState() => _ApAgingReportScreenState();
}

class _ApAgingReportScreenState extends State<ApAgingReportScreen> {
  final ApAgingReportService  _reportService  = ApAgingReportService();
  final CompanyService        _companyService = CompanyService();
  final AuthService           _authService    = AuthService();
  final ApVendorGroupService  _groupService   = ApVendorGroupService();
  final ApVendorService       _vendorService  = ApVendorService();
  final TextEditingController _daysIntervalCtrl =
      TextEditingController(text: '30');

  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;

  Company? _company;
  Map<String, String>? _headers;

  DateTime         _asOfDate        = DateTime.now();
  List<UserBranch> _allowedBranches = [];
  int?             _selectedBranchId;

  List<ApVendorGroup> _vendorGroups     = [];
  List<int>           _selectedGroupIds = [];
  String? _vendorCodeFrom;
  String? _vendorCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';

  int    _overdueColumnCount = 3;
  bool   _showDetail = false;
  String _sortOrder  = 'none'; // 'none' | 'desc' | 'asc'

  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _allowedBranches = _authService.allowedBranches;
    _loadMasterData();
  }

  @override
  void dispose() {
    _daysIntervalCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ──────────────────────────────────────────────────────────────────

  int get _columnInterval =>
      (int.tryParse(_daysIntervalCtrl.text) ?? 30).clamp(1, 9999);

  int get _totalBuckets => _overdueColumnCount + 1;

  List<String> get _dynamicBucketLabels {
    final I = _columnInterval;
    final labels = <String>['ยังไม่ครบกำหนด'];
    for (int i = 0; i < _overdueColumnCount - 1; i++) {
      labels.add('${i * I + 1}-${(i + 1) * I}');
    }
    labels.add('เกิน ${(_overdueColumnCount - 1) * I}');
    return labels;
  }

  int _bucketDynamic(num days) {
    if (days <= 0) return 0;
    final I = _columnInterval;
    for (int i = 1; i < _overdueColumnCount; i++) {
      if (days <= i * I) return i;
    }
    return _overdueColumnCount;
  }

  // ─── data ─────────────────────────────────────────────────────────────────────

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
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getAgingReport(
        asOfDate:       DateFormat('yyyy-MM-dd').format(_asOfDate),
        branchId:       _selectedBranchId,
        vendorCodeFrom: _vendorCodeFrom,
        vendorCodeTo:   _vendorCodeTo,
      );

      // client-side filtering
      var filtered = raw
          .where((v) => ((v['invoices'] as List?) ?? []).isNotEmpty)
          .toList();
      if (_selectedGroupIds.isNotEmpty) {
        filtered = filtered
            .where((v) => _selectedGroupIds.contains(v['vendor_group_id']))
            .toList();
      }
      if (_vendorCodeFrom != null && _vendorCodeFrom!.isNotEmpty) {
        filtered = filtered
            .where((v) =>
                (v['vendor_code'] as String? ?? '')
                    .compareTo(_vendorCodeFrom!) >= 0)
            .toList();
      }
      if (_vendorCodeTo != null && _vendorCodeTo!.isNotEmpty) {
        filtered = filtered
            .where((v) =>
                (v['vendor_code'] as String? ?? '')
                    .compareTo(_vendorCodeTo!) <= 0)
            .toList();
      }

      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่พบข้อมูลเจ้าหนี้คงค้าง ณ วันที่ที่เลือก')));
      }

      setState(() { _reportData = filtered; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onColumnSettingChanged() {
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
  }

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'Aging');
      final s      = ex['Aging'];
      final hdrBg  = ExcelColor.fromHexString('#92D050');
      final totBg  = ExcelColor.fromHexString('#BDD7EE');
      final detBg  = ExcelColor.fromHexString('#F2F2F2');

      final bucketLabels = _dynamicBucketLabels;
      final totalBuckets = _totalBuckets;

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'รายงานเจ้าหนี้คงค้างตามอายุหนี้', bold: true);
      _xlCell(s, 2, 0, 'ณ วันที่: ${DateFormat('dd/MM/yyyy').format(_asOfDate)}  |  พิมพ์: $ts');

      int r = 3;
      _xlCell(s, r, 0, 'รหัสผู้ขาย', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, 'ชื่อผู้ขาย',  bg: hdrBg, bold: true);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, bucketLabels[b], bg: hdrBg, bold: true,
            align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, 'รวม', bg: hdrBg, bold: true,
          align: HorizontalAlign.Right);
      _xlCell(s, r, 3 + totalBuckets, 'วงเงินเครดิต', bg: hdrBg, bold: true,
          align: HorizontalAlign.Right);
      r++;

      final grandBuckets = List<double>.filled(totalBuckets, 0.0);
      double grandTotal = 0.0;

      for (final vend in _reportData) {
        final code     = vend['vendor_code']    as String? ?? '';
        final name     = vend['vendor_name_th'] as String? ?? '';
        final invoices = (vend['invoices'] as List?) ?? [];
        final custBuckets = List<double>.filled(totalBuckets, 0.0);
        for (final inv in invoices) {
          final days = (inv['days_overdue'] as num?) ?? 0;
          final amt  = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
          final b    = _bucketDynamic(days);
          custBuckets[b] += amt;
          if (_showDetail) {
            _xlCell(s, r, 0, inv['doc_no']?.toString() ?? '', bg: detBg);
            _xlCell(s, r, 1, inv['doc_date']?.toString() ?? '', bg: detBg);
            for (int bi = 0; bi < totalBuckets; bi++) {
              _xlCell(s, r, 2 + bi,
                  bi == b ? DoubleCellValue(amt) : TextCellValue('-'),
                  bg: detBg, align: HorizontalAlign.Right);
            }
            _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(amt),
                bg: detBg, align: HorizontalAlign.Right);
            _xlCell(s, r, 3 + totalBuckets, TextCellValue(''), bg: detBg);
            r++;
          }
        }
        final custTotal = custBuckets.fold(0.0, (a, b) => a + b);
        _xlCell(s, r, 0, code);
        _xlCell(s, r, 1, name);
        for (int b = 0; b < totalBuckets; b++) {
          _xlCell(s, r, 2 + b,
              custBuckets[b] == 0
                  ? TextCellValue('-')
                  : DoubleCellValue(custBuckets[b]),
              align: HorizontalAlign.Right);
          grandBuckets[b] += custBuckets[b];
        }
        final custCreditLimit = (vend['credit_limit'] as num?)?.toDouble() ?? 0.0;
        _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(custTotal),
            align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 3 + totalBuckets,
            custCreditLimit > 0
                ? DoubleCellValue(custCreditLimit)
                : TextCellValue('-'),
            align: HorizontalAlign.Right);
        grandTotal += custTotal;
        r++;
      }

      _xlCell(s, r, 0, 'รวมทั้งสิ้น', bg: totBg, bold: true);
      _xlCell(s, r, 1, '', bg: totBg);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, DoubleCellValue(grandBuckets[b]),
            bg: totBg, bold: true, align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(grandTotal),
          bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 3 + totalBuckets, TextCellValue('-'),
          bg: totBg, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final fileTs = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'รายงานเจ้าหนี้คงค้างตามอายุหนี้_$fileTs.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue
        ? v
        : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName     = _headers?['UserName'] ?? '(ไม่ระบุชื่อ)';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final asOfLine     = 'ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_asOfDate)}';

    final bucketLabels = _dynamicBucketLabels;
    final totalBuckets = _totalBuckets;
    final showDetail   = _showDetail;
    final sortOrder    = _sortOrder;

    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _allowedBranches.firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _allowedBranches.first);
      conditions.add('สาขา: ${b.branchCode} ${b.branchNameThai}');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _vendorGroups.firstWhere((g) => g.id == id,
            orElse: () => _vendorGroups.first);
        return '${g.groupCode} ${g.groupNameThai}';
      }).join(', ');
      conditions.add('กลุ่มผู้ขาย: $names');
    }
    if ((_vendorCodeFrom ?? '').isNotEmpty || (_vendorCodeTo ?? '').isNotEmpty) {
      final from = _vendorCodeFrom ?? '';
      final to   = _vendorCodeTo   ?? '';
      conditions.add(
          'รหัสผู้ขาย: ${from.isEmpty ? '(ทั้งหมด)' : from} – ${to.isEmpty ? '(ทั้งหมด)' : to}');
    }
    conditions.add('คอลัมน์ครบกำหนด: $_overdueColumnCount คอลัมน์  ทุก $_columnInterval วัน');
    if (sortOrder != 'none') {
      conditions.add('เรียงยอดหนี้: ${sortOrder == 'desc' ? 'มากไปน้อย' : 'น้อยไปมาก'}');
    }
    if (showDetail) conditions.add('แสดงรายละเอียดใบแจ้งหนี้');
    final conditionLine = '* ${conditions.join(' | ')}';

    final numFmt = NumberFormat('#,##0.00', 'en_US');
    String fmtAmt(double v) => v == 0 ? '-' : numFmt.format(v);
    String fmtDate(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      try {
        final local = DateTime.parse(raw).toLocal();
        return DateFormat('dd/MM/yyyy')
            .format(DateTime(local.year, local.month, local.day));
      } catch (_) { return raw; }
    }

    // compute per-vendor buckets
    final rows = _reportData.map((v) {
      final buckets = List<double>.filled(totalBuckets, 0);
      for (final inv in (v['invoices'] as List? ?? [])) {
        final days = (inv['days_overdue'] as num?) ?? 0;
        final bal  = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
        buckets[_bucketDynamic(days)] += bal;
      }
      return (
        code:        v['vendor_code']    as String? ?? '',
        name:        v['vendor_name_th'] as String? ?? '',
        buckets:     buckets,
        total:       buckets.fold(0.0, (s, v) => s + v),
        creditLimit: (v['credit_limit'] as num?)?.toDouble() ?? 0.0,
        invoices:    (v['invoices'] as List? ?? []).cast<Map<String, dynamic>>().toList(),
      );
    }).toList();

    if (sortOrder == 'desc') {
      rows.sort((a, b) => b.total.compareTo(a.total));
    } else if (sortOrder == 'asc') {
      rows.sort((a, b) => a.total.compareTo(b.total));
    }

    final grand = List<double>.filled(totalBuckets, 0);
    for (final r in rows) {
      for (int i = 0; i < totalBuckets; i++) { grand[i] += r.buckets[i]; }
    }
    final grandTotal = grand.fold(0.0, (s, v) => s + v);

    final colW = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(7),
      1: const pw.FlexColumnWidth(15),
    };
    for (int i = 0; i < totalBuckets; i++) {
      colW[i + 2] = const pw.FlexColumnWidth(9);
    }
    colW[totalBuckets + 2] = const pw.FlexColumnWidth(10);
    colW[totalBuckets + 3] = const pw.FlexColumnWidth(10);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text('รายงานเจ้าหนี้คงค้างตามอายุหนี้',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 3, child: pw.Text('', style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text(asOfLine,
                  textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 3, child: pw.Text('พิมพ์โดย $userName',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 10, child: pw.Text(conditionLine,
                  textAlign: pw.TextAlign.left, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text('พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) {
          final hdrStyle    = pw.TextStyle(font: fontBold,   fontSize: 9);
          final cellStyle   = pw.TextStyle(font: font,       fontSize: 9);
          final boldStyle   = pw.TextStyle(font: fontBold,   fontSize: 9);
          final detailStyle = pw.TextStyle(font: fontItalic, fontSize: 8);
          const edg    = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2);
          const edgDtl = pw.EdgeInsets.fromLTRB(8, 1, 3, 1);

          pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
              pw.Container(padding: edg,
                  child: pw.Text(t, style: hdrStyle, textAlign: a));

          pw.Widget dCell(String t,
                  {pw.TextAlign a = pw.TextAlign.left, pw.TextStyle? s, pw.EdgeInsets? p}) =>
              pw.Container(padding: p ?? edg,
                  child: pw.Text(t, style: s ?? cellStyle, textAlign: a));

          pw.Widget amtCell(double v, {bool bold = false, pw.TextStyle? s}) =>
              pw.Container(padding: edg,
                  child: pw.Text(fmtAmt(v),
                      style: s ?? (bold ? boldStyle : cellStyle),
                      textAlign: pw.TextAlign.right));

          pw.TableRow summaryRow(
              String code, String name, List<double> bks, double tot,
              {bool isTotal = false, PdfColor? bg, double creditLimit = 0}) {
            final s = isTotal ? boldStyle : cellStyle;
            return pw.TableRow(
              decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
              children: [
                dCell(code, s: s),
                dCell(name, s: s),
                ...bks.map((v) => amtCell(v, bold: isTotal)),
                amtCell(tot, bold: isTotal),
                isTotal
                    ? dCell('-', s: s, a: pw.TextAlign.right)
                    : amtCell(creditLimit),
              ],
            );
          }

          pw.TableRow invRow(Map<String, dynamic> inv) {
            final docNo   = inv['doc_no']  as String? ?? '';
            final docDate = fmtDate(inv['doc_date'] as String?);
            final dueDate = fmtDate(inv['due_date']  as String?);
            final days    = (inv['days_overdue'] as num?) ?? 0;
            final bal     = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
            final bucket  = _bucketDynamic(days);

            final dateParts = <String>[];
            if (docDate.isNotEmpty) dateParts.add('วันที่:$docDate');
            if (dueDate.isNotEmpty) dateParts.add('ครบ:$dueDate');
            final dateText = dateParts.join('  ');

            final bks = List<double>.filled(totalBuckets, 0);
            bks[bucket] = bal;

            return pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor(0.96, 0.96, 0.96)),
              children: [
                dCell(docNo,    s: detailStyle, p: edgDtl),
                dCell(dateText, s: detailStyle, p: edgDtl),
                ...bks.map((v) => amtCell(v, s: detailStyle)),
                amtCell(bal, s: detailStyle),
                dCell('', s: detailStyle),
              ],
            );
          }

          const cHeader = PdfColor(0.82, 0.87, 0.90);
          const cTotal  = PdfColor(0.75, 0.85, 0.88);

          final tableRows = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: cHeader),
              children: [
                hCell(showDetail ? 'รหัส / ใบแจ้งหนี้' : 'รหัส', a: pw.TextAlign.left),
                hCell(showDetail ? 'ชื่อผู้ขาย / วันที่เอกสาร,ครบกำหนด' : 'ชื่อผู้ขาย', a: pw.TextAlign.left),
                ...bucketLabels.map((l) => hCell(l)),
                hCell('รวม'),
                hCell('วงเงินเครดิต'),
              ],
            ),
          ];

          for (final r in rows) {
            final isOver = r.creditLimit > 0 && r.total > r.creditLimit;
            tableRows.add(summaryRow(r.code, r.name, r.buckets, r.total,
                creditLimit: r.creditLimit,
                bg: isOver ? const PdfColor(1.0, 0.87, 0.87) : null));
            if (showDetail) {
              for (final inv in r.invoices) {
                tableRows.add(invRow(inv));
              }
            }
          }

          tableRows.add(summaryRow('', 'รวมทั้งหมด', grand, grandTotal,
              isTotal: true, bg: cTotal));

          return [
            pw.Table(
              border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
              columnWidths: colW,
              children: tableRows,
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  // ─── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.account_balance_wallet, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text('รายงานเจ้าหนี้คงค้างตามอายุหนี้'),
        ]),
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
                      icon: Icon(
                          _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
                      onPressed: () =>
                          setState(() => _isFilterExpanded = !_isFilterExpanded),
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
                                    const Text('เงื่อนไขรายงาน',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 16),

                                    // ณ วันที่
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _asOfDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => _asOfDate = picked);
                                        }
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

                                    // สาขา
                                    if (_allowedBranches.isNotEmpty) ...[
                                      const SizedBox(height: 12),
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

                                    // กลุ่มผู้ขาย
                                    const SizedBox(height: 12),
                                    ApVendorGroupMultiPicker(
                                      groups: _vendorGroups,
                                      selectedIds: _selectedGroupIds,
                                      label: 'กลุ่มผู้ขาย',
                                      onChanged: (v) =>
                                          setState(() => _selectedGroupIds = v),
                                    ),

                                    // รหัสผู้ขาย ตั้งแต่ / ถึง
                                    const SizedBox(height: 12),
                                    _buildVendorCodeField(
                                      label: 'รหัสผู้ขาย ตั้งแต่',
                                      displayText: _fromLabel,
                                      onPick: () => _pickVendor(isFrom: true),
                                      onClear: () => setState(() {
                                        _vendorCodeFrom = null;
                                        _fromLabel = '';
                                      }),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildVendorCodeField(
                                      label: 'รหัสผู้ขาย ถึง',
                                      displayText: _toLabel,
                                      onPick: () => _pickVendor(isFrom: false),
                                      onClear: () => setState(() {
                                        _vendorCodeTo = null;
                                        _toLabel = '';
                                      }),
                                    ),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // จำนวนคอลัมน์
                                    DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      value: _overdueColumnCount,
                                      decoration: const InputDecoration(
                                          labelText: 'จำนวนคอลัมน์ที่ครบกำหนดแล้ว',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: [2, 3, 4, 5]
                                          .map((n) => DropdownMenuItem<int>(
                                              value: n, child: Text('$n คอลัมน์')))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _overdueColumnCount = v);
                                          _onColumnSettingChanged();
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // จำนวนวันต่อคอลัมน์
                                    TextField(
                                      controller: _daysIntervalCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      decoration: const InputDecoration(
                                        labelText: 'จำนวนวันต่อคอลัมน์',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        suffixText: 'วัน',
                                      ),
                                      onEditingComplete: _onColumnSettingChanged,
                                    ),
                                    const SizedBox(height: 12),

                                    // เรียงตามยอดหนี้รวม
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _sortOrder,
                                      decoration: const InputDecoration(
                                          labelText: 'เรียงตามยอดหนี้รวม',
                                          border: OutlineInputBorder(),
                                          isDense: true),
                                      items: const [
                                        DropdownMenuItem(value: 'none', child: Text('— ไม่ระบุ —')),
                                        DropdownMenuItem(value: 'desc', child: Text('มากไปน้อย ↓')),
                                        DropdownMenuItem(value: 'asc',  child: Text('น้อยไปมาก ↑')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _sortOrder = v);
                                          _onColumnSettingChanged();
                                        }
                                      },
                                    ),

                                    const SizedBox(height: 8),
                                    const Divider(height: 1),

                                    // แสดงรายละเอียด
                                    Row(children: [
                                      const Expanded(
                                        child: Text('แสดงรายละเอียดใบแจ้งหนี้',
                                            style: TextStyle(fontSize: 13)),
                                      ),
                                      Switch(
                                        value: _showDetail,
                                        activeColor: Colors.blueGrey[800],
                                        onChanged: (v) {
                                          setState(() => _showDetail = v);
                                          _onColumnSettingChanged();
                                        },
                                      ),
                                    ]),
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
                                  label: const Text('ประมวลผลรายงาน'),
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
                              (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth);
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
                              ? const Center(
                                  child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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

  // ── vendor code picker ────────────────────────────────────────────────────────

  Future<void> _pickVendor({required bool isFrom}) async {
    final result = await showDialog<ApVendor>(
      context: context,
      builder: (_) => _VendorSearchDialog(vendorService: _vendorService),
    );
    if (result != null && mounted) {
      setState(() {
        final label = '${result.vendorCode}  ${result.vendorNameTh}';
        if (isFrom) {
          _vendorCodeFrom = result.vendorCode;
          _fromLabel      = label;
        } else {
          _vendorCodeTo = result.vendorCode;
          _toLabel      = label;
        }
      });
    }
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
                child: Icon(Icons.clear, size: 16, color: Colors.grey),
              ),
            ),
          InkWell(
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.search, size: 18, color: Colors.blueGrey[800]),
            ),
          ),
        ]),
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
}

// ── vendor search dialog ──────────────────────────────────────────────────────

class _VendorSearchDialog extends StatefulWidget {
  final ApVendorService vendorService;
  const _VendorSearchDialog({required this.vendorService});

  @override
  State<_VendorSearchDialog> createState() => _VendorSearchDialogState();
}

class _VendorSearchDialogState extends State<_VendorSearchDialog> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ApVendor> _vendors = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _search(''); }

  @override
  void dispose() { _searchCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final list = await widget.vendorService.fetchRows(
          search: query.trim().isEmpty ? null : query.trim());
      if (mounted) setState(() => _vendors = list);
    } catch (_) {
      if (mounted) setState(() => _vendors = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blueGrey[800],
            child: const Text('ค้นหาผู้ขาย',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'ค้นหาจากรหัสหรือชื่อผู้ขาย',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: _search,
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(children: [
              SizedBox(width: 100,
                  child: Text('รหัส', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('ชื่อผู้ขาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vendors.isEmpty
                    ? const Center(
                        child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: _scrollCtrl,
                        itemCount: _vendors.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 12),
                        itemBuilder: (ctx, i) {
                          final v = _vendors[i];
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, v),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 100,
                                    child: Text(v.vendorCode,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Expanded(child: Text(v.vendorNameTh,
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
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก')),
            ]),
          ),
        ]),
      ),
    );
  }
}
