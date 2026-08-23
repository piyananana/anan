// lib/im/screens/im_stock_count_variance_report_screen.dart — ขั้นตอนที่ 5: รายงานผลต่างยอดตรวจนับ
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/im_stock_count.dart';
import '../models/im_location.dart';
import '../services/im_stock_count_service.dart';
import '../widgets/im_stock_count_picker_field.dart';
import '../widgets/im_location_tree_widget.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../utils/file_download.dart';

class ImStockCountVarianceReportScreen extends StatefulWidget {
  const ImStockCountVarianceReportScreen({super.key});

  @override
  State<ImStockCountVarianceReportScreen> createState() => _ImStockCountVarianceReportScreenState();
}

class _ImStockCountVarianceReportScreenState extends State<ImStockCountVarianceReportScreen> {
  final ImStockCountService _service = ImStockCountService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtMoney = NumberFormat('#,##0.00');

  bool _isFilterExpanded = true;
  double _filterWidth = 340;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;
  bool _isProcessing = false;
  bool _isExporting = false;

  ImStockCountHeader? _selectedCount;
  ImLocation? _selectedLocation;
  bool _varianceOnly = true;

  List<ImStockCountVarianceRow> _rows = [];
  bool _hasResult = false;

  Future<void> _process() async {
    final isEnglish = _isEnglish;
    if (_selectedCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a count sheet' : 'กรุณาเลือกใบตรวจนับ')));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final rows = await _service.fetchVarianceReport(
        countId: _selectedCount!.id,
        locationId: _selectedLocation?.id,
        varianceOnly: _varianceOnly,
      );
      if (mounted) setState(() { _rows = rows; _hasResult = true; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  double get _totalVarianceValue => _rows.fold<double>(0, (s, r) => s + r.varianceValue);

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final company = await CompanyService().fetchCompany();
    final companyName = company != null ? company.displayName(isEnglish) : (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = AuthService().currentUser?.userName ?? (isEnglish ? '(Unknown user)' : '(ไม่ระบุชื่อ)');
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pw.Widget buildHeader(pw.Context ctx) => pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
            pw.Expanded(
                flex: 7,
                child: pw.Text(isEnglish ? 'Stock Count Variance Report' : 'รายงานเปรียบเทียบยอดตรวจนับ',
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                flex: 3,
                child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                    textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
          ]),
          pw.SizedBox(height: 4),
          pw.Text('${isEnglish ? 'Count No.' : 'เลขที่ใบตรวจนับ'}: ${_selectedCount?.countNo ?? ''}   ${_dateFmt.format(_selectedCount?.countDate ?? DateTime.now())}',
              style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.Expanded(child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName', style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(child: pw.Text(isEnglish ? 'Printed: $printDateStr' : 'พิมพ์เมื่อ $printDateStr', style: const pw.TextStyle(fontSize: 9))),
          ]),
          pw.SizedBox(height: 6),
        ]);

    final headers = [
      isEnglish ? 'Warehouse' : 'คลังสินค้า',
      isEnglish ? 'Bin' : 'ตำแหน่ง',
      isEnglish ? 'Item Code / Name' : 'รหัส/ชื่อสินค้า',
      isEnglish ? 'System Qty' : 'ยอดในระบบ',
      isEnglish ? 'Counted Qty' : 'ยอดตรวจนับ',
      isEnglish ? 'Variance' : 'ผลต่าง',
      isEnglish ? 'Variance Value' : 'มูลค่าผลต่าง',
    ];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.6),
      1: const pw.FlexColumnWidth(1.4),
      2: const pw.FlexColumnWidth(3),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.2),
      5: const pw.FlexColumnWidth(1.2),
      6: const pw.FlexColumnWidth(1.4),
    };

    pw.Alignment num0 = pw.Alignment.centerRight;

    doc.addPage(pw.MultiPage(
      pageFormat: format.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(24),
      header: buildHeader,
      build: (ctx) => [
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: widths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: headers.map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(h, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)))).toList(),
            ),
            ..._rows.map((r) => pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.warehouseCode ?? '', style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.locationCode ?? '', style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${r.itemCode ?? ''} ${r.itemName ?? ''}', style: const pw.TextStyle(fontSize: 9))),
                  pw.Container(padding: const pw.EdgeInsets.all(4), alignment: num0, child: pw.Text(_fmtQty.format(r.systemQty), style: const pw.TextStyle(fontSize: 9))),
                  pw.Container(padding: const pw.EdgeInsets.all(4), alignment: num0, child: pw.Text(_fmtQty.format(r.countedQty), style: const pw.TextStyle(fontSize: 9))),
                  pw.Container(padding: const pw.EdgeInsets.all(4), alignment: num0, child: pw.Text(_fmtQty.format(r.varianceQty), style: const pw.TextStyle(fontSize: 9))),
                  pw.Container(padding: const pw.EdgeInsets.all(4), alignment: num0, child: pw.Text(_fmtMoney.format(r.varianceValue), style: const pw.TextStyle(fontSize: 9))),
                ])),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  alignment: num0,
                  child: pw.Text(_fmtMoney.format(_totalVarianceValue), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ],
    ));

    return doc.save();
  }

  void _xlCell(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue ? v : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(backgroundColorHex: bg ?? ExcelColor.none, horizontalAlign: align ?? HorizontalAlign.Left, bold: bold);
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    final isEnglish = _isEnglish;
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'Variance');
      final s = ex['Variance'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      _xlCell(s, 0, 0, isEnglish ? 'Stock Count Variance Report' : 'รายงานเปรียบเทียบยอดตรวจนับ', bold: true);
      _xlCell(s, 1, 0, '${_selectedCount?.countNo ?? ''}   ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');

      int r = 3;
      final headers = [
        isEnglish ? 'Warehouse' : 'คลังสินค้า', isEnglish ? 'Bin' : 'ตำแหน่ง', isEnglish ? 'Item Code' : 'รหัสสินค้า', isEnglish ? 'Item Name' : 'ชื่อสินค้า',
        isEnglish ? 'System Qty' : 'ยอดในระบบ', isEnglish ? 'Counted Qty' : 'ยอดตรวจนับ', isEnglish ? 'Variance' : 'ผลต่าง', isEnglish ? 'Variance Value' : 'มูลค่าผลต่าง',
      ];
      for (var i = 0; i < headers.length; i++) { _xlCell(s, r, i, headers[i], bg: hdrBg, bold: true); }
      r++;
      for (final row in _rows) {
        _xlCell(s, r, 0, row.warehouseCode ?? '');
        _xlCell(s, r, 1, row.locationCode ?? '');
        _xlCell(s, r, 2, row.itemCode ?? '');
        _xlCell(s, r, 3, row.itemName ?? '');
        _xlCell(s, r, 4, DoubleCellValue(row.systemQty), align: HorizontalAlign.Right);
        _xlCell(s, r, 5, DoubleCellValue(row.countedQty), align: HorizontalAlign.Right);
        _xlCell(s, r, 6, DoubleCellValue(row.varianceQty), align: HorizontalAlign.Right);
        _xlCell(s, r, 7, DoubleCellValue(row.varianceValue), align: HorizontalAlign.Right);
        r++;
      }
      _xlCell(s, r, 0, isEnglish ? 'Grand Total' : 'รวมทั้งสิ้น', bold: true);
      _xlCell(s, r, 7, DoubleCellValue(_totalVarianceValue), align: HorizontalAlign.Right, bold: true);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'stock_count_variance_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _fkField({required String label, required String? displayText, required bool hasValue, VoidCallback? onSearch}) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white),
      child: Row(children: [
        Expanded(
          child: Text(hasValue ? (displayText ?? '') : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
              style: hasValue ? const TextStyle(fontWeight: FontWeight.bold) : TextStyle(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
        ),
        if (onSearch != null) IconButton(icon: const Icon(Icons.search, color: Colors.teal, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canPrint = perm?.canPrint ?? true;
    final canExport = perm?.canExport ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
          else
            IconButton(icon: const Icon(Icons.table_chart_outlined), tooltip: 'Export Excel', onPressed: (_rows.isEmpty || !canExport) ? null : _exportExcel),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 36,
            color: Colors.teal[800],
            child: IconButton(
              icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
            ),
          ),
          AnimatedContainer(
            duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
            width: _isFilterExpanded ? _filterWidth : 0.0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _filterWidth,
                minWidth: _filterWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.blueGrey.shade100,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _fkField(
                        label: isEnglish ? 'Count Sheet *' : 'ใบตรวจนับ *',
                        hasValue: _selectedCount != null,
                        displayText: _selectedCount != null ? '${_selectedCount!.countNo} — ${_dateFmt.format(_selectedCount!.countDate)}' : null,
                        onSearch: () => ImStockCountPickerField.search(context, onSelected: (h) => setState(() {
                          _selectedCount = h;
                          _selectedLocation = null;
                          _hasResult = false;
                        })),
                      ),
                      const SizedBox(height: 12),
                      _fkField(
                        label: isEnglish ? 'Warehouse' : 'คลังสินค้า',
                        hasValue: _selectedCount != null,
                        displayText: _selectedCount != null ? '${_selectedCount!.warehouseCode ?? ''} ${_selectedCount!.warehouseNameTh ?? ''}' : null,
                      ),
                      const SizedBox(height: 12),
                      _fkField(
                        label: isEnglish ? 'Location' : 'ตำแหน่งจัดเก็บ',
                        hasValue: _selectedLocation != null,
                        displayText: _selectedLocation != null ? '${_selectedLocation!.locationCode} ${_selectedLocation!.locationName ?? ''}' : null,
                        onSearch: _selectedCount == null
                            ? null
                            : () => ImLocationTreeWidget.search(context, warehouseId: _selectedCount!.warehouseId, onSelected: (loc) => setState(() => _selectedLocation = loc)),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(isEnglish ? 'Variance only' : 'เฉพาะรายการที่มีผลต่าง', style: const TextStyle(fontSize: 13)),
                        value: _varianceOnly,
                        onChanged: (v) => setState(() => _varianceOnly = v),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _process,
                          icon: _isProcessing
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(isEnglish ? 'Process Report' : 'ประมวลผลรายงาน'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (_isFilterExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                onHorizontalDragUpdate: (details) => setState(() => _filterWidth = (_filterWidth + details.delta.dx).clamp(240.0, maxFilterWidth)),
                onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: !_hasResult
                  ? Center(child: Text(isEnglish ? 'Select filters and click Process Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน'))
                  : PdfPreview(
                      build: (format) => _generatePdf(format),
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
