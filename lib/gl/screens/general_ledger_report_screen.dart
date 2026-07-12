import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:anan/sa/models/company.dart';
import 'package:anan/sa/services/company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../../sa/services/language_provider.dart';
import '../../sa/utils/app_l10n.dart';
import '../../sa/utils/menu_scope.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../sa/models/user_branch.dart';
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
  final GlDimensionService _dimService = GlDimensionService();
  final AuthService authService = AuthService();
  
  late Map<String, String> headers;

  // Data
  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<dynamic> _branchList = []; // [{id, branchCode, branchNameThai}]
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;
  List<Account> _controlAccounts = [];
  
  // Master Data Maps
  Map<int, String> _branchMap = {};
  Map<int, Account> _accountMap = {};
  List<GlDimensionType> _activeDimTypes = [];
  Map<int, String> _dimValueMap = {}; // dim_value.id → value_code

  // Filter States
  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;
  Account? _accountFrom;
  Account? _accountTo;
  
  bool _pageBreakPerAccount = false;
  bool _hideZero = true;
  bool _isLoading = false;
  bool _reportGenerated = false;
  bool _isExporting = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 350.0;
  bool _isDraggingDivider = false;

  // Report Data
  List<Map<String, dynamic>> _beginningBalances = [];
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _allowedBranches = authService.allowedBranches;
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
      _branchList = branches
          .map((b) => {'id': b.id, 'code': b.branchCode, 'name': b.branchNameThai})
          .toList()
        ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));

      // โหลดเฉพาะบัญชีคุม (Control Account) สำหรับตัวกรอง
      _controlAccounts = await _accountService.fetchRowsControlAccount()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));

      final allAccounts = await _accountService.fetchRows();
      _accountMap = {for (var a in allAccounts) a.id!: a};
      _branchMap = {for (var e in branches) e.id!: e.branchCode};

      // โหลด Dimension Types และ Values (แสดงเฉพาะเมื่อมีการตั้งค่า dimension)
      _activeDimTypes = await _dimService.fetchActiveTypes();
      _dimValueMap = {};
      for (final dt in _activeDimTypes) {
        final vals = await _dimService.fetchValuesByType(dt.typeCode);
        for (final v in vals) {
          _dimValueMap[v.id] = v.valueCode;
        }
      }
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
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_controlAccounts);
    final current = isFrom ? _accountFrom : _accountTo;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void doFilter(String q) {
            setDlgState(() {
              if (q.isEmpty) {
                filtered = List.from(_controlAccounts);
              } else {
                final lq = q.toLowerCase();
                filtered = _controlAccounts
                    .where((a) =>
                        a.accountCode.toLowerCase().contains(lq) ||
                        a.accountNameThai.toLowerCase().contains(lq))
                    .toList();
              }
            });
          }

          return AlertDialog(
            title: Text(isFrom ? 'เลือกบัญชีเริ่มต้น' : 'เลือกบัญชีสิ้นสุด'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onChanged: doFilter,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('ไม่พบบัญชี'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final a = filtered[i];
                              final isSelected = current?.id == a.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.deepOrange.shade50,
                                leading: isSelected
                                    ? Icon(Icons.check_circle,
                                        color: Colors.deepOrange[900], size: 18)
                                    : const SizedBox(width: 18),
                                title: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        a.accountCode,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange[900]),
                                      ),
                                    ),
                                    Expanded(child: Text(a.accountNameThai)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        accountTypeOptions[a.accountType] ??
                                            a.accountType,
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    if (isFrom) _accountFrom = a;
                                    else _accountTo = a;
                                  });
                                  Navigator.of(ctx).pop();
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.close),
              ),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
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
        branchId: _selectedBranchId,
      );

      // 2. ดึงรายการเคลื่อนไหวจาก API
      _transactions = await _reportService.getGlTransactions(
        periodId: _selectedPeriod?.id,
        fiscalYearId: _selectedYear!.id,
        accountFrom: _accountFrom?.accountCode,
        accountTo: _accountTo?.accountCode,
        branchId: _selectedBranchId,
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
      // Group ด้วย Account + Branch + Dimensions (dim1..dim5)
      String key = "${t['account_id']}_${t['branch_id'] ?? 0}_${t['dim1_id'] ?? 0}_${t['dim2_id'] ?? 0}_${t['dim3_id'] ?? 0}_${t['dim4_id'] ?? 0}_${t['dim5_id'] ?? 0}";
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(t);
    }
    return grouped;
  }

  // --- Excel Export ---
  Future<void> _exportExcel() async {
    _isExporting = true;
    setState(() {});
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'GL');
      final s = ex['GL'];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final totBg = ExcelColor.fromHexString('#BDD7EE');
      final detBg = ExcelColor.fromHexString('#F2F2F2');

      String fmtDate(dynamic raw) {
        if (raw == null || raw.toString().isEmpty) return '';
        try {
          final d = DateTime.parse(raw.toString()).toLocal();
          return DateFormat('dd/MM/yyyy').format(DateTime(d.year, d.month, d.day));
        } catch (_) { return raw.toString(); }
      }

      final _periodLabel = _selectedPeriod != null
          ? 'งวด ${_selectedPeriod!.periodNumber} - ${_selectedPeriod!.periodName}'
          : 'ปี ${_selectedYear?.fyCode ?? ''}';
      final _ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.thaiName ?? '', bold: true);
      _xlCell(s, 1, 0, 'บัญชีแยกประเภท (General Ledger)', bold: true);
      _xlCell(s, 2, 0, '$_periodLabel  |  พิมพ์: $_ts');

      int r = 3;
      _xlCell(s, r, 0, 'รหัสบัญชี', bg: hdrBg, bold: true);
      _xlCell(s, r, 1, 'วันที่', bg: hdrBg, bold: true);
      _xlCell(s, r, 2, 'ประเภท', bg: hdrBg, bold: true);
      _xlCell(s, r, 3, 'เลขที่เอกสาร', bg: hdrBg, bold: true);
      _xlCell(s, r, 4, 'ลำดับ', bg: hdrBg, bold: true);
      _xlCell(s, r, 5, 'อ้างอิง', bg: hdrBg, bold: true);
      _xlCell(s, r, 6, 'คำอธิบาย', bg: hdrBg, bold: true);
      _xlCell(s, r, 7, 'เดบิต', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 8, 'เครดิต', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 9, 'คงเหลือ', bg: hdrBg, bold: true, align: HorizontalAlign.Right);
      _xlCell(s, r, 10, 'สาขา/มิติ', bg: hdrBg, bold: true);
      r++;

      final groupedData = _groupTransactions();
      final txKeys = groupedData.keys.toSet();

      List<Map<String, dynamic>> entries = [];
      groupedData.forEach((key, transactions) {
        final firstTx = transactions.first;
        entries.add({
          'key': key,
          'accId': firstTx['account_id'] as int,
          'accCode': firstTx['account_code'] as String? ?? '',
          'accName': "${firstTx['account_code']} ${firstTx['account_name_thai']}",
          'brId': firstTx['branch_id'] as int?,
          'dim1Id': firstTx['dim1_id'] as int?, 'dim2Id': firstTx['dim2_id'] as int?,
          'dim3Id': firstTx['dim3_id'] as int?, 'dim4Id': firstTx['dim4_id'] as int?,
          'dim5Id': firstTx['dim5_id'] as int?,
          'transactions': transactions,
          'begDr': null, 'begCr': null,
        });
      });

      for (var b in _beginningBalances) {
        final int bAccId = b['account_id'] as int;
        final int? bBrId = b['branch_id'] as int?;
        final int? bDim1 = b['dim1_id'] as int?; final int? bDim2 = b['dim2_id'] as int?;
        final int? bDim3 = b['dim3_id'] as int?; final int? bDim4 = b['dim4_id'] as int?;
        final int? bDim5 = b['dim5_id'] as int?;
        final String key = "${bAccId}_${bBrId ?? 0}_${bDim1 ?? 0}_${bDim2 ?? 0}_${bDim3 ?? 0}_${bDim4 ?? 0}_${bDim5 ?? 0}";
        if (txKeys.contains(key)) continue;
        final acc = _accountMap[bAccId];
        entries.add({
          'key': key, 'accId': bAccId,
          'accCode': acc?.accountCode ?? '',
          'accName': acc != null ? "${acc.accountCode} ${acc.accountNameThai}" : "Account $bAccId",
          'brId': bBrId, 'dim1Id': bDim1, 'dim2Id': bDim2, 'dim3Id': bDim3, 'dim4Id': bDim4, 'dim5Id': bDim5,
          'transactions': <Map<String, dynamic>>[],
          'begDr': double.tryParse(b['amount_dr']?.toString() ?? '0') ?? 0,
          'begCr': double.tryParse(b['amount_cr']?.toString() ?? '0') ?? 0,
        });
      }

      entries.sort((a, b) {
        int cmp = (a['accCode'] as String).compareTo(b['accCode'] as String);
        if (cmp != 0) return cmp;
        cmp = (a['brId'] as int? ?? 0).compareTo(b['brId'] as int? ?? 0);
        if (cmp != 0) return cmp;
        return (a['dim1Id'] as int? ?? 0).compareTo(b['dim1Id'] as int? ?? 0);
      });

      for (var entry in entries) {
        final int accId = entry['accId'] as int;
        final int? brId = entry['brId'] as int?;
        final int? dim1Id = entry['dim1Id'] as int?; final int? dim2Id = entry['dim2Id'] as int?;
        final int? dim3Id = entry['dim3Id'] as int?; final int? dim4Id = entry['dim4Id'] as int?;
        final int? dim5Id = entry['dim5Id'] as int?;
        final String accName = entry['accName'] as String;
        final List<Map<String, dynamic>> transactions = entry['transactions'] as List<Map<String, dynamic>>;

        double begDr = entry['begDr'] as double? ?? 0;
        double begCr = entry['begCr'] as double? ?? 0;
        if (entry['begDr'] == null) {
          try {
            var begRow = _beginningBalances.firstWhere((b) =>
              b['account_id'] == accId &&
              (b['branch_id'] == brId || (b['branch_id'] == null && brId == null)) &&
              (b['dim1_id'] == dim1Id || (b['dim1_id'] == null && dim1Id == null)) &&
              (b['dim2_id'] == dim2Id || (b['dim2_id'] == null && dim2Id == null)) &&
              (b['dim3_id'] == dim3Id || (b['dim3_id'] == null && dim3Id == null)) &&
              (b['dim4_id'] == dim4Id || (b['dim4_id'] == null && dim4Id == null)) &&
              (b['dim5_id'] == dim5Id || (b['dim5_id'] == null && dim5Id == null))
            );
            begDr = double.tryParse(begRow['amount_dr']?.toString() ?? '0') ?? 0;
            begCr = double.tryParse(begRow['amount_cr']?.toString() ?? '0') ?? 0;
          } catch (_) {}
        }

        if (_hideZero && begDr.abs() < 0.001 && begCr.abs() < 0.001 && transactions.isEmpty) continue;

        double runningBalance = begDr - begCr;

        final dimIds = [dim1Id, dim2Id, dim3Id, dim4Id, dim5Id];
        String brCode = brId != null ? (_branchMap[brId] ?? '') : '';
        final dimParts = <String>[];
        if (brCode.isNotEmpty) dimParts.add(brCode);
        for (int i = 0; i < _activeDimTypes.length && i < 5; i++) {
          final id = dimIds[i];
          if (id != null) {
            final code = _dimValueMap[id] ?? '';
            if (code.isNotEmpty) dimParts.add(code);
          }
        }
        final dimStr = dimParts.join('/');

        // Account header
        _xlCell(s, r, 0, accName, bold: true);
        for (int c = 1; c <= 10; c++) _xlCell(s, r, c, '', bold: true);
        r++;

        // Opening balance row
        _xlCell(s, r, 0, '', bg: detBg);
        _xlCell(s, r, 1, '', bg: detBg);
        _xlCell(s, r, 2, 'ยอดยกมา', bg: detBg, bold: true);
        for (int c = 3; c <= 8; c++) _xlCell(s, r, c, '', bg: detBg);
        _xlCell(s, r, 9, DoubleCellValue(runningBalance), bg: detBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, r, 10, dimStr, bg: detBg);
        r++;

        double sumDr = 0, sumCr = 0;
        for (var t in transactions) {
          final dr = double.tryParse(t['debit_lc'].toString()) ?? 0;
          final cr = double.tryParse(t['credit_lc'].toString()) ?? 0;
          runningBalance += (dr - cr);
          sumDr += dr; sumCr += cr;
          _xlCell(s, r, 0, '', bg: detBg);
          _xlCell(s, r, 1, fmtDate(t['doc_date']), bg: detBg);
          _xlCell(s, r, 2, t['doc_code']?.toString() ?? '', bg: detBg);
          _xlCell(s, r, 3, t['doc_no']?.toString() ?? '', bg: detBg);
          _xlCell(s, r, 4, t['line_no']?.toString() ?? '', bg: detBg);
          _xlCell(s, r, 5, '${t['ref_doc_code'] ?? ''} ${t['ref_doc_no'] ?? ''}'.trim(), bg: detBg);
          _xlCell(s, r, 6, t['description']?.toString() ?? '', bg: detBg);
          _xlCell(s, r, 7, dr == 0 ? TextCellValue('') : DoubleCellValue(dr), bg: detBg, align: HorizontalAlign.Right);
          _xlCell(s, r, 8, cr == 0 ? TextCellValue('') : DoubleCellValue(cr), bg: detBg, align: HorizontalAlign.Right);
          _xlCell(s, r, 9, DoubleCellValue(runningBalance), bg: detBg, align: HorizontalAlign.Right);
          _xlCell(s, r, 10, dimStr, bg: detBg);
          r++;
        }

        // Total row
        _xlCell(s, r, 0, 'รวม $accName', bg: totBg, bold: true);
        for (int c = 1; c <= 6; c++) _xlCell(s, r, c, '', bg: totBg);
        _xlCell(s, r, 7, DoubleCellValue(sumDr), bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, r, 8, DoubleCellValue(sumCr), bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, r, 9, DoubleCellValue(runningBalance), bg: totBg, bold: true, align: HorizontalAlign.Right);
        _xlCell(s, r, 10, '', bg: totBg);
        r++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'บัญชีแยกประเภท_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v,
      {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue ? v : (v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? ''));
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  // --- สร้าง PDF ---
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

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
              pw.Expanded(flex: 3, child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text("บัญชีแยกประเภท (General Ledger)", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text("หน้า ${context.pageNumber}/${context.pagesCount}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12)))
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(flex: 3, child: pw.Text("", style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 7, child: pw.Text(periodLine, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(flex: 3, child: pw.Text("พิมพ์โดย $userName", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12)))
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(flex: 10, child: pw.Text(conditionLine, textAlign: pw.TextAlign.left, style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text("พิมพ์เมื่อ $printDateStr", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12)))
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
                    .map((t) => pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(t, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))))
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
            child: pw.Text(entry.value, textAlign: align, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
          'dim1Id': firstTx['dim1_id'] as int?,
          'dim2Id': firstTx['dim2_id'] as int?,
          'dim3Id': firstTx['dim3_id'] as int?,
          'dim4Id': firstTx['dim4_id'] as int?,
          'dim5Id': firstTx['dim5_id'] as int?,
          'transactions': transactions,
          'begDr': null, // จะดึงในลูปหลัก
          'begCr': null,
        });
      });

      for (var b in _beginningBalances) {
        final int bAccId = b['account_id'] as int;
        final int? bBrId = b['branch_id'] as int?;
        final int? bDim1 = b['dim1_id'] as int?;
        final int? bDim2 = b['dim2_id'] as int?;
        final int? bDim3 = b['dim3_id'] as int?;
        final int? bDim4 = b['dim4_id'] as int?;
        final int? bDim5 = b['dim5_id'] as int?;
        final String key = "${bAccId}_${bBrId ?? 0}_${bDim1 ?? 0}_${bDim2 ?? 0}_${bDim3 ?? 0}_${bDim4 ?? 0}_${bDim5 ?? 0}";
        if (txKeys.contains(key)) continue;

        final acc = _accountMap[bAccId];
        entries.add({
          'key': key,
          'accId': bAccId,
          'accCode': acc?.accountCode ?? '',
          'accName': acc != null ? "${acc.accountCode} ${acc.accountNameThai}" : "Account $bAccId",
          'brId': bBrId,
          'dim1Id': bDim1, 'dim2Id': bDim2, 'dim3Id': bDim3, 'dim4Id': bDim4, 'dim5Id': bDim5,
          'transactions': <Map<String, dynamic>>[],
          'begDr': double.tryParse(b['amount_dr']?.toString() ?? '0') ?? 0,
          'begCr': double.tryParse(b['amount_cr']?.toString() ?? '0') ?? 0,
        });
      }

      // เรียงตามรหัสบัญชี -> สาขา -> dim1 -> dim2
      entries.sort((a, b) {
        int cmp = (a['accCode'] as String).compareTo(b['accCode'] as String);
        if (cmp != 0) return cmp;
        cmp = (a['brId'] as int? ?? 0).compareTo(b['brId'] as int? ?? 0);
        if (cmp != 0) return cmp;
        cmp = (a['dim1Id'] as int? ?? 0).compareTo(b['dim1Id'] as int? ?? 0);
        if (cmp != 0) return cmp;
        return (a['dim2Id'] as int? ?? 0).compareTo(b['dim2Id'] as int? ?? 0);
      });

      for (var entry in entries) {
        final int accId = entry['accId'] as int;
        final int? brId = entry['brId'] as int?;
        final int? dim1Id = entry['dim1Id'] as int?;
        final int? dim2Id = entry['dim2Id'] as int?;
        final int? dim3Id = entry['dim3Id'] as int?;
        final int? dim4Id = entry['dim4Id'] as int?;
        final int? dim5Id = entry['dim5Id'] as int?;
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
              (b['dim1_id'] == dim1Id || (b['dim1_id'] == null && dim1Id == null)) &&
              (b['dim2_id'] == dim2Id || (b['dim2_id'] == null && dim2Id == null)) &&
              (b['dim3_id'] == dim3Id || (b['dim3_id'] == null && dim3Id == null)) &&
              (b['dim4_id'] == dim4Id || (b['dim4_id'] == null && dim4Id == null)) &&
              (b['dim5_id'] == dim5Id || (b['dim5_id'] == null && dim5Id == null))
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

        // สร้าง dimension string จาก active dim types
        final dimIds = [dim1Id, dim2Id, dim3Id, dim4Id, dim5Id];
        String brCode = brId != null ? (_branchMap[brId] ?? '') : '';
        final dimParts = <String>[];
        if (brCode.isNotEmpty) dimParts.add('สาขา: $brCode');
        for (final dt in _activeDimTypes) {
          final id = dimIds[dt.slotNo - 1];
          final code = id != null ? (_dimValueMap[id] ?? '') : '';
          if (code.isNotEmpty) dimParts.add('${dt.nameThai}: $code');
        }
        String dims = dimParts.join(' / ');

        // [ส่วนที่ 1] บรรทัดยอดยกมา
        blocks.add(pw.Table(
          columnWidths: const { 0: pw.FlexColumnWidth(13.9), 1: pw.FlexColumnWidth(1.5) },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text("รหัส/ชื่อบัญชี: $accName ${dims.isNotEmpty ? '($dims)' : ''}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(fmt.format(runningBalance), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))
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
          String fDate = rawDate.length >= 10 ? DateFormat('dd/MM/yyyy').format(DateTime.parse(rawDate).toLocal()) : rawDate;

          String refRawDate = t['ref_doc_date']?.toString() ?? '';
          String fRefDate = refRawDate.length >= 10 ? DateFormat('dd/MM/yyyy').format(DateTime.parse(refRawDate).toLocal()) : refRawDate;

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
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text("ยอดรวมเดบิต / เครดิต / ยกไป", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(transactions.isEmpty ? '' : fmt.format(sumDr), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(transactions.isEmpty ? '' : fmt.format(sumCr), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(fmt.format(runningBalance), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: _reportGenerated ? _exportExcel : null,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _loadMasterData,
          ),
        ],
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
                      isExpanded: true,
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
                      isExpanded: true,
                      value: _selectedPeriod,
                      items: [
                        const DropdownMenuItem<PostingPeriod>(value: null, child: Text('ทุกงวด (ตั้งแต่ต้นปี)')),
                        ..._periods.skip(1).map((p) => DropdownMenuItem(value: p, child: Text("${p.periodNumber} - ${p.periodName}"))),
                      ],
                      decoration: const InputDecoration(labelText: 'งวดเดือน', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() => _selectedPeriod = val),
                    ),
                    const SizedBox(height: 16),
                    if (_allowedBranches.isNotEmpty) ...[
                      DropdownButtonFormField<int?>(
                        value: _selectedBranchId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'สาขา', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— ทุกสาขา —')),
                          ..._allowedBranches.map((b) => DropdownMenuItem<int?>(
                            value: b.branchId,
                            child: Text('${b.branchCode}  ${b.branchNameThai}', overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (val) => setState(() => _selectedBranchId = val),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'รหัสบัญชี (จาก)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _accountFrom != null
                                ? Text(
                                    '${_accountFrom!.accountCode} — ${_accountFrom!.accountNameThai}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : const Text('— ทั้งหมด —',
                                    style: TextStyle(color: Colors.grey)),
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.deepOrange[900]),
                            tooltip: 'ค้นหาบัญชีเริ่มต้น',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showAccountSearchDialog(true),
                          ),
                          if (_accountFrom != null)
                            IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.red, size: 18),
                              tooltip: 'ล้าง',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _accountFrom = null),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'รหัสบัญชี (ถึง)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _accountTo != null
                                ? Text(
                                    '${_accountTo!.accountCode} — ${_accountTo!.accountNameThai}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : const Text('— ทั้งหมด —',
                                    style: TextStyle(color: Colors.grey)),
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.deepOrange[900]),
                            tooltip: 'ค้นหาบัญชีสิ้นสุด',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showAccountSearchDialog(false),
                          ),
                          if (_accountTo != null)
                            IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.red, size: 18),
                              tooltip: 'ล้าง',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _accountTo = null),
                            ),
                        ],
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