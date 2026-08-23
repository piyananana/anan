// lib/im/screens/im_stock_count_print_screen.dart — ขั้นตอนที่ 3: พิมพ์ใบตรวจนับ
import 'dart:typed_data';
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
import '../services/im_location_service.dart';
import '../widgets/im_stock_count_picker_field.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_auth_service.dart';

class ImStockCountPrintScreen extends StatefulWidget {
  const ImStockCountPrintScreen({super.key});

  @override
  State<ImStockCountPrintScreen> createState() => _ImStockCountPrintScreenState();
}

class _ImStockCountPrintScreenState extends State<ImStockCountPrintScreen> {
  final ImStockCountService _service = ImStockCountService();
  final ImLocationService _locationService = ImLocationService();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isFilterExpanded = true;
  double _filterWidth = 340;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;
  bool _isProcessing = false;

  ImStockCountHeader? _selectedCount;
  int _printCount = 0;
  bool _printEmptyBins = false;
  bool _pageBreakPerBin = false;

  List<ImStockCountDetail> _lines = [];
  List<ImLocation> _locations = [];
  bool _hasReport = false;

  Future<void> _process() async {
    if (_selectedCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Please select a count sheet' : 'กรุณาเลือกใบตรวจนับ')));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final id = _selectedCount!.id;
      final newCount = await _service.incrementPrintCount(id);
      final data = await _service.fetchRow(id);
      final locations = await _locationService.fetchRows(warehouseId: data.header.warehouseId);
      if (mounted) {
        setState(() {
          _printCount = newCount;
          _lines = data.details;
          _locations = locations;
          _hasReport = true;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  List<ImLocation> get _bins => _locations.where((l) => l.locationType == 'BIN').toList();

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

    // เรียงตาม sort_order ของ bin (ถ้าไม่ระบุ ใช้ location_code แทน)
    final binsSorted = [..._bins]
      ..sort((a, b) {
        if (a.sortOrder != null && b.sortOrder != null && a.sortOrder != b.sortOrder) return a.sortOrder!.compareTo(b.sortOrder!);
        if (a.sortOrder != null && b.sortOrder == null) return -1;
        if (a.sortOrder == null && b.sortOrder != null) return 1;
        return a.locationCode.compareTo(b.locationCode);
      });

    final linesByBin = <int, List<ImStockCountDetail>>{};
    for (final l in _lines) {
      if (l.locationId == null) continue;
      linesByBin.putIfAbsent(l.locationId!, () => []).add(l);
    }
    for (final list in linesByBin.values) {
      list.sort((a, b) => (a.itemCode ?? '').compareTo(b.itemCode ?? ''));
    }

    final binsToPrint = _printEmptyBins ? binsSorted : binsSorted.where((b) => (linesByBin[b.id] ?? []).isNotEmpty).toList();

    pw.Widget buildHeader(pw.Context ctx) => pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
            pw.Expanded(
                flex: 7,
                child: pw.Text(isEnglish ? 'Physical Count Sheet' : 'ใบตรวจนับสต็อก',
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                flex: 3,
                child: pw.Text(isEnglish ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}' : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                    textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(child: pw.Text('${isEnglish ? 'Count No.' : 'เลขที่ใบตรวจนับ'}: ${_selectedCount?.countNo ?? ''}', style: const pw.TextStyle(fontSize: 11))),
            pw.Expanded(
                child: pw.Text(
                    '${isEnglish ? 'Warehouse' : 'คลังสินค้า'}: ${_selectedCount?.warehouseCode ?? ''} ${_selectedCount?.warehouseNameTh ?? ''}',
                    style: const pw.TextStyle(fontSize: 11))),
            pw.Expanded(
                child: pw.Text('${isEnglish ? 'Count Date' : 'วันที่ตรวจนับ'}: ${_selectedCount != null ? _dateFmt.format(_selectedCount!.countDate) : ''}',
                    style: const pw.TextStyle(fontSize: 11))),
          ]),
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.Expanded(child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName', style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(child: pw.Text(isEnglish ? 'Printed: $printDateStr' : 'พิมพ์เมื่อ $printDateStr', style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(
                child: pw.Text(isEnglish ? 'Print No.: $_printCount' : 'ครั้งที่พิมพ์: $_printCount',
                    textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
          ]),
          pw.SizedBox(height: 6),
        ]);

    final headers = [
      isEnglish ? 'No.' : 'ลำดับ',
      isEnglish ? 'Item Code' : 'รหัสสินค้า',
      isEnglish ? 'Item Name' : 'ชื่อสินค้า',
      isEnglish ? 'UOM' : 'หน่วยนับ',
      isEnglish ? 'Counted Qty' : 'ยอดตรวจนับ',
      isEnglish ? 'Remark' : 'หมายเหตุ',
    ];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(28),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(3),
      3: const pw.FlexColumnWidth(1.2),
    };

    pw.Widget buildBinTable(ImLocation bin) {
      final items = linesByBin[bin.id] ?? [];
      int rowNo = 1;
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text('${isEnglish ? 'Bin' : 'ตำแหน่ง'}: ${bin.locationCode}  ${bin.locationName ?? ''}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: widths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: headers
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(h, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))))
                  .toList(),
            ),
            ...items.map((l) => pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${rowNo++}', style: const pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l.itemCode ?? '', style: const pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l.itemName ?? '', style: const pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l.uomCode ?? '', style: const pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                ])),
          ],
        ),
        pw.SizedBox(height: 10),
      ]);
    }

    if (_pageBreakPerBin) {
      for (final bin in binsToPrint) {
        doc.addPage(pw.MultiPage(
          pageFormat: format,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.all(24),
          header: buildHeader,
          build: (ctx) => [buildBinTable(bin)],
        ));
      }
      if (binsToPrint.isEmpty) {
        doc.addPage(pw.MultiPage(
          pageFormat: format,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.all(24),
          header: buildHeader,
          build: (ctx) => [pw.Text(isEnglish ? 'No bins to print' : 'ไม่มีตำแหน่งจัดเก็บให้พิมพ์')],
        ));
      }
    } else {
      doc.addPage(pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(24),
        header: buildHeader,
        build: (ctx) => binsToPrint.isEmpty
            ? [pw.Text(isEnglish ? 'No bins to print' : 'ไม่มีตำแหน่งจัดเก็บให้พิมพ์')]
            : binsToPrint.map(buildBinTable).toList(),
      ));
    }

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canPrint = perm?.canPrint ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
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
                      InputDecorator(
                        decoration: InputDecoration(labelText: isEnglish ? 'Count Sheet *' : 'ใบตรวจนับ *', border: const OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              _selectedCount != null ? '${_selectedCount!.countNo} — ${_dateFmt.format(_selectedCount!.countDate)}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.teal, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => ImStockCountPickerField.search(context, onSelected: (h) => setState(() { _selectedCount = h; _hasReport = false; })),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(labelText: isEnglish ? 'This Print No.' : 'ครั้งที่พิมพ์ครั้งนี้', border: const OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white),
                        child: Text(_hasReport ? '$_printCount' : '-'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(isEnglish ? 'Print empty bins' : 'พิมพ์ bin ว่างด้วย', style: const TextStyle(fontSize: 13)),
                        value: _printEmptyBins,
                        onChanged: (v) => setState(() => _printEmptyBins = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(isEnglish ? 'New page per bin' : 'ขึ้นหน้าใหม่ทุก bin', style: const TextStyle(fontSize: 13)),
                        value: _pageBreakPerBin,
                        onChanged: (v) => setState(() => _pageBreakPerBin = v),
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
              child: !_hasReport
                  ? Center(child: Text(isEnglish ? 'Select a count sheet and click Process Report' : 'กรุณาเลือกใบตรวจนับและกดประมวลผลรายงาน'))
                  : PdfPreview(
                      build: (format) => _generatePdf(format),
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
