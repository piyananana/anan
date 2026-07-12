import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';
import '../../sa/services/language_provider.dart';
import '../../sa/utils/app_l10n.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_movement_report_service.dart';
import '../services/ap_vendor_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../../sa/models/company.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../widgets/ap_vendor_group_multi_picker.dart';

class ApMovementReportScreen extends StatefulWidget {
  const ApMovementReportScreen({super.key});

  @override
  State<ApMovementReportScreen> createState() => _ApMovementReportScreenState();
}

class _ApMovementReportScreenState extends State<ApMovementReportScreen> {
  final ApMovementReportService _reportService = ApMovementReportService();
  final CompanyService _companyService = CompanyService();
  final AuthService _authService = AuthService();
  final ApVendorGroupService _groupService = ApVendorGroupService();
  final ApVendorService _vendorService = ApVendorService();

  bool _isLoading = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;
  bool _isExporting = false;

  Company? _company;
  Map<String, String>? _headers;

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<ApVendorGroup> _vendorGroups   = [];
  List<int> _selectedGroupIds = [];
  String? _vendorCodeFrom;
  String? _vendorCodeTo;
  String _fromLabel = '';
  String _toLabel   = '';
  bool _pageBreakPerVendor = false;
  bool _matchDocuments     = false;

  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

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
      final raw = await _reportService.getMovementReport(
        dateFrom:       DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:         DateFormat('yyyy-MM-dd').format(_dateTo),
        vendorGroupIds: _selectedGroupIds,
        vendorCodeFrom: _vendorCodeFrom,
        vendorCodeTo:   _vendorCodeTo,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ไม่พบข้อมูลการเคลื่อนไหวเจ้าหนี้ในช่วงที่เลือก')));
      }
      setState(() { _reportData = raw; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSettingChanged() {
    if (_reportData.isNotEmpty) setState(() => _pdfKey++);
  }

  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'Movement');
      final s = ex['Movement'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      String fmtDate(String? raw) {
        if (raw == null || raw.isEmpty) return '';
        try {
          final d = DateTime.parse(raw).toLocal();
          return DateFormat('dd/MM/yyyy').format(DateTime(d.year, d.month, d.day));
        } catch (_) { return raw; }
      }

      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'รายงานการเคลื่อนไหวเจ้าหนี้', bold: true);
      _xlCell(s, 2, 0, 'ช่วงวันที่: ${DateFormat('dd/MM/yyyy').format(_dateFrom)} – ${DateFormat('dd/MM/yyyy').format(_dateTo)}  |  พิมพ์: $tsLabel');

      int r = 3;
      _xlCell(s, r, 0, 'รหัส-ชื่อผู้ขาย', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, 'เลขที่เอกสาร', bg: hdrBg, bold: true);
      _xlCell(s, r, 2, 'วันที่', bg: hdrBg, bold: true);
      _xlCell(s, r, 3, 'ประเภทเอกสาร', bg: hdrBg, bold: true);
      _xlCell(s, r, 4, 'อ้างอิง', bg: hdrBg, bold: true);
      _xlCell(s, r, 5, 'เพิ่มหนี้', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 6, 'ลดหนี้', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 7, 'คงเหลือสะสม', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      r++;

      for (final vend in _reportData) {
        final code    = vend['vendor_code']    as String? ?? '';
        final name    = vend['vendor_name_th'] as String? ?? '';
        final openBal = (vend['opening_balance'] as num?)?.toDouble() ?? 0.0;

        _xlCell(s, r, 0, '$code $name', bold: true);
        _xlCell(s, r, 1, 'ยอดยกมา');
        _xlCell(s, r, 5, TextCellValue(''), align: HorizontalAlign.Right);
        _xlCell(s, r, 6, TextCellValue(''), align: HorizontalAlign.Right);
        _xlCell(s, r, 7, DoubleCellValue(openBal), align: HorizontalAlign.Right, bold: true);
        r++;

        final txns = (vend['transactions'] as List?) ?? [];
        for (final txn in txns) {
          final debit   = (txn['debit_amount']   as num?)?.toDouble() ?? 0.0;
          final credit  = (txn['credit_amount']  as num?)?.toDouble() ?? 0.0;
          final running = (txn['running_balance'] as num?)?.toDouble() ?? 0.0;
          _xlCell(s, r, 0, '', bg: detBg);
          _xlCell(s, r, 1, txn['doc_no']?.toString() ?? '', bg: detBg);
          _xlCell(s, r, 2, fmtDate(txn['doc_date']?.toString()), bg: detBg);
          _xlCell(s, r, 3, txn['doc_name_thai']?.toString() ?? '', bg: detBg);
          _xlCell(s, r, 4, _getRefDisplay(txn as Map<String, dynamic>), bg: detBg);
          _xlCell(s, r, 5, debit  == 0 ? TextCellValue('-') : DoubleCellValue(debit),  bg: detBg, align: HorizontalAlign.Right);
          _xlCell(s, r, 6, credit == 0 ? TextCellValue('-') : DoubleCellValue(credit), bg: detBg, align: HorizontalAlign.Right);
          _xlCell(s, r, 7, DoubleCellValue(running), bg: detBg, align: HorizontalAlign.Right);
          r++;
        }

        final lastBal = txns.isNotEmpty
            ? (txns.last['running_balance'] as num?)?.toDouble() ?? openBal
            : openBal;
        _xlCell(s, r, 0, 'ยอดคงเหลือ $code', bg: totBg, bold: true);
        _xlCell(s, r, 7, DoubleCellValue(lastBal), bg: totBg, bold: true, align: HorizontalAlign.Right);
        r++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'รายงานการเคลื่อนไหวเจ้าหนี้_$ts.xlsx');
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

  static String _getRefDisplay(Map<String, dynamic> txn) {
    final applyRefs = (txn['apply_refs'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final refDocNo = (txn['ref_doc_no'] as String?) ?? '';
    final parts = <String>[];
    if (refDocNo.isNotEmpty) parts.add(refDocNo);
    for (final r in applyRefs) {
      if (!parts.contains(r)) parts.add(r);
    }
    return parts.join(', ');
  }

  static String _getParentRef(Map<String, dynamic> txn) {
    final applyRefs = (txn['apply_refs'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    if (applyRefs.isNotEmpty) return applyRefs.first;
    return (txn['ref_doc_no'] as String?) ?? '';
  }

  static List<Map<String, dynamic>> _pairTransactions(
      List<Map<String, dynamic>> txns, double openingBalance) {
    if (txns.isEmpty) return txns;

    bool isSub(Map<String, dynamic> t) =>
        t['is_advance_sub'] == true || t['is_applied_by_sub'] == true;
    final regular       = txns.where((t) => !isSub(t)).toList();
    final advSubs       = txns.where((t) => t['is_advance_sub']     == true).toList();
    final appliedBySubs = txns.where((t) => t['is_applied_by_sub']  == true).toList();

    final byDocNo = <String, Map<String, dynamic>>{};
    for (final t in regular) {
      final dn = t['doc_no'] as String? ?? '';
      if (dn.isNotEmpty) byDocNo[dn] = t;
    }

    final result = <Map<String, dynamic>>[];
    final placed  = <String>{};

    void attachSubs(String parentDocNo) {
      for (final adv in advSubs) {
        if ((adv['ref_doc_no'] as String?) == parentDocNo) {
          result.add({...adv, '_indent': true});
        }
      }
      for (final app in appliedBySubs) {
        if ((app['ref_doc_no'] as String?) == parentDocNo) {
          result.add({...app, '_indent': true});
        }
      }
    }

    for (final txn in regular) {
      final docNo = txn['doc_no'] as String? ?? '';
      if (placed.contains(docNo)) continue;

      final parentRef = _getParentRef(txn);
      if (parentRef.isNotEmpty && byDocNo.containsKey(parentRef)) continue;

      result.add({...txn, '_indent': false});
      placed.add(docNo);
      attachSubs(docNo);

      for (final child in regular) {
        final cDocNo = child['doc_no'] as String? ?? '';
        if (placed.contains(cDocNo)) continue;
        if (_getParentRef(child) == docNo) {
          result.add({...child, '_indent': true});
          placed.add(cDocNo);
          attachSubs(cDocNo);
        }
      }
    }

    for (final txn in regular) {
      final docNo = txn['doc_no'] as String? ?? '';
      if (!placed.contains(docNo)) {
        result.add({...txn, '_indent': false});
        attachSubs(docNo);
      }
    }

    double running = openingBalance;
    for (final t in result) {
      if (isSub(t)) {
        t['running_balance'] = running;
        continue;
      }
      final dr = (t['debit_amount']  as num?)?.toDouble() ?? 0;
      final cr = (t['credit_amount'] as num?)?.toDouble() ?? 0;
      running += dr - cr;
      t['running_balance'] = running;
    }

    return result;
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/fonts/THSarabun Italic.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);
    final fontItalic = pw.Font.ttf(fontItalicData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine =
        'ช่วงวันที่ ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
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
      conditions.add('รหัสผู้ขาย: ${from.isEmpty ? '(ทั้งหมด)' : from} – ${to.isEmpty ? '(ทั้งหมด)' : to}');
    }
    if (_pageBreakPerVendor) conditions.add('ขึ้นหน้าใหม่ทุกผู้ขาย');
    if (_matchDocuments)     conditions.add('จับคู่เอกสาร');
    final matchDocs = _matchDocuments;
    final conditionLine = conditions.isEmpty ? 'ทุกผู้ขาย' : conditions.join(' | ');

    String fmtDate(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      try {
        final local = DateTime.parse(raw).toLocal();
        return DateFormat('dd/MM/yyyy').format(DateTime(local.year, local.month, local.day));
      } catch (_) { return raw; }
    }

    const colW = {
      0: pw.FlexColumnWidth(8),
      1: pw.FlexColumnWidth(6),
      2: pw.FlexColumnWidth(10),
      3: pw.FlexColumnWidth(8),
      4: pw.FlexColumnWidth(8),
      5: pw.FlexColumnWidth(8),
      6: pw.FlexColumnWidth(9),
    };

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
            pw.Expanded(flex: 7, child: pw.Text('รายงานการเคลื่อนไหวเจ้าหนี้',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 3, child: pw.Text('หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 3, child: pw.Text('', style: const pw.TextStyle(fontSize: 12))),
            pw.Expanded(flex: 7, child: pw.Text(dateRangeLine, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
            pw.Expanded(flex: 3, child: pw.Text('พิมพ์โดย $userName', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 10, child: pw.Text('* $conditionLine', textAlign: pw.TextAlign.left, style: const pw.TextStyle(fontSize: 10))),
            pw.Expanded(flex: 3, child: pw.Text('พิมพ์เมื่อ $printDateStr', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
          ]),
          pw.SizedBox(height: 4),
        ]);

    List<pw.Widget> buildVendorContent(
        Map<String, dynamic> vendor,
        pw.TextStyle normal,
        pw.TextStyle bold,
        pw.TextStyle italic) {
      final openingBal = (vendor['opening_balance'] as num?)?.toDouble() ?? 0;
      final code = vendor['vendor_code']    as String? ?? '';
      final name = vendor['vendor_name_th'] as String? ?? '';

      final rawTxns = (vendor['transactions'] as List? ?? []).cast<Map<String, dynamic>>();
      final txns = matchDocs ? _pairTransactions(rawTxns, openingBal) : rawTxns;

      final closingBal = txns.isNotEmpty
          ? (txns.last['running_balance'] as num?)?.toDouble() ?? openingBal
          : (vendor['closing_balance'] as num?)?.toDouble() ?? openingBal;

      bool isSubEntry(Map<String, dynamic> t) =>
          t['is_advance_sub'] == true || t['is_applied_by_sub'] == true;
      final totalDr = rawTxns.where((t) => !isSubEntry(t)).fold(0.0, (s, t) => s + ((t['debit_amount']  as num?)?.toDouble() ?? 0));
      final totalCr = rawTxns.where((t) => !isSubEntry(t)).fold(0.0, (s, t) => s + ((t['credit_amount'] as num?)?.toDouble() ?? 0));

      const cBlue   = PdfColor(0.82, 0.87, 0.90);
      const cYellow = PdfColor(1.0, 0.98, 0.88);
      const cGreen  = PdfColor(0.82, 0.87, 0.87);

      final rows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: cGreen),
          children: [
            _hCell('เลขที่เอกสาร', bold, a: pw.TextAlign.left),
            _hCell('วันที่', bold),
            _hCell('ประเภทเอกสาร', bold, a: pw.TextAlign.left),
            _hCell('อ้างอิง', bold, a: pw.TextAlign.left),
            _hCell('เพิ่มหนี้', bold),
            _hCell('ลดหนี้', bold),
            _hCell('คงเหลือสะสม', bold),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: cYellow),
          children: [
            _dCell('ยอดยกมา', bold, a: pw.TextAlign.left),
            _dCell('', normal), _dCell('', normal), _dCell('', normal),
            _dCell('', normal), _dCell('', normal),
            _amtCell(openingBal, bold, color: _balColor(openingBal)),
          ],
        ),
        ...txns.map((t) {
          final isAdvSub     = t['is_advance_sub']     == true;
          final isAppliedSub = t['is_applied_by_sub']  == true;
          final isSub        = isAdvSub || isAppliedSub;
          final dr  = (t['debit_amount']   as num?)?.toDouble() ?? 0;
          final cr  = (t['credit_amount']  as num?)?.toDouble() ?? 0;
          final bal = (t['running_balance'] as num?)?.toDouble() ?? 0;
          final subAmt = isAdvSub
              ? (t['advance_amount']  as num?)?.toDouble() ?? 0
              : isAppliedSub
                  ? (t['applied_amount'] as num?)?.toDouble() ?? 0
                  : 0.0;
          final indent = t['_indent'] == true || isSub;
          final rowDec = indent ? const pw.BoxDecoration(color: PdfColor(0.96, 0.96, 0.96)) : null;
          final docNoText = indent ? '>>  ${t['doc_no'] as String? ?? ''}' : t['doc_no'] as String? ?? '';
          final dateText = isSub ? '' : fmtDate(t['doc_date'] as String?);
          final refText = isAdvSub
              ? (t['advance_ref'] as String? ?? '')
              : isAppliedSub
                  ? (t['applied_by_ref'] as String? ?? '')
                  : _getRefDisplay(t);

          return pw.TableRow(
            decoration: rowDec,
            children: [
              _dCell(docNoText, italic, a: pw.TextAlign.left),
              _dCell(dateText, italic),
              _dCell(t['doc_name_thai'] as String? ?? '', italic, a: pw.TextAlign.left),
              _dCell(refText, italic, a: pw.TextAlign.left),
              (!isSub && dr > 0) ? _amtCell(dr, indent ? italic : normal, color: PdfColors.black) : _dCell('-', normal, a: pw.TextAlign.right),
              isSub
                  ? (subAmt > 0 ? _amtCell(subAmt, italic, color: const PdfColor(0.45, 0.45, 0.45)) : _dCell('-', normal, a: pw.TextAlign.right))
                  : (cr > 0 ? _amtCell(cr, indent ? italic : normal, color: PdfColors.black) : _dCell('-', normal, a: pw.TextAlign.right)),
              isSub ? _dCell('', normal) : _amtCell(bal, indent ? italic : normal, color: _balColor(bal)),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: cYellow),
          children: [
            _dCell('รวม', bold, a: pw.TextAlign.left),
            _dCell('', bold), _dCell('', bold), _dCell('', bold),
            _amtCell(totalDr, bold, color: PdfColors.black),
            _amtCell(totalCr, bold, color: PdfColors.black),
            _amtCell(closingBal, bold, color: _balColor(closingBal)),
          ],
        ),
      ];

      return [
        pw.Container(
          decoration: const pw.BoxDecoration(color: cBlue),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(children: [
            pw.Text('$code  $name', style: pw.TextStyle(font: fontBold, fontSize: 10)),
          ]),
        ),
        pw.Table(border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400), columnWidths: colW, children: rows),
        pw.SizedBox(height: 6),
      ];
    }

    List<pw.Widget> buildGrandTotal(pw.TextStyle bold, pw.TextStyle normal) {
      bool isSubG(Map<String, dynamic> t) =>
          t['is_advance_sub'] == true || t['is_applied_by_sub'] == true;
      final grandDr = _reportData.fold(0.0, (s, v) {
        final txns = (v['transactions'] as List? ?? []).cast<Map<String, dynamic>>().where((t) => !isSubG(t));
        return s + txns.fold(0.0, (ss, t) => ss + ((t['debit_amount'] as num?)?.toDouble() ?? 0));
      });
      final grandCr = _reportData.fold(0.0, (s, v) {
        final txns = (v['transactions'] as List? ?? []).cast<Map<String, dynamic>>().where((t) => !isSubG(t));
        return s + txns.fold(0.0, (ss, t) => ss + ((t['credit_amount'] as num?)?.toDouble() ?? 0));
      });
      final grandClose = _reportData.fold(0.0, (s, v) => s + ((v['closing_balance'] as num?)?.toDouble() ?? 0));

      return [
        pw.Table(
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          columnWidths: colW,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor(0.75, 0.85, 0.88)),
              children: [
                _dCell('รวมทุกผู้ขาย', bold, a: pw.TextAlign.left),
                _dCell('', bold), _dCell('', bold), _dCell('', bold),
                _amtCell(grandDr, bold, color: PdfColors.black),
                _amtCell(grandCr, bold, color: PdfColors.black),
                _amtCell(grandClose, bold, color: _balColor(grandClose)),
              ],
            ),
          ],
        ),
      ];
    }

    if (_pageBreakPerVendor) {
      for (int i = 0; i < _reportData.length; i++) {
        final vendor = _reportData[i];
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            theme: pw.ThemeData.withFont(base: font, bold: fontBold),
            margin: const pw.EdgeInsets.all(20),
            header: pageHeader(),
            build: (ctx) {
              final normal = pw.TextStyle(font: font, fontSize: 9);
              final bold   = pw.TextStyle(font: fontBold, fontSize: 9);
              final italic = pw.TextStyle(font: fontItalic, fontSize: 9);
              final content = buildVendorContent(vendor, normal, bold, italic);
              if (i == _reportData.length - 1) content.addAll(buildGrandTotal(bold, normal));
              return content;
            },
          ),
        );
      }
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.all(20),
          header: pageHeader(),
          build: (ctx) {
            final normal = pw.TextStyle(font: font, fontSize: 9);
            final bold   = pw.TextStyle(font: fontBold, fontSize: 9);
            final italic = pw.TextStyle(font: fontItalic, fontSize: 9);
            final content = <pw.Widget>[];
            for (final vendor in _reportData) {
              content.addAll(buildVendorContent(vendor, normal, bold, italic));
            }
            content.addAll(buildGrandTotal(bold, normal));
            return content;
          },
        ),
      );
    }

    return doc.save();
  }

