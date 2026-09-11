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
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../models/im_warehouse.dart';
import '../models/im_location.dart';
import '../services/im_item_service.dart';
import '../services/im_item_category_service.dart';
import '../services/im_warehouse_service.dart';
import '../services/im_location_service.dart';
import '../services/im_stock_balance_by_item_report_service.dart';
import '../../utils/file_download.dart';

// รายงานสินค้าคงเหลือตามตำแหน่งที่เก็บ — flat list ระดับ (สินค้า, คลัง, ตำแหน่ง, ล็อต/ซีเรียล) จัดกลุ่ม+ยอดรวมย่อย
// ตามหมวดหมู่ ยอดคงเหลือคำนวณ ณ วันที่สิ้นสุดที่เลือกด้วยการ SUM จาก im_transaction_detail ตรงๆ ฝั่ง backend
// (ไม่ได้อ่านจาก im_stock_balance/im_stock_layer ซึ่งเก็บแค่ยอดปัจจุบัน ไม่รองรับดูย้อนหลัง) — ดู
// imStockBalanceByItemReportController.js สำหรับรายละเอียด query และ verify ที่ทำไว้ก่อนเขียน
//
// backend ORDER BY มาให้ถูกต้องแล้ว (category > [sort ที่เลือก ถ้ามี] > item > warehouse > location > lot/serial)
// เดินลิสต์ตามลำดับที่ได้รับมาเป็น linear pass เดียว ห้าม re-sort/regroup ด้วย Map ที่นี่ — sort ที่เลือกเป็นแค่
// secondary sort ภายในแต่ละหมวดหมู่เท่านั้น หมวดหมู่ยังคงเป็น outer grouping key เสมอ (ดูหมายเหตุเดียวกันใน
// imStockBalanceByItemReportController.js)

const Map<String, String> _sortLabelsTh = {
  '': 'ไม่ระบุ',
  'qty': 'เรียงตามจำนวน',
  'value': 'เรียงตามมูลค่า',
  'location': 'เรียงตามตำแหน่งที่เก็บ',
  'lot_serial': 'เรียงตามล็อตและซีเรียล',
};
const Map<String, String> _sortLabelsEn = {
  '': 'Not specified',
  'qty': 'Sort by Quantity',
  'value': 'Sort by Value',
  'location': 'Sort by Location',
  'lot_serial': 'Sort by Lot/Serial',
};

class ImStockBalanceByItemReportScreen extends StatefulWidget {
  const ImStockBalanceByItemReportScreen({super.key});

  @override
  State<ImStockBalanceByItemReportScreen> createState() => _ImStockBalanceByItemReportScreenState();
}

class _ImStockBalanceByItemReportScreenState extends State<ImStockBalanceByItemReportScreen> {
  final _reportService  = ImStockBalanceByItemReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();
  final _categorySvc    = ImItemCategoryService();
  final _warehouseSvc   = ImWarehouseService();
  final _locationSvc    = ImLocationService();

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
  List<ImWarehouse>    _warehouses = [];
  List<ImLocation>     _locations  = [];
  Map<int, ImLocation> _locationsById = {};

  // Filters
  DateTime _dateTo = DateTime.now();
  List<int> _selectedCategoryIds  = [];
  String?   _itemCodeFrom;
  String?   _itemCodeTo;
  String    _fromLabel = '';
  String    _toLabel   = '';
  String    _costingMethod = ''; // '' | FIFO | AVG | STANDARD | SPECIFIC
  List<int> _selectedWarehouseIds = [];
  String?   _locationCodeFrom;
  String?   _locationCodeTo;
  String    _locFromLabel = '';
  String    _locToLabel   = '';
  String    _balanceFilter = 'has'; // 'has' | 'none' | 'all'
  String    _sortField = ''; // '' (ไม่ระบุ) | qty | value | location | lot_serial — secondary sort ภายในแต่ละหมวดหมู่
  String    _sortDir   = 'asc'; // 'asc' | 'desc' — แสดง dropdown นี้เฉพาะเมื่อ _sortField ไม่ใช่ ''

