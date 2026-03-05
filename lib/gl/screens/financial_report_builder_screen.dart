import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import '../services/financial_report_builder_service.dart';

class FinancialReportBuilderScreen extends StatefulWidget {
  const FinancialReportBuilderScreen({super.key});

  @override
  State<FinancialReportBuilderScreen> createState() => _FinancialReportBuilderScreenState();
}

class _FinancialReportBuilderScreenState extends State<FinancialReportBuilderScreen> {
  final FinancialReportBuilderService _service = FinancialReportBuilderService();

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _selectedReport;
  bool _isLoadingReports = false;
  bool _isLoadingRows = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await _service.fetchReports();
      setState(() => _reports = reports);
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
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
  void _showRowDialog([Map<String, dynamic>? row]) {
    final isEdit = row != null;
    final seqCtrl = TextEditingController(text: isEdit ? (row['row_seq_no'] ?? '').toString() : '');
    String rowType = row?['row_type'] ?? 'BODY';
    String printControl = row?['print_control'] ?? 'SHOW';
    final accFromCtrl = TextEditingController(text: row?['account_from'] ?? '');
    final accToCtrl = TextEditingController(text: row?['account_to'] ?? '');
    String normalSign = row?['normal_sign'] ?? 'DEBIT';
    final branchCtrl = TextEditingController(text: (row?['branch_id'] ?? '').toString());
    final projectCtrl = TextEditingController(text: (row?['project_id'] ?? '').toString());
    final buCtrl = TextEditingController(text: (row?['business_unit_id'] ?? '').toString());

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
                    Expanded(child: TextField(controller: accFromCtrl, decoration: const InputDecoration(labelText: 'รหัสบัญชีต้น (account_from)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: accToCtrl, decoration: const InputDecoration(labelText: 'รหัสบัญชีปลาย (account_to)', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: normalSign,
                    decoration: const InputDecoration(labelText: 'เครื่องหมายปกติ (normal_sign)', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'DEBIT', child: Text('DEBIT (เดบิต)')),
                      DropdownMenuItem(value: 'CREDIT', child: Text('CREDIT (เครดิต)')),
                    ],
                    onChanged: (v) => setDialogState(() => normalSign = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: branchCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'branch_id (ว่างได้)', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: projectCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'project_id (ว่างได้)', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: buCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'business_unit_id (ว่างได้)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900], foregroundColor: Colors.white),
              onPressed: () async {
                final data = {
                  if (!isEdit) 'report_id': _selectedReport!['id'],
                  'row_seq_no': int.tryParse(seqCtrl.text) ?? 0,
                  'row_type': rowType,
                  'print_control': printControl,
                  'account_from': accFromCtrl.text.trim().isEmpty ? null : accFromCtrl.text.trim(),
                  'account_to': accToCtrl.text.trim().isEmpty ? null : accToCtrl.text.trim(),
                  'normal_sign': normalSign,
                  'branch_id': int.tryParse(branchCtrl.text),
                  'project_id': int.tryParse(projectCtrl.text),
                  'business_unit_id': int.tryParse(buCtrl.text),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างแบบงบการเงิน (Financial Report Builder)'),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
      ),
      body: ResizableContainer(
        direction: Axis.horizontal,
        children: [
          ResizableChild(
            size: const ResizableSize.ratio(0.35),
            child: _buildLeftPanel(),
          ),
          ResizableChild(
            child: _buildRightPanel(),
          ),
        ],
      ),
    );
  }

  // ===== LEFT PANEL =====
  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.deepOrange[900],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('รายการงบการเงิน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่ม'),
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
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            r['is_active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
                            style: TextStyle(fontSize: 11, color: r['is_active'] == true ? Colors.green : Colors.red),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('ลบ'),
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
              child: Text('$seqNo', style: TextStyle(color: Colors.deepOrange[900], fontWeight: FontWeight.bold, fontSize: 12)),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                      child: const Text('(ยังไม่มีคอลัมน์)', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: textAlignVal,
                ),
              ),
              Text(ref, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
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
