// lib/mo/screens/mo_bom_cost_report_screen.dart — รายงานต้นทุนสูตรการผลิต / Where-Used หน้าจอสำหรับฝ่ายต้นทุน
// (Costing): สองโหมดสลับกันได้ — (1) ต้นทุนสูตรการผลิต (Cost Rollup) ไล่ต้นทุนลงไปหลายชั้นผ่านสูตรย่อย เมื่อ
// ส่วนประกอบเป็นสินค้าที่ผลิตเองอีกชั้น (2) Where-Used หาว่าสินค้าชิ้นหนึ่งถูกใช้เป็นส่วนประกอบของสูตรไหนบ้าง —
// read-only ทั้งคู่ ดึงจาก fetchCostRollupReport/fetchWhereUsedReport ใน moBomController.js ใช้ pattern เดียวกับ
// หน้าจอรายงานอื่น: left filter panel + right PDF preview + Excel export
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../widgets/zoomable_pdf_preview.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../im/models/im_item.dart';
import '../../im/widgets/im_item_list_widget.dart';
import '../../utils/file_download.dart';
import '../models/mo_bom.dart';
import '../services/mo_bom_service.dart';
import '../widgets/mo_bom_list_widget.dart';

enum _ReportMode { costRollup, whereUsed }

class MoBomCostReportScreen extends StatefulWidget {
  const MoBomCostReportScreen({super.key});

  @override
  State<MoBomCostReportScreen> createState() => _MoBomCostReportScreenState();
}

class _MoBomCostReportScreenState extends State<MoBomCostReportScreen> {
  final _bomService = MoBomService();
  final _companyService = CompanyService();
  final _authService = AuthService();

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 330.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;
  String _reportTitle = '';

  Company? _company;
  Map<String, String>? _headers;
  _ReportMode _mode = _ReportMode.costRollup;

  List<MoBomCostRollupRow> _rollupRows = [];
  List<MoBomWhereUsedRow> _whereUsedRows = [];

  int? _bomHeaderId;
  String? _bomLabel;
  int? _componentItemId;
  String? _componentLabel;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      _company = await _companyService.fetchCompany();
      _headers = await _authService.getAuthHeader();
      await _search();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBom() async {
    await MoBomListWidget.search(context, onSelected: (MoBomHeader h) {
      final isEnglish = _isEnglish;
      setState(() {
        _bomHeaderId = h.id;
        final name = isEnglish && (h.parentItemNameEn ?? '').isNotEmpty ? h.parentItemNameEn : h.parentItemNameTh;
        _bomLabel = '${h.parentItemCode ?? ''} $name (v${h.bomVersion})';
      });
    });
  }

  Future<void> _pickComponentItem() async {
    await ImItemListWidget.search(context, onSelected: (ImItem i) {
      final isEnglish = _isEnglish;
      setState(() {
        _componentItemId = i.id;
        final name = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
        _componentLabel = '${i.itemCode} $name';
      });
    });
  }

