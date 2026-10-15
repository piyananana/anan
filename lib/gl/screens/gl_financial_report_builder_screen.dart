import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../models/gl_account.dart';
import '../models/gl_dimension.dart';
import '../services/gl_account_service.dart';
import '../services/gl_financial_report_builder_service.dart';
import '../services/gl_dimension_service.dart';
import '../services/gl_financial_report_service.dart';
import '../services/gl_period_service.dart';
import '../models/gl_period.dart';
import '../widgets/gl_fin_report_table_view.dart';
import '../../utils/file_download.dart';
import '../widgets/gl_dimension_picker_field.dart';

class FinancialReportBuilderScreen extends StatefulWidget {
  const FinancialReportBuilderScreen({super.key});

  @override
  State<FinancialReportBuilderScreen> createState() => _FinancialReportBuilderScreenState();
}

class _FinancialReportBuilderScreenState extends State<FinancialReportBuilderScreen> {
  final FinancialReportBuilderService _service = FinancialReportBuilderService();
  final AccountService _accountService = AccountService();
  final GlDimensionService _dimService = GlDimensionService();
  final FinancialReportService _reportService = FinancialReportService();
  final PeriodService _periodService = PeriodService();

  List<Account> _accounts = [];
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _reportCols = []; // คอลัมน์ระดับรายงาน (gl_fin_report_col)
  List<Branch> _branches = [];
  Map<String, dynamic>? _selectedReport;
  bool _isLoadingReports = false;
  bool _isLoadingRows = false;

