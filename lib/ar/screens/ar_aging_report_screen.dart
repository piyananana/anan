import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import 'package:provider/provider.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_aging_report_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/models/cd_salesperson.dart';
import '../../cd/services/cd_salesperson_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

class ArAgingReportScreen extends StatefulWidget {
  const ArAgingReportScreen({super.key});

  @override
  State<ArAgingReportScreen> createState() => _ArAgingReportScreenState();
}

class _ArAgingReportScreenState extends State<ArAgingReportScreen> {
  final ArAgingReportService _reportService = ArAgingReportService();
  final CompanyService _companyService = CompanyService();
  final AuthService _authService = AuthService();
  final ArCustomerGroupService _groupService = ArCustomerGroupService();
  final ArCustomerService _customerService = ArCustomerService();
  final SalespersonService _salespersonService = SalespersonService();
  final BranchService _branchService = BranchService();
  final TextEditingController _daysIntervalCtrl =
      TextEditingController(text: '30');

  bool _isLoading = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;
  bool _isExporting = false;
  bool _isEnglish = false;

  Company? _company;
  Map<String, String>? _headers;
  // ชื่อรายงาน — ใช้ชื่อเมนู (จาก AppBar/MenuTitle) แทนข้อความ hardcode เพื่อให้ตรงกับที่ผู้ใช้เห็นบนแท็บเสมอ
  String _reportTitle = '';

  DateTime _asOfDate = DateTime.now();
  List<UserBranch> _allowedBranches = [];
  List<Branch> _allBranches = [];
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
  int _overdueColumnCount = 3;
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
    _daysIntervalCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  int get _columnInterval =>
      (int.tryParse(_daysIntervalCtrl.text) ?? 30).clamp(1, 9999);

  // totalBuckets = 1 (ยังไม่ครบกำหนด) + overdueColumnCount
  int get _totalBuckets => _overdueColumnCount + 1;

  // Labels: index 0 = ยังไม่ครบกำหนด, 1..N-1 = ranges, N = เกิน
  List<String> get _dynamicBucketLabels {
    final I = _columnInterval;
    final labels = <String>[_isEnglish ? 'Not yet due' : 'ยังไม่ครบกำหนด'];
    for (int i = 0; i < _overdueColumnCount - 1; i++) {
      labels.add('${i * I + 1}-${(i + 1) * I}');
    }
    labels.add('${_isEnglish ? "Over" : "เกิน"} ${(_overdueColumnCount - 1) * I}');
    return labels;
  }

