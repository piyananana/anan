import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_aging_report_service.dart';
import '../services/ap_vendor_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
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
  final BranchService         _branchService  = BranchService();
  final TextEditingController _daysIntervalCtrl =
      TextEditingController(text: '30');

  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth  = 320.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;
  bool   _isEnglish         = false;

  Company? _company;
  Map<String, String>? _headers;

  DateTime         _asOfDate        = DateTime.now();
  List<UserBranch> _allowedBranches = [];
  List<Branch>     _allBranches     = [];
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
    final labels = <String>[_isEnglish ? 'Not yet due' : 'ยังไม่ครบกำหนด'];
    for (int i = 0; i < _overdueColumnCount - 1; i++) {
      labels.add('${i * I + 1}-${(i + 1) * I}');
    }
    labels.add('${_isEnglish ? "Over" : "เกิน"} ${(_overdueColumnCount - 1) * I}');
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
      _branchService.fetchRows(),
    ]);
    _company      = results[0] as Company?;
    _vendorGroups = results[1] as List<ApVendorGroup>;
    _allBranches  = results[2] as List<Branch>;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No outstanding payable data found as of the selected date'
                : 'ไม่พบข้อมูลเจ้าหนี้คงค้าง ณ วันที่ที่เลือก')));
      }

      setState(() {
        _reportData = filtered;
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

  void _onColumnSettingChanged() {
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
  }

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      final sheetName = isEnglish ? 'Aging' : 'อายุหนี้';
      ex.rename('Sheet1', sheetName);
      final s      = ex[sheetName];
      final hdrBg  = ExcelColor.fromHexString('#92D050');
      final totBg  = ExcelColor.fromHexString('#BDD7EE');
      final detBg  = ExcelColor.fromHexString('#F2F2F2');

      final bucketLabels = _dynamicBucketLabels;
      final totalBuckets = _totalBuckets;

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, isEnglish ? 'AP Aging Report' : 'รายงานเจ้าหนี้คงค้างตามอายุหนี้', bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? "As of" : "ณ วันที่"}: ${DateFormat('dd/MM/yyyy').format(_asOfDate)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $ts');

      int r = 3;
      _xlCell(s, r, 0, isEnglish ? 'Vendor Code' : 'รหัสผู้ขาย', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, isEnglish ? 'Vendor Name' : 'ชื่อผู้ขาย',  bg: hdrBg, bold: true);
      for (int b = 0; b < totalBuckets; b++) {
        _xlCell(s, r, 2 + b, bucketLabels[b], bg: hdrBg, bold: true,
            align: HorizontalAlign.Right);
      }
      _xlCell(s, r, 2 + totalBuckets, isEnglish ? 'Total' : 'รวม', bg: hdrBg, bold: true,
          align: HorizontalAlign.Right);
      _xlCell(s, r, 3 + totalBuckets, isEnglish ? 'Credit Limit' : 'วงเงินเครดิต', bg: hdrBg, bold: true,
          align: HorizontalAlign.Right);
      r++;

      final grandBuckets = List<double>.filled(totalBuckets, 0.0);
      double grandTotal = 0.0;

      for (final vend in _reportData) {
        final code     = vend['vendor_code']    as String? ?? '';
        final nameTh   = vend['vendor_name_th'] as String? ?? '';
        final nameEn   = vend['vendor_name_en'] as String?;
        final name     = isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
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

      _xlCell(s, r, 0, isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', bg: totBg, bold: true);
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
      await downloadFile(bytes,
          isEnglish ? 'AP_Aging_Report_$fileTs.xlsx' : 'รายงานเจ้าหนี้คงค้างตามอายุหนี้_$fileTs.xlsx');
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
    final isEnglish       = _isEnglish;
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? (isEnglish ? '(No name)' : '(ไม่ระบุชื่อ)');
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final asOfLine     = '${isEnglish ? "As of" : "ณ วันที่"} ${DateFormat('dd/MM/yyyy').format(_asOfDate)}';

    final bucketLabels = _dynamicBucketLabels;
    final totalBuckets = _totalBuckets;
    final showDetail   = _showDetail;
    final sortOrder    = _sortOrder;

    final conditions = <String>[];
    if (_selectedBranchId != null) {
      final b = _allowedBranches.firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _allowedBranches.first);
      conditions.add('${isEnglish ? "Branch" : "สาขา"}: ${b.branchCode} ${_resolveBranchName(b.branchId, b.branchNameThai, isEnglish)}');
    }
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _vendorGroups.firstWhere((g) => g.id == id,
            orElse: () => _vendorGroups.first);
        final gName = isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai;
        return '${g.groupCode} $gName';
      }).join(', ');
      conditions.add('${isEnglish ? "Vendor Group" : "กลุ่มผู้ขาย"}: $names');
    }
    if ((_vendorCodeFrom ?? '').isNotEmpty || (_vendorCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final from = _vendorCodeFrom ?? '';
      final to   = _vendorCodeTo   ?? '';
      conditions.add(
          '${isEnglish ? "Vendor Code" : "รหัสผู้ขาย"}: ${from.isEmpty ? all : from} – ${to.isEmpty ? all : to}');
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
      final code   = v['vendor_code']    as String? ?? '';
      final nameTh = v['vendor_name_th'] as String? ?? '';
      final nameEn = v['vendor_name_en'] as String?;
      return (
        code:        code,
        name:        isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh,
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
              pw.Expanded(flex: 7, child: pw.Text(isEnglish ? 'AP Aging Report' : 'รายงานเจ้าหนี้คงค้างตามอายุหนี้',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Page" : "หน้า"} ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 3, child: pw.Text('', style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text(asOfLine,
                  textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed by" : "พิมพ์โดย"} $userName',
                  textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(flex: 10, child: pw.Text(conditionLine,
                  textAlign: pw.TextAlign.left, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed" : "พิมพ์เมื่อ"} $printDateStr',
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
            if (docDate.isNotEmpty) dateParts.add('${isEnglish ? "Doc" : "วันที่"}:$docDate');
            if (dueDate.isNotEmpty) dateParts.add('${isEnglish ? "Due" : "ครบ"}:$dueDate');
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
                hCell(
                    showDetail
                        ? (isEnglish ? 'Code / Invoice' : 'รหัส / ใบแจ้งหนี้')
                        : (isEnglish ? 'Code' : 'รหัส'),
                    a: pw.TextAlign.left),
                hCell(
                    showDetail
                        ? (isEnglish ? 'Vendor Name / Doc Date, Due' : 'ชื่อผู้ขาย / วันที่เอกสาร,ครบกำหนด')
                        : (isEnglish ? 'Vendor Name' : 'ชื่อผู้ขาย'),
                    a: pw.TextAlign.left),
                ...bucketLabels.map((l) => hCell(l)),
                hCell(isEnglish ? 'Total' : 'รวม'),
                hCell(isEnglish ? 'Credit Limit' : 'วงเงินเครดิต'),
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

          tableRows.add(summaryRow('', isEnglish ? 'Grand Total' : 'รวมทั้งหมด', grand, grandTotal,
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
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
              tooltip: isEnglish ? 'Export Excel' : 'ส่งออก Excel',
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
                      tooltip: _isFilterExpanded
                          ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                          : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
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
                                    Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                                        style: const TextStyle(
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
                                        decoration: InputDecoration(
                                          labelText: isEnglish ? 'As of' : 'ณ วันที่',
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                          suffixIcon: const Icon(Icons.calendar_today, size: 16),
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
                                        decoration: InputDecoration(
                                            labelText: isEnglish ? 'Branch' : 'สาขา',
                                            border: const OutlineInputBorder(),
                                            isDense: true),
                                        items: [
                                          DropdownMenuItem<int?>(
                                              value: null, child: Text(isEnglish ? '— All Branches —' : '— ทุกสาขา —')),
                                          ..._allowedBranches.map((b) =>
                                              DropdownMenuItem<int?>(
                                                value: b.branchId,
                                                child: Text(
                                                    '${b.branchCode}  ${_resolveBranchName(b.branchId, b.branchNameThai, isEnglish)}',
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
                                      onChanged: (v) =>
                                          setState(() => _selectedGroupIds = v),
                                    ),

                                    // รหัสผู้ขาย ตั้งแต่ / ถึง
                                    const SizedBox(height: 12),
                                    _buildVendorCodeField(
                                      label: isEnglish ? 'Vendor Code From' : 'รหัสผู้ขาย ตั้งแต่',
                                      displayText: _fromLabel,
                                      onPick: () => _pickVendor(isFrom: true),
                                      onClear: () => setState(() {
                                        _vendorCodeFrom = null;
                                        _fromLabel = '';
                                      }),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildVendorCodeField(
                                      label: isEnglish ? 'Vendor Code To' : 'รหัสผู้ขาย ถึง',
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
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Number of Overdue Columns' : 'จำนวนคอลัมน์ที่ครบกำหนดแล้ว',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [2, 3, 4, 5]
                                          .map((n) => DropdownMenuItem<int>(
                                              value: n, child: Text(isEnglish ? '$n columns' : '$n คอลัมน์')))
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
                                        labelText: isEnglish ? 'Days per Column' : 'จำนวนวันต่อคอลัมน์',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                        suffixText: isEnglish ? 'days' : 'วัน',
                                      ),
                                      onEditingComplete: _onColumnSettingChanged,
                                    ),
                                    const SizedBox(height: 12),

                                    // เรียงตามยอดหนี้รวม
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _sortOrder,
                                      decoration: InputDecoration(
                                          labelText: isEnglish ? 'Sort by Total Debt' : 'เรียงตามยอดหนี้รวม',
                                          border: const OutlineInputBorder(),
                                          isDense: true),
                                      items: [
                                        DropdownMenuItem(value: 'none', child: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
                                        DropdownMenuItem(value: 'desc', child: Text(isEnglish ? 'High to Low ↓' : 'มากไปน้อย ↓')),
                                        DropdownMenuItem(value: 'asc',  child: Text(isEnglish ? 'Low to High ↑' : 'น้อยไปมาก ↑')),
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
                                      Expanded(
                                        child: Text(isEnglish ? 'Show invoice details' : 'แสดงรายละเอียดใบแจ้งหนี้',
                                            style: const TextStyle(fontSize: 13)),
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
                                  label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
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
                              ? Center(
                                  child: Text(isEnglish
                                      ? 'Please select conditions and click Generate'
                                      : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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
        final vName = _isEnglish && (result.vendorNameEn ?? '').isNotEmpty
            ? result.vendorNameEn!
            : result.vendorNameTh;
        final label = '${result.vendorCode}  $vName';
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
          hasValue ? displayText : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blueGrey[800],
            child: Text(isEnglish ? 'Search Vendor' : 'ค้นหาผู้ขาย',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: isEnglish ? 'Search by vendor code or name' : 'ค้นหาจากรหัสหรือชื่อผู้ขาย',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true),
              onChanged: _search,
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              SizedBox(width: 100,
                  child: Text(isEnglish ? 'Code' : 'รหัส', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text(isEnglish ? 'Vendor Name' : 'ชื่อผู้ขาย', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vendors.isEmpty
                    ? Center(
                        child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
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
                                Expanded(child: Text(
                                    isEnglish && (v.vendorNameEn ?? '').isNotEmpty
                                        ? v.vendorNameEn!
                                        : v.vendorNameTh,
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
                  child: Text(l.cancel)),
            ]),
          ),
        ]),
      ),
    );
  }
}
