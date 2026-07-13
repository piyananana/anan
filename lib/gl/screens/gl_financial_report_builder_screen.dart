import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/gl_account.dart';
import '../models/gl_dimension.dart';
import '../services/gl_account_service.dart';
import '../services/gl_financial_report_builder_service.dart';
import '../services/gl_dimension_service.dart';
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

  List<Account> _accounts = [];
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _selectedReport;
  bool _isLoadingReports = false;
  bool _isLoadingRows = false;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 400.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final results = await Future.wait([
        _service.fetchReports(),
        _accountService.fetchRows(),
        _dimService.fetchActiveTypes(),
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
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
      });
    } catch (e) {
      _showError('โหลดรายการล้มเหลว: $e');
    } finally {
      setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadRows(int reportId) async {
    setState(() => _isLoadingRows = true);
    try {
      final rows = await _service.fetchRows(reportId);
      setState(() => _rows = rows);
    } catch (e) {
      _showError('โหลดบรรทัดล้มเหลว: $e');
    } finally {
      setState(() => _isLoadingRows = false);
    }
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
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEdit = report != null;
    final codeCtrl = TextEditingController(text: report?['report_code'] ?? '');
    final nameCtrl = TextEditingController(text: report?['report_name_thai'] ?? '');
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
          title: Text(isEdit ? 'แก้ไขงบการเงิน' : 'เพิ่มงบการเงินใหม่'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'รหัส (report_code)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่องบการเงิน (ภาษาไทย)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: orientation,
                    decoration: const InputDecoration(labelText: 'การวางแนวหน้ากระดาษ', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'PORTRAIT', child: Text('PORTRAIT (แนวตั้ง)')),
                      DropdownMenuItem(value: 'LANDSCAPE', child: Text('LANDSCAPE (แนวนอน)')),
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
                    title: const Text('ใช้งาน (is_active)'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    dense: true,
                  ),
                  SwitchListTile(
                    title: const Text('แสดงค่าติดลบในวงเล็บ'),
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
                  _showSuccess(isEdit ? 'แก้ไขเรียบร้อย' : 'เพิ่มเรียบร้อย');
                } catch (e) {
                  _showError('เกิดข้อผิดพลาด: $e');
                }
              },
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ROW DIALOG =====
  Future<Account?> _pickAccountInDialog(BuildContext ctx, Account? current) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);
    Account? picked;

    await showDialog(
      context: ctx,
      builder: (ctx2) => StatefulBuilder(builder: (ctx2, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(_accounts);
            } else {
              final lq = q.toLowerCase();
              filtered = _accounts
                  .where((a) =>
                      a.accountCode.toLowerCase().contains(lq) ||
                      a.accountNameThai.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกรหัสบัญชี'),
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

  void _showRowDialog([Map<String, dynamic>? row]) {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEdit = row != null;
    final seqCtrl = TextEditingController(text: isEdit ? (row['row_seq_no'] ?? '').toString() : '');
    String rowType = row?['row_type'] ?? 'BODY';
    String printControl = row?['print_control'] ?? 'SHOW';
    final String? initAccFrom = row?['account_from'];
    final String? initAccTo = row?['account_to'];
    Account? dlgAccFrom = initAccFrom != null
        ? _accounts.cast<Account?>().firstWhere(
            (a) => a?.accountCode == initAccFrom, orElse: () => null)
        : null;
    Account? dlgAccTo = initAccTo != null
        ? _accounts.cast<Account?>().firstWhere(
            (a) => a?.accountCode == initAccTo, orElse: () => null)
        : null;
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
          title: Text(isEdit ? 'แก้ไขบรรทัด' : 'เพิ่มบรรทัดใหม่'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: seqCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ลำดับบรรทัด (row_seq_no)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: rowType,
                    decoration: const InputDecoration(labelText: 'ประเภทบรรทัด (row_type)', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'HEADER', child: Text('HEADER (ส่วนหัว)')),
                      DropdownMenuItem(value: 'BODY', child: Text('BODY (เนื้อหา)')),
                      DropdownMenuItem(value: 'FOOTER', child: Text('FOOTER (ส่วนท้าย)')),
                    ],
                    onChanged: (v) => setDialogState(() => rowType = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: printControl,
                    decoration: const InputDecoration(labelText: 'การแสดงผล (print_control)', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'SHOW', child: Text('SHOW (แสดง)')),
                      DropdownMenuItem(value: 'HIDE', child: Text('HIDE (ซ่อน)')),
                    ],
                    onChanged: (v) => setDialogState(() => printControl = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'รหัสบัญชีต้น (account_from)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: dlgAccFrom != null
                                ? Text('${dlgAccFrom!.accountCode} — ${dlgAccFrom!.accountNameThai}',
                                    style: const TextStyle(fontWeight: FontWeight.bold))
                                : const Text('— ไม่ระบุ —',
                                    style: TextStyle(color: Colors.grey)),
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.deepOrange[900]),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final picked = await _pickAccountInDialog(ctx, dlgAccFrom);
                              if (picked != null) setDialogState(() => dlgAccFrom = picked);
                            },
                          ),
                          if (dlgAccFrom != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setDialogState(() => dlgAccFrom = null),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'รหัสบัญชีปลาย (account_to)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: dlgAccTo != null
                                ? Text('${dlgAccTo!.accountCode} — ${dlgAccTo!.accountNameThai}',
                                    style: const TextStyle(fontWeight: FontWeight.bold))
                                : const Text('— ไม่ระบุ —',
                                    style: TextStyle(color: Colors.grey)),
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.deepOrange[900]),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final picked = await _pickAccountInDialog(ctx, dlgAccTo);
                              if (picked != null) setDialogState(() => dlgAccTo = picked);
                            },
                          ),
                          if (dlgAccTo != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setDialogState(() => dlgAccTo = null),
                            ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: normalSign,
                    decoration: const InputDecoration(labelText: 'เครื่องหมายปกติ (normal_sign)', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'DEBIT', child: Text('DEBIT (เดบิต)')),
                      DropdownMenuItem(value: 'CREDIT', child: Text('CREDIT (เครดิต)')),
                    ],
                    onChanged: (v) => setDialogState(() => normalSign = v!),
                  ),
                  if (_dimTypes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('กรอง Dimension (เลือกเฉพาะที่ต้องการ)',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  'row_type': rowType,
                  'print_control': printControl,
                  'account_from': dlgAccFrom?.accountCode,
                  'account_to': dlgAccTo?.accountCode,
                  'normal_sign': normalSign,
                  'branch_id': int.tryParse(branchCtrl.text.trim()),
                  for (final t in _dimTypes)
                    'dim${t.slotNo}_id': dimPicks[t.slotNo]?.id,
                };
                try {
                  if (isEdit) {
                    await _service.updateRow(row!['id'], data);
                  } else {
                    await _service.createRow(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadRows(_selectedReport!['id']);
                  _showSuccess(isEdit ? 'แก้ไขบรรทัดเรียบร้อย' : 'เพิ่มบรรทัดเรียบร้อย');
                } catch (e) {
                  _showError('เกิดข้อผิดพลาด: $e');
                }
              },
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== COLUMN DIALOG =====
  void _showColumnDialog(int rowId, [Map<String, dynamic>? col]) {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEdit = col != null;
    final seqCtrl = TextEditingController(text: isEdit ? (col['column_seq_no'] ?? '').toString() : '');
    String colType = col?['column_type'] ?? 'TEXT';
    final descCtrl = TextEditingController(text: col?['description_thai'] ?? '');
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
          title: Text(isEdit ? 'แก้ไขคอลัมน์' : 'เพิ่มคอลัมน์ใหม่'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: TextField(controller: seqCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ลำดับ (column_seq_no)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: flexCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'สัดส่วน (flex)', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: colType,
                    decoration: const InputDecoration(labelText: 'ประเภทคอลัมน์ (column_type)', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'TEXT', child: Text('TEXT (ข้อความ)')),
                      DropdownMenuItem(value: 'MTD', child: Text('MTD (ยอดรายเดือน)')),
                      DropdownMenuItem(value: 'YTD', child: Text('YTD (ยอดสะสม)')),
                      DropdownMenuItem(value: 'FORMULA', child: Text('FORMULA (สูตรคำนวณ)')),
                      DropdownMenuItem(value: 'DIVIDER', child: Text('DIVIDER (เส้นคั่น)')),
                    ],
                    onChanged: (v) => setDialogState(() => colType = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'ข้อความ / คำอธิบาย (description_thai)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dataTypeCtrl,
                    decoration: const InputDecoration(labelText: 'data_type (เช่น = สำหรับเส้นคู่)', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'period_offset (MTD/YTD เท่านั้น)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: formulaCtrl,
                    decoration: const InputDecoration(labelText: 'formula_text (FORMULA เท่านั้น)', border: OutlineInputBorder()),
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
                  _showSuccess(isEdit ? 'แก้ไขคอลัมน์เรียบร้อย' : 'เพิ่มคอลัมน์เรียบร้อย');
                } catch (e) {
                  _showError('เกิดข้อผิดพลาด: $e');
                }
              },
              child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
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
                  tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
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
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.blueGrey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('รายการงบการเงิน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.add),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange[900]),
                onPressed: () => _showReportDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('ยังไม่มีรายการ'))
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
                            r['is_active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
                            style: TextStyle(fontSize: 13, color: r['is_active'] == true ? Colors.green : Colors.red),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'แก้ไข',
                                onPressed: () => _showReportDialog(r),
                              ),
                              IconButton(
                                icon: Icon(Icons.design_services, size: 18, color: Colors.deepOrange[900]),
                                tooltip: 'ออกแบบ',
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
    if (_selectedReport == null) {
      return const Center(
        child: Text(
          'กรุณากดปุ่ม "ออกแบบ" เพื่อเลือกงบการเงิน',
          style: TextStyle(color: Colors.grey, fontSize: 16),
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
                  'ออกแบบ: ${_selectedReport!['report_code']} - ${_selectedReport!['report_name_thai']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มบรรทัด'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange[900]),
                onPressed: () => _showRowDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRows
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(child: Text('ยังไม่มีบรรทัด กดปุ่ม "เพิ่มบรรทัด" เพื่อเริ่ม', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (ctx, i) => _buildRowItem(_rows[i]),
                    ),
        ),
      ],
    );
  }

  // ===== ROW ITEM =====
  Widget _buildRowItem(Map<String, dynamic> row) {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final List<dynamic> columns = row['columns'] ?? [];
    final String rowType = row['row_type'] ?? 'BODY';
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
            // ปุ่มลบบรรทัด
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: 'ลบบรรทัด',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ยืนยันลบ'),
                    content: Text('ต้องการลบบรรทัดที่ $seqNo และคอลัมน์ทั้งหมดในบรรทัดนี้?'),
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
                    _showSuccess('ลบบรรทัดเรียบร้อย');
                  } catch (e) {
                    _showError('ลบไม่สำเร็จ: $e');
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
            const SizedBox(width: 8),
            // พื้นที่คอลัมน์
            Expanded(
              child: columns.isEmpty
                  ? Container(
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text('(ยังไม่มีคอลัมน์)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : _buildColumnsPreview(row['id'], row['row_seq_no'] ?? 0, columns),
            ),
            const SizedBox(width: 6),
            // ปุ่มเพิ่มคอลัมน์
            IconButton(
              icon: Icon(Icons.add_box_outlined, size: 22, color: Colors.deepOrange[900]),
              tooltip: 'เพิ่มคอลัมน์',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _showColumnDialog(row['id']),
            ),
          ],
        ),
      ),
    );
  }

  // ===== COLUMNS PREVIEW =====
  Widget _buildColumnsPreview(int rowId, int rowSeqNo, List<dynamic> columns) {
    final sorted = List<Map<String, dynamic>>.from(columns)
      ..sort((a, b) => (a['column_seq_no'] ?? 0).compareTo(b['column_seq_no'] ?? 0));

    return Row(
      children: sorted.map((col) {
        final int flex = col['column_flex'] ?? 1;
        final String colType = col['column_type'] ?? 'TEXT';
        final String? desc = col['description_thai'];
        final String? dataType = col['data_type'];
        final int offset = col['period_offset'] ?? 0;
        final String? formula = col['formula_text'];
        final int colSeqNo = col['column_seq_no'] ?? 0;
        final int indent = col['indent_level'] ?? 0;
        final String align = col['text_align'] ?? 'LEFT';
        final String ref = 'flex:$flex, R$rowSeqNo, C$colSeqNo';

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
            label = desc ?? colType;
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
