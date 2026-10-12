// lib/mo/screens/mo_work_center_efficiency_report_screen.dart — รายงานประสิทธิภาพศูนย์งาน (Work Center
// Efficiency Report) หน้าจอสำหรับฝ่ายต้นทุน/วางแผน (Costing/Planning): ชั่วโมงแรงงาน/เครื่องจักรที่วางแผน vs
// เกิดขึ้นจริง ต่อศูนย์งาน รวมทุก MO ที่ตรงตามเงื่อนไข (มีความหมายเฉพาะ MO ที่ costing_mode='ROUTING' เท่านั้น) —
// read-only, ดึงจาก fetchEfficiencyReport ใน moWorkCenterController.js ใช้ pattern เดียวกับหน้าจอรายงานอื่น:
// left filter panel + right PDF preview + Excel export
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
import '../models/mo_work_center.dart';
import '../services/mo_work_center_service.dart';

class MoWorkCenterEfficiencyReportScreen extends StatefulWidget {
  const MoWorkCenterEfficiencyReportScreen({super.key});

  @override
  State<MoWorkCenterEfficiencyReportScreen> createState() => _MoWorkCenterEfficiencyReportScreenState();
}

class _MoWorkCenterEfficiencyReportScreenState extends State<MoWorkCenterEfficiencyReportScreen> {
  final _wcService = MoWorkCenterService();
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
  List<MoWorkCenterEfficiencyRow> _rows = [];

  String? _status;
  int? _warehouseId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _searchCtrl = TextEditingController();

