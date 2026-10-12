// lib/mo/screens/mo_wip_valuation_report_screen.dart — รายงานมูลค่างานระหว่างผลิต (MO WIP Valuation Report)
// หน้าจอสำหรับฝ่ายต้นทุน (Costing): แสดงยอด wip_balance_lc ของทุก MO ที่ยังเปิดอยู่ (Released/InProgress/
// Completed) และกระทบยอดกับยอดจริงในบัญชีงานระหว่างผลิต (wip_account_id ของ MOR) — read-only, ดึงจาก
// fetchWipValuationReport ใน moHeaderController.js ใช้ pattern เดียวกับหน้าจอรายงานอื่น: left filter panel +
// right PDF preview + Excel export
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
import '../../im/models/im_warehouse.dart';
import '../../im/services/im_warehouse_service.dart';
import '../../utils/file_download.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoWipValuationReportScreen extends StatefulWidget {
  const MoWipValuationReportScreen({super.key});

  @override
  State<MoWipValuationReportScreen> createState() => _MoWipValuationReportScreenState();
}

class _MoWipValuationReportScreenState extends State<MoWipValuationReportScreen> {
  final _moService = MoHeaderService();
  final _warehouseService = ImWarehouseService();
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

  List<ImWarehouse> _warehouses = [];
  Company? _company;
  Map<String, String>? _headers;
  MoWipValuationReport? _report;

