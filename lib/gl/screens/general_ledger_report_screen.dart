import 'dart:typed_data';
import 'package:anan/sa/models/company.dart';
import 'package:anan/sa/services/company_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
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
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 350.0;
  bool _isDraggingDivider = false;

  // Report Data
  List<Map<String, dynamic>> _beginningBalances = [];
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
      _fiscalYears = await _periodService.fetchActiveFiscalYears();
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
    setState(() { _isLoading = true; _reportGenerated = false; });

    try {
      // 1. ดึงยอดยกมา (สะสมตั้งแต่ต้นปีถึงก่อนหน้างวดที่เลือก)
      _beginningBalances = await _reportService.fetchBeginningBalance(
        fiscalYearId: _selectedYear!.id,
        periodId: _selectedPeriod?.id,
      );

      // 2. ดึงรายการเคลื่อนไหวจาก API
      _transactions = await _reportService.getGlTransactions(
        periodId: _selectedPeriod?.id,
        fiscalYearId: _selectedYear!.id,
        accountFrom: _accountFrom?.accountCode,
        accountTo: _accountTo?.accountCode,
      );

      if (_beginningBalances.isEmpty && _transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลในปีบัญชีที่เลือก')),
          );
        }
        return;
      }

      setState(() { _reportGenerated = true; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        ? "วันที่ ${_selectedPeriod!.periodEndDate.day} ${_selectedPeriod!.periodName} ${_selectedYear!.fyCode}"
        : "ปี ${_selectedYear?.fyCode}";

    String conditionLine = "* บัญชี: ${_accountFrom?.accountCode ?? 'ทั้งหมด'} - ${_accountTo?.accountCode ?? 'ทั้งหมด'}";
    final fmt = NumberFormat("#,##0.00", "en_US");

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

      // รวม 2 sources: transaction groups + beginning-balance-only accounts
      final txKeys = groupedData.keys.toSet();

      // สร้าง entries รวม พร้อมข้อมูลที่ต้องใช้ sort
      List<Map<String, dynamic>> entries = [];

      groupedData.forEach((key, transactions) {
        final firstTx = transactions.first;
        entries.add({
          'key': key,
          'accId': firstTx['account_id'] as int,
          'accCode': firstTx['account_code'] as String? ?? '',
          'accName': "${firstTx['account_code']} ${firstTx['account_name_thai']}",
          'brId': firstTx['branch_id'] as int?,
          'buId': firstTx['business_unit_id'] as int?,
          'pjId': firstTx['project_id'] as int?,
          'transactions': transactions,
          'begDr': null, // จะดึงในลูปหลัก
          'begCr': null,
        });
      });

      for (var b in _beginningBalances) {
        final int bAccId = b['account_id'] as int;
        final int? bBrId = b['branch_id'] as int?;
        final int? bBuId = b['business_unit_id'] as int?;
        final int? bPjId = b['project_id'] as int?;
        final String key = "${bAccId}_${bBrId ?? 0}_${bBuId ?? 0}_${bPjId ?? 0}";
        if (txKeys.contains(key)) continue; // มี transaction แล้ว ข้ามไป

        final acc = _accountMap[bAccId];
        entries.add({
          'key': key,
          'accId': bAccId,
          'accCode': acc?.accountCode ?? '',
          'accName': acc != null ? "${acc.accountCode} ${acc.accountNameThai}" : "Account $bAccId",
          'brId': bBrId,
          'buId': bBuId,
          'pjId': bPjId,
          'transactions': <Map<String, dynamic>>[],
          'begDr': double.tryParse(b['amount_dr']?.toString() ?? '0') ?? 0,
          'begCr': double.tryParse(b['amount_cr']?.toString() ?? '0') ?? 0,
        });
      }

      // เรียงตามรหัสบัญชี -> สาขา -> หน่วยงาน -> โครงการ
      entries.sort((a, b) {
        int cmp = (a['accCode'] as String).compareTo(b['accCode'] as String);
        if (cmp != 0) return cmp;
        cmp = (a['brId'] as int? ?? 0).compareTo(b['brId'] as int? ?? 0);
        if (cmp != 0) return cmp;
        cmp = (a['buId'] as int? ?? 0).compareTo(b['buId'] as int? ?? 0);
        if (cmp != 0) return cmp;
        return (a['pjId'] as int? ?? 0).compareTo(b['pjId'] as int? ?? 0);
      });

      for (var entry in entries) {
        final int accId = entry['accId'] as int;
        final int? brId = entry['brId'] as int?;
        final int? buId = entry['buId'] as int?;
        final int? pjId = entry['pjId'] as int?;
        final String accName = entry['accName'] as String;
        final List<Map<String, dynamic>> transactions = entry['transactions'] as List<Map<String, dynamic>>;

        // ดึงยอดยกมา (transaction entries ดึงจาก _beginningBalances, balance-only entries มีค่าอยู่แล้ว)
        double begDr = entry['begDr'] as double? ?? 0;
        double begCr = entry['begCr'] as double? ?? 0;
        if (entry['begDr'] == null) {
          try {
            var begRow = _beginningBalances.firstWhere((b) =>
              b['account_id'] == accId &&
              (b['branch_id'] == brId || (b['branch_id'] == null && brId == null)) &&
              (b['business_unit_id'] == buId || (b['business_unit_id'] == null && buId == null)) &&
              (b['project_id'] == pjId || (b['project_id'] == null && pjId == null))
            );
            begDr = double.tryParse(begRow['amount_dr']?.toString() ?? '0') ?? 0;
            begCr = double.tryParse(begRow['amount_cr']?.toString() ?? '0') ?? 0;
          } catch (_) {}
        }

        // กรอง: ซ่อนบัญชีที่ยอดยกมาเป็น 0 และไม่มีรายการเคลื่อนไหว
        if (_hideZero && begDr.abs() < 0.001 && begCr.abs() < 0.001 && transactions.isEmpty) {
          continue;
        }

        double runningBalance = begDr - begCr;

        // resolve code ก่อน แล้วค่อยตัดสินว่ามี dimension จริงหรือไม่
        String brCode = brId != null ? (_branchMap[brId] ?? '') : '';
        String buCode = buId != null ? (_buMap[buId] ?? '') : '';
        String pjCode = pjId != null ? (_projectMap[pjId] ?? '') : '';
        bool hasDim = brCode.isNotEmpty || buCode.isNotEmpty || pjCode.isNotEmpty;
        String branchStr = "สาขา: ${brCode.isNotEmpty ? brCode : '-'}";
        String buStr = "หน่วยงาน: ${buCode.isNotEmpty ? buCode : '-'}";
        String pjStr = "โครงการ: ${pjCode.isNotEmpty ? pjCode : '-'}";
        String dims = hasDim ? '$branchStr / $buStr / $pjStr' : '';

        // [ส่วนที่ 1] บรรทัดยอดยกมา
        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(13.9), 1: pw.FlexColumnWidth(1.5) },
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

          runningBalance += (dr - cr);
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
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(transactions.isEmpty ? '' : fmt.format(sumDr), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(transactions.isEmpty ? '' : fmt.format(sumCr), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(fmt.format(runningBalance), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              ]
            )
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
        title: const Row(children: [Icon(Icons.menu_book, color: Colors.white, size: 20), SizedBox(width: 8), Text('บัญชีแยกประเภท (General Ledger)')]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxFilterWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 36,
            color: Colors.deepOrange[900],
            child: IconButton(
              icon: Icon(
                _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              tooltip: _isFilterExpanded ? 'ย่อเงื่อนไข' : 'ขยายเงื่อนไข',
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
              ),
            ),
          // draggable divider
          if (_isFilterExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) =>
                    setState(() => _isDraggingDivider = true),
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _filterPanelWidth =
                        (_filterPanelWidth + details.delta.dx)
                            .clamp(200.0, maxFilterWidth);
                  });
                },
                onHorizontalDragEnd: (_) =>
                    setState(() => _isDraggingDivider = false),
                child: Container(
                  width: 5,
                  color: Colors.grey[400],
                ),
              ),
            ),
          // ส่วน Preview
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: !_reportGenerated
                  ? const Center(child: Text("กรุณาเลือกเงื่อนไขและกดประมวลผล"))
                  : PdfPreview(
                      build: (format) => _generatePdf(format),
                      initialPageFormat: PdfPageFormat.a4.landscape,
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}