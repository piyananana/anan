// lib/po/screens/po_replenishment_report_screen.dart — ใบแนะนำสั่งซื้อเพื่อเติมสต็อก
// สูตร: ผสม min_stock_qty/max_stock_qty/reorder_point (นโยบายที่ตั้งไว้ในข้อมูลหลักสินค้า/ต่อคลัง — เดิมไม่เคยถูกใช้
// คำนวณอะไรเลย) กับยอดขายเฉลี่ย/วันจริงจาก DLN ในช่วงย้อนหลังที่เลือก คูณช่วงเวลาที่ต้องการให้พอ — ดู
// poReplenishmentController.js สำหรับสูตรเต็ม ผู้ขาย+ราคาที่แนะนำมาจากประวัติ PO จริง ไม่ใช่ im_price_list
//
// รองรับเลือกได้หลายคลัง/หลายหมวดหมู่พร้อมกัน — แต่ละแถวคำนวณแยกต่อ (สินค้า, คลัง) เสมอ
//
// เลือกรายการ (checkbox) แล้วสร้างเป็น "ใบขอซื้อ (PR)" หรือ "ใบสั่งซื้อ (PO)" ตรงๆ ได้ทั้งคู่ — แบ่งกลุ่มตาม
// (ผู้ขาย, คลัง) เพราะแต่ละเอกสารมี warehouse_id ระดับหัวเอกสารเดียว เรียก createTransaction เดิมของ PR/PO ไม่มี
// endpoint สร้างเอกสารใหม่ในไฟล์นี้เลย — รายงานนี้อ่านอย่างเดียว
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../im/models/im_warehouse.dart';
import '../../im/services/im_warehouse_service.dart';
import '../../im/models/im_item_category.dart';
import '../../im/services/im_item_category_service.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../widgets/po_search_multi_picker.dart';
import '../models/po_replenishment.dart';
import '../services/po_replenishment_service.dart';
import '../models/po_transaction.dart';
import '../services/po_transaction_service.dart';
import '../models/po_pr_transaction.dart';
import '../services/po_pr_transaction_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/file_download.dart';

class PoReplenishmentReportScreen extends StatefulWidget {
  const PoReplenishmentReportScreen({super.key});

  @override
  State<PoReplenishmentReportScreen> createState() => _PoReplenishmentReportScreenState();
}

class _PoReplenishmentReportScreenState extends State<PoReplenishmentReportScreen> {
  final _service = PoReplenishmentService();
  final _poService = PoTransactionService();
  final _prService = PrTransactionService();
  final _warehouseService = ImWarehouseService();
  final _categoryService = ImItemCategoryService();
  final _companyService = CompanyService();
  final _authService = AuthService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isExporting = false;

  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;

  List<ImWarehouse> _warehouses = [];
  List<int> _selectedWarehouseIds = [];
  List<ImItemCategory> _categories = [];
  List<int> _selectedCategoryIds = [];
  DateTime _asOf = DateTime.now();
  final _lookbackCtrl = TextEditingController(text: '90');
  final _coverageCtrl = TextEditingController(text: '30');

  List<ReplenishmentSuggestion> _rows = [];
  bool _hasGenerated = false; // แยกสถานะ "ยังไม่เคยกดประมวลผล" ออกจาก "กดแล้วแต่ไม่มีรายการที่ต้องสั่งซื้อ" — เดิม
  // ใช้ _rows.isEmpty เงื่อนไขเดียวทำให้สองสถานะนี้แสดงข้อความเดียวกัน ผู้ใช้กดประมวลผลแล้วดูเหมือนไม่มีอะไรเกิดขึ้น
  final Set<int> _selected = {}; // เก็บ index ใน _rows เพราะ itemId ไม่ unique ต่อแถวอีกต่อไป (หลายคลัง)

  Company? _company;
  Map<String, String>? _headers;
  String _reportTitle = '';
  List<ModuleDocument> _prDocTypes = [];
  List<ModuleDocument> _poDocTypes = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _lookbackCtrl.dispose();
    _coverageCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _headers = await _authService.getAuthHeader();
    final results = await Future.wait([
      _warehouseService.fetchActiveRows(),
      _categoryService.fetchActiveRows(),
      _companyService.fetchCompany(),
    ]);
    if (!mounted) return;
    setState(() {
      _warehouses = results[0] as List<ImWarehouse>;
      _categories = results[1] as List<ImItemCategory>;
      _company = results[2] as Company?;
    });
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  void _syncPdf() {
    if (_rows.isNotEmpty) setState(() => _pdfKey++);
  }

