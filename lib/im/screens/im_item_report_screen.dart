import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../models/im_warehouse.dart';
import '../services/im_item_service.dart';
import '../services/im_item_category_service.dart';
import '../services/im_warehouse_service.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/file_download.dart';

// ---------------------------------------------------------------------------
// Detail section enum — เนื้อหารายละเอียดต่อสินค้า 1 บรรทัด (มิเรอร์ _Category ของ
// ar_customer_report_screen.dart แต่เปลี่ยนชื่อเป็น _Section เพื่อไม่ชนกับ "หมวดหมู่สินค้า"
// (ImItemCategory) ที่เป็นทั้งตัวกรองและตัว group-by ของรายงานนี้)
// ---------------------------------------------------------------------------
enum _Section { generalInfo, uomInfo, warehouseInfo, glAccount }

extension _SecLabel on _Section {
  String label(bool isEnglish) {
    switch (this) {
      case _Section.generalInfo:  return isEnglish ? 'General Information' : 'ข้อมูลทั่วไป';
      case _Section.uomInfo:      return isEnglish ? 'Units of Measure'    : 'หน่วยนับ';
      case _Section.warehouseInfo:return isEnglish ? 'Warehouse Settings' : 'การตั้งค่าคลังสินค้า';
      case _Section.glAccount:    return isEnglish ? 'GL Account Codes'   : 'รหัสบัญชี GL';
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ImItemReportScreen extends StatefulWidget {
  const ImItemReportScreen({super.key});

  @override
  State<ImItemReportScreen> createState() => _ImItemReportScreenState();
}

class _ImItemReportScreenState extends State<ImItemReportScreen> {
  final _itemSvc      = ImItemService();
  final _companySvc   = CompanyService();
  final _authSvc      = AuthService();
  final _categorySvc  = ImItemCategoryService();
  final _warehouseSvc = ImWarehouseService();
  final _vatRateSvc   = VatRateService();

  bool   _isLoading         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 330.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;
  bool   _isEnglish         = false;

  Company?               _company;
  Map<String, String>?   _headers;
  List<ImItemCategory>   _categories  = [];
  List<ImWarehouse>      _warehouses  = [];
  List<VatRate>          _vatRates    = [];

  // Filters
  List<int> _selectedCategoryIds = [];
  int?      _selectedWarehouseId;
  String    _itemType            = '';   // '' | STOCK | SERVICE | NON_STOCK
  String?   _itemCodeFrom;
  String?   _itemCodeTo;
  String    _fromLabel           = '';
  String    _toLabel             = '';
  String    _status              = '';   // '' | active | inactive
  List<_Section> _selectedSections = [];

  List<ImItem> _reportData = [];

  // ─── init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    _headers = await _authSvc.getAuthHeader();
    final res = await Future.wait([
      _companySvc.fetchCompany(),
      _categorySvc.fetchActiveRows(),
      _warehouseSvc.fetchActiveRows(),
      _vatRateSvc.fetchRows(),
    ]);
    _company = res[0] as Company?;
    // หมวดหมู่ระดับ HEADER เป็นแค่โครงต้นไม้ ไม่ใช่หมวดที่สินค้าอ้างอิงได้จริง (มิเรอร์เงื่อนไขเดียวกับ
    // imItemImportController.js: category_type='CATEGORY' เท่านั้นที่สินค้าเลือกได้)
    _categories  = (res[1] as List<ImItemCategory>).where((c) => c.categoryType == 'CATEGORY').toList();
    _warehouses  = res[2] as List<ImWarehouse>;
    _vatRates    = (res[3] as List<VatRate>).where((v) => v.isActive).toList();
    if (mounted) setState(() {});
  }

  // ─── report generation ────────────────────────────────────────────────────

  // uomInfo/warehouseInfo ต้องใช้ uom_conversions/item_warehouses ซึ่ง fetchRows (list) ไม่ส่งมาให้
  // (มิเรอร์ ar_customer_report_screen.dart's _needsFullData — ต้อง fetchRow(id) แยกทีละสินค้าเมื่อเลือก)
  bool _needsFullData() => _selectedSections.any((s) => const {
        _Section.uomInfo,
        _Section.warehouseInfo,
      }.contains(s));

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      var list = await _itemSvc.fetchRows();

      if (_selectedCategoryIds.isNotEmpty) {
        list = list
            .where((i) => i.categoryId != null && _selectedCategoryIds.contains(i.categoryId))
            .toList();
      }
      if (_selectedWarehouseId != null) {
        list = list.where((i) => i.defaultWarehouseId == _selectedWarehouseId).toList();
      }
      if (_itemType.isNotEmpty) {
        list = list.where((i) => i.itemType == _itemType).toList();
      }
      if ((_itemCodeFrom ?? '').isNotEmpty) {
        list = list.where((i) => i.itemCode.compareTo(_itemCodeFrom!) >= 0).toList();
      }
      if ((_itemCodeTo ?? '').isNotEmpty) {
        list = list.where((i) => i.itemCode.compareTo(_itemCodeTo!) <= 0).toList();
      }
      if (_status == 'active')   list = list.where((i) =>  i.isActive).toList();
      if (_status == 'inactive') list = list.where((i) => !i.isActive).toList();

      list.sort((a, b) => a.itemCode.compareTo(b.itemCode));

      List<ImItem> finalList = list;
      if (_needsFullData() && list.isNotEmpty) {
        final futures = list.map((i) async {
          if (i.id == null) return i;
          try { return await _itemSvc.fetchRow(i.id!); } catch (_) { return i; }
        }).toList();
        finalList = await Future.wait(futures);
      }

      if (finalList.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No data found for the selected conditions'
                : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
      }
      if (mounted) setState(() { _reportData = finalList; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── formatters ───────────────────────────────────────────────────────────

  static String _yn(bool v, bool isEnglish) =>
      v ? (isEnglish ? 'Yes' : 'ใช่') : (isEnglish ? 'No' : 'ไม่ใช่');

  String _vatLabel(String vatCode) {
    final v = _vatRates.cast<VatRate?>().firstWhere((x) => x?.vatCode == vatCode, orElse: () => null);
    if (v != null) {
      final rateStr = v.rate == v.rate.roundToDouble() ? v.rate.toStringAsFixed(0) : v.rate.toString();
      return '${v.vatCode}  $rateStr%';
    }
    return vatCode;
  }

  static String _uomConvStr(ImUomConversion u, bool isEnglish) {
    final name = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn! : (u.uomNameTh ?? '');
    final flags = [
      if (u.isPurchaseDefault) (isEnglish ? 'purchase default' : 'หน่วยซื้อตั้งต้น'),
      if (u.isSalesDefault)    (isEnglish ? 'sales default'    : 'หน่วยขายตั้งต้น'),
    ].join(', ');
    return [
      '${u.uomCode ?? ''} $name',
      '= ${u.conversionFactor}  ${isEnglish ? "x base unit" : "เท่าของหน่วยหลัก"}',
      if ((u.barcode ?? '').isNotEmpty) 'Barcode: ${u.barcode}',
      if (flags.isNotEmpty) '($flags)',
    ].join('  ');
  }

  static String _itemWarehouseStr(ImItemWarehouse w, bool isEnglish) {
    final name = isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : (w.warehouseNameTh ?? '');
    return [
      '${w.warehouseCode ?? ''} $name',
      '${isEnglish ? "Min" : "ต่ำสุด"} ${w.minStockQty}',
      '${isEnglish ? "Max" : "สูงสุด"} ${w.maxStockQty}',
      '${isEnglish ? "Reorder" : "จุดสั่งซื้อ"} ${w.reorderPoint}',
      if ((w.defaultLocationCode ?? '').isNotEmpty) '${isEnglish ? "Bin" : "ตำแหน่ง"}: ${w.defaultLocationCode}',
    ].join('  ');
  }

  List<String> _sectionLines(ImItem i, _Section sec, bool isEnglish) {
    switch (sec) {
      case _Section.generalInfo:
        final p = <String>[];
        p.add('${isEnglish ? "Item Type" : "ประเภทสินค้า"}: ${imItemTypeLabel(i.itemType, isEnglish)}');
        if ((i.categoryName ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Category" : "หมวดหมู่"}: ${i.categoryCode} ${i.categoryName}');
        }
        p.add('${isEnglish ? "Costing Method" : "วิธีคำนวณต้นทุน"}: ${imCostingMethodLabel(i.costingMethod, isEnglish)}');
        if (i.standardCost > 0) {
          p.add('${isEnglish ? "Standard Cost" : "ต้นทุนมาตรฐาน"}: ${NumberFormat("#,##0.00").format(i.standardCost)}');
        }
        p.add('${isEnglish ? "Purchase" : "ซื้อได้"}: ${_yn(i.isPurchaseItem, isEnglish)}');
        p.add('${isEnglish ? "Sales" : "ขายได้"}: ${_yn(i.isSalesItem, isEnglish)}');
        p.add('${isEnglish ? "Manufactured" : "ผลิตได้"}: ${_yn(i.isManufactured, isEnglish)}');
        p.add('${isEnglish ? "Lot Tracked" : "ติดตาม Lot"}: ${_yn(i.isLotTracked, isEnglish)}');
        p.add('${isEnglish ? "Serial Tracked" : "ติดตาม Serial"}: ${_yn(i.isSerialTracked, isEnglish)}');
        if (i.shelfLifeDays != null) {
          p.add('${isEnglish ? "Shelf Life" : "อายุสินค้า"}: ${i.shelfLifeDays} ${isEnglish ? "day(s)" : "วัน"}');
        }
        if (i.minStockQty > 0) p.add('${isEnglish ? "Min Stock" : "สต็อกขั้นต่ำ"}: ${i.minStockQty}');
        if (i.maxStockQty > 0) p.add('${isEnglish ? "Max Stock" : "สต็อกสูงสุด"}: ${i.maxStockQty}');
        if (i.reorderPoint > 0) p.add('${isEnglish ? "Reorder Point" : "จุดสั่งซื้อ"}: ${i.reorderPoint}');
        p.add('${isEnglish ? "VAT Type" : "ประเภทภาษี"}: ${_vatLabel(i.defaultVatType)}');
        if ((i.barcode ?? '').isNotEmpty) p.add('Barcode: ${i.barcode}');
        p.add('${isEnglish ? "Status" : "สถานะ"}: ${i.isActive ? (isEnglish ? "Active" : "ใช้งาน") : (isEnglish ? "Inactive" : "ไม่ใช้งาน")}');
        if ((i.description ?? '').isNotEmpty) p.add('${isEnglish ? "Description" : "คำอธิบาย"}: ${i.description}');
        return [p.join('  |  ')];

      case _Section.uomInfo:
        final p = <String>[];
        final baseName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn! : (i.baseUomNameTh ?? '');
        p.add('${isEnglish ? "Base Unit" : "หน่วยหลัก"}: ${i.baseUomCode ?? ''} $baseName');
        if (i.uomConversions.isEmpty) {
          p.add(isEnglish ? '(No alternate units)' : '(ไม่มีหน่วยนับทางเลือก)');
          return [p.join('  |  ')];
        }
        final lines = [p.join('  |  ')];
        lines.addAll(i.uomConversions.map((u) => _uomConvStr(u, isEnglish)));
        return lines;

      case _Section.warehouseInfo:
        final p = <String>[];
        final whName = isEnglish && (i.defaultWarehouseNameEn ?? '').isNotEmpty ? i.defaultWarehouseNameEn! : (i.defaultWarehouseNameTh ?? '');
        if ((i.defaultWarehouseCode ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Default Warehouse" : "คลังตั้งต้น"}: ${i.defaultWarehouseCode} $whName');
        }
        if (i.itemWarehouses.isEmpty) {
          p.add(isEnglish ? '(No per-warehouse settings)' : '(ไม่มีการตั้งค่าเฉพาะคลัง)');
          return p.isEmpty ? [isEnglish ? '(No data)' : '(ไม่มีข้อมูล)'] : [p.join('  |  ')];
        }
        final lines = p.isEmpty ? <String>[] : [p.join('  |  ')];
        lines.addAll(i.itemWarehouses.map((w) => _itemWarehouseStr(w, isEnglish)));
        return lines;

      case _Section.glAccount:
        final p = <String>[
          '${isEnglish ? "Inventory" : "สินค้าคงเหลือ"}: ${(i.inventoryAccountCode ?? '').isEmpty ? (isEnglish ? "(not set)" : "(ยังไม่ตั้งค่า)") : "${i.inventoryAccountCode} ${i.inventoryAccountName ?? ''}"}',
          '${isEnglish ? "COGS" : "ต้นทุนขาย"}: ${(i.cogsAccountCode ?? '').isEmpty ? (isEnglish ? "(not set)" : "(ยังไม่ตั้งค่า)") : "${i.cogsAccountCode} ${i.cogsAccountName ?? ''}"}',
          '${isEnglish ? "Revenue" : "รายได้"}: ${(i.revenueAccountCode ?? '').isEmpty ? (isEnglish ? "(not set)" : "(ยังไม่ตั้งค่า)") : "${i.revenueAccountCode} ${i.revenueAccountName ?? ''}"}',
          '${isEnglish ? "Expense" : "ค่าใช้จ่าย"}: ${(i.expenseAccountCode ?? '').isEmpty ? (isEnglish ? "(not set)" : "(ยังไม่ตั้งค่า)") : "${i.expenseAccountCode} ${i.expenseAccountName ?? ''}"}',
        ];
        return [p.join('  |  ')];
    }
  }

  String _conditionLine(bool isEnglish) {
    final p = <String>[];
    if (_selectedCategoryIds.isNotEmpty) {
      final names = _selectedCategoryIds.map((id) {
        final c = _categories.firstWhere((c) => c.id == id, orElse: () => _categories.first);
        return isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh;
      }).join(', ');
      p.add('${isEnglish ? "Category" : "หมวดหมู่"}: $names');
    }
    if (_selectedWarehouseId != null) {
      final w = _warehouses.firstWhere((w) => w.id == _selectedWarehouseId, orElse: () => _warehouses.first);
      final name = isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh;
      p.add('${isEnglish ? "Default Warehouse" : "คลังตั้งต้น"}: ${w.warehouseCode} $name');
    }
    if (_itemType.isNotEmpty) {
      p.add('${isEnglish ? "Item Type" : "ประเภทสินค้า"}: ${imItemTypeLabel(_itemType, isEnglish)}');
    }
    if ((_itemCodeFrom ?? '').isNotEmpty || (_itemCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final f = (_itemCodeFrom ?? '').isEmpty ? all : _itemCodeFrom!;
      final t = (_itemCodeTo   ?? '').isEmpty ? all : _itemCodeTo!;
      p.add('${isEnglish ? "Code" : "รหัส"}: $f – $t');
    }
    if (_status == 'active')   p.add(isEnglish ? 'Status: Active'   : 'สถานะ: ใช้งาน');
    if (_status == 'inactive') p.add(isEnglish ? 'Status: Inactive' : 'สถานะ: ไม่ใช้งาน');
    return p.isEmpty ? (isEnglish ? 'All' : 'ทั้งหมด') : p.join(' | ');
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish     = _isEnglish;
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font         = pw.Font.ttf(fontData);
    final fontBold     = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.displayName(isEnglish) ?? (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final condLine     = _conditionLine(isEnglish);

    const mg = 20.0;
    final pageW = format.width - mg * 2;

    // Column widths (absolute) — มิเรอร์สัดส่วนของ ar_customer_report_screen.dart
    final codeW   = pageW * 0.13;
    final nameTHW = pageW * 0.37;
    final nameENW = pageW * 0.31;
    final oldW    = pageW * 0.19;

    const cGreen  = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal  = PdfColor(0.75, 0.88, 0.96);
    const cBorder = PdfColors.grey400;
    const hp = 3.0;
    const vp = 2.5;

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font,     fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    pw.Widget box(double w, String t, pw.TextStyle s,
        {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.SizedBox(
          width: w,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: vp),
            child: pw.Text(t, style: s, textAlign: align,
                softWrap: true, maxLines: 3),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(
        color: cGreen,
        border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5)),
      ),
      child: pw.Row(children: [
        box(codeW,   isEnglish ? 'Item Code' : 'รหัสสินค้า',           tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(nameTHW, isEnglish ? 'Item Name (TH)' : 'ชื่อสินค้า (ไทย)',      tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(nameENW, isEnglish ? 'Item Name (EN)' : 'ชื่อสินค้า (อังกฤษ)',   tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(oldW,    isEnglish ? 'Old Code' : 'รหัสเก่า',               tB(9)),
      ]),
    );

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
        pw.Expanded(flex: 6, child: pw.Text(isEnglish ? 'Item Master Report' : 'รายงานข้อมูลสินค้า',
            textAlign: pw.TextAlign.center, style: tB(15))),
        pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Page" : "หน้า"} ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.SizedBox()),
        pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed by" : "พิมพ์โดย"} $userName',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 2),
      pw.Row(children: [
        pw.Expanded(flex: 9,
            child: pw.Text('* $condLine', style: tN(9))),
        pw.Expanded(flex: 3,
            child: pw.Text('${isEnglish ? "Printed" : "พิมพ์เมื่อ"} $printDateStr',
                textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 4),
      tableHeader,
    ]);

    const cGroupTot = PdfColor(0.80, 0.93, 0.88);

    // จัดกลุ่มสินค้าตาม categoryCode แล้วเรียงตาม code หมวดหมู่ (มิเรอร์การจัดกลุ่มตาม customerGroupCode)
    final grouped = <String, List<ImItem>>{};
    for (final i in _reportData) {
      final key = i.categoryCode ?? '';
      grouped.putIfAbsent(key, () => []).add(i);
    }
    final sortedGroupKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    final content = <pw.Widget>[];

    int globalIdx = 0;
    for (final groupKey in sortedGroupKeys) {
      final groupItems = grouped[groupKey]!;

      for (final i in groupItems) {
        final bg = globalIdx.isOdd ? cStripe : null;

        content.add(pw.Container(
          color: bg,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3)),
          ),
          child: pw.Row(children: [
            box(codeW,   i.itemCode,          tB(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(nameTHW, i.itemNameTh,        tN(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(nameENW, i.itemNameEn ?? '',  tN(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(oldW,    i.oldItemCode ?? '', tN(9)),
          ]),
        ));

        for (final sec in _selectedSections) {
          final lines = _sectionLines(i, sec, isEnglish);
          content.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: 2),
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(
                  text: '${sec.label(isEnglish)}  ',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5, decoration: pw.TextDecoration.underline),
                ),
                pw.TextSpan(
                  text: lines.join('  |  '),
                  style: pw.TextStyle(font: font, fontSize: 8.5),
                ),
              ]),
            ),
          ));
        }

        if (_selectedSections.isNotEmpty) {
          content.add(pw.Divider(height: 0.5, color: PdfColors.grey400));
        }
        globalIdx++;
      }

      final first = groupItems.first;
      final groupLabel = groupKey.isEmpty
          ? (isEnglish ? '(No category)' : '(ไม่ระบุหมวดหมู่)')
          : '$groupKey  ${first.categoryName ?? ""}';
      content.add(pw.Container(
        width: pageW,
        color: cGroupTot,
        padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp),
        child: pw.Text(
          isEnglish
              ? 'Category total $groupLabel:  ${groupItems.length} item(s)'
              : 'รวมหมวดหมู่ $groupLabel:  ${groupItems.length} รายการ',
          style: tB(9),
        ),
      ));
    }

    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp + 1),
      child: pw.Text(
          isEnglish
              ? 'Grand total ${_reportData.length} item(s)'
              : 'รวมทั้งสิ้น ${_reportData.length} รายการ',
          style: tB(9)),
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
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      final sName = isEnglish ? 'Item' : 'สินค้า';
      ex.rename('Sheet1', sName);
      final s = ex[sName];

      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final catBg = ExcelColor.fromHexString('#D0E4F7');

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, isEnglish ? 'Item Master Report' : 'รายงานข้อมูลสินค้า', bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}');
      _xl(s, 3, 0, '${isEnglish ? "Printed" : "พิมพ์"}: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}');

      final hdrs = isEnglish
          ? ['Item Code', 'Item Name (TH)', 'Item Name (EN)', 'Old Code']
          : ['รหัสสินค้า', 'ชื่อสินค้า (ไทย)', 'ชื่อสินค้า (อังกฤษ)', 'รหัสเก่า'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 5, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }
      if (_selectedSections.isNotEmpty) {
        _xl(s, 5, 4, isEnglish ? 'Section' : 'หมวด', bg: hdrBg, bold: true);
        _xl(s, 5, 5, isEnglish ? 'Details' : 'รายละเอียด', bg: hdrBg, bold: true);
      }

      int row = 6;
      for (final i in _reportData) {
        if (_selectedSections.isEmpty) {
          _xl(s, row, 0, i.itemCode);
          _xl(s, row, 1, i.itemNameTh);
          _xl(s, row, 2, i.itemNameEn ?? '');
          _xl(s, row, 3, i.oldItemCode ?? '');
          row++;
        } else {
          bool firstSec = true;
          for (final sec in _selectedSections) {
            final lines = _sectionLines(i, sec, isEnglish);
            for (int li = 0; li < lines.length; li++) {
              if (firstSec && li == 0) {
                _xl(s, row, 0, i.itemCode);
                _xl(s, row, 1, i.itemNameTh);
                _xl(s, row, 2, i.itemNameEn ?? '');
                _xl(s, row, 3, i.oldItemCode ?? '');
                firstSec = false;
              }
              _xl(s, row, 4, sec.label(isEnglish), bg: catBg);
              _xl(s, row, 5, lines[li]);
              row++;
            }
          }
        }
      }

      _xl(s, row, 0,
          isEnglish
              ? 'Grand total ${_reportData.length} item(s)'
              : 'รวมทั้งสิ้น ${_reportData.length} รายการ',
          bg: totBg, bold: true);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes,
          isEnglish ? 'ItemReport_$ts.xlsx' : 'รายงานข้อมูลสินค้า_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xl(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  Future<void> _pickItem({required bool isFrom}) async {
    final result = await showDialog<ImItem>(
      context: context,
      builder: (_) => const _ItemPickerDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      final displayName = _isEnglish && (result.itemNameEn ?? '').isNotEmpty
          ? result.itemNameEn!
          : result.itemNameTh;
      final label = '${result.itemCode}  $displayName';
      if (isFrom) {
        _itemCodeFrom = result.itemCode;
        _fromLabel    = label;
      } else {
        _itemCodeTo = result.itemCode;
        _toLabel    = label;
      }
    });
  }

  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImItemCategory>(
        title: isEnglish ? 'Select Item Categories' : 'เลือกหมวดหมู่สินค้า',
        items: _categories,
        selected: _selectedCategoryIds,
        idOf: (c) => c.id,
        labelOf: (c) => '${c.categoryCode}  ${isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedCategoryIds = result);
  }

  Future<void> _pickSections() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<_Section>(
        title: isEnglish ? 'Select Detail Sections' : 'เลือกหมวดรายละเอียด',
        items: _Section.values,
        selected: _selectedSections.map((s) => s.index).toList(),
        idOf: (s) => s.index,
        labelOf: (s) => s.label(isEnglish),
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedSections = result.map((i) => _Section.values[i]).toList());
    }
  }

  Widget _buildPickerField({
    required String label,
    required String displayText,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(
                onTap: onClear,
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(
              onTap: onPick,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.search, size: 18, color: Colors.orange[700]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMultiField({
    required String label,
    required int count,
    required String allLabel,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasValue = count > 0;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(
                onTap: onClear,
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(
              onTap: onTap,
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_drop_down, size: 20))),
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

  Widget _buildFilterPanel() {
    final isEnglish = _isEnglish;
    return Card(
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

                // หมวดหมู่สินค้า (multi-select)
                _buildMultiField(
                  label: isEnglish ? 'Item Category' : 'หมวดหมู่สินค้า',
                  count: _selectedCategoryIds.length,
                  allLabel: isEnglish ? '— All Categories —' : '— ทุกหมวดหมู่ —',
                  onTap: _pickCategories,
                  onClear: () => setState(() => _selectedCategoryIds = []),
                ),
                const SizedBox(height: 12),

                // คลังตั้งต้น
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  value: _selectedWarehouseId,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Default Warehouse' : 'คลังตั้งต้น',
                      border: const OutlineInputBorder(),
                      isDense: true),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                    ..._warehouses.map((w) => DropdownMenuItem<int?>(
                          value: w.id,
                          child: Text(
                              '${w.warehouseCode}  ${isEnglish && (w.warehouseNameEn ?? "").isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh}',
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedWarehouseId = v),
                ),
                const SizedBox(height: 12),

                // ประเภทสินค้า
                DropdownButtonFormField<String>(
                  value: _itemType,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Item Type' : 'ประเภทสินค้า',
                      border: const OutlineInputBorder(),
                      isDense: true),
                  items: [
                    DropdownMenuItem(value: '', child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                    ...imItemTypes.map((t) => DropdownMenuItem(value: t, child: Text(imItemTypeLabel(t, isEnglish)))),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _itemType = v); },
                ),
                const SizedBox(height: 12),

                // รหัสสินค้า ตั้งแต่ / ถึง
                _buildPickerField(
                  label: isEnglish ? 'Item Code From' : 'รหัสสินค้า ตั้งแต่',
                  displayText: _fromLabel,
                  onPick: () => _pickItem(isFrom: true),
                  onClear: () => setState(() {
                    _itemCodeFrom = null;
                    _fromLabel = '';
                  }),
                ),
                const SizedBox(height: 8),
                _buildPickerField(
                  label: isEnglish ? 'Item Code To' : 'รหัสสินค้า ถึง',
                  displayText: _toLabel,
                  onPick: () => _pickItem(isFrom: false),
                  onClear: () => setState(() {
                    _itemCodeTo = null;
                    _toLabel = '';
                  }),
                ),
                const SizedBox(height: 12),

                // สถานะ
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Status' : 'สถานะ',
                      border: const OutlineInputBorder(),
                      isDense: true),
                  items: [
                    DropdownMenuItem(value: '', child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                    DropdownMenuItem(value: 'active',   child: Text(isEnglish ? 'Active'   : 'ใช้งาน')),
                    DropdownMenuItem(value: 'inactive', child: Text(isEnglish ? 'Inactive' : 'ไม่ใช้งาน')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _status = v); },
                ),
                const SizedBox(height: 12),

                // หมวดรายละเอียด (multi-select)
                _buildMultiField(
                  label: isEnglish ? 'Detail Sections' : 'หมวดรายละเอียด',
                  count: _selectedSections.length,
                  allLabel: isEnglish ? '— Master data only —' : '— ข้อมูลหลักเท่านั้น —',
                  onTap: _pickSections,
                  onClear: () => setState(() => _selectedSections = []),
                ),
                if (_selectedSections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: _selectedSections.map((sec) => Chip(
                      label: Text(sec.label(isEnglish), style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.orange[50],
                      side: BorderSide(color: Colors.orange[200]!),
                    )).toList(),
                  ),
                ],
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white),
              onPressed: _isLoading ? null : _generateReport,
            ),
          ),
        ),
      ]),
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
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: (_reportData.isEmpty || !canExport) ? null : _exportExcel,
            ),
        ],
      ),
      body: _isLoading && _company == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxFW = (constraints.maxWidth - 36 - 5 - 300)
                  .clamp(100.0, double.infinity);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 36,
                    color: Colors.orange[700],
                    child: IconButton(
                      icon: Icon(
                          _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded
                          ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                          : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
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
                          _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFW);
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
                          : _reportData.isEmpty
                              ? Center(
                                  child: Text(isEnglish
                                      ? 'Please select conditions and click Generate Report'
                                      : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat: PdfPageFormat.a4,
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
// Item picker dialog
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
            color: Colors.orange[700],
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

// ---------------------------------------------------------------------------
// Generic multi-select picker dialog
// ---------------------------------------------------------------------------
class _MultiPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<int> selected;
  final int Function(T) idOf;
  final String Function(T) labelOf;
  final bool isEnglish;

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.isEnglish,
  });

  @override
  State<_MultiPickerDialog<T>> createState() => _MultiPickerDialogState<T>();
}

class _MultiPickerDialogState<T> extends State<_MultiPickerDialog<T>> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange[700],
            child: Text(widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: ListView(
              children: widget.items.map((item) {
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
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