  static PdfColor _balColor(double v) => v < 0 ? PdfColors.red700 : PdfColors.black;

  static pw.Widget _hCell(String t, pw.TextStyle s, {pw.TextAlign a = pw.TextAlign.center}) =>
      pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(t, style: s, textAlign: a));

  static pw.Widget _dCell(String t, pw.TextStyle s, {pw.TextAlign a = pw.TextAlign.center}) =>
      pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t, style: s, textAlign: a));

  static pw.Widget _amtCell(double v, pw.TextStyle s, {PdfColor color = PdfColors.black}) =>
      pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
            NumberFormat('#,##0.00', 'en_US').format(v),
            style: pw.TextStyle(font: s.font, fontSize: s.fontSize, color: color),
            textAlign: pw.TextAlign.right,
          ));

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
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
              tooltip: 'Export Excel',
              onPressed: _reportData.isEmpty ? null : _exportExcel,
            ),
        ],
      ),
      body: _isLoading && _company == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // toggle
                  Container(
                    width: 36,
                    color: Colors.blueGrey[800],
                    child: IconButton(
                      icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
                      onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                    ),
                  ),
                  // filter panel
                  AnimatedContainer(
                    duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                    width: _isFilterExpanded ? _filterPanelWidth : 0.0,
                    child: ClipRect(
                      child: OverflowBox(
                        maxWidth: _filterPanelWidth, minWidth: _filterPanelWidth,
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
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 16),

                                    _buildDateField(label: 'วันที่เอกสาร ตั้งแต่', date: _dateFrom, onPick: (d) => setState(() => _dateFrom = d)),
                                    const SizedBox(height: 12),
                                    _buildDateField(label: 'วันที่เอกสาร ถึง', date: _dateTo, onPick: (d) => setState(() => _dateTo = d)),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    ApVendorGroupMultiPicker(
                                      groups: _vendorGroups,
                                      selectedIds: _selectedGroupIds,
                                      onChanged: (v) => setState(() => _selectedGroupIds = v),
                                    ),

                                    const SizedBox(height: 12),
                                    _buildVendorCodeField(
                                      label: 'รหัสผู้ขาย ตั้งแต่',
                                      displayText: _fromLabel,
                                      onPick: () => _pickVendor(isFrom: true),
                                      onClear: () => setState(() { _vendorCodeFrom = null; _fromLabel = ''; }),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildVendorCodeField(
                                      label: 'รหัสผู้ขาย ถึง',
                                      displayText: _toLabel,
                                      onPick: () => _pickVendor(isFrom: false),
                                      onClear: () => setState(() { _vendorCodeTo = null; _toLabel = ''; }),
                                    ),

                                    const SizedBox(height: 8),
                                    const Divider(height: 1),

                                    Row(children: [
                                      const Expanded(child: Text('จับคู่เอกสาร', style: TextStyle(fontSize: 13))),
                                      Switch(
                                        value: _matchDocuments,
                                        activeColor: Colors.blueGrey[800],
                                        onChanged: (v) { setState(() => _matchDocuments = v); _onSettingChanged(); },
                                      ),
                                    ]),

                                    Row(children: [
                                      const Expanded(child: Text('ขึ้นหน้าใหม่ทุกผู้ขาย', style: TextStyle(fontSize: 13))),
                                      Switch(
                                        value: _pageBreakPerVendor,
                                        activeColor: Colors.blueGrey[800],
                                        onChanged: (v) { setState(() => _pageBreakPerVendor = v); _onSettingChanged(); },
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SizedBox(
                                width: double.infinity, height: 50,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('ประมวลผลรายงาน'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
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
                        onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                        onHorizontalDragUpdate: (d) => setState(() {
                          _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth);
                        }),
                        onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
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
                              ? const Center(child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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

  Widget _buildDateField({required String label, required DateTime date, required void Function(DateTime) onPick}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.calendar_today, size: 16)),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }

  Future<void> _pickVendor({required bool isFrom}) async {
    final result = await showDialog<ApVendor>(
      context: context,
      builder: (_) => _MovRptVendorSearchDialog(vendorService: _vendorService),
    );
    if (result != null && mounted) {
      setState(() {
        final label = '${result.vendorCode}  ${result.vendorNameTh}';
        if (isFrom) { _vendorCodeFrom = result.vendorCode; _fromLabel = label; }
        else        { _vendorCodeTo   = result.vendorCode; _toLabel   = label; }
      });
    }
  }

  Widget _buildVendorCodeField({required String label, required String displayText, required VoidCallback onPick, required VoidCallback onClear}) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onPick, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.search, size: 18, color: Colors.blueGrey[800]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(hasValue ? displayText : '— ทั้งหมด —',
            style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _MovRptVendorSearchDialog extends StatefulWidget {
  final ApVendorService vendorService;
  const _MovRptVendorSearchDialog({required this.vendorService});

  @override
  State<_MovRptVendorSearchDialog> createState() => _MovRptVendorSearchDialogState();
}

class _MovRptVendorSearchDialogState extends State<_MovRptVendorSearchDialog> {
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
      final list = await widget.vendorService.fetchRows(search: query.trim().isEmpty ? null : query.trim());
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
              controller: _searchCtrl, autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'ค้นหาจากรหัสหรือชื่อผู้ขาย',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(), isDense: true),
              onChanged: _search,
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(children: [
              SizedBox(width: 100, child: Text('รหัส', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('ชื่อผู้ขาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vendors.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.grey)))
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
                                SizedBox(width: 100, child: Text(v.vendorCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Expanded(child: Text(v.vendorNameTh, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          );
                        }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
            ]),
          ),
        ]),
      ),
    );
  }
}