  Future<void> _generate() async {
    final isEnglish = _isEnglish;
    if (_selectedWarehouseIds.isEmpty) { _warn(isEnglish ? 'Please select at least 1 warehouse' : 'กรุณาเลือกคลังสินค้าอย่างน้อย 1 คลัง'); return; }
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchSuggestions(
        warehouseIds: _selectedWarehouseIds,
        asOf: formatLocalDate(_asOf),
        lookbackDays: int.tryParse(_lookbackCtrl.text) ?? 90,
        coverageDays: int.tryParse(_coverageCtrl.text) ?? 30,
        categoryIds: _selectedCategoryIds,
      );
      setState(() {
        _rows = rows;
        _hasGenerated = true;
        _selected.clear();
        _pdfKey++;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVendorForRow(ReplenishmentSuggestion r) async {
    await ApVendorListWidget.search(context, onSelected: (v) {
      setState(() {
        r.vendorId = v.id;
        r.vendorCode = v.vendorCode;
        r.vendorNameTh = v.vendorNameTh;
      });
      _syncPdf();
    });
  }

  // แบ่งกลุ่มตาม (ผู้ขาย, คลัง) เพราะแต่ละเอกสาร PR/PO มี warehouse_id ระดับหัวเอกสารเดียว ต่างจากเดิมที่มีคลังเดียว
  // ทั้งรายงานจึงแบ่งตามผู้ขายอย่างเดียวได้ — ตอนนี้รายการที่เลือกอาจมาจากหลายคลัง
  Map<(int?, int), List<ReplenishmentSuggestion>> _groupSelectedByVendorAndWarehouse() {
    final selectedRows = _selected.map((i) => _rows[i]).toList();
    final groups = <(int?, int), List<ReplenishmentSuggestion>>{};
    for (final r in selectedRows) {
      groups.putIfAbsent((r.vendorId, r.warehouseId), () => []).add(r);
    }
    return groups;
  }

  Future<void> _createPr() async {
    final isEnglish = _isEnglish;
    if (_selected.isEmpty) { _warn(isEnglish ? 'Please select at least 1 item' : 'กรุณาเลือกรายการอย่างน้อย 1 รายการ'); return; }
    setState(() => _isCreating = true);
    try {
      if (_prDocTypes.isEmpty) {
        _prDocTypes = (await _prService.fetchDocTypesByUser()).where((d) => d.isDocType).toList();
      }
      if (_prDocTypes.isEmpty) throw Exception(isEnglish ? 'No PR document type found' : 'ไม่พบประเภทเอกสารใบขอซื้อ');
      final groups = _groupSelectedByVendorAndWarehouse();
      final createdDocNos = <String>[];
      for (final entry in groups.entries) {
        final (vendorId, warehouseId) = entry.key;
        final header = PrTransactionHeader(
          docId: _prDocTypes.first.id, docNo: 'AUTO', docDate: DateTime.now(),
          warehouseId: warehouseId, vendorId: vendorId,
          description: isEnglish ? 'Auto-generated from Replenishment Suggestion' : 'สร้างจากใบแนะนำสั่งซื้อเพื่อเติมสต็อก',
        );
        final details = entry.value.map((r) => PrTransactionDetail(
              lineNo: 0, itemId: r.itemId, itemCode: r.itemCode, itemName: r.itemNameTh, uomId: r.uomId,
              qtyRequested: r.suggestedQty, estimatedUnitCost: r.lastPrice ?? 0,
            )).toList();
        final created = await _prService.createTransaction(header: header, details: details);
        createdDocNos.add(created.docNo);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            isEnglish ? 'Created PR: ${createdDocNos.join(', ')}' : 'สร้างใบขอซื้อแล้ว: ${createdDocNos.join(', ')}')));
        setState(() => _selected.clear());
        _syncPdf();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed: $e' : 'ล้มเหลว: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _createPo() async {
    final isEnglish = _isEnglish;
    if (_selected.isEmpty) { _warn(isEnglish ? 'Please select at least 1 item' : 'กรุณาเลือกรายการอย่างน้อย 1 รายการ'); return; }
    // PO ต้องมีผู้ขายเสมอ (po_transaction.vendor_id NOT NULL) — บล็อกก่อนเรียก API ถ้ายังมีรายการที่ไม่มีผู้ขาย
    // แทนที่จะเดาเอาเองหรือข้ามเงียบๆ
    final missingVendor = _selected.map((i) => _rows[i]).where((r) => r.vendorId == null).toList();
    if (missingVendor.isNotEmpty) {
      _warn(isEnglish
          ? 'Please assign a vendor first for: ${missingVendor.map((r) => r.itemCode).join(', ')}'
          : 'กรุณาระบุผู้ขายให้ครบก่อนสำหรับ: ${missingVendor.map((r) => r.itemCode).join(', ')}');
      return;
    }
    setState(() => _isCreating = true);
    try {
      if (_poDocTypes.isEmpty) {
        _poDocTypes = (await _poService.fetchDocTypesByUser()).where((d) => d.isDocType).toList();
      }
      if (_poDocTypes.isEmpty) throw Exception(isEnglish ? 'No PO document type found' : 'ไม่พบประเภทเอกสารใบสั่งซื้อ');
      final groups = _groupSelectedByVendorAndWarehouse();
      final createdDocNos = <String>[];
      for (final entry in groups.entries) {
        final (vendorId, warehouseId) = entry.key;
        final header = PoTransactionHeader(
          docId: _poDocTypes.first.id, docNo: 'AUTO', docDate: DateTime.now(),
          vendorId: vendorId!, warehouseId: warehouseId,
          description: isEnglish ? 'Auto-generated from Replenishment Suggestion' : 'สร้างจากใบแนะนำสั่งซื้อเพื่อเติมสต็อก',
        );
        final details = entry.value.map((r) => PoTransactionDetail(
              lineNo: 0, itemId: r.itemId, itemCode: r.itemCode, itemName: r.itemNameTh, uomId: r.uomId,
              qtyOrdered: r.suggestedQty, unitPriceFc: r.lastPrice ?? 0,
            )).toList();
        final created = await _poService.createTransaction(header: header, details: details);
        createdDocNos.add(created.docNo);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            isEnglish ? 'Created PO: ${createdDocNos.join(', ')}' : 'สร้างใบสั่งซื้อแล้ว: ${createdDocNos.join(', ')}')));
        setState(() => _selected.clear());
        _syncPdf();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed: $e' : 'ล้มเหลว: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  String _warehouseLabel(ReplenishmentSuggestion r, bool isEnglish) =>
      '${r.warehouseCode} ${isEnglish && (r.warehouseNameEn ?? '').isNotEmpty ? r.warehouseNameEn! : r.warehouseNameTh}';

  // ─── Excel ────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      final sheetName = isEnglish ? 'Replenishment' : 'แนะนำสั่งซื้อ';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, _reportTitle, bold: true);
      _xlCell(s, 2, 0,
          '${isEnglish ? "As of" : "ณ วันที่"}: ${_dateFmt.format(_asOf)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $ts');

      int r = 3;
      final headers = [
        isEnglish ? 'Warehouse' : 'คลังสินค้า',
        isEnglish ? 'Item Code' : 'รหัสสินค้า',
        isEnglish ? 'Item Name' : 'ชื่อสินค้า',
        isEnglish ? 'On Hand' : 'คงเหลือ',
        isEnglish ? 'Incoming' : 'กำลังมา',
        isEnglish ? 'Avg/Day' : 'ขาย/วัน',
        isEnglish ? 'Demand' : 'ที่ต้องใช้',
        isEnglish ? 'Reorder Pt.' : 'จุดสั่งซื้อ',
        isEnglish ? 'Max' : 'สูงสุด',
        isEnglish ? 'Suggested Qty' : 'แนะนำสั่ง',
        isEnglish ? 'Vendor' : 'ผู้ขายแนะนำ',
        isEnglish ? 'Last Price' : 'ราคาล่าสุด',
      ];
      for (int c = 0; c < headers.length; c++) {
        _xlCell(s, r, c, headers[c], bg: hdrBg, bold: true);
      }
      r++;

      for (final row in _rows) {
        _xlCell(s, r, 0, _warehouseLabel(row, isEnglish));
        _xlCell(s, r, 1, row.itemCode);
        _xlCell(s, r, 2, isEnglish && (row.itemNameEn ?? '').isNotEmpty ? row.itemNameEn! : row.itemNameTh);
        _xlCell(s, r, 3, DoubleCellValue(row.onHand), align: HorizontalAlign.Right);
        _xlCell(s, r, 4, DoubleCellValue(row.incoming), align: HorizontalAlign.Right);
        _xlCell(s, r, 5, DoubleCellValue(row.avgDailySales), align: HorizontalAlign.Right);
        _xlCell(s, r, 6, DoubleCellValue(row.projectedDemand), align: HorizontalAlign.Right);
        _xlCell(s, r, 7, DoubleCellValue(row.reorderPoint), align: HorizontalAlign.Right);
        _xlCell(s, r, 8, DoubleCellValue(row.maxStockQty), align: HorizontalAlign.Right);
        _xlCell(s, r, 9, DoubleCellValue(row.suggestedQty), align: HorizontalAlign.Right, bold: true);
        _xlCell(s, r, 10, row.vendorCode == null ? '-' : '${row.vendorCode} ${row.vendorNameTh ?? ''}');
        _xlCell(s, r, 11, row.lastPrice != null ? DoubleCellValue(row.lastPrice!) : TextCellValue('-'), align: HorizontalAlign.Right);
        r++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final fileTs = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes,
          isEnglish ? 'PO_Replenishment_Report_$fileTs.xlsx' : 'ใบแนะนำสั่งซื้อเพื่อเติมสต็อก_$fileTs.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue ? v : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(backgroundColorHex: bg ?? ExcelColor.none, horizontalAlign: align ?? HorizontalAlign.Left, bold: bold);
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final selectedSnapshot = Set<int>.from(_selected);
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final reportTitle = _reportTitle;
    final whLabel = _selectedWarehouseIds.isEmpty
        ? ''
        : _warehouses.where((w) => _selectedWarehouseIds.contains(w.id)).map((w) => w.warehouseCode).join(', ');
    final catLabel = _selectedCategoryIds.isEmpty
        ? (isEnglish ? 'All' : 'ทั้งหมด')
        : _categories.where((c) => _selectedCategoryIds.contains(c.id)).map((c) => c.categoryCode).join(', ');
    final condLine = isEnglish
        ? 'Warehouse: $whLabel  |  Category: $catLabel  |  As of: ${_dateFmt.format(_asOf)}  |  Lookback: ${_lookbackCtrl.text}d  |  Coverage: ${_coverageCtrl.text}d'
        : 'คลัง: $whLabel  |  หมวดหมู่: $catLabel  |  ณ วันที่: ${_dateFmt.format(_asOf)}  |  ย้อนหลัง: ${_lookbackCtrl.text} วัน  |  ให้พอ: ${_coverageCtrl.text} วัน';

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    const mg = 20.0;
    final pageW = format.width - mg * 2;
    const cHeader = PdfColor(0.87, 0.94, 0.92);
    const cBorder = PdfColors.grey400;

    final cw = {
      'chk': pageW * 0.04, 'wh': pageW * 0.10, 'item': pageW * 0.20, 'onHand': pageW * 0.07, 'incoming': pageW * 0.07,
      'avgSales': pageW * 0.08, 'demand': pageW * 0.08, 'reorder': pageW * 0.07, 'max': pageW * 0.07,
      'suggested': pageW * 0.08, 'vendor': pageW * 0.14,
    };

    pw.Widget cell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: bold ? tB(8) : tN(8), textAlign: a),
          ),
        );

    // ช่องติ๊กแบบ static (วาดเป็นกรอบสี่เหลี่ยม/ทึบ ไม่ใช้ font glyph) — สะท้อนสถานะที่เลือกไว้ในแท็บรายการ ณ ตอนสร้าง PDF
    pw.Widget checkboxCell(bool checked) => pw.SizedBox(
          width: cw['chk'],
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Container(
              width: 10, height: 10,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.7, color: PdfColors.black),
                color: checked ? PdfColors.black : null,
              ),
            ),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cHeader, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['chk']!, isEnglish ? 'Sel' : 'เลือก', bold: true),
        cell(cw['wh']!, isEnglish ? 'Warehouse' : 'คลัง', bold: true),
        cell(cw['item']!, isEnglish ? 'Item' : 'สินค้า', bold: true),
        cell(cw['onHand']!, isEnglish ? 'On Hand' : 'คงเหลือ', bold: true, a: pw.TextAlign.right),
        cell(cw['incoming']!, isEnglish ? 'Incoming' : 'กำลังมา', bold: true, a: pw.TextAlign.right),
        cell(cw['avgSales']!, isEnglish ? 'Avg/Day' : 'ขาย/วัน', bold: true, a: pw.TextAlign.right),
        cell(cw['demand']!, isEnglish ? 'Demand' : 'ที่ต้องใช้', bold: true, a: pw.TextAlign.right),
        cell(cw['reorder']!, isEnglish ? 'Reorder' : 'จุดสั่งซื้อ', bold: true, a: pw.TextAlign.right),
        cell(cw['max']!, isEnglish ? 'Max' : 'สูงสุด', bold: true, a: pw.TextAlign.right),
        cell(cw['suggested']!, isEnglish ? 'Suggested' : 'แนะนำสั่ง', bold: true, a: pw.TextAlign.right),
        cell(cw['vendor']!, isEnglish ? 'Vendor' : 'ผู้ขายแนะนำ', bold: true),
      ]),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(mg),
      header: (ctx) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
          pw.Expanded(flex: 6, child: pw.Text(reportTitle, textAlign: pw.TextAlign.center, style: tB(15))),
          pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}', textAlign: pw.TextAlign.right, style: tN(10))),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.Text(condLine, style: tN(9))),
          pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName', textAlign: pw.TextAlign.right, style: tN(10))),
        ]),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.SizedBox()),
          pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr', textAlign: pw.TextAlign.right, style: tN(10))),
        ]),
        pw.SizedBox(height: 4),
        tableHeader,
      ]),
      build: (ctx) => _rows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        return pw.Container(
          decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : const PdfColor(0.97, 0.97, 0.97)),
          child: pw.Row(children: [
            checkboxCell(selectedSnapshot.contains(i)),
            cell(cw['wh']!, r.warehouseCode),
            cell(cw['item']!, '${r.itemCode} ${isEnglish && (r.itemNameEn ?? '').isNotEmpty ? r.itemNameEn! : r.itemNameTh}'),
            cell(cw['onHand']!, _fmtQty.format(r.onHand), a: pw.TextAlign.right),
            cell(cw['incoming']!, _fmtQty.format(r.incoming), a: pw.TextAlign.right),
            cell(cw['avgSales']!, _fmtQty.format(r.avgDailySales), a: pw.TextAlign.right),
            cell(cw['demand']!, _fmtQty.format(r.projectedDemand), a: pw.TextAlign.right),
            cell(cw['reorder']!, _fmtQty.format(r.reorderPoint), a: pw.TextAlign.right),
            cell(cw['max']!, _fmtQty.format(r.maxStockQty), a: pw.TextAlign.right),
            cell(cw['suggested']!, _fmtQty.format(r.suggestedQty), bold: true, a: pw.TextAlign.right),
            cell(cw['vendor']!, r.vendorCode == null ? '-' : '${r.vendorCode} ${r.vendorNameTh ?? ''}'),
          ]),
        );
      }).toList(),
    ));
    return doc.save();
  }

  // ─── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Purchase Replenishment Suggestion' : 'ใบแนะนำสั่งซื้อเพื่อเติมสต็อก'));

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
              tooltip: isEnglish ? 'Export Excel' : 'ส่งออก Excel',
              onPressed: (_rows.isEmpty || !canExport) ? null : _exportExcel,
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // toggle
            Container(
              width: 36,
              color: Colors.teal[800],
              child: IconButton(
                icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            // filter panel
            AnimatedContainer(
              duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),

                              // คลังสินค้า (multi-select ค้นหา)
                              SearchMultiPicker<ImWarehouse>(
                                items: _warehouses,
                                selectedIds: _selectedWarehouseIds,
                                idOf: (w) => w.id,
                                labelOf: (w, en) => '${w.warehouseCode}  ${en && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh}',
                                searchTextOf: (w) => '${w.warehouseCode} ${w.warehouseNameTh} ${w.warehouseNameEn ?? ''}',
                                onChanged: (v) => setState(() => _selectedWarehouseIds = v),
                                labelTh: 'คลังสินค้า *',
                                labelEn: 'Warehouse *',
                                allLabelTh: '— เลือกคลังสินค้า —',
                                allLabelEn: '— Select warehouse —',
                              ),

                              const SizedBox(height: 12),
                              // หมวดหมู่สินค้า (multi-select ค้นหา)
                              SearchMultiPicker<ImItemCategory>(
                                items: _categories,
                                selectedIds: _selectedCategoryIds,
                                idOf: (c) => c.id,
                                labelOf: (c, en) => '${c.categoryCode}  ${en && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
                                searchTextOf: (c) => '${c.categoryCode} ${c.categoryNameTh} ${c.categoryNameEn ?? ''}',
                                onChanged: (v) => setState(() => _selectedCategoryIds = v),
                                labelTh: 'หมวดหมู่สินค้า',
                                labelEn: 'Category',
                                allLabelTh: '— ทุกหมวดหมู่ —',
                                allLabelEn: '— All categories —',
                              ),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // ณ วันที่
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: _asOf, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (picked != null) setState(() => _asOf = picked);
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: isEnglish ? 'As of Date' : 'ณ วันที่',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                  ),
                                  child: Text(_dateFmt.format(_asOf)),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ย้อนหลัง (วัน)
                              TextField(
                                controller: _lookbackCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isEnglish ? 'Lookback (days)' : 'ย้อนหลัง (วัน)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ให้พอ (วัน)
                              TextField(
                                controller: _coverageCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isEnglish ? 'Coverage (days)' : 'ให้พอ (วัน)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                            icon: const Icon(Icons.calculate),
                            label: Text(isEnglish ? 'Generate' : 'ประมวลผล'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _generate,
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
            // right panel — 2 tabs
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(children: [
                  Container(
                    color: Colors.teal[50],
                    child: TabBar(
                      labelColor: Colors.teal[900],
                      indicatorColor: Colors.teal[800],
                      tabs: [
                        Tab(text: isEnglish ? 'Items' : 'รายการ', icon: const Icon(Icons.checklist, size: 18)),
                        Tab(text: isEnglish ? 'PDF Report' : 'รายงาน PDF', icon: const Icon(Icons.picture_as_pdf, size: 18)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(children: [
                      _buildItemsTab(isEnglish, canCreate),
                      _buildPdfTab(isEnglish, canPrint),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildItemsTab(bool isEnglish, bool canCreate) {
    return Column(children: [
      if (_rows.isNotEmpty)
        Container(
          color: Colors.blue.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text(
              isEnglish ? 'Selected ${_selected.length} of ${_rows.length} item(s)' : 'เลือกแล้ว ${_selected.length} จาก ${_rows.length} รายการ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue[800]),
            ),
            const Spacer(),
            if (canCreate) ...[
              OutlinedButton.icon(
                onPressed: _isCreating || _selected.isEmpty ? null : _createPr,
                icon: const Icon(Icons.assignment_outlined, size: 16),
                label: Text(isEnglish ? 'Create PR' : 'สร้างใบขอซื้อ (PR)'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isCreating || _selected.isEmpty ? null : _createPo,
                icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                label: Text(isEnglish ? 'Create PO' : 'สร้างใบสั่งซื้อ (PO)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[600], foregroundColor: Colors.white),
              ),
            ],
          ]),
        ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? Center(child: Text(
                    _hasGenerated
                        ? (isEnglish
                            ? 'No items need reordering for the selected warehouse/conditions'
                            : 'ไม่มีรายการที่ต้องสั่งซื้อสำหรับคลังสินค้า/เงื่อนไขที่เลือก')
                        : (isEnglish ? 'Select warehouse(s) and click Generate' : 'เลือกคลังสินค้าแล้วกดประมวลผล'),
                    style: const TextStyle(color: Colors.grey)))
                : _buildTable(isEnglish),
      ),
    ]);
  }

  Widget _buildPdfTab(bool isEnglish, bool canPrint) {
    return Container(
      color: Colors.grey[200],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(child: Text(
                  _hasGenerated
                      ? (isEnglish ? 'No items need reordering for the selected warehouse/conditions' : 'ไม่มีรายการที่ต้องสั่งซื้อสำหรับคลังสินค้า/เงื่อนไขที่เลือก')
                      : (isEnglish ? 'Select warehouse(s) and click Generate' : 'เลือกคลังสินค้าแล้วกดประมวลผล'),
                  style: const TextStyle(color: Colors.grey)))
              : PdfPreview(
                  key: ValueKey(_pdfKey),
                  build: (fmt) => _generatePdf(fmt),
                  initialPageFormat: PdfPageFormat.a4.landscape,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: canPrint,
                  allowSharing: canPrint,
                ),
    );
  }

  Widget _buildTable(bool isEnglish) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            columnSpacing: 12,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 46,
            columns: [
              DataColumn(label: Checkbox(
                value: _rows.isNotEmpty && _selected.length == _rows.length,
                tristate: _selected.isNotEmpty && _selected.length < _rows.length,
                onChanged: (v) => setState(() {
                  if (v == true) { _selected.addAll(List.generate(_rows.length, (i) => i)); } else { _selected.clear(); }
                  _pdfKey++;
                }),
              )),
              DataColumn(label: Text(isEnglish ? 'Warehouse' : 'คลัง', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Item' : 'สินค้า', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'On Hand' : 'คงเหลือ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Incoming' : 'กำลังมา', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Avg/Day' : 'ขาย/วัน', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Demand' : 'ที่ต้องใช้', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Reorder Pt.' : 'จุดสั่งซื้อ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Max' : 'สูงสุด', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Suggested Qty' : 'แนะนำสั่ง', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Vendor' : 'ผู้ขายแนะนำ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Last Price' : 'ราคาล่าสุด', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            ],
            rows: _rows.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final sel = _selected.contains(i);
              return DataRow(
                color: WidgetStateProperty.all(sel ? Colors.blue.withOpacity(0.06) : null),
                cells: [
                  DataCell(Checkbox(value: sel, onChanged: (v) => setState(() {
                    if (v == true) _selected.add(i); else _selected.remove(i);
                    _pdfKey++;
                  }))),
                  DataCell(Text(r.warehouseCode, style: const TextStyle(fontSize: 12))),
                  DataCell(SizedBox(width: 220, child: Text('${r.itemCode}  ${isEnglish && (r.itemNameEn ?? '').isNotEmpty ? r.itemNameEn! : r.itemNameTh}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  DataCell(Text(_fmtQty.format(r.onHand), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmtQty.format(r.incoming), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmtQty.format(r.avgDailySales), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmtQty.format(r.projectedDemand), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmtQty.format(r.reorderPoint), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmtQty.format(r.maxStockQty), style: const TextStyle(fontSize: 12))),
                  DataCell(SizedBox(
                    width: 100,
                    child: TextFormField(
                      key: ValueKey('sugg_$i'),
                      initialValue: _fmtQty.format(r.suggestedQty),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                      onChanged: (v) => r.suggestedQty = double.tryParse(v) ?? 0,
                      onEditingComplete: _syncPdf,
                    ),
                  )),
                  DataCell(InkWell(
                    onTap: () => _pickVendorForRow(r),
                    child: SizedBox(
                      width: 160,
                      child: Text(r.vendorId == null ? (isEnglish ? '— pick vendor —' : '— เลือกผู้ขาย —') : '${r.vendorCode ?? ''} ${r.vendorNameTh ?? ''}',
                          style: TextStyle(fontSize: 12, color: r.vendorId == null ? Colors.orange[800] : Colors.black87, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis),
                    ),
                  )),
                  DataCell(Text(r.lastPrice != null ? _fmtValue.format(r.lastPrice) : '-', style: const TextStyle(fontSize: 12))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