  static const _statuses = ['Draft', 'Released', 'InProgress', 'Completed', 'Closed', 'Cancelled'];

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
      final rows = await _wcService.fetchEfficiencyReport(
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

  String _wcName(MoWorkCenterEfficiencyRow r, bool isEnglish) {
    final name = isEnglish && (r.workCenterNameEn ?? '').isNotEmpty ? r.workCenterNameEn : r.workCenterNameTh;
    return '${r.workCenterCode} $name';
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
    parts.add(isEnglish ? 'Only meaningful for Routing-costed MOs' : 'มีความหมายเฉพาะ MO ที่คิดต้นทุนแบบ Routing');
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
    final fmtQty = NumberFormat('#,##0.##', 'en_US');
    final fmtPct = NumberFormat('#,##0.0', 'en_US');
    final fmtMoney = NumberFormat('#,##0.00', 'en_US');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal = PdfColor(0.75, 0.88, 0.96);
    const cBorder = PdfColors.grey400;

    final cw = {
      'wc': pageW * 0.20,
      'moCount': pageW * 0.08,
      'opCount': pageW * 0.08,
      'laborPlan': pageW * 0.10,
      'laborAct': pageW * 0.10,
      'laborPct': pageW * 0.08,
      'machPlan': pageW * 0.10,
      'machAct': pageW * 0.10,
      'machPct': pageW * 0.08,
      'cost': pageW * 0.08,
    };

    pw.Widget cell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t, style: bold ? tB(8.5) : tN(8.5), textAlign: a),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cGreen, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['wc']!, isEnglish ? 'Work Center' : 'ศูนย์งาน', bold: true),
        cell(cw['moCount']!, isEnglish ? 'MOs' : 'จำนวน MO', bold: true, a: pw.TextAlign.right),
        cell(cw['opCount']!, isEnglish ? 'Ops' : 'ขั้นตอน', bold: true, a: pw.TextAlign.right),
        cell(cw['laborPlan']!, isEnglish ? 'Labor Plan' : 'แรงงานแผน', bold: true, a: pw.TextAlign.right),
        cell(cw['laborAct']!, isEnglish ? 'Labor Actual' : 'แรงงานจริง', bold: true, a: pw.TextAlign.right),
        cell(cw['laborPct']!, isEnglish ? 'Labor %' : '% แรงงาน', bold: true, a: pw.TextAlign.right),
        cell(cw['machPlan']!, isEnglish ? 'Machine Plan' : 'เครื่องจักรแผน', bold: true, a: pw.TextAlign.right),
        cell(cw['machAct']!, isEnglish ? 'Machine Actual' : 'เครื่องจักรจริง', bold: true, a: pw.TextAlign.right),
        cell(cw['machPct']!, isEnglish ? 'Machine %' : '% เครื่องจักร', bold: true, a: pw.TextAlign.right),
        cell(cw['cost']!, isEnglish ? 'Cost' : 'ต้นทุน', bold: true, a: pw.TextAlign.right),
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
    double totalLaborPlan = 0, totalLaborActual = 0, totalMachinePlan = 0, totalMachineActual = 0, totalCost = 0;
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      totalLaborPlan += r.plannedLaborHours;
      totalLaborActual += r.actualLaborHours;
      totalMachinePlan += r.plannedMachineHours;
      totalMachineActual += r.actualMachineHours;
      totalCost += r.actualCost;
      final bg = i.isOdd ? cStripe : null;
      content.add(pw.Container(
        color: bg,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
        child: pw.Row(children: [
          cell(cw['wc']!, _wcName(r, isEnglish)),
          cell(cw['moCount']!, '${r.moCount}', a: pw.TextAlign.right),
          cell(cw['opCount']!, '${r.operationCount}', a: pw.TextAlign.right),
          cell(cw['laborPlan']!, fmtQty.format(r.plannedLaborHours), a: pw.TextAlign.right),
          cell(cw['laborAct']!, fmtQty.format(r.actualLaborHours), a: pw.TextAlign.right),
          cell(cw['laborPct']!, '${fmtPct.format(r.laborUtilizationPct)}%', a: pw.TextAlign.right),
          cell(cw['machPlan']!, fmtQty.format(r.plannedMachineHours), a: pw.TextAlign.right),
          cell(cw['machAct']!, fmtQty.format(r.actualMachineHours), a: pw.TextAlign.right),
          cell(cw['machPct']!, '${fmtPct.format(r.machineUtilizationPct)}%', a: pw.TextAlign.right),
          cell(cw['cost']!, fmtMoney.format(r.actualCost), a: pw.TextAlign.right),
        ]),
      ));
    }

    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      child: pw.Row(children: [
        pw.Expanded(
          flex: 100,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: pw.Text(isEnglish ? 'Total ${_rows.length} work center(s):' : 'รวมทั้งสิ้น ${_rows.length} ศูนย์งาน:', style: tB(9)),
          ),
        ),
        cell(cw['laborPlan']!, fmtQty.format(totalLaborPlan), bold: true, a: pw.TextAlign.right),
        cell(cw['laborAct']!, fmtQty.format(totalLaborActual), bold: true, a: pw.TextAlign.right),
        cell(cw['laborPct']!, '', a: pw.TextAlign.right),
        cell(cw['machPlan']!, fmtQty.format(totalMachinePlan), bold: true, a: pw.TextAlign.right),
        cell(cw['machAct']!, fmtQty.format(totalMachineActual), bold: true, a: pw.TextAlign.right),
        cell(cw['machPct']!, '', a: pw.TextAlign.right),
        cell(cw['cost']!, fmtMoney.format(totalCost), bold: true, a: pw.TextAlign.right),
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
      const sheetName = 'WcEfficiency';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      final hdrs = isEnglish
          ? ['Work Center', 'MOs', 'Operations', 'Labor Plan', 'Labor Actual', 'Labor %', 'Machine Plan', 'Machine Actual', 'Machine %', 'Cost']
          : ['ศูนย์งาน', 'จำนวน MO', 'ขั้นตอน', 'แรงงานแผน', 'แรงงานจริง', '% แรงงาน', 'เครื่องจักรแผน', 'เครื่องจักรจริง', '% เครื่องจักร', 'ต้นทุน'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 4, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 5;
      double totalLaborPlan = 0, totalLaborActual = 0, totalMachinePlan = 0, totalMachineActual = 0, totalCost = 0;
      for (final r in _rows) {
        totalLaborPlan += r.plannedLaborHours;
        totalLaborActual += r.actualLaborHours;
        totalMachinePlan += r.plannedMachineHours;
        totalMachineActual += r.actualMachineHours;
        totalCost += r.actualCost;
        _xl(s, row, 0, _wcName(r, isEnglish));
        _xl(s, row, 1, r.moCount, align: HorizontalAlign.Right);
        _xl(s, row, 2, r.operationCount, align: HorizontalAlign.Right);
        _xl(s, row, 3, r.plannedLaborHours, align: HorizontalAlign.Right);
        _xl(s, row, 4, r.actualLaborHours, align: HorizontalAlign.Right);
        _xl(s, row, 5, r.laborUtilizationPct, align: HorizontalAlign.Right);
        _xl(s, row, 6, r.plannedMachineHours, align: HorizontalAlign.Right);
        _xl(s, row, 7, r.actualMachineHours, align: HorizontalAlign.Right);
        _xl(s, row, 8, r.machineUtilizationPct, align: HorizontalAlign.Right);
        _xl(s, row, 9, r.actualCost, align: HorizontalAlign.Right);
        row++;
      }

      final totBg = ExcelColor.fromHexString('#BDD7EE');
      _xl(s, row, 0, isEnglish ? 'Total ${_rows.length} work center(s):' : 'รวมทั้งสิ้น ${_rows.length} ศูนย์งาน:', bg: totBg, bold: true);
      for (int c = 1; c < 3; c++) {
        _xl(s, row, c, '', bg: totBg);
      }
      _xl(s, row, 3, totalLaborPlan, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xl(s, row, 4, totalLaborActual, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xl(s, row, 5, '', bg: totBg);
      _xl(s, row, 6, totalMachinePlan, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xl(s, row, 7, totalMachineActual, bg: totBg, bold: true, align: HorizontalAlign.Right);
      _xl(s, row, 8, '', bg: totBg);
      _xl(s, row, 9, totalCost, bg: totBg, bold: true, align: HorizontalAlign.Right);

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'Work_Center_Efficiency_Report' : 'รายงานประสิทธิภาพศูนย์งาน';
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${title}_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xl(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : (v is int ? IntCellValue(v) : TextCellValue(v?.toString() ?? ''));
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
                isEnglish ? 'Meaningful only for Routing-costed MOs' : 'มีความหมายเฉพาะ MO ที่คิดต้นทุนแบบ Routing',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
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
                  labelText: isEnglish ? 'Search (Work Center)' : 'ค้นหา (ศูนย์งาน)',
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
        : (perm?.menuName ?? (isEnglish ? 'Work Center Efficiency Report' : 'รายงานประสิทธิภาพศูนย์งาน'));

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
