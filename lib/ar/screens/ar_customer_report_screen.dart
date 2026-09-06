import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../../cd/models/cd_salesperson.dart';
import '../../cd/services/cd_salesperson_service.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_company_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/file_download.dart';

// ---------------------------------------------------------------------------
// Category enum
// ---------------------------------------------------------------------------
enum _Category {
  generalInfo,
  salesTerritory,
  billingCondition,
  paymentCondition,
  address,
  contact,
  bankAccount,
  arAccount,
}

extension _CatLabel on _Category {
  String label(bool isEnglish) {
    switch (this) {
      case _Category.generalInfo:      return isEnglish ? 'General Information'          : 'ข้อมูลทั่วไป';
      case _Category.salesTerritory:   return isEnglish ? 'Sales Territory & Salesperson' : 'เขตการขายและพนักงานขาย';
      case _Category.billingCondition: return isEnglish ? 'Billing Condition'             : 'เงื่อนไขการวางบิล';
      case _Category.paymentCondition: return isEnglish ? 'Payment Condition'             : 'เงื่อนไขการรับชำระเงิน';
      case _Category.address:          return isEnglish ? 'Address'                       : 'ที่อยู่';
      case _Category.contact:          return isEnglish ? 'Contact'                       : 'ผู้ติดต่อ';
      case _Category.bankAccount:      return isEnglish ? 'Bank Account'                  : 'บัญชีธนาคาร';
      case _Category.arAccount:        return isEnglish ? 'AR Account Code'               : 'รหัสบัญชีลูกหนี้';
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ArCustomerReportScreen extends StatefulWidget {
  const ArCustomerReportScreen({super.key});

  @override
  State<ArCustomerReportScreen> createState() => _ArCustomerReportScreenState();
}

class _ArCustomerReportScreenState extends State<ArCustomerReportScreen> {
  final _customerSvc    = ArCustomerService();
  final _companySvc     = CompanyService();
  final _authSvc        = AuthService();
  final _groupSvc       = ArCustomerGroupService();
  final _salespersonSvc = SalespersonService();

  bool   _isLoading         = false;
  bool   _isFilterExpanded  = true;
  double _filterPanelWidth  = 330.0;
  bool   _isDraggingDivider = false;
  int    _pdfKey            = 0;
  bool   _isExporting       = false;
  bool   _isEnglish         = false;

  Company?              _company;
  Map<String, String>?  _headers;
  // ชื่อรายงาน — ใช้ชื่อเมนู (จาก AppBar/MenuTitle) แทนข้อความ hardcode เพื่อให้ตรงกับที่ผู้ใช้เห็นบนแท็บเสมอ
  String _reportTitle = '';
  List<ArCustomerGroup> _groups      = [];
  List<Salesperson>     _salespersons = [];

  // Filters
  List<int>      _selectedGroupIds      = [];
  int?           _selectedSalespersonId;
  String?        _customerCodeFrom;
  String?        _customerCodeTo;
  String         _fromLabel             = '';
  String         _toLabel               = '';
  String         _status                = '';   // '' | 'active' | 'inactive'
  List<_Category> _selectedCategories  = [];

  List<ArCustomer> _reportData = [];

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
      _salespersonSvc.fetchRows(),
    ]);
    _company      = res[0] as Company?;
    _groups       = res[1] as List<ArCustomerGroup>;
    _salespersons = (res[2] as List<Salesperson>)
        .where((s) => s.isActive).toList();
    if (mounted) setState(() {});
  }

  // ─── report generation ────────────────────────────────────────────────────

  bool _needsFullData() => _selectedCategories.any((c) => const {
        _Category.billingCondition,
        _Category.paymentCondition,
        _Category.address,
        _Category.contact,
        _Category.bankAccount,
      }.contains(c));