  // ตัวอย่างงบ (เรียก engine จริงด้วยงวดที่เลือก) — รีเฟรชทุกครั้งที่บันทึกบรรทัด/คอลัมน์
  bool _showPreview = false;
  List<FiscalYear> _previewYears = [];
  List<PostingPeriod> _previewPeriods = [];
  FiscalYear? _previewYear;
  PostingPeriod? _previewPeriod;
  Map<String, dynamic>? _previewData;
  String? _previewError;
  bool _previewLoading = false;
  int _previewSeq = 0; // กันผลของการเรียกเก่าทับผลใหม่

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 400.0;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;
  bool _canCreate = true;
  bool _canEdit = true;
  bool _canDelete = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoadingReports = true);
    try {
      final results = await Future.wait([
        _service.fetchReports(),
        _accountService.fetchRows(),
        _dimService.fetchActiveTypes(),
        // backend ไม่มี /cd_branch/active — โหลดทั้งหมดแล้วกรอง active ตอนแสดง dropdown
        // โหลดสาขาล้มเหลวไม่ควรทำให้ทั้งหน้าจอใช้งานไม่ได้
        BranchService().fetchRows().catchError((_) => <Branch>[]),
      ]);
      final accounts = (results[1] as List<Account>)
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
      final types = results[2] as List<GlDimensionType>;
      // โหลด dimension values ทุก type
      final valResults = await Future.wait(
        types.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      setState(() {
        _reports   = results[0] as List<Map<String, dynamic>>;
        _accounts  = accounts;
        _dimTypes  = types;
        _branches  = (results[3] as List<Branch>)
          ..sort((a, b) => a.branchCode.compareTo(b.branchCode));
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
      });
    } catch (e) {
      _showError(isEnglish ? 'Failed to load reports: $e' : 'โหลดรายการล้มเหลว: $e');
    } finally {
      setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadRows(int reportId) async {
    final isEnglish = _isEnglish;
    setState(() => _isLoadingRows = true);
    try {
      final results = await Future.wait([
        _service.fetchRows(reportId),
        _service.fetchReportCols(reportId),
      ]);
      setState(() {
        _rows = results[0];
        _reportCols = results[1];
      });
    } catch (e) {
      _showError(isEnglish ? 'Failed to load rows: $e' : 'โหลดบรรทัดล้มเหลว: $e');
    } finally {
      setState(() => _isLoadingRows = false);
    }
    if (_showPreview) _refreshPreview();
  }

  // ===== PREVIEW =====
  Future<void> _togglePreview() async {
    setState(() => _showPreview = !_showPreview);
    if (!_showPreview) return;
    if (_previewYears.isEmpty) {
      try {
        final years = (await _periodService.fetchFiscalYears())
          ..sort((a, b) => b.yearStartDate.compareTo(a.yearStartDate));
        // ปีปัจจุบันถ้ามี ไม่งั้นปีล่าสุด
        final now = DateTime.now();
        final current = years.where((y) => !now.isBefore(y.yearStartDate) && !now.isAfter(y.yearEndDate)).firstOrNull;
        setState(() => _previewYears = years);
        final year = current ?? years.firstOrNull;
        if (year != null) await _selectPreviewYear(year, refresh: false);
      } catch (e) {
        setState(() => _previewError = '$e');
      }
    }
    _refreshPreview();
  }

  Future<void> _selectPreviewYear(FiscalYear year, {bool refresh = true}) async {
    final periods = (await _periodService.fetchPostingPeriodsByFiscalYearId(year.id))
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    final now = DateTime.now();
    setState(() {
      _previewYear = year;
      _previewPeriods = periods;
      // งวดของวันนี้ถ้าอยู่ในปีนี้ ไม่งั้นงวดสุดท้าย
      _previewPeriod = periods.where((p) => !now.isBefore(p.periodStartDate) && !now.isAfter(p.periodEndDate)).firstOrNull
          ?? periods.lastOrNull;
    });
    if (refresh) _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    if (_selectedReport == null || _previewPeriod == null) return;
    final seq = ++_previewSeq;
    setState(() => _previewLoading = true);
    try {
      final data = await _reportService.generateReport(
        _selectedReport!['id'], _previewPeriod!.id, isEnglish: _isEnglish, preview: true);
      if (!mounted || seq != _previewSeq) return;
      setState(() { _previewData = data; _previewError = null; });
    } catch (e) {
      if (!mounted || seq != _previewSeq) return;
      setState(() { _previewData = null; _previewError = '$e'; });
    } finally {
      if (mounted && seq == _previewSeq) setState(() => _previewLoading = false);
    }
  }

  /// ตัวแปรในข้อความ — แทนเท่าที่หน้าออกแบบรู้ ที่เหลือแสดงชื่อตัวแปรไว้ให้เห็นว่าจะถูกแทนตอนพิมพ์
  String _previewText(String text) => text
      .replaceAll(r'$reportName', _previewData?['report_name']?.toString() ?? '')
      .replaceAll(r'$periodName', _previewPeriod?.periodName ?? '')
      .replaceAll(r'$fiscalYear', _previewYear?.fyCode ?? '');

  Widget _buildPreviewPanel() {
    final isEnglish = _isEnglish;
    final errors = (_previewData?['formula_errors'] as List?) ?? const [];
    return Container(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade400))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.blueGrey.shade50,
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(children: [
              Text(isEnglish ? 'Preview' : 'ตัวอย่างงบ', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  value: _previewYear?.id,
                  hint: Text(isEnglish ? 'Year' : 'ปี'),
                  items: _previewYears.map((y) => DropdownMenuItem(value: y.id, child: Text(y.fyCode, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (id) => _selectPreviewYear(_previewYears.firstWhere((y) => y.id == id)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  value: _previewPeriod?.id,
                  hint: Text(isEnglish ? 'Period' : 'งวด'),
                  items: _previewPeriods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.periodName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (id) {
                    setState(() => _previewPeriod = _previewPeriods.firstWhere((p) => p.id == id));
                    _refreshPreview();
                  },
                ),
              ),
              IconButton(
                icon: _previewLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                tooltip: isEnglish ? 'Refresh' : 'รีเฟรช',
                onPressed: _previewLoading ? null : _refreshPreview,
              ),
            ]),
          ),
          if (errors.isNotEmpty)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                (isEnglish ? '${errors.length} formula error(s): ' : 'สูตรผิด ${errors.length} ช่อง: ') +
                    errors.take(3).map((e) => '(${e['row_code'] ?? 'R${e['row_seq_no']}'}, C${e['column_seq_no']}) ${e['code']}').join('  '),
                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
              ),
            ),
          Expanded(
            child: _previewError != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_previewError!, style: const TextStyle(color: Colors.red)),
                  )
                : _previewData == null
                    ? Center(child: Text(
                        _previewPeriod == null ? (isEnglish ? 'Select a period' : 'เลือกงวด') : '',
                        style: const TextStyle(color: Colors.grey)))
                    : FinReportTableView(
                        reportData: _previewData!,
                        resolveText: _previewText,
                        padding: const EdgeInsets.all(8),
                        fontScale: 0.9,
                      ),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green[700]),
    );
  }

  // ===== REPORT DIALOG =====
  void _showReportDialog([Map<String, dynamic>? report]) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final isEdit = report != null;
    final codeCtrl = TextEditingController(text: report?['report_code'] ?? '');
    final nameCtrl = TextEditingController(text: report?['report_name_thai'] ?? '');
    final nameEnCtrl = TextEditingController(text: report?['report_name_eng'] ?? '');
    bool isActive = report?['is_active'] ?? true;
    bool parenthesis = report?['parenthesis_for_minus'] ?? true;
    String orientation = report?['page_orientation'] ?? 'PORTRAIT';
    final marginTopCtrl = TextEditingController(text: (report?['margin_top'] ?? 30).toString());
    final marginRightCtrl = TextEditingController(text: (report?['margin_right'] ?? 30).toString());
    final marginBottomCtrl = TextEditingController(text: (report?['margin_bottom'] ?? 30).toString());
    final marginLeftCtrl = TextEditingController(text: (report?['margin_left'] ?? 30).toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit
              ? (isEnglish ? 'Edit Financial Report' : 'แก้ไขงบการเงิน')
              : (isEnglish ? 'Add New Financial Report' : 'เพิ่มงบการเงินใหม่')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(labelText: isEnglish ? 'Code (report_code)' : 'รหัส (report_code)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: isEnglish ? 'Report Name (Thai)' : 'ชื่องบการเงิน (ภาษาไทย)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: InputDecoration(labelText: isEnglish ? 'Report Name (English)' : 'ชื่องบการเงิน (ภาษาอังกฤษ)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: orientation,
                    decoration: InputDecoration(labelText: isEnglish ? 'Page Orientation' : 'การวางแนวหน้ากระดาษ', border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'PORTRAIT', child: Text(isEnglish ? 'PORTRAIT' : 'PORTRAIT (แนวตั้ง)')),
                      DropdownMenuItem(value: 'LANDSCAPE', child: Text(isEnglish ? 'LANDSCAPE' : 'LANDSCAPE (แนวนอน)')),
                    ],
                    onChanged: (v) => setDialogState(() => orientation = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: marginTopCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Margin Top', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: marginRightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Right', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: marginBottomCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Margin Bottom', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: marginLeftCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Left', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    title: Text(isEnglish ? 'Active (is_active)' : 'ใช้งาน (is_active)'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    dense: true,
                  ),
                  SwitchListTile(
                    title: Text(isEnglish ? 'Show negative values in parentheses' : 'แสดงค่าติดลบในวงเล็บ'),
                    value: parenthesis,
                    onChanged: (v) => setDialogState(() => parenthesis = v),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
              onPressed: () async {
                final data = {
                  'report_code': codeCtrl.text.trim(),
                  'report_name_thai': nameCtrl.text.trim(),
                  'report_name_eng': nameEnCtrl.text.trim(),
                  'is_active': isActive,
                  'parenthesis_for_minus': parenthesis,
                  'page_orientation': orientation,
                  'margin_top': int.tryParse(marginTopCtrl.text) ?? 30,
                  'margin_right': int.tryParse(marginRightCtrl.text) ?? 30,
                  'margin_bottom': int.tryParse(marginBottomCtrl.text) ?? 30,
                  'margin_left': int.tryParse(marginLeftCtrl.text) ?? 30,
                };
                try {
                  if (isEdit) {
                    final updated = await _service.updateReport(report!['id'], data);
                    if (_selectedReport?['id'] == report['id']) {
                      setState(() => _selectedReport = updated);
                    }
                  } else {
                    await _service.createReport(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadReports();
                  _showSuccess(isEdit
                      ? (isEnglish ? 'Updated successfully' : 'แก้ไขเรียบร้อย')
                      : (isEnglish ? 'Added successfully' : 'เพิ่มเรียบร้อย'));
                } catch (e) {
                  _showError(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e');
                }
              },
              child: Text(isEdit ? l.save : l.add),
            ),
          ],
        ),
      ),
    );
  }

  // ===== EXPORT / IMPORT / TEMPLATES =====
  Future<void> _exportReport(Map<String, dynamic> report) async {
    final isEnglish = _isEnglish;
    try {
      final data = await _service.exportReport(report['id']);
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final savedPath = await downloadFile(bytes, '${report['report_code']}.json');
      _showSuccess(isEnglish
          ? 'Exported ${report['report_code']}.json${savedPath != null ? ' to $savedPath' : ''}'
          : 'ส่งออก ${report['report_code']}.json แล้ว${savedPath != null ? ' ที่ $savedPath' : ''}');
    } catch (e) {
      _showError(isEnglish ? 'Export failed: $e' : 'ส่งออกไม่สำเร็จ: $e');
    }
  }

  Future<void> _importFromFile() async {
    final isEnglish = _isEnglish;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = picked?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)));
    } catch (_) {
      _showError(isEnglish ? 'The file is not valid JSON' : 'ไฟล์ไม่ใช่ JSON ที่ถูกต้อง');
      return;
    }
    if (data['format'] != 'anan.gl_fin_report') {
      _showError(isEnglish ? 'This is not an ANAN financial report file' : 'ไฟล์นี้ไม่ใช่แบบงบการเงินของ ANAN');
      return;
    }
    final rep = Map<String, dynamic>.from(data['report'] ?? const {});
    _showImportDialog(
      title: isEnglish ? 'Import Report from File' : 'นำเข้าแบบงบจากไฟล์',
      data: data,
      code: rep['report_code'] ?? '',
      nameThai: rep['report_name_thai'] ?? '',
      nameEng: rep['report_name_eng'] ?? '',
    );
  }

  Future<void> _showTemplatePicker() async {
    final isEnglish = _isEnglish;
    final l = AppL10n(isEnglish);
    List<Map<String, dynamic>> templates;
    try {
      templates = await _service.fetchTemplates();
    } catch (e) {
      _showError(isEnglish ? 'Failed to load templates: $e' : 'โหลดแม่แบบไม่สำเร็จ: $e');
      return;
    }
    if (!mounted) return;
    String tr(Map t, String key) {
      final String en = t['${key}_eng'] ?? '';
      return isEnglish && en.isNotEmpty ? en : (t['${key}_thai'] ?? en);
    }

    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Create from Template' : 'สร้างงบจากแม่แบบ'),
        content: SizedBox(
          width: 520,
          child: templates.isEmpty
              ? Text(isEnglish ? 'No templates available' : 'ไม่มีแม่แบบ')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = templates[i];
                    return ListTile(
                      leading: Icon(Icons.article_outlined, color: Colors.deepOrange[900]),
                      title: Text(tr(t, 'name'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${tr(t, 'description')}\n'
                          '${isEnglish ? 'Rows' : 'จำนวนบรรทัด'}: ${t['row_count']}'),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel))],
      ),
    );
    if (chosen == null) return;
    _showImportDialog(
      title: '${isEnglish ? 'Create from Template' : 'สร้างงบจากแม่แบบ'}: ${tr(chosen, 'name')}',
      templateId: chosen['id'],
      code: chosen['report_code'] ?? '',
      nameThai: (chosen['name_thai'] ?? '').toString().replaceAll(RegExp(r'\s*\(.*\)$'), ''),
      nameEng: (chosen['name_eng'] ?? '').toString().replaceAll(RegExp(r'\s*\(.*\)$'), ''),
    );
  }

  /// ตั้งรหัส/ชื่องบใหม่ก่อนสร้าง (รหัสงบต้องไม่ซ้ำ)
  void _showImportDialog({
    required String title,
    Map<String, dynamic>? data,
    String? templateId,
    required String code,
    required String nameThai,
    required String nameEng,
  }) {
    final isEnglish = _isEnglish;
    final l = AppL10n(isEnglish);
    final codeCtrl = TextEditingController(text: code);
    final nameThCtrl = TextEditingController(text: nameThai);
    final nameEnCtrl = TextEditingController(text: nameEng);
    bool busy = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: codeCtrl, decoration: InputDecoration(labelText: isEnglish ? 'New report code' : 'รหัสงบใหม่', border: const OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: nameThCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Report Name (Thai)' : 'ชื่องบการเงิน (ภาษาไทย)', border: const OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: nameEnCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Report Name (English)' : 'ชื่องบการเงิน (ภาษาอังกฤษ)', border: const OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
              onPressed: busy
                  ? null
                  : () async {
                      if (codeCtrl.text.trim().isEmpty) {
                        _showError(isEnglish ? 'Please enter a report code' : 'กรุณาระบุรหัสงบ');
                        return;
                      }
                      setDlgState(() => busy = true);
                      try {
                        final result = await _service.importReport(
                          data: data,
                          templateId: templateId,
                          reportCode: codeCtrl.text.trim(),
                          reportNameThai: nameThCtrl.text.trim(),
                          reportNameEng: nameEnCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _afterImport(result);
                      } on FinReportValidationException catch (e) {
                        setDlgState(() => busy = false);
                        _showError(switch (e.code) {
                          'DUPLICATE_CODE' => isEnglish ? 'This report code already exists' : 'รหัสงบนี้มีอยู่แล้ว',
                          'INVALID_FILE' => isEnglish ? 'The file content is invalid: ${e.message}' : 'ข้อมูลในไฟล์ไม่ถูกต้อง: ${e.message}',
                          _ => e.localized(isEnglish),
                        });
                      } catch (e) {
                        setDlgState(() => busy = false);
                        _showError(isEnglish ? 'Import failed: $e' : 'นำเข้าไม่สำเร็จ: $e');
                      }
                    },
              child: Text(isEnglish ? 'Create' : 'สร้างงบ'),
            ),
          ],
        ),
      ),
    );
  }

  /// เปิดงบที่สร้างใหม่ แล้วแจ้งสิ่งที่ต้องทำต่อ (บรรทัดที่ยังไม่เลือกบัญชี, รหัสที่ไม่มีในฐานนี้)
  Future<void> _afterImport(Map<String, dynamic> result) async {
    final isEnglish = _isEnglish;
    final report = Map<String, dynamic>.from(result['report']);
    await _loadReports();
    setState(() {
      _selectedReport = report;
      _rows = [];
    });
    await _loadRows(report['id']);
    final warnings = (result['warnings'] as List?) ?? const [];
    final emptyRows = (result['empty_account_rows'] as List?) ?? const [];
    if (warnings.isEmpty && emptyRows.isEmpty) {
      _showSuccess(isEnglish ? 'Report ${report['report_code']} created' : 'สร้างงบ ${report['report_code']} แล้ว');
      return;
    }
    if (!mounted) return;
    String warningText(Map w) {
      final what = switch (w['code']) {
        'BRANCH_NOT_FOUND' => isEnglish ? 'branch' : 'สาขา',
        'DIM_NOT_FOUND' => isEnglish ? 'dimension' : 'มิติ',
        _ => isEnglish ? 'header account' : 'หัวบัญชี',
      };
      return '${w['where']}: ${isEnglish ? 'no $what' : 'ไม่มี$what'} ${w['value']} ${isEnglish ? 'in this database (left empty)' : 'ในฐานข้อมูลนี้ (เว้นว่างไว้)'}';
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Report ${report['report_code']} created — next steps' : 'สร้างงบ ${report['report_code']} แล้ว — สิ่งที่ต้องทำต่อ'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (emptyRows.isNotEmpty) ...[
                Text(isEnglish
                    ? '${emptyRows.length} rows have no accounts yet — edit each row, or use "Check Chart Mapping" to see which accounts are not in the report:'
                    : 'มี ${emptyRows.length} บรรทัดที่ยังไม่ได้เลือกบัญชี — แก้ไขทีละบรรทัด หรือกด "ตรวจผังบัญชี" เพื่อดูว่าบัญชีใดยังไม่อยู่ในงบ:'),
                const SizedBox(height: 4),
                Text(emptyRows.join(', '), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const SizedBox(height: 12),
              ],
              ...warnings.map((w) => Text('• ${warningText(w as Map)}', style: TextStyle(fontSize: 13, color: Colors.orange[900]))),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppL10n(isEnglish).close))],
      ),
    );
  }

  // ===== ROW DIALOG =====
  /// [headersOnly] = เลือกหัวบัญชี (ใช้เฉพาะเงื่อนไข "ทั้งกลุ่มใต้หัวบัญชี") — ปกติแสดงเฉพาะบัญชีลงรายการได้
  Future<Account?> _pickAccountInDialog(BuildContext ctx, Account? current, {bool headersOnly = false}) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final searchCtrl = TextEditingController();
    final postable = _accounts.where((a) => a.isActive && a.isNormalAccount != headersOnly).toList();
    List<Account> filtered = List.from(postable);
    Account? picked;

    await showDialog(
      context: ctx,
      builder: (ctx2) => StatefulBuilder(builder: (ctx2, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(postable);
            } else {
              final lq = q.toLowerCase();
              filtered = postable
                  .where((a) =>
                      a.accountCode.toLowerCase().contains(lq) ||
                      a.accountNameThai.toLowerCase().contains(lq) ||
                      a.accountNameEng.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text(headersOnly
              ? (isEnglish ? 'Select Header Account' : 'เลือกหัวบัญชี')
              : (isEnglish ? 'Select Account Code' : 'เลือกรหัสบัญชี')),
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
                                  Expanded(child: Text(isEnglish && a.accountNameEng.isNotEmpty
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
                                picked = a;
                                Navigator.of(ctx2).pop();
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
              onPressed: () => Navigator.of(ctx2).pop(),
              child: Text(l.close),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  // ===== ROW HELPERS (row_kind / ชื่อบรรทัด / เส้น) =====
  String _rowKindLabel(String kind, bool isEnglish) {
    switch (kind) {
      case 'HEADING':
        return isEnglish ? 'HEADING (label only)' : 'HEADING (หัวข้อ ไม่มียอด)';
      case 'TOTAL':
        return isEnglish ? 'TOTAL (sum of rows added into it)' : 'TOTAL (รวมบรรทัดที่เลือกรวมเข้ามา)';
      case 'FORMULA':
        return isEnglish ? 'FORMULA (calculated from other rows)' : 'FORMULA (คำนวณจากบรรทัดอื่น)';
      case 'BLANK':
        return isEnglish ? 'BLANK (empty line)' : 'BLANK (บรรทัดว่าง)';
      default:
        return isEnglish ? 'ACCOUNTS (balance of an account range)' : 'ACCOUNTS (ยอดจากช่วงบัญชี)';
    }
  }

  Color _rowKindColor(String kind) {
    switch (kind) {
      case 'TOTAL':
        return Colors.indigo;
      case 'FORMULA':
        return Colors.purple;
      case 'HEADING':
        return Colors.brown;
      case 'BLANK':
        return Colors.grey;
      default:
        return Colors.green[800]!;
    }
  }

  String _rowLabelOf(Map<String, dynamic> r, bool isEnglish) {
    final String th = r['label_thai'] ?? '';
    final String en = r['label_eng'] ?? '';
    return isEnglish && en.isNotEmpty ? en : (th.isNotEmpty ? th : en);
  }

  Widget _lineStyleDropdown(String label, String value, bool isEnglish, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        DropdownMenuItem(value: 'NONE', child: Text(isEnglish ? 'None' : 'ไม่มี')),
        DropdownMenuItem(value: 'SINGLE', child: Text(isEnglish ? 'Single line' : 'เส้นเดี่ยว')),
        DropdownMenuItem(value: 'DOUBLE', child: Text(isEnglish ? 'Double line' : 'เส้นคู่')),
      ],
      onChanged: (v) => onChanged(v!),
    );
  }

  // ===== ACCOUNT SELECTIONS (gl_fin_report_row_acct) =====
  static const _acctSelTypes = ['RANGE', 'UNDER_HEADER', 'ACCOUNT_TYPE'];

  String _acctSelTypeLabel(String type, bool isEnglish) {
    switch (type) {
      case 'UNDER_HEADER':
        return isEnglish ? 'Accounts under header' : 'ทั้งกลุ่มใต้หัวบัญชี';
      case 'ACCOUNT_TYPE':
        return isEnglish ? 'Account type' : 'ประเภทบัญชี';
      default:
        return isEnglish ? 'Account range' : 'ช่วงบัญชี';
    }
  }

  String _accountDisplay(String? code, bool isEnglish) {
    if (code == null || code.isEmpty) return '';
    final a = _accounts.where((x) => x.accountCode == code).firstOrNull;
    if (a == null) return code;
    return '$code — ${isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai}';
  }

  /// สรุปเงื่อนไขสั้นๆ เช่น "4100..4199", "ใต้ 41", "ยกเว้น 4102..4102"
  String _acctSelSummary(Map<String, dynamic> s, bool isEnglish) {
    final prefix = s['is_exclude'] == true ? (isEnglish ? 'except ' : 'ยกเว้น ') : '';
    switch (s['sel_type']) {
      case 'UNDER_HEADER':
        return '$prefix${isEnglish ? 'under' : 'ใต้'} ${s['header_account_code']}';
      case 'ACCOUNT_TYPE':
        return '$prefix${accountTypeLabel(s['account_type'] ?? '', isEnglish)}';
      default:
        return '$prefix${s['account_from']}..${s['account_to']}';
    }
  }

  /// เงื่อนไขของบรรทัด — บรรทัดเก่าที่ยังไม่มีในตารางใหม่ ใช้ช่วงเดิม account_from/account_to
  List<Map<String, dynamic>> _rowAcctSels(Map<String, dynamic>? row) {
    final list = [for (final a in (row?['accounts'] as List? ?? const [])) Map<String, dynamic>.from(a)];
    final String from = row?['account_from'] ?? '';
    final String to = row?['account_to'] ?? '';
    if (list.isEmpty && from.isNotEmpty && to.isNotEmpty) {
      list.add({'sel_type': 'RANGE', 'is_exclude': false, 'account_from': from, 'account_to': to});
    }
    return list;
  }

  /// บัญชีลงรายการที่ตรงเงื่อนไข (ตรรกะเดียวกับ backend utils/finReportAccounts.js)
  Set<String> _resolveAcctCodes(List<Map<String, dynamic>> sels) {
    final childrenOf = <int, List<Account>>{};
    for (final a in _accounts) {
      if (a.parentId != null) childrenOf.putIfAbsent(a.parentId!, () => []).add(a);
    }
    Set<String> match(Map<String, dynamic> s) {
      switch (s['sel_type']) {
        case 'UNDER_HEADER':
          final root = _accounts.where((a) => a.accountCode == s['header_account_code']).firstOrNull;
          final out = <String>{};
          final stack = [if (root != null) root];
          final seen = <int>{};
          while (stack.isNotEmpty) {
            final a = stack.removeLast();
            if (!seen.add(a.id)) continue;
            out.add(a.accountCode);
            stack.addAll(childrenOf[a.id] ?? const []);
          }
          return out;
        case 'ACCOUNT_TYPE':
          return _accounts.where((a) => a.accountType == s['account_type']).map((a) => a.accountCode).toSet();
        default:
          final String from = s['account_from'] ?? '';
          final String to = s['account_to'] ?? '';
          if (from.isEmpty || to.isEmpty) return {};
          // account_to รวมบัญชีลูกที่ขึ้นต้นด้วยรหัสนั้นด้วย
          return _accounts
              .where((a) => a.accountCode.compareTo(from) >= 0 &&
                  (a.accountCode.compareTo(to) <= 0 || a.accountCode.startsWith(to)))
              .map((a) => a.accountCode)
              .toSet();
      }
    }

    final out = <String>{
      for (final s in sels.where((s) => s['is_exclude'] != true)) ...match(s),
    };
    for (final s in sels.where((s) => s['is_exclude'] == true)) {
      out.removeAll(match(s));
    }
    final posting = _accounts.where((a) => a.isNormalAccount).map((a) => a.accountCode).toSet();
    return out.intersection(posting);
  }

  Widget _acctPickField(BuildContext ctx, {
    required String label,
    required String? code,
    required bool isEnglish,
    required ValueChanged<String?> onChanged,
    bool headersOnly = false,
  }) {
    final hasCode = code != null && code.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            hasCode ? _accountDisplay(code, isEnglish) : (isEnglish ? '— Select —' : '— เลือก —'),
            style: TextStyle(fontSize: 13, fontWeight: hasCode ? FontWeight.bold : FontWeight.normal, color: hasCode ? null : Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(Icons.search, color: Colors.deepOrange[900], size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () async {
            final current = _accounts.where((a) => a.accountCode == code).firstOrNull;
            final picked = await _pickAccountInDialog(ctx, current, headersOnly: headersOnly);
            if (picked != null) onChanged(picked.accountCode);
          },
        ),
      ]),
    );
  }

  Widget _acctSelLine(BuildContext ctx, List<Map<String, dynamic>> sels, int i, bool isEnglish, VoidCallback refresh) {
    final s = sels[i];
    final String type = s['sel_type'] ?? 'RANGE';
    final bool exclude = s['is_exclude'] == true;
    Widget body;
    if (type == 'UNDER_HEADER') {
      body = _acctPickField(ctx,
          label: isEnglish ? 'Header account (includes all accounts under it)' : 'หัวบัญชี (รวมทุกบัญชีที่อยู่ใต้หัวนี้)',
          code: s['header_account_code'],
          isEnglish: isEnglish,
          headersOnly: true,
          onChanged: (c) { s['header_account_code'] = c; refresh(); });
    } else if (type == 'ACCOUNT_TYPE') {
      body = DropdownButtonFormField<String>(
        isExpanded: true,
        isDense: true,
        value: s['account_type'],
        decoration: InputDecoration(
          labelText: _acctSelTypeLabel(type, isEnglish),
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        items: accountTypeOptions.keys
            .map((k) => DropdownMenuItem(value: k, child: Text(accountTypeLabel(k, isEnglish), style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) { s['account_type'] = v; refresh(); },
      );
    } else {
      body = Row(children: [
        Expanded(child: _acctPickField(ctx, label: isEnglish ? 'From' : 'ตั้งแต่', code: s['account_from'], isEnglish: isEnglish,
            onChanged: (c) { s['account_from'] = c; if ((s['account_to'] ?? '').isEmpty) s['account_to'] = c; refresh(); })),
        const SizedBox(width: 6),
        Expanded(child: _acctPickField(ctx, label: isEnglish ? 'To' : 'ถึง', code: s['account_to'], isEnglish: isEnglish,
            onChanged: (c) { s['account_to'] = c; refresh(); })),
      ]);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: exclude ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: exclude ? Colors.red[200]! : Colors.green[200]!),
      ),
      child: Row(children: [
        Tooltip(
          message: isEnglish ? 'Click to switch include / exclude' : 'คลิกเพื่อสลับ รวม / ยกเว้น',
          child: InkWell(
            onTap: () { s['is_exclude'] = !exclude; refresh(); },
            child: Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: exclude ? Colors.red[700] : Colors.green[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                exclude ? (isEnglish ? 'Except' : 'ยกเว้น') : (isEnglish ? 'Include' : 'รวม'),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: body),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red, size: 18),
          tooltip: isEnglish ? 'Remove condition' : 'ลบเงื่อนไข',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28),
          onPressed: () { sels.removeAt(i); refresh(); },
        ),
      ]),
    );
  }

  Widget _buildAcctSelEditor(BuildContext ctx, List<Map<String, dynamic>> sels, bool isEnglish, VoidCallback refresh) {
    final matched = _resolveAcctCodes(sels);
    final hasInclude = sels.any((s) => s['is_exclude'] != true);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: isEnglish ? 'Accounts in this row' : 'บัญชีในบรรทัดนี้',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < sels.length; i++) _acctSelLine(ctx, sels, i, isEnglish, refresh),
          Wrap(spacing: 4, children: [
            for (final t in _acctSelTypes)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(_acctSelTypeLabel(t, isEnglish), style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.deepOrange[900], visualDensity: VisualDensity.compact),
                onPressed: () {
                  sels.add({'sel_type': t, 'is_exclude': false, if (t == 'ACCOUNT_TYPE') 'account_type': 'ASSET'});
                  refresh();
                },
              ),
          ]),
          Text(
            !hasInclude
                ? (isEnglish ? 'Add at least one include condition — exclusions are subtracted from it' : 'เพิ่มเงื่อนไข "รวม" อย่างน้อย 1 เงื่อนไข — เงื่อนไข "ยกเว้น" จะหักออกจากบัญชีที่รวมไว้')
                : (isEnglish ? '${matched.length} posting accounts selected' : 'ได้บัญชีลงรายการ ${matched.length} บัญชี'),
            style: TextStyle(fontSize: 12, color: hasInclude && matched.isNotEmpty ? Colors.grey[700] : Colors.red[700]),
          ),
        ],
      ),
    );
  }

  // ===== CHECK CHART MAPPING =====
  /// บัญชีลงรายการที่ไม่อยู่ในบรรทัดใด (ยอดหายจากงบ) และที่อยู่หลายบรรทัด (ยอดนับซ้ำ)
  Future<void> _showAccountMappingDialog() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final reportId = _selectedReport!['id'] as int;
    List<Map<String, dynamic>> mapping;
    try {
      mapping = await _service.fetchAccountMapping(reportId);
    } catch (e) {
      _showError(isEnglish ? 'Check failed: $e' : 'ตรวจไม่สำเร็จ: $e');
      return;
    }
    if (!mounted) return;
    List rowsOf(Map<String, dynamic> a) => a['rows'] as List? ?? const [];
    // เริ่มจากประเภทบัญชีที่รายงานนี้ใช้อยู่ (งบฐานะการเงินไม่ต้องเห็นรายได้/ค่าใช้จ่ายที่ไม่ได้ใส่)
    final usedTypes = mapping.where((a) => rowsOf(a).isNotEmpty).map((a) => a['account_type'] as String).toSet();
    final types = usedTypes.isEmpty ? accountTypeOptions.keys.toSet() : usedTypes;

    String nameOf(Map<String, dynamic> a) {
      final String en = a['account_name_eng'] ?? '';
      return isEnglish && en.isNotEmpty ? en : (a['account_name_thai'] ?? '');
    }

    String rowRef(Map r) {
      final label = _rowLabelOf(Map<String, dynamic>.from(r), isEnglish);
      return '${r['row_code'] ?? 'R${r['row_seq_no']}'}${label.isEmpty ? '' : ' $label'}';
    }

    Widget accountTile(Map<String, dynamic> a, {bool showRows = false}) {
      final rows = rowsOf(a);
      final dimNote = rows.any((r) => r['has_dims'] == true);
      return ListTile(
        dense: true,
        title: Row(children: [
          SizedBox(width: 90, child: Text(a['account_code'], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange[900]))),
          Expanded(child: Text(nameOf(a), overflow: TextOverflow.ellipsis)),
          Text(accountTypeLabel(a['account_type'] ?? '', isEnglish), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        subtitle: showRows
            ? Text(
                '${rows.map((r) => rowRef(r)).join('  |  ')}'
                '${dimNote ? (isEnglish ? '\n(some rows filter by dimension — may be split on purpose)' : '\n(มีบรรทัดที่กรองมิติ — อาจตั้งใจแยกตามมิติ)') : ''}',
                style: TextStyle(fontSize: 12, color: dimNote ? Colors.blueGrey : Colors.red[700]),
              )
            : null,
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        final shown = mapping.where((a) => types.contains(a['account_type'])).toList();
        final unmapped = shown.where((a) => rowsOf(a).isEmpty).toList();
        final multi = shown.where((a) => rowsOf(a).length > 1).toList();
        Widget list(List<Map<String, dynamic>> items, String emptyText, {bool showRows = false}) => items.isEmpty
            ? Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(emptyText),
              ]))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => accountTile(items[i], showRows: showRows),
              );
        return AlertDialog(
          title: Text(isEnglish ? 'Check Chart Mapping' : 'ตรวจผังบัญชีกับงบ'),
          content: SizedBox(
            width: 680,
            height: 480,
            child: DefaultTabController(
              length: 2,
              child: Column(children: [
                Wrap(spacing: 6, children: [
                  for (final t in accountTypeOptions.keys)
                    FilterChip(
                      label: Text(accountTypeLabel(t, isEnglish)),
                      selected: types.contains(t),
                      onSelected: (v) => setDlgState(() => v ? types.add(t) : types.remove(t)),
                    ),
                ]),
                TabBar(
                  labelColor: Colors.deepOrange[900],
                  indicatorColor: Colors.deepOrange[900],
                  tabs: [
                    Tab(text: '${isEnglish ? 'Not in any row' : 'ไม่อยู่ในบรรทัดใด'} (${unmapped.length})'),
                    Tab(text: '${isEnglish ? 'In more than one row' : 'อยู่หลายบรรทัด'} (${multi.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(children: [
                    list(unmapped, isEnglish ? 'Every account is in the report' : 'ทุกบัญชีอยู่ในงบแล้ว'),
                    list(multi, isEnglish ? 'No account is counted twice' : 'ไม่มีบัญชีที่นับซ้ำ', showRows: true),
                  ]),
                ),
                Text(
                  isEnglish
                      ? 'Active posting accounts only. Balances of accounts not in any row are missing from the report; accounts in several rows are counted more than once.'
                      : 'ตรวจเฉพาะบัญชีลงรายการที่ใช้งาน — บัญชีที่ไม่อยู่ในบรรทัดใด ยอดจะหายจากงบ ส่วนบัญชีที่อยู่หลายบรรทัด ยอดจะถูกนับซ้ำ',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close))],
        );
      }),
    );
  }

  void _showRowDialog([Map<String, dynamic>? row]) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final isEdit = row != null;
    final int nextSeq = _rows.isEmpty
        ? 10
        : (_rows.map((r) => (r['row_seq_no'] as int?) ?? 0).reduce((a, b) => a > b ? a : b) + 10);
    final seqCtrl = TextEditingController(text: (isEdit ? row['row_seq_no'] : nextSeq)?.toString() ?? '');
    final codeCtrl = TextEditingController(text: row?['row_code'] ?? '');
    String rowKind = row?['row_kind'] ?? 'ACCOUNTS';
    final labelThCtrl = TextEditingController(text: row?['label_thai'] ?? '');
    final labelEnCtrl = TextEditingController(text: row?['label_eng'] ?? '');
    final indentCtrl = TextEditingController(text: (row?['indent_level'] ?? 0).toString());
    String? parentCode = row?['parent_row_code'];
    final rowFormulaCtrl = TextEditingController(text: row?['row_formula'] ?? '');
    bool isBold = row?['is_bold'] ?? false;
    bool hideIfZero = row?['hide_if_zero'] ?? false;
    String lineAbove = row?['line_above'] ?? 'NONE';
    String lineBelow = row?['line_below'] ?? 'NONE';
    // บรรทัด TOTAL อื่นที่บรรทัดนี้รวมเข้าได้
    final totalRows = _rows
        .where((r) => r['row_kind'] == 'TOTAL' && r['row_code'] != null && r['id'] != row?['id'])
        .toList();
    final otherRowCodes = _rows
        .where((r) => r['row_code'] != null && r['id'] != row?['id'])
        .map((r) => r['row_code'] as String)
        .join('  ');
    String rowType = row?['row_type'] ?? 'BODY';
    String printControl = row?['print_control'] ?? 'SHOW';
    // เงื่อนไขเลือกบัญชี (หลายช่วง/ยกเว้น/ใต้หัวบัญชี/ประเภทบัญชี) บันทึกพร้อมบรรทัด
    final List<Map<String, dynamic>> acctSels = _rowAcctSels(row);
    String normalSign = row?['normal_sign'] ?? 'DEBIT';
    // Branch filter (ป้อน id ตรงๆ ยังคงไว้ก่อน เพราะ branch มักไม่ได้ filter ใน report)
    final branchCtrl = TextEditingController(
        text: row?['branch_id'] != null ? row!['branch_id'].toString() : '');
    // Dimension filters — ใช้ GlDimensionPickerField
    final Map<int, GlDimensionValue?> dimPicks = {};
    for (final t in _dimTypes) {
      final storedId = row?['dim${t.slotNo}_id'] as int?;
      if (storedId != null) {
        final vals = _dimValues[t.typeCode] ?? [];
        dimPicks[t.slotNo] = vals.cast<GlDimensionValue?>()
            .firstWhere((v) => v?.id == storedId, orElse: () => null);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit
              ? (isEnglish ? 'Edit Row' : 'แก้ไขบรรทัด')
              : (isEnglish ? 'Add New Row' : 'เพิ่มบรรทัดใหม่')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: seqCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: isEnglish ? 'Row Sequence (R no.)' : 'ลำดับบรรทัด (เลข R)', border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Row Code (used in formulas)' : 'รหัสบรรทัด (ใช้ในสูตร)',
                          hintText: 'REV_TOTAL',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: rowKind,
                    decoration: InputDecoration(labelText: isEnglish ? 'Row Kind' : 'ชนิดบรรทัด', border: const OutlineInputBorder()),
                    items: ['ACCOUNTS', 'HEADING', 'TOTAL', 'FORMULA', 'BLANK']
                        .map((k) => DropdownMenuItem(value: k, child: Text(_rowKindLabel(k, isEnglish))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => rowKind = v!),
                  ),
                  const SizedBox(height: 10),
                  if (rowKind != 'BLANK') ...[
                    TextField(controller: labelThCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Row Label (Thai)' : 'ชื่อบรรทัด (ไทย)', border: const OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: labelEnCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Row Label (English)' : 'ชื่อบรรทัด (อังกฤษ)', border: const OutlineInputBorder())),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: indentCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: isEnglish ? 'Indent' : 'ย่อหน้า', border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: totalRows.any((r) => r['row_code'] == parentCode) ? parentCode : null,
                        decoration: InputDecoration(labelText: isEnglish ? 'Add into total row' : 'รวมเข้าบรรทัดยอดรวม', border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text(isEnglish ? '— None —' : '— ไม่รวม —')),
                          ...totalRows.map((r) => DropdownMenuItem<String?>(
                                value: r['row_code'],
                                child: Text('${r['row_code']}  ${_rowLabelOf(r, isEnglish)}', overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setDialogState(() => parentCode = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  if (rowKind == 'FORMULA') ...[
                    TextField(
                      controller: rowFormulaCtrl,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Row formula (every amount column)' : 'สูตรของบรรทัด (คำนวณทุกคอลัมน์ตัวเลข)',
                        hintText: 'REV_TOTAL - COGS_TOTAL',
                        helperText: otherRowCodes.isEmpty
                            ? (isEnglish ? 'Give other rows a row code first' : 'ตั้งรหัสให้บรรทัดอื่นก่อน')
                            : '${isEnglish ? 'Rows' : 'บรรทัด'}: $otherRowCodes   '
                              '${isEnglish ? 'specific column' : 'ระบุคอลัมน์'}: REV_TOTAL[CUR]   ABS ROUND MIN MAX',
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: rowType,
                    decoration: InputDecoration(labelText: isEnglish ? 'Row Type (row_type)' : 'ประเภทบรรทัด (row_type)', border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'HEADER', child: Text(isEnglish ? 'HEADER' : 'HEADER (ส่วนหัว)')),
                      DropdownMenuItem(value: 'BODY', child: Text(isEnglish ? 'BODY' : 'BODY (เนื้อหา)')),
                      DropdownMenuItem(value: 'FOOTER', child: Text(isEnglish ? 'FOOTER' : 'FOOTER (ส่วนท้าย)')),
                    ],
                    onChanged: (v) => setDialogState(() => rowType = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: printControl,
                    decoration: InputDecoration(labelText: isEnglish ? 'Print Control (print_control)' : 'การแสดงผล (print_control)', border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'SHOW', child: Text(isEnglish ? 'SHOW' : 'SHOW (แสดง)')),
                      DropdownMenuItem(value: 'HIDE', child: Text(isEnglish ? 'HIDE' : 'HIDE (ซ่อน)')),
                    ],
                    onChanged: (v) => setDialogState(() => printControl = v!),
                  ),
                  if (rowKind == 'ACCOUNTS') ...[
                  const SizedBox(height: 10),
                  _buildAcctSelEditor(ctx, acctSels, isEnglish, () => setDialogState(() {})),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: normalSign,
                    decoration: InputDecoration(labelText: isEnglish ? 'Normal Sign (normal_sign)' : 'เครื่องหมายปกติ (normal_sign)', border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'DEBIT', child: Text(isEnglish ? 'DEBIT' : 'DEBIT (เดบิต)')),
                      DropdownMenuItem(value: 'CREDIT', child: Text(isEnglish ? 'CREDIT' : 'CREDIT (เครดิต)')),
                    ],
                    onChanged: (v) => setDialogState(() => normalSign = v!),
                  ),
                  if (_dimTypes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(isEnglish ? 'Filter Dimension (select as needed)' : 'กรอง Dimension (เลือกเฉพาะที่ต้องการ)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    const SizedBox(height: 6),
                    ..._dimTypes.map((t) {
                      final vals = _dimValues[t.typeCode] ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: StatefulBuilder(
                          builder: (ctx2, setPickState) => GlDimensionPickerField(
                            dimType:  t,
                            values:   vals,
                            selected: dimPicks[t.slotNo],
                            isDense:  false,
                            onSelected: (val) {
                              setPickState(() => dimPicks[t.slotNo] = val);
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                  ],
                  if (rowKind != 'BLANK') ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _lineStyleDropdown(isEnglish ? 'Line above amounts' : 'เส้นเหนือยอดเงิน', lineAbove, isEnglish, (v) => setDialogState(() => lineAbove = v))),
                      const SizedBox(width: 8),
                      Expanded(child: _lineStyleDropdown(isEnglish ? 'Line below amounts' : 'เส้นใต้ยอดเงิน', lineBelow, isEnglish, (v) => setDialogState(() => lineBelow = v))),
                    ]),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(isEnglish ? 'Bold row' : 'ตัวหนาทั้งบรรทัด'),
                      value: isBold,
                      onChanged: (v) => setDialogState(() => isBold = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(isEnglish ? 'Hide row when all amounts are zero' : 'ไม่พิมพ์บรรทัดถ้ายอดทุกคอลัมน์เป็นศูนย์'),
                      value: hideIfZero,
                      onChanged: (v) => setDialogState(() => hideIfZero = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
              onPressed: () async {
                final data = {
                  if (!isEdit) 'report_id': _selectedReport!['id'],
                  'row_seq_no': int.tryParse(seqCtrl.text) ?? 0,
                  'row_code': codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim().toUpperCase(),
                  'row_kind': rowKind,
                  'label_thai': labelThCtrl.text.trim().isEmpty ? null : labelThCtrl.text.trim(),
                  'label_eng': labelEnCtrl.text.trim().isEmpty ? null : labelEnCtrl.text.trim(),
                  'indent_level': int.tryParse(indentCtrl.text.trim()) ?? 0,
                  'parent_row_code': parentCode,
                  'row_formula': rowKind == 'FORMULA' ? rowFormulaCtrl.text.trim() : null,
                  'is_bold': isBold,
                  'hide_if_zero': hideIfZero,
                  'line_above': lineAbove,
                  'line_below': lineBelow,
                  'row_type': rowType,
                  'print_control': printControl,
                  // เงื่อนไขบัญชี/Dimension ใช้เฉพาะบรรทัด ACCOUNTS (backend ล้างช่วงเดิม account_from/to ให้)
                  'accounts': rowKind == 'ACCOUNTS' ? acctSels : const [],
                  'normal_sign': normalSign,
                  'branch_id': int.tryParse(branchCtrl.text.trim()),
                  for (final t in _dimTypes)
                    'dim${t.slotNo}_id': rowKind == 'ACCOUNTS' ? dimPicks[t.slotNo]?.id : null,
                };
                try {
                  if (isEdit) {
                    await _service.updateRow(row!['id'], data);
                  } else {
                    await _service.createRow(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadRows(_selectedReport!['id']);
                  _showSuccess(isEdit
                      ? (isEnglish ? 'Row updated successfully' : 'แก้ไขบรรทัดเรียบร้อย')
                      : (isEnglish ? 'Row added successfully' : 'เพิ่มบรรทัดเรียบร้อย'));
                } on FinReportValidationException catch (e) {
                  _showError(e.localized(isEnglish, forRow: true));
                } catch (e) {
                  _showError(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e');
                }
              },
              child: Text(isEdit ? l.save : l.add),
            ),
          ],
        ),
      ),
    );
  }

  // ===== COLUMN DIALOG =====
  void _showColumnDialog(int rowId, [Map<String, dynamic>? col]) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final isEdit = col != null;
    final seqCtrl = TextEditingController(text: isEdit ? (col['column_seq_no'] ?? '').toString() : '');
    String colType = col?['column_type'] ?? 'TEXT';
    final descCtrl = TextEditingController(text: col?['description_thai'] ?? '');
    final descEnCtrl = TextEditingController(text: col?['description_eng'] ?? '');
    final dataTypeCtrl = TextEditingController(text: col?['data_type'] ?? '');
    final flexCtrl = TextEditingController(text: (col?['column_flex'] ?? 1).toString());
    final indentCtrl = TextEditingController(text: (col?['indent_level'] ?? 0).toString());
    final fontSizeCtrl = TextEditingController(text: (col?['font_size'] ?? 10).toString());
    String fontWeight = col?['font_weight'] ?? 'NORMAL';
    String textAlign = col?['text_align'] ?? 'LEFT';
    final offsetCtrl = TextEditingController(text: (col?['period_offset'] ?? 0).toString());
    final formulaCtrl = TextEditingController(text: col?['formula_text'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit
              ? (isEnglish ? 'Edit Column' : 'แก้ไขคอลัมน์')
              : (isEnglish ? 'Add New Column' : 'เพิ่มคอลัมน์ใหม่')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: TextField(controller: seqCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isEnglish ? 'Sequence (column_seq_no)' : 'ลำดับ (column_seq_no)', border: const OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: flexCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isEnglish ? 'Flex (flex)' : 'สัดส่วน (flex)', border: const OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: colType,
                    decoration: InputDecoration(labelText: isEnglish ? 'Column Type (column_type)' : 'ประเภทคอลัมน์ (column_type)', border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'TEXT', child: Text(isEnglish ? 'TEXT' : 'TEXT (ข้อความ)')),
                      DropdownMenuItem(value: 'MTD', child: Text(isEnglish ? 'MTD (Monthly)' : 'MTD (ยอดรายเดือน)')),
                      DropdownMenuItem(value: 'YTD', child: Text(isEnglish ? 'YTD (Cumulative)' : 'YTD (ยอดสะสม)')),
                      DropdownMenuItem(value: 'FORMULA', child: Text(isEnglish ? 'FORMULA' : 'FORMULA (สูตรคำนวณ)')),
                      DropdownMenuItem(value: 'DIVIDER', child: Text(isEnglish ? 'DIVIDER (Line)' : 'DIVIDER (เส้นคั่น)')),
                    ],
                    onChanged: (v) => setDialogState(() => colType = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(labelText: isEnglish ? 'Text (Thai)' : 'ข้อความ (ไทย)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descEnCtrl,
                    decoration: InputDecoration(labelText: isEnglish ? 'Text (English)' : 'ข้อความ (อังกฤษ)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dataTypeCtrl,
                    decoration: InputDecoration(labelText: isEnglish ? 'data_type (e.g. = for double line)' : 'data_type (เช่น = สำหรับเส้นคู่)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: indentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'indent_level', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: fontSizeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'font_size', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: fontWeight,
                        decoration: const InputDecoration(labelText: 'font_weight', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                          DropdownMenuItem(value: 'BOLD', child: Text('BOLD')),
                          DropdownMenuItem(value: 'ITALIC', child: Text('ITALIC')),
                        ],
                        onChanged: (v) => setDialogState(() => fontWeight = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: textAlign,
                        decoration: const InputDecoration(labelText: 'text_align', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'LEFT', child: Text('LEFT')),
                          DropdownMenuItem(value: 'CENTER', child: Text('CENTER')),
                          DropdownMenuItem(value: 'RIGHT', child: Text('RIGHT')),
                        ],
                        onChanged: (v) => setDialogState(() => textAlign = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: offsetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    decoration: InputDecoration(labelText: isEnglish ? 'period_offset (MTD/YTD only)' : 'period_offset (MTD/YTD เท่านั้น)', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: formulaCtrl,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'formula_text (FORMULA only)' : 'formula_text (FORMULA เท่านั้น)',
                      helperText: isEnglish
                          ? 'e.g. REV_TOTAL - COGS (row codes), [CUR] * 2, (R100, C20)   operators + - * / ( )   functions ABS ROUND MIN MAX'
                          : 'เช่น REV_TOTAL - COGS (รหัสบรรทัด), [CUR] * 2, (R100, C20)   เครื่องหมาย + - * / ( )   ฟังก์ชัน ABS ROUND MIN MAX',
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
              onPressed: () async {
                final data = {
                  if (!isEdit) 'row_id': rowId,
                  'column_seq_no': int.tryParse(seqCtrl.text) ?? 0,
                  'column_type': colType,
                  'description_thai': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'description_eng': descEnCtrl.text.trim().isEmpty ? null : descEnCtrl.text.trim(),
                  'data_type': dataTypeCtrl.text.trim().isEmpty ? null : dataTypeCtrl.text.trim(),
                  'column_flex': int.tryParse(flexCtrl.text) ?? 1,
                  'indent_level': int.tryParse(indentCtrl.text) ?? 0,
                  'font_size': int.tryParse(fontSizeCtrl.text) ?? 10,
                  'font_weight': fontWeight,
                  'text_align': textAlign,
                  'period_offset': int.tryParse(offsetCtrl.text) ?? 0,
                  'formula_text': formulaCtrl.text.trim().isEmpty ? null : formulaCtrl.text.trim(),
                };
                try {
                  if (isEdit) {
                    await _service.updateColumn(col!['id'], data);
                  } else {
                    await _service.createColumn(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadRows(_selectedReport!['id']);
                  _showSuccess(isEdit
                      ? (isEnglish ? 'Column updated successfully' : 'แก้ไขคอลัมน์เรียบร้อย')
                      : (isEnglish ? 'Column added successfully' : 'เพิ่มคอลัมน์เรียบร้อย'));
                } on FinReportValidationException catch (e) {
                  _showError(e.localized(isEnglish));
                } catch (e) {
                  _showError(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e');
                }
              },
              child: Text(isEdit ? l.save : l.add),
            ),
          ],
        ),
      ),
    );
  }

  // ===== REPORT COLUMN DIALOG (gl_fin_report_col — ใช้กับทุกบรรทัด) =====
  String _periodRangeLabel(String range, bool isEnglish) {
    switch (range) {
      case 'QTD':
        return isEnglish ? 'QTD (Quarter to date)' : 'QTD (สะสมต้นไตรมาส)';
      case 'YTD':
        return isEnglish ? 'YTD (Year to date)' : 'YTD (สะสมต้นปี)';
      case 'FULL_YEAR':
        return isEnglish ? 'Full year' : 'ทั้งปีบัญชี';
      default:
        return isEnglish ? 'MTD (Period)' : 'MTD (ยอดงวดนี้)';
    }
  }

  /// ข้อความสั้นอธิบายคอลัมน์ เช่น "YTD -1Y" หรือ "= [CUR] - [PY]"
  String _reportColSummary(Map<String, dynamic> rc) {
    if (rc['col_kind'] == 'CALC') return '= ${rc['formula_text'] ?? ''}';
    if (rc['col_kind'] == 'LABEL') return _isEnglish ? 'row labels' : 'ชื่อบรรทัด';
    final parts = <String>[rc['period_range'] ?? 'MTD'];
    final int oy = rc['offset_years'] ?? 0;
    final int op = rc['offset_periods'] ?? 0;
    if (oy != 0) parts.add('${oy > 0 ? '+' : ''}${oy}Y');
    if (op != 0) parts.add('${op > 0 ? '+' : ''}${op}P');
    if (rc['branch_id'] != null) {
      final b = _branches.where((x) => x.id == rc['branch_id']).firstOrNull;
      parts.add('@${b?.branchCode ?? rc['branch_id']}');
    }
    return parts.join(' ');
  }

  void _showReportColDialog([Map<String, dynamic>? rc]) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final isEdit = rc != null;
    final int nextSeq = _reportCols.isEmpty
        ? 10
        : (_reportCols.map((c) => c['col_seq_no'] as int).reduce((a, b) => a > b ? a : b) + 10);
    final seqCtrl = TextEditingController(text: (rc?['col_seq_no'] ?? nextSeq).toString());
    final codeCtrl = TextEditingController(text: rc?['col_code'] ?? '');
    final headerThCtrl = TextEditingController(text: rc?['header_thai'] ?? '');
    final headerEnCtrl = TextEditingController(text: rc?['header_eng'] ?? '');
    String kind = rc?['col_kind'] ?? 'AMOUNT';
    String range = rc?['period_range'] ?? 'MTD';
    final offsetYearsCtrl = TextEditingController(text: (rc?['offset_years'] ?? 0).toString());
    final offsetPeriodsCtrl = TextEditingController(text: (rc?['offset_periods'] ?? 0).toString());
    final formulaCtrl = TextEditingController(text: rc?['formula_text'] ?? '');
    int? branchId = rc?['branch_id'];
    bool excludeClosing = rc?['exclude_closing_entries'] ?? true;
    bool isHidden = rc?['is_hidden'] ?? false;
    final flexCtrl = TextEditingController(text: (rc?['column_flex'] ?? 1).toString());
    final fontSizeCtrl = TextEditingController(text: (rc?['font_size'] ?? 10).toString());
    String fontWeight = rc?['font_weight'] ?? 'NORMAL';
    String textAlign = rc?['text_align'] ?? 'RIGHT';
    final Map<int, GlDimensionValue?> dimPicks = {};
    for (final t in _dimTypes) {
      final storedId = rc?['dim${t.slotNo}_id'] as int?;
      if (storedId != null) {
        dimPicks[t.slotNo] = (_dimValues[t.typeCode] ?? []).cast<GlDimensionValue?>()
            .firstWhere((v) => v?.id == storedId, orElse: () => null);
      }
    }
    final otherCodes = _reportCols
        .where((c) => c['id'] != rc?['id'])
        .map((c) => '[${c['col_code']}]')
        .join('  ');

    Future<void> save(BuildContext ctx) async {
      final data = {
        if (!isEdit) 'report_id': _selectedReport!['id'],
        'col_seq_no': int.tryParse(seqCtrl.text.trim()),
        'col_code': codeCtrl.text.trim().toUpperCase(),
        'header_thai': headerThCtrl.text.trim().isEmpty ? null : headerThCtrl.text.trim(),
        'header_eng': headerEnCtrl.text.trim().isEmpty ? null : headerEnCtrl.text.trim(),
        'col_kind': kind,
        'period_range': range,
        'offset_years': int.tryParse(offsetYearsCtrl.text.trim()) ?? 0,
        'offset_periods': int.tryParse(offsetPeriodsCtrl.text.trim()) ?? 0,
        'formula_text': kind == 'CALC' ? formulaCtrl.text.trim() : null,
        'branch_id': kind == 'AMOUNT' ? branchId : null,
        for (final t in _dimTypes)
          'dim${t.slotNo}_id': kind == 'AMOUNT' ? dimPicks[t.slotNo]?.id : null,
        'exclude_closing_entries': excludeClosing,
        'column_flex': int.tryParse(flexCtrl.text.trim()) ?? 1,
        'text_align': textAlign,
        'font_weight': fontWeight,
        'font_size': int.tryParse(fontSizeCtrl.text.trim()) ?? 10,
        'is_hidden': isHidden,
      };
      try {
        if (isEdit) {
          await _service.updateReportCol(rc['id'], data);
        } else {
          await _service.createReportCol(data);
        }
        if (ctx.mounted) Navigator.pop(ctx);
        await _loadRows(_selectedReport!['id']);
        _showSuccess(isEdit
            ? (isEnglish ? 'Column updated successfully' : 'แก้ไขคอลัมน์เรียบร้อย')
            : (isEnglish ? 'Column added successfully' : 'เพิ่มคอลัมน์เรียบร้อย'));
      } on FinReportValidationException catch (e) {
        _showError(e.localized(isEnglish));
      } catch (e) {
        _showError(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e');
      }
    }

    Future<void> delete(BuildContext ctx) async {
      final confirm = await showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: Text(l.confirmDelete),
          content: Text(isEnglish
              ? 'Delete column [${rc!['col_code']}] from every row of this report?'
              : 'ต้องการลบคอลัมน์ [${rc!['col_code']}] ออกจากทุกบรรทัดของรายงานนี้?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.delete),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await _service.deleteReportCol(rc!['id']);
        if (ctx.mounted) Navigator.pop(ctx);
        await _loadRows(_selectedReport!['id']);
        _showSuccess(isEnglish ? 'Column deleted successfully' : 'ลบคอลัมน์เรียบร้อย');
      } on FinReportValidationException catch (e) {
        _showError(e.localized(isEnglish));
      } catch (e) {
        _showError(isEnglish ? 'Delete failed: $e' : 'ลบไม่สำเร็จ: $e');
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit
              ? (isEnglish ? 'Edit Report Column (all rows)' : 'แก้ไขคอลัมน์ของรายงาน (ใช้กับทุกบรรทัด)')
              : (isEnglish ? 'Add Report Column (all rows)' : 'เพิ่มคอลัมน์ของรายงาน (ใช้กับทุกบรรทัด)')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: TextField(controller: seqCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isEnglish ? 'Sequence (C no.)' : 'ลำดับ (เลข C)', border: const OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Code (used in formulas)' : 'รหัส (ใช้ในสูตร)',
                          hintText: 'CUR, PY, VAR',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: headerThCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Header (Thai)' : 'หัวคอลัมน์ (ไทย)', border: const OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                    controller: headerEnCtrl,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Header (English)' : 'หัวคอลัมน์ (อังกฤษ)',
                      helperText: isEnglish
                          ? r'Variables: $colPeriodName  $colFiscalYear (period of this column)'
                          : r'ตัวแปร: $colPeriodName  $colFiscalYear (งวดของคอลัมน์นี้)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: kind,
                    decoration: InputDecoration(labelText: isEnglish ? 'Column Kind' : 'ชนิดคอลัมน์', border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'LABEL', child: Text(isEnglish ? 'LABEL (row labels)' : 'LABEL (ชื่อบรรทัด)')),
                      DropdownMenuItem(value: 'AMOUNT', child: Text(isEnglish ? 'AMOUNT (balance from GL)' : 'AMOUNT (ยอดจากบัญชี)')),
                      DropdownMenuItem(value: 'CALC', child: Text(isEnglish ? 'CALC (formula from other columns)' : 'CALC (คำนวณจากคอลัมน์อื่น)')),
                    ],
                    onChanged: (v) => setDialogState(() {
                      // ชื่อบรรทัดปกติชิดซ้ายและกว้างกว่าคอลัมน์ตัวเลข
                      if (v == 'LABEL' && kind != 'LABEL' && !isEdit) {
                        textAlign = 'LEFT';
                        if (flexCtrl.text.trim() == '1') flexCtrl.text = '4';
                      }
                      kind = v!;
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (kind == 'AMOUNT') ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: range,
                      decoration: InputDecoration(labelText: isEnglish ? 'Period Range' : 'ช่วงงวด', border: const OutlineInputBorder()),
                      items: ['MTD', 'QTD', 'YTD', 'FULL_YEAR']
                          .map((r) => DropdownMenuItem(value: r, child: Text(_periodRangeLabel(r, isEnglish))))
                          .toList(),
                      onChanged: (v) => setDialogState(() => range = v!),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: offsetYearsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          decoration: InputDecoration(labelText: isEnglish ? 'Year offset (-1 = prior year)' : 'เลื่อนปี (-1 = ปีก่อน)', border: const OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: offsetPeriodsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          decoration: InputDecoration(labelText: isEnglish ? 'Period offset (-1 = prior period)' : 'เลื่อนงวด (-1 = งวดก่อน)', border: const OutlineInputBorder()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: _branches.any((b) => b.id == branchId) ? branchId : null,
                      decoration: InputDecoration(labelText: isEnglish ? 'Branch (this column only)' : 'สาขา (เฉพาะคอลัมน์นี้)', border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(isEnglish ? '— All Branches —' : '— ทุกสาขา —')),
                        ..._branches.where((b) => b.isActive || b.id == branchId).map((b) => DropdownMenuItem<int?>(
                              value: b.id,
                              child: Text('${b.branchCode}  ${isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai}'),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => branchId = v),
                    ),
                    if (_dimTypes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ..._dimTypes.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlDimensionPickerField(
                              dimType: t,
                              values: _dimValues[t.typeCode] ?? [],
                              selected: dimPicks[t.slotNo],
                              isDense: false,
                              onSelected: (val) => setDialogState(() => dimPicks[t.slotNo] = val),
                            ),
                          )),
                    ],
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(isEnglish ? 'Exclude year-end closing entries' : 'ไม่รวมรายการปิดบัญชีสิ้นปี'),
                      subtitle: Text(isEnglish
                          ? 'Keep on so P&L does not show zero after year-end closing'
                          : 'ควรเปิดไว้ ไม่เช่นนั้นงบกำไรขาดทุนงวดสุดท้ายจะเป็นศูนย์หลังปิดบัญชี'),
                      value: excludeClosing,
                      onChanged: (v) => setDialogState(() => excludeClosing = v),
                    ),
                  ] else if (kind == 'CALC') ...[
                    TextField(
                      controller: formulaCtrl,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Formula' : 'สูตรคำนวณ',
                        hintText: '[CUR] - [PY]',
                        helperText: otherCodes.isEmpty
                            ? (isEnglish ? 'Add AMOUNT columns first' : 'เพิ่มคอลัมน์ AMOUNT ก่อน')
                            : '${isEnglish ? 'Columns' : 'คอลัมน์'}: $otherCodes   ABS ROUND MIN MAX\n'
                              '${isEnglish ? '% of revenue' : '% ของรายได้'}: [CUR] / REV_TOTAL[CUR] * 100',
                        helperMaxLines: 2,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(child: TextField(controller: flexCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isEnglish ? 'Width (flex)' : 'ความกว้าง (flex)', border: const OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: fontSizeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'font_size', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: fontWeight,
                        decoration: const InputDecoration(labelText: 'font_weight', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                          DropdownMenuItem(value: 'BOLD', child: Text('BOLD')),
                          DropdownMenuItem(value: 'ITALIC', child: Text('ITALIC')),
                        ],
                        onChanged: (v) => setDialogState(() => fontWeight = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: textAlign,
                        decoration: const InputDecoration(labelText: 'text_align', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'LEFT', child: Text('LEFT')),
                          DropdownMenuItem(value: 'CENTER', child: Text('CENTER')),
                          DropdownMenuItem(value: 'RIGHT', child: Text('RIGHT')),
                        ],
                        onChanged: (v) => setDialogState(() => textAlign = v!),
                      ),
                    ),
                  ]),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(isEnglish ? 'Hidden (helper column for formulas)' : 'ซ่อน (คอลัมน์ช่วยคำนวณ ไม่แสดงผล)'),
                    value: isHidden,
                    onChanged: (v) => setDialogState(() => isHidden = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit && _canDelete)
              TextButton(
                onPressed: () => delete(ctx),
                child: Text(l.delete, style: const TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            if (isEdit ? _canEdit : _canCreate)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
                onPressed: () => save(ctx),
                child: Text(isEdit ? l.save : l.add),
              ),
          ],
        ),
      ),
    );
  }

  // ===== REPORT COLUMNS BAR =====
  Widget _buildReportColsBar() {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    return Container(
      color: Colors.deepOrange[50],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Tooltip(
            message: isEnglish
                ? 'Defined once, applied to every row. A row column with the same C number overrides it for that row.'
                : 'กำหนดครั้งเดียว ใช้กับทุกบรรทัด ถ้าบรรทัดมีคอลัมน์ที่เลข C ตรงกัน จะใช้คอลัมน์ของบรรทัดนั้นแทน',
            child: Text(
              isEnglish ? 'Report columns:' : 'คอลัมน์ของรายงาน:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange[900]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _reportCols.isEmpty
                ? Text(
                    isEnglish ? '(none — amounts are defined per row)' : '(ยังไม่มี — กำหนดยอดแยกทีละบรรทัด)',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _reportCols.map((rc) {
                        final bool hidden = rc['is_hidden'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            backgroundColor: rc['col_kind'] == 'CALC'
                                ? Colors.purple[50]
                                : (rc['col_kind'] == 'LABEL' ? Colors.orange[50] : Colors.blue[50]),
                            avatar: hidden ? const Icon(Icons.visibility_off, size: 16) : null,
                            label: Text(
                              'C${rc['col_seq_no']} [${rc['col_code']}]  ${_reportColSummary(rc)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            tooltip: (isEnglish ? rc['header_eng'] : null) ?? rc['header_thai'] ?? '',
                            onPressed: () => _showReportColDialog(rc),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          if (_canCreate)
            TextButton.icon(
              icon: const Icon(Icons.view_column, size: 18),
              label: Text(isEnglish ? 'Add Column' : 'เพิ่มคอลัมน์'),
              style: TextButton.styleFrom(foregroundColor: Colors.deepOrange[900]),
              onPressed: () => _showReportColDialog(),
            ),
        ],
      ),
    );
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    _canCreate = MenuScope.of(context)?.canCreate ?? true;
    _canEdit = MenuScope.of(context)?.canEdit ?? true;
    _canDelete = MenuScope.of(context)?.canDelete ?? true;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: _loadReports,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36,
                color: Colors.deepOrange[900],
                child: IconButton(
                  icon: Icon(
                    _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded
                      ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                      : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                ),
              ),
              AnimatedContainer(
                duration: _isDraggingDivider
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    alignment: Alignment.topLeft,
                    child: _buildLeftPanel(),
                  ),
                ),
              ),
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) =>
                        setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _leftPanelWidth = (_leftPanelWidth + details.delta.dx)
                            .clamp(200.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) =>
                        setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              Expanded(child: _buildRightPanel()),
            ],
          );
        },
      ),
    );
  }

  // ===== LEFT PANEL =====
  Widget _buildLeftPanel() {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.blueGrey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(isEnglish ? 'Financial Reports' : 'รายการงบการเงิน', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (_canCreate)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.add),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange[900]),
                  onPressed: () => _showReportDialog(),
                ),
              if (_canCreate)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: isEnglish ? 'More ways to create' : 'สร้างงบแบบอื่น',
                  onSelected: (v) => v == 'template' ? _showTemplatePicker() : _importFromFile(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'template', child: ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: Text(isEnglish ? 'Create from template…' : 'สร้างจากแม่แบบ…'),
                      dense: true,
                    )),
                    PopupMenuItem(value: 'import', child: ListTile(
                      leading: const Icon(Icons.upload_file),
                      title: Text(isEnglish ? 'Import from JSON file…' : 'นำเข้าจากไฟล์ JSON…'),
                      dense: true,
                    )),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? Center(child: Text(isEnglish ? 'No reports yet' : 'ยังไม่มีรายการ'))
                  : ListView.separated(
                      itemCount: _reports.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = _reports[i];
                        final isSelected = _selectedReport?['id'] == r['id'];
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Colors.deepOrange[50],
                          title: Text(
                            '${r['report_code']} - ${r['report_name_thai']}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          subtitle: Text(
                            r['is_active'] == true ? l.active : l.inactive,
                            style: TextStyle(fontSize: 13, color: r['is_active'] == true ? Colors.green : Colors.red),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_canEdit)
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: l.edit,
                                  onPressed: () => _showReportDialog(r),
                                ),
                              IconButton(
                                icon: const Icon(Icons.download, size: 18),
                                tooltip: isEnglish ? 'Export JSON (to copy to another database)' : 'ส่งออก JSON (ไปใช้ในฐานข้อมูลอื่น)',
                                onPressed: () => _exportReport(r),
                              ),
                              IconButton(
                                icon: Icon(Icons.design_services, size: 18, color: Colors.deepOrange[900]),
                                tooltip: isEnglish ? 'Design' : 'ออกแบบ',
                                onPressed: () {
                                  setState(() {
                                    _selectedReport = r;
                                    _rows = [];
                                  });
                                  _loadRows(r['id']);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ===== RIGHT PANEL =====
  Widget _buildRightPanel() {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    if (_selectedReport == null) {
      return Center(
        child: Text(
          isEnglish ? 'Please click "Design" to select a financial report' : 'กรุณากดปุ่ม "ออกแบบ" เพื่อเลือกงบการเงิน',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.deepOrange[800],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${isEnglish ? 'Design' : 'ออกแบบ'}: ${_selectedReport!['report_code']} - ${_selectedReport!['report_name_thai']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                icon: Icon(_showPreview ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                label: Text(_showPreview
                    ? (isEnglish ? 'Hide Preview' : 'ซ่อนตัวอย่าง')
                    : (isEnglish ? 'Preview' : 'ตัวอย่างงบ')),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                onPressed: _togglePreview,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(isEnglish ? 'Check Chart Mapping' : 'ตรวจผังบัญชี'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                onPressed: _showAccountMappingDialog,
              ),
              const SizedBox(width: 8),
              if (_canCreate)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(isEnglish ? 'Add Row' : 'เพิ่มบรรทัด'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange[900]),
                  onPressed: () => _showRowDialog(),
                ),
            ],
          ),
        ),
        _buildReportColsBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildRowsList(isEnglish)),
              if (_showPreview) Expanded(flex: 4, child: _buildPreviewPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRowsList(bool isEnglish) {
    return _isLoadingRows
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(child: Text(isEnglish ? 'No rows yet — click "Add Row" to start' : 'ยังไม่มีบรรทัด กดปุ่ม "เพิ่มบรรทัด" เพื่อเริ่ม', style: const TextStyle(color: Colors.grey)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(8),
                      buildDefaultDragHandles: false,
                      itemCount: _rows.length,
                      onReorder: _onReorderRows,
                      itemBuilder: (ctx, i) => Padding(
                        key: ValueKey(_rows[i]['id']),
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildRowItem(_rows[i], i),
                      ),
                    );
  }

  /// ลากวางบรรทัด → backend ตั้งเลขบรรทัดใหม่ 10, 20, 30, ... และแก้ (Rn, Cm) ในสูตรให้ตรง
  Future<void> _onReorderRows(int oldIndex, int newIndex) async {
    final isEnglish = _isEnglish;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    final reordered = List<Map<String, dynamic>>.from(_rows);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    setState(() => _rows = reordered);
    try {
      final result = await _service.reorderRows(
          _selectedReport!['id'], reordered.map((r) => r['id'] as int).toList());
      final int fixed = result['formulas_updated'] ?? 0;
      _showSuccess(isEnglish
          ? 'Rows renumbered${fixed > 0 ? ' — $fixed formula(s) updated to the new row numbers' : ''}'
          : 'เรียงบรรทัดใหม่แล้ว${fixed > 0 ? ' — แก้เลขบรรทัดในสูตร $fixed สูตร' : ''}');
    } catch (e) {
      _showError(isEnglish ? 'Reorder failed: $e' : 'เรียงบรรทัดไม่สำเร็จ: $e');
    }
    await _loadRows(_selectedReport!['id']);
  }

  // ===== ROW ITEM =====
  Widget _buildRowItem(Map<String, dynamic> row, int index) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final List<dynamic> columns = row['columns'] ?? [];
    final String rowType = row['row_type'] ?? 'BODY';
    final String rowKind = row['row_kind'] ?? 'ACCOUNTS';
    final int seqNo = row['row_seq_no'] ?? 0;

    Color badgeColor;
    switch (rowType) {
      case 'HEADER':
        badgeColor = Colors.blue[700]!;
        break;
      case 'FOOTER':
        badgeColor = Colors.purple[700]!;
        break;
      default:
        badgeColor = Colors.green[700]!;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            if (_canEdit)
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: isEnglish ? 'Drag to reorder' : 'ลากเพื่อย้ายบรรทัด',
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
                  ),
                ),
              ),
            // ปุ่มลบบรรทัด
            if (_canDelete)
              IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: isEnglish ? 'Delete row' : 'ลบบรรทัด',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.confirmDelete),
                    content: Text(isEnglish
                        ? 'Do you want to delete row $seqNo and all columns in this row?'
                        : 'ต้องการลบบรรทัดที่ $seqNo และคอลัมน์ทั้งหมดในบรรทัดนี้?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.delete),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await _service.deleteRow(row['id']);
                    await _loadRows(_selectedReport!['id']);
                    _showSuccess(isEnglish ? 'Row deleted successfully' : 'ลบบรรทัดเรียบร้อย');
                  } on FinReportValidationException catch (e) {
                    _showError(e.localized(isEnglish, forRow: true));
                  } catch (e) {
                    _showError(isEnglish ? 'Delete failed: $e' : 'ลบไม่สำเร็จ: $e');
                  }
                }
              },
            ),
            const SizedBox(width: 4),
            // ปุ่มเลขบรรทัด (คลิกแก้ไข)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(40, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(color: Colors.deepOrange[900]!),
              ),
              onPressed: () => _showRowDialog(row),
              child: Text('$seqNo', style: TextStyle(color: Colors.deepOrange[900], fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 6),
            // Badge อักษรย่อ row_type
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                rowType[0],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            // รหัสบรรทัด + ชนิดบรรทัด (+ บรรทัดยอดรวมที่รวมเข้า)
            Tooltip(
              message: [
                _rowKindLabel(rowKind, isEnglish),
                if (row['parent_row_code'] != null) '${isEnglish ? 'Added into' : 'รวมเข้า'} ${row['parent_row_code']}',
                if (rowKind == 'FORMULA' && row['row_formula'] != null) '= ${row['row_formula']}',
                if (row['print_control'] == 'HIDE') isEnglish ? 'Hidden (helper row)' : 'ซ่อน (บรรทัดช่วยคำนวณ)',
                if (rowKind == 'ACCOUNTS')
                  '${isEnglish ? 'Accounts' : 'บัญชี'}: ${_rowAcctSels(row).map((s) => _acctSelSummary(s, isEnglish)).join(', ')}',
              ].join('\n'),
              child: SizedBox(
                width: 96,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['row_code'] ?? '—',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: row['row_code'] == null ? Colors.grey : Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$rowKind${row['parent_row_code'] != null ? ' > ${row['parent_row_code']}' : ''}',
                      style: TextStyle(fontSize: 10, color: _rowKindColor(rowKind)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // พื้นที่คอลัมน์
            Expanded(
              child: columns.isEmpty && _reportCols.isEmpty && _rowLabelOf(row, isEnglish).isEmpty
                  ? Container(
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(isEnglish ? '(No columns yet)' : '(ยังไม่มีคอลัมน์)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : _buildColumnsPreview(row, columns),
            ),
            const SizedBox(width: 6),
            // ปุ่มเพิ่มคอลัมน์
            IconButton(
              icon: Icon(Icons.add_box_outlined, size: 22, color: Colors.deepOrange[900]),
              tooltip: isEnglish ? 'Add column' : 'เพิ่มคอลัมน์',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _showColumnDialog(row['id']),
            ),
          ],
        ),
      ),
    );
  }

  /// ช่องชื่อบรรทัดในตัวอย่าง (คลิกแล้วเปิดแก้ไขบรรทัด เพราะชื่อเก็บที่บรรทัด)
  Widget _labelChip(String label, Map<String, dynamic> row, bool isEnglish, String ref) {
    final int indent = row['indent_level'] ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: indent * 8.0),
            child: Text(
              label.isEmpty ? (isEnglish ? '(no label)' : '(ไม่มีชื่อ)') : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: row['is_bold'] == true ? FontWeight.bold : FontWeight.normal,
                color: label.isEmpty ? Colors.grey : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(ref, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ===== COLUMNS PREVIEW =====
  Widget _buildColumnsPreview(Map<String, dynamic> row, List<dynamic> columns) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final int rowId = row['id'];
    final int rowSeqNo = row['row_seq_no'] ?? 0;
    final rowCols = List<Map<String, dynamic>>.from(columns);
    final overrideSeqs = rowCols.map((c) => c['column_seq_no']).toSet();
    final reportColSeqs = _reportCols.map((rc) => rc['col_seq_no']).toSet();
    final String rowKind = row['row_kind'] ?? 'ACCOUNTS';
    final bool hasAccounts = rowKind == 'ACCOUNTS' && _rowAcctSels(row).any((s) => s['is_exclude'] != true);
    final bool hasAmounts = hasAccounts || rowKind == 'TOTAL' || rowKind == 'FORMULA';
    final bool hasOverride = _reportCols.any((rc) => rc['col_kind'] != 'LABEL' && overrideSeqs.contains(rc['col_seq_no']));
    final String rowLabel = rowKind == 'BLANK' ? '' : _rowLabelOf(row, isEnglish);
    final String rowRef = row['row_code'] ?? 'R$rowSeqNo';
    final String amountPrefix = rowKind == 'TOTAL' ? 'Σ ' : (rowKind == 'FORMULA' ? '= ' : '');
    final bool hasLabelCol = _reportCols.any((rc) => rc['col_kind'] == 'LABEL');

    // คอลัมน์ระดับรายงานที่บรรทัดนี้ไม่ได้ override — แสดงเหมือนผลจริง (บรรทัดหัวข้อไม่มีตัวเลข)
    final cells = <Map<String, dynamic>>[
      ...rowCols,
      for (final rc in _reportCols)
        if (!overrideSeqs.contains(rc['col_seq_no']) && rc['is_hidden'] != true)
          {'_report_col': rc, 'column_seq_no': rc['col_seq_no'], 'column_flex': rc['column_flex'] ?? 1},
      // ไม่มีคอลัมน์ LABEL → engine วางชื่อบรรทัดไว้หน้าสุด (seq 0, flex 3)
      if (!hasLabelCol && rowLabel.isNotEmpty && !overrideSeqs.contains(0))
        {'_fallback_label': true, 'column_seq_no': 0, 'column_flex': 3},
    ]..sort((a, b) => (a['column_seq_no'] ?? 0).compareTo(b['column_seq_no'] ?? 0));

    return Row(
      children: cells.map((col) {
        if (col['_fallback_label'] == true) {
          return Expanded(
            flex: 3,
            child: Tooltip(
              message: isEnglish
                  ? 'Row label — add a LABEL report column to control its position and width'
                  : 'ชื่อบรรทัด — เพิ่มคอลัมน์ของรายงานชนิด LABEL เพื่อกำหนดตำแหน่งและความกว้าง',
              child: GestureDetector(
                onTap: () => _showRowDialog(row),
                child: _labelChip(rowLabel, row, isEnglish, '$rowRef, C0'),
              ),
            ),
          );
        }
        final Map<String, dynamic>? rc = col['_report_col'];
        if (rc != null && rc['col_kind'] == 'LABEL') {
          return Expanded(
            flex: rc['column_flex'] ?? 1,
            child: GestureDetector(
              onTap: () => _showRowDialog(row),
              child: _labelChip(rowLabel, row, isEnglish, '$rowRef, C${rc['col_seq_no']}'),
            ),
          );
        }
        if (rc != null) {
          final bool showsValue = rc['col_kind'] == 'CALC' ? (hasAmounts || hasOverride) : hasAmounts;
          return Expanded(
            flex: rc['column_flex'] ?? 1,
            child: Tooltip(
              message: isEnglish ? 'Report column (all rows) — click to edit' : 'คอลัมน์ของรายงาน (ทุกบรรทัด) — คลิกเพื่อแก้ไข',
              child: GestureDetector(
                onTap: () => _showReportColDialog(rc),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        showsValue ? '${rc['col_kind'] == 'CALC' ? '' : amountPrefix}[${rc['col_code']}]' : '',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: row['is_bold'] == true ? FontWeight.bold : FontWeight.normal,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('$rowRef, C${rc['col_seq_no']}', style: TextStyle(fontSize: 11, color: Colors.grey[500]), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final int flex = col['column_flex'] ?? 1;
        final String colType = col['column_type'] ?? 'TEXT';
        final String? desc = col['description_thai'];
        final String? dataType = col['data_type'];
        final int offset = col['period_offset'] ?? 0;
        final String? formula = col['formula_text'];
        final int colSeqNo = col['column_seq_no'] ?? 0;
        final int indent = col['indent_level'] ?? 0;
        final String align = col['text_align'] ?? 'LEFT';
        final bool overridesReportCol = reportColSeqs.contains(colSeqNo);
        final String ref = 'flex:$flex, R$rowSeqNo, C$colSeqNo'
            '${overridesReportCol ? (isEnglish ? ' (override)' : ' (แทนคอลัมน์รายงาน)') : ''}';

        Color chipColor;
        switch (colType) {
          case 'MTD':
            chipColor = Colors.blue[100]!;
            break;
          case 'YTD':
            chipColor = Colors.teal[100]!;
            break;
          case 'FORMULA':
            chipColor = Colors.purple[100]!;
            break;
          case 'DIVIDER':
            chipColor = Colors.grey[300]!;
            break;
          default:
            chipColor = Colors.orange[100]!;
        }

        // สร้าง widget แสดงเนื้อหาตาม column_type
        Widget contentWidget;
        if (colType == 'DIVIDER') {
          contentWidget = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: dataType == '='
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Divider(thickness: 1, height: 1, color: Colors.grey[600]),
                    const SizedBox(height: 2),
                    Divider(thickness: 1, height: 1, color: Colors.grey[600]),
                  ])
                : Divider(thickness: 1, height: 1, color: Colors.grey[600]),
          );
        } else {
          TextAlign textAlignVal = TextAlign.left;
          if (align == 'CENTER') textAlignVal = TextAlign.center;
          if (align == 'RIGHT') textAlignVal = TextAlign.right;

          String label;
          if (colType == 'TEXT') {
            final String? descEn = col['description_eng'];
            label = (isEnglish && descEn != null && descEn.isNotEmpty) ? descEn : (desc ?? colType);
          } else if (colType == 'MTD' || colType == 'YTD') {
            label = offset == 0 ? colType : '$colType($offset)';
          } else if (colType == 'FORMULA') {
            label = formula ?? colType;
          } else {
            label = colType;
          }

          contentWidget = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(left: indent * 8.0),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: textAlignVal,
                ),
              ),
              Text(ref, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          );
        }

        return Expanded(
          flex: flex,
          child: GestureDetector(
            onTap: () => _showColumnDialog(rowId, col),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: contentWidget,
            ),
          ),
        );
      }).toList(),
    );
  }
}
