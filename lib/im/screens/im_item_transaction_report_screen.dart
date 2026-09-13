import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../services/im_item_service.dart';
import '../services/im_item_category_service.dart';
import '../services/im_item_transaction_report_service.dart';
import '../../utils/file_download.dart';

// รายงานสินค้าในธุรกรรม — flat list ระดับบรรทัดสินค้า (ต่างจาก im_transaction_report_screen ซึ่งเป็นระดับเอกสาร)
// รวมทุก sys_doc_type ของ IM ในรายงานเดียว จัดกลุ่ม+แสดงยอดรวมย่อยตามฟีลด์ที่เลือกเรียง — backend ORDER BY มาให้ถูก
// ต้องแล้ว ฝั่งนี้แค่เดินลิสต์ตามลำดับที่ได้รับมาเป็น linear pass เดียว (ห้าม re-sort/regroup ด้วย Map ที่นี่
// เพราะถ้าเรียงตามวันที่ การจัดกลุ่มด้วย Map แล้ว sort key ตามตัวอักษร จะทำให้ลำดับวันที่ผิดเพี้ยนได้)

const Map<String, String> _sortLabelsTh = {
  'doc_date': 'วันที่เอกสาร',
  'doc_type': 'ประเภทเอกสาร',
  'item_code': 'รหัสสินค้า',
  'party_code': 'รหัสผู้ซื้อ/ผู้ขาย',
};
const Map<String, String> _sortLabelsEn = {
  'doc_date': 'Document Date',
  'doc_type': 'Document Type',
  'item_code': 'Item Code',
  'party_code': 'Vendor/Customer Code',
};

class ImItemTransactionReportScreen extends StatefulWidget {
  const ImItemTransactionReportScreen({super.key});

  @override
  State<ImItemTransactionReportScreen> createState() => _ImItemTransactionReportScreenState();
}

class _ImItemTransactionReportScreenState extends State<ImItemTransactionReportScreen> {
  final _reportService  = ImItemTransactionReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();
  final _categorySvc    = ImItemCategoryService();

  bool   _isEnglish        = false;
  bool   _isLoading        = false;
  bool   _isFilterExpanded = true;
  double _filterPanelWidth = 330.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey           = 0;
  bool   _isExporting      = false;

  Company? _company;
  Map<String, String>? _headers;
  // ชื่อรายงาน — ใช้ชื่อเมนู (จาก AppBar/MenuTitle) แทนข้อความ hardcode เพื่อให้ตรงกับที่ผู้ใช้เห็นบนแท็บเสมอ
  String _reportTitle = '';

