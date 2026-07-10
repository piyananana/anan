import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../sa/utils/menu_scope.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_aging_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/salesperson.dart';
import '../../cd/services/salesperson_service.dart';
import '../../sa/models/company.dart';
import '../../sa/models/user_branch.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

class ArDueReportScreen extends StatefulWidget {
  const ArDueReportScreen({super.key});

  @override
  State<ArDueReportScreen> createState() => _ArDueReportScreenState();
}

class _ArDueReportScreenState extends State<ArDueReportScreen> {
  final ArAgingReportService _reportService = ArAgingReportService();
  final CompanyService _companyService = CompanyService();
  final AuthService _authService = AuthService();
  final ArCustomerGroupService _groupService = ArCustomerGroupService();
  final ArCustomerService _customerService = ArCustomerService();
  final SalespersonService _salespersonService = SalespersonService();
  final TextEditingController _monthsIntervalCtrl =
      TextEditingController(text: '1');

  bool _isLoading = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;
  bool _isExporting = false;

  Company? _company;
  Map<String, String>? _headers;

  DateTime _asOfDate = DateTime.now();
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;

  // Customer filters
  List<ArCustomerGroup> _customerGroups = [];
  List<int> _selectedGroupIds = [];
  List<Salesperson> _salespersons = [];
  int? _selectedSalespersonId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String _fromLabel = '';
  String _toLabel = '';

  // Column settings
  int _columnCount = 3;
  bool _showDetail = false;
  String _sortOrder = 'none'; // 'none' | 'desc' | 'asc'

  List<Map<String, dynamic>> _reportData = [];
  Map<String, ArCustomer> _customerDetailMap = {};

  @override
  void initState() {
    super.initState();
    _allowedBranches = _authService.allowedBranches;
    _loadMasterData();
  }

