import 'dart:typed_data';
import 'package:anan/sa/models/company.dart';
import 'package:anan/sa/services/company_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
import '../../gl/models/gl_beginning_balance.dart';
import '../../gl/services/gl_beginning_balance_service.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../gl/services/general_ledger_report_service.dart';

import '../../cd/services/branch_service.dart';
import '../../cd/services/business_unit_service.dart';
import '../../cd/services/project_service.dart';
import '../../sa/services/auth_service.dart';

class GeneralLedgerReportScreen extends StatefulWidget {
  const GeneralLedgerReportScreen({super.key});

  @override
  State<GeneralLedgerReportScreen> createState() => _GeneralLedgerReportScreenState();
}

class _GeneralLedgerReportScreenState extends State<GeneralLedgerReportScreen> {
  // Services
  final CompanyService _companyService = CompanyService();
  final PeriodService _periodService = PeriodService();
  final GlBeginningBalanceService _begBalService = GlBeginningBalanceService();
  final AccountService _accountService = AccountService();
  final GeneralLedgerReportService _reportService = GeneralLedgerReportService();
  final BranchService _branchService = BranchService();
  final BusinessUnitService _buService = BusinessUnitService();
  final ProjectService _projectService = ProjectService();
  final AuthService authService = AuthService();
  
  late Map<String, String> headers;

  // Data
  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<Account> _controlAccounts = [];
  
  // Master Data Maps
  Map<int, String> _branchMap = {};
  Map<int, String> _buMap = {};
  Map<int, String> _projectMap = {};
  Map<int, Account> _accountMap = {};

  // Filter States
  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;
  Account? _accountFrom;
  Account? _accountTo;
  
  bool _pageBreakPerAccount = false;
  bool _hideZero = true;
  bool _isLoading = false;
  bool _reportGenerated = false;

  // Report Data
  List<GlBeginningBalance> _beginningBalances = [];
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    headers = await authService.getAuthHeader();
    _company = await _companyService.fetchCompany();

