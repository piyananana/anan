// lib/mo/screens/mo_status_report_screen.dart — รายงานสถานะใบสั่งผลิต (MO Status Report) หน้าจอสำหรับฝ่ายวางแผน
// (Planning): ตัวกรองสถานะ/คลัง/ช่วงวันที่/ค้นหา แสดงจำนวนวางแผน vs เบิกจริง (ฝั่งวัตถุดิบ) และวางแผน vs รับจริง
// (ฝั่งผลผลิต) พร้อม % สำเร็จ และยอดคงเหลือ WIP เปิดอยู่ ต่อ MO — read-only, ดึงจาก fetchStatusReport ใน
// moHeaderController.js (คำนวณ % complete ฝั่ง backend) ใช้ pattern เดียวกับหน้าจอรายงานอื่นในระบบ: left filter
// panel ย่อ/ขยายได้ + right PDF preview เป็นเนื้อหาหลัก + ปุ่ม export Excel ดู [[pattern_master_report_screen]]
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

String _uomName(String? code, String? nameTh, String? nameEn, bool isEnglish) {
  if (isEnglish && (nameEn ?? '').isNotEmpty) return nameEn!;
  if ((nameTh ?? '').isNotEmpty) return nameTh!;
  return code ?? '';
}

class MoStatusReportScreen extends StatefulWidget {
  const MoStatusReportScreen({super.key});

  @override
  State<MoStatusReportScreen> createState() => _MoStatusReportScreenState();
}

class _MoStatusReportScreenState extends State<MoStatusReportScreen> {
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
  List<MoStatusReportRow> _rows = [];

  String? _status;
  int? _warehouseId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _searchCtrl = TextEditingController();