  Future<void> _search() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      if (_mode == _ReportMode.costRollup) {
        final rows = await _bomService.fetchCostRollupReport(
          bomHeaderId: _bomHeaderId,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        );
        if (mounted) setState(() { _rollupRows = rows; _pdfKey++; });
      } else {
        final rows = await _bomService.fetchWhereUsedReport(
          componentItemId: _componentItemId,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        );
        if (mounted) setState(() { _whereUsedRows = rows; _pdfKey++; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _itemName(String? th, String? en, bool isEnglish) {
    if (isEnglish && (en ?? '').isNotEmpty) return en!;
    return th ?? '';
  }

  String _conditionLine(bool isEnglish) {
    final parts = <String>[];
    if (_mode == _ReportMode.costRollup) {
      parts.add(_bomHeaderId == null
          ? (isEnglish ? 'All active BOMs' : 'ทุกสูตรการผลิตที่ใช้งานอยู่')
          : '${isEnglish ? 'BOM' : 'สูตร'}: ${_bomLabel ?? ''}');
    } else {
      parts.add(_componentItemId == null
          ? (isEnglish ? 'All components' : 'ทุกส่วนประกอบ')
          : '${isEnglish ? 'Component' : 'ส่วนประกอบ'}: ${_componentLabel ?? ''}');
    }
    if (_searchCtrl.text.trim().isNotEmpty) {
      parts.add('${isEnglish ? 'Search' : 'ค้นหา'}: ${_searchCtrl.text.trim()}');
    }
    return parts.join('  |  ');
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final condLine = _conditionLine(isEnglish);

    const mg = 20.0;
    final pageW = format.width - mg * 2;
    final fmtQty = NumberFormat('#,##0.####', 'en_US');
    final fmtMoney = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    pw.TextStyle tI(double fs) => pw.TextStyle(font: font, fontSize: fs, fontStyle: pw.FontStyle.italic);

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cHeader = PdfColor(0.93, 0.93, 0.97);
    const cBorder = PdfColors.grey400;

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
            pw.Expanded(flex: 6, child: pw.Text(reportTitle, textAlign: pw.TextAlign.center, style: tB(15))),
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
          pw.SizedBox(height: 6),
        ]);

    final content = <pw.Widget>[];

    if (_mode == _ReportMode.costRollup) {
      final cw = {'code': pageW * 0.42, 'qty': pageW * 0.14, 'scrap': pageW * 0.1, 'unit': pageW * 0.17, 'total': pageW * 0.17};
      pw.Widget cell(double w, String t, {bool bold = false, bool italic = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
            width: w,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Text(t, style: bold ? tB(9) : (italic ? tI(9) : tN(9)), textAlign: a),
            ),
          );
      for (final row in _rollupRows) {
        if (row.error != null) {
          content.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(6),
            decoration: const pw.BoxDecoration(color: PdfColor(0.98, 0.85, 0.85)),
            child: pw.Text('BOM #${row.bomHeaderId}: ${row.error}', style: tN(9)),
          ));
          continue;
        }
        final parentName = _itemName(row.parentItemNameTh, row.parentItemNameEn, isEnglish);
        content.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: const pw.BoxDecoration(color: cHeader),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text('${row.parentItemCode ?? ''} $parentName (v${row.bomVersion ?? ''})', style: tB(10))),
            pw.Text(
                isEnglish
                    ? 'Qty/Batch: ${fmtQty.format(row.bomQty)}   Material: ${fmtMoney.format(row.materialCost)}   Conversion: ${fmtMoney.format(row.conversionCost)}   Unit Cost: ${fmtMoney.format(row.unitCost)}'
                    : 'จำนวนต่อรอบ: ${fmtQty.format(row.bomQty)}   วัตถุดิบ: ${fmtMoney.format(row.materialCost)}   แปรรูป: ${fmtMoney.format(row.conversionCost)}   ต้นทุน/หน่วย: ${fmtMoney.format(row.unitCost)}',
                style: tB(9)),
          ]),
        ));
        content.add(pw.Container(
          decoration: const pw.BoxDecoration(color: cGreen, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
          child: pw.Row(children: [
            cell(cw['code']!, isEnglish ? 'Component' : 'ส่วนประกอบ', bold: true),
            cell(cw['qty']!, isEnglish ? 'Qty/Unit' : 'จำนวน/หน่วย', bold: true, a: pw.TextAlign.right),
            cell(cw['scrap']!, isEnglish ? 'Scrap%' : 'สูญเสีย%', bold: true, a: pw.TextAlign.right),
            cell(cw['unit']!, isEnglish ? 'Unit Cost' : 'ต้นทุน/หน่วย', bold: true, a: pw.TextAlign.right),
            cell(cw['total']!, isEnglish ? 'Line Total' : 'รวม', bold: true, a: pw.TextAlign.right),
          ]),
        ));
        for (final b in row.breakdown) {
          final compName = _itemName(b.componentItemNameTh, b.componentItemNameEn, isEnglish);
          final label = b.isSubAssembly ? '  ↳ ${b.componentItemCode ?? ''} $compName' : '    ${b.componentItemCode ?? ''} $compName';
          content.add(pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
            child: pw.Row(children: [
              cell(cw['code']!, label, italic: b.isSubAssembly),
              cell(cw['qty']!, fmtQty.format(b.quantityPer), a: pw.TextAlign.right),
              cell(cw['scrap']!, '${fmtQty.format(b.scrapPercent)}%', a: pw.TextAlign.right),
              cell(cw['unit']!, fmtMoney.format(b.unitCost), a: pw.TextAlign.right),
              cell(cw['total']!, fmtMoney.format(b.lineTotal), a: pw.TextAlign.right),
            ]),
          ));
        }
      }
    } else {
      final cw = {'comp': pageW * 0.3, 'bom': pageW * 0.38, 'ver': pageW * 0.1, 'qty': pageW * 0.11, 'scrap': pageW * 0.11};
      pw.Widget cell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
            width: w,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              child: pw.Text(t, style: bold ? tB(9) : tN(9), textAlign: a),
            ),
          );
      content.add(pw.Container(
        decoration: const pw.BoxDecoration(color: cGreen, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
        child: pw.Row(children: [
          cell(cw['comp']!, isEnglish ? 'Component' : 'ส่วนประกอบ', bold: true),
          cell(cw['bom']!, isEnglish ? 'Used In (BOM)' : 'ใช้ในสูตร', bold: true),
          cell(cw['ver']!, isEnglish ? 'Version' : 'เวอร์ชัน', bold: true),
          cell(cw['qty']!, isEnglish ? 'Qty/Unit' : 'จำนวน/หน่วย', bold: true, a: pw.TextAlign.right),
          cell(cw['scrap']!, isEnglish ? 'Scrap%' : 'สูญเสีย%', bold: true, a: pw.TextAlign.right),
        ]),
      ));
      for (int i = 0; i < _whereUsedRows.length; i++) {
        final r = _whereUsedRows[i];
        final compName = _itemName(r.componentItemNameTh, r.componentItemNameEn, isEnglish);
        final parentName = _itemName(r.parentItemNameTh, r.parentItemNameEn, isEnglish);
        final bg = i.isOdd ? const PdfColor(0.97, 0.97, 0.97) : null;
        content.add(pw.Container(
          color: bg,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
          child: pw.Row(children: [
            cell(cw['comp']!, '${r.componentItemCode ?? ''} $compName'),
            cell(cw['bom']!, '${r.parentItemCode ?? ''} $parentName'),
            cell(cw['ver']!, r.bomVersion ?? ''),
            cell(cw['qty']!, fmtQty.format(r.quantityPer), a: pw.TextAlign.right),
            cell(cw['scrap']!, '${fmtQty.format(r.scrapPercent)}%', a: pw.TextAlign.right),
          ]),
        ));
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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
      final sheetName = _mode == _ReportMode.costRollup ? 'BomCostRollup' : 'BomWhereUsed';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      int row = 4;
      if (_mode == _ReportMode.costRollup) {
        final hdrs = isEnglish
            ? ['BOM', 'Version', 'Component', 'Qty/Unit', 'Scrap%', 'Unit Cost', 'Line Total', 'Sub-Assembly?']
            : ['สูตร', 'เวอร์ชัน', 'ส่วนประกอบ', 'จำนวน/หน่วย', 'สูญเสีย%', 'ต้นทุน/หน่วย', 'รวม', 'เป็นสูตรย่อย?'];
        for (int i = 0; i < hdrs.length; i++) {
          _xl(s, row, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
        }
        row++;
        for (final r in _rollupRows) {
          if (r.error != null) {
            _xl(s, row, 0, 'BOM #${r.bomHeaderId}: ${r.error}');
            row++;
            continue;
          }
          final parentName = _itemName(r.parentItemNameTh, r.parentItemNameEn, isEnglish);
          for (final b in r.breakdown) {
            final compName = _itemName(b.componentItemNameTh, b.componentItemNameEn, isEnglish);
            _xl(s, row, 0, '${r.parentItemCode ?? ''} $parentName');
            _xl(s, row, 1, r.bomVersion ?? '');
            _xl(s, row, 2, '${b.componentItemCode ?? ''} $compName');
            _xl(s, row, 3, b.quantityPer, align: HorizontalAlign.Right);
            _xl(s, row, 4, b.scrapPercent, align: HorizontalAlign.Right);
            _xl(s, row, 5, b.unitCost, align: HorizontalAlign.Right);
            _xl(s, row, 6, b.lineTotal, align: HorizontalAlign.Right);
            _xl(s, row, 7, b.isSubAssembly ? (isEnglish ? 'Yes' : 'ใช่') : (isEnglish ? 'No' : 'ไม่'));
            row++;
          }
          _xl(s, row, 0, isEnglish ? 'Unit Cost:' : 'ต้นทุน/หน่วย:', bold: true);
          _xl(s, row, 6, r.unitCost, bold: true, align: HorizontalAlign.Right);
          row++;
        }
      } else {
        final hdrs = isEnglish
            ? ['Component', 'Used In (BOM)', 'Version', 'Qty/Unit', 'Scrap%']
            : ['ส่วนประกอบ', 'ใช้ในสูตร', 'เวอร์ชัน', 'จำนวน/หน่วย', 'สูญเสีย%'];
        for (int i = 0; i < hdrs.length; i++) {
          _xl(s, row, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
        }
        row++;
        for (final r in _whereUsedRows) {
          final compName = _itemName(r.componentItemNameTh, r.componentItemNameEn, isEnglish);
          final parentName = _itemName(r.parentItemNameTh, r.parentItemNameEn, isEnglish);
          _xl(s, row, 0, '${r.componentItemCode ?? ''} $compName');
          _xl(s, row, 1, '${r.parentItemCode ?? ''} $parentName');
          _xl(s, row, 2, r.bomVersion ?? '');
          _xl(s, row, 3, r.quantityPer, align: HorizontalAlign.Right);
          _xl(s, row, 4, r.scrapPercent, align: HorizontalAlign.Right);
          row++;
        }
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = _mode == _ReportMode.costRollup
          ? (isEnglish ? 'BOM_Cost_Rollup_Report' : 'รายงานต้นทุนสูตรการผลิต')
          : (isEnglish ? 'BOM_Where_Used_Report' : 'รายงานการใช้สินค้าในสูตร');
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

  // ─── Filter panel ───────────────────────────────────────────────────────
  Widget _buildFilterPanel() {
    final isEnglish = _isEnglish;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              SegmentedButton<_ReportMode>(
                segments: [
                  ButtonSegment(value: _ReportMode.costRollup, label: Text(isEnglish ? 'Cost Rollup' : 'ต้นทุนสูตร', style: const TextStyle(fontSize: 12))),
                  ButtonSegment(value: _ReportMode.whereUsed, label: Text(isEnglish ? 'Where-Used' : 'ใช้ที่ไหน', style: const TextStyle(fontSize: 12))),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),
              if (_mode == _ReportMode.costRollup) ...[
                InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'BOM' : 'สูตรการผลิต', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                  child: Row(children: [
                    Expanded(
                      child: Text(_bomLabel ?? (isEnglish ? '— All active BOMs —' : '— ทุกสูตรที่ใช้งานอยู่ —'),
                          overflow: TextOverflow.ellipsis, style: TextStyle(color: _bomLabel == null ? Colors.grey.shade600 : null)),
                    ),
                    if (_bomHeaderId != null)
                      IconButton(icon: const Icon(Icons.clear, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _bomHeaderId = null; _bomLabel = null; })),
                    IconButton(icon: const Icon(Icons.search, size: 18, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _pickBom),
                  ]),
                ),
              ] else ...[
                InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'Component Item' : 'สินค้าส่วนประกอบ', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                  child: Row(children: [
                    Expanded(
                      child: Text(_componentLabel ?? (isEnglish ? '— All components —' : '— ทุกส่วนประกอบ —'),
                          overflow: TextOverflow.ellipsis, style: TextStyle(color: _componentLabel == null ? Colors.grey.shade600 : null)),
                    ),
                    if (_componentItemId != null)
                      IconButton(icon: const Icon(Icons.clear, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _componentItemId = null; _componentLabel = null; })),
                    IconButton(icon: const Icon(Icons.search, size: 18, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _pickComponentItem),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Search (Item Code)' : 'ค้นหา (รหัสสินค้า)',
                  prefixIcon: const Icon(Icons.search), isDense: true, border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
            ]),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white),
              onPressed: _isLoading ? null : _search,
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'BOM Cost / Where-Used Report' : 'รายงานต้นทุนสูตรการผลิต / Where-Used'));
    final hasData = _mode == _ReportMode.costRollup ? _rollupRows.isNotEmpty : _whereUsedRows.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[700],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.grid_on),
              tooltip: isEnglish ? 'Export Excel' : 'ส่งออก Excel',
              onPressed: (!hasData || !canExport) ? null : _exportExcel,
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 36,
            color: Colors.deepOrange[700],
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
                  : !hasData
                      ? Center(child: Text(isEnglish ? 'No data' : 'ไม่พบข้อมูล', style: TextStyle(color: Colors.grey.shade600)))
                      : ZoomablePdfPreview(
                          documentVersion: _pdfKey,
                          build: (fmt) => _generatePdf(fmt),
                          initialPageFormat: PdfPageFormat.a4,
                          canChangeOrientation: false,
                          canDebug: false,
                          allowPrinting: canPrint,
                          allowSharing: canPrint,
                        ),
            ),
          ),
        ]);
      }),
    );
  }
}
