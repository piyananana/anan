// lib/po/screens/po_pending_receipt_report_screen.dart — รายงานจัดซื้อสินค้าค้างรับ (บรรทัด PO ที่ยังรับสินค้า
// ไม่ครบ) — อ่านอย่างเดียว ดู poPendingReceiptReportController.js สำหรับการคำนวณจำนวนคงเหลือที่ยังไม่รับเต็ม
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
import '../../ap/models/ap_vendor.dart';
import '../../ap/services/ap_vendor_service.dart';
import '../../im/models/im_item.dart';
import '../../im/services/im_item_service.dart';
import '../widgets/po_search_multi_picker.dart';
import '../models/po_pending_receipt_report.dart';
import '../services/po_pending_receipt_report_service.dart';

class PoPendingReceiptReportScreen extends StatefulWidget {
  const PoPendingReceiptReportScreen({super.key});

  @override
  State<PoPendingReceiptReportScreen> createState() =>
      _PoPendingReceiptReportScreenState();
}

class _PoPendingReceiptReportScreenState
    extends State<PoPendingReceiptReportScreen> {
  final _service = PoPendingReceiptReportService();
  final _vendorService = ApVendorService();
  final _itemService = ImItemService();
  final _companyService = CompanyService();
  final _authService = AuthService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isEnglish = false;
  bool _isLoading = false;

  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;
  double _zoom = 1.0;

  DateTime? _poDateFrom;
  DateTime? _poDateTo;
  DateTime? _dueDateFrom;
  DateTime? _dueDateTo;
  List<ApVendor> _vendors = [];
  List<int> _selectedVendorIds = [];
  List<ImItem> _items = [];
  List<int> _selectedItemIds = [];
  bool _sortDueDateAsc = true;

  List<PoPendingReceiptReportRow> _reportData = [];
  bool _hasGenerated = false;

  Company? _company;
  Map<String, String>? _headers;
  String _reportTitle = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _headers = await _authService.getAuthHeader();
    final results = await Future.wait([
      _companyService.fetchCompany(),
      _vendorService.fetchActiveRows(),
      _itemService.fetchRows(),
    ]);
    if (!mounted) return;
    setState(() {
      _company = results[0] as Company?;
      _vendors = results[1] as List<ApVendor>;
      _items = (results[2] as List<ImItem>)
          .where((i) => i.isActive && i.isPurchaseItem)
          .toList();
    });
  }

  Future<void> _generate() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchReport(
        poDateFrom: _poDateFrom,
        poDateTo: _poDateTo,
        dueDateFrom: _dueDateFrom,
        dueDateTo: _dueDateTo,
        vendorIds: _selectedVendorIds,
        itemIds: _selectedItemIds,
        sortDueDateAsc: _sortDueDateAsc,
      );
      setState(() {
        _reportData = rows;
        _hasGenerated = true;
        _pdfKey++;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setZoom(double z) {
    setState(() => _zoom = z);
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData =
        await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final companyName = _company?.displayName(isEnglish) ??
        (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final reportTitle = _reportTitle.isNotEmpty
        ? _reportTitle
        : (isEnglish ? 'Pending Receipt Report' : 'รายงานจัดซื้อสินค้าค้างรับ');

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);
    const mg = 20.0;
    final pageW = format.width - mg * 2;
    const cHeader = PdfColor(0.87, 0.94, 0.92);
    const cBorder = PdfColors.grey400;

    final cw = {
      'dueDate': pageW * 0.09,
      'overdue': pageW * 0.08,
      'poNo': pageW * 0.10,
      'poDate': pageW * 0.08,
      'item': pageW * 0.16,
      'vendor': pageW * 0.15,
      'warehouse': pageW * 0.13,
      'qty': pageW * 0.07,
      'unitPrice': pageW * 0.07,
      'total': pageW * 0.07,
    };

    pw.Widget cell(double w, String t,
            {bool bold = false,
            pw.TextAlign a = pw.TextAlign.left,
            PdfColor? color}) =>
        pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(t,
                style: (bold ? tB(8) : tN(8)).copyWith(color: color),
                textAlign: a),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(
          color: cHeader,
          border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        cell(cw['dueDate']!, isEnglish ? 'Due Date' : 'วันที่ครบกำหนด',
            bold: true),
        cell(cw['overdue']!,
            isEnglish ? 'Overdue/\nDue (days)' : 'เกิน/ถึง\nกำหนด(วัน)',
            bold: true, a: pw.TextAlign.right),
        cell(cw['poNo']!, isEnglish ? 'PO No.' : 'เลขที่ใบสั่งซื้อ',
            bold: true),
        cell(cw['poDate']!, isEnglish ? 'PO Date' : 'วันที่สั่งซื้อ',
            bold: true),
        cell(cw['item']!, isEnglish ? 'Item' : 'รหัส/ชื่อสินค้า', bold: true),
        cell(cw['vendor']!, isEnglish ? 'Vendor' : 'รหัส/ชื่อผู้ขาย',
            bold: true),
        cell(cw['warehouse']!, isEnglish ? 'Warehouse' : 'รหัส/ชื่อคลัง',
            bold: true),
        cell(cw['qty']!, isEnglish ? 'Qty' : 'จำนวน',
            bold: true, a: pw.TextAlign.right),
        cell(cw['unitPrice']!, isEnglish ? 'Unit Price' : 'ราคา/หน่วย',
            bold: true, a: pw.TextAlign.right),
        cell(cw['total']!, isEnglish ? 'Total' : 'ราคารวม',
            bold: true, a: pw.TextAlign.right),
      ]),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(mg),
      header: (ctx) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
          pw.Expanded(
              flex: 6,
              child: pw.Text(reportTitle,
                  textAlign: pw.TextAlign.center, style: tB(15))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  isEnglish
                      ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}'
                      : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right,
                  style: tN(10))),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.SizedBox()),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
                  textAlign: pw.TextAlign.right,
                  style: tN(10))),
        ]),
        pw.Row(children: [
          pw.Expanded(flex: 9, child: pw.SizedBox()),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  isEnglish
                      ? 'Printed $printDateStr'
                      : 'พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right,
                  style: tN(10))),
        ]),
        pw.SizedBox(height: 4),
        tableHeader,
      ]),
      build: (ctx) => _reportData.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final days = r.daysOverdue;
        String overdueText;
        PdfColor? overdueColor;
        if (days == null) {
          overdueText = '-';
        } else if (days > 0) {
          overdueText = isEnglish ? 'Overdue $days' : 'เกิน $days วัน';
          overdueColor = PdfColors.red;
        } else if (days == 0) {
          overdueText = isEnglish ? 'Due today' : 'ถึงกำหนดวันนี้';
          overdueColor = PdfColors.orange800;
        } else {
          overdueText = isEnglish ? 'In ${-days}' : 'อีก ${-days} วัน';
        }
        final vendorName = isEnglish && (r.vendorNameEn ?? '').isNotEmpty
            ? r.vendorNameEn!
            : (r.vendorNameTh ?? '');
        final warehouseName = isEnglish && (r.warehouseNameEn ?? '').isNotEmpty
            ? r.warehouseNameEn!
            : (r.warehouseNameTh ?? '');
        return pw.Container(
          decoration: pw.BoxDecoration(
              color: i.isEven
                  ? PdfColors.white
                  : const PdfColor(0.98, 0.98, 0.98)),
          child: pw.Row(children: [
            cell(cw['dueDate']!,
                r.dueDate != null ? _dateFmt.format(r.dueDate!) : '-'),
            cell(cw['overdue']!, overdueText,
                a: pw.TextAlign.right,
                color: overdueColor,
                bold: overdueColor != null),
            cell(cw['poNo']!, r.poDocNo),
            cell(cw['poDate']!,
                r.poDocDate != null ? _dateFmt.format(r.poDocDate!) : '-'),
            cell(cw['item']!, '${r.itemCode ?? ''} ${r.itemName ?? ''}'),
            cell(cw['vendor']!, '${r.vendorCode ?? ''} $vendorName'),
            cell(cw['warehouse']!, '${r.warehouseCode ?? ''} $warehouseName'),
            cell(cw['qty']!, _fmtQty.format(r.qtyOutstanding),
                a: pw.TextAlign.right),
            cell(cw['unitPrice']!, _fmtValue.format(r.unitPriceFc),
                a: pw.TextAlign.right),
            cell(cw['total']!, _fmtValue.format(r.totalAmountLc),
                a: pw.TextAlign.right, bold: true),
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
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ??
            (isEnglish
                ? 'Pending Receipt Report'
                : 'รายงานจัดซื้อสินค้าค้างรับ'));

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth =
            (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              color: Colors.teal[800],
              child: IconButton(
                icon: Icon(
                    _isFilterExpanded
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    color: Colors.white,
                    size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded
                    ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                    : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                onPressed: () =>
                    setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            AnimatedContainer(
              duration: _isDraggingDivider
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
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
                              Text(
                                  isEnglish
                                      ? 'Report Conditions'
                                      : 'เงื่อนไขรายงาน',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 16),
                              Text(isEnglish ? 'Order Date' : 'วันที่สั่งซื้อ',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Expanded(
                                    child: _dateField(
                                        isEnglish ? 'From' : 'ตั้งแต่',
                                        _poDateFrom,
                                        (d) =>
                                            setState(() => _poDateFrom = d))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _dateField(
                                        isEnglish ? 'To' : 'ถึง',
                                        _poDateTo,
                                        (d) => setState(() => _poDateTo = d))),
                              ]),
                              const SizedBox(height: 12),
                              Text(isEnglish ? 'Due Date' : 'วันที่ครบกำหนด',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Expanded(
                                    child: _dateField(
                                        isEnglish ? 'From' : 'ตั้งแต่',
                                        _dueDateFrom,
                                        (d) =>
                                            setState(() => _dueDateFrom = d))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _dateField(
                                        isEnglish ? 'To' : 'ถึง',
                                        _dueDateTo,
                                        (d) => setState(() => _dueDateTo = d))),
                              ]),
                              const SizedBox(height: 12),
                              SearchMultiPicker<ApVendor>(
                                items: _vendors,
                                selectedIds: _selectedVendorIds,
                                idOf: (v) => v.id!,
                                labelOf: (v, en) =>
                                    '${v.vendorCode}  ${en && (v.vendorNameEn ?? '').isNotEmpty ? v.vendorNameEn! : v.vendorNameTh}',
                                searchTextOf: (v) =>
                                    '${v.vendorCode} ${v.vendorNameTh} ${v.vendorNameEn ?? ''}',
                                onChanged: (v) =>
                                    setState(() => _selectedVendorIds = v),
                                labelTh: 'ผู้ขาย',
                                labelEn: 'Vendor',
                                allLabelTh: '— ทุกผู้ขาย —',
                                allLabelEn: '— All vendors —',
                              ),
                              const SizedBox(height: 12),
                              SearchMultiPicker<ImItem>(
                                items: _items,
                                selectedIds: _selectedItemIds,
                                idOf: (i) => i.id!,
                                labelOf: (i, en) =>
                                    '${i.itemCode}  ${en && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn! : i.itemNameTh}',
                                searchTextOf: (i) =>
                                    '${i.itemCode} ${i.itemNameTh} ${i.itemNameEn ?? ''}',
                                onChanged: (v) =>
                                    setState(() => _selectedItemIds = v),
                                labelTh: 'สินค้า',
                                labelEn: 'Item',
                                allLabelTh: '— ทุกสินค้า —',
                                allLabelEn: '— All items —',
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<bool>(
                                value: _sortDueDateAsc,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: isEnglish
                                      ? 'Sort by Due Date'
                                      : 'จัดเรียงวันที่ครบกำหนด',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: [
                                  DropdownMenuItem(
                                      value: true,
                                      child: Text(isEnglish
                                          ? 'Nearest → Farthest'
                                          : 'ใกล้สุด → ไกลสุด')),
                                  DropdownMenuItem(
                                      value: false,
                                      child: Text(isEnglish
                                          ? 'Farthest → Nearest'
                                          : 'ไกลสุด → ใกล้สุด')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _sortDueDateAsc = v ?? true),
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
                            label: Text(isEnglish
                                ? 'Generate Report'
                                : 'ประมวลผลรายงาน'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[800],
                                foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _generate,
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
                  onHorizontalDragStart: (_) =>
                      setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _filterPanelWidth = (_filterPanelWidth + d.delta.dx)
                        .clamp(200.0, maxFilterWidth);
                  }),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _isDraggingDivider = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            Expanded(
              child: Column(children: [
                if (_reportData.isNotEmpty)
                  Container(
                    color: Colors.grey[100],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(children: [
                      Icon(Icons.zoom_out, size: 18, color: Colors.grey[700]),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: SizedBox(
                            height: 24,
                            child: Slider(
                              value: _zoom,
                              min: 0.5,
                              max: 2.5,
                              divisions: 20,
                              label: '${(_zoom * 100).round()}%',
                              onChanged: _setZoom,
                            ),
                          ),
                        ),
                      ),
                      Icon(Icons.zoom_in, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 48,
                          child: Text('${(_zoom * 100).round()}%',
                              style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
                Expanded(
                  child: Container(
                    color: Colors.grey[200],
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _reportData.isEmpty
                            ? Center(
                                child: Text(_hasGenerated
                                    ? (isEnglish
                                        ? 'No data found for the selected conditions'
                                        : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก')
                                    : (isEnglish
                                        ? 'Please select conditions and click Generate'
                                        : 'กรุณาเลือกเงื่อนไขและกดประมวลผล')))
                            : ClipRect(
                                child: Transform.scale(
                                  scale: _zoom,
                                  alignment: Alignment.topCenter,
                                  child: PdfPreview(
                                    key: ValueKey(_pdfKey),
                                    build: (fmt) => _generatePdf(fmt),
                                    initialPageFormat:
                                        PdfPageFormat.a4.landscape,
                                    canChangeOrientation: false,
                                    canDebug: false,
                                    allowPrinting: canPrint,
                                    allowSharing: canPrint,
                                  ),
                                ),
                              ),
                  ),
                ),
              ]),
            ),
          ],
        );
      }),
    );
  }

  Widget _dateField(
      String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null)
            InkWell(
              onTap: () => onPicked(null),
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.clear, size: 14, color: Colors.grey)),
            ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100));
              if (picked != null) onPicked(picked);
            },
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.calendar_today, size: 14)),
          ),
        ]),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (picked != null) onPicked(picked);
        },
        child: Text(
            value != null
                ? _dateFmt.format(value)
                : (_isEnglish ? '— Any —' : '— ไม่ระบุ —'),
            style: TextStyle(
                fontSize: 13,
                color: value != null ? Colors.black87 : Colors.black38)),
      ),
    );
  }
}