  // Assign invoice to bucket index (0 = not yet due, 1 = most recent, N = oldest)
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
      _salespersonService.fetchRows(),
      _branchService.fetchRows(),
    ]);
    _company = results[0] as Company?;
    _customerGroups = results[1] as List<ArCustomerGroup>;
    _salespersons = (results[2] as List<Salesperson>)
        .where((s) => s.isActive)
        .toList();
    _allBranches = results[3] as List<Branch>;
    if (mounted) setState(() {});
  }

  // UserBranch (allowed branches) has no English name — resolve it from the
  // full bilingual Branch list by branchId.
  String _resolveBranchName(int? branchId, String fallbackThai, bool isEnglish) {
    if (isEnglish) {
      final match = _allBranches.where((b) => b.id == branchId);
      if (match.isNotEmpty && match.first.branchNameEng.isNotEmpty) {
        return match.first.branchNameEng;
      }
    }
    return fallbackThai;
  }

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
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
      // Step 1: filter non-empty + code range + กลุ่ม + พนักงานขาย จาก raw data
      // (backend ส่ง customer_group_id, salesperson_id มาแล้วใน response)
      var filtered = raw
          .where((c) => ((c['invoices'] as List?) ?? []).isNotEmpty)
          .toList();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No outstanding receivable data found as of the selected date'
                : 'ไม่พบข้อมูลลูกหนี้คงค้าง ณ วันที่ที่เลือก')));
      }

      setState(() {
        _reportData = filtered;
        _customerDetailMap = detailMap;
        _pdfKey++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
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
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'Aging');
      final s = ex['Aging'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      final bucketLabels = _dynamicBucketLabels;
      final totalBuckets = _totalBuckets;

      final _ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? "As of" : "ณ วันที่"}: ${DateFormat('dd/MM/yyyy').format(_asOfDate)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $_ts');

      int r = 3;
      // Header row
      _xlCell(s, r, 0, isEnglish ? 'Customer Code' : 'รหัสลูกหนี้', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, isEnglish ? 'Customer Name' : 'ชื่อลูกหนี้', bg: hdrBg, bold: true);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, bucketLabels[b], bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, isEnglish ? 'Total' : 'รวม', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      r++;

      final grandBuckets = List<double>.filled(totalBuckets, 0.0);
      double grandTotal = 0.0;

      for (final cust in _reportData) {
        final code = cust['customer_code'] as String? ?? '';
        final nameTh = cust['customer_name_th'] as String? ?? '';
        final nameEn = _customerDetailMap[code]?.customerNameEn;
        final name = isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
        final invoices = (cust['invoices'] as List?) ?? [];
        final custBuckets = List<double>.filled(totalBuckets, 0.0);
        for (final inv in invoices) {
          final days = (inv['days_overdue'] as num?) ?? 0;
          final amt = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
          final b = _bucketDynamic(days);
          custBuckets[b] += amt;
          if (_showDetail) {
            _xlCell(s, r, 0, inv['doc_no']?.toString() ?? '', bg: detBg);
            _xlCell(s, r, 1, inv['doc_date']?.toString() ?? '', bg: detBg);
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

      // Grand total
      _xlCell(s, r, 0, isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', bg: totBg, bold: true);
      _xlCell(s, r, 1, '', bg: totBg);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, DoubleCellValue(grandBuckets[b]), bg: totBg, bold: true, align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, DoubleCellValue(grandTotal), bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes,
          isEnglish ? 'AR_Aging_Report_$ts.xlsx' : 'รายงานลูกหนี้คงค้างตามอายุหนี้_$ts.xlsx');
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
    final isEnglish         = _isEnglish;
    final reportTitle       = _reportTitle;
    final doc              = pw.Document();
    final fontData         = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData     = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData   = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font             = pw.Font.ttf(fontData);
    final fontBold         = pw.Font.ttf(fontBoldData);
    final fontItalic       = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? (isEnglish ? '(No name)' : '(ไม่ระบุชื่อ)');
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final asOfLine     = '${isEnglish ? "As of" : "ณ วันที่"} ${DateFormat('dd/MM/yyyy').format(_asOfDate)}';

    // Snapshot settings for this render
    final bucketLabels = _dynamicBucketLabels;
    final totalBuckets = _totalBuckets;
    final showDetail   = _showDetail;
    final sortOrder    = _sortOrder;

    // เงื่อนไข บรรทัดที่ 3 ชิดซ้าย
    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _allowedBranches.firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _allowedBranches.first);
      conditions.add('${isEnglish ? "Branch" : "สาขา"}: ${b.branchCode} ${_resolveBranchName(b.branchId, b.branchNameThai, isEnglish)}');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _customerGroups.firstWhere((g) => g.id == id,
            orElse: () => _customerGroups.first);
        final gName = isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai;
        return '${g.groupCode} $gName';
      }).join(', ');
      conditions.add('${isEnglish ? "Customer Group" : "กลุ่มลูกค้า"}: $names');
    }
    if (_selectedSalespersonId != null) {
      final sp = _salespersons.firstWhere(
          (s) => s.id == _selectedSalespersonId,
          orElse: () => _salespersons.first);
      final spName = isEnglish && (sp.salespersonNameEng ?? '').isNotEmpty
          ? sp.salespersonNameEng!
          : sp.salespersonNameThai;
      conditions.add('${isEnglish ? "Salesperson" : "พนักงานขาย"}: ${sp.salespersonCode} $spName');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty || (_customerCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final from = _customerCodeFrom ?? '';
      final to = _customerCodeTo ?? '';
      conditions.add('${isEnglish ? "Customer Code" : "รหัสลูกค้า"}: ${from.isEmpty ? all : from} – ${to.isEmpty ? all : to}');
    }
    conditions.add(isEnglish
        ? 'Overdue columns: $_overdueColumnCount column(s)  every $_columnInterval day(s)'
        : 'คอลัมน์ครบกำหนด: $_overdueColumnCount คอลัมน์  ทุก $_columnInterval วัน');
    if (sortOrder != 'none') {
      conditions.add(isEnglish
          ? 'Sort by balance: ${sortOrder == 'desc' ? 'Descending' : 'Ascending'}'
          : 'เรียงยอดหนี้: ${sortOrder == 'desc' ? 'มากไปน้อย' : 'น้อยไปมาก'}');
    }
    if (showDetail) {
      conditions.add(isEnglish ? 'Show invoice details' : 'แสดงรายละเอียดใบแจ้งหนี้');
    }
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

    // ── compute per-customer buckets ──
    final rows = _reportData.map((c) {
      final buckets = List<double>.filled(totalBuckets, 0);
      for (final inv in (c['invoices'] as List? ?? [])) {
        final days = (inv['days_overdue'] as num?) ?? 0;
        final bal  = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
        buckets[_bucketDynamic(days)] += bal;
      }
      final code   = c['customer_code'] as String? ?? '';
      final detail = _customerDetailMap[code];
      final nameTh = c['customer_name_th'] as String? ?? '';
      final nameEn = detail?.customerNameEn;
      return (
        code:         code,
        name:         isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh,
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

    // Sort by total
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
      0: const pw.FlexColumnWidth(7),   // รหัส / เลขที่ใบแจ้งหนี้
      1: const pw.FlexColumnWidth(15),  // ชื่อ / วันที่ครบกำหนด
    };
    for (int i = 0; i < totalBuckets; i++) {
      colW[i + 2] = const pw.FlexColumnWidth(9);
    }
    colW[totalBuckets + 2] = const pw.FlexColumnWidth(10); // รวม

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          children: [
            // แถว 1: บริษัท | ชื่อรายงาน | หน้า
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(companyName,
                        style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 7,
                    child: pw.Text(reportTitle,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text('${isEnglish ? "Page" : "หน้า"} ${ctx.pageNumber}/${ctx.pagesCount}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            // แถว 2: | ณ วันที่ | พิมพ์โดย
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
                    child: pw.Text('${isEnglish ? "Printed by" : "พิมพ์โดย"} $userName',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            // แถว 3: เงื่อนไขทั้งหมด ชิดซ้าย | พิมพ์เมื่อ ชิดขวา
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
                    child: pw.Text('${isEnglish ? "Printed" : "พิมพ์เมื่อ"} $printDateStr',
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
          const edg     = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2);
          const edgDtl  = pw.EdgeInsets.fromLTRB(8, 1, 3, 1);

          pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
              pw.Container(
                  padding: edg,
                  child: pw.Text(t, style: hdrStyle, textAlign: a));

          pw.Widget dCell(String t,
                  {pw.TextAlign a = pw.TextAlign.left, pw.TextStyle? s,
                  pw.EdgeInsets? p}) =>
              pw.Container(
                  padding: p ?? edg,
                  child: pw.Text(t, style: s ?? cellStyle, textAlign: a));

          pw.Widget amtCell(double v, {bool bold = false, pw.TextStyle? s}) =>
              pw.Container(
                  padding: edg,
                  child: pw.Text(fmtAmt(v),
                      style: s ?? (bold ? boldStyle : cellStyle),
                      textAlign: pw.TextAlign.right));

          // ── summary row (per customer) ──
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

          // ── conditions row (billing + payment, same cell as name, italic) ──
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

          // ── detail row (per invoice) ──
          pw.TableRow invRow(Map<String, dynamic> inv) {
            final docNo    = inv['doc_no'] as String? ?? '';
            final docDate  = fmtDate(inv['doc_date'] as String?);
            final billDate = fmtDate(inv['billing_date'] as String?);
            final dueDate  = fmtDate(inv['due_date'] as String?);
            final days     = (inv['days_overdue'] as num?) ?? 0;
            final bal      = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0.0;
            final bucket   = _bucketDynamic(days);

            final dateParts = <String>[];
            if (docDate.isNotEmpty) dateParts.add('${isEnglish ? "Doc" : "แจ้ง"}:$docDate');
            if (billDate.isNotEmpty) dateParts.add('${isEnglish ? "Bill" : "บิล"}:$billDate');
            if (dueDate.isNotEmpty) dateParts.add('${isEnglish ? "Due" : "ครบ"}:$dueDate');
            final dateText = dateParts.join('  ');

            final bks = List<double>.filled(totalBuckets, 0);
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
            // header
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
              // conditions row (billing + payment) under customer name
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
              // invoice detail rows
              for (final inv in r.invoices) {
                tableRows.add(invRow(inv));
              }
            }
          }

          // grand total
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    _isEnglish = l.isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = l.isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (l.isEnglish ? 'AR Aging Report' : 'รายงานลูกหนี้คงค้างตามอายุหนี้'));
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
              onPressed: (_reportData.isEmpty || !canExport) ? null : _exportExcel,
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
                  // ── toggle button ──────────────────────────────────────────
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
                      tooltip: _isFilterExpanded
                          ? (l.isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                          : (l.isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                      onPressed: () =>
                          setState(() => _isFilterExpanded = !_isFilterExpanded),
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
                                      Text(l.isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                                          style: const TextStyle(
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
                                    decoration: InputDecoration(
                                      labelText: l.isEnglish ? 'As of' : 'ณ วันที่',
                                      border: const OutlineInputBorder(),
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
                                    decoration: InputDecoration(
                                        labelText: l.isEnglish ? 'Branch' : 'สาขา',
                                        border: const OutlineInputBorder(),
                                        isDense: true),
                                    items: [
                                      DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text(l.isEnglish ? '— All Branches —' : '— ทุกสาขา —')),
                                      ..._allowedBranches.map((b) =>
                                          DropdownMenuItem<int?>(
                                            value: b.branchId,
                                            child: Text(
                                                '${b.branchCode}  ${_resolveBranchName(b.branchId, b.branchNameThai, l.isEnglish)}',
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _selectedBranchId = v),
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
                                  decoration: InputDecoration(
                                      labelText: l.isEnglish ? 'Salesperson' : 'พนักงานขาย',
                                      border: const OutlineInputBorder(),
                                      isDense: true),
                                  items: [
                                    DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text(l.isEnglish ? '— All —' : '— ทั้งหมด —')),
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
                                  label: l.isEnglish ? 'Customer Code From' : 'รหัสลูกค้า ตั้งแต่',
                                  displayText: _fromLabel,
                                  onPick: () => _pickCustomer(isFrom: true),
                                  onClear: () => setState(() {
                                    _customerCodeFrom = null;
                                    _fromLabel = '';
                                  }),
                                ),

                                // รหัสลูกค้าถึง
                                const SizedBox(height: 8),
                                _buildCustomerCodeField(
                                  label: l.isEnglish ? 'Customer Code To' : 'รหัสลูกค้า ถึง',
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

                                // จำนวนคอลัมน์ที่ครบกำหนดแล้ว (2-5)
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  value: _overdueColumnCount,
                                  decoration: InputDecoration(
                                      labelText: l.isEnglish ? 'Number of Overdue Columns' : 'จำนวนคอลัมน์ที่ครบกำหนดแล้ว',
                                      border: const OutlineInputBorder(),
                                      isDense: true),
                                  items: [2, 3, 4, 5]
                                      .map((n) => DropdownMenuItem<int>(
                                          value: n,
                                          child: Text(l.isEnglish ? '$n columns' : '$n คอลัมน์')))
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
                                  decoration: InputDecoration(
                                    labelText: l.isEnglish ? 'Days per Column' : 'จำนวนวันต่อคอลัมน์',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixText: l.isEnglish ? 'days' : 'วัน',
                                  ),
                                  onEditingComplete: _onColumnSettingChanged,
                                ),

                                const SizedBox(height: 12),

                                // เรียงตามยอดหนี้รวม
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _sortOrder,
                                  decoration: InputDecoration(
                                      labelText: l.isEnglish ? 'Sort by Total Debt' : 'เรียงตามยอดหนี้รวม',
                                      border: const OutlineInputBorder(),
                                      isDense: true),
                                  items: [
                                    DropdownMenuItem(
                                        value: 'none',
                                        child: Text(l.isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
                                    DropdownMenuItem(
                                        value: 'desc',
                                        child: Text(l.isEnglish ? 'High to Low ↓' : 'มากไปน้อย ↓')),
                                    DropdownMenuItem(
                                        value: 'asc',
                                        child: Text(l.isEnglish ? 'Low to High ↑' : 'น้อยไปมาก ↑')),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(l.isEnglish ? 'Show invoice details' : 'แสดงรายละเอียดใบแจ้งหนี้',
                                          style: const TextStyle(fontSize: 13)),
                                    ),
                                    Switch(
                                      value: _showDetail,
                                      activeColor: Colors.teal[800],
                                      onChanged: (v) {
                                        setState(() => _showDetail = v);
                                        _onColumnSettingChanged();
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
                                    label: Text(l.isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
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
                              ? Center(
                                  child: Text(l.isEnglish
                                      ? 'Please select conditions and click Generate'
                                      : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat:
                                      PdfPageFormat.a4.landscape,
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

  // ── customer code picker ────────────────────────────────────────────────────

  Future<void> _pickCustomer({required bool isFrom}) async {
    final result = await showDialog<ArCustomer>(
      context: context,
      builder: (_) => const _CustomerSearchDialog(),
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
                child: Icon(Icons.search, size: 18,
                    color: Colors.teal[800]),
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
            color: hasValue ? Colors.black87 : Colors.black38,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── condition text helpers (identical logic to ar_customer_detail_widget) ─────

const _dayNames = [
  'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'
];
const _weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};

String _billingCondSummary(ArCustomerBillingCondition b) {
  final parts = <String>[];
  if (b.billWithDelivery) parts.add('วางบิลพร้อมส่งของ');
  if (b.billingDayOfMonth.isNotEmpty) {
    parts.add(b.billingDayOfMonth
        .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
        .join(', '));
  }
  if (b.billingDayOfWeek.isNotEmpty) {
    parts.add('วัน${b.billingDayOfWeek.map((d) => _dayNames[d]).join('-')}');
  }
  if (b.billingWeekOfMonth.isNotEmpty) {
    parts.add(
        'สัปดาห์${b.billingWeekOfMonth.map((w) => _weekNames[w] ?? '$w').join('/')}');
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
    parts.add('วัน${p.paymentDayOfWeek.map((d) => _dayNames[d]).join('-')}');
  }
  if (p.paymentWeekOfMonth.isNotEmpty) {
    parts.add(
        'สัปดาห์${p.paymentWeekOfMonth.map((w) => _weekNames[w] ?? '$w').join('/')}');
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

// ── customer search dialog ───────────────────────────────────────────────────

class _CustomerSearchDialog extends StatefulWidget {
  const _CustomerSearchDialog();

  @override
  State<_CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<_CustomerSearchDialog> {
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.teal[800],
              child: Text(l.isEnglish ? 'Search Customer' : 'ค้นหาลูกค้า',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            // search field
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.isEnglish ? 'Search by customer code or name' : 'ค้นหาจากรหัสหรือชื่อลูกค้า',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            // column headers
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 100,
                      child: Text(l.isEnglish ? 'Code' : 'รหัส',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(
                      child: Text(l.isEnglish ? 'Customer Name' : 'ชื่อลูกค้า',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const Divider(height: 1),
            // list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? Center(
                          child: Text(l.isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                              style: const TextStyle(color: Colors.grey)))
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
                                      child: Text(
                                          l.isEnglish && (c.customerNameEn?.isNotEmpty ?? false)
                                              ? c.customerNameEn!
                                              : c.customerNameTh,
                                          style: const TextStyle(fontSize: 13),
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
            // cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
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