  @override
  void dispose() {
    _monthsIntervalCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  int get _columnInterval =>
      (int.tryParse(_monthsIntervalCtrl.text) ?? 1).clamp(1, 12);

  // totalBuckets = 1 (เกินกำหนดแล้ว) + columnCount
  int get _totalBuckets => _columnCount + 1;

  // Bucket labels:
  //   0 = เกินกำหนดแล้ว
  //   1..N-1 = calendar months forward from asOfDate
  //   N = last month + "+" (catch-all for far future)
  List<String> get _dynamicBucketLabels {
    final I = _columnInterval;
    final labels = <String>['เกินกำหนดแล้ว'];
    for (int i = 0; i < _columnCount - 1; i++) {
      final dt =
          DateTime(_asOfDate.year, _asOfDate.month + i * I, 1);
      labels.add(DateFormat('MM/yy').format(dt));
    }
    final lastDt = DateTime(
        _asOfDate.year, _asOfDate.month + (_columnCount - 1) * I, 1);
    labels.add('${DateFormat('MM/yy').format(lastDt)}+');
    return labels;
  }

  // Assign invoice to bucket using due_date (not days_overdue)
  //   0 = already overdue
  //   1 = due in first interval (current month or soon)
  //   N = due in Nth interval or later (catch-all)
  int _bucketForDueDate(String? dueDateStr) {
    if (dueDateStr == null || dueDateStr.isEmpty) return 0;
    try {
      final raw  = DateTime.parse(dueDateStr).toLocal();
      final dueDate = DateTime(raw.year, raw.month, raw.day);
      final asOf    = DateTime(_asOfDate.year, _asOfDate.month, _asOfDate.day);
      if (dueDate.isBefore(asOf)) return 0; // already overdue
      final monthsDiff = (dueDate.year - _asOfDate.year) * 12 +
          (dueDate.month - _asOfDate.month);
      final I = _columnInterval;
      final idx = (monthsDiff / I).floor() + 1;
      return idx.clamp(1, _columnCount);
    } catch (_) {
      return 0;
    }
  }

  // ─── data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadMasterData() async {
    _headers = await _authService.getAuthHeader();
    final results = await Future.wait([
      _companyService.fetchCompany(),
      _groupService.fetchActiveRows(),
      _salespersonService.fetchRows(),
    ]);
    _company = results[0] as Company?;
    _customerGroups = results[1] as List<ArCustomerGroup>;
    _salespersons = (results[2] as List<Salesperson>)
        .where((s) => s.isActive)
        .toList();
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _reportData = [];
    });
    try {
      final raw = await _reportService.getAgingReport(
        asOfDate: DateFormat('yyyy-MM-dd').format(_asOfDate),
        branchId: _selectedBranchId,
        salespersonId: _selectedSalespersonId,
        customerCodeFrom: _customerCodeFrom,
        customerCodeTo: _customerCodeTo,
      );
      // Step 1: filter non-empty + กลุ่ม + พนักงานขาย + code range จาก raw data
      var filtered =
          raw.where((c) => ((c['invoices'] as List?) ?? []).isNotEmpty).toList();
      if (_selectedGroupIds.isNotEmpty) {
        filtered = filtered
            .where((c) => _selectedGroupIds.contains(c['customer_group_id']))
            .toList();
      }
      if (_selectedSalespersonId != null) {
        filtered = filtered
            .where((c) => c['salesperson_id'] == _selectedSalespersonId)
            .toList();
      }
      if (_customerCodeFrom != null && _customerCodeFrom!.isNotEmpty) {
        filtered = filtered
            .where((c) =>
                (c['customer_code'] as String? ?? '')
                    .compareTo(_customerCodeFrom!) >= 0)
            .toList();
      }
      if (_customerCodeTo != null && _customerCodeTo!.isNotEmpty) {
        filtered = filtered
            .where((c) =>
                (c['customer_code'] as String? ?? '')
                    .compareTo(_customerCodeTo!) <= 0)
            .toList();
      }

      // Step 2: โหลด customer detail สำหรับ billing/payment conditions
      final detailMap = <String, ArCustomer>{};
      if (filtered.isNotEmpty) {
        final futures = filtered.map((c) async {
          final id = c['customer_id'] as int?;
          if (id == null) return null;
          try {
            return await _customerService.fetchRow(id);
          } catch (_) {
            return null;
          }
        }).toList();
        final details = await Future.wait(futures);
        for (final d in details) {
          if (d != null) detailMap[d.customerCode] = d;
        }
      }

      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่พบข้อมูลลูกหนี้ ณ วันที่ที่เลือก')));
      }

      setState(() {
        _reportData = filtered;
        _customerDetailMap = detailMap;
        _pdfKey++;
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

  void _onSettingChanged() {
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
  }

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'Due');
      final s = ex['Due'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      final bucketLabels = _dynamicBucketLabels;
      final totalBuckets = _totalBuckets;
      String fmtDate(String? raw) {
        if (raw == null || raw.isEmpty) return '';
        try {
          final d = DateTime.parse(raw).toLocal();
          return DateFormat('dd/MM/yyyy').format(DateTime(d.year, d.month, d.day));
        } catch (_) { return raw; }
      }

      final _ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'รายงานกำหนดชำระลูกหนี้', bold: true);
      _xlCell(s, 2, 0, 'ณ วันที่: ${DateFormat('dd/MM/yyyy').format(_asOfDate)}  |  พิมพ์: $_ts');

      int r = 3;
      _xlCell(s, r, 0, 'รหัสลูกหนี้', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, 'ชื่อลูกหนี้', bg: hdrBg, bold: true);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, bucketLabels[b], bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, 'รวม', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      r++;

      final grandBuckets = List<double>.filled(totalBuckets, 0.0);
      double grandTotal = 0.0;

      for (final cust in _reportData) {
        final code = cust['customer_code'] as String? ?? '';
        final name = cust['customer_name_th'] as String? ?? '';
        final invoices = (cust['invoices'] as List?) ?? [];
        final custBuckets = List<double>.filled(totalBuckets, 0.0);
        for (final inv in invoices) {
          final dueDate = inv['due_date']?.toString();
          final amt = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
          final b = _bucketForDueDate(dueDate);
          custBuckets[b] += amt;
          if (_showDetail) {
            _xlCell(s, r, 0, inv['doc_no']?.toString() ?? '', bg: detBg);
            _xlCell(s, r, 1, fmtDate(dueDate), bg: detBg);
            for (int bi = 0; bi < totalBuckets; bi++) {
              _xlCell(s, r, 2 + bi, bi == b ? DoubleCellValue(amt) : TextCellValue('-'), bg: detBg, align: HorizontalAlign.Right);
            }
            _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(amt), bg: detBg, align: HorizontalAlign.Right);
            r++;
          }
        }
        final custTotal = custBuckets.fold(0.0, (a, b) => a + b);
        _xlCell(s, r, 0, code);
        _xlCell(s, r, 1, name);
        for (int b = 0; b < totalBuckets; b++) {
          _xlCell(s, r, 2 + b, custBuckets[b] == 0 ? TextCellValue('-') : DoubleCellValue(custBuckets[b]), align: HorizontalAlign.Right);
          grandBuckets[b] += custBuckets[b];
        }
        _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(custTotal), align: HorizontalAlign.Right, bold: true);
        grandTotal += custTotal;
        r++;
      }

      _xlCell(s, r, 0, 'รวมทั้งสิ้น', bg: totBg, bold: true);
      _xlCell(s, r, 1, '', bg: totBg);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, DoubleCellValue(grandBuckets[b]), bg: totBg, bold: true, align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(grandTotal), bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'รายงานกำหนดชำระลูกหนี้_$ts.xlsx');
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

  // ─── PDF ──────────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font           = pw.Font.ttf(fontData);
    final fontBold       = pw.Font.ttf(fontBoldData);
    final fontItalic     = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName     = _headers?['UserName'] ?? '(ไม่ระบุชื่อ)';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final asOfLine     = 'ณ วันที่ ${DateFormat('dd/MM/yyyy').format(_asOfDate)}';

    final bucketLabels = _dynamicBucketLabels;
    final totalBuckets = _totalBuckets;
    final showDetail   = _showDetail;
    final sortOrder    = _sortOrder;

    // Conditions line (row 3)
    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _allowedBranches.firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _allowedBranches.first);
      conditions.add('สาขา: ${b.branchCode} ${b.branchNameThai}');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _customerGroups.firstWhere((g) => g.id == id,
            orElse: () => _customerGroups.first);
        return '${g.groupCode} ${g.groupNameThai}';
      }).join(', ');
      conditions.add('กลุ่มลูกค้า: $names');
    }
    if (_selectedSalespersonId != null) {
      final sp = _salespersons.firstWhere(
          (s) => s.id == _selectedSalespersonId,
          orElse: () => _salespersons.first);
      conditions.add('พนักงานขาย: ${sp.salespersonCode} ${sp.salespersonNameThai}');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty || (_customerCodeTo ?? '').isNotEmpty) {
      final from = _customerCodeFrom ?? '';
      final to   = _customerCodeTo ?? '';
      conditions.add(
          'รหัสลูกค้า: ${from.isEmpty ? '(ทั้งหมด)' : from} – ${to.isEmpty ? '(ทั้งหมด)' : to}');
    }
    conditions.add('คอลัมน์: $_columnCount คอลัมน์  ทุก $_columnInterval เดือน');
    if (sortOrder != 'none') {
      conditions.add(
          'เรียงยอด: ${sortOrder == 'desc' ? 'มากไปน้อย' : 'น้อยไปมาก'}');
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
      } catch (_) {
        return raw;
      }
    }

    // Compute per-customer buckets using due_date
    final rows = _reportData.map((c) {
      final buckets = List<double>.filled(totalBuckets, 0);
      for (final inv in (c['invoices'] as List? ?? [])) {
        final dueDate = inv['due_date'] as String?;
        final bal     = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
        buckets[_bucketForDueDate(dueDate)] += bal;
      }
      final code   = c['customer_code'] as String? ?? '';
      final detail = _customerDetailMap[code];
      return (
        code:         code,
        name:         c['customer_name_th'] as String? ?? '',
        buckets:      buckets,
        total:        buckets.fold(0.0, (s, v) => s + v),
        invoices:     (c['invoices'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .toList(),
        billingConds: detail?.billingConditions
            ?? const <ArCustomerBillingCondition>[],
        paymentConds: detail?.paymentConditions
            ?? const <ArCustomerPaymentCondition>[],
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

    // Dynamic column widths
    final colW = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(7),
      1: const pw.FlexColumnWidth(15),
    };
    for (int i = 0; i < totalBuckets; i++) {
      colW[i + 2] = const pw.FlexColumnWidth(9);
    }
    colW[totalBuckets + 2] = const pw.FlexColumnWidth(10);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(companyName,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text('รายงานกำหนดชำระลูกหนี้',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text('หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text(asOfLine,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text('พิมพ์โดย $userName',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
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
                    child: pw.Text('พิมพ์เมื่อ $printDateStr',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) {
          final hdrStyle    = pw.TextStyle(font: fontBold, fontSize: 9);
          final cellStyle   = pw.TextStyle(font: font, fontSize: 9);
          final boldStyle   = pw.TextStyle(font: fontBold, fontSize: 9);
          final detailStyle = pw.TextStyle(font: fontItalic, fontSize: 8);
          const edg    = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2);
          const edgDtl = pw.EdgeInsets.fromLTRB(8, 1, 3, 1);

          pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
              pw.Container(
                  padding: edg,
                  child: pw.Text(t, style: hdrStyle, textAlign: a));

          pw.Widget dCell(String t,
                  {pw.TextAlign a = pw.TextAlign.left,
                  pw.TextStyle? s,
                  pw.EdgeInsets? p}) =>
              pw.Container(
                  padding: p ?? edg,
                  child: pw.Text(t, style: s ?? cellStyle, textAlign: a));

          pw.Widget amtCell(double v,
                  {bool bold = false, pw.TextStyle? s}) =>
              pw.Container(
                  padding: edg,
                  child: pw.Text(fmtAmt(v),
                      style: s ?? (bold ? boldStyle : cellStyle),
                      textAlign: pw.TextAlign.right));

          pw.TableRow summaryRow(
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

          pw.TableRow conditionsRow(String text) {
            final empty = pw.Container(
                padding: edgDtl,
                child: pw.Text('', style: detailStyle));
            return pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor(0.96, 0.96, 0.96)),
              children: [
                empty,
                pw.Container(
                    padding: edgDtl,
                    child: pw.Text(text, style: detailStyle)),
                for (int i = 0; i < totalBuckets + 1; i++) empty,
              ],
            );
          }

          pw.TableRow invRow(Map<String, dynamic> inv) {
            final docNo    = inv['doc_no'] as String? ?? '';
            final docDate  = fmtDate(inv['doc_date'] as String?);
            final billDate = fmtDate(inv['billing_date'] as String?);
            final dueStr   = inv['due_date'] as String?;
            final dueDate  = fmtDate(dueStr);
            final bal      = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
            final bucket   = _bucketForDueDate(dueStr);
            final dateParts = <String>[];
            if (docDate.isNotEmpty) dateParts.add('แจ้ง:$docDate');
            if (billDate.isNotEmpty) dateParts.add('บิล:$billDate');
            if (dueDate.isNotEmpty) dateParts.add('ครบ:$dueDate');
            final dateText = dateParts.join('  ');
            final bks   = List<double>.filled(totalBuckets, 0);
            bks[bucket] = bal;
            return pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor(0.96, 0.96, 0.96)),
              children: [
                dCell(docNo, s: detailStyle, p: edgDtl),
                dCell(dateText, s: detailStyle, p: edgDtl),
                ...bks.map((v) => amtCell(v, s: detailStyle)),
                amtCell(bal, s: detailStyle),
              ],
            );
          }

          // Build table rows
          final tableRows = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColor(0.87, 0.94, 0.92)),
              children: [
                hCell(showDetail ? 'รหัส / ใบแจ้งหนี้' : 'รหัส',
                    a: pw.TextAlign.left),
                hCell(showDetail
                    ? 'ชื่อลูกค้า / วันแจ้งหนี้,วางบิล,ครบกำหนด'
                    : 'ชื่อลูกค้า',
                    a: pw.TextAlign.left),
                ...bucketLabels.map((l) => hCell(l)),
                hCell('รวม'),
              ],
            ),
          ];

          for (final r in rows) {
            tableRows.add(summaryRow(r.code, r.name, r.buckets, r.total));
            if (showDetail) {
              final billTexts = r.billingConds
                  .map(_billingCondSummary)
                  .where((s) => s != '(ไม่ระบุเงื่อนไข)')
                  .toList();
              final payTexts = r.paymentConds
                  .map(_paymentCondSummary)
                  .where((s) => s != '(ไม่ระบุเงื่อนไข)')
                  .toList();
              if (billTexts.isNotEmpty || payTexts.isNotEmpty) {
                final lines = <String>[];
                if (billTexts.isNotEmpty) {
                  lines.add('วางบิล: ${billTexts.join(' / ')}');
                }
                if (payTexts.isNotEmpty) {
                  lines.add('ชำระ:   ${payTexts.join(' / ')}');
                }
                tableRows.add(conditionsRow(lines.join('\n')));
              }
              for (final inv in r.invoices) {
                tableRows.add(invRow(inv));
              }
            }
          }

          tableRows.add(summaryRow('', 'รวมทั้งหมด', grand, grandTotal,
              isTotal: true,
              bg: const PdfColor(0.87, 0.94, 0.92)));

          return [
            pw.Table(
              border: pw.TableBorder.all(
                  width: 0.3, color: PdfColors.grey400),
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
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
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
                  (constraints.maxWidth - 36 - 5 - 300)
                      .clamp(100.0, double.infinity);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── toggle ─────────────────────────────────────────────────
                  Container(
                    width: 36,
                    color: Colors.teal[800],
                    child: IconButton(
                      icon: Icon(
                          _isFilterExpanded
                              ? Icons.filter_list_off
                              : Icons.filter_list,
                          color: Colors.white,
                          size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
                      onPressed: () => setState(
                          () => _isFilterExpanded = !_isFilterExpanded),
                    ),
                  ),
                  // ── filter panel ───────────────────────────────────────────
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
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('เงื่อนไขรายงาน',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
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
                                      suffixIcon: Icon(
                                          Icons.calendar_today, size: 16),
                                    ),
                                    child: Text(DateFormat('dd/MM/yyyy')
                                        .format(_asOfDate)),
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
                                          value: null,
                                          child: Text('— ทุกสาขา —')),
                                      ..._allowedBranches.map((b) =>
                                          DropdownMenuItem<int?>(
                                            value: b.branchId,
                                            child: Text(
                                                '${b.branchCode}  ${b.branchNameThai}',
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _selectedBranchId = v),
                                  ),
                                ],

                                // กลุ่มลูกค้า
                                const SizedBox(height: 12),
                                ArCustomerGroupMultiPicker(
                                  groups: _customerGroups,
                                  selectedIds: _selectedGroupIds,
                                  onChanged: (v) =>
                                      setState(() => _selectedGroupIds = v),
                                ),

                                // พนักงานขาย
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int?>(
                                  isExpanded: true,
                                  value: _selectedSalespersonId,
                                  decoration: const InputDecoration(
                                      labelText: 'พนักงานขาย',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('— ทั้งหมด —')),
                                    ..._salespersons.map((s) =>
                                        DropdownMenuItem<int?>(
                                          value: s.id,
                                          child: Text(
                                              '${s.salespersonCode}  ${s.salespersonNameThai}',
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        )),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _selectedSalespersonId = v),
                                ),

                                // รหัสลูกค้าตั้งแต่
                                const SizedBox(height: 12),
                                _buildCustomerCodeField(
                                  label: 'รหัสลูกค้า ตั้งแต่',
                                  displayText: _fromLabel,
                                  onPick: () => _pickCustomer(isFrom: true),
                                  onClear: () => setState(() {
                                    _customerCodeFrom = null;
                                    _fromLabel = '';
                                  }),
                                ),
                                const SizedBox(height: 8),
                                _buildCustomerCodeField(
                                  label: 'รหัสลูกค้า ถึง',
                                  displayText: _toLabel,
                                  onPick: () => _pickCustomer(isFrom: false),
                                  onClear: () => setState(() {
                                    _customerCodeTo = null;
                                    _toLabel = '';
                                  }),
                                ),

                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 12),

                                // จำนวนคอลัมน์
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  value: _columnCount,
                                  decoration: const InputDecoration(
                                      labelText: 'จำนวนคอลัมน์กำหนดชำระ',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  items: [2, 3, 4, 5]
                                      .map((n) => DropdownMenuItem<int>(
                                          value: n,
                                          child: Text('$n คอลัมน์')))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _columnCount = v);
                                      _onSettingChanged();
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // จำนวนเดือนต่อคอลัมน์
                                TextField(
                                  controller: _monthsIntervalCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                    labelText: 'จำนวนเดือนต่อคอลัมน์',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    suffixText: 'เดือน',
                                  ),
                                  onEditingComplete: _onSettingChanged,
                                ),
                                const SizedBox(height: 12),

                                // เรียงตามยอด
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _sortOrder,
                                  decoration: const InputDecoration(
                                      labelText: 'เรียงตามยอดรวม',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'none',
                                        child: Text('— ไม่ระบุ —')),
                                    DropdownMenuItem(
                                        value: 'desc',
                                        child: Text('มากไปน้อย ↓')),
                                    DropdownMenuItem(
                                        value: 'asc',
                                        child: Text('น้อยไปมาก ↑')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _sortOrder = v);
                                      _onSettingChanged();
                                    }
                                  },
                                ),

                                const SizedBox(height: 8),
                                const Divider(height: 1),

                                // แสดงรายละเอียด
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text('แสดงรายละเอียดใบแจ้งหนี้',
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                    Switch(
                                      value: _showDetail,
                                      activeColor: Colors.teal[800],
                                      onChanged: (v) {
                                        setState(() => _showDetail = v);
                                        _onSettingChanged();
                                      },
                                    ),
                                  ],
                                ),

                                    ],  // inner Column children
                                  ),   // inner Column
                                ),     // SingleChildScrollView
                              ),       // Expanded
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('ประมวลผลรายงาน'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[800],
                                        foregroundColor: Colors.white),
                                    onPressed:
                                        _isLoading ? null : _generateReport,
                                  ),
                                ),
                              ),
                            ],  // outer Column children
                          ),    // outer Column (Card child)
                        ),
                      ),
                    ),
                  ),
                  // ── draggable divider ──────────────────────────────────────
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
                  // ── PDF preview ────────────────────────────────────────────
                  Expanded(
                    child: Container(
                      color: Colors.grey[200],
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _reportData.isEmpty
                              ? const Center(
                                  child: Text(
                                      'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat:
                                      PdfPageFormat.a4.landscape,
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

  // ── customer code picker ──────────────────────────────────────────────────

  Future<void> _pickCustomer({required bool isFrom}) async {
    final result = await showDialog<ArCustomer>(
      context: context,
      builder: (_) => const _DueReportCustomerSearchDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        final label = '${result.customerCode}  ${result.customerNameTh}';
        if (isFrom) {
          _customerCodeFrom = result.customerCode;
          _fromLabel = label;
        } else {
          _customerCodeTo = result.customerCode;
          _toLabel = label;
        }
      });
    }
  }

  Widget _buildCustomerCodeField({
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                child: Icon(Icons.search, size: 18, color: Colors.teal[800]),
              ),
            ),
          ],
        ),
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

