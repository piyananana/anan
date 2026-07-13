import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/ap_vendor.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_vendor_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../utils/file_download.dart';

// ---------------------------------------------------------------------------
// Category enum
// ---------------------------------------------------------------------------
enum _Category {
  generalInfo,
  address,
  contact,
  bankAccount,
  apAccount,
}

extension _CatLabel on _Category {
  String get label {
    switch (this) {
      case _Category.generalInfo: return 'ข้อมูลทั่วไป';
      case _Category.address:     return 'ที่อยู่';
      case _Category.contact:     return 'ผู้ติดต่อ';
      case _Category.bankAccount: return 'บัญชีธนาคาร';
      case _Category.apAccount:   return 'รหัสบัญชีเจ้าหนี้';
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ApVendorReportScreen extends StatefulWidget {
  const ApVendorReportScreen({super.key});

  @override
  State<ApVendorReportScreen> createState() => _ApVendorReportScreenState();
}

class _ApVendorReportScreenState extends State<ApVendorReportScreen> {
  final _vendorSvc  = ApVendorService();
  final _companySvc = CompanyService();
  final _authSvc    = AuthService();
  final _groupSvc   = ApVendorGroupService();

  bool   _isLoading         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 330.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;

  Company?             _company;
  Map<String, String>? _headers;
  List<ApVendorGroup>  _groups = [];

  // Filters
  List<int>       _selectedGroupIds = [];
  String?         _vendorCodeFrom;
  String?         _vendorCodeTo;
  String          _fromLabel = '';
  String          _toLabel   = '';
  String          _status    = '';   // '' | 'active' | 'inactive'
  List<_Category> _selectedCategories = [];

  List<ApVendor> _reportData = [];

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
      _groupSvc.fetchActiveRows(),
    ]);
    _company = res[0] as Company?;
    _groups  = res[1] as List<ApVendorGroup>;
    if (mounted) setState(() {});
  }

  // ─── report generation ────────────────────────────────────────────────────

