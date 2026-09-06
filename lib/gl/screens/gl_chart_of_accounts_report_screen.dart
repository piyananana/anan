import 'package:flutter/services.dart';
import 'package:anan/sa/models/sa_company.dart';
import 'package:anan/sa/services/sa_company_service.dart';
import 'package:excel/excel.dart';
import '../../utils/file_download.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/gl_account.dart';
import '../services/gl_account_service.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';
import '../../sa/services/sa_auth_service.dart';

class ChartOfAccountsReportScreen extends StatefulWidget {
  const ChartOfAccountsReportScreen({super.key});

  @override
  State<ChartOfAccountsReportScreen> createState() =>
      _ChartOfAccountsReportScreenState();
}

class _ChartOfAccountsReportScreenState
    extends State<ChartOfAccountsReportScreen> {
  final CompanyService _companyService = CompanyService();
  final AccountService _accountService = AccountService();
  final GlDimensionService _dimService = GlDimensionService();
  final AuthService authService = AuthService();
  late Map<String, String> headers;

  Company? _company;
  // ชื่อรายงาน — ใช้ชื่อเมนู (จาก AppBar/MenuTitle) แทนข้อความ hardcode เพื่อให้ตรงกับที่ผู้ใช้เห็นบนแท็บเสมอ
  String _reportTitle = '';
  List<Account> _accounts = [];
  final Map<int, int> _accountLevels = {};
  Map<String, GlDimensionType> _dimTypeMap = {};

  List<Account> _reportData = [];

  // Filter States
  Set<String> _selectedAccountTypes = {};
  Account? _accountFrom;
  Account? _accountTo;
  String _status = 'active';
  bool _pageBreakPerType = false;
  bool _showHeaderAccounts = true;

  bool _isLoading = false;
  bool _isExporting = false;
  bool _isFilterExpanded = true;
  bool _isEnglish = false;
  double _filterPanelWidth = 350.0;
  bool _isDraggingDivider = false;

  static final Map<int, pw.TableColumnWidth> _colWidths = {
    0: const pw.FlexColumnWidth(1.0),
    1: const pw.FlexColumnWidth(4.0),
    2: const pw.FlexColumnWidth(1.0),
    3: const pw.FlexColumnWidth(0.9),
    4: const pw.FlexColumnWidth(0.9),
    5: const pw.FlexColumnWidth(3.6),
  };

  List<Map<String, dynamic>> _accountTypeOptionsList(bool isEnglish) =>
      accountTypeOptions.entries
          .map((e) => {'doc_code': e.key, 'doc_name_thai': '${isEnglish ? (accountTypeOptionsEng[e.key] ?? e.value) : e.value} (${e.key})'})
          .toList();

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
      _accounts = await _accountService.fetchAllRows();
      final dimTypes = await _dimService.fetchActiveTypes();
      _dimTypeMap = {for (var d in dimTypes) d.typeCode: d};
      _calculateAccountLevels(_accounts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_isEnglish ? 'Error loading master data: $e' : 'เกิดข้อผิดพลาดในการโหลดข้อมูลหลัก: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateAccountLevels(List<Account> accounts) {
    _accountLevels.clear();
    final Map<int, int?> parentMap = {for (var a in accounts) a.id: a.parentId};
    for (var a in accounts) {
      int level = 0;
      int? currentId = a.id;
      int safeguard = 0;
      while (parentMap[currentId] != null && safeguard < 10) {
        level++;
        currentId = parentMap[currentId];
        safeguard++;
      }
      _accountLevels[a.id] = level;
    }
  }

  // เรียงลำดับบัญชีตามผังบัญชี (ต้นไม้): root ก่อน แล้วลูกเรียงตามรหัสบัญชี
  List<Account> _sortedTree(List<Account> all) {
    final List<Account> result = [];
    void walk(int? parentId) {
      final children = all.where((a) => a.parentId == parentId).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
      for (final c in children) {
        result.add(c);
        walk(c.id);
      }
    }
    walk(null);
    return result;
  }

  void _generateReport() {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'No chart of accounts found' : 'ไม่พบข้อมูลผังบัญชี')));
      return;
    }

    List<Account> ordered = _sortedTree(_accounts);

    if (_selectedAccountTypes.isNotEmpty &&
        _selectedAccountTypes.length < accountTypeOptions.length) {
      ordered = ordered
          .where((a) => _selectedAccountTypes.contains(a.accountType))
          .toList();
    }
    if (_accountFrom != null) {
      ordered = ordered
          .where((a) => a.accountCode.compareTo(_accountFrom!.accountCode) >= 0)
          .toList();
    }
    if (_accountTo != null) {
      ordered = ordered
          .where((a) => a.accountCode.compareTo(_accountTo!.accountCode) <= 0)
          .toList();
    }
    if (!_showHeaderAccounts) {
      ordered = ordered.where((a) => a.isNormalAccount).toList();
    }
    if (_status == 'active')   ordered = ordered.where((a) =>  a.isActive).toList();
    if (_status == 'inactive') ordered = ordered.where((a) => !a.isActive).toList();

    if (ordered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'No accounts match the selected conditions'
              : 'ไม่พบบัญชีตามเงื่อนไขที่เลือก')));
    }

    setState(() => _reportData = ordered);
  }

  // จัดกลุ่มบัญชีที่มี accountType เดียวกันต่อเนื่องกันไว้กลุ่มเดียวกัน (รักษาลำดับผังบัญชีเดิม)
  List<List<Account>> _groupByType(List<Account> accounts) {
    final List<List<Account>> groups = [];
    for (final a in accounts) {
      if (groups.isNotEmpty && groups.last.first.accountType == a.accountType) {
        groups.last.add(a);
      } else {
        groups.add([a]);
      }
    }
    return groups;
  }

  // รวมค่าจาก switch ต่างๆ ในหน้า account_detail_widget ที่ "เปิดใช้งาน" คั่นด้วย " | "
  String _settingsText(Account a, bool isEnglish) {
    final List<String> parts = [];
    if (!a.isNormalAccount) parts.add(isEnglish ? 'Header/Group Account' : 'หัวบัญชี/บัญชีรวม');
    if (a.isControlAccount) parts.add('Control Account');
    if (a.branchRequired) parts.add(isEnglish ? 'Branch Required' : 'ระบุสาขา');
    for (final r in a.dimRules.where((r) => r.isRequired)) {
      final label = _dimTypeMap[r.typeCode]?.nameThai ?? r.typeCode;
      parts.add(isEnglish ? 'Require $label' : 'ระบุ$label');
    }
    return parts.join(' | ');
  }

  String _buildFilterLine(bool isEnglish) {
    final List<String> parts = [];
    if (_selectedAccountTypes.isEmpty ||
        _selectedAccountTypes.length == accountTypeOptions.length) {
      parts.add(isEnglish ? 'Account Type: All' : 'หมวดบัญชี: ทั้งหมด');
    } else {
      final typesText = _selectedAccountTypes
          .map((t) => accountTypeLabel(t, isEnglish))
          .join(', ');
      parts.add(isEnglish ? 'Account Type: $typesText' : 'หมวดบัญชี: $typesText');
    }
    final allText = isEnglish ? 'All' : 'ทั้งหมด';
    parts.add(isEnglish
        ? 'Account Code: ${_accountFrom?.accountCode ?? allText} - ${_accountTo?.accountCode ?? allText}'
        : 'รหัสบัญชี: ${_accountFrom?.accountCode ?? allText} - ${_accountTo?.accountCode ?? allText}');
    if (_status == 'active') {
      parts.add(isEnglish ? 'Status: Active' : 'สถานะ: ใช้งาน');
    } else if (_status == 'inactive') {
      parts.add(isEnglish ? 'Status: Inactive' : 'สถานะ: หยุดใช้งาน');
    } else {
      parts.add(isEnglish ? 'Status: All' : 'สถานะ: ทั้งหมด');
    }
    if (!_showHeaderAccounts) {
      parts.add(isEnglish ? 'Exclude header accounts' : 'ไม่รวมหัวบัญชี/บัญชีรวม');
    }
    return '* ${parts.join("  |  ")}';
  }

  // ── Multi-select dialog ──────────────────────────────────────────────────

  Future<void> _showMultiSelectDialog({
    required String title,
    required List<Map<String, dynamic>> options,
    required Set<String> selected,
    required Function(Set<String>) onChanged,
  }) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    Set<String> temp = Set.from(selected);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            height: 320,
            child: Column(
              children: [
                CheckboxListTile(
                  title: Text(isEnglish ? 'Select All' : 'เลือกทั้งหมด'),
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
                        title: Text(opt['doc_name_thai'] ?? code,
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
                child: Text(l.cancel)),
            ElevatedButton(
                onPressed: () {
                  onChanged(temp);
                  Navigator.pop(ctx);
                },
                child: Text(isEnglish ? 'OK' : 'ตกลง')),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectField(
      String label, List<Map<String, dynamic>> options, Set<String> selected,
      Function(Set<String>) onChanged) {
    final displayText = selected.isEmpty || selected.length == options.length
        ? (_isEnglish ? 'All' : 'ทั้งหมด')
        : selected.map((c) {
            final opt = options.firstWhere((o) => o['doc_code'] == c,
                orElse: () => {'doc_code': c, 'doc_name_thai': c});
            return opt['doc_name_thai'] ?? c;
          }).join(', ');
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

  // ── Dialog ค้นหาบัญชี ──────────────────────────────────────────────────────

  Future<void> _showAccountSearchDialog(bool isFrom) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts)
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    final current = isFrom ? _accountFrom : _accountTo;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void doFilter(String q) {
            setDlgState(() {
              if (q.isEmpty) {
                filtered = List.from(_accounts)
                  ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
              } else {
                final lq = q.toLowerCase();
                filtered = _accounts
                    .where((a) =>
                        a.accountCode.toLowerCase().contains(lq) ||
                        a.accountNameThai.toLowerCase().contains(lq) ||
                        a.accountNameEng.toLowerCase().contains(lq))
                    .toList()
                  ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
              }
            });
          }

          return AlertDialog(
            title: Text(isFrom
                ? (isEnglish ? 'Select Start Account' : 'เลือกบัญชีเริ่มต้น')
                : (isEnglish ? 'Select End Account' : 'เลือกบัญชีสิ้นสุด')),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: isEnglish ? 'Search code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onChanged: doFilter,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text(isEnglish ? 'No accounts found' : 'ไม่พบบัญชี'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final a = filtered[i];
                              final isSelected = current?.id == a.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.indigo.shade50,
                                leading: isSelected
                                    ? Icon(Icons.check_circle,
                                        color: Colors.indigo[900], size: 18)
                                    : const SizedBox(width: 18),
                                title: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        a.accountCode,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo[900]),
                                      ),
                                    ),
                                    Expanded(
                                        child: Text(isEnglish && a.accountNameEng.isNotEmpty
                                            ? a.accountNameEng
                                            : a.accountNameThai)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        accountTypeLabel(a.accountType, isEnglish),
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    if (isFrom) {
                                      _accountFrom = a;
                                    } else {
                                      _accountTo = a;
                                    }
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

  // ── Excel Export ─────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      ex.rename('Sheet1', 'ChartOfAccounts');
      final s = ex['ChartOfAccounts'];
      final hdrBg = ExcelColor.fromHexString('#92D050');

      final ts = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      _xlCell(s, 0, 0, _company?.displayName(_isEnglish) ?? '', bold: true);
      _xlCell(s, 1, 0, reportTitle, bold: true);
      _xlCell(s, 2, 0, '${_buildFilterLine(isEnglish)}  |  ${isEnglish ? 'Printed: $ts' : 'พิมพ์: $ts'}');

      int r = 3;
      final colHeaders = isEnglish
          ? ['Account Code', 'Account Name (TH/EN)', 'Balance', 'Currency', 'Status', 'Settings']
          : ['รหัสบัญชี', 'ชื่อบัญชี (ไทย/อังกฤษ)', 'ยอดดุล', 'สกุลเงิน', 'สถานะ', 'การตั้งค่าต่างๆ'];
      for (int c = 0; c < colHeaders.length; c++) {
        _xlCell(s, r, c, colHeaders[c], bg: hdrBg, bold: true);
      }
      r++;

      for (final group in _groupByType(_reportData)) {
        _xlCell(
            s, r, 0,
            isEnglish
                ? 'Account Type: ${accountTypeLabel(group.first.accountType, true)} (${group.first.accountType})'
                : 'หมวดบัญชี: ${accountTypeOptions[group.first.accountType] ?? group.first.accountType} (${group.first.accountType})',
            bold: true);
        r++;
        for (final a in group) {
          final level = _accountLevels[a.id] ?? 0;
          final nameText = a.accountNameEng.trim().isNotEmpty
              ? '${a.accountNameThai} - ${a.accountNameEng}'
              : a.accountNameThai;
          _xlCell(s, r, 0, a.accountCode);
          _xlCell(s, r, 1, '${'    ' * level}$nameText');
          _xlCell(s, r, 2, a.normalBalance == 'DR' ? (isEnglish ? 'DR' : 'เดบิต') : (isEnglish ? 'CR' : 'เครดิต'));
          _xlCell(s, r, 3, a.currencyCode);
          _xlCell(s, r, 4, a.isActive ? (isEnglish ? 'Active' : 'ใช้งาน') : (isEnglish ? 'Inactive' : 'หยุดใช้งาน'));
          _xlCell(s, r, 5, _settingsText(a, isEnglish));
          r++;
        }
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final ts2 = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, 'ผังบัญชี_$ts2.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xlCell(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is CellValue ? v : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      bold: bold,
    );
  }

  // ── PDF Generation ───────────────────────────────────────────────────────

  pw.Widget _tableHeaderRow(bool isEnglish) {
    pw.Widget cell(String text) => pw.Container(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey800, width: 1)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(text,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        );

    final headers = isEnglish
        ? ['Account Code', 'Account Name (TH/EN)', 'Balance', 'Currency', 'Status', 'Settings']
        : ['รหัสบัญชี', 'ชื่อบัญชี (ไทย/อังกฤษ)', 'ยอดดุล', 'สกุลเงิน', 'สถานะ', 'การตั้งค่าต่างๆ'];

    return pw.Table(columnWidths: _colWidths, children: [
      pw.TableRow(children: headers.map(cell).toList()),
    ]);
  }

  pw.Widget _buildAccountRow(Account a, bool isEnglish) {
    final level = _accountLevels[a.id] ?? 0;
    final double indent = level * 10.0;
    const cellStyle = pw.TextStyle(fontSize: 10);
    const rowDecoration = pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
    );

    pw.Widget cell(pw.Widget child, {pw.EdgeInsets? padding}) => pw.Container(
          decoration: rowDecoration,
          padding: padding ?? const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: child,
        );

    final nameText = a.accountNameEng.trim().isNotEmpty
        ? '${a.accountNameThai} - ${a.accountNameEng}'
        : a.accountNameThai;

    return pw.Table(columnWidths: _colWidths, children: [
      pw.TableRow(children: [
        cell(pw.Text(a.accountCode, style: cellStyle)),
        cell(
          pw.Text(nameText, style: cellStyle),
          padding: pw.EdgeInsets.only(left: 4 + indent, right: 4, top: 3, bottom: 3),
        ),
        cell(pw.Text(a.normalBalance == 'DR' ? (isEnglish ? 'DR' : 'เดบิต') : (isEnglish ? 'CR' : 'เครดิต'), style: cellStyle)),
        cell(pw.Text(a.currencyCode, style: cellStyle)),
        cell(pw.Text(a.isActive ? (isEnglish ? 'Active' : 'ใช้งาน') : (isEnglish ? 'Inactive' : 'หยุดใช้งาน'), style: cellStyle)),
        cell(pw.Text(_settingsText(a, isEnglish), style: const pw.TextStyle(fontSize: 9))),
      ]),
    ]);
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final isEnglish = _isEnglish;
    final reportTitle = _reportTitle;
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final String companyName = _company != null
        ? _company!.displayName(isEnglish)
        : (isEnglish ? '(No company name)' : '(ไม่ระบุชื่อบริษัท)');
    final String userName = headers['UserName'] ?? (isEnglish ? '(Unknown user)' : '(ไม่ระบุชื่อ)');
    final String printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String filterLine = _buildFilterLine(isEnglish);
    final int totalAccounts = _reportData.length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(20),
      header: (context) {
        return pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(companyName, style: const pw.TextStyle(fontSize: 12))),
                pw.Expanded(
                    flex: 6,
                    child: pw.Text(reportTitle,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                        isEnglish
                            ? 'Page ${context.pageNumber}/${context.pagesCount}'
                            : 'หน้า ${context.pageNumber}/${context.pagesCount}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 9,
                    child: pw.Text(filterLine, style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                        isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                    flex: 9,
                    child: pw.Text(
                        isEnglish
                            ? '* Total $totalAccounts accounts'
                            : '* ทั้งหมด $totalAccounts บัญชี',
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                        isEnglish ? 'Printed $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
            pw.SizedBox(height: 6),
            _tableHeaderRow(isEnglish),
          ],
        );
      },
      build: (context) {
        final groups = _groupByType(_reportData);
        final widgets = <pw.Widget>[];
        for (var i = 0; i < groups.length; i++) {
          final group = groups[i];
          if (i > 0 && _pageBreakPerType) widgets.add(pw.NewPage());
          widgets.add(pw.Padding(
            padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 6, bottom: 4),
            child: pw.Text(
                isEnglish
                    ? 'Account Type: ${accountTypeLabel(group.first.accountType, true)} (${group.first.accountType})'
                    : 'หมวดบัญชี: ${accountTypeOptions[group.first.accountType] ?? group.first.accountType} (${group.first.accountType})',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ));
          widgets.addAll(group.map((a) => _buildAccountRow(a, isEnglish)));
        }
        return widgets;
      },
    ));

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canExport = perm?.canExport ?? true;
    final canPrint = perm?.canPrint ?? true;
    _reportTitle = isEnglish && perm != null && perm.menuNameEn.isNotEmpty
        ? perm.menuNameEn
        : (perm?.menuName ?? (isEnglish ? 'Chart of Accounts' : 'รายงานผังบัญชี (Chart of Accounts)'));
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: (_reportData.isEmpty || !canExport) ? null : _exportExcel,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh accounts' : 'รีเฟรชผังบัญชี',
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
                color: Colors.indigo[900],
                child: IconButton(
                  icon: Icon(
                    _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                  tooltip: _isFilterExpanded
                      ? (isEnglish ? 'Collapse filters' : 'ย่อเงื่อนไข')
                      : (isEnglish ? 'Expand filters' : 'ขยายเงื่อนไข'),
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
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEnglish ? 'Report Filters' : 'เงื่อนไขรายงาน',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            _buildMultiSelectField(
                                isEnglish ? 'Account Type' : 'หมวดบัญชี',
                                _accountTypeOptionsList(isEnglish),
                                _selectedAccountTypes, (v) => _selectedAccountTypes = v),
                            const SizedBox(height: 16),
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Account Code (From)' : 'รหัสบัญชี (จาก)',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _accountFrom != null
                                        ? Text(
                                            '${_accountFrom!.accountCode} — ${_accountFrom!.accountNameThai}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : Text(isEnglish ? '— All —' : '— ทั้งหมด —',
                                            style: const TextStyle(color: Colors.grey)),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.search, color: Colors.indigo[900]),
                                    tooltip: isEnglish ? 'Search start account' : 'ค้นหาบัญชีเริ่มต้น',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showAccountSearchDialog(true),
                                  ),
                                  if (_accountFrom != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                                      tooltip: isEnglish ? 'Clear' : 'ล้าง',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _accountFrom = null),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Account Code (To)' : 'รหัสบัญชี (ถึง)',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _accountTo != null
                                        ? Text(
                                            '${_accountTo!.accountCode} — ${_accountTo!.accountNameThai}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : Text(isEnglish ? '— All —' : '— ทั้งหมด —',
                                            style: const TextStyle(color: Colors.grey)),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.search, color: Colors.indigo[900]),
                                    tooltip: isEnglish ? 'Search end account' : 'ค้นหาบัญชีสิ้นสุด',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showAccountSearchDialog(false),
                                  ),
                                  if (_accountTo != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                                      tooltip: isEnglish ? 'Clear' : 'ล้าง',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _accountTo = null),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Status' : 'สถานะ',
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(value: '', child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                                DropdownMenuItem(value: 'active', child: Text(isEnglish ? 'Active' : 'ใช้งาน')),
                                DropdownMenuItem(value: 'inactive', child: Text(isEnglish ? 'Inactive' : 'หยุดใช้งาน')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? ''),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title: Text(isEnglish ? 'Show Header Accounts' : 'แสดงหัวบัญชี'),
                              subtitle: Text(isEnglish
                                  ? 'Include header/group accounts (non-normal accounts)'
                                  : 'รวมบัญชีที่เป็นหัวบัญชี/บัญชีรวม (ไม่ใช่บัญชีปกติ)'),
                              value: _showHeaderAccounts,
                              onChanged: (v) => setState(() => _showHeaderAccounts = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                            SwitchListTile(
                              title: Text(isEnglish ? 'Page Break per Account Type' : 'ขึ้นหน้าใหม่ทุกหมวดบัญชี'),
                              subtitle: Text(isEnglish
                                  ? 'Print each account type on a separate page'
                                  : 'แยกพิมพ์ตามหมวดบัญชีคนละหน้า'),
                              value: _pageBreakPerType,
                              onChanged: (v) => setState(() => _pageBreakPerType = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const Spacer(),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: Text(isEnglish ? 'Generate Report' : 'ประมวลผลรายงาน'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo[900],
                                      foregroundColor: Colors.white),
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
              if (_isFilterExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _filterPanelWidth =
                            (_filterPanelWidth + details.delta.dx).clamp(200.0, maxFilterWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: _reportData.isEmpty
                      ? Center(child: Text(isEnglish ? 'Please select filters and click Generate Report' : 'กรุณาเลือกเงื่อนไขและกดประมวลผล'))
                      : PdfPreview(
                          build: (format) => _generatePdf(format),
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
        },
      ),
    );
  }
}