  int? _warehouseId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      final res = await Future.wait([_warehouseService.fetchActiveRows(), _companyService.fetchCompany()]);
      _warehouses = res[0] as List<ImWarehouse>;
      _company = res[1] as Company?;
      _headers = await _authService.getAuthHeader();
      await _search();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final report = await _moService.fetchWipValuationReport(
        warehouseId: _warehouseId,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (mounted) setState(() { _report = report; _pdfKey++; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  String _itemLabel(MoWipValuationLine r, bool isEnglish) {
    final name = isEnglish && (r.bomParentItemNameEn ?? '').isNotEmpty ? r.bomParentItemNameEn : r.bomParentItemNameTh;
    return '${r.bomParentItemCode ?? ''} ${name ?? ''}'.trim();
  }

  String _warehouseLabel(MoWipValuationLine r, bool isEnglish) {
    final name = isEnglish && (r.warehouseNameEn ?? '').isNotEmpty ? r.warehouseNameEn : r.warehouseNameTh;
    return '${r.warehouseCode ?? ''} ${name ?? ''}'.trim();
  }

  String _conditionLine(bool isEnglish) {
    final parts = <String>[isEnglish ? 'Open MOs only (Released/InProgress/Completed)' : 'เฉพาะ MO ที่ยังเปิดอยู่ (ปล่อยแล้ว/กำลังผลิต/ผลิตครบแล้ว)'];
    if (_warehouseId != null) {
      final w = _warehouses.where((w) => w.id == _warehouseId).toList();
      if (w.isNotEmpty) {
        final name = isEnglish && (w.first.warehouseNameEn ?? '').isNotEmpty ? w.first.warehouseNameEn : w.first.warehouseNameTh;
        parts.add('${isEnglish ? 'Warehouse' : 'คลัง'}: ${w.first.warehouseCode} $name');
      }
    }
    if (_dateFrom != null || _dateTo != null) {
      final fmt = DateFormat('dd/MM/yyyy');
      final from = _dateFrom != null ? fmt.format(_dateFrom!) : (isEnglish ? '(no limit)' : '(ไม่กำหนด)');
      final to = _dateTo != null ? fmt.format(_dateTo!) : (isEnglish ? '(no limit)' : '(ไม่กำหนด)');
      parts.add('${isEnglish ? 'Date' : 'วันที่'}: $from - $to');
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
    final report = _report!;
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
    final fmtMoney = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal = PdfColor(0.75, 0.88, 0.96);
    const cBorder = PdfColors.grey400;
    final hasDiff = report.difference != null && report.difference!.abs() > 0.01;
    final cRecon = hasDiff ? const PdfColor(0.98, 0.90, 0.80) : const PdfColor(0.85, 0.95, 0.85);

    final cw = {
      'moNo': pageW * 0.12,
      'date': pageW * 0.09,
      'item': pageW * 0.26,
      'wh': pageW * 0.17,
      'status': pageW * 0.13,
      'wip': pageW * 0.23,
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
        cell(cw['moNo']!, isEnglish ? 'MO No.' : 'เลขที่ MO', bold: true),
        cell(cw['date']!, isEnglish ? 'Date' : 'วันที่', bold: true),
        cell(cw['item']!, isEnglish ? 'Item' : 'สินค้า', bold: true),
        cell(cw['wh']!, isEnglish ? 'Warehouse' : 'คลัง', bold: true),
        cell(cw['status']!, isEnglish ? 'Status' : 'สถานะ', bold: true),
        cell(cw['wip']!, isEnglish ? 'WIP Balance' : 'ยอดคงเหลือ WIP', bold: true, a: pw.TextAlign.right),
      ]),
    );

    final reconBox = pw.Container(
      width: pageW,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: cRecon, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(isEnglish ? 'Reconciliation with GL' : 'กระทบยอดกับบัญชีแยกประเภท', style: tB(10)),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(child: pw.Text(
              isEnglish
                  ? 'WIP Account: ${report.wipAccountCode ?? '-'} ${report.wipAccountName ?? ''}'
                  : 'บัญชีงานระหว่างผลิต: ${report.wipAccountCode ?? '-'} ${report.wipAccountName ?? ''}',
              style: tN(9))),
          pw.Text(isEnglish ? 'Sum of MO WIP: ${fmtMoney.format(report.totalMoWip)}' : 'รวมยอด WIP ของ MO: ${fmtMoney.format(report.totalMoWip)}', style: tN(9)),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Text(
              isEnglish
                  ? 'GL Balance: ${report.glBalance != null ? fmtMoney.format(report.glBalance) : 'N/A'}'
                  : 'ยอดในบัญชี GL: ${report.glBalance != null ? fmtMoney.format(report.glBalance) : 'ไม่มีข้อมูล'}',
              style: tN(9)),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Text(
              isEnglish
                  ? 'Difference: ${report.difference != null ? fmtMoney.format(report.difference) : 'N/A'}'
                  : 'ผลต่าง: ${report.difference != null ? fmtMoney.format(report.difference) : 'ไม่มีข้อมูล'}',
              style: tB(9)),
        ]),
      ]),
    );

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
          if (ctx.pageNumber == 1) reconBox,
          tableHeader,
        ]);

    final content = <pw.Widget>[];
    for (int i = 0; i < report.lines.length; i++) {
      final r = report.lines[i];
      final bg = i.isOdd ? cStripe : null;
      content.add(pw.Container(
        color: bg,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
        child: pw.Row(children: [
          cell(cw['moNo']!, r.docNo),
          cell(cw['date']!, DateFormat('dd/MM/yyyy').format(r.docDate)),
          cell(cw['item']!, _itemLabel(r, isEnglish)),
          cell(cw['wh']!, _warehouseLabel(r, isEnglish)),
          cell(cw['status']!, moHeaderStatusLabel(r.status, isEnglish)),
          cell(cw['wip']!, fmtMoney.format(r.wipBalanceLc), a: pw.TextAlign.right),
        ]),
      ));
    }

    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: pw.Text(isEnglish ? 'Total ${report.lines.length} order(s):' : 'รวมทั้งสิ้น ${report.lines.length} ใบสั่งผลิต:', style: tB(9)),
          ),
        ),
        cell(cw['wip']!, fmtMoney.format(report.totalMoWip), bold: true, a: pw.TextAlign.right),
      ]),
    ));

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
    final report = _report!;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      const sheetName = 'MoWipValuation';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');
      _xl(s, 3, 0, isEnglish
          ? 'WIP Account: ${report.wipAccountCode ?? '-'} ${report.wipAccountName ?? ''}  |  Sum of MO WIP: ${report.totalMoWip.toStringAsFixed(2)}  |  GL Balance: ${report.glBalance?.toStringAsFixed(2) ?? 'N/A'}  |  Difference: ${report.difference?.toStringAsFixed(2) ?? 'N/A'}'
          : 'บัญชีงานระหว่างผลิต: ${report.wipAccountCode ?? '-'} ${report.wipAccountName ?? ''}  |  รวมยอด WIP ของ MO: ${report.totalMoWip.toStringAsFixed(2)}  |  ยอดในบัญชี GL: ${report.glBalance?.toStringAsFixed(2) ?? 'ไม่มีข้อมูล'}  |  ผลต่าง: ${report.difference?.toStringAsFixed(2) ?? 'ไม่มีข้อมูล'}',
          bold: true);

      final hdrs = isEnglish
          ? ['MO No.', 'Date', 'Item', 'Warehouse', 'Status', 'WIP Balance']
          : ['เลขที่ MO', 'วันที่', 'สินค้า', 'คลัง', 'สถานะ', 'ยอดคงเหลือ WIP'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 5, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 6;
      for (final r in report.lines) {
        _xl(s, row, 0, r.docNo);
        _xl(s, row, 1, DateFormat('dd/MM/yyyy').format(r.docDate));
        _xl(s, row, 2, _itemLabel(r, isEnglish));
        _xl(s, row, 3, _warehouseLabel(r, isEnglish));
        _xl(s, row, 4, moHeaderStatusLabel(r.status, isEnglish));
        _xl(s, row, 5, r.wipBalanceLc, align: HorizontalAlign.Right);
        row++;
      }

      final totBg = ExcelColor.fromHexString('#BDD7EE');
      _xl(s, row, 0, isEnglish ? 'Total ${report.lines.length} order(s):' : 'รวมทั้งสิ้น ${report.lines.length} ใบสั่งผลิต:', bg: totBg, bold: true);
      for (int c = 1; c < 5; c++) {
        _xl(s, row, c, '', bg: totBg);
      }
      _xl(s, row, 5, report.totalMoWip, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'MO_WIP_Valuation_Report' : 'รายงานมูลค่างานระหว่างผลิต';
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
    final fmtDate = DateFormat('dd/MM/yyyy');
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                isEnglish ? 'Shows open MOs only (Released / In Progress / Completed)' : 'แสดงเฉพาะ MO ที่ยังเปิดอยู่ (ปล่อยแล้ว / กำลังผลิต / ผลิตครบแล้ว)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _warehouseId,
                isExpanded: true,
                decoration: InputDecoration(labelText: isEnglish ? 'Warehouse' : 'คลัง', isDense: true, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: null, child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                  ..._warehouses.map((w) => DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.warehouseCode} ${isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn : w.warehouseNameTh}'),
                      )),
                ],
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(_dateFrom == null ? (isEnglish ? 'Date From' : 'วันที่เริ่ม') : fmtDate.format(_dateFrom!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(_dateTo == null ? (isEnglish ? 'Date To' : 'วันที่สิ้นสุด') : fmtDate.format(_dateTo!)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Search (MO No. / Item)' : 'ค้นหา (เลขที่ / สินค้า)',
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
        : (perm?.menuName ?? (isEnglish ? 'Manufacturing Order WIP Valuation Report' : 'รายงานมูลค่างานระหว่างผลิต'));
    final hasData = _report != null && _report!.lines.isNotEmpty;

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