  Future<void> _generateReport() async {
    setState(() { _isLoading = true; _reportData = []; });
    try {
      final list = await _vendorSvc.fetchReport(
        groupIds:  _selectedGroupIds,
        codeFrom:  _vendorCodeFrom,
        codeTo:    _vendorCodeTo,
        status:    _status,
      );

      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
      }
      if (mounted) setState(() { _reportData = list; _pdfKey++; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── formatters ───────────────────────────────────────────────────────────

  static String _addressStr(ApVendorAddress a) {
    const typeLabel = {
      'billing':      'ใบแจ้งหนี้',
      'shipping':     'จัดส่ง',
      'billing note': 'วางบิล',
      'payment':      'ชำระเงิน',
    };
    final t = typeLabel[a.addressType] ?? a.addressType;
    final parts = [
      '[$t]${a.isDefault ? "(หลัก)" : ""}',
      if ((a.addressNo ?? '').isNotEmpty) a.addressNo!,
      if ((a.addressBuildingVillage ?? '').isNotEmpty) a.addressBuildingVillage!,
      if ((a.addressAlley ?? '').isNotEmpty) 'ซ.${a.addressAlley}',
      if ((a.addressRoad ?? '').isNotEmpty) 'ถ.${a.addressRoad}',
      if ((a.addressSubDistrict ?? '').isNotEmpty) a.addressSubDistrict!,
      if ((a.addressDistrict ?? '').isNotEmpty) a.addressDistrict!,
      if ((a.addressProvince ?? '').isNotEmpty) a.addressProvince!,
      if ((a.addressZipCode ?? '').isNotEmpty) a.addressZipCode!,
      if ((a.addressCountry ?? '').isNotEmpty && a.addressCountry != 'Thailand')
        a.addressCountry!,
    ];
    return parts.join(' ');
  }

  static String _contactStr(ApVendorContact ct) {
    return [
      if (ct.isDefault) '(หลัก)',
      ct.contactName,
      if ((ct.position ?? '').isNotEmpty) ct.position!,
      if ((ct.phone  ?? '').isNotEmpty) 'โทร:${ct.phone}',
      if ((ct.mobile ?? '').isNotEmpty) 'มือถือ:${ct.mobile}',
      if ((ct.email  ?? '').isNotEmpty) 'Email:${ct.email}',
    ].join('  ');
  }

  static String _bankStr(ApVendorBankAccount ba) {
    final t = ba.accountType == 'current' ? 'กระแสรายวัน'
            : ba.accountType == 'savings'  ? 'ออมทรัพย์' : ba.accountType;
    return [
      if (ba.isDefault) '(หลัก)',
      '${ba.bankName ?? ""}${(ba.branchName ?? "").isNotEmpty ? " สาขา ${ba.branchName}" : ""}',
      if ((ba.accountNumber ?? '').isNotEmpty) 'เลขบัญชี:${ba.accountNumber}',
      if ((ba.accountName   ?? '').isNotEmpty) 'ชื่อ:${ba.accountName}',
      '[$t]',
    ].where((s) => s.trim().isNotEmpty).join('  ');
  }

  List<String> _catLines(ApVendor v, _Category cat) {
    switch (cat) {
      case _Category.generalInfo:
        final p = <String>[];
        if ((v.taxId ?? '').isNotEmpty) {
          p.add('เลขผู้เสียภาษี: ${v.taxId}');
        }
        final vtLabel = v.vendorType == 'individual' ? 'บุคคลธรรมดา'
                      : v.vendorType == 'juristic'   ? 'นิติบุคคล'
                      : null;
        if (vtLabel != null) p.add('ประเภทผู้ขาย: $vtLabel');
        if ((v.businessTypeNameThai ?? '').isNotEmpty) {
          p.add('ประเภทธุรกิจ: ${v.businessTypeCode} ${v.businessTypeNameThai}');
        }
        if ((v.vendorGroupName ?? '').isNotEmpty) {
          p.add('กลุ่มผู้ขาย: ${v.vendorGroupCode} ${v.vendorGroupName}');
        }
        p.add('สกุลเงิน: ${v.currencyCode}');
        final credit = [
          if (v.creditTermMonths > 0) '${v.creditTermMonths} เดือน',
          if (v.creditTermDays   > 0) '${v.creditTermDays} วัน',
        ].join(' ');
        if (credit.isNotEmpty) p.add('เครดิต: $credit');
        if (v.creditLimit > 0) {
          final fmtCL = NumberFormat('#,##0.00', 'en_US');
          p.add('วงเงินเครดิต: ${fmtCL.format(v.creditLimit)}');
        }
        p.add('สถานะ: ${v.isActive ? "ใช้งาน" : "ไม่ใช้งาน"}');
        if ((v.remark ?? '').isNotEmpty) p.add('หมายเหตุ: ${v.remark}');
        return [p.join('  |  ')];

      case _Category.address:
        return v.addresses.isEmpty
            ? ['(ไม่มีที่อยู่)']
            : v.addresses.map(_addressStr).toList();

      case _Category.contact:
        return v.contacts.isEmpty
            ? ['(ไม่มีผู้ติดต่อ)']
            : v.contacts.map(_contactStr).toList();

      case _Category.bankAccount:
        return v.bankAccounts.isEmpty
            ? ['(ไม่มีบัญชีธนาคาร)']
            : v.bankAccounts.map(_bankStr).toList();

      case _Category.apAccount:
        if ((v.apAccountCode ?? '').isNotEmpty) {
          return ['บัญชีเจ้าหนี้: ${v.apAccountCode} ${v.apAccountNameThai ?? ""}'];
        }
        return ['(ไม่ระบุรหัสบัญชีเจ้าหนี้)'];
    }
  }

  String _conditionLine() {
    final p = <String>[];
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        try { return _groups.firstWhere((g) => g.id == id).groupNameThai; }
        catch (_) { return '$id'; }
      }).join(', ');
      p.add('กลุ่ม: $names');
    }
    if ((_vendorCodeFrom ?? '').isNotEmpty || (_vendorCodeTo ?? '').isNotEmpty) {
      final f = (_vendorCodeFrom ?? '').isEmpty ? '(ทั้งหมด)' : _vendorCodeFrom!;
      final t = (_vendorCodeTo   ?? '').isEmpty ? '(ทั้งหมด)' : _vendorCodeTo!;
      p.add('รหัส: $f – $t');
    }
    if (_status == 'active')   p.add('สถานะ: ใช้งาน');
    if (_status == 'inactive') p.add('สถานะ: ไม่ใช้งาน');
    return p.isEmpty ? 'ทั้งหมด' : p.join(' | ');
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font         = pw.Font.ttf(fontData);
    final fontBold     = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final condLine     = _conditionLine();

    const mg   = 20.0;
    final pageW = format.width - mg * 2;

    final codeW   = pageW * 0.14;
    final nameTHW = pageW * 0.36;
    final nameENW = pageW * 0.31;
    final oldW    = pageW * 0.19;

    const cGreen    = PdfColor(0.82, 0.91, 0.96);  // blue tint for AP
    const cStripe   = PdfColor(0.97, 0.97, 0.97);
    const cGroupTot = PdfColor(0.76, 0.90, 0.97);
    const cTotal    = PdfColor(0.65, 0.81, 0.93);
    const cBorder   = PdfColors.grey400;
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
        box(codeW,   'รหัสผู้ขาย',          tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(nameTHW, 'ชื่อผู้ขาย (ไทย)',     tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(nameENW, 'ชื่อผู้ขาย (อังกฤษ)',  tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(oldW,    'รหัสเก่า',              tB(9)),
      ]),
    );

    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
        pw.Expanded(flex: 6, child: pw.Text('รายงานข้อมูลผู้ขาย',
            textAlign: pw.TextAlign.center, style: tB(15))),
        pw.Expanded(flex: 3, child: pw.Text('หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        pw.Expanded(flex: 9, child: pw.SizedBox()),
        pw.Expanded(flex: 3, child: pw.Text('พิมพ์โดย $userName',
            textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 2),
      pw.Row(children: [
        pw.Expanded(flex: 9,
            child: pw.Text('* $condLine', style: tN(9))),
        pw.Expanded(flex: 3,
            child: pw.Text('พิมพ์เมื่อ $printDateStr',
                textAlign: pw.TextAlign.right, style: tN(10))),
      ]),
      pw.SizedBox(height: 4),
      tableHeader,
    ]);

    // จัดกลุ่มผู้ขายตาม vendorGroupCode
    final grouped = <String, List<ApVendor>>{};
    for (final v in _reportData) {
      final key = v.vendorGroupCode ?? '';
      grouped.putIfAbsent(key, () => []).add(v);
    }
    final sortedGroupKeys = grouped.keys.toList()..sort();

    final content = <pw.Widget>[];
    int globalIdx = 0;

    for (final groupKey in sortedGroupKeys) {
      final groupVendors = grouped[groupKey]!;

      for (final v in groupVendors) {
        final bg = globalIdx.isOdd ? cStripe : null;

        content.add(pw.Container(
          color: bg,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3)),
          ),
          child: pw.Row(children: [
            box(codeW,   v.vendorCode,         tB(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(nameTHW, v.vendorNameTh,        tN(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(nameENW, v.vendorNameEn ?? '',   tN(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(oldW,    v.oldVendorCode ?? '',  tN(9)),
          ]),
        ));

        for (final cat in _selectedCategories) {
          final lines = _catLines(v, cat);
          content.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: 2),
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(
                  text: '${cat.label}  ',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      decoration: pw.TextDecoration.underline),
                ),
                pw.TextSpan(
                  text: lines.join('  |  '),
                  style: pw.TextStyle(font: font, fontSize: 8.5),
                ),
              ]),
            ),
          ));
        }