    try {
      _fiscalYears = await _periodService.fetchFiscalYears();
      if (_fiscalYears.isNotEmpty) {
        final now = DateTime.now();
        try {
          _selectedYear = _fiscalYears.firstWhere((fy) => now.isAfter(fy.yearStartDate) && now.isBefore(fy.yearEndDate));
        } catch (_) {
          _selectedYear = _fiscalYears.first;
        }
        await _loadPeriods(_selectedYear!.id);
      }

      // โหลด Master Data
      final branches = await _branchService.fetchRows();
      final bus = await _buService.fetchRows();
      final projects = await _projectService.fetchRows();
      
      // โหลดเฉพาะบัญชีคุม (Control Account) สำหรับตัวกรอง
      _controlAccounts = await _accountService.fetchRowsControlAccount();

      final allAccounts = await _accountService.fetchRows();
      _accountMap = {for (var a in allAccounts) a.id!: a};

      _branchMap = {for (var e in branches) e.id!: e.branchCode};
      _buMap = {for (var e in bus) e.id!: e.buCode};
      _projectMap = {for (var e in projects) e.id!: e.projectCode};
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading master: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPeriods(int yearId) async {
    final ps = await _periodService.fetchPostingPeriodsByFiscalYearId(yearId);
    setState(() {
      _periods = ps;
      _selectedPeriod = null;
      _reportGenerated = false;
    });
  }

  // --- Dialog ค้นหาบัญชี ---
  Future<void> _showAccountSearchDialog(bool isFrom) async {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // กรองรายการตามคำค้นหา (ค้นได้ทั้ง Code และ Name)
            final filteredAccounts = _controlAccounts.where((acc) {
              final q = searchQuery.toLowerCase();
              return acc.accountCode.toLowerCase().contains(q) || 
                     acc.accountNameThai.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              title: const Text('ค้นหารหัสบัญชี'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'ค้นหารหัส หรือ ชื่อบัญชี',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredAccounts.length,
                        itemBuilder: (context, index) {
                          final acc = filteredAccounts[index];
                          return ListTile(
                            title: Text('${acc.accountCode} - ${acc.accountNameThai}'),
                            onTap: () {
                              setState(() {
                                if (isFrom) _accountFrom = acc;
                                else _accountTo = acc;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                )
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _generateReport() async {
    if (_selectedYear == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกปีบัญชี')));
       return;
    }
    setState(() => _isLoading = true);

    try {
      // 1. ดึงยอดยกมา (งวดยกยอด + งวดก่อนหน้าสะสม) จาก gl_balance_accum
      _beginningBalances = await _begBalService.fetchFromAccum(_selectedYear!.id, _selectedPeriod?.id);

      // 2. ดึงรายการเคลื่อนไหวจาก API
      _transactions = await _reportService.getGlTransactions(
        periodId: _selectedPeriod?.id,
        fiscalYearId: _selectedYear!.id,
        accountFrom: _accountFrom?.accountCode,
        accountTo: _accountTo?.accountCode,
      );

      setState(() { _reportGenerated = true; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- จัดกลุ่มข้อมูลเพื่อพิมพ์รายงาน ---
  Map<String, List<Map<String, dynamic>>> _groupTransactions() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var t in _transactions) {
      // Group ด้วย Account + Dimensions
      String key = "${t['account_id']}_${t['branch_id'] ?? 0}_${t['business_unit_id'] ?? 0}_${t['project_id'] ?? 0}";
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(t);
    }
    return grouped;
  }

  // --- สร้าง PDF ---
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    String companyName = _company != null ? _company!.thaiName : "(ไม่ระบุชื่อบริษัท)";
    final String userName = headers['UserName'] ?? "(ไม่ระบุชื่อ)";
    final String printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    
    String periodLine = _selectedPeriod != null
        ? "งวดเดือน ${_selectedPeriod!.periodName} ปีบัญชี ${_selectedYear!.fyCode}"
        : "ปีบัญชี ${_selectedYear?.fyCode}";

    String conditionLine = "* บัญชี: ${_accountFrom?.accountCode ?? 'ทั้งหมด'} - ${_accountTo?.accountCode ?? 'ทั้งหมด'}";
    final fmt = NumberFormat("#,##0.00");

    // ฟังก์ชันสร้าง Header ของหน้า
    pw.Widget buildPageHeader(pw.Context context) {
      return pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 7, child: pw.Text("บัญชีแยกประเภท (General Ledger)", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text("หน้า ${context.pageNumber}/${context.pagesCount}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)))
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(flex: 3, child: pw.Text("", style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 7, child: pw.Text(periodLine, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text("พิมพ์โดย $userName", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)))
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(flex: 10, child: pw.Text(conditionLine, textAlign: pw.TextAlign.left, style: const pw.TextStyle(fontSize: 8))),
              pw.Expanded(flex: 3, child: pw.Text("พิมพ์เมื่อ $printDateStr", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)))
            ],
          ),
          pw.SizedBox(height: 4),
          // หัวคอลัมน์
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2), 1: pw.FlexColumnWidth(1.0), 2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(0.5), 4: pw.FlexColumnWidth(1.0), 5: pw.FlexColumnWidth(1.5),
              6: pw.FlexColumnWidth(1.2), 7: pw.FlexColumnWidth(3.0), 8: pw.FlexColumnWidth(1.5),
              9: pw.FlexColumnWidth(1.5), 10: pw.FlexColumnWidth(1.5),
            },
            border: pw.TableBorder.all(color: PdfColors.grey800, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ["วันที่เอกสาร", "ประเภท\nเอกสาร", "เลขที่ใบสำคัญ", "ลำดับ", "ประเภท\nอ้างอิง", "เลขที่อ้างอิง", "วันที่อ้างอิง", "อธิบายรายการ", "เดบิต", "เครดิต", "ยกมา/สะสม\n/ยกไป"]
                    .map((t) => pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(t, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))))
                    .toList(),
              ),
            ]
          ),
        ],
      );
    }

    final groupedData = _groupTransactions();
    
    pw.TableRow buildTableRow(List<String> values, {bool isBold = false, pw.BoxDecoration? decoration}) {
      return pw.TableRow(
        decoration: decoration,
        children: values.asMap().entries.map((entry) {
          int idx = entry.key;
          pw.TextAlign align = (idx >= 8) ? pw.TextAlign.right : pw.TextAlign.left; 
          if ([0, 1, 3, 4, 6].contains(idx)) align = pw.TextAlign.center;
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: pw.Text(entry.value, textAlign: align, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          );
        }).toList(),
      );
    }

    // สร้างข้อมูลของแต่ละกลุ่ม (บัญชี/มิติ) ให้เป็น List ของ Widget
    List<pw.Widget> buildAccountBlocks() {
      List<pw.Widget> blocks = [];

      groupedData.forEach((key, transactions) {
        final firstTx = transactions.first;
        int accId = firstTx['account_id'];
        int? brId = firstTx['branch_id'];
        int? buId = firstTx['business_unit_id'];
        int? pjId = firstTx['project_id'];

        // 1. ดึงยอดยกมา
        double begDr = 0, begCr = 0;
        try {
          var begRow = _beginningBalances.firstWhere((b) => 
            b.accountId == accId && b.branchId == brId && b.businessUnitId == buId && b.projectId == pjId
          );
          begDr = begRow.amountDr;
          begCr = begRow.amountCr;
        } catch (_) {}
        
        // ยอดสะสมเริ่มต้น (Dr - Cr)
        double runningBalance = begDr - begCr; 

        String accName = "${firstTx['account_code']} ${firstTx['account_name_thai']}";
        String branchStr = brId != null ? "สาขา: ${_branchMap[brId] ?? ''}" : "";
        String buStr = buId != null ? "หน่วยงาน: ${_buMap[buId] ?? ''}" : "";
        String pjStr = pjId != null ? "โครงการ: ${_projectMap[pjId] ?? ''}" : "";
        String dims = [branchStr, buStr, pjStr].where((e) => e.isNotEmpty).join(' / ');

        // กรอง: ซ่อนบัญชีที่ยอดยกมาเป็น0 และไม่มีรายการเคลื่อนไหวเลย
        if (_hideZero && begDr.abs() < 0.001 && begCr.abs() < 0.001 && transactions.isEmpty) {
          return;
        }

        // [ส่วนที่ 1] บรรทัดยอดยกมา
        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(13.9), 1: pw.FlexColumnWidth(1.5) },
          border: const pw.TableBorder(left: pw.BorderSide(), right: pw.BorderSide()),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4), 
                  child: pw.Text("รหัส/ชื่อบัญชี: $accName ${dims.isNotEmpty ? '($dims)' : ''}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4), 
                  child: pw.Text(fmt.format(runningBalance), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))
                )
              ]
            )
          ]
        ));

        // [ส่วนที่ 2] รายการเคลื่อนไหว
        double sumDr = 0, sumCr = 0;
        List<pw.TableRow> txRows = [];
        for (var t in transactions) {
          double dr = double.tryParse(t['debit_lc'].toString()) ?? 0;
          double cr = double.tryParse(t['credit_lc'].toString()) ?? 0;
          
          runningBalance += (dr - cr); // คำนวณยอดสะสม
          sumDr += dr;
          sumCr += cr;

          String rawDate = t['doc_date']?.toString() ?? '';
          String fDate = rawDate.length >= 10 ? DateFormat('dd/MM/yyyy').format(DateTime.parse(rawDate)) : rawDate;
          
          String refRawDate = t['ref_doc_date']?.toString() ?? '';
          String fRefDate = refRawDate.length >= 10 ? DateFormat('dd/MM/yyyy').format(DateTime.parse(refRawDate)) : refRawDate;

          txRows.add(buildTableRow([
            fDate, t['doc_code'] ?? '', t['doc_no'] ?? '', t['line_no']?.toString() ?? '',
            t['ref_doc_code'] ?? '', t['ref_doc_no'] ?? '', fRefDate,
            t['description'] ?? '', 
            dr == 0 ? '' : fmt.format(dr), 
            cr == 0 ? '' : fmt.format(cr), 
            fmt.format(runningBalance)
          ]));
        }

        blocks.add(pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2), 1: pw.FlexColumnWidth(1.0), 2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(0.5), 4: pw.FlexColumnWidth(1.0), 5: pw.FlexColumnWidth(1.5),
            6: pw.FlexColumnWidth(1.2), 7: pw.FlexColumnWidth(3.0), 8: pw.FlexColumnWidth(1.5),
            9: pw.FlexColumnWidth(1.5), 10: pw.FlexColumnWidth(1.5),
          },
          border: const pw.TableBorder(left: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5), verticalInside: pw.BorderSide(width: 0.1, color: PdfColors.grey400)),
          children: txRows
        ));

        // [ส่วนที่ 3] บรรทัดยอดรวมและยอดยกไป
        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(10.9), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.5), 3: pw.FlexColumnWidth(1.5) },
          border: pw.TableBorder.all(width: 0.5),
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("ยอดรวมเดบิต / เครดิต / ยกไป", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(fmt.format(sumDr), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(fmt.format(sumCr), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(fmt.format(runningBalance), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              ]
            )
          ]
        ));
        blocks.add(pw.SizedBox(height: 15)); // เว้นบรรทัดขึ้นบัญชีใหม่
      });

      // loop ที่ 2: accounts ที่มีแต่ยอดยกมา ไม่มี transaction ในงวดนี้
      for (var b in _beginningBalances) {
        final String key = "${b.accountId}_${b.branchId ?? 0}_${b.businessUnitId ?? 0}_${b.projectId ?? 0}";
        if (groupedData.containsKey(key)) continue; // มี transaction แล้ว ข้ามไป

        final double begDr = b.amountDr;
        final double begCr = b.amountCr;
        // accounts ที่อยู่ใน _beginningBalances คือมี transaction ในงวดก่อนๆแน่นอน
        // ไม่กรองด้วยยอด เพราะยอดสุทธิอาจเป็น 0 ได้ (Dr=Cr) แต่ก็ยังต้องพิมพ์

        final acc = _accountMap[b.accountId];
        final String accName = acc != null
            ? "${acc.accountCode} ${acc.accountNameThai}"
            : "Account ${b.accountId}";
        final String branchStr = b.branchId != null ? "สาขา: ${_branchMap[b.branchId] ?? ''}" : "";
        final String buStr = b.businessUnitId != null ? "หน่วยงาน: ${_buMap[b.businessUnitId] ?? ''}" : "";
        final String pjStr = b.projectId != null ? "โครงการ: ${_projectMap[b.projectId] ?? ''}" : "";
        final String dims = [branchStr, buStr, pjStr].where((e) => e.isNotEmpty).join(' / ');
        final double runningBal = begDr - begCr;

        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(13.9), 1: pw.FlexColumnWidth(1.5) },
          border: const pw.TableBorder(left: pw.BorderSide(), right: pw.BorderSide()),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("รหัส/ชื่อบัญชี: $accName ${dims.isNotEmpty ? '($dims)' : ''}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmt.format(runningBal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              ]
            )
          ]
        ));
        // ไม่มี transaction rows — เพิ่ม table ว่างเพื่อให้ block count = 4 เหมือน accounts ที่มี transaction
        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(15.4) },
          children: [],
        ));
        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(10.9), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.5), 3: pw.FlexColumnWidth(1.5) },
          border: pw.TableBorder.all(width: 0.5),
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("ยอดรวมเดบิต / เครดิต / ยกไป", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(fmt.format(runningBal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            ])
          ]
        ));
        blocks.add(pw.SizedBox(height: 15));
      }

      return blocks;
    }

    final accountBlocks = buildAccountBlocks();

    if (_pageBreakPerAccount) {
      // ขึ้นหน้าใหม่ทุกบัญชี: วนลูปทีละ 4 Widget (หัว, ดีเทล, ท้าย, Space) ไปเป็นหน้าใหม่
      for (int i = 0; i < accountBlocks.length; i += 4) { 
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.all(20),
          header: buildPageHeader,
          build: (context) => [
            accountBlocks[i],     
            accountBlocks[i + 1], 
            accountBlocks[i + 2], 
          ]
        ));
      }
    } else {
      // พิมพ์ต่อกันไปเรื่อยๆ
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(20),
        header: buildPageHeader,
        build: (context) => accountBlocks,
      ));
    }

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บัญชีแยกประเภท (General Ledger)'),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
      ),
      body: ResizableContainer(
        direction: Axis.horizontal,
        children: [
          // ส่วนเงื่อนไข
          ResizableChild(
            size: const ResizableSize.pixels(350),
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เงื่อนไขรายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<FiscalYear>(
                      value: _selectedYear,
                      items: _fiscalYears.map((fy) => DropdownMenuItem(value: fy, child: Text(fy.fyCode))).toList(),
                      decoration: const InputDecoration(labelText: 'ปีบัญชี', border: OutlineInputBorder()),
                      onChanged: (val) async {
                        if (val != null) {
                           setState(() => _selectedYear = val);
                           await _loadPeriods(val.id);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PostingPeriod>(
                      value: _selectedPeriod,
                      items: [
                        const DropdownMenuItem<PostingPeriod>(value: null, child: Text('ทุกงวด (ตั้งแต่ต้นปี)')),
                        ..._periods.skip(1).map((p) => DropdownMenuItem(value: p, child: Text("${p.periodNumber} - ${p.periodName}"))),
                      ],
                      decoration: const InputDecoration(labelText: 'งวดเดือน', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() => _selectedPeriod = val),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _showAccountSearchDialog(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'รหัสบัญชี (จาก)', 
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                        child: Text(_accountFrom != null ? '${_accountFrom!.accountCode} - ${_accountFrom!.accountNameThai}' : 'เลือกบัญชีเริ่มต้น'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: () => _showAccountSearchDialog(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'รหัสบัญชี (ถึง)', 
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                        child: Text(_accountTo != null ? '${_accountTo!.accountCode} - ${_accountTo!.accountNameThai}' : 'เลือกบัญชีสิ้นสุด'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('พิมพ์เฉพาะที่มียอดยกมาหรือมีรายการเคลื่อนไหว'),
                      value: _hideZero,
                      onChanged: (v) => setState(() => _hideZero = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    SwitchListTile(
                      title: const Text('ขึ้นหน้าใหม่ทุกรหัสบัญชี'),
                      value: _pageBreakPerAccount,
                      onChanged: (v) => setState(() => _pageBreakPerAccount = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Spacer(),
                    if (_isLoading) const Center(child: CircularProgressIndicator())
                    else SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('ประมวลผลรายงาน'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
                        onPressed: _generateReport,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ส่วน Preview
          ResizableChild(
            child: Container(
              color: Colors.grey[200],
              child: !_reportGenerated
                  ? const Center(child: Text("กรุณาเลือกเงื่อนไขและกดประมวลผล"))
                  : PdfPreview(
                      build: (format) => _generatePdf(format),
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}