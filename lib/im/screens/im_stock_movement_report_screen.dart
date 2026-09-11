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
import '../services/im_item_service.dart';
import '../services/im_item_category_service.dart';
import '../services/im_warehouse_service.dart';
import '../services/im_stock_movement_report_service.dart';
import '../../utils/file_download.dart';

// รายงานสินค้าคงเหลือและการเคลื่อนไหว — 1 "การ์ด" ต่อ (คลัง, สินค้า) จัดกลุ่ม คลัง > หมวดหมู่ > สินค้า
// (backend ORDER BY มาให้ถูกต้องแล้ว เดินลิสต์ตามลำดับที่ได้รับมาเป็น linear pass เดียว ห้าม re-sort/regroup)
// ยอดยกมา (opening) คำนวณจาก server เสมอ (ไม่ใช่ 0) รวมถึงสินค้าที่มียอดยกมาแต่ไม่มีการเคลื่อนไหวในช่วงที่เลือก
// ก็ยังต้องแสดง (txn_id เป็น null แถวเดียวในกลุ่มนั้น)
//
// การจับกลุ่มคอลัมน์ รับ/จ่าย/เบิก/โอน/ปรับ — verify กับข้อมูลจริงแล้ว (ดู project memory
// pattern_im_stock_movement_report): รับ=สต็อกเพิ่ม(GRN/GRB/GRP/DNS/RTC/CNC), จ่าย=สต็อกลด
// (DLN/DLB/DLP/CNS/DNC/RTS), เบิก=ISS, โอน=TRF (สองทิศทางตามคลังต้นทาง/ปลายทาง), ปรับ=AJS
// รับ/จ่าย/เบิก มีทิศทางคงที่เสมอ (sign ไม่เปลี่ยน) จึงแสดงแบบ absolute value ใต้คอลัมน์นั้นได้เลย ส่วน
// โอน/ปรับ มีได้ทั้งสองทิศทางแม้ในการ์ดเดียวกัน จึงต้องคงเครื่องหมาย +/- ไว้

class ImStockMovementReportScreen extends StatefulWidget {
  const ImStockMovementReportScreen({super.key});

  @override
  State<ImStockMovementReportScreen> createState() => _ImStockMovementReportScreenState();
}

class _ImStockMovementReportScreenState extends State<ImStockMovementReportScreen> {
  final _reportService  = ImStockMovementReportService();
  final _companyService = CompanyService();
  final _authService    = AuthService();
  final _warehouseSvc   = ImWarehouseService();
  final _categorySvc    = ImItemCategoryService();

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