  static const _statuses = ['Draft', 'Submitted', 'Rejected', 'Released', 'InProgress', 'Completed', 'Closed', 'Cancelled'];

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
      final rows = await _moService.fetchStatusReport(
        status: _status,
        warehouseId: _warehouseId,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (mounted) setState(() { _rows = rows; _pdfKey++; });
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

  String _itemLabel(MoStatusReportRow r, bool isEnglish) {
    final name = isEnglish && (r.bomParentItemNameEn ?? '').isNotEmpty ? r.bomParentItemNameEn : r.bomParentItemNameTh;
    return '${r.bomParentItemCode ?? ''} ${name ?? ''}'.trim();
  }

  String _warehouseLabel(MoStatusReportRow r, bool isEnglish) {
    final name = isEnglish && (r.warehouseNameEn ?? '').isNotEmpty ? r.warehouseNameEn : r.warehouseNameTh;
    return '${r.warehouseCode ?? ''} ${name ?? ''}'.trim();
  }

  String _conditionLine(bool isEnglish) {
    final parts = <String>[];
    parts.add(_status == null
        ? (isEnglish ? 'Status: All' : 'สถานะ: ทั้งหมด')
        : '${isEnglish ? 'Status' : 'สถานะ'}: ${moHeaderStatusLabel(_status!, isEnglish)}');
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
    final fmtPct = NumberFormat('#,##0.0', 'en_US');
    final fmtMoney = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal = PdfColor(0.75, 0.88, 0.96);
    const cBorder = PdfColors.grey400;

    final cw = {
      'moNo': pageW * 0.09,
      'date': pageW * 0.07,
      'item': pageW * 0.17,
      'wh': pageW * 0.11,
      'status': pageW * 0.08,
      'orderQty': pageW * 0.10,
      'component': pageW * 0.13,
      'output': pageW * 0.13,
      'pct': pageW * 0.06,
      'wip': pageW * 0.06,
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
        cell(cw['orderQty']!, isEnglish ? 'Order Qty' : 'สั่งผลิต', bold: true, a: pw.TextAlign.right),
        cell(cw['component']!, isEnglish ? 'Component\nIssued/Planned' : 'วัตถุดิบ\nเบิก/แผน', bold: true, a: pw.TextAlign.right),
        cell(cw['output']!, isEnglish ? 'Output\nReceived/Planned' : 'ผลผลิต\nรับ/แผน', bold: true, a: pw.TextAlign.right),
        cell(cw['pct']!, isEnglish ? '%Done' : '%สำเร็จ', bold: true, a: pw.TextAlign.right),
        cell(cw['wip']!, isEnglish ? 'WIP' : 'WIP', bold: true, a: pw.TextAlign.right),
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
          pw.SizedBox(height: 4),
          tableHeader,
        ]);

    final content = <pw.Widget>[];
    double totalWip = 0;
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final uom = _uomName(r.uomCode, r.uomNameTh, r.uomNameEn, isEnglish);
      totalWip += r.wipBalanceLc;
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
          cell(cw['orderQty']!, '${fmtQty.format(r.orderQty)} $uom', a: pw.TextAlign.right),
          cell(cw['component']!, '${fmtQty.format(r.componentIssuedQty)} / ${fmtQty.format(r.componentPlannedQty)}', a: pw.TextAlign.right),
          cell(cw['output']!, '${fmtQty.format(r.outputReceivedQty)} / ${fmtQty.format(r.outputPlannedQty)}', a: pw.TextAlign.right),
          cell(cw['pct']!, '${fmtPct.format(r.percentComplete)}%', a: pw.TextAlign.right),
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
            child: pw.Text(isEnglish ? 'Total ${_rows.length} order(s):' : 'รวมทั้งสิ้น ${_rows.length} ใบสั่งผลิต:', style: tB(9)),
          ),
        ),
        cell(cw['wip']!, fmtMoney.format(totalWip), bold: true, a: pw.TextAlign.right),
      ]),
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
      const sheetName = 'MoStatus';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      final hdrs = isEnglish
          ? ['MO No.', 'Date', 'Item', 'Warehouse', 'Status', 'Order Qty', 'Unit', 'Component Planned', 'Component Issued', 'Output Planned', 'Output Received', '% Complete', 'WIP Balance']
          : ['เลขที่ MO', 'วันที่', 'สินค้า', 'คลัง', 'สถานะ', 'จำนวนสั่งผลิต', 'หน่วย', 'วัตถุดิบตามแผน', 'วัตถุดิบเบิกแล้ว', 'ผลผลิตตามแผน', 'ผลผลิตรับแล้ว', '% สำเร็จ', 'คงเหลือ WIP'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 4, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 5;
      double totalWip = 0;
      for (final r in _rows) {
        totalWip += r.wipBalanceLc;
        _xl(s, row, 0, r.docNo);
        _xl(s, row, 1, DateFormat('dd/MM/yyyy').format(r.docDate));
        _xl(s, row, 2, _itemLabel(r, isEnglish));
        _xl(s, row, 3, _warehouseLabel(r, isEnglish));
        _xl(s, row, 4, moHeaderStatusLabel(r.status, isEnglish));
        _xl(s, row, 5, r.orderQty, align: HorizontalAlign.Right);
        _xl(s, row, 6, _uomName(r.uomCode, r.uomNameTh, r.uomNameEn, isEnglish));
        _xl(s, row, 7, r.componentPlannedQty, align: HorizontalAlign.Right);
        _xl(s, row, 8, r.componentIssuedQty, align: HorizontalAlign.Right);
        _xl(s, row, 9, r.outputPlannedQty, align: HorizontalAlign.Right);
        _xl(s, row, 10, r.outputReceivedQty, align: HorizontalAlign.Right);
        _xl(s, row, 11, r.percentComplete, align: HorizontalAlign.Right);
        _xl(s, row, 12, r.wipBalanceLc, align: HorizontalAlign.Right);
        row++;
      }

      _xl(s, row, 0, isEnglish ? 'Total ${_rows.length} order(s):' : 'รวมทั้งสิ้น ${_rows.length} ใบสั่งผลิต:', bg: ExcelColor.fromHexString('#BDD7EE'), bold: true);
      for (int c = 1; c < 12; c++) {
        _xl(s, row, c, '', bg: ExcelColor.fromHexString('#BDD7EE'));
      }
      _xl(s, row, 12, totalWip, bg: ExcelColor.fromHexString('#BDD7EE'), bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'MO_Status_Report' : 'รายงานสถานะใบสั่งผลิต';
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _status,
                isExpanded: true,
                decoration: InputDecoration(labelText: isEnglish ? 'Status' : 'สถานะ', isDense: true, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: null, child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                  ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(moHeaderStatusLabel(s, isEnglish)))),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 12),
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
        : (perm?.menuName ?? (isEnglish ? 'Manufacturing Order Status Report' : 'รายงานสถานะใบสั่งผลิต'));

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
              onPressed: (_rows.isEmpty || !canExport) ? null : _exportExcel,
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
                  : _rows.isEmpty
                      ? Center(child: Text(isEnglish ? 'No data' : 'ไม่พบข้อมูล', style: TextStyle(color: Colors.grey.shade600)))
                      : ZoomablePdfPreview(
                          documentVersion: _pdfKey,
                          build: (fmt) => _generatePdf(fmt),
                          initialPageFormat: PdfPageFormat.a4.landscape,
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