  List<ImItemCategory> _categories = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<String> _selectedSysDocTypes = [];
  List<int>    _selectedCategoryIds = [];
  String? _itemCodeFrom;
  String? _itemCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';
  String _sort = 'doc_date'; // 'doc_date' | 'doc_type' | 'item_code' | 'party_code'

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
      _categorySvc.fetchActiveRows(),
    ]);
    _company = results[0] as Company?;
    _categories = (results[1] as List<ImItemCategory>).where((c) => c.categoryType == 'CATEGORY').toList();
    if (mounted) setState(() {});
  }

  // ─── report ───────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getReport(
        dateFrom:      DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:        DateFormat('yyyy-MM-dd').format(_dateTo),
        sysDocTypes:   _selectedSysDocTypes,
        categoryIds:   _selectedCategoryIds,
        itemCodeFrom:  _itemCodeFrom,
        itemCodeTo:    _itemCodeTo,
        sort:          _sort,
      );
      if (raw.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No data found for the selected conditions'
                : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
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

  // ─── shared value helpers ─────────────────────────────────────────────────

  static num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);

  String _docTypeName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['doc_name_eng'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (r['doc_name_thai'] as String? ?? '');
  }

  String _itemName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['item_name_en'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (r['item_name_th'] as String? ?? '');
  }

  // ของแถม — badge ต่อท้ายชื่อสินค้า เพื่อตรวจสอบย้อนหลังได้ว่าบรรทัดใดเป็นของแถม (ไม่กระทบ GL/logic ใดๆ)
  String _freeSuffix(Map<String, dynamic> r, bool isEnglish) =>
      r['is_free'] == true ? (isEnglish ? '  (Free)' : '  (ของแถม)') : '';

  String _uomName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['uom_name_en'] as String?;
    final th = r['uom_name_th'] as String?;
    if (isEnglish && (en ?? '').isNotEmpty) return en!;
    if ((th ?? '').isNotEmpty) return th!;
    return r['uom_code']?.toString() ?? '';
  }

  String _partyLabel(Map<String, dynamic> r, bool isEnglish) {
    final code = r['party_code'] as String?;
    final name = r['party_name'] as String?;
    if ((code ?? '').isEmpty && (name ?? '').isEmpty) {
      return isEnglish ? '-' : '-';
    }
    return [code, name].where((s) => (s ?? '').isNotEmpty).join('  ');
  }

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy').format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  // key ที่ใช้ตรวจการเปลี่ยนกลุ่ม (ต้องคงลำดับเดิมจาก backend เสมอ ไม่ re-sort)
  String _groupKey(Map<String, dynamic> r) {
    switch (_sort) {
      case 'doc_type':   return r['doc_code'] as String? ?? '';
      case 'item_code':  return r['item_code'] as String? ?? '';
      case 'party_code': return r['party_code'] as String? ?? '';
      default:           return _fmtDate(r['doc_date'] as String?);
    }
  }

  String _groupLabel(Map<String, dynamic> r, bool isEnglish) {
    switch (_sort) {
      case 'doc_type':
        return '${r['doc_code'] ?? ''}  ${_docTypeName(r, isEnglish)}';
      case 'item_code':
        return '${r['item_code'] ?? ''}  ${_itemName(r, isEnglish)}';
      case 'party_code':
        final label = _partyLabel(r, isEnglish);
        return label == '-' ? (isEnglish ? '(No counterparty)' : '(ไม่มีคู่ค้า)') : label;
      default:
        return _fmtDate(r['doc_date'] as String?);
    }
  }

  String _groupTypeLabel(bool isEnglish) =>
      isEnglish ? _sortLabelsEn[_sort]! : _sortLabelsTh[_sort]!;

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    final sort = _sort;
    final doc            = pw.Document();
    final fontData       = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData   = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine = '${isEnglish ? "Date range" : "ช่วงวันที่"} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[];
    if (_selectedSysDocTypes.isNotEmpty) {
      final names = _selectedSysDocTypes.map((sdt) => imSysDocType[sdt] ?? sdt).join(', ');
      conditions.add('${isEnglish ? "Document Types" : "ประเภทเอกสาร"}: $names');
    }
    if (_selectedCategoryIds.isNotEmpty) {
      final names = _categories
          .where((c) => _selectedCategoryIds.contains(c.id))
          .map((c) => c.categoryCode)
          .join(', ');
      conditions.add('${isEnglish ? "Categories" : "หมวดหมู่"}: $names');
    }
    if ((_itemCodeFrom ?? '').isNotEmpty || (_itemCodeTo ?? '').isNotEmpty) {
      conditions.add('${isEnglish ? "Item Code" : "รหัสสินค้า"}: ${_itemCodeFrom ?? (isEnglish ? "start" : "เริ่มต้น")} - ${_itemCodeTo ?? (isEnglish ? "end" : "สุดท้าย")}');
    }
    conditions.add('${isEnglish ? "Sorted by" : "เรียงตาม"}: ${isEnglish ? _sortLabelsEn[sort] : _sortLabelsTh[sort]}');
    final conditionLine = conditions.isEmpty
        ? (isEnglish ? 'All documents' : 'ทุกเอกสาร')
        : conditions.join(' | ');

    const mg = 20.0;
    final pageW = format.width - mg * 2;

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cGroup  = PdfColor(0.93, 0.93, 0.97);
    const cGroupTot = PdfColor(0.80, 0.93, 0.88);
    const cTotal  = PdfColor(0.75, 0.88, 0.96);
    const cBorder = PdfColors.grey400;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final fmtQty = NumberFormat('#,##0.####', 'en_US');

    // ─── 7 คอลัมน์ตามที่ผู้ใช้กำหนด ─────────────────────────────────────────
    final cw = {
      'date':   pageW * 0.09,
      'type':   pageW * 0.14,
      'docNo':  pageW * 0.12,
      'party':  pageW * 0.20,
      'item':   pageW * 0.22,
      'qty':    pageW * 0.11,
      'amount': pageW * 0.12,
    };

    pw.Widget cell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: bold ? tB(9) : tN(9), textAlign: a),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cGreen, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['date']!,   isEnglish ? 'Date'            : 'วันที่เอกสาร',   bold: true),
        cell(cw['type']!,   isEnglish ? 'Document Type'   : 'ประเภทเอกสาร',   bold: true),
        cell(cw['docNo']!,  isEnglish ? 'Doc No.'         : 'เลขที่เอกสาร',   bold: true),
        cell(cw['party']!,  isEnglish ? 'Vendor/Customer' : 'ผู้ซื้อ/ผู้ขาย',  bold: true),
        cell(cw['item']!,   isEnglish ? 'Item'            : 'สินค้า',        bold: true),
        cell(cw['qty']!,    isEnglish ? 'Qty  Unit'        : 'จำนวน  หน่วย',   bold: true, a: pw.TextAlign.right),
        cell(cw['amount']!, isEnglish ? 'Amount'          : 'จำนวนเงิน',     bold: true, a: pw.TextAlign.right),
      ]),
    );

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
        pw.Expanded(flex: 6, child: pw.Text(reportTitle,
            textAlign: pw.TextAlign.center, style: tB(15))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.Text(dateRangeLine, textAlign: pw.TextAlign.center, style: tN(10))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.Text('* $conditionLine', style: tN(9))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 4),
      tableHeader,
    ]);

    // ─── เดินข้อมูลแบบ linear pass เดียว จัดกลุ่ม+ยอดรวมย่อยตามลำดับที่ backend ส่งมา (ห้าม re-sort) ────
    final content = <pw.Widget>[];
    String? curKey;
    String curLabel = '';
    double curSubtotal = 0;
    int curCount = 0;
    double grandTotal = 0;
    int rowIdx = 0;
    final groupTypeLabel = _groupTypeLabel(isEnglish);

    pw.Widget groupHeaderBar(String label) => pw.Container(
          width: pageW,
          color: cGroup,
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: pw.Text('$groupTypeLabel:  $label', style: tB(9)),
        );

    // แถวยอดรวม — วางตัวเลขให้ชิดขวาในตำแหน่งคอลัมน์ "จำนวนเงิน" เดียวกับแถวข้อมูล (แนวคิดเดียวกับ cell()
    // แต่ vertical padding มากกว่าเล็กน้อยให้ดูเป็นแถวสรุป)
    pw.Widget totalAmountCell(double amt) => pw.SizedBox(
          width: cw['amount']!,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: pw.Text(fmt.format(amt), style: tB(9), textAlign: pw.TextAlign.right),
          ),
        );

    pw.Widget totalRow(PdfColor bg, String label, double amount) => pw.Container(
          width: pageW,
          color: bg,
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: pw.Text(label, style: tB(9)),
              ),
            ),
            totalAmountCell(amount),
          ]),
        );

    pw.Widget groupSubtotalBar(String label, double subtotal, int count) => totalRow(
          cGroupTot,
          isEnglish ? 'Subtotal ($count line(s)):' : 'รวมยอด ($count รายการ):',
          subtotal,
        );

    for (final r in _reportData) {
      final key = _groupKey(r);
      if (curKey != null && key != curKey) {
        content.add(groupSubtotalBar(curLabel, curSubtotal, curCount));
        curSubtotal = 0;
        curCount = 0;
      }
      final isNewGroup = key != curKey;
      curKey = key;
      curLabel = _groupLabel(r, isEnglish);
      if (isNewGroup) content.add(groupHeaderBar(curLabel));

      final amount = _num(r['total_value_lc']).toDouble();
      curSubtotal += amount;
      grandTotal += amount;
      curCount++;

      final bg = rowIdx.isOdd ? cStripe : null;
      final qtyUnit = '${fmtQty.format(_num(r['qty']))} ${_uomName(r, isEnglish)}';
      content.add(pw.Container(
        color: bg,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
        child: pw.Row(children: [
          cell(cw['date']!,   _fmtDate(r['doc_date'] as String?)),
          cell(cw['type']!,   '${r['doc_code'] ?? ''}  ${_docTypeName(r, isEnglish)}'),
          cell(cw['docNo']!,  r['doc_no'] as String? ?? ''),
          cell(cw['party']!,  _partyLabel(r, isEnglish)),
          cell(cw['item']!,   '${r['item_code'] ?? ''}  ${_itemName(r, isEnglish)}${_freeSuffix(r, isEnglish)}'),
          cell(cw['qty']!,    qtyUnit, a: pw.TextAlign.right),
          cell(cw['amount']!, fmt.format(amount), a: pw.TextAlign.right),
        ]),
      ));
      rowIdx++;
    }
    if (curKey != null) content.add(groupSubtotalBar(curLabel, curSubtotal, curCount));

    content.add(totalRow(
      cTotal,
      isEnglish ? 'Grand total ${_reportData.length} line(s):' : 'รวมทั้งสิ้น ${_reportData.length} รายการ:',
      grandTotal,
    ));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(mg),
        header: pageHeader(),
        build: (ctx) => content,
      ),
    );

    return doc.save();
  }

  // ─── Excel ────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      const sheet = 'ItemTransaction';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final groupBg = ExcelColor.fromHexString('#EDEDF7');
      final groupTotBg = ExcelColor.fromHexString('#CCE9DE');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0,
          '${isEnglish ? "Date range" : "ช่วงวันที่"}: ${DateFormat("dd/MM/yyyy").format(_dateFrom)} – ${DateFormat("dd/MM/yyyy").format(_dateTo)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      final hdrs = isEnglish
          ? ['Date', 'Document Type', 'Doc No.', 'Vendor/Customer', 'Item', 'Qty', 'Unit', 'Amount']
          : ['วันที่เอกสาร', 'ประเภทเอกสาร', 'เลขที่เอกสาร', 'ผู้ซื้อ/ผู้ขาย', 'สินค้า', 'จำนวน', 'หน่วย', 'จำนวนเงิน'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 3, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 4;
      String? curKey;
      String curLabel = '';
      double curSubtotal = 0;
      int curCount = 0;
      double grandTotal = 0;
      final groupTypeLabel = _groupTypeLabel(isEnglish);

      void writeGroupSubtotal() {
        _xl(s, row, 0,
            isEnglish
                ? 'Subtotal $groupTypeLabel $curLabel ($curCount line(s)):'
                : 'รวมยอด $groupTypeLabel $curLabel ($curCount รายการ):',
            bg: groupTotBg, bold: true);
        for (int c = 1; c < 7; c++) {
          _xl(s, row, c, '', bg: groupTotBg);
        }
        _xl(s, row, 7, curSubtotal, bg: groupTotBg, bold: true, align: HorizontalAlign.Right);
        row++;
      }

      for (final r in _reportData) {
        final key = _groupKey(r);
        if (curKey != null && key != curKey) {
          writeGroupSubtotal();
          curSubtotal = 0;
          curCount = 0;
        }
        final isNewGroup = key != curKey;
        curKey = key;
        curLabel = _groupLabel(r, isEnglish);
        if (isNewGroup) {
          _xl(s, row, 0, '$groupTypeLabel:  $curLabel', bg: groupBg, bold: true);
          row++;
        }

        final amount = _num(r['total_value_lc']).toDouble();
        curSubtotal += amount;
        grandTotal += amount;
        curCount++;

        _xl(s, row, 0, _fmtDate(r['doc_date'] as String?));
        _xl(s, row, 1, '${r['doc_code'] ?? ''}  ${_docTypeName(r, isEnglish)}');
        _xl(s, row, 2, r['doc_no'] as String? ?? '');
        _xl(s, row, 3, _partyLabel(r, isEnglish));
        _xl(s, row, 4, '${r['item_code'] ?? ''}  ${_itemName(r, isEnglish)}${_freeSuffix(r, isEnglish)}');
        _xl(s, row, 5, _num(r['qty']).toDouble(), align: HorizontalAlign.Right);
        _xl(s, row, 6, _uomName(r, isEnglish));
        _xl(s, row, 7, amount, align: HorizontalAlign.Right);
        row++;
      }
      if (curKey != null) writeGroupSubtotal();

      _xl(s, row, 0,
          isEnglish ? 'Grand total ${_reportData.length} line(s):' : 'รวมทั้งสิ้น ${_reportData.length} รายการ:',
          bg: totBg, bold: true);
      for (int c = 1; c < 7; c++) {
        _xl(s, row, c, '', bg: totBg);
      }
      _xl(s, row, 7, grandTotal, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'IM_Item_Transaction_Report' : 'รายงานสินค้าในธุรกรรม';
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${title}_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xl(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

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

  Future<void> _pickSysDocTypes() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiPickerDialog<MapEntry<String, String>>(
        title: isEnglish ? 'Select Document Types' : 'เลือกประเภทเอกสาร',
        items: imSysDocType.entries.toList(),
        selected: _selectedSysDocTypes,
        idOf: (e) => e.key,
        labelOf: (e) => e.value,
        isEnglish: isEnglish,
        showSearch: false,
      ),
    );
    if (result != null && mounted) setState(() => _selectedSysDocTypes = result);
  }

  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImItemCategory>(
        title: isEnglish ? 'Select Item Categories' : 'เลือกหมวดหมู่สินค้า',
        items: _categories,
        selected: _selectedCategoryIds.map((e) => e.toString()).toList(),
        idOf: (c) => c.id.toString(),
        labelOf: (c) => '${c.categoryCode}  ${isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
        isEnglish: isEnglish,
        showSearch: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategoryIds = result.map((e) => int.parse(e)).toList());
    }
  }

  Future<void> _pickItem({required bool isFrom}) async {
    final result = await showDialog<ImItem>(
      context: context,
      builder: (_) => const _ItemPickerDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      final displayName = _isEnglish && (result.itemNameEn ?? '').isNotEmpty ? result.itemNameEn! : result.itemNameTh;
      final label = '${result.itemCode}  $displayName';
      if (isFrom) {
        _itemCodeFrom = result.itemCode;
        _fromLabel = label;
      } else {
        _itemCodeTo = result.itemCode;
        _toLabel = label;
      }
    });
  }

  Widget _buildMultiField({required String label, required int count, required String allLabel, required VoidCallback onTap, required VoidCallback onClear}) {
    final hasValue = count > 0;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onTap, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_drop_down, size: 20))),
        ]),
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          hasValue ? (_isEnglish ? '$count selected' : 'เลือก $count รายการ') : allLabel,
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPickerField({required String label, required String displayText, required VoidCallback onPick, required VoidCallback onClear}) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onPick, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.search, size: 18, color: Colors.teal[700]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Item Transaction Report' : 'รายงานสินค้าในธุรกรรม'));
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: (_reportData.isEmpty || !canExport) ? null : _exportExcel,
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              color: Colors.teal[800],
              child: IconButton(
                icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse Filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand Filter' : 'ขยายเงื่อนไข'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
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
                              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),

                              _buildDateField(label: isEnglish ? 'Document Date From' : 'วันที่เอกสาร ตั้งแต่', date: _dateFrom, onPick: (d) => setState(() => _dateFrom = d)),
                              const SizedBox(height: 12),
                              _buildDateField(label: isEnglish ? 'Document Date To' : 'วันที่เอกสาร ถึง', date: _dateTo, onPick: (d) => setState(() => _dateTo = d)),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildMultiField(
                                label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
                                count: _selectedSysDocTypes.length,
                                allLabel: isEnglish ? '— All Types —' : '— ทุกประเภท —',
                                onTap: _pickSysDocTypes,
                                onClear: () => setState(() => _selectedSysDocTypes = []),
                              ),
                              if (_selectedSysDocTypes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4, runSpacing: 2,
                                  children: _selectedSysDocTypes.map((sdt) => Chip(
                                    label: Text(imSysDocType[sdt] ?? sdt, style: const TextStyle(fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.teal[50],
                                    side: BorderSide(color: Colors.teal[200]!),
                                  )).toList(),
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildMultiField(
                                label: isEnglish ? 'Item Category' : 'หมวดหมู่สินค้า',
                                count: _selectedCategoryIds.length,
                                allLabel: isEnglish ? '— All Categories —' : '— ทุกหมวดหมู่ —',
                                onTap: _pickCategories,
                                onClear: () => setState(() => _selectedCategoryIds = []),
                              ),
                              if (_selectedCategoryIds.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4, runSpacing: 2,
                                  children: _selectedCategoryIds.map((id) {
                                    final cat = _categories.where((c) => c.id == id);
                                    final code = cat.isNotEmpty ? cat.first.categoryCode : '$id';
                                    return Chip(
                                      label: Text(code, style: const TextStyle(fontSize: 11)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.teal[50],
                                      side: BorderSide(color: Colors.teal[200]!),
                                    );
                                  }).toList(),
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildPickerField(
                                label: isEnglish ? 'Item Code From' : 'รหัสสินค้า ตั้งแต่',
                                displayText: _fromLabel,
                                onPick: () => _pickItem(isFrom: true),
                                onClear: () => setState(() { _itemCodeFrom = null; _fromLabel = ''; }),
                              ),
                              const SizedBox(height: 12),
                              _buildPickerField(
                                label: isEnglish ? 'Item Code To' : 'รหัสสินค้า ถึง',
                                displayText: _toLabel,
                                onPick: () => _pickItem(isFrom: false),
                                onClear: () => setState(() { _itemCodeTo = null; _toLabel = ''; }),
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                value: _sort,
                                decoration: InputDecoration(labelText: isEnglish ? 'Sort By' : 'การจัดเรียง', border: const OutlineInputBorder(), isDense: true),
                                items: ['doc_date', 'doc_type', 'item_code', 'party_code']
                                    .map((k) => DropdownMenuItem(value: k, child: Text(isEnglish ? _sortLabelsEn[k]! : _sortLabelsTh[k]!)))
                                    .toList(),
                                onChanged: (v) { if (v != null) setState(() => _sort = v); },
                              ),
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _generateReport,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() => _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth)),
                  onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportData.isEmpty
                        ? Center(child: Text(isEnglish ? 'Select conditions and click Generate Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                        : PdfPreview(
                            key: ValueKey(_pdfKey),
                            build: (fmt) => _generatePdf(fmt),
                            initialPageFormat: PdfPageFormat.a4.landscape,
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
}

// ---------------------------------------------------------------------------
// Generic multi-select picker dialog — เพิ่มช่องค้นหา (optional) เทียบกับตัวเดียวกันใน
// im_transaction_report_screen.dart — ทำซ้ำในไฟล์นี้ตาม convention เดิม (pattern_master_report_screen)
// ---------------------------------------------------------------------------
class _MultiPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<String> selected;
  final String Function(T) idOf;
  final String Function(T) labelOf;
  final bool isEnglish;
  final bool showSearch;

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.isEnglish,
    this.showSearch = false,
  });

  @override
  State<_MultiPickerDialog<T>> createState() => _MultiPickerDialogState<T>();
}

class _MultiPickerDialogState<T> extends State<_MultiPickerDialog<T>> {
  late List<String> _selected;
  late List<T> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    _filtered = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _doFilter(String q) {
    setState(() {
      _filtered = q.trim().isEmpty
          ? List.from(widget.items)
          : widget.items.where((e) => widget.labelOf(e).toLowerCase().contains(q.trim().toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420, height: 520,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.isEnglish ? 'Search' : 'ค้นหา',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _doFilter,
              ),
            ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text(widget.isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                : ListView(
                    children: _filtered.map((item) {
                      final id = widget.idOf(item);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(widget.labelOf(item), style: const TextStyle(fontSize: 13)),
                        value: _selected.contains(id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == widget.items.length) {
                      _selected = [];
                    } else {
                      _selected = widget.items.map((e) => widget.idOf(e)).toList();
                    }
                  });
                },
                child: Text(_selected.length == widget.items.length
                    ? (widget.isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด')
                    : (widget.isEnglish ? 'Select All' : 'เลือกทั้งหมด')),
              ),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isEnglish ? 'Cancel' : 'ยกเลิก')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                  child: Text(widget.isEnglish ? 'OK' : 'ตกลง'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item search dialog สำหรับเลือกรหัสสินค้าจาก-ถึง — มิเรอร์ im_item_report_screen.dart
// ---------------------------------------------------------------------------
class _ItemPickerDialog extends StatefulWidget {
  const _ItemPickerDialog();

  @override
  State<_ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<_ItemPickerDialog> {
  final _ctrl = TextEditingController();
  final _svc  = ImItemService();
  List<ImItem> _list = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchRows(keyword: q.trim().isEmpty ? null : q.trim());
      if (mounted) setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(isEnglish ? 'Search Item' : 'ค้นหาสินค้า',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: isEnglish ? 'Search by item code or name' : 'ค้นหาจากรหัสหรือชื่อสินค้า',
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
                  child: Text(isEnglish ? 'Code' : 'รหัส',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text(isEnglish ? 'Item Name' : 'ชื่อสินค้า',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 12),
                        itemBuilder: (ctx, i) {
                          final it = _list[i];
                          final displayName = isEnglish && (it.itemNameEn ?? '').isNotEmpty ? it.itemNameEn! : it.itemNameTh;
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, it),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 100,
                                    child: Text(it.itemCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Expanded(child: Text(displayName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          );
                        }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ]),
          ),
        ]),
      ),
    );
  }
}