  List<ImWarehouse> _warehouses = [];
  List<ImItemCategory> _categories = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<int> _selectedWarehouseIds = [];
  List<int> _selectedCategoryIds  = [];
  String? _itemCodeFrom;
  String? _itemCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';
  bool _showMovement = true; // true=แสดงการเคลื่อนไหว, false=แสดงเฉพาะยอดรวม
  bool _showValue    = true; // true=แสดงมูลค่า(default), false=แสดงจำนวน
  bool _newPagePerItem = false; // true=ขึ้นหน้าใหม่ทุกสินค้า, false=แสดงต่อเนื่อง(default)

  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    _headers = await _authService.getAuthHeader();
    final results = await Future.wait([
      _companyService.fetchCompany(),
      _warehouseSvc.fetchActiveRows(),
      _categorySvc.fetchActiveRows(),
    ]);
    _company = results[0] as Company?;
    _warehouses = results[1] as List<ImWarehouse>;
    _categories = (results[2] as List<ImItemCategory>).where((c) => c.categoryType == 'CATEGORY').toList();
    if (mounted) setState(() {});
  }

  // ─── report ───────────────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final raw = await _reportService.getReport(
        dateFrom:     DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:       DateFormat('yyyy-MM-dd').format(_dateTo),
        warehouseIds: _selectedWarehouseIds,
        categoryIds:  _selectedCategoryIds,
        itemCodeFrom: _selectedCategoryIds.isEmpty ? _itemCodeFrom : null,
        itemCodeTo:   _selectedCategoryIds.isEmpty ? _itemCodeTo : null,
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

  String _warehouseName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['warehouse_name_en'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (r['warehouse_name_th'] as String? ?? '');
  }

  String _categoryLabel(Map<String, dynamic> r, bool isEnglish) {
    final code = r['category_code'] as String?;
    if ((code ?? '').isEmpty) return isEnglish ? '(No category)' : '(ไม่ระบุหมวดหมู่)';
    return '$code  ${_categoryNameOnly(r, isEnglish)}';
  }

  // ชื่อหมวดหมู่ล้วนๆ (ไม่มีรหัสนำหน้า) — ใช้กับหัวการ์ดที่ต้องแสดงรหัสและชื่อคนละบรรทัด (มิเรอร์ _warehouseName/
  // _itemName ที่คืนแค่ชื่อเช่นกัน)
  String _categoryNameOnly(Map<String, dynamic> r, bool isEnglish) {
    final code = r['category_code'] as String?;
    if ((code ?? '').isEmpty) return isEnglish ? '(No category)' : '(ไม่ระบุหมวดหมู่)';
    final en = r['category_name_en'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (r['category_name_th'] as String? ?? '');
  }

  String _itemName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['item_name_en'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (r['item_name_th'] as String? ?? '');
  }

  String _uomName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['uom_name_en'] as String?;
    final th = r['uom_name_th'] as String?;
    if (isEnglish && (en ?? '').isNotEmpty) return en!;
    if ((th ?? '').isNotEmpty) return th!;
    return r['uom_code']?.toString() ?? '';
  }

  String _docTypeName(Map<String, dynamic> r, bool isEnglish) {
    final en = r['doc_name_eng'] as String?;
    return isEnglish && (en ?? '').isNotEmpty ? en! : (r['doc_name_thai'] as String? ?? '');
  }

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy').format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  // จำนวนหรือมูลค่าของแถว ตามสวิตช์ที่เลือก
  num _rowAmount(Map<String, dynamic> r) => _showValue ? _num(r['total_value_lc']) : _num(r['qty']);
  num _openingAmount(Map<String, dynamic> r) => _showValue ? _num(r['opening_value']) : _num(r['opening_qty']);
  num _runningAmount(Map<String, dynamic> r) => _showValue ? _num(r['running_value']) : _num(r['running_qty']);

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    final showMovement = _showMovement;
    final showValue = _showValue;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font       = pw.Font.ttf(fontData);
    final fontBold   = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final dateRangeLine = '${isEnglish ? "Date range" : "ช่วงวันที่"} ${DateFormat('dd/MM/yyyy').format(_dateFrom)}'
        ' – ${DateFormat('dd/MM/yyyy').format(_dateTo)}';

    final conditions = <String>[
      showValue ? (isEnglish ? 'Showing value' : 'แสดงมูลค่า') : (isEnglish ? 'Showing quantity' : 'แสดงจำนวน'),
      showMovement ? (isEnglish ? 'Showing movement detail' : 'แสดงรายละเอียดการเคลื่อนไหว') : (isEnglish ? 'Summary only' : 'แสดงเฉพาะยอดรวม'),
    ];
    final conditionLine = conditions.join(' | ');

    const mg = 20.0;
    final pageW = format.width - mg * 2;

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cHeaderBg = PdfColor(0.93, 0.93, 0.97);
    const cTotalBg  = PdfColor(0.80, 0.93, 0.88);
    final fmt = NumberFormat('#,##0.00', 'en_US');

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
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.Text(dateRangeLine, textAlign: pw.TextAlign.center, style: tN(10))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.Text('* $conditionLine', style: tN(9))),
        pw.Expanded(flex: 3, child: pw.Text(isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 6),
    ]);

    // ─── ตารางการเคลื่อนไหว 10 คอลัมน์ (เพิ่มคอลัมน์ Lot/Serial ถัดจากเลขที่เอกสาร) ─────────────────────
    // balance คงความกว้างเดิมไว้ (ต้องตรงกับ hcw ยอดยกมาของหัวการ์ดเป๊ะ — ดูหมายเหตุที่ cardHeaderRow ด้านล่าง)
    final mw = {
      'date':   pageW * 0.08,
      'type':   pageW * 0.12,
      'docNo':  pageW * 0.10,
      'lotSerial': pageW * 0.09,
      'receive':pageW * 0.105,
      'issue':  pageW * 0.105,
      'withdraw':pageW * 0.105,
      'transfer':pageW * 0.105,
      'adjust': pageW * 0.10,
      'balance':pageW * 0.09,
    };
    const bucketOrder = ['receive', 'issue', 'withdraw', 'transfer', 'adjust'];
    // จ่าย/เบิก แสดงเครื่องหมายลบเสมอ (ให้เห็นชัดว่าเป็นยอดหักจากยอดสะสม) — รับ ทิศทางคงที่เป็นบวกเสมอจึงยังคง
    // แสดงแบบ absolute value ได้ ส่วนโอน/ปรับ มีได้ทั้งสองทิศทางแม้ในการ์ดเดียวกัน จึงต้องคงเครื่องหมาย +/- ไว้
    const signedBuckets = {'issue', 'withdraw', 'transfer', 'adjust'};

    pw.Widget mCell(double w, String t, {bool bold = false, pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
            child: pw.Text(t, style: bold ? tB(8.5) : tN(8.5), textAlign: a),
          ),
        );

    // showDocCols=false (โหมดแสดงเฉพาะยอดรวม) — เว้นว่างหัวคอลัมน์วันที่เอกสาร/ประเภทเอกสาร/เลขที่เอกสาร/Lot-Serial
    // แต่ยังกินพื้นที่คอลัมน์ไว้เหมือนเดิม เพื่อให้บรรทัดยอดรวมด้านล่างยังตรงคอลัมน์กัน — lotSerialLabel มาจาก
    // costing_method/is_lot_tracked/is_serial_tracked ของสินค้าแต่ละการ์ด (ดู flushItem) จึงส่งมาเฉพาะตอน
    // showDocCols=true เท่านั้น
    pw.Widget movementHeaderRow({required bool showDocCols, String lotSerialLabel = ''}) => pw.Container(
          color: cGreen,
          child: pw.Row(children: [
            mCell(mw['date']!,   showDocCols ? (isEnglish ? 'Date' : 'วันที่เอกสาร') : '', bold: true),
            mCell(mw['type']!,   showDocCols ? (isEnglish ? 'Doc Type' : 'ประเภทเอกสาร') : '', bold: true),
            mCell(mw['docNo']!,  showDocCols ? (isEnglish ? 'Doc No.' : 'เลขที่เอกสาร') : '', bold: true),
            mCell(mw['lotSerial']!, showDocCols ? lotSerialLabel : '', bold: true),
            mCell(mw['receive']!, isEnglish ? 'Receive' : 'รับ', bold: true, a: pw.TextAlign.right),
            mCell(mw['issue']!,   isEnglish ? 'Issue' : 'จ่าย', bold: true, a: pw.TextAlign.right),
            mCell(mw['withdraw']!,isEnglish ? 'Withdraw' : 'เบิก', bold: true, a: pw.TextAlign.right),
            mCell(mw['transfer']!,isEnglish ? 'Transfer' : 'โอน', bold: true, a: pw.TextAlign.right),
            mCell(mw['adjust']!,  isEnglish ? 'Adjust' : 'ปรับ', bold: true, a: pw.TextAlign.right),
            mCell(mw['balance']!, isEnglish ? 'Balance' : 'ยอดสะสม', bold: true, a: pw.TextAlign.right),
          ]),
        );

    String bucketCellText(String col, Map<String, dynamic> row) {
      if (row['bucket'] != col) return '';
      final v = _rowAmount(row);
      final display = signedBuckets.contains(col) ? v : v.abs();
      return fmt.format(display);
    }

    pw.Widget movementDataRow(Map<String, dynamic> row, {String lotSerialText = ''}) => pw.Row(children: [
          mCell(mw['date']!,  _fmtDate(row['doc_date'] as String?)),
          mCell(mw['type']!,  '${row['doc_code'] ?? ''}  ${_docTypeName(row, isEnglish)}'),
          mCell(mw['docNo']!, row['doc_no'] as String? ?? ''),
          mCell(mw['lotSerial']!, lotSerialText),
          for (final b in bucketOrder) mCell(mw[b == 'withdraw' ? 'withdraw' : b]!, bucketCellText(b, row), a: pw.TextAlign.right),
          mCell(mw['balance']!, fmt.format(_runningAmount(row)), bold: true, a: pw.TextAlign.right),
        ]);

    pw.Widget totalsRow(String label, Map<String, num> bucketTotals, num closing, {double indent = 0}) => pw.Row(children: [
          pw.SizedBox(
            width: mw['date']! + mw['type']! + mw['docNo']! + mw['lotSerial']!,
            child: pw.Padding(
              padding: pw.EdgeInsets.only(left: 3 + indent, right: 3, top: 2.5, bottom: 2.5),
              child: pw.Text(label, style: tB(8.5)),
            ),
          ),
          for (final b in bucketOrder)
            mCell(mw[b]!, fmt.format(signedBuckets.contains(b) ? bucketTotals[b]! : bucketTotals[b]!.abs()), bold: true, a: pw.TextAlign.right),
          mCell(mw['balance']!, fmt.format(closing), bold: true, a: pw.TextAlign.right),
        ]);

    Map<String, num> emptyBuckets() => {for (final b in bucketOrder) b: 0.0};

    // ─── หัวการ์ด (Requirement 1) — คอลัมน์ คลัง/หมวดหมู่/สินค้า/วิธีคิดต้นทุน/หน่วย/ยอดยกมา — คอลัมน์
    // ยอดยกมา ต้องกว้างและชิดขวาตรงกับคอลัมน์ "ยอดสะสม" ของตารางเคลื่อนไหวด้านล่างเป๊ะ จึงใช้ mw['balance']
    // เป็นความกว้างเดียวกัน ส่วน 5 คอลัมน์ที่เหลือแบ่งพื้นที่ที่เหลือกันเอง (ไม่ต้องตรงกับคอลัมน์อื่นด้านล่าง)
    final hcw = {
      'warehouse': pageW * 0.14,
      'category':  pageW * 0.20,
      'item':      pageW * 0.30,
      'costing':   pageW * 0.17,
      'unit':      pageW * 0.10,
    };

    // เว้นวรรค/บรรทัดว่างล้วน — pw.Text ใน package:pdf ยุบ height เป็น 0 เมื่อเนื้อหาเป็น whitespace ล้วน (ต่างจาก
    // Flutter's Text ที่ยังกิน line-height ปกติ) จึงต้องแทนที่ด้วย Opacity(opacity:0) ครอบตัวอักษรจริง เพื่อให้
    // ได้ line-height เท่าบรรทัดข้อความปกติแต่มองไม่เห็น — verify แล้วด้วย pw.Page ทดสอบจริง
    pw.Widget headerCell(double w, String label, List<String> lines, {pw.TextAlign a = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Column(
              crossAxisAlignment: a == pw.TextAlign.right ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: tB(8.5)),
                for (final line in lines)
                  line.trim().isEmpty
                      ? pw.Opacity(opacity: 0, child: pw.Text('X', style: tN(8.5), textAlign: a))
                      : pw.Text(line, style: tN(8.5), textAlign: a),
              ],
            ),
          ),
        );

    pw.Widget cardHeaderRow({
      required String warehouseCode, required String warehouseName,
      required String categoryCode, required String categoryName,
      required String itemCode, required String itemName,
      required String costingLabel, required String uomCode, required String uomName,
      required num opening,
    }) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 6, bottom: 2),
          decoration: pw.BoxDecoration(color: cHeaderBg, borderRadius: pw.BorderRadius.circular(2)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            headerCell(hcw['warehouse']!, isEnglish ? 'Warehouse' : 'คลัง', [warehouseCode, warehouseName]),
            headerCell(hcw['category']!,  isEnglish ? 'Category'  : 'หมวดหมู่', [categoryCode, categoryName]),
            headerCell(hcw['item']!,      isEnglish ? 'Item'      : 'สินค้า', [itemCode, itemName]),
            // เว้นบรรทัดแรกว่าง (สลับกับ warehouse/category/item ที่มีรหัสอยู่บรรทัดแรก) เพื่อให้ค่าจริงลง
            // มาอยู่บรรทัดเดียวกับชื่อสินค้า (บรรทัดที่ 2) ตามที่ผู้ใช้ต้องการ — headerCell แปลงบรรทัดว่างเป็น
            // spacer ที่มองไม่เห็นแต่กิน line-height จริงให้อัตโนมัติ (ดูหมายเหตุใน headerCell ด้านบน)
            headerCell(hcw['costing']!,   isEnglish ? 'Costing Method' : 'วิธีคิดต้นทุน', ['', costingLabel]),
            headerCell(hcw['unit']!,      isEnglish ? 'Unit'      : 'หน่วย', [uomCode, uomName]),
            headerCell(mw['balance']!,    isEnglish ? 'Opening Balance' : 'ยอดยกมา', ['', fmt.format(opening)], a: pw.TextAlign.right),
          ]),
        );

    // ─── การ์ดต่อ (คลัง, สินค้า) — เดินแบบ linear pass เดียวตามลำดับที่ backend ส่งมา (ห้าม re-sort) ──────
    // ระดับ item -> category -> warehouse ตรวจการเปลี่ยนกลุ่มพร้อมกันในรอบเดียว แล้วสะสมยอดขึ้นชั้นบนเป็นทอดๆ
    final content = <pw.Widget>[];
    bool isFirstBlock = true;
    void maybeNewPage() {
      if (_newPagePerItem && !isFirstBlock) content.add(pw.NewPage());
      isFirstBlock = false;
    }

    String? curItemKey, curCatKey, curWhKey;
    List<Map<String, dynamic>> curItemRows = [];
    Map<String, num> catBucketTotals = emptyBuckets();
    num catClosingSum = 0;
    Map<String, num> whBucketTotals = emptyBuckets();
    num whClosingSum = 0;
    Map<String, dynamic>? lastCatFirstRow, lastWhFirstRow;

    // สรุปยอดท้ายรายงาน (ไม่ reset ตลอดการเดินลิสต์ ต่างจาก catBucketTotals/whBucketTotals ด้านบนที่ reset
    // ทุกครั้งที่ข้ามกลุ่ม) — key ด้วย category_id/warehouse_id ล้วนๆ (ข้ามคลัง/ข้ามหมวดหมู่) เพื่อสรุปยอดรวม
    // ตามเงื่อนไขคลัง+หมวดหมู่ที่เลือกทั้งหมด ไม่ใช่แค่ภายในกลุ่มที่กำลังแสดงอยู่
    final finalCatTotals = <String, Map<String, num>>{};
    final finalCatClosing = <String, num>{};
    final finalCatRow = <String, Map<String, dynamic>>{};
    final finalWhTotals = <String, Map<String, num>>{};
    final finalWhClosing = <String, num>{};
    final finalWhRow = <String, Map<String, dynamic>>{};
    // ผลรวมย่อยระดับ (หมวดหมู่, คลัง) คู่ — ใช้แสดง drill-down ใต้ทั้งสองหัวข้อสรุปด้านบน (คีย์เดียวกัน มองจาก
    // สองมุมตอน render: จัดกลุ่มตามหมวดหมู่แล้วไล่คลังย่อย / จัดกลุ่มตามคลังแล้วไล่หมวดหมู่ย่อย)
    final finalCatWhTotals = <String, Map<String, num>>{};
    final finalCatWhClosing = <String, num>{};
    final finalCatWhRow = <String, Map<String, dynamic>>{};
    final grandBucketTotals = emptyBuckets();
    num grandClosing = 0;

    void flushItem() {
      if (curItemRows.isEmpty) return;
      final first = curItemRows.first;
      final txnRows = curItemRows.where((r) => r['txn_id'] != null).toList();
      final opening = _openingAmount(first);
      final costingLabel = imCostingMethodLabel(first['costing_method'] as String? ?? 'AVG', isEnglish);
      // Lot/Serial — SPECIFIC (บังคับ serial ตาม project rule) หรือ is_serial_tracked มาก่อน is_lot_tracked
      // เพราะสินค้าจะติดตามได้ทีละแบบเท่านั้นในทางปฏิบัติ (serial ละเอียดกว่า lot)
      final isSerialItem = first['costing_method'] == 'SPECIFIC' || first['is_serial_tracked'] == true;
      final isLotItem = !isSerialItem && first['is_lot_tracked'] == true;
      final lotSerialLabel = isSerialItem
          ? (isEnglish ? 'Serial#' : 'ซีเรียล')
          : (isLotItem ? (isEnglish ? 'Lot#' : 'ล็อต') : '');
      String lotSerialText(Map<String, dynamic> row) {
        if (isSerialItem) return row['serial_no']?.toString() ?? '';
        if (isLotItem) return row['lot_no']?.toString() ?? '';
        return '';
      }

      maybeNewPage();
      content.add(cardHeaderRow(
        warehouseCode: first['warehouse_code'] as String? ?? '',
        warehouseName: _warehouseName(first, isEnglish),
        categoryCode: (first['category_code'] as String?) ?? '',
        categoryName: _categoryNameOnly(first, isEnglish),
        itemCode: first['item_code'] as String? ?? '',
        itemName: _itemName(first, isEnglish),
        costingLabel: costingLabel,
        uomCode: first['uom_code']?.toString() ?? '',
        uomName: _uomName(first, isEnglish),
        opening: opening,
      ));
      content.add(movementHeaderRow(showDocCols: showMovement, lotSerialLabel: lotSerialLabel));

      num closing = opening;
      final bucketTotals = emptyBuckets();
      if (showMovement) {
        for (final row in txnRows) {
          content.add(movementDataRow(row, lotSerialText: lotSerialText(row)));
          final v = _rowAmount(row);
          final b = row['bucket'] as String?;
          if (b != null && bucketTotals.containsKey(b)) bucketTotals[b] = bucketTotals[b]! + v;
          closing = _runningAmount(row);
        }
      } else {
        for (final row in txnRows) {
          final v = _rowAmount(row);
          final b = row['bucket'] as String?;
          if (b != null && bucketTotals.containsKey(b)) bucketTotals[b] = bucketTotals[b]! + v;
          closing = _runningAmount(row);
        }
      }
      content.add(pw.Container(color: cTotalBg, child: totalsRow(isEnglish ? 'Total' : 'รวม', bucketTotals, closing)));

      final catKeyGlobal = '${first['category_id']}';
      final whKeyGlobal  = '${first['warehouse_id']}';
      final catWhKey = '$catKeyGlobal|$whKeyGlobal';
      finalCatTotals.putIfAbsent(catKeyGlobal, emptyBuckets);
      finalCatRow.putIfAbsent(catKeyGlobal, () => first);
      finalWhTotals.putIfAbsent(whKeyGlobal, emptyBuckets);
      finalWhRow.putIfAbsent(whKeyGlobal, () => first);
      finalCatWhTotals.putIfAbsent(catWhKey, emptyBuckets);
      finalCatWhRow.putIfAbsent(catWhKey, () => first);
      for (final b in bucketOrder) {
        catBucketTotals[b] = catBucketTotals[b]! + bucketTotals[b]!;
        whBucketTotals[b] = whBucketTotals[b]! + bucketTotals[b]!;
        finalCatTotals[catKeyGlobal]![b] = finalCatTotals[catKeyGlobal]![b]! + bucketTotals[b]!;
        finalWhTotals[whKeyGlobal]![b] = finalWhTotals[whKeyGlobal]![b]! + bucketTotals[b]!;
        finalCatWhTotals[catWhKey]![b] = finalCatWhTotals[catWhKey]![b]! + bucketTotals[b]!;
        grandBucketTotals[b] = grandBucketTotals[b]! + bucketTotals[b]!;
      }
      catClosingSum += closing;
      whClosingSum += closing;
      finalCatClosing[catKeyGlobal] = (finalCatClosing[catKeyGlobal] ?? 0) + closing;
      finalWhClosing[whKeyGlobal] = (finalWhClosing[whKeyGlobal] ?? 0) + closing;
      finalCatWhClosing[catWhKey] = (finalCatWhClosing[catWhKey] ?? 0) + closing;
      grandClosing += closing;
    }

    void flushCategory() {
      final r = lastCatFirstRow;
      if (r == null) return;
      if (showValue) {
        maybeNewPage();
        content.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 2, bottom: 2),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: cTotalBg,
          child: pw.Text(
              '${isEnglish ? "Category Total" : "รวมหมวดหมู่"}: ${_categoryLabel(r, isEnglish)}  '
              '(${isEnglish ? "Warehouse" : "คลัง"} ${r['warehouse_code'] ?? ''} ${_warehouseName(r, isEnglish)})',
              style: tB(9.5)),
        ));
        content.add(movementHeaderRow(showDocCols: false));
        content.add(totalsRow(isEnglish ? 'Total' : 'รวม', catBucketTotals, catClosingSum));
      }
      catBucketTotals = emptyBuckets();
      catClosingSum = 0;
    }

    void flushWarehouse() {
      final r = lastWhFirstRow;
      if (r == null) return;
      if (showValue) {
        maybeNewPage();
        content.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 2, bottom: 2),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: cTotalBg,
          child: pw.Text('${isEnglish ? "Warehouse Total" : "รวมคลัง"}: ${r['warehouse_code'] ?? ''}  ${_warehouseName(r, isEnglish)}', style: tB(10)),
        ));
        content.add(movementHeaderRow(showDocCols: false));
        content.add(totalsRow(isEnglish ? 'Total' : 'รวม', whBucketTotals, whClosingSum));
      }
      whBucketTotals = emptyBuckets();
      whClosingSum = 0;
    }

    for (final r in _reportData) {
      final itemKey = '${r['warehouse_id']}_${r['item_id']}';
      final catKey  = '${r['warehouse_id']}_${r['category_id']}';
      final whKey   = '${r['warehouse_id']}';

      if (curItemKey != null && itemKey != curItemKey) {
        flushItem();
        curItemRows = [];
      }
      if (curCatKey != null && catKey != curCatKey) {
        flushCategory();
      }
      if (curWhKey != null && whKey != curWhKey) {
        flushWarehouse();
      }

      curItemKey = itemKey;
      if (catKey != curCatKey) lastCatFirstRow = r;
      curCatKey = catKey;
      if (whKey != curWhKey) lastWhFirstRow = r;
      curWhKey = whKey;
      curItemRows.add(r);
    }
    flushItem();
    flushCategory();
    flushWarehouse();

    // ─── สรุปยอดท้ายรายงาน (หน้าสุดท้าย) — ตามหมวดหมู่ / ตามคลัง / ยอดรวมทั้งหมด ตามเงื่อนไขที่เลือก ──────
    // มีความหมายเฉพาะตอนแสดงมูลค่า (ผลรวมจำนวนของสินค้าต่างหน่วยกันข้ามหมวดหมู่/คลังไม่มีความหมาย)
    if (showValue && finalCatTotals.isNotEmpty) {
      content.add(pw.NewPage());
      content.add(pw.Text(isEnglish ? 'Summary' : 'สรุปยอดรวม', style: tB(13)));
      content.add(pw.SizedBox(height: 8));

      content.add(pw.Text(isEnglish ? 'Summary by Category' : 'สรุปยอดตามหมวดหมู่', style: tB(10)));
      content.add(movementHeaderRow(showDocCols: false));
      final catKeys = finalCatTotals.keys.toList()
        ..sort((a, b) => (finalCatRow[a]!['category_code'] as String? ?? '').compareTo(finalCatRow[b]!['category_code'] as String? ?? ''));
      for (final k in catKeys) {
        content.add(totalsRow(_categoryLabel(finalCatRow[k]!, isEnglish), finalCatTotals[k]!, finalCatClosing[k]!));
        // drill-down: คลังใดบ้างที่หมวดหมู่นี้มีอยู่ — ชื่อคลังเยื้องขวา
        final subKeys = finalCatWhTotals.keys.where((ck) => ck.startsWith('$k|')).toList()
          ..sort((a, b) => (finalCatWhRow[a]!['warehouse_code'] as String? ?? '').compareTo(finalCatWhRow[b]!['warehouse_code'] as String? ?? ''));
        for (final sk in subKeys) {
          final r = finalCatWhRow[sk]!;
          content.add(totalsRow('${r['warehouse_code'] ?? ''}  ${_warehouseName(r, isEnglish)}', finalCatWhTotals[sk]!, finalCatWhClosing[sk]!, indent: 16));
        }
      }
      content.add(pw.Container(
          color: cTotalBg,
          child: totalsRow(isEnglish ? 'Total - All Categories' : 'ยอดรวมทุกหมวดหมู่', grandBucketTotals, grandClosing)));
      content.add(pw.SizedBox(height: 14));

      content.add(pw.Text(isEnglish ? 'Summary by Warehouse' : 'สรุปยอดตามคลัง', style: tB(10)));
      content.add(movementHeaderRow(showDocCols: false));
      final whKeys = finalWhTotals.keys.toList()
        ..sort((a, b) => (finalWhRow[a]!['warehouse_code'] as String? ?? '').compareTo(finalWhRow[b]!['warehouse_code'] as String? ?? ''));
      for (final k in whKeys) {
        final r = finalWhRow[k]!;
        content.add(totalsRow('${r['warehouse_code'] ?? ''}  ${_warehouseName(r, isEnglish)}', finalWhTotals[k]!, finalWhClosing[k]!));
        // drill-down: หมวดหมู่ใดบ้างที่คลังนี้มีอยู่ — ชื่อหมวดหมู่เยื้องขวา
        final subKeys = finalCatWhTotals.keys.where((ck) => ck.endsWith('|$k')).toList()
          ..sort((a, b) => (finalCatWhRow[a]!['category_code'] as String? ?? '').compareTo(finalCatWhRow[b]!['category_code'] as String? ?? ''));
        for (final sk in subKeys) {
          content.add(totalsRow(_categoryLabel(finalCatWhRow[sk]!, isEnglish), finalCatWhTotals[sk]!, finalCatWhClosing[sk]!, indent: 16));
        }
      }
      content.add(pw.Container(
          color: cTotalBg,
          child: totalsRow(isEnglish ? 'Total - All Warehouses' : 'ยอดรวมทุกคลัง', grandBucketTotals, grandClosing)));
      content.add(pw.SizedBox(height: 14));

      content.add(movementHeaderRow(showDocCols: false));
      content.add(pw.Container(
          color: cTotalBg,
          child: totalsRow(isEnglish ? 'Grand Total' : 'ยอดรวมทั้งหมด', grandBucketTotals, grandClosing)));
    }

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
    final showMovement = _showMovement;
    final showValue = _showValue;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      const sheet = 'StockMovement';
      ex.rename('Sheet1', sheet);
      final s = ex[sheet];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final groupBg = ExcelColor.fromHexString('#EDEDF7');
      final totBg = ExcelColor.fromHexString('#CCE9DE');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0,
          '${isEnglish ? "Date range" : "ช่วงวันที่"}: ${DateFormat("dd/MM/yyyy").format(_dateFrom)} – ${DateFormat("dd/MM/yyyy").format(_dateTo)}  |  ${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      const bucketOrder = ['receive', 'issue', 'withdraw', 'transfer', 'adjust'];
      // จ่าย/เบิก แสดงเครื่องหมายลบเสมอ (ให้เห็นชัดว่าเป็นยอดหักจากยอดสะสม) — รับ ทิศทางคงที่เป็นบวกเสมอจึงยังคง
      // แสดงแบบ absolute value ได้ ส่วนโอน/ปรับ มีได้ทั้งสองทิศทางแม้ในการ์ดเดียวกัน จึงต้องคงเครื่องหมาย +/- ไว้
      const signedBuckets = {'issue', 'withdraw', 'transfer', 'adjust'};
      Map<String, num> emptyBuckets() => {for (final b in bucketOrder) b: 0.0};

      void writeMovementHeader(int r, {required bool showDocCols, String lotSerialLabel = ''}) {
        final hdrs = isEnglish
            ? [showDocCols ? 'Date' : '', showDocCols ? 'Doc Type' : '', showDocCols ? 'Doc No.' : '', showDocCols ? lotSerialLabel : '', 'Receive', 'Issue', 'Withdraw', 'Transfer', 'Adjust', 'Balance']
            : [showDocCols ? 'วันที่เอกสาร' : '', showDocCols ? 'ประเภทเอกสาร' : '', showDocCols ? 'เลขที่เอกสาร' : '', showDocCols ? lotSerialLabel : '', 'รับ', 'จ่าย', 'เบิก', 'โอน', 'ปรับ', 'ยอดสะสม'];
        for (int i = 0; i < hdrs.length; i++) {
          _xl(s, r, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
        }
      }

      void writeTotalsRow(int r, String label, Map<String, num> bucketTotals, num closing, {ExcelColor? bg}) {
        _xl(s, r, 0, label, bg: bg, bold: true);
        for (int ci = 0; ci < bucketOrder.length; ci++) {
          final bc = bucketOrder[ci];
          final t = bucketTotals[bc]!;
          _xl(s, r, 4 + ci, (signedBuckets.contains(bc) ? t : t.abs()).toDouble(), bg: bg, align: HorizontalAlign.Right, bold: true);
        }
        _xl(s, r, 9, closing.toDouble(), bg: bg, align: HorizontalAlign.Right, bold: true);
      }

      int row = 3;
      String? curItemKey, curCatKey, curWhKey;
      List<Map<String, dynamic>> curItemRows = [];
      Map<String, num> catBucketTotals = emptyBuckets();
      num catClosingSum = 0;
      Map<String, num> whBucketTotals = emptyBuckets();
      num whClosingSum = 0;
      Map<String, dynamic>? lastCatFirstRow, lastWhFirstRow;

      final finalCatTotals = <String, Map<String, num>>{};
      final finalCatClosing = <String, num>{};
      final finalCatRow = <String, Map<String, dynamic>>{};
      final finalWhTotals = <String, Map<String, num>>{};
      final finalWhClosing = <String, num>{};
      final finalWhRow = <String, Map<String, dynamic>>{};
      final finalCatWhTotals = <String, Map<String, num>>{};
      final finalCatWhClosing = <String, num>{};
      final finalCatWhRow = <String, Map<String, dynamic>>{};
      final grandBucketTotals = emptyBuckets();
      num grandClosing = 0;

      void flushItem() {
        if (curItemRows.isEmpty) return;
        final first = curItemRows.first;
        final txnRows = curItemRows.where((r) => r['txn_id'] != null).toList();
        final opening = _openingAmount(first);
        final costingLabel = imCostingMethodLabel(first['costing_method'] as String? ?? 'AVG', isEnglish);
        final isSerialItem = first['costing_method'] == 'SPECIFIC' || first['is_serial_tracked'] == true;
        final isLotItem = !isSerialItem && first['is_lot_tracked'] == true;
        final lotSerialLabel = isSerialItem
            ? (isEnglish ? 'Serial#' : 'ซีเรียล')
            : (isLotItem ? (isEnglish ? 'Lot#' : 'ล็อต') : '');
        String lotSerialText(Map<String, dynamic> r) {
          if (isSerialItem) return r['serial_no']?.toString() ?? '';
          if (isLotItem) return r['lot_no']?.toString() ?? '';
          return '';
        }

        // การ์ดหัว 3 แถว: ป้ายกำกับ / รหัส (+วิธีคิดต้นทุน+ยอดยกมา) / ชื่อ — คอลัมน์ ยอดยกมา อยู่ที่ col 9
        // ตรงกับคอลัมน์ยอดสะสมด้านล่างเป๊ะ (Requirement 1)
        _xl(s, row, 0, isEnglish ? 'Warehouse' : 'คลัง', bg: groupBg, bold: true);
        _xl(s, row, 1, isEnglish ? 'Category' : 'หมวดหมู่', bg: groupBg, bold: true);
        _xl(s, row, 2, isEnglish ? 'Item' : 'สินค้า', bg: groupBg, bold: true);
        _xl(s, row, 3, isEnglish ? 'Costing Method' : 'วิธีคิดต้นทุน', bg: groupBg, bold: true);
        _xl(s, row, 4, isEnglish ? 'Unit' : 'หน่วย', bg: groupBg, bold: true);
        _xl(s, row, 9, isEnglish ? 'Opening Balance' : 'ยอดยกมา', bg: groupBg, bold: true, align: HorizontalAlign.Right);
        row++;
        _xl(s, row, 0, first['warehouse_code'] as String? ?? '');
        _xl(s, row, 1, first['category_code'] as String? ?? '');
        _xl(s, row, 2, first['item_code'] as String? ?? '');
        _xl(s, row, 4, first['uom_code']?.toString() ?? '');
        row++;
        // วิธีคิดต้นทุน/ยอดยกมา ลงมาอยู่แถวเดียวกับชื่อสินค้า (ต่างจาก code cells ด้านบนที่อยู่แถวรหัส)
        _xl(s, row, 0, _warehouseName(first, isEnglish));
        _xl(s, row, 1, _categoryNameOnly(first, isEnglish));
        _xl(s, row, 2, _itemName(first, isEnglish));
        _xl(s, row, 3, costingLabel);
        _xl(s, row, 4, _uomName(first, isEnglish));
        _xl(s, row, 9, opening.toDouble(), align: HorizontalAlign.Right, bold: true);
        row++;

        writeMovementHeader(row, showDocCols: showMovement, lotSerialLabel: lotSerialLabel);
        row++;

        num closing = opening;
        final bucketTotals = emptyBuckets();
        for (final r in txnRows) {
          final v = _rowAmount(r);
          final b = r['bucket'] as String?;
          if (showMovement) {
            _xl(s, row, 0, _fmtDate(r['doc_date'] as String?));
            _xl(s, row, 1, '${r['doc_code'] ?? ''}  ${_docTypeName(r, isEnglish)}');
            _xl(s, row, 2, r['doc_no'] as String? ?? '');
            _xl(s, row, 3, lotSerialText(r));
            for (int ci = 0; ci < bucketOrder.length; ci++) {
              final bc = bucketOrder[ci];
              if (bc == b) {
                final display = signedBuckets.contains(bc) ? v : v.abs();
                _xl(s, row, 4 + ci, display.toDouble(), align: HorizontalAlign.Right);
              }
            }
            _xl(s, row, 9, _runningAmount(r).toDouble(), align: HorizontalAlign.Right);
            row++;
          }
          if (b != null && bucketTotals.containsKey(b)) bucketTotals[b] = bucketTotals[b]! + v;
          closing = _runningAmount(r);
        }
        writeTotalsRow(row, isEnglish ? 'Total' : 'รวม', bucketTotals, closing, bg: totBg);
        row += 2; // + blank separator row

        final catKeyGlobal = '${first['category_id']}';
        final whKeyGlobal  = '${first['warehouse_id']}';
        final catWhKey = '$catKeyGlobal|$whKeyGlobal';
        finalCatTotals.putIfAbsent(catKeyGlobal, emptyBuckets);
        finalCatRow.putIfAbsent(catKeyGlobal, () => first);
        finalWhTotals.putIfAbsent(whKeyGlobal, emptyBuckets);
        finalWhRow.putIfAbsent(whKeyGlobal, () => first);
        finalCatWhTotals.putIfAbsent(catWhKey, emptyBuckets);
        finalCatWhRow.putIfAbsent(catWhKey, () => first);
        for (final b in bucketOrder) {
          catBucketTotals[b] = catBucketTotals[b]! + bucketTotals[b]!;
          whBucketTotals[b] = whBucketTotals[b]! + bucketTotals[b]!;
          finalCatTotals[catKeyGlobal]![b] = finalCatTotals[catKeyGlobal]![b]! + bucketTotals[b]!;
          finalWhTotals[whKeyGlobal]![b] = finalWhTotals[whKeyGlobal]![b]! + bucketTotals[b]!;
          finalCatWhTotals[catWhKey]![b] = finalCatWhTotals[catWhKey]![b]! + bucketTotals[b]!;
          grandBucketTotals[b] = grandBucketTotals[b]! + bucketTotals[b]!;
        }
        catClosingSum += closing;
        whClosingSum += closing;
        finalCatClosing[catKeyGlobal] = (finalCatClosing[catKeyGlobal] ?? 0) + closing;
        finalWhClosing[whKeyGlobal] = (finalWhClosing[whKeyGlobal] ?? 0) + closing;
        finalCatWhClosing[catWhKey] = (finalCatWhClosing[catWhKey] ?? 0) + closing;
        grandClosing += closing;
      }

      void flushCategory() {
        final r = lastCatFirstRow;
        if (r == null) return;
        if (showValue) {
          _xl(s, row, 0,
              '${isEnglish ? "Category Total" : "รวมหมวดหมู่"}: ${_categoryLabel(r, isEnglish)} '
              '(${isEnglish ? "Warehouse" : "คลัง"} ${r['warehouse_code'] ?? ''} ${_warehouseName(r, isEnglish)})',
              bg: totBg, bold: true);
          row++;
          writeMovementHeader(row, showDocCols: false);
          row++;
          writeTotalsRow(row, isEnglish ? 'Total' : 'รวม', catBucketTotals, catClosingSum, bg: totBg);
          row += 2;
        }
        catBucketTotals = emptyBuckets();
        catClosingSum = 0;
      }

      void flushWarehouse() {
        final r = lastWhFirstRow;
        if (r == null) return;
        if (showValue) {
          _xl(s, row, 0, '${isEnglish ? "Warehouse Total" : "รวมคลัง"}: ${r['warehouse_code'] ?? ''} ${_warehouseName(r, isEnglish)}', bg: totBg, bold: true);
          row++;
          writeMovementHeader(row, showDocCols: false);
          row++;
          writeTotalsRow(row, isEnglish ? 'Total' : 'รวม', whBucketTotals, whClosingSum, bg: totBg);
          row += 2;
        }
        whBucketTotals = emptyBuckets();
        whClosingSum = 0;
      }

      for (final r in _reportData) {
        final itemKey = '${r['warehouse_id']}_${r['item_id']}';
        final catKey  = '${r['warehouse_id']}_${r['category_id']}';
        final whKey   = '${r['warehouse_id']}';

        if (curItemKey != null && itemKey != curItemKey) {
          flushItem();
          curItemRows = [];
        }
        if (curCatKey != null && catKey != curCatKey) {
          flushCategory();
        }
        if (curWhKey != null && whKey != curWhKey) {
          flushWarehouse();
        }

        curItemKey = itemKey;
        if (catKey != curCatKey) lastCatFirstRow = r;
        curCatKey = catKey;
        if (whKey != curWhKey) lastWhFirstRow = r;
        curWhKey = whKey;
        curItemRows.add(r);
      }
      flushItem();
      flushCategory();
      flushWarehouse();

      // ─── สรุปยอดท้ายรายงาน — ตามหมวดหมู่ / ตามคลัง / ยอดรวมทั้งหมด ตามเงื่อนไขที่เลือก ─────────────
      if (showValue && finalCatTotals.isNotEmpty) {
        _xl(s, row, 0, isEnglish ? 'Summary' : 'สรุปยอดรวม', bold: true);
        row += 2;

        _xl(s, row, 0, isEnglish ? 'Summary by Category' : 'สรุปยอดตามหมวดหมู่', bold: true);
        row++;
        writeMovementHeader(row, showDocCols: false);
        row++;
        final catKeys = finalCatTotals.keys.toList()
          ..sort((a, b) => (finalCatRow[a]!['category_code'] as String? ?? '').compareTo(finalCatRow[b]!['category_code'] as String? ?? ''));
        for (final k in catKeys) {
          writeTotalsRow(row, _categoryLabel(finalCatRow[k]!, isEnglish), finalCatTotals[k]!, finalCatClosing[k]!);
          row++;
          // drill-down: คลังใดบ้างที่หมวดหมู่นี้มีอยู่ — ชื่อคลังเยื้องขวา (indent ด้วย spaces)
          final subKeys = finalCatWhTotals.keys.where((ck) => ck.startsWith('$k|')).toList()
            ..sort((a, b) => (finalCatWhRow[a]!['warehouse_code'] as String? ?? '').compareTo(finalCatWhRow[b]!['warehouse_code'] as String? ?? ''));
          for (final sk in subKeys) {
            final r = finalCatWhRow[sk]!;
            writeTotalsRow(row, '     ${r['warehouse_code'] ?? ''} ${_warehouseName(r, isEnglish)}', finalCatWhTotals[sk]!, finalCatWhClosing[sk]!);
            row++;
          }
        }
        writeTotalsRow(row, isEnglish ? 'Total - All Categories' : 'ยอดรวมทุกหมวดหมู่', grandBucketTotals, grandClosing, bg: totBg);
        row += 2;

        _xl(s, row, 0, isEnglish ? 'Summary by Warehouse' : 'สรุปยอดตามคลัง', bold: true);
        row++;
        writeMovementHeader(row, showDocCols: false);
        row++;
        final whKeys = finalWhTotals.keys.toList()
          ..sort((a, b) => (finalWhRow[a]!['warehouse_code'] as String? ?? '').compareTo(finalWhRow[b]!['warehouse_code'] as String? ?? ''));
        for (final k in whKeys) {
          final r = finalWhRow[k]!;
          writeTotalsRow(row, '${r['warehouse_code'] ?? ''} ${_warehouseName(r, isEnglish)}', finalWhTotals[k]!, finalWhClosing[k]!);
          row++;
          // drill-down: หมวดหมู่ใดบ้างที่คลังนี้มีอยู่ — ชื่อหมวดหมู่เยื้องขวา (indent ด้วย spaces)
          final subKeys = finalCatWhTotals.keys.where((ck) => ck.endsWith('|$k')).toList()
            ..sort((a, b) => (finalCatWhRow[a]!['category_code'] as String? ?? '').compareTo(finalCatWhRow[b]!['category_code'] as String? ?? ''));
          for (final sk in subKeys) {
            writeTotalsRow(row, '     ${_categoryLabel(finalCatWhRow[sk]!, isEnglish)}', finalCatWhTotals[sk]!, finalCatWhClosing[sk]!);
            row++;
          }
        }
        writeTotalsRow(row, isEnglish ? 'Total - All Warehouses' : 'ยอดรวมทุกคลัง', grandBucketTotals, grandClosing, bg: totBg);
        row += 2;

        writeMovementHeader(row, showDocCols: false);
        row++;
        writeTotalsRow(row, isEnglish ? 'Grand Total' : 'ยอดรวมทั้งหมด', grandBucketTotals, grandClosing, bg: totBg);
        row++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'IM_Stock_Movement_Report' : 'รายงานสินค้าคงเหลือและการเคลื่อนไหว';
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

  Future<void> _pickWarehouses() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImWarehouse>(
        title: isEnglish ? 'Select Warehouses' : 'เลือกคลังสินค้า',
        items: _warehouses,
        selected: _selectedWarehouseIds.map((e) => e.toString()).toList(),
        idOf: (w) => w.id.toString(),
        labelOf: (w) => '${w.warehouseCode}  ${isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh}',
        isEnglish: isEnglish,
        showSearch: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedWarehouseIds = result.map((e) => int.parse(e)).toList());
    }
  }

  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImItemCategory>(
        title: isEnglish ? 'Select Item Categories' : 'เลือกหมวดหมู่สินค้า',
        items: _categories,
        selected: _selectedCategoryIds.map((e) => e.toString()).toList(),
        idOf: (c) => c.id.toString(),
        labelOf: (c) => '${c.categoryCode}  ${isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
        isEnglish: isEnglish,
        showSearch: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategoryIds = result.map((e) => int.parse(e)).toList());
    }
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
        : (perm?.menuName ?? (isEnglish ? 'Stock Balance & Movement Report' : 'รายงานสินค้าคงเหลือและการเคลื่อนไหว'));
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
                  maxWidth: _filterPanelWidth, minWidth: _filterPanelWidth,
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
                              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),

                              _buildMultiField(
                                label: isEnglish ? 'Warehouse' : 'คลังสินค้า',
                                count: _selectedWarehouseIds.length,
                                allLabel: isEnglish ? '— All Warehouses —' : '— ทุกคลัง —',
                                onTap: _pickWarehouses,
                                onClear: () => setState(() => _selectedWarehouseIds = []),
                              ),
                              if (_selectedWarehouseIds.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4, runSpacing: 2,
                                  children: _selectedWarehouseIds.map((id) {
                                    final w = _warehouses.where((x) => x.id == id);
                                    final code = w.isNotEmpty ? w.first.warehouseCode : '$id';
                                    return Chip(
                                      label: Text(code, style: const TextStyle(fontSize: 11)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.teal[50],
                                      side: BorderSide(color: Colors.teal[200]!),
                                    );
                                  }).toList(),
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildMultiField(
                                label: isEnglish ? 'Item Category' : 'หมวดหมู่สินค้า',
                                count: _selectedCategoryIds.length,
                                allLabel: isEnglish ? '— Not specified —' : '— ไม่ระบุ —',
                                onTap: _pickCategories,
                                onClear: () => setState(() => _selectedCategoryIds = []),
                              ),
                              if (_selectedCategoryIds.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4, runSpacing: 2,
                                  children: _selectedCategoryIds.map((id) {
                                    final cat = _categories.where((x) => x.id == id);
                                    final code = cat.isNotEmpty ? cat.first.categoryCode : '$id';
                                    return Chip(
                                      label: Text(code, style: const TextStyle(fontSize: 11)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.teal[50],
                                      side: BorderSide(color: Colors.teal[200]!),
                                    );
                                  }).toList(),
                                ),
                              ],

                              // รหัสสินค้าจาก-ถึง แสดงเฉพาะเมื่อไม่ได้ระบุหมวดหมู่ (mutually exclusive กับข้อ 2)
                              if (_selectedCategoryIds.isEmpty) ...[
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
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              _buildDateField(label: isEnglish ? 'Document Date From' : 'วันที่เอกสาร ตั้งแต่', date: _dateFrom, onPick: (d) => setState(() => _dateFrom = d)),
                              const SizedBox(height: 12),
                              _buildDateField(label: isEnglish ? 'Document Date To' : 'วันที่เอกสาร ถึง', date: _dateTo, onPick: (d) => setState(() => _dateTo = d)),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              Row(children: [
                                Expanded(child: Text(_showMovement
                                    ? (isEnglish ? 'Showing: Movement Detail' : 'แสดง: การเคลื่อนไหว')
                                    : (isEnglish ? 'Showing: Summary Only' : 'แสดง: เฉพาะยอดรวม'), style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showMovement,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) => setState(() => _showMovement = v),
                                ),
                              ]),
                              Row(children: [
                                Expanded(child: Text(_showValue
                                    ? (isEnglish ? 'Showing: Value' : 'แสดง: มูลค่า')
                                    : (isEnglish ? 'Showing: Quantity' : 'แสดง: จำนวน'), style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _showValue,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) => setState(() => _showValue = v),
                                ),
                              ]),
                              Row(children: [
                                Expanded(child: Text(_newPagePerItem
                                    ? (isEnglish ? 'New page per item' : 'ขึ้นหน้าใหม่ทุกสินค้า')
                                    : (isEnglish ? 'Continuous' : 'แสดงต่อเนื่อง'), style: const TextStyle(fontSize: 13))),
                                Switch(
                                  value: _newPagePerItem,
                                  activeColor: Colors.teal[800],
                                  onChanged: (v) => setState(() => _newPagePerItem = v),
                                ),
                              ]),
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
                  ),
                ),
              ),
            ),
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() => _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth)),
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
                        ? Center(child: Text(isEnglish ? 'Select conditions and click Generate Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
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
// Generic multi-select picker dialog with search — ทำซ้ำในไฟล์นี้ตาม convention เดิม
// (pattern_master_report_screen) มิเรอร์ตัวเดียวกับ im_item_transaction_report_screen.dart
// ---------------------------------------------------------------------------
class _MultiPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<String> selected;
  final String Function(T) idOf;
  final String Function(T) labelOf;
  final bool isEnglish;
  final bool showSearch;

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.isEnglish,
    this.showSearch = false,
  });

  @override
  State<_MultiPickerDialog<T>> createState() => _MultiPickerDialogState<T>();
}

class _MultiPickerDialogState<T> extends State<_MultiPickerDialog<T>> {
  late List<String> _selected;
  late List<T> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    _filtered = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _doFilter(String q) {
    setState(() {
      _filtered = q.trim().isEmpty
          ? List.from(widget.items)
          : widget.items.where((e) => widget.labelOf(e).toLowerCase().contains(q.trim().toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420, height: 520,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.isEnglish ? 'Search' : 'ค้นหา',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _doFilter,
              ),
            ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text(widget.isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                : ListView(
                    children: _filtered.map((item) {
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

// ---------------------------------------------------------------------------
// Item search dialog สำหรับเลือกรหัสสินค้าจาก-ถึง — มิเรอร์ im_item_report_screen.dart
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