  List<Map<String, dynamic>> _reportData = [];

  // ─── init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    _headers = await _authService.getAuthHeader();
    final res = await Future.wait([
      _companyService.fetchCompany(),
      _categorySvc.fetchActiveRows(),
      _warehouseSvc.fetchActiveRows(),
      _locationSvc.fetchActiveRows(),
    ]);
    _company    = res[0] as Company?;
    _categories = (res[1] as List<ImItemCategory>).where((c) => c.categoryType == 'CATEGORY').toList();
    _warehouses = res[2] as List<ImWarehouse>;
    _locations  = res[3] as List<ImLocation>;
    _locationsById = {for (final l in _locations) l.id: l};
    if (mounted) setState(() {});
  }

  // ─── report generation ────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getReport(
        dateTo:           DateFormat('yyyy-MM-dd').format(_dateTo),
        categoryIds:       _selectedCategoryIds,
        itemCodeFrom:      _itemCodeFrom,
        itemCodeTo:        _itemCodeTo,
        costingMethod:     _costingMethod.isEmpty ? null : _costingMethod,
        warehouseIds:      _selectedWarehouseIds,
        locationCodeFrom:  _locationCodeFrom,
        locationCodeTo:    _locationCodeTo,
        balanceFilter:     _balanceFilter,
        sort:              _sortField.isEmpty ? null : _sortField,
        sortDir:           _sortField.isEmpty ? null : _sortDir,
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

  String _categoryLabel(Map<String, dynamic> r, bool isEnglish) {
    final code = r['category_code'] as String?;
    if ((code ?? '').isEmpty) return isEnglish ? '(No category)' : '(ไม่ระบุหมวดหมู่)';
    final en = r['category_name_en'] as String?;
    final name = isEnglish && (en ?? '').isNotEmpty ? en! : (r['category_name_th'] as String? ?? '');
    return '$code  $name';
  }

  String _itemLabel(Map<String, dynamic> r, bool isEnglish) {
    final en = r['item_name_en'] as String?;
    final name = isEnglish && (en ?? '').isNotEmpty ? en! : (r['item_name_th'] as String? ?? '');
    return '${r['item_code'] ?? ''}  $name';
  }

  String _warehouseLabel(Map<String, dynamic> r, bool isEnglish) {
    final en = r['warehouse_name_en'] as String?;
    final name = isEnglish && (en ?? '').isNotEmpty ? en! : (r['warehouse_name_th'] as String? ?? '');
    return '${r['warehouse_code'] ?? ''}  $name';
  }

  String _uomName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['uom_name_en'] as String?;
    final th = r['uom_name_th'] as String?;
    if (isEnglish && (en ?? '').isNotEmpty) return en!;
    if ((th ?? '').isNotEmpty) return th!;
    return r['uom_code']?.toString() ?? '';
  }

  // ล็อต/ซีเรียล — แสดงเมื่อมีวิธีคิดต้นทุนที่เกี่ยวข้องเท่านั้น (SPECIFIC/is_serial_tracked -> serial_no,
  // is_lot_tracked -> lot_no) ส่วนสินค้าถัวเฉลี่ย/มาตรฐานที่ไม่ได้ติดตามล็อตจะว่างเสมอ
  String _lotSerial(Map<String, dynamic> r) {
    final lot = r['lot_no'] as String?;
    final serial = r['serial_no'] as String?;
    return (serial ?? '').isNotEmpty ? serial! : ((lot ?? '').isNotEmpty ? lot! : '');
  }

  // ตำแหน่งที่เก็บ — เดินขึ้น parent_id จนถึงราก แล้วกลับหัวเป็น parent1 > parent2 > ... > bin
  String _locationPath(int? locationId, bool isEnglish) {
    if (locationId == null) return isEnglish ? '(Not specified)' : '(ไม่ระบุ)';
    final parts = <String>[];
    int? curId = locationId;
    int guard = 0;
    while (curId != null && guard < 20) {
      final loc = _locationsById[curId];
      if (loc == null) break;
      parts.add(loc.locationCode);
      curId = loc.parentId;
      guard++;
    }
    if (parts.isEmpty) return isEnglish ? '(Not specified)' : '(ไม่ระบุ)';
    return parts.reversed.join(' > ');
  }

  String _conditionLine(bool isEnglish) {
    final p = <String>[];
    p.add('${isEnglish ? "As of" : "ณ วันที่"}: ${DateFormat('dd/MM/yyyy').format(_dateTo)}');
    if (_selectedCategoryIds.isNotEmpty) {
      final names = _selectedCategoryIds.map((id) {
        final c = _categories.firstWhere((c) => c.id == id, orElse: () => _categories.first);
        return c.categoryCode;
      }).join(', ');
      p.add('${isEnglish ? "Category" : "หมวดหมู่"}: $names');
    }
    if ((_itemCodeFrom ?? '').isNotEmpty || (_itemCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      p.add('${isEnglish ? "Item Code" : "รหัสสินค้า"}: ${(_itemCodeFrom ?? '').isEmpty ? all : _itemCodeFrom!} – ${(_itemCodeTo ?? '').isEmpty ? all : _itemCodeTo!}');
    }
    if (_costingMethod.isNotEmpty) {
      p.add('${isEnglish ? "Costing Method" : "วิธีคิดต้นทุน"}: ${imCostingMethodLabel(_costingMethod, isEnglish)}');
    }
    if (_selectedWarehouseIds.isNotEmpty) {
      final names = _selectedWarehouseIds.map((id) {
        final w = _warehouses.firstWhere((w) => w.id == id, orElse: () => _warehouses.first);
        return w.warehouseCode;
      }).join(', ');
      p.add('${isEnglish ? "Warehouse" : "คลัง"}: $names');
    }
    if ((_locationCodeFrom ?? '').isNotEmpty || (_locationCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      p.add('${isEnglish ? "Location" : "ตำแหน่งที่เก็บ"}: ${(_locationCodeFrom ?? '').isEmpty ? all : _locationCodeFrom!} – ${(_locationCodeTo ?? '').isEmpty ? all : _locationCodeTo!}');
    }
    final balLabels = isEnglish
        ? {'has': 'Has balance', 'none': 'No balance', 'all': 'All'}
        : {'has': 'มียอดคงเหลือ', 'none': 'ไม่มียอดคงเหลือ', 'all': 'ทั้งหมด'};
    p.add('${isEnglish ? "Balance" : "แสดงยอดคงเหลือ"}: ${balLabels[_balanceFilter]}');
    if (_sortField.isNotEmpty) {
      final dirLabel = _sortDir == 'desc'
          ? (isEnglish ? 'Descending' : 'มากไปน้อย')
          : (isEnglish ? 'Ascending' : 'น้อยไปมาก');
      final sortLabel = isEnglish ? _sortLabelsEn[_sortField] : _sortLabelsTh[_sortField];
      p.add('${isEnglish ? "Sort" : "การจัดเรียง"}: $sortLabel ($dirLabel)');
    }
    return p.join(' | ');
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish   = _isEnglish;
    final reportTitle = _reportTitle;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final condLine     = _conditionLine(isEnglish);

    const mg = 20.0;
    final pageW = format.width - mg * 2;

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen    = PdfColor(0.87, 0.94, 0.92);
    const cStripe   = PdfColor(0.97, 0.97, 0.97);
    const cGroup    = PdfColor(0.93, 0.93, 0.97);
    const cGroupTot = PdfColor(0.80, 0.93, 0.88);
    const cTotal    = PdfColor(0.75, 0.88, 0.96);
    const cBorder   = PdfColors.grey400;
    final fmt    = NumberFormat('#,##0.00', 'en_US');
    final fmtQty = NumberFormat('#,##0.####', 'en_US');

    // ─── 8 คอลัมน์ตามที่ผู้ใช้กำหนด ─────────────────────────────────────────
    final cw = {
      'category': pageW * 0.15,
      'item':     pageW * 0.17,
      'warehouse':pageW * 0.13,
      'lotSerial':pageW * 0.09,
      'location': pageW * 0.16,
      'unit':     pageW * 0.08,
      'qty':      pageW * 0.10,
      'value':    pageW * 0.12,
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
        cell(cw['category']!,  isEnglish ? 'Category'       : 'หมวดหมู่',       bold: true),
        cell(cw['item']!,      isEnglish ? 'Item'            : 'สินค้า',         bold: true),
        cell(cw['warehouse']!, isEnglish ? 'Warehouse'       : 'คลัง',           bold: true),
        cell(cw['lotSerial']!, isEnglish ? 'Lot/Serial'      : 'ล็อต/ซีเรียล',    bold: true),
        cell(cw['location']!,  isEnglish ? 'Location'        : 'ตำแหน่งที่เก็บ',   bold: true),
        cell(cw['unit']!,      isEnglish ? 'Unit'            : 'หน่วย',          bold: true),
        cell(cw['qty']!,       isEnglish ? 'Quantity'        : 'จำนวน',          bold: true, a: pw.TextAlign.right),
        cell(cw['value']!,     isEnglish ? 'Value'           : 'มูลค่า',         bold: true, a: pw.TextAlign.right),
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
        pw.Expanded(flex: 9, child: pw.SizedBox()),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.Text('* $condLine', style: tN(9))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 4),
      tableHeader,
    ]);

    // ─── เดินข้อมูลแบบ linear pass เดียว จัดกลุ่มตามหมวดหมู่ + ยอดรวมย่อย ตามลำดับที่ backend ส่งมา ──────
    final content = <pw.Widget>[];
    String? curKey;
    String curLabel = '';
    double curSubtotalQty = 0;
    double curSubtotalValue = 0;
    int curCount = 0;
    double grandQty = 0;
    double grandValue = 0;
    int rowIdx = 0;

    pw.Widget groupHeaderBar(String label) => pw.Container(
          width: pageW,
          color: cGroup,
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: pw.Text('${isEnglish ? "Category" : "หมวดหมู่"}:  $label', style: tB(9)),
        );

    pw.Widget totalsRow(PdfColor bg, String label, double qty, double value) => pw.Container(
          width: pageW,
          color: bg,
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: pw.Text(label, style: tB(9)),
              ),
            ),
            cell(cw['qty']!,   fmtQty.format(qty), bold: true, a: pw.TextAlign.right),
            cell(cw['value']!, fmt.format(value),  bold: true, a: pw.TextAlign.right),
          ]),
        );

    for (final r in _reportData) {
      final key = '${r['category_id']}';
      if (curKey != null && key != curKey) {
        content.add(totalsRow(cGroupTot,
            isEnglish ? 'Subtotal ($curCount line(s)):' : 'รวมยอด ($curCount รายการ):',
            curSubtotalQty, curSubtotalValue));
        curSubtotalQty = 0;
        curSubtotalValue = 0;
        curCount = 0;
      }
      final isNewGroup = key != curKey;
      curKey = key;
      curLabel = _categoryLabel(r, isEnglish);
      if (isNewGroup) content.add(groupHeaderBar(curLabel));

      final qty = _num(r['qty']).toDouble();
      final value = _num(r['value']).toDouble();
      curSubtotalQty += qty;
      curSubtotalValue += value;
      grandQty += qty;
      grandValue += value;
      curCount++;

      final bg = rowIdx.isOdd ? cStripe : null;
      content.add(pw.Container(
        color: bg,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
        child: pw.Row(children: [
          cell(cw['category']!,  _categoryLabel(r, isEnglish)),
          cell(cw['item']!,      _itemLabel(r, isEnglish)),
          cell(cw['warehouse']!, _warehouseLabel(r, isEnglish)),
          cell(cw['lotSerial']!, _lotSerial(r)),
          cell(cw['location']!,  _locationPath(r['location_id'] as int?, isEnglish)),
          cell(cw['unit']!,      _uomName(r, isEnglish)),
          cell(cw['qty']!,       fmtQty.format(qty),   a: pw.TextAlign.right),
          cell(cw['value']!,     fmt.format(value),    a: pw.TextAlign.right),
        ]),
      ));
      rowIdx++;
    }
    if (curKey != null) {
      content.add(totalsRow(cGroupTot,
          isEnglish ? 'Subtotal ($curCount line(s)):' : 'รวมยอด ($curCount รายการ):',
          curSubtotalQty, curSubtotalValue));
    }

    content.add(totalsRow(cTotal,
        isEnglish ? 'Grand total ${_reportData.length} line(s):' : 'รวมทั้งสิ้น ${_reportData.length} รายการ:',
        grandQty, grandValue));

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
      const sheet = 'StockByLocation';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final groupBg = ExcelColor.fromHexString('#EDEDF7');
      final groupTotBg = ExcelColor.fromHexString('#CCE9DE');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      final hdrs = isEnglish
          ? ['Category', 'Item', 'Warehouse', 'Lot/Serial', 'Location', 'Unit', 'Quantity', 'Value']
          : ['หมวดหมู่', 'สินค้า', 'คลัง', 'ล็อต/ซีเรียล', 'ตำแหน่งที่เก็บ', 'หน่วย', 'จำนวน', 'มูลค่า'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 4, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 5;
      String? curKey;
      String curLabel = '';
      double curSubtotalQty = 0;
      double curSubtotalValue = 0;
      int curCount = 0;
      double grandQty = 0;
      double grandValue = 0;

      void writeGroupSubtotal() {
        _xl(s, row, 0,
            isEnglish ? 'Subtotal $curLabel ($curCount line(s)):' : 'รวมยอด $curLabel ($curCount รายการ):',
            bg: groupTotBg, bold: true);
        for (int c = 1; c < 6; c++) {
          _xl(s, row, c, '', bg: groupTotBg);
        }
        _xl(s, row, 6, curSubtotalQty, bg: groupTotBg, bold: true, align: HorizontalAlign.Right);
        _xl(s, row, 7, curSubtotalValue, bg: groupTotBg, bold: true, align: HorizontalAlign.Right);
        row++;
      }

      for (final r in _reportData) {
        final key = '${r['category_id']}';
        if (curKey != null && key != curKey) {
          writeGroupSubtotal();
          curSubtotalQty = 0;
          curSubtotalValue = 0;
          curCount = 0;
        }
        final isNewGroup = key != curKey;
        curKey = key;
        curLabel = _categoryLabel(r, isEnglish);
        if (isNewGroup) {
          _xl(s, row, 0, '${isEnglish ? "Category" : "หมวดหมู่"}:  $curLabel', bg: groupBg, bold: true);
          row++;
        }

        final qty = _num(r['qty']).toDouble();
        final value = _num(r['value']).toDouble();
        curSubtotalQty += qty;
        curSubtotalValue += value;
        grandQty += qty;
        grandValue += value;
        curCount++;

        _xl(s, row, 0, _categoryLabel(r, isEnglish));
        _xl(s, row, 1, _itemLabel(r, isEnglish));
        _xl(s, row, 2, _warehouseLabel(r, isEnglish));
        _xl(s, row, 3, _lotSerial(r));
        _xl(s, row, 4, _locationPath(r['location_id'] as int?, isEnglish));
        _xl(s, row, 5, _uomName(r, isEnglish));
        _xl(s, row, 6, qty, align: HorizontalAlign.Right);
        _xl(s, row, 7, value, align: HorizontalAlign.Right);
        row++;
      }
      if (curKey != null) writeGroupSubtotal();

      _xl(s, row, 0,
          isEnglish ? 'Grand total ${_reportData.length} line(s):' : 'รวมทั้งสิ้น ${_reportData.length} รายการ:',
          bg: totBg, bold: true);
      for (int c = 1; c < 6; c++) {
        _xl(s, row, c, '', bg: totBg);
      }
      _xl(s, row, 6, grandQty, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xl(s, row, 7, grandValue, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'IM_Stock_Balance_By_Location' : 'รายงานสินค้าคงเหลือตามตำแหน่งที่เก็บ';
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

  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImItemCategory>(
        title: isEnglish ? 'Select Item Categories' : 'เลือกหมวดหมู่สินค้า',
        items: _categories,
        selected: _selectedCategoryIds,
        idOf: (c) => c.id,
        labelOf: (c) => '${c.categoryCode}  ${isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedCategoryIds = result);
  }

  Future<void> _pickWarehouses() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImWarehouse>(
        title: isEnglish ? 'Select Warehouses' : 'เลือกคลังสินค้า',
        items: _warehouses,
        selected: _selectedWarehouseIds,
        idOf: (w) => w.id,
        labelOf: (w) => '${w.warehouseCode}  ${isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedWarehouseIds = result);
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

  Future<void> _pickLocation({required bool isFrom}) async {
    final result = await showDialog<ImLocation>(
      context: context,
      builder: (_) => _LocationPickerDialog(locations: _locations),
    );
    if (result == null || !mounted) return;
    setState(() {
      final name = (result.locationName ?? '').isNotEmpty ? '${result.locationCode}  ${result.locationName}' : result.locationCode;
      if (isFrom) {
        _locationCodeFrom = result.locationCode;
        _locFromLabel = name;
      } else {
        _locationCodeTo = result.locationCode;
        _locToLabel = name;
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

  Widget _buildFilterPanel() {
    final isEnglish = _isEnglish;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),

                _buildDateField(
                  label: isEnglish ? 'As of Date' : 'วันที่สิ้นสุด',
                  date: _dateTo,
                  onPick: (d) => setState(() => _dateTo = d),
                ),
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

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _costingMethod,
                  decoration: InputDecoration(labelText: isEnglish ? 'Costing Method' : 'วิธีคิดต้นทุน', border: const OutlineInputBorder(), isDense: true),
                  items: [
                    DropdownMenuItem(value: '', child: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
                    ...imCostingMethods.map((m) => DropdownMenuItem(value: m, child: Text(imCostingMethodLabel(m, isEnglish)))),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _costingMethod = v); },
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                _buildMultiField(
                  label: isEnglish ? 'Warehouse' : 'คลัง',
                  count: _selectedWarehouseIds.length,
                  allLabel: isEnglish ? '— All Warehouses —' : '— ทุกคลัง —',
                  onTap: _pickWarehouses,
                  onClear: () => setState(() => _selectedWarehouseIds = []),
                ),
                const SizedBox(height: 12),

                _buildPickerField(
                  label: isEnglish ? 'Location From' : 'ตำแหน่งที่เก็บ ตั้งแต่',
                  displayText: _locFromLabel,
                  onPick: () => _pickLocation(isFrom: true),
                  onClear: () => setState(() { _locationCodeFrom = null; _locFromLabel = ''; }),
                ),
                const SizedBox(height: 12),
                _buildPickerField(
                  label: isEnglish ? 'Location To' : 'ตำแหน่งที่เก็บ ถึง',
                  displayText: _locToLabel,
                  onPick: () => _pickLocation(isFrom: false),
                  onClear: () => setState(() { _locationCodeTo = null; _locToLabel = ''; }),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _balanceFilter,
                  decoration: InputDecoration(labelText: isEnglish ? 'Show Balance' : 'แสดงยอดคงเหลือ', border: const OutlineInputBorder(), isDense: true),
                  items: [
                    DropdownMenuItem(value: 'has',  child: Text(isEnglish ? 'Has balance'   : 'มียอดคงเหลือ')),
                    DropdownMenuItem(value: 'none', child: Text(isEnglish ? 'No balance'     : 'ไม่มียอดคงเหลือ')),
                    DropdownMenuItem(value: 'all',  child: Text(isEnglish ? 'All'            : 'ทั้งหมด')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _balanceFilter = v); },
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _sortField,
                  decoration: InputDecoration(labelText: isEnglish ? 'Sort By' : 'การจัดเรียง', border: const OutlineInputBorder(), isDense: true),
                  items: ['', 'qty', 'value', 'location', 'lot_serial']
                      .map((k) => DropdownMenuItem(value: k, child: Text(isEnglish ? _sortLabelsEn[k]! : _sortLabelsTh[k]!)))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _sortField = v); },
                ),
                if (_sortField.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _sortDir,
                    decoration: InputDecoration(labelText: isEnglish ? 'Sort Direction' : 'ทิศทางการเรียง', border: const OutlineInputBorder(), isDense: true),
                    items: [
                      DropdownMenuItem(value: 'asc',  child: Text(isEnglish ? 'Ascending'  : 'น้อยไปมาก')),
                      DropdownMenuItem(value: 'desc', child: Text(isEnglish ? 'Descending' : 'มากไปน้อย')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _sortDir = v); },
                  ),
                ],
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
        : (perm?.menuName ?? (isEnglish ? 'Stock Balance by Location Report' : 'รายงานสินค้าคงเหลือตามตำแหน่งที่เก็บ'));
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
                  maxWidth: _filterPanelWidth,
                  minWidth: _filterPanelWidth,
                  alignment: Alignment.topLeft,
                  child: _buildFilterPanel(),
                ),
              ),
            ),
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
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportData.isEmpty
                        ? Center(
                            child: Text(isEnglish
                                ? 'Please select conditions and click Generate Report'
                                : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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
// Item picker dialog — มิเรอร์ im_stock_movement_report_screen.dart
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

// ---------------------------------------------------------------------------
// Location picker dialog — ค้นหาแบบ client-side บนลิสต์ตำแหน่งจัดเก็บที่โหลดไว้แล้ว (โหลดครั้งเดียวตอน
// init ของหน้าจอ ใช้ร่วมกับ path builder จึงไม่ต้องเพิ่ม endpoint ค้นหาฝั่ง backend)
// ---------------------------------------------------------------------------
class _LocationPickerDialog extends StatefulWidget {
  final List<ImLocation> locations;
  const _LocationPickerDialog({required this.locations});

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  final _ctrl = TextEditingController();
  late List<ImLocation> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.locations);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() {
      final query = q.trim().toLowerCase();
      _filtered = query.isEmpty
          ? List.from(widget.locations)
          : widget.locations.where((l) =>
              l.locationCode.toLowerCase().contains(query) ||
              (l.locationName ?? '').toLowerCase().contains(query) ||
              (l.warehouseCode ?? '').toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Dialog(
      child: SizedBox(
        width: 560, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(isEnglish ? 'Search Storage Location' : 'ค้นหาตำแหน่งที่เก็บ',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: isEnglish ? 'Search by location code, name, or warehouse' : 'ค้นหาจากรหัส/ชื่อตำแหน่ง หรือรหัสคลัง',
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
              SizedBox(width: 70, child: Text(isEnglish ? 'Whse' : 'คลัง', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 90, child: Text(isEnglish ? 'Code' : 'รหัส', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text(isEnglish ? 'Name' : 'ชื่อ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 12),
                    itemBuilder: (ctx, i) {
                      final loc = _filtered[i];
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, loc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(children: [
                            SizedBox(width: 70, child: Text(loc.warehouseCode ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54))),
                            SizedBox(width: 90, child: Text(loc.locationCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            Expanded(child: Text(loc.locationName ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
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

// ---------------------------------------------------------------------------
// Generic multi-select picker dialog
// ---------------------------------------------------------------------------
class _MultiPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<int> selected;
  final int Function(T) idOf;
  final String Function(T) labelOf;
  final bool isEnglish;

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.isEnglish,
  });

  @override
  State<_MultiPickerDialog<T>> createState() => _MultiPickerDialogState<T>();
}

class _MultiPickerDialogState<T> extends State<_MultiPickerDialog<T>> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: ListView(
              children: widget.items.map((item) {
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
