// lib/im/screens/im_price_change_report_screen.dart
// รายงานตรวจเช็คการเปลี่ยนแปลงราคา — filter panel ซ้าย (มิเรอร์ Master Report Screen Pattern เดียวกับ
// im_item_report_screen.dart) + PDF preview ขวา ตัวกรองกลุ่มราคา/ตารางราคา/กลุ่มสินค้า เป็น cascade ต่อกัน
// (เลือกกลุ่มราคา -> ตัวเลือกตารางราคาแคบลง -> เลือกตารางราคา -> ตัวเลือกกลุ่มสินค้า/สินค้าแคบลง)
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../widgets/zoomable_pdf_preview.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../models/im_price_group.dart';
import '../models/im_price_list.dart';
import '../models/im_item_category.dart';
import '../models/im_price_change_report.dart';
import '../services/im_price_group_service.dart';
import '../services/im_price_list_service.dart';
import '../services/im_item_category_service.dart';
import '../services/im_price_change_report_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/file_download.dart';

// ---------------------------------------------------------------------------
// Generic multi-select picker dialog — มิเรอร์ im_item_report_screen.dart ทุกจุด
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
            child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: widget.items.isEmpty
                ? Center(child: Text(widget.isEnglish ? 'No options available' : 'ไม่มีตัวเลือก', style: const TextStyle(color: Colors.grey)))
                : ListView(
                    children: widget.items.map((item) {
                      final id = widget.idOf(item);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(widget.labelOf(item), style: const TextStyle(fontSize: 13)),
                        value: _selected.contains(id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) { _selected.add(id); } else { _selected.remove(id); }
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
                onPressed: widget.items.isEmpty ? null : () => setState(() {
                  _selected = _selected.length == widget.items.length ? [] : widget.items.map((e) => widget.idOf(e)).toList();
                }),
                child: Text(_selected.length == widget.items.length && widget.items.isNotEmpty
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

// ---------------------------------------------------------------------------
// ตัวเลือกสถานะธุรกรรม (คงที่ 3 ตัว) — ใช้คู่กับ _MultiPickerDialog ด้านบน (idOf ต้องการ int)
// ---------------------------------------------------------------------------
class _ChangeStatusOption {
  final int id;
  final String value;
  final String label;
  const _ChangeStatusOption(this.id, this.value, this.label);
}

// ---------------------------------------------------------------------------
// ค้นหาสินค้า (เลือกรายการเดียว) — ขอบเขตเฉพาะสินค้าที่มีราคาอยู่ในตารางราคาที่เลือกไว้ (ไม่เลือก = ทุกสินค้า
// ที่เคยตั้งราคาไว้)
// ---------------------------------------------------------------------------
class _ScopedItemPickerDialog extends StatefulWidget {
  final List<int> priceListIds;
  const _ScopedItemPickerDialog({required this.priceListIds});

  @override
  State<_ScopedItemPickerDialog> createState() => _ScopedItemPickerDialogState();
}

class _ScopedItemPickerDialogState extends State<_ScopedItemPickerDialog> {
  final _ctrl = TextEditingController();
  final _svc = ImPriceChangeReportService();
  List<ImPriceChangeReportItem> _list = [];
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
      final list = await _svc.searchItems(priceListIds: widget.priceListIds, search: q.trim().isEmpty ? null : q.trim());
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
            child: Text(isEnglish ? 'Search Item' : 'ค้นหาสินค้า', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search by item code or name' : 'ค้นหาจากรหัสหรือชื่อสินค้า',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(), isDense: true,
              ),
              onChanged: _search,
            ),
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
                                SizedBox(width: 100, child: Text(it.itemCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
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
// Screen
// ---------------------------------------------------------------------------
class ImPriceChangeReportScreen extends StatefulWidget {
  const ImPriceChangeReportScreen({super.key});

  @override
  State<ImPriceChangeReportScreen> createState() => _ImPriceChangeReportScreenState();
}

class _ImPriceChangeReportScreenState extends State<ImPriceChangeReportScreen> {
  final _priceGroupSvc = ImPriceGroupService();
  final _priceListSvc = ImPriceListService();
  final _categorySvc = ImItemCategoryService();
  final _reportSvc = ImPriceChangeReportService();
  final _companySvc = CompanyService();
  final _authSvc = AuthService();

  bool _isLoading = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 340.0;
  bool _isDraggingDivider = false;
  int _pdfKey = 0;
  bool _isExporting = false;
  bool _isEnglish = false;

  Company? _company;
  Map<String, String>? _headers;
  String _reportTitle = '';

  List<ImPriceGroup> _priceGroups = [];
  List<ImPriceListHeader> _priceLists = [];
  List<ImItemCategory> _categories = [];

  // Filters
  List<int> _selectedPriceGroupIds = [];
  List<int> _selectedPriceListIds = [];
  List<int> _selectedCategoryIds = [];
  String? _itemCodeFrom;
  String? _itemCodeTo;
  String _fromLabel = '';
  String _toLabel = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<String> _selectedChangeStatuses = []; // ว่าง = ไม่กรอง (แสดงทั้ง 3)
  String _activeStatus = 'ALL';

  List<ImPriceChangeReportRow> _reportData = [];

  static const List<_ChangeStatusOption> _changeStatusOptions = [
    _ChangeStatusOption(0, 'Draft', 'ร่าง'),
    _ChangeStatusOption(1, 'Pending', 'รออนุมัติ'),
    _ChangeStatusOption(2, 'Approved', 'ประวัติการเปลี่ยนแปลง'),
  ];

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    _headers = await _authSvc.getAuthHeader();
    final res = await Future.wait([
      _companySvc.fetchCompany(),
      _priceGroupSvc.fetchActiveRows(),
      _priceListSvc.fetchRows(),
      _categorySvc.fetchActiveRows(),
    ]);
    _company = res[0] as Company?;
    _priceGroups = res[1] as List<ImPriceGroup>;
    _priceLists = res[2] as List<ImPriceListHeader>;
    _categories = (res[3] as List<ImItemCategory>).where((c) => c.categoryType == 'CATEGORY').toList();
    if (mounted) setState(() {});
  }

  // ─── cascade: กลุ่มราคา -> ตารางราคา -> กลุ่มสินค้า ──────────────────────────
  Future<void> _onPriceGroupsChanged(List<int> ids) async {
    setState(() {
      _selectedPriceGroupIds = ids;
      _selectedPriceListIds = [];
      _selectedCategoryIds = [];
    });
    final lists = await _priceListSvc.fetchRows(priceGroupIds: ids.isEmpty ? null : ids);
    if (!mounted) return;
    setState(() => _priceLists = lists);
    await _reloadCategories();
  }

  Future<void> _onPriceListsChanged(List<int> ids) async {
    setState(() {
      _selectedPriceListIds = ids;
      _selectedCategoryIds = [];
    });
    await _reloadCategories();
  }

  Future<void> _reloadCategories() async {
    final cats = await _reportSvc.fetchCategories(priceListIds: _selectedPriceListIds.isEmpty ? null : _selectedPriceListIds);
    if (mounted) setState(() => _categories = cats);
  }

  // ─── pickers ──────────────────────────────────────────────────────────────
  Future<void> _pickPriceGroups() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImPriceGroup>(
        title: isEnglish ? 'Select Price Groups' : 'เลือกกลุ่มราคา',
        items: _priceGroups,
        selected: _selectedPriceGroupIds,
        idOf: (g) => g.id,
        labelOf: (g) => '${g.priceGroupCode}  ${isEnglish && (g.priceGroupNameEn ?? '').isNotEmpty ? g.priceGroupNameEn! : g.priceGroupNameTh}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null) await _onPriceGroupsChanged(result);
  }

  Future<void> _pickPriceLists() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImPriceListHeader>(
        title: isEnglish ? 'Select Price Lists' : 'เลือกตารางราคา',
        items: _priceLists,
        selected: _selectedPriceListIds,
        idOf: (p) => p.id!,
        labelOf: (p) => '${p.priceListCode}  ${p.priceListName}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null) await _onPriceListsChanged(result);
  }

  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImItemCategory>(
        title: isEnglish ? 'Select Item Categories' : 'เลือกกลุ่มสินค้า',
        items: _categories,
        selected: _selectedCategoryIds,
        idOf: (c) => c.id,
        labelOf: (c) => '${c.categoryCode}  ${isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedCategoryIds = result);
  }

  Future<void> _pickChangeStatuses() async {
    final isEnglish = _isEnglish;
    final selectedIds = _changeStatusOptions.where((o) => _selectedChangeStatuses.contains(o.value)).map((o) => o.id).toList();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<_ChangeStatusOption>(
        title: isEnglish ? 'Select Change Status' : 'เลือกรายการเปลี่ยนแปลง',
        items: _changeStatusOptions,
        selected: selectedIds,
        idOf: (o) => o.id,
        labelOf: (o) => isEnglish ? imPriceChangeReportStatusLabel(o.value, true) : o.label,
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedChangeStatuses = _changeStatusOptions.where((o) => result.contains(o.id)).map((o) => o.value).toList());
    }
  }

  Future<void> _pickItem({required bool isFrom}) async {
    final result = await showDialog<ImPriceChangeReportItem>(
      context: context,
      builder: (_) => _ScopedItemPickerDialog(priceListIds: _selectedPriceListIds),
    );
    if (result == null || !mounted) return;
    setState(() {
      final displayName = _isEnglish && (result.itemNameEn ?? '').isNotEmpty ? result.itemNameEn! : result.itemNameTh;
      final label = '${result.itemCode}  $displayName';
      if (isFrom) { _itemCodeFrom = result.itemCode; _fromLabel = label; } else { _itemCodeTo = result.itemCode; _toLabel = label; }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() { if (isFrom) { _dateFrom = picked; } else { _dateTo = picked; } });
  }

  // ─── report generation ────────────────────────────────────────────────────
  Future<void> _generateReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _reportSvc.fetchReport(
        priceGroupIds: _selectedPriceGroupIds.isEmpty ? null : _selectedPriceGroupIds,
        priceListIds: _selectedPriceListIds.isEmpty ? null : _selectedPriceListIds,
        categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds,
        itemCodeFrom: _itemCodeFrom,
        itemCodeTo: _itemCodeTo,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        changeStatuses: _selectedChangeStatuses.isEmpty ? null : _selectedChangeStatuses,
        activeStatus: _activeStatus,
      );
      if (mounted) setState(() { _reportData = data; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _conditionLine(bool isEnglish) {
    final p = <String>[];
    if (_selectedPriceGroupIds.isNotEmpty) {
      final names = _selectedPriceGroupIds.map((id) {
        final g = _priceGroups.firstWhere((g) => g.id == id, orElse: () => _priceGroups.first);
        return isEnglish && (g.priceGroupNameEn ?? '').isNotEmpty ? g.priceGroupNameEn! : g.priceGroupNameTh;
      }).join(', ');
      p.add('${isEnglish ? "Price Group" : "กลุ่มราคา"}: $names');
    }
    if (_selectedPriceListIds.isNotEmpty) {
      final names = _selectedPriceListIds.map((id) {
        final pl = _priceLists.firstWhere((p) => p.id == id, orElse: () => _priceLists.first);
        return pl.priceListCode;
      }).join(', ');
      p.add('${isEnglish ? "Price List" : "ตารางราคา"}: $names');
    }
    if (_selectedCategoryIds.isNotEmpty) {
      final names = _selectedCategoryIds.map((id) {
        final c = _categories.firstWhere((c) => c.id == id, orElse: () => _categories.first);
        return isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh;
      }).join(', ');
      p.add('${isEnglish ? "Category" : "กลุ่มสินค้า"}: $names');
    }
    if (_dateFrom != null || _dateTo != null) {
      String fmt(DateTime? d) => d == null ? '…' : '${d.day}/${d.month}/${d.year}';
      p.add('${isEnglish ? "Effective" : "วันที่มีผล"}: ${fmt(_dateFrom)} - ${fmt(_dateTo)}');
    }
    if (_selectedChangeStatuses.isNotEmpty) {
      final names = _selectedChangeStatuses.map((v) => imPriceChangeReportStatusLabel(v, isEnglish)).join(', ');
      p.add('${isEnglish ? "Status" : "รายการ"}: $names');
    }
    if (_activeStatus != 'ALL') {
      p.add('${isEnglish ? "Active" : "สถานะ"}: ${imPriceChangeActiveStatusLabel(_activeStatus, isEnglish)}');
    }
    return p.isEmpty ? (isEnglish ? 'All conditions' : 'ทุกเงื่อนไข') : p.join('   •   ');
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

    const mg = 18.0;
    final pageW = format.width - mg * 2;

    final wGroup = pageW * 0.08;
    final wList = pageW * 0.09;
    final wCat = pageW * 0.09;
    final wItem = pageW * 0.14;
    final wDate = pageW * 0.11;
    final wChange = pageW * 0.09;
    final wActive = pageW * 0.06;
    final wOld = pageW * 0.07;
    final wUom = pageW * 0.05;
    final wNew = pageW * 0.07;
    final wDiff = pageW * 0.08;
    final wDoc = pageW * 0.07;

    const cGreen = PdfColor(0.87, 0.94, 0.92);
    const cStripe = PdfColor(0.97, 0.97, 0.97);
    const cTotal = PdfColor(0.75, 0.88, 0.96);
    const cGroupTot = PdfColor(0.80, 0.93, 0.88);
    const cBorder = PdfColors.grey400;
    const hp = 2.5, vp = 2.0;

    pw.TextStyle tN(double fs) => pw.TextStyle(font: font, fontSize: fs);
    pw.TextStyle tB(double fs) => pw.TextStyle(font: fontBold, fontSize: fs);

    pw.Widget box(double w, String t, pw.TextStyle s, {pw.TextAlign align = pw.TextAlign.left}) => pw.SizedBox(
          width: w,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: vp),
            child: pw.Text(t, style: s, textAlign: align, softWrap: true, maxLines: 3),
          ),
        );

    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(color: cGreen, border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5))),
      child: pw.Row(children: [
        box(wGroup, isEnglish ? 'Price Group' : 'กลุ่มราคา', tB(8)),
        box(wList, isEnglish ? 'Price List' : 'ตารางราคา', tB(8)),
        box(wCat, isEnglish ? 'Category' : 'กลุ่มสินค้า', tB(8)),
        box(wItem, isEnglish ? 'Item' : 'สินค้า', tB(8)),
        box(wDate, isEnglish ? 'Effective From-To' : 'วันที่มีผลจาก-ถึง', tB(8)),
        box(wChange, isEnglish ? 'Change' : 'รายการ', tB(8)),
        box(wActive, isEnglish ? 'Status' : 'สถานะ', tB(8)),
        box(wOld, isEnglish ? 'Old Price' : 'ราคาเก่า', tB(8), align: pw.TextAlign.right),
        box(wUom, isEnglish ? 'UOM' : 'หน่วยนับ', tB(8)),
        box(wNew, isEnglish ? 'New Price' : 'ราคาใหม่', tB(8), align: pw.TextAlign.right),
        box(wDiff, isEnglish ? '+/-' : 'เพิ่ม/ลด', tB(8), align: pw.TextAlign.right),
        box(wDoc, isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', tB(8)),
      ]),
    );

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
            pw.Expanded(flex: 6, child: pw.Text(reportTitle, textAlign: pw.TextAlign.center, style: tB(14))),
            pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Page" : "หน้า"} ${ctx.pageNumber}/${ctx.pagesCount}', textAlign: pw.TextAlign.right, style: tN(9))),
          ]),
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.Expanded(flex: 9, child: pw.SizedBox()),
            pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed by" : "พิมพ์โดย"} $userName', textAlign: pw.TextAlign.right, style: tN(9))),
          ]),
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.Expanded(flex: 9, child: pw.Text('* $condLine', style: tN(8))),
            pw.Expanded(flex: 3, child: pw.Text('${isEnglish ? "Printed" : "พิมพ์เมื่อ"} $printDateStr', textAlign: pw.TextAlign.right, style: tN(9))),
          ]),
          pw.SizedBox(height: 4),
          tableHeader,
        ]);

    String fmtDate(DateTime? d) => d == null ? '-' : '${d.day}/${d.month}/${d.year}';
    String fmtMoney(double? v) => v == null ? '-' : v.toStringAsFixed(2);

    // จัดกลุ่มตามกลุ่มราคา (แสดงผลเป็นลำดับชั้นให้ตรวจสอบง่าย) — backend เรียงมาตาม price_group_code ให้แล้ว
    final grouped = <String, List<ImPriceChangeReportRow>>{};
    for (final r in _reportData) {
      final key = r.priceGroupCode ?? (isEnglish ? '(No group)' : '(ไม่มีกลุ่มราคา)');
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final content = <pw.Widget>[];
    int globalIdx = 0;
    for (final groupKey in grouped.keys) {
      final rows = grouped[groupKey]!;
      for (final r in rows) {
        final bg = globalIdx.isOdd ? cStripe : null;
        final itemName = isEnglish && (r.itemNameEn ?? '').isNotEmpty ? r.itemNameEn : r.itemNameTh;
        final catName = isEnglish && (r.categoryNameEn ?? '').isNotEmpty ? r.categoryNameEn : r.categoryNameTh;
        final groupName = isEnglish && (r.priceGroupNameEn ?? '').isNotEmpty ? r.priceGroupNameEn : r.priceGroupNameTh;
        final uomName = isEnglish && (r.uomNameEn ?? '').isNotEmpty ? r.uomNameEn : r.uomNameTh;
        final changeTypeLabel = r.changeType == 'PROMOTION' ? (isEnglish ? 'Promo' : 'โปรโมชั่น') : (isEnglish ? 'Revise' : 'ถาวร');
        final changeLabel = '${imPriceChangeReportStatusLabel(r.changeStatus, isEnglish)} ($changeTypeLabel)';
        final activeLabel = r.resultStatus == null ? '-' : imPriceChangeActiveStatusLabel(r.resultStatus!, isEnglish);
        final diffColor = r.changeAmount > 0 ? PdfColors.green800 : (r.changeAmount < 0 ? PdfColors.red800 : PdfColors.black);
        final diffText = '${r.changeAmount >= 0 ? '+' : ''}${r.changeAmount.toStringAsFixed(2)}\n(${r.changePercent >= 0 ? '+' : ''}${r.changePercent.toStringAsFixed(1)}%)';

        content.add(pw.Container(
          color: bg,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3))),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            box(wGroup, '${r.priceGroupCode ?? ''}\n${groupName ?? ''}', tN(7.5)),
            box(wList, '${r.priceListCode ?? ''}\n${r.priceListName ?? ''}', tN(7.5)),
            box(wCat, '${r.categoryCode ?? ''}\n${catName ?? ''}', tN(7.5)),
            box(wItem, '${r.itemCode ?? ''}\n${itemName ?? ''}', tN(7.5)),
            box(wDate, '${fmtDate(r.effectiveFrom)} -\n${fmtDate(r.effectiveTo)}', tN(7.5)),
            box(wChange, changeLabel, tN(7.5)),
            box(wActive, activeLabel, tN(7.5)),
            box(wOld, fmtMoney(r.oldUnitPriceFc), tN(7.5), align: pw.TextAlign.right),
            box(wUom, uomName ?? r.uomCode ?? '', tN(7.5)),
            box(wNew, fmtMoney(r.newUnitPriceFc), tB(7.5), align: pw.TextAlign.right),
            box(wDiff, diffText, pw.TextStyle(font: fontBold, fontSize: 7.5, color: diffColor), align: pw.TextAlign.right),
            box(wDoc, r.changeNo ?? '', tN(7.5)),
          ]),
        ));
        globalIdx++;
      }
      content.add(pw.Container(
        width: pageW,
        color: cGroupTot,
        padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp),
        child: pw.Text(
          isEnglish ? 'Group total $groupKey:  ${rows.length} line(s)' : 'รวมกลุ่มราคา $groupKey:  ${rows.length} รายการ',
          style: tB(8.5),
        ),
      ));
    }

    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp + 1),
      child: pw.Text(isEnglish ? 'Grand total ${_reportData.length} line(s)' : 'รวมทั้งสิ้น ${_reportData.length} รายการ', style: tB(9)),
    ));

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(mg),
      header: pageHeader(),
      build: (ctx) => content,
    ));
    return doc.save();
  }

  // ─── Excel export ─────────────────────────────────────────────────────────
  void _xl(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(backgroundColorHex: bg ?? ExcelColor.none, horizontalAlign: align ?? HorizontalAlign.Left, bold: bold);
  }

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      final sName = isEnglish ? 'PriceChange' : 'เปลี่ยนแปลงราคา';
      ex.rename('Sheet1', sName);
      final s = ex[sName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}');
      _xl(s, 3, 0, '${isEnglish ? "Printed" : "พิมพ์"}: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}');

      final hdrs = isEnglish
          ? ['Price Group', 'Price List', 'Category', 'Item Code', 'Item Name', 'Effective From', 'Effective To', 'Change Status', 'Change Type', 'Active Status', 'Old Price', 'UOM', 'New Price', 'Diff', 'Diff %', 'Doc No.']
          : ['กลุ่มราคา', 'ตารางราคา', 'กลุ่มสินค้า', 'รหัสสินค้า', 'ชื่อสินค้า', 'วันที่มีผลจาก', 'วันที่มีผลถึง', 'รายการ', 'ประเภท', 'สถานะ', 'ราคาเก่า', 'หน่วยนับ', 'ราคาใหม่', 'เพิ่ม/ลด', '%เปลี่ยนแปลง', 'เลขที่เอกสาร'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 5, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 6;
      for (final r in _reportData) {
        final itemName = isEnglish && (r.itemNameEn ?? '').isNotEmpty ? r.itemNameEn : r.itemNameTh;
        final groupName = isEnglish && (r.priceGroupNameEn ?? '').isNotEmpty ? r.priceGroupNameEn : r.priceGroupNameTh;
        final catName = isEnglish && (r.categoryNameEn ?? '').isNotEmpty ? r.categoryNameEn : r.categoryNameTh;
        _xl(s, row, 0, '${r.priceGroupCode ?? ''} ${groupName ?? ''}');
        _xl(s, row, 1, '${r.priceListCode ?? ''} ${r.priceListName ?? ''}');
        _xl(s, row, 2, '${r.categoryCode ?? ''} ${catName ?? ''}');
        _xl(s, row, 3, r.itemCode ?? '');
        _xl(s, row, 4, itemName ?? '');
        _xl(s, row, 5, r.effectiveFrom != null ? DateFormat('dd/MM/yyyy').format(r.effectiveFrom!) : '');
        _xl(s, row, 6, r.effectiveTo != null ? DateFormat('dd/MM/yyyy').format(r.effectiveTo!) : '');
        _xl(s, row, 7, imPriceChangeReportStatusLabel(r.changeStatus, isEnglish));
        _xl(s, row, 8, r.changeType == 'PROMOTION' ? (isEnglish ? 'Promotion' : 'โปรโมชั่น') : (isEnglish ? 'Revise' : 'ถาวร'));
        _xl(s, row, 9, r.resultStatus == null ? '-' : imPriceChangeActiveStatusLabel(r.resultStatus!, isEnglish));
        _xl(s, row, 10, r.oldUnitPriceFc ?? 0);
        _xl(s, row, 11, r.uomCode ?? '');
        _xl(s, row, 12, r.newUnitPriceFc);
        _xl(s, row, 13, r.changeAmount);
        _xl(s, row, 14, '${r.changePercent.toStringAsFixed(1)}%');
        _xl(s, row, 15, r.changeNo ?? '');
        row++;
      }

      _xl(s, row, 0, isEnglish ? 'Grand total ${_reportData.length} line(s)' : 'รวมทั้งสิ้น ${_reportData.length} รายการ', bg: totBg, bold: true);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, isEnglish ? 'PriceChangeReport_$ts.xlsx' : 'รายงานตรวจเช็คการเปลี่ยนแปลงราคา_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────
  Widget _buildMultiField({required String label, required int count, required String allLabel, required VoidCallback onTap, required VoidCallback onClear}) {
    final hasValue = count > 0;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue) InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
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

  Widget _buildPickerField({required String label, required String displayText, required VoidCallback onTap, required VoidCallback onClear}) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue) InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onTap, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.search, size: 18, color: Colors.orange))),
        ]),
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          hasValue ? displayText : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, required DateTime? date, required VoidCallback onPick, required VoidCallback onClear}) {
    final text = date == null ? '' : '${date.day}/${date.month}/${date.year}';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (text.isNotEmpty) InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(onTap: onPick, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.calendar_today, size: 16))),
        ]),
      ),
      child: InkWell(onTap: onPick, child: Text(text.isEmpty ? (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : text, style: const TextStyle(fontSize: 13))),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildMultiField(
                label: isEnglish ? 'Price Group' : 'กลุ่มราคา',
                count: _selectedPriceGroupIds.length,
                allLabel: isEnglish ? 'All price groups' : 'ทุกกลุ่มราคา',
                onTap: _pickPriceGroups,
                onClear: () => _onPriceGroupsChanged([]),
              ),
              const SizedBox(height: 12),
              _buildMultiField(
                label: isEnglish ? 'Price List' : 'ตารางราคา',
                count: _selectedPriceListIds.length,
                allLabel: isEnglish ? 'All price lists' : 'ทุกตารางราคา',
                onTap: _pickPriceLists,
                onClear: () => _onPriceListsChanged([]),
              ),
              const SizedBox(height: 12),
              _buildMultiField(
                label: isEnglish ? 'Item Category' : 'กลุ่มสินค้า',
                count: _selectedCategoryIds.length,
                allLabel: isEnglish ? 'All categories' : 'ทุกกลุ่มสินค้า',
                onTap: _pickCategories,
                onClear: () => setState(() => _selectedCategoryIds = []),
              ),
              const SizedBox(height: 12),
              _buildPickerField(
                label: isEnglish ? 'Item Code From' : 'รหัสสินค้าจาก',
                displayText: _fromLabel,
                onTap: () => _pickItem(isFrom: true),
                onClear: () => setState(() { _itemCodeFrom = null; _fromLabel = ''; }),
              ),
              const SizedBox(height: 8),
              _buildPickerField(
                label: isEnglish ? 'Item Code To' : 'รหัสสินค้าถึง',
                displayText: _toLabel,
                onTap: () => _pickItem(isFrom: false),
                onClear: () => setState(() { _itemCodeTo = null; _toLabel = ''; }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildDateField(label: isEnglish ? 'Effective From' : 'วันที่มีผลจาก', date: _dateFrom, onPick: () => _pickDate(isFrom: true), onClear: () => setState(() => _dateFrom = null))),
                const SizedBox(width: 8),
                Expanded(child: _buildDateField(label: isEnglish ? 'Effective To' : 'วันที่มีผลถึง', date: _dateTo, onPick: () => _pickDate(isFrom: false), onClear: () => setState(() => _dateTo = null))),
              ]),
              const SizedBox(height: 12),
              _buildMultiField(
                label: isEnglish ? 'Change Status' : 'รายการเปลี่ยนแปลง',
                count: _selectedChangeStatuses.length,
                allLabel: isEnglish ? 'All (Draft/Pending/History)' : 'ทั้งหมด (ร่าง/รออนุมัติ/ประวัติ)',
                onTap: _pickChangeStatuses,
                onClear: () => setState(() => _selectedChangeStatuses = []),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _activeStatus,
                isExpanded: true,
                decoration: InputDecoration(labelText: isEnglish ? 'Status' : 'สถานะ', border: const OutlineInputBorder(), isDense: true),
                items: imPriceChangeActiveStatuses.map((s) => DropdownMenuItem(value: s, child: Text(imPriceChangeActiveStatusLabel(s, isEnglish)))).toList(),
                onChanged: (v) => setState(() => _activeStatus = v ?? 'ALL'),
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
              onPressed: _isLoading ? null : _generateReport,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Price Change Audit Report' : 'รายงานตรวจเช็คการเปลี่ยนแปลงราคา'));
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.orange[700],
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
        final maxFW = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              color: Colors.orange[700],
              child: IconButton(
                icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            AnimatedContainer(
              duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
              width: _isFilterExpanded ? _filterPanelWidth : 0.0,
              child: ClipRect(
                child: OverflowBox(maxWidth: _filterPanelWidth, minWidth: _filterPanelWidth, alignment: Alignment.topLeft, child: _buildFilterPanel()),
              ),
            ),
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() => _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFW)),
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
                        ? Center(child: Text(isEnglish ? 'Please select conditions and click Generate Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลรายงาน'))
                        : ZoomablePdfPreview(
                            documentVersion: _pdfKey,
                            build: (fmt) => _generatePdf(fmt),
                            initialPageFormat: PdfPageFormat.a4.landscape,
                            canChangeOrientation: true,
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
