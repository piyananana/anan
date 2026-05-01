import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
import '../../gl/services/daily_transaction_report_service.dart';
import '../../cd/services/branch_service.dart';
import '../../cd/services/business_unit_service.dart';
import '../../cd/services/project_service.dart';
import '../../sa/models/company.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';

class DailyTransactionReportScreen extends StatefulWidget {
  const DailyTransactionReportScreen({super.key});

  @override
  State<DailyTransactionReportScreen> createState() =>
      _DailyTransactionReportScreenState();
}

class _DailyTransactionReportScreenState
    extends State<DailyTransactionReportScreen> {
  // Services
  final CompanyService _companyService = CompanyService();
  final PeriodService _periodService = PeriodService();
  final DailyTransactionReportService _reportService =
      DailyTransactionReportService();
  final BranchService _branchService = BranchService();
  final BusinessUnitService _buService = BusinessUnitService();
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();

  // Auth
  late Map<String, String> _headers;

  // Master data
  Company? _company;
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];
  List<Map<String, dynamic>> _glDocTypes = [];
  List<Map<String, dynamic>> _refDocTypes = [];
  Map<int, String> _branchMap = {};
  Map<int, String> _buMap = {};
  Map<int, String> _projectMap = {};

  // Filter state
  FiscalYear? _selectedYear;
  PostingPeriod? _selectedPeriod;
  DateTime? _docDateFrom;
  DateTime? _docDateTo;
  Set<String> _selectedDocCodes = {};
  final _docNoFromCtrl = TextEditingController();
  final _docNoToCtrl = TextEditingController();
  Set<String> _selectedRefDocCodes = {};
  final _refDocNoFromCtrl = TextEditingController();
  final _refDocNoToCtrl = TextEditingController();
  DateTime? _refDocDateFrom;
  DateTime? _refDocDateTo;
  bool _useRefDocFilter = false; // default: ไม่กรองตามเอกสารอ้างอิง

  // Report
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;
  bool _reportGenerated = false;
  bool _isFilterExpanded = true;
  double _filterPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _docNoFromCtrl.dispose();
    _docNoToCtrl.dispose();
    _refDocNoFromCtrl.dispose();
    _refDocNoToCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    _headers = await _authService.getAuthHeader();
    _company = await _companyService.fetchCompany();
    try {
      _fiscalYears = await _periodService.fetchActiveFiscalYears();
      if (_fiscalYears.isNotEmpty) {
        final now = DateTime.now();
        try {
          _selectedYear = _fiscalYears.firstWhere(
            (fy) => now.isAfter(fy.yearStartDate) && now.isBefore(fy.yearEndDate),
          );
        } catch (_) {
          _selectedYear = _fiscalYears.first;
        }
        await _loadPeriods(_selectedYear!.id);
      }

      final docTypes = await _reportService.getDocTypes();
      _glDocTypes = docTypes.where((d) => d['sys_module'] == '01').toList();
      _refDocTypes = docTypes.where((d) => d['sys_module'] != '01').toList();

      final branches = await _branchService.fetchRows();
      final bus = await _buService.fetchRows();
      final projects = await _projectService.fetchRows();
      _branchMap = {for (var e in branches) e.id!: e.branchCode};
      _buMap = {for (var e in bus) e.id!: e.buCode};
      _projectMap = {for (var e in projects) e.id!: e.projectCode};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading master: $e')));
      }
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
    _applyPeriodDefaults(null);
  }

  void _applyPeriodDefaults(PostingPeriod? period) {
    if (period != null) {
      setState(() {
        _docDateFrom = period.periodStartDate;
        _docDateTo = period.periodEndDate;
        _refDocDateFrom = period.periodStartDate;
        _refDocDateTo = period.periodEndDate;
      });
    } else if (_selectedYear != null) {
      setState(() {
        _docDateFrom = _selectedYear!.yearStartDate;
        _docDateTo = _selectedYear!.yearEndDate;
        _refDocDateFrom = _selectedYear!.yearStartDate;
        _refDocDateTo = _selectedYear!.yearEndDate;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกปีบัญชี')));
      return;
    }
    setState(() {
      _isLoading = true;
      _reportGenerated = false;
    });
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final data = await _reportService.getDailyTransactions(
        fiscalYearId: _selectedYear!.id,
        periodId: _selectedPeriod?.id,
        docDateFrom: _docDateFrom != null ? dateFormat.format(_docDateFrom!) : null,
        docDateTo: _docDateTo != null ? dateFormat.format(_docDateTo!) : null,
        docCodes: _selectedDocCodes.isEmpty ? null : _selectedDocCodes.toList(),
        docNoFrom: _docNoFromCtrl.text.trim().isEmpty ? null : _docNoFromCtrl.text.trim(),
        docNoTo: _docNoToCtrl.text.trim().isEmpty ? null : _docNoToCtrl.text.trim(),
        refDocCodes: _useRefDocFilter && _selectedRefDocCodes.isNotEmpty ? _selectedRefDocCodes.toList() : null,
        refDocNoFrom: _useRefDocFilter && _refDocNoFromCtrl.text.trim().isNotEmpty ? _refDocNoFromCtrl.text.trim() : null,
        refDocNoTo: _useRefDocFilter && _refDocNoToCtrl.text.trim().isNotEmpty ? _refDocNoToCtrl.text.trim() : null,
        refDocDateFrom: _useRefDocFilter && _refDocDateFrom != null ? dateFormat.format(_refDocDateFrom!) : null,
        refDocDateTo: _useRefDocFilter && _refDocDateTo != null ? dateFormat.format(_refDocDateTo!) : null,
      );
      setState(() {
        _reportData = data;
        _reportGenerated = data.isNotEmpty;
      });
      if (data.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลตามเงื่อนไขที่เลือก')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Multi-select dialog ──────────────────────────────────────────────────

  Future<void> _showMultiSelectDialog({
    required String title,
    required List<Map<String, dynamic>> options,
    required Set<String> selected,
    required Function(Set<String>) onChanged,
  }) async {
    Set<String> temp = Set.from(selected);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            height: 400,
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('เลือกทั้งหมด'),
                  value: temp.length == options.length
                      ? true
                      : (temp.isEmpty ? false : null),
                  tristate: true,
                  onChanged: (v) => setD(() {
                    if (temp.length < options.length) {
                      temp = options.map<String>((o) => o['doc_code'] as String).toSet();
                    } else {
                      temp.clear();
                    }
                  }),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView(
                    children: options.map((opt) {
                      final code = opt['doc_code'] as String;
                      return CheckboxListTile(
                        dense: true,
                        title: Text('$code  ${opt['doc_name_thai'] ?? ''}',
                            style: const TextStyle(fontSize: 13)),
                        value: temp.contains(code),
                        onChanged: (v) => setD(() {
                          if (v == true) {
                            temp.add(code);
                          } else {
                            temp.remove(code);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            ElevatedButton(
                onPressed: () {
                  onChanged(temp);
                  Navigator.pop(ctx);
                },
                child: const Text('ตกลง')),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ───────────────────────────────────────────────────────

  Widget _buildMultiSelectField(
      String label, List<Map<String, dynamic>> options, Set<String> selected,
      Function(Set<String>) onChanged) {
    final displayText = selected.isEmpty || selected.length == options.length
        ? 'ทั้งหมด'
        : selected.join(', ');
    return InkWell(
      onTap: () => _showMultiSelectDialog(
          title: label,
          options: options,
          selected: selected.isEmpty
              ? options.map<String>((o) => o['doc_code'] as String).toSet()
              : selected,
          onChanged: (v) => setState(() => onChanged(v))),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down)),
        child: Text(displayText,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildDateField(
      String label, DateTime? value, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (d != null) setState(() => onChanged(d));
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon:
                const Icon(Icons.calendar_today, size: 18)),
        child: Text(
            value != null ? DateFormat('dd/MM/yyyy').format(value) : '-',
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  // ── PDF Generation ───────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final dfmt = DateFormat('dd/MM/yyyy');

    final companyName = _company?.thaiName ?? '(ไม่ระบุชื่อบริษัท)';
    final userName = _headers['UserName'] ?? '(ไม่ระบุชื่อ)';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Period / date label
    String periodLabel = _selectedPeriod != null
        ? 'งวด ${_selectedPeriod!.periodNumber} - ${_selectedPeriod!.periodName}'
        : 'ปี ${_selectedYear?.fyCode ?? ''}';
    String dateRangeLabel = '';
    if (_docDateFrom != null && _docDateTo != null) {
      dateRangeLabel =
          '(${dfmt.format(_docDateFrom!)} – ${dfmt.format(_docDateTo!)})';
    }

    // Column widths (total flex = 11.2) reused in detail table, total row, page header
    const colWidths = {
      0: pw.FlexColumnWidth(1.2), // รหัสบัญชี
      1: pw.FlexColumnWidth(3.0), // ชื่อบัญชี
      2: pw.FlexColumnWidth(1.5), // มิติ
      3: pw.FlexColumnWidth(2.5), // คำอธิบาย
      4: pw.FlexColumnWidth(1.5), // เดบิต
      5: pw.FlexColumnWidth(1.5), // เครดิต
    };
    // Header banner column widths (same total 11.2)
    const hdrColWidths = {
      0: pw.FlexColumnWidth(8.2), // doc info
      1: pw.FlexColumnWidth(3.0), // ref info
    };

    pw.Widget buildPageHeader(pw.Context ctx) {
      return pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(
              flex: 3,
              child: pw.Text(companyName,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 7,
              child: pw.Text('บันทึกรายการบัญชี (Daily Transaction)',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Text('')),
          pw.Expanded(
              flex: 7,
              child: pw.Text('$periodLabel $dateRangeLabel',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(
              flex: 3,
              child: pw.Text('พิมพ์โดย $userName',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(flex: 10, child: pw.Text('')),
          pw.Expanded(
              flex: 3,
              child: pw.Text('พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 3),
        // Column header row
        pw.Table(
          columnWidths: colWidths,
          border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                'รหัสบัญชี',
                'ชื่อบัญชี',
                'สาขา/หน่วยงาน\n/โครงการ',
                'คำอธิบายรายการ',
                'เดบิต',
                'เครดิต',
              ]
                  .asMap()
                  .entries
                  .map((e) => pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(e.value,
                            textAlign: e.key >= 4
                                ? pw.TextAlign.center
                                : pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ]);
    }

    // Build list of widgets for all documents
    List<pw.Widget> blocks = [];

    for (final entry in _reportData) {
      final docDate = entry['doc_date'] != null
          ? dfmt.format(DateTime.parse(entry['doc_date'].toString()).toLocal())
          : '';
      final docCode = entry['doc_code'] ?? '';
      final docNo = entry['doc_no'] ?? '';
      final description = entry['description'] ?? '';
      final refDocCode = entry['ref_doc_code'] ?? '';
      final refDocNo = entry['ref_doc_no'] ?? '';
      final refDocDate = entry['ref_doc_date'] != null
          ? dfmt.format(
              DateTime.parse(entry['ref_doc_date'].toString()).toLocal())
          : '';

      final details =
          List<Map<String, dynamic>>.from(entry['details'] as List);

      double sumDr = 0, sumCr = 0;
      for (final d in details) {
        sumDr += (d['debit_lc'] as num).toDouble();
        sumCr += (d['credit_lc'] as num).toDouble();
      }
      final isBalanced = (sumDr - sumCr).abs() < 0.005;

      // 1. Document banner (grey, no border)
      blocks.add(pw.Table(
        columnWidths: hdrColWidths,
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(6, 4, 4, 4),
                child: pw.Text(
                  'วันที่: $docDate   '
                  '${docCode.isNotEmpty ? '$docCode  ' : ''}'
                  '${docNo.isNotEmpty ? '$docNo  ' : ''}'
                  '${description.isNotEmpty ? '| $description' : ''}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(4, 4, 6, 4),
                child: pw.Text(
                  [
                    if (refDocCode.isNotEmpty) 'อ้างอิง: $refDocCode',
                    if (refDocNo.isNotEmpty) refDocNo,
                    if (refDocDate.isNotEmpty) refDocDate,
                  ].join('  '),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ));

      // 2. Detail rows
      final detailRows = details.map((d) {
        final accCode = d['account_code'] ?? '';
        final accName = d['account_name_thai'] ?? '';
        final dr = (d['debit_lc'] as num).toDouble();
        final cr = (d['credit_lc'] as num).toDouble();
        final desc = d['description'] ?? '';

        final brCode = d['branch_id'] != null
            ? (_branchMap[d['branch_id']] ?? '')
            : '';
        final buCode = d['business_unit_id'] != null
            ? (_buMap[d['business_unit_id']] ?? '')
            : '';
        final pjCode = d['project_id'] != null
            ? (_projectMap[d['project_id']] ?? '')
            : '';
        final dimParts = [brCode, buCode, pjCode]
            .where((s) => s.isNotEmpty)
            .toList();
        final dimStr = dimParts.isEmpty ? '' : dimParts.join('/');

        return pw.TableRow(children: [
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Text(accCode,
                  style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Text(accName,
                  style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Text(dimStr,
                  style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Text(desc,
                  style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      dr == 0 ? '' : fmt.format(dr),
                      style: const pw.TextStyle(fontSize: 8)))),
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      cr == 0 ? '' : fmt.format(cr),
                      style: const pw.TextStyle(fontSize: 8)))),
        ]);
      }).toList();

      blocks.add(pw.Table(
        columnWidths: colWidths,
        border: const pw.TableBorder(
          left: pw.BorderSide(width: 0.5),
          right: pw.BorderSide(width: 0.5),
          bottom: pw.BorderSide(width: 0.5),
          verticalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey400),
        ),
        children: detailRows,
      ));

      // 3. Total row (4 columns, same total flex 11.2 = 1.2+7.0+1.5+1.5)
      const PdfColor lightRed = PdfColor(1.0, 0.85, 0.85);
      blocks.add(pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1.2),
          1: pw.FlexColumnWidth(7.0),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(1.5),
        },
        border: pw.TableBorder.all(
            color: PdfColors.grey700, width: 0.5),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
                color: isBalanced ? PdfColors.grey100 : lightRed),
            children: [
              // Warning cell
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: isBalanced
                    ? pw.SizedBox()
                    : pw.Text('⚠ ไม่ดุล!',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900)),
              ),
              // Label
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('ยอดรวมเดบิต / เครดิต',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
              ),
              // Total debit
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(fmt.format(sumDr),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
              ),
              // Total credit
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(fmt.format(sumCr),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
              ),
            ],
          ),
        ],
      ));

      blocks.add(pw.SizedBox(height: 10));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(20),
      header: buildPageHeader,
      footer: (ctx) => pw.Column(children: [pw.Divider(thickness: 0.5)]),
      build: (ctx) => blocks,
    ));

    return doc.save();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.receipt_long, color: Colors.white, size: 20), SizedBox(width: 8), Text('บันทึกรายการบัญชี (Daily Transaction)')]),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
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
            color: Colors.indigo[800],
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('เงื่อนไขรายงาน',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 14),

                            // ── ปีบัญชี ──
                            DropdownButtonFormField<FiscalYear>(
                              value: _selectedYear,
                              items: _fiscalYears
                                  .map((fy) => DropdownMenuItem(
                                      value: fy,
                                      child: Text(fy.fyCode)))
                                  .toList(),
                              decoration: const InputDecoration(
                                  labelText: 'ปีบัญชี',
                                  border: OutlineInputBorder()),
                              onChanged: (v) async {
                                if (v != null) {
                                  setState(() => _selectedYear = v);
                                  await _loadPeriods(v.id);
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // ── งวด ──
                            DropdownButtonFormField<PostingPeriod?>(
                              value: _selectedPeriod,
                              items: [
                                const DropdownMenuItem<PostingPeriod?>(
                                    value: null,
                                    child: Text('ทุกงวด (ตั้งแต่ต้นปี)')),
                                ..._periods.map((p) =>
                                    DropdownMenuItem(
                                        value: p,
                                        child: Text(
                                            '${p.periodNumber} - ${p.periodName}'))),
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'งวด',
                                  border: OutlineInputBorder()),
                              onChanged: (v) {
                                setState(() => _selectedPeriod = v);
                                _applyPeriodDefaults(v);
                              },
                            ),
                            const SizedBox(height: 14),

                            // ── วันที่เอกสาร ──
                            _buildSectionLabel('วันที่เอกสาร'),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(
                                  child: _buildDateField(
                                      'จาก',
                                      _docDateFrom,
                                      (d) => _docDateFrom = d)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _buildDateField(
                                      'ถึง',
                                      _docDateTo,
                                      (d) => _docDateTo = d)),
                            ]),
                            const SizedBox(height: 14),

                            // ── ประเภทเอกสาร GL ──
                            _buildSectionLabel('เอกสาร GL'),
                            const SizedBox(height: 6),
                            _buildMultiSelectField(
                                'ประเภทเอกสาร GL',
                                _glDocTypes,
                                _selectedDocCodes,
                                (v) => _selectedDocCodes = v),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                      controller: _docNoFromCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'เลขที่เอกสาร จาก',
                                          border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: TextField(
                                      controller: _docNoToCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'เลขที่เอกสาร ถึง',
                                          border: OutlineInputBorder()))),
                            ]),
                            const SizedBox(height: 14),

                            // ── เอกสารอ้างอิง ──
                            Row(
                              children: [
                                Expanded(child: _buildSectionLabel('เอกสารอ้างอิง')),
                                Switch(
                                  value: _useRefDocFilter,
                                  activeColor: Colors.indigo[800],
                                  onChanged: (v) =>
                                      setState(() => _useRefDocFilter = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Opacity(
                              opacity: _useRefDocFilter ? 1.0 : 0.38,
                              child: IgnorePointer(
                                ignoring: !_useRefDocFilter,
                                child: Column(
                                  children: [
                                    _buildMultiSelectField(
                                        'ประเภทเอกสารอ้างอิง',
                                        _refDocTypes,
                                        _selectedRefDocCodes,
                                        (v) => _selectedRefDocCodes = v),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                          child: TextField(
                                              controller: _refDocNoFromCtrl,
                                              decoration: const InputDecoration(
                                                  labelText: 'เลขที่อ้างอิง จาก',
                                                  border: OutlineInputBorder()))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: TextField(
                                              controller: _refDocNoToCtrl,
                                              decoration: const InputDecoration(
                                                  labelText: 'เลขที่อ้างอิง ถึง',
                                                  border: OutlineInputBorder()))),
                                    ]),
                                    const SizedBox(height: 8),
                                    _buildSectionLabel('วันที่เอกสารอ้างอิง'),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Expanded(
                                          child: _buildDateField(
                                              'จาก',
                                              _refDocDateFrom,
                                              (d) => _refDocDateFrom = d)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: _buildDateField(
                                              'ถึง',
                                              _refDocDateTo,
                                              (d) => _refDocDateTo = d)),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.picture_as_pdf),
                        label: const Text('ประมวลผลรายงาน'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[800],
                            foregroundColor: Colors.white),
                        onPressed: _isLoading ? null : _generateReport,
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

          // ── PDF Preview panel ──
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: !_reportGenerated
                  ? const Center(
                      child: Text('กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                  : PdfPreview(
                      build: (f) => _generatePdf(f),
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

  Widget _buildSectionLabel(String text) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[800]));
}
