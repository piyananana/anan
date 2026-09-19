// lib/po/screens/po_replenishment_report_screen.dart — ใบแนะนำสั่งซื้อเพื่อเติมสต็อก
// สูตร: ผสม min_stock_qty/max_stock_qty/reorder_point (นโยบายที่ตั้งไว้ในข้อมูลหลักสินค้า/ต่อคลัง — เดิมไม่เคยถูกใช้
// คำนวณอะไรเลย) กับยอดขายเฉลี่ย/วันจริงจาก DLN ในช่วงย้อนหลังที่เลือก คูณช่วงเวลาที่ต้องการให้พอ — ดู
// poReplenishmentController.js สำหรับสูตรเต็ม ผู้ขาย+ราคาที่แนะนำมาจากประวัติ PO จริง ไม่ใช่ im_price_list
//
// เลือกรายการ (checkbox) แล้วสร้างเป็น "ใบขอซื้อ (PR)" หรือ "ใบสั่งซื้อ (PO)" ตรงๆ ได้ทั้งคู่ — แบ่งกลุ่มตาม
// ผู้ขายที่แนะนำ (มิเรอร์วิธี ap_payment_run สร้าง 1 ใบต่อ 1 เจ้าหนี้) เรียก createTransaction เดิมของ PR/PO ไม่มี
// endpoint สร้างเอกสารใหม่ในไฟล์นี้เลย — รายงานนี้อ่านอย่างเดียว
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../im/models/im_warehouse.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../im/models/im_item_category.dart';
import '../../im/services/im_item_category_service.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../models/po_replenishment.dart';
import '../services/po_replenishment_service.dart';
import '../models/po_transaction.dart';
import '../services/po_transaction_service.dart';
import '../../pr/models/pr_transaction.dart';
import '../../pr/services/pr_transaction_service.dart';
import '../../utils/date_utils.dart';

class PoReplenishmentReportScreen extends StatefulWidget {
  const PoReplenishmentReportScreen({super.key});

  @override
  State<PoReplenishmentReportScreen> createState() => _PoReplenishmentReportScreenState();
}

class _PoReplenishmentReportScreenState extends State<PoReplenishmentReportScreen> {
  final _service = PoReplenishmentService();
  final _poService = PoTransactionService();
  final _prService = PrTransactionService();
  final _categoryService = ImItemCategoryService();
  final _companyService = CompanyService();
  final _authService = AuthService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isCreating = false;

  ImWarehouse? _warehouse;
  ImItemCategory? _category;
  DateTime _asOf = DateTime.now();
  final _lookbackCtrl = TextEditingController(text: '90');
  final _coverageCtrl = TextEditingController(text: '30');
  List<ImItemCategory> _categories = [];

  List<ReplenishmentSuggestion> _rows = [];
  final Set<int> _selected = {};

  Company? _company;
  Map<String, String>? _headers;
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
      _categoryService.fetchActiveRows(),
      _companyService.fetchCompany(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<ImItemCategory>;
      _company = results[1] as Company?;
    });
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  Future<void> _generate() async {
    final isEnglish = _isEnglish;
    if (_warehouse == null) { _warn(isEnglish ? 'Please select a warehouse' : 'กรุณาเลือกคลังสินค้า'); return; }
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchSuggestions(
        warehouseId: _warehouse!.id,
        asOf: formatLocalDate(_asOf),
        lookbackDays: int.tryParse(_lookbackCtrl.text) ?? 90,
        coverageDays: int.tryParse(_coverageCtrl.text) ?? 30,
        categoryId: _category?.id,
      );
      setState(() {
        _rows = rows;
        _selected.clear();
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
    });
  }

  Map<int?, List<ReplenishmentSuggestion>> _groupSelectedByVendor() {
    final selectedRows = _rows.where((r) => _selected.contains(r.itemId)).toList();
    final groups = <int?, List<ReplenishmentSuggestion>>{};
    for (final r in selectedRows) {
      groups.putIfAbsent(r.vendorId, () => []).add(r);
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
      final groups = _groupSelectedByVendor();
      final createdDocNos = <String>[];
      for (final entry in groups.entries) {
        final header = PrTransactionHeader(
          docId: _prDocTypes.first.id, docNo: 'AUTO', docDate: DateTime.now(),
          warehouseId: _warehouse!.id, vendorId: entry.key,
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
    final missingVendor = _rows.where((r) => _selected.contains(r.itemId) && r.vendorId == null).toList();
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
      final groups = _groupSelectedByVendor();
      final createdDocNos = <String>[];
      for (final entry in groups.entries) {
        final header = PoTransactionHeader(
          docId: _poDocTypes.first.id, docNo: 'AUTO', docDate: DateTime.now(),
          vendorId: entry.key!, warehouseId: _warehouse!.id,
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
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed: $e' : 'ล้มเหลว: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final reportTitle = isEnglish ? 'Purchase Replenishment Suggestion' : 'ใบแนะนำสั่งซื้อเพื่อเติมสต็อก';
    final condLine = isEnglish
        ? 'Warehouse: ${_warehouse?.warehouseCode ?? ''}  |  As of: ${_dateFmt.format(_asOf)}  |  Lookback: ${_lookbackCtrl.text}d  |  Coverage: ${_coverageCtrl.text}d'
        : 'คลัง: ${_warehouse?.warehouseCode ?? ''}  |  ณ วันที่: ${_dateFmt.format(_asOf)}  |  ย้อนหลัง: ${_lookbackCtrl.text} วัน  |  ให้พอ: ${_coverageCtrl.text} วัน';

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    const mg = 20.0;
    final pageW = format.width - mg * 2;
    const cHeader = PdfColor(0.87, 0.94, 0.92);
    const cBorder = PdfColors.grey400;

    final cw = {
      'item': pageW * 0.23, 'onHand': pageW * 0.08, 'incoming': pageW * 0.08, 'avgSales': pageW * 0.09,
      'demand': pageW * 0.09, 'reorder': pageW * 0.08, 'max': pageW * 0.08, 'suggested': pageW * 0.09,
      'vendor': pageW * 0.18,
    };

    pw.Widget cell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: bold ? tB(8) : tN(8), textAlign: a),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cHeader, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
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

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(
              width: 220,
              child: InkWell(
                onTap: () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() => _warehouse = w)),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse *' : 'คลังสินค้า *', border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.search, size: 16)),
                  child: Text(_warehouse == null ? (isEnglish ? '— Select —' : '— เลือก —') : '${_warehouse!.warehouseCode} ${_warehouse!.warehouseNameTh}',
                      style: TextStyle(fontSize: 13, color: _warehouse == null ? Colors.black38 : Colors.black87)),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<ImItemCategory?>(
                value: _category,
                isExpanded: true,
                decoration: InputDecoration(labelText: isEnglish ? 'Category' : 'หมวดหมู่สินค้า', border: const OutlineInputBorder(), isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                  ..._categories.map((c) => DropdownMenuItem(value: c, child: Text('${c.categoryCode} ${c.categoryNameTh}', overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
            SizedBox(
              width: 150,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _asOf, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _asOf = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'As of Date' : 'ณ วันที่', border: const OutlineInputBorder(), isDense: true),
                  child: Text(_dateFmt.format(_asOf)),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _lookbackCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: isEnglish ? 'Lookback (days)' : 'ย้อนหลัง (วัน)', border: const OutlineInputBorder(), isDense: true),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _coverageCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: isEnglish ? 'Coverage (days)' : 'ให้พอ (วัน)', border: const OutlineInputBorder(), isDense: true),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generate,
              icon: const Icon(Icons.calculate, size: 16),
              label: Text(isEnglish ? 'Generate' : 'ประมวลผล'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            ),
            if (_rows.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => Printing.layoutPdf(onLayout: (fmt) => _generatePdf(fmt)),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: Text(isEnglish ? 'Export PDF' : 'ส่งออก PDF'),
              ),
          ]),
        ),
        const Divider(height: 1),
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
                  ? Center(child: Text(isEnglish ? 'Select a warehouse and click Generate' : 'เลือกคลังสินค้าแล้วกดประมวลผล', style: const TextStyle(color: Colors.grey)))
                  : _buildTable(isEnglish),
        ),
      ]),
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
                  if (v == true) { _selected.addAll(_rows.map((r) => r.itemId)); } else { _selected.clear(); }
                }),
              )),
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
            rows: _rows.map((r) {
              final sel = _selected.contains(r.itemId);
              return DataRow(
                color: WidgetStateProperty.all(sel ? Colors.blue.withOpacity(0.06) : null),
                cells: [
                  DataCell(Checkbox(value: sel, onChanged: (v) => setState(() {
                    if (v == true) _selected.add(r.itemId); else _selected.remove(r.itemId);
                  }))),
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
                      key: ValueKey('sugg_${r.itemId}'),
                      initialValue: _fmtQty.format(r.suggestedQty),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                      onChanged: (v) => r.suggestedQty = double.tryParse(v) ?? 0,
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