  Future<void> _generateReport() async {
    final isEnglish = _isEnglish;
    setState(() { _isLoading = true; _reportData = []; });
    try {
      var list = await _customerSvc.fetchRows();

      if (_selectedGroupIds.isNotEmpty) {
        list = list
            .where((c) =>
                c.customerGroupId != null &&
                _selectedGroupIds.contains(c.customerGroupId))
            .toList();
      }
      if (_selectedSalespersonId != null) {
        list = list
            .where((c) => c.salespersonId == _selectedSalespersonId)
            .toList();
      }
      if ((_customerCodeFrom ?? '').isNotEmpty) {
        list = list
            .where((c) => c.customerCode.compareTo(_customerCodeFrom!) >= 0)
            .toList();
      }
      if ((_customerCodeTo ?? '').isNotEmpty) {
        list = list
            .where((c) => c.customerCode.compareTo(_customerCodeTo!) <= 0)
            .toList();
      }
      if (_status == 'active')   list = list.where((c) =>  c.isActive).toList();
      if (_status == 'inactive') list = list.where((c) => !c.isActive).toList();

      list.sort((a, b) => a.customerCode.compareTo(b.customerCode));

      List<ArCustomer> finalList = list;
      if (_needsFullData() && list.isNotEmpty) {
        final futures = list.map((c) async {
          if (c.id == null) return c;
          try { return await _customerSvc.fetchRow(c.id!); } catch (_) { return c; }
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
            content: Text(
                isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── formatters ───────────────────────────────────────────────────────────

  static String _billingCondStr(ArCustomerBillingCondition bc, bool isEnglish) {
    final p = <String>[];
    if (bc.billWithDelivery) {
      p.add(isEnglish ? 'Bill together with delivery' : 'วางบิลพร้อมส่งของ');
    } else {
      if (bc.billingDayOfMonth.isNotEmpty) {
        p.add('${isEnglish ? "Date" : "วันที่"}: ${bc.billingDayOfMonth.map((d) => d == 31 ? (isEnglish ? "End of month" : "สิ้นเดือน") : "$d").join(", ")}');
      }
      if (bc.billingDayOfWeek.isNotEmpty) {
        final dow = isEnglish
            ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
        p.add('${isEnglish ? "Day" : "วัน"}: ${bc.billingDayOfWeek.map((d) => dow[d]).join(", ")}');
      }
      if (bc.billingWeekOfMonth.isNotEmpty) {
        p.add('${isEnglish ? "Week" : "สัปดาห์"}: ${bc.billingWeekOfMonth.map((w) => w == -1 ? (isEnglish ? "Last" : "สุดท้าย") : (isEnglish ? "$w" : "ที่$w")).join(", ")}');
      }
    }
    if ((bc.billingTimeFrom ?? '').isNotEmpty || (bc.billingTimeTo ?? '').isNotEmpty) {
      p.add('${isEnglish ? "Time" : "เวลา"}: ${bc.billingTimeFrom ?? ""}–${bc.billingTimeTo ?? ""}');
    }
    if (bc.dueFromBillingDate) {
      p.add(isEnglish ? 'Due date from billing date' : 'Due จากวันวางบิล');
    }
    if ((bc.remark ?? '').isNotEmpty) p.add('${isEnglish ? "Remark" : "หมายเหตุ"}: ${bc.remark}');
    return p.isEmpty ? (isEnglish ? '(Not specified)' : '(ไม่ระบุรายละเอียด)') : p.join('  |  ');
  }

  static String _paymentCondStr(ArCustomerPaymentCondition pc, bool isEnglish) {
    final p = <String>[];
    if (pc.paymentDayOfMonth.isNotEmpty) {
      p.add('${isEnglish ? "Date" : "วันที่"}: ${pc.paymentDayOfMonth.map((d) => d == 31 ? (isEnglish ? "End of month" : "สิ้นเดือน") : "$d").join(", ")}');
    }
    if (pc.paymentDayOfWeek.isNotEmpty) {
      final dow = isEnglish
          ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
          : ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
      p.add('${isEnglish ? "Day" : "วัน"}: ${pc.paymentDayOfWeek.map((d) => dow[d]).join(", ")}');
    }
    if (pc.paymentWeekOfMonth.isNotEmpty) {
      p.add('${isEnglish ? "Week" : "สัปดาห์"}: ${pc.paymentWeekOfMonth.map((w) => w == -1 ? (isEnglish ? "Last" : "สุดท้าย") : (isEnglish ? "$w" : "ที่$w")).join(", ")}');
    }
    if ((pc.paymentTimeFrom ?? '').isNotEmpty || (pc.paymentTimeTo ?? '').isNotEmpty) {
      p.add('${isEnglish ? "Time" : "เวลา"}: ${pc.paymentTimeFrom ?? ""}–${pc.paymentTimeTo ?? ""}');
    }
    if (pc.withinMonthsFromBilling > 0) {
      p.add(isEnglish ? 'Within ${pc.withinMonthsFromBilling} month(s)' : 'ภายใน ${pc.withinMonthsFromBilling} เดือน');
    }
    if (pc.additionalDays != 0) {
      p.add(isEnglish ? 'Plus ${pc.additionalDays} day(s)' : 'บวก ${pc.additionalDays} วัน');
    }
    if ((pc.remark ?? '').isNotEmpty) p.add('${isEnglish ? "Remark" : "หมายเหตุ"}: ${pc.remark}');
    return p.isEmpty ? (isEnglish ? '(Not specified)' : '(ไม่ระบุรายละเอียด)') : p.join('  |  ');
  }

  static String _addressStr(ArCustomerAddress a, bool isEnglish) {
    final typeName = isEnglish
        ? {'billing': 'Billing', 'shipping': 'Shipping', 'main': 'Main'}[a.addressType] ?? a.addressType
        : {'billing': 'วางบิล', 'shipping': 'จัดส่ง', 'main': 'หลัก'}[a.addressType] ?? a.addressType;
    final parts = [
      '[$typeName]${a.isDefault ? "(default)" : ""}',
      if ((a.addressNo ?? '').isNotEmpty) a.addressNo!,
      if ((a.addressBuildingVillage ?? '').isNotEmpty) a.addressBuildingVillage!,
      if ((a.addressAlley ?? '').isNotEmpty) '${isEnglish ? "Soi" : "ซ."}${a.addressAlley}',
      if ((a.addressRoad ?? '').isNotEmpty) '${isEnglish ? "Rd." : "ถ."}${a.addressRoad}',
      if ((a.addressSubDistrict ?? '').isNotEmpty) a.addressSubDistrict!,
      if ((a.addressDistrict ?? '').isNotEmpty) a.addressDistrict!,
      if ((a.addressProvince ?? '').isNotEmpty) a.addressProvince!,
      if ((a.addressZipCode ?? '').isNotEmpty) a.addressZipCode!,
      if ((a.addressCountry ?? '').isNotEmpty && a.addressCountry != 'Thailand') a.addressCountry!,
    ];
    return parts.join(' ');
  }

  static String _contactStr(ArCustomerContact ct, bool isEnglish) {
    return [
      if (ct.isDefault) '(default)',
      ct.contactName,
      if ((ct.position ?? '').isNotEmpty) ct.position!,
      if ((ct.phone ?? '').isNotEmpty) '${isEnglish ? "Tel" : "โทร"}:${ct.phone}',
      if ((ct.mobile ?? '').isNotEmpty) '${isEnglish ? "Mobile" : "มือถือ"}:${ct.mobile}',
      if ((ct.email ?? '').isNotEmpty) 'Email:${ct.email}',
    ].join('  ');
  }

  static String _bankStr(ArCustomerBankAccount ba, bool isEnglish) {
    final t = ba.accountType == 'current'
        ? (isEnglish ? 'Current' : 'กระแสรายวัน')
        : ba.accountType == 'savings'
            ? (isEnglish ? 'Savings' : 'ออมทรัพย์')
            : ba.accountType;
    return [
      if (ba.isDefault) '(default)',
      '${ba.bankName ?? ""}${(ba.branchName ?? "").isNotEmpty ? " ${isEnglish ? "Branch" : "สาขา"} ${ba.branchName}" : ""}',
      if ((ba.accountNumber ?? '').isNotEmpty) '${isEnglish ? "Account No." : "เลขบัญชี"}:${ba.accountNumber}',
      if ((ba.accountName ?? '').isNotEmpty)   '${isEnglish ? "Name" : "ชื่อ"}:${ba.accountName}',
      '[$t]',
    ].where((s) => s.trim().isNotEmpty).join('  ');
  }

  List<String> _catLines(ArCustomer c, _Category cat, bool isEnglish) {
    switch (cat) {
      case _Category.generalInfo:
        final p = <String>[];
        if ((c.taxId ?? '').isNotEmpty) p.add('${isEnglish ? "Tax ID" : "เลขผู้เสียภาษี"}: ${c.taxId}');
        if ((c.businessTypeNameThai ?? '').isNotEmpty) p.add('${isEnglish ? "Business Type" : "ประเภทธุรกิจ"}: ${c.businessTypeCode} ${c.businessTypeNameThai}');
        if ((c.customerGroupName ?? '').isNotEmpty)  p.add('${isEnglish ? "Customer Group" : "กลุ่มลูกค้า"}: ${c.customerGroupCode} ${c.customerGroupName}');
        p.add('${isEnglish ? "Currency" : "สกุลเงิน"}: ${c.currencyCode}');
        final credit = [
          if (c.creditTermMonths > 0) isEnglish ? '${c.creditTermMonths} month(s)' : '${c.creditTermMonths} เดือน',
          if (c.creditTermDays  > 0) isEnglish ? '${c.creditTermDays} day(s)' : '${c.creditTermDays} วัน',
        ].join(' ');
        if (credit.isNotEmpty) p.add('${isEnglish ? "Credit Term" : "เครดิต"}: $credit');
        if (c.creditLimit   > 0) p.add('${isEnglish ? "Credit Limit" : "วงเงิน"}: ${NumberFormat("#,##0.00").format(c.creditLimit)}');
        if (c.discountPercent > 0) p.add('${isEnglish ? "Discount" : "ส่วนลด"}: ${c.discountPercent}%');
        p.add('${isEnglish ? "Billing" : "วางบิล"}: ${c.requiresBilling ? (isEnglish ? "Required" : "ต้องวางบิล") : (isEnglish ? "Not required" : "ไม่บังคับ")}');
        p.add('${isEnglish ? "Status" : "สถานะ"}: ${c.isActive ? (isEnglish ? "Active" : "ใช้งาน") : (isEnglish ? "Inactive" : "ไม่ใช้งาน")}');
        if ((c.remark ?? '').isNotEmpty) p.add('${isEnglish ? "Remark" : "หมายเหตุ"}: ${c.remark}');
        return [p.join('  |  ')];

      case _Category.salesTerritory:
        final p = <String>[];
        if ((c.salesTerritoryNameThai ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Sales Territory" : "เขตการขาย"}: ${c.salesTerritoryCode} ${c.salesTerritoryNameThai}');
        }
        if ((c.salespersonNameThai ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Salesperson" : "พนักงานขาย"}: ${c.salespersonCode} ${c.salespersonNameThai}');
        }
        if ((c.billingCollectorNameThai ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Billing Collector" : "ผู้วางบิล"}: ${c.billingCollectorCode} ${c.billingCollectorNameThai}');
        }
        if ((c.collectionCollectorNameThai ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Collection Collector" : "ผู้รับชำระ"}: ${c.collectionCollectorCode} ${c.collectionCollectorNameThai}');
        }
        return p.isEmpty ? [isEnglish ? '(No data)' : '(ไม่มีข้อมูล)'] : [p.join('  |  ')];

      case _Category.billingCondition:
        return c.billingConditions.isEmpty
            ? [isEnglish ? '(No billing condition)' : '(ไม่มีเงื่อนไขการวางบิล)']
            : c.billingConditions.map((bc) => _billingCondStr(bc, isEnglish)).toList();

      case _Category.paymentCondition:
        return c.paymentConditions.isEmpty
            ? [isEnglish ? '(No payment condition)' : '(ไม่มีเงื่อนไขการรับชำระ)']
            : c.paymentConditions.map((pc) => _paymentCondStr(pc, isEnglish)).toList();

      case _Category.address:
        return c.addresses.isEmpty
            ? [isEnglish ? '(No address)' : '(ไม่มีที่อยู่)']
            : c.addresses.map((a) => _addressStr(a, isEnglish)).toList();

      case _Category.contact:
        return c.contacts.isEmpty
            ? [isEnglish ? '(No contact)' : '(ไม่มีผู้ติดต่อ)']
            : c.contacts.map((ct) => _contactStr(ct, isEnglish)).toList();

      case _Category.bankAccount:
        return c.bankAccounts.isEmpty
            ? [isEnglish ? '(No bank account)' : '(ไม่มีบัญชีธนาคาร)']
            : c.bankAccounts.map((ba) => _bankStr(ba, isEnglish)).toList();

      case _Category.arAccount:
        final p = <String>[];
        if ((c.arAccountCode ?? '').isNotEmpty) {
          p.add('${isEnglish ? "AR Account" : "บัญชีลูกหนี้"}: ${c.arAccountCode} ${c.arAccountNameThai ?? ""}');
        }
        if ((c.groupArAccountCode ?? '').isNotEmpty) {
          p.add('${isEnglish ? "Group Account" : "บัญชีกลุ่ม"}: ${c.groupArAccountCode} ${c.groupArAccountNameThai ?? ""}');
        }
        return p.isEmpty ? [isEnglish ? '(AR account code not specified)' : '(ไม่ระบุรหัสบัญชีลูกหนี้)'] : [p.join('  |  ')];
    }
  }

  String _conditionLine(bool isEnglish) {
    final p = <String>[];
    if (_selectedGroupIds.isNotEmpty) {
      final names = _selectedGroupIds.map((id) {
        final g = _groups.firstWhere((g) => g.id == id,
            orElse: () => _groups.first);
        return isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai;
      }).join(', ');
      p.add('${isEnglish ? "Group" : "กลุ่ม"}: $names');
    }
    if (_selectedSalespersonId != null) {
      final s = _salespersons.firstWhere((s) => s.id == _selectedSalespersonId,
          orElse: () => _salespersons.first);
      final name = isEnglish && (s.salespersonNameEng ?? '').isNotEmpty
          ? s.salespersonNameEng!
          : s.salespersonNameThai;
      p.add('${isEnglish ? "Salesperson" : "พนักงานขาย"}: ${s.salespersonCode} $name');
    }
    if ((_customerCodeFrom ?? '').isNotEmpty || (_customerCodeTo ?? '').isNotEmpty) {
      final all = isEnglish ? '(All)' : '(ทั้งหมด)';
      final f = (_customerCodeFrom ?? '').isEmpty ? all : _customerCodeFrom!;
      final t = (_customerCodeTo   ?? '').isEmpty ? all : _customerCodeTo!;
      p.add('${isEnglish ? "Code" : "รหัส"}: $f – $t');
    }
    if (_status == 'active')   p.add(isEnglish ? 'Status: Active'   : 'สถานะ: ใช้งาน');
    if (_status == 'inactive') p.add(isEnglish ? 'Status: Inactive' : 'สถานะ: ไม่ใช้งาน');
    return p.isEmpty ? (isEnglish ? 'All' : 'ทั้งหมด') : p.join(' | ');
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish     = _isEnglish;
    final reportTitle   = _reportTitle;
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

    // Column widths (absolute)
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

    // Table header row
    final tableHeader = pw.Container(
      decoration: const pw.BoxDecoration(
        color: cGreen,
        border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.5)),
      ),
      child: pw.Row(children: [
        box(codeW,   isEnglish ? 'Customer Code' : 'รหัสลูกค้า',           tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(nameTHW, isEnglish ? 'Customer Name (TH)' : 'ชื่อลูกค้า (ไทย)',      tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(nameENW, isEnglish ? 'Customer Name (EN)' : 'ชื่อลูกค้า (อังกฤษ)',   tB(9)),
        pw.Container(width: 0.5, color: cBorder),
        box(oldW,    isEnglish ? 'Old Code' : 'รหัสเก่า',               tB(9)),
      ]),
    );

    // Page header — รวม table header ไว้ด้วยเพื่อให้แสดงซ้ำทุกหน้า
    pw.Widget Function(pw.Context) pageHeader() => (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: pw.Text(companyName, style: tN(11))),
        pw.Expanded(flex: 6, child: pw.Text(reportTitle,
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

    // จัดกลุ่มลูกค้าตาม customerGroupCode แล้วเรียงตาม code กลุ่ม
    final grouped = <String, List<ArCustomer>>{};
    for (final c in _reportData) {
      final key = c.customerGroupCode ?? '';
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final sortedGroupKeys = grouped.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    // Build content (ไม่ต้องใส่ tableHeader ซ้ำที่นี่แล้ว)
    final content = <pw.Widget>[];

    int globalIdx = 0;
    for (final groupKey in sortedGroupKeys) {
      final groupCustomers = grouped[groupKey]!;

      for (final c in groupCustomers) {
        final bg = globalIdx.isOdd ? cStripe : null;

        // Customer main row
        content.add(pw.Container(
          color: bg,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.3)),
          ),
          child: pw.Row(children: [
            box(codeW,   c.customerCode,         tB(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(nameTHW, c.customerNameTh,       tN(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(nameENW, c.customerNameEn ?? '',  tN(9)),
            pw.Container(width: 0.3, color: cBorder),
            box(oldW,    c.oldCustomerCode ?? '', tN(9)),
          ]),
        ));

        // Category sections — ชื่อหมวด + รายละเอียดในบรรทัดเดียวกัน wrap อัตโนมัติ
        for (final cat in _selectedCategories) {
          final lines = _catLines(c, cat, isEnglish);
          content.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: hp, vertical: 2),
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(
                  text: '${cat.label(isEnglish)}  ',
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

      // Group subtotal row
      final first = groupCustomers.first;
      final groupLabel = groupKey.isEmpty
          ? (isEnglish ? '(No group)' : '(ไม่ระบุกลุ่ม)')
          : '$groupKey  ${first.customerGroupName ?? ""}';
      content.add(pw.Container(
        width: pageW,
        color: cGroupTot,
        padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp),
        child: pw.Text(
          isEnglish
              ? 'Group total $groupLabel:  ${groupCustomers.length} customer(s)'
              : 'รวมกลุ่ม $groupLabel:  ${groupCustomers.length} ลูกค้า',
          style: tB(9),
        ),
      ));
    }

    // Grand total
    content.add(pw.Container(
      width: pageW,
      color: cTotal,
      padding: const pw.EdgeInsets.symmetric(horizontal: hp + 4, vertical: vp + 1),
      child: pw.Text(
          isEnglish
              ? 'Grand total ${_reportData.length} customer(s)'
              : 'รวมทั้งสิ้น ${_reportData.length} ลูกค้า',
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
    final reportTitle = _reportTitle;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      final sName = isEnglish ? 'Customer' : 'ลูกค้า';
      ex.rename('Sheet1', sName);
      final s = ex[sName];

      final hdrBg  = ExcelColor.fromHexString('#92D050');
      final totBg  = ExcelColor.fromHexString('#BDD7EE');
      final catBg  = ExcelColor.fromHexString('#D0E4F7');

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, reportTitle, bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Condition" : "เงื่อนไข"}: ${_conditionLine(isEnglish)}');
      _xl(s, 3, 0, '${isEnglish ? "Printed" : "พิมพ์"}: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}');

      final hdrs = isEnglish
          ? ['Customer Code', 'Customer Name (TH)', 'Customer Name (EN)', 'Old Code']
          : ['รหัสลูกค้า', 'ชื่อลูกค้า (ไทย)', 'ชื่อลูกค้า (อังกฤษ)', 'รหัสเก่า'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 5, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }
      // Category header column
      if (_selectedCategories.isNotEmpty) {
        _xl(s, 5, 4, isEnglish ? 'Category' : 'หมวด', bg: hdrBg, bold: true);
        _xl(s, 5, 5, isEnglish ? 'Details' : 'รายละเอียด', bg: hdrBg, bold: true);
      }

      int row = 6;
      for (final c in _reportData) {
        if (_selectedCategories.isEmpty) {
          _xl(s, row, 0, c.customerCode);
          _xl(s, row, 1, c.customerNameTh);
          _xl(s, row, 2, c.customerNameEn ?? '');
          _xl(s, row, 3, c.oldCustomerCode ?? '');
          row++;
        } else {
          bool firstCat = true;
          for (final cat in _selectedCategories) {
            final lines = _catLines(c, cat, isEnglish);
            for (int li = 0; li < lines.length; li++) {
              if (firstCat && li == 0) {
                _xl(s, row, 0, c.customerCode);
                _xl(s, row, 1, c.customerNameTh);
                _xl(s, row, 2, c.customerNameEn ?? '');
                _xl(s, row, 3, c.oldCustomerCode ?? '');
                firstCat = false;
              }
              _xl(s, row, 4, cat.label(isEnglish), bg: catBg);
              _xl(s, row, 5, lines[li]);
              row++;
            }
          }
        }
      }

      _xl(s, row, 0,
          isEnglish
              ? 'Grand total ${_reportData.length} customer(s)'
              : 'รวมทั้งสิ้น ${_reportData.length} ลูกค้า',
          bg: totBg, bold: true);

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes,
          isEnglish ? 'CustomerReport_$ts.xlsx' : 'รายงานข้อมูลลูกค้า_$ts.xlsx');
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

  Future<void> _pickCustomer({required bool isFrom}) async {
    final result = await showDialog<ArCustomer>(
      context: context,
      builder: (_) => const _CustomerPickerDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      final displayName = _isEnglish && (result.customerNameEn ?? '').isNotEmpty
          ? result.customerNameEn!
          : result.customerNameTh;
      final label = '${result.customerCode}  $displayName';
      if (isFrom) {
        _customerCodeFrom = result.customerCode;
        _fromLabel        = label;
      } else {
        _customerCodeTo = result.customerCode;
        _toLabel        = label;
      }
    });
  }

  Future<void> _pickGroups() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ArCustomerGroup>(
        title: isEnglish ? 'Select Customer Groups' : 'เลือกกลุ่มลูกค้า',
        items: _groups,
        selected: _selectedGroupIds,
        idOf: (g) => g.id!,
        labelOf: (g) => '${g.groupCode}  ${isEnglish && g.groupNameEng.isNotEmpty ? g.groupNameEng : g.groupNameThai}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedGroupIds = result);
  }

  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<_Category>(
        title: isEnglish ? 'Select Detail Categories' : 'เลือกหมวดรายละเอียด',
        items: _Category.values,
        selected: _selectedCategories.map((c) => c.index).toList(),
        idOf: (c) => c.index,
        labelOf: (c) => c.label(isEnglish),
        isEnglish: isEnglish,
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
                      color: Colors.orange[700]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue ? displayText : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
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
          hasValue ? (_isEnglish ? '$count selected' : 'เลือก $count รายการ') : allLabel,
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
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

                // กลุ่มลูกค้า (multi-select)
                _buildMultiField(
                  label: isEnglish ? 'Customer Group' : 'กลุ่มลูกค้า',
                  count: _selectedGroupIds.length,
                  allLabel: isEnglish ? '— All Groups —' : '— ทุกกลุ่ม —',
                  onTap: _pickGroups,
                  onClear: () => setState(() => _selectedGroupIds = []),
                ),
                const SizedBox(height: 12),

                // พนักงานขาย
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  value: _selectedSalespersonId,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Salesperson' : 'พนักงานขาย',
                      border: const OutlineInputBorder(),
                      isDense: true),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(isEnglish ? '— All —' : '— ทั้งหมด —')),
                    ..._salespersons.map((s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(
                              '${s.salespersonCode}  ${isEnglish && (s.salespersonNameEng ?? "").isNotEmpty ? s.salespersonNameEng! : s.salespersonNameThai}',
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedSalespersonId = v),
                ),
                const SizedBox(height: 12),

                // รหัสลูกค้า ตั้งแต่ / ถึง
                _buildPickerField(
                  label: isEnglish ? 'Customer Code From' : 'รหัสลูกค้า ตั้งแต่',
                  displayText: _fromLabel,
                  onPick: () => _pickCustomer(isFrom: true),
                  onClear: () => setState(() {
                    _customerCodeFrom = null;
                    _fromLabel = '';
                  }),
                ),
                const SizedBox(height: 8),
                _buildPickerField(
                  label: isEnglish ? 'Customer Code To' : 'รหัสลูกค้า ถึง',
                  displayText: _toLabel,
                  onPick: () => _pickCustomer(isFrom: false),
                  onClear: () => setState(() {
                    _customerCodeTo = null;
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

                // หมวด (multi-select)
                _buildMultiField(
                  label: isEnglish ? 'Detail Categories' : 'หมวดรายละเอียด',
                  count: _selectedCategories.length,
                  allLabel: isEnglish ? '— Master data only —' : '— ข้อมูลหลักเท่านั้น —',
                  onTap: _pickCategories,
                  onClear: () => setState(() => _selectedCategories = []),
                ),
                if (_selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: _selectedCategories.map((cat) => Chip(
                      label: Text(cat.label(isEnglish), style: const TextStyle(fontSize: 11)),
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
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Customer Master Report' : 'รายงานข้อมูลลูกค้า'));
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))),
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
                  // Toggle button
                  Container(
                    width: 36,
                    color: Colors.orange[700],
                    child: IconButton(
                      icon: Icon(
                          _isFilterExpanded
                              ? Icons.filter_list_off
                              : Icons.filter_list,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: _isFilterExpanded
                          ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข')
                          : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
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
// Customer picker dialog
// ---------------------------------------------------------------------------
class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog();

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _ctrl   = TextEditingController();
  final _svc    = ArCustomerService();
  List<ArCustomer> _list = [];
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange[700],
            child: Text(isEnglish ? 'Search Customer' : 'ค้นหาลูกค้า',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: isEnglish
                      ? 'Search by customer code or name'
                      : 'ค้นหาจากรหัสหรือชื่อลูกค้า',
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
              Expanded(child: Text(isEnglish ? 'Customer Name' : 'ชื่อลูกค้า',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(
                        child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                            style: const TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 12),
                        itemBuilder: (ctx, i) {
                          final c = _list[i];
                          final displayName = isEnglish && (c.customerNameEn ?? '').isNotEmpty
                              ? c.customerNameEn!
                              : c.customerNameTh;
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 100,
                                    child: Text(c.customerCode,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500))),
                                Expanded(
                                    child: Text(displayName,
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
                  child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
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
  State<_MultiPickerDialog<T>> createState() =>
      _MultiPickerDialogState<T>();
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
                    ? (widget.isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด')
                    : (widget.isEnglish ? 'Select All' : 'เลือกทั้งหมด')),
              ),
              Row(children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.isEnglish ? 'Cancel' : 'ยกเลิก')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white),
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