        if (_selectedCategories.isNotEmpty) {
          content.add(pw.Divider(height: 0.5, color: PdfColors.grey400));
        }
        globalIdx++;
      }

      final first      = groupVendors.first;
      final groupLabel = groupKey.isEmpty
          ? '(ไม่ระบุกลุ่ม)'
          : '$groupKey  ${first.vendorGroupName ?? ""}';
      content.add(pw.Container(
        width: pageW,
        color: cGroupTot,
        padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp),
        child: pw.Text('รวมกลุ่ม $groupLabel:  ${groupVendors.length} ผู้ขาย',
            style: tB(9)),
      ));
    }

    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp + 1),
      child: pw.Text('รวมทั้งสิ้น ${_reportData.length} ผู้ขาย', style: tB(9)),
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
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      const sName = 'ผู้ขาย';
      ex.rename('Sheet1', sName);
      final s = ex[sName];

      final hdrBg = ExcelColor.fromHexString('#4DA3D4');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final catBg = ExcelColor.fromHexString('#D0E4F7');

      _xl(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xl(s, 1, 0, 'รายงานข้อมูลผู้ขาย', bold: true);
      _xl(s, 2, 0, 'เงื่อนไข: ${_conditionLine()}');
      _xl(s, 3, 0, 'พิมพ์: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}');

      const hdrs = ['รหัสผู้ขาย', 'ชื่อผู้ขาย (ไทย)', 'ชื่อผู้ขาย (อังกฤษ)', 'รหัสเก่า'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 5, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }
      if (_selectedCategories.isNotEmpty) {
        _xl(s, 5, 4, 'หมวด', bg: hdrBg, bold: true);
        _xl(s, 5, 5, 'รายละเอียด', bg: hdrBg, bold: true);
      }

      int row = 6;
      for (final v in _reportData) {
        if (_selectedCategories.isEmpty) {
          _xl(s, row, 0, v.vendorCode);
          _xl(s, row, 1, v.vendorNameTh);
          _xl(s, row, 2, v.vendorNameEn ?? '');
          _xl(s, row, 3, v.oldVendorCode ?? '');
          row++;
        } else {
          bool firstCat = true;
          for (final cat in _selectedCategories) {
            final lines = _catLines(v, cat);
            for (int li = 0; li < lines.length; li++) {
              if (firstCat && li == 0) {
                _xl(s, row, 0, v.vendorCode);
                _xl(s, row, 1, v.vendorNameTh);
                _xl(s, row, 2, v.vendorNameEn ?? '');
                _xl(s, row, 3, v.oldVendorCode ?? '');
                firstCat = false;
              }
              _xl(s, row, 4, cat.label, bg: catBg);
              _xl(s, row, 5, lines[li]);
              row++;
            }
          }
        }
      }

      _xl(s, row, 0, 'รวมทั้งสิ้น ${_reportData.length} ผู้ขาย',
          bg: totBg, bold: true);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'รายงานข้อมูลผู้ขาย_$ts.xlsx');
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

  Future<void> _pickVendor({required bool isFrom}) async {
    final result = await showDialog<ApVendor>(
      context: context,
      builder: (_) => const _VendorPickerDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      final label = '${result.vendorCode}  ${result.vendorNameTh}';
      if (isFrom) {
        _vendorCodeFrom = result.vendorCode;
        _fromLabel      = label;
      } else {
        _vendorCodeTo = result.vendorCode;
        _toLabel      = label;
      }
    });
  }

  Future<void> _pickGroups() async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ApVendorGroup>(
        title: 'เลือกกลุ่มผู้ขาย',
        items: _groups,
        selected: _selectedGroupIds,
        idOf: (g) => g.id!,
        labelOf: (g) => '${g.groupCode}  ${g.groupNameThai}',
      ),
    );
    if (result != null && mounted) setState(() => _selectedGroupIds = result);
  }

  Future<void> _pickCategories() async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<_Category>(
        title: 'เลือกหมวดรายละเอียด',
        items: _Category.values,
        selected: _selectedCategories.map((c) => c.index).toList(),
        idOf: (c) => c.index,
        labelOf: (c) => c.label,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategories =
          result.map((i) => _Category.values[i]).toList());
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
                  child: Icon(Icons.search, size: 18,
                      color: Colors.blue[700]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : '— ทั้งหมด —',
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
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
          hasValue ? 'เลือก $count รายการ' : allLabel,
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('เงื่อนไขรายงาน',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),

                // กลุ่มผู้ขาย (multi-select)
                _buildMultiField(
                  label: 'กลุ่มผู้ขาย',
                  count: _selectedGroupIds.length,
                  allLabel: '— ทุกกลุ่ม —',
                  onTap: _pickGroups,
                  onClear: () => setState(() => _selectedGroupIds = []),
                ),
                const SizedBox(height: 12),

                // รหัสผู้ขาย ตั้งแต่ / ถึง
                _buildPickerField(
                  label: 'รหัสผู้ขาย ตั้งแต่',
                  displayText: _fromLabel,
                  onPick: () => _pickVendor(isFrom: true),
                  onClear: () => setState(() {
                    _vendorCodeFrom = null;
                    _fromLabel = '';
                  }),
                ),
                const SizedBox(height: 8),
                _buildPickerField(
                  label: 'รหัสผู้ขาย ถึง',
                  displayText: _toLabel,
                  onPick: () => _pickVendor(isFrom: false),
                  onClear: () => setState(() {
                    _vendorCodeTo = null;
                    _toLabel = '';
                  }),
                ),
                const SizedBox(height: 12),

                // สถานะ
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                      labelText: 'สถานะ',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('— ทั้งหมด —')),
                    DropdownMenuItem(value: 'active',   child: Text('ใช้งาน')),
                    DropdownMenuItem(value: 'inactive', child: Text('ไม่ใช้งาน')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _status = v); },
                ),
                const SizedBox(height: 12),

                // หมวด (multi-select)
                _buildMultiField(
                  label: 'หมวดรายละเอียด',
                  count: _selectedCategories.length,
                  allLabel: '— ข้อมูลหลักเท่านั้น —',
                  onTap: _pickCategories,
                  onClear: () => setState(() => _selectedCategories = []),
                ),
                if (_selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: _selectedCategories.map((cat) => Chip(
                      label: Text(cat.label,
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.blue[50],
                      side: BorderSide(color: Colors.blue[200]!),
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
              label: const Text('ประมวลผลรายงาน'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: _reportData.isEmpty ? null : _exportExcel,
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
                  // Toggle button
                  Container(
                    width: 36,
                    color: Colors.blue[700],
                    child: IconButton(
                      icon: Icon(
                          _isFilterExpanded
                              ? Icons.filter_list_off
                              : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
                      onPressed: () =>
                          setState(() => _isFilterExpanded = !_isFilterExpanded),
                    ),
                  ),
                  // Filter panel
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
                        child: _buildFilterPanel(),
                      ),
                    ),
                  ),
                  // Draggable divider
                  if (_isFilterExpanded)
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        onHorizontalDragStart: (_) =>
                            setState(() => _isDraggingDivider = true),
                        onHorizontalDragUpdate: (d) => setState(() {
                          _filterPanelWidth =
                              (_filterPanelWidth + d.delta.dx)
                                  .clamp(200.0, maxFW);
                        }),
                        onHorizontalDragEnd: (_) =>
                            setState(() => _isDraggingDivider = false),
                        child: Container(width: 5, color: Colors.grey[400]),
                      ),
                    ),
                  // PDF preview
                  Expanded(
                    child: Container(
                      color: Colors.grey[200],
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _reportData.isEmpty
                              ? const Center(
                                  child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                              : PdfPreview(
                                  key: ValueKey(_pdfKey),
                                  build: (fmt) => _generatePdf(fmt),
                                  initialPageFormat: PdfPageFormat.a4,
                                  canChangeOrientation: false,
                                  canDebug: false,
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
// Vendor picker dialog
// ---------------------------------------------------------------------------
class _VendorPickerDialog extends StatefulWidget {
  const _VendorPickerDialog();

  @override
  State<_VendorPickerDialog> createState() => _VendorPickerDialogState();
}

class _VendorPickerDialogState extends State<_VendorPickerDialog> {
  final _ctrl = TextEditingController();
  final _svc  = ApVendorService();
  List<ApVendor> _list    = [];
  bool           _loading = false;

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
      final list = await _svc.fetchRows(search: q.trim().isEmpty ? null : q.trim());
      if (mounted) setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue[700],
            child: const Text('ค้นหาผู้ขาย',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'ค้นหาจากรหัสหรือชื่อผู้ขาย',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: _search,
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(children: [
              SizedBox(width: 100,
                  child: Text('รหัส',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('ชื่อผู้ขาย',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(
                        child: Text('ไม่พบข้อมูล',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 12),
                        itemBuilder: (ctx, i) {
                          final v = _list[i];
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, v),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 100,
                                    child: Text(v.vendorCode,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500))),
                                Expanded(
                                    child: Text(v.vendorNameTh,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          );
                        }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel)),
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

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 400, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue[700],
            child: Text(widget.title,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: ListView(
              children: widget.items.map((item) {
                final id = widget.idOf(item);
                return CheckboxListTile(
                  dense: true,
                  title: Text(widget.labelOf(item),
                      style: const TextStyle(fontSize: 13)),
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
                    ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด'),
              ),
              Row(children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel)),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white),
                  child: const Text('ตกลง'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