// ── customer search dialog ────────────────────────────────────────────────────

class _DueReportCustomerSearchDialog extends StatefulWidget {
  const _DueReportCustomerSearchDialog();

  @override
  State<_DueReportCustomerSearchDialog> createState() =>
      _DueReportCustomerSearchDialogState();
}

class _DueReportCustomerSearchDialogState
    extends State<_DueReportCustomerSearchDialog> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final ArCustomerService _service = ArCustomerService();
  List<ArCustomer> _customers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final list = await _service.fetchRows(
          search: query.trim().isEmpty ? null : query.trim());
      if (mounted) setState(() => _customers = list);
    } catch (_) {
      if (mounted) setState(() => _customers = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.teal[800],
              child: const Text('ค้นหาลูกค้า',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาจากรหัสหรือชื่อลูกค้า',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                children: [
                  SizedBox(
                      width: 100,
                      child: Text('รหัส',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(
                      child: Text('ชื่อลูกค้า',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? const Center(
                          child: Text('ไม่พบข้อมูล',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: _scrollCtrl,
                          itemCount: _customers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 12),
                          itemBuilder: (ctx, i) {
                            final c = _customers[i];
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, c),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(c.customerCode,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                    Expanded(
                                      child: Text(c.customerNameTh,
                                          style:
                                              const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── condition text helpers (same as ar_aging_report_screen) ──────────────────

const _dueRptDayNames = [
  'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'
];
const _dueRptWeekNames = {
  1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'
};

String _billingCondSummary(ArCustomerBillingCondition b) {
  final parts = <String>[];
  if (b.billWithDelivery) parts.add('วางบิลพร้อมส่งของ');
  if (b.billingDayOfMonth.isNotEmpty) {
    parts.add(b.billingDayOfMonth
        .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
        .join(', '));
  }
  if (b.billingDayOfWeek.isNotEmpty) {
    parts.add(
        'วัน${b.billingDayOfWeek.map((d) => _dueRptDayNames[d]).join('-')}');
  }
  if (b.billingWeekOfMonth.isNotEmpty) {
    parts.add('สัปดาห์${b.billingWeekOfMonth.map((w) => _dueRptWeekNames[w] ?? '$w').join('/')}');
  }
  if (b.billingTimeFrom != null || b.billingTimeTo != null) {
    parts.add('${b.billingTimeFrom ?? ''}–${b.billingTimeTo ?? ''}');
  }
  if (b.dueFromBillingDate) parts.add('due นับจากวางบิล');
  return parts.isEmpty ? '(ไม่ระบุเงื่อนไข)' : parts.join('  ·  ');
}

String _paymentCondSummary(ArCustomerPaymentCondition p) {
  final parts = <String>[];
  if (p.paymentDayOfMonth.isNotEmpty) {
    parts.add(p.paymentDayOfMonth
        .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
        .join(', '));
  }
  if (p.paymentDayOfWeek.isNotEmpty) {
    parts.add(
        'วัน${p.paymentDayOfWeek.map((d) => _dueRptDayNames[d]).join('-')}');
  }
  if (p.paymentWeekOfMonth.isNotEmpty) {
    parts.add('สัปดาห์${p.paymentWeekOfMonth.map((w) => _dueRptWeekNames[w] ?? '$w').join('/')}');
  }
  if (p.withinMonthsFromBilling > 0) {
    parts.add('ภายใน ${p.withinMonthsFromBilling} เดือนจากวางบิล');
  }
  if (p.additionalDays != 0) parts.add('+${p.additionalDays} วัน');
  if (p.paymentTimeFrom != null || p.paymentTimeTo != null) {
    parts.add('${p.paymentTimeFrom ?? ''}–${p.paymentTimeTo ?? ''}');
  }
  return parts.isEmpty ? '(ไม่ระบุเงื่อนไข)' : parts.join('  ·  ');
}
