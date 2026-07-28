import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/file_download.dart';

class GlOpeningBalanceImportScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;

  const GlOpeningBalanceImportScreen({super.key, required this.onFieldsChanged});

  @override
  State<GlOpeningBalanceImportScreen> createState() => _GlOpeningBalanceImportScreenState();
}

class _GlOpeningBalanceImportScreenState extends State<GlOpeningBalanceImportScreen> {
  // File state
  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileExtension;

  // Template (loaded dynamically so it always matches the backend)
  List<Map<String, dynamic>> _headerColumns = [];
  List<Map<String, dynamic>> _detailColumns = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _dimensionTypes = [];

  // Validation result
  bool _isValidated = false;
  int _totalHeaders = 0;
  int _validHeaders = 0;
  int _errorHeaders = 0;
  int _totalDetailRows = 0;
  int _validDetailRows = 0;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, dynamic>> _validatedHeaders = [];
  List<Map<String, dynamic>> _validatedDetails = [];

  bool _isLoading = false;
  bool _isImporting = false;

  final _headerPreviewScrollCtrl = ScrollController();
  final _detailPreviewScrollCtrl = ScrollController();

  final _amountFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _headerPreviewScrollCtrl.dispose();
    _detailPreviewScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Template definition ─────────────────────────────────────────────────

  Future<void> _loadTemplate() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiGl}/gl_opening_balance/import/template'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        final sheets = data['sheets'] as Map<String, dynamic>? ?? {};
        setState(() {
          _headerColumns = List<Map<String, dynamic>>.from(
              (sheets['header'] as Map<String, dynamic>?)?['columns'] ?? []);
          _detailColumns = List<Map<String, dynamic>>.from(
              (sheets['detail'] as Map<String, dynamic>?)?['columns'] ?? []);
          _branches = List<Map<String, dynamic>>.from(data['branches'] ?? []);
          _currencies = List<Map<String, dynamic>>.from(data['currencies'] ?? []);
          _dimensionTypes = List<Map<String, dynamic>>.from(data['dimensionTypes'] ?? []);
        });
      }
    } catch (_) {
      // ไม่เป็นไร — การดาวน์โหลดเทมเพลตยังทำงานได้แม้โหลดรายละเอียดคอลัมน์ไม่สำเร็จ
    }
  }

  // ─── File picker ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _fileName = file.name;
      _fileBytes = file.bytes;
      _fileExtension = file.extension?.toLowerCase();
      _isValidated = false;
      _errors = [];
      _validatedHeaders = [];
      _validatedDetails = [];
    });
  }

  // ─── Validate ───────────────────────────────────────────────────────────────

  Future<void> _validate() async {
    if (_fileBytes == null) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();

      final uri = Uri.parse('${AppConfig.apiGl}/gl_opening_balance/import/validate');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      final mimeType = _fileExtension == 'csv'
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _fileBytes!,
        filename: _fileName!,
        contentType: MediaType.parse(mimeType),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          _isValidated = true;
          _totalHeaders = (data['totalHeaders'] as num? ?? 0).toInt();
          _validHeaders = (data['validHeaders'] as num? ?? 0).toInt();
          _errorHeaders = (data['errorHeaders'] as num? ?? 0).toInt();
          _totalDetailRows = (data['totalDetailRows'] as num? ?? 0).toInt();
          _validDetailRows = (data['validDetailRows'] as num? ?? 0).toInt();
          _errors = List<Map<String, dynamic>>.from(data['errors'] ?? []);
          _validatedHeaders = List<Map<String, dynamic>>.from(result['headers'] ?? []);
          _validatedDetails = List<Map<String, dynamic>>.from(result['details'] ?? []);
        });
      } else {
        final body = jsonDecode(response.body);
        _showSnack(body['message'] ?? 'เกิดข้อผิดพลาด', isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Confirm import ─────────────────────────────────────────────────────────

  Future<void> _confirmImport() async {
    if (_validatedHeaders.isEmpty) return;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Import' : 'ยืนยันการนำเข้า'),
        content: Text(isEnglish
            ? 'Import $_validHeaders opening balance documents (total $_totalDetailRows lines)?'
            : 'ต้องการนำเข้ายอดยกมา $_validHeaders เอกสาร (รวม $_totalDetailRows บรรทัด) ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isEnglish ? 'Confirm' : 'ยืนยัน', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse('${AppConfig.apiGl}/gl_opening_balance/import/confirm'),
        headers: headers,
        body: jsonEncode({'headers': _validatedHeaders, 'details': _validatedDetails}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final imported = data['imported'] ?? 0;
        final skipped = data['skipped'] ?? 0;
        final errs = (data['errors'] as List?)?.length ?? 0;
        if (mounted) {
          _showSnack(
            'นำเข้าสำเร็จ $imported เอกสาร'
            '${skipped > 0 ? '  |  ข้าม $skipped เอกสาร' : ''}'
            '${errs > 0 ? '  |  ผิดพลาด $errs เอกสาร' : ''}',
          );
          setState(() {
            _fileName = null;
            _fileBytes = null;
            _isValidated = false;
            _errors = [];
            _validatedHeaders = [];
            _validatedDetails = [];
          });
          widget.onFieldsChanged();
        }
      } else {
        String errMsg = 'เกิดข้อผิดพลาด (${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          errMsg = body['message'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        _showSnack(errMsg, isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF303F9F),
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Reset' : 'เริ่มใหม่',
            onPressed: () => setState(() {
              _fileName = null;
              _fileBytes = null;
              _fileExtension = null;
              _isValidated = false;
              _totalHeaders = 0;
              _validHeaders = 0;
              _errorHeaders = 0;
              _totalDetailRows = 0;
              _validDetailRows = 0;
              _errors = [];
              _validatedHeaders = [];
              _validatedDetails = [];
              _isLoading = false;
              _isImporting = false;
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTemplateSection(isEnglish),
          const SizedBox(height: 16),
          _buildFilePickerSection(isEnglish),
          if (_isValidated) ...[
            const SizedBox(height: 16),
            _buildResultSection(isEnglish),
          ],
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: _isValidated && _errorHeaders == 0 && _validHeaders > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: (_isImporting || !(MenuScope.of(context)?.canCreate ?? true))
                      ? null
                      : _confirmImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isImporting
                      ? (isEnglish ? 'Importing...' : 'กำลังนำเข้า...')
                      : (isEnglish ? 'Confirm Import $_validHeaders Documents' : 'ยืนยันนำเข้ายอดยกมา $_validHeaders เอกสาร')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ─── Template section ────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiGl}/gl_opening_balance/import/template/download'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await downloadFile(response.bodyBytes, 'gl_opening_balance_template.xlsx');
      } else {
        _showSnack('ดาวน์โหลดเทมเพลตไม่สำเร็จ (${response.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    }
  }

  Widget _buildTemplateSection(bool isEnglish) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF303F9F)),
        title: Text(isEnglish ? 'Import Template' : 'เทมเพลตนำเข้าข้อมูล', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isEnglish ? 'Click to see column details and available reference codes' : 'คลิกเพื่อดูรายละเอียดคอลัมน์และรหัสอ้างอิงที่ใช้ได้'),
        trailing: OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: Text(isEnglish ? 'Download Template' : 'ดาวน์โหลดเทมเพลต'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF303F9F),
            side: const BorderSide(color: Color(0xFF303F9F)),
          ),
        ),
        initiallyExpanded: false,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'เทมเพลตประกอบด้วย 2 sheet คือ "header" (1 แถว = 1 เอกสาร) และ "detail" (รายการย่อยของเอกสาร)\n'
              'เชื่อมโยงกันด้วยคอลัมน์ header_ref   ★ = จำเป็นต้องระบุ',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          _buildColumnsTable('sheet "header"', _headerColumns),
          const SizedBox(height: 8),
          _buildColumnsTable('sheet "detail"', _detailColumns),
          const SizedBox(height: 8),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('รหัสอ้างอิงที่ใช้ได้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildReferenceWrap('สาขา (branch_code)', _branches),
              const SizedBox(height: 8),
              _buildReferenceWrap('สกุลเงิน (currency_code)', _currencies),
              for (final dt in _dimensionTypes) ...[
                const SizedBox(height: 8),
                _buildReferenceWrap(
                  '${dt['label']} (dim_${dt['type_code']})',
                  List<Map<String, dynamic>>.from(dt['values'] ?? []),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildColumnsTable(String title, List<Map<String, dynamic>> columns) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DataTable(
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
          columns: const [
            DataColumn(label: Text('ชื่อ Header', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ความหมาย', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('จำเป็น', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ตัวอย่าง', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: columns
              .map((col) => DataRow(cells: [
                    DataCell(Text(col['key']?.toString() ?? '',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    DataCell(Text(col['label']?.toString() ?? '')),
                    DataCell((col['required'] as bool? ?? false)
                        ? const Icon(Icons.star, color: Colors.red, size: 14)
                        : const Text('-', style: TextStyle(color: Colors.grey))),
                    DataCell(Text(col['example']?.toString() ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12))),
                  ]))
              .toList(),
        ),
      ),
    ]);
  }

  Widget _buildReferenceWrap(String title, List<Map<String, dynamic>> items,
      {String codeKey = 'code', String labelKey = 'label'}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map((item) => Chip(
                  label: Text(
                    '${item[codeKey]} - ${item[labelKey]}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: const Color(0xFFE8EAF6),
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    ]);
  }

  // ─── File picker section ────────────────────────────────────────────────────

  Widget _buildFilePickerSection(bool isEnglish) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEnglish ? 'Select Import File' : 'เลือกไฟล์นำเข้า', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(isEnglish ? 'Supports .xlsx, .xls, .csv' : 'รองรับไฟล์ .xlsx, .xls, .csv', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade50,
                ),
                child: Text(
                  _fileName ?? (isEnglish ? 'No file selected' : 'ยังไม่ได้เลือกไฟล์'),
                  style: TextStyle(color: _fileName != null ? Colors.black87 : Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text(isEnglish ? 'Browse' : 'เลือกไฟล์'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _fileBytes == null || _isLoading ? null : _validate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.fact_check_outlined),
              label: Text(isEnglish ? 'Validate' : 'ตรวจสอบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF303F9F),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ─── Validation result section ──────────────────────────────────────────────

  Widget _buildResultSection(bool isEnglish) {
    final allOk = _errorHeaders == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary
      Card(
        color: allOk ? Colors.green.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(
              allOk ? Icons.check_circle : Icons.warning_amber_rounded,
              color: allOk ? Colors.green.shade700 : Colors.orange.shade700,
              size: 36,
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                allOk
                    ? (isEnglish ? 'All data is valid — ready to import' : 'ข้อมูลถูกต้องทั้งหมด พร้อมนำเข้า')
                    : (isEnglish ? 'Invalid data found. Please fix the file and re-validate.' : 'พบข้อมูลไม่ถูกต้อง กรุณาแก้ไขไฟล์แล้วตรวจสอบใหม่'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: allOk ? Colors.green.shade800 : Colors.orange.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                isEnglish
                    ? 'Total: $_totalHeaders   Valid: $_validHeaders   Invalid: $_errorHeaders'
                    : 'เอกสารทั้งหมด: $_totalHeaders   ถูกต้อง: $_validHeaders   ไม่ถูกต้อง: $_errorHeaders',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                isEnglish
                    ? 'Detail rows total: $_totalDetailRows   Valid: $_validDetailRows'
                    : 'รายการ (detail) ทั้งหมด: $_totalDetailRows   ถูกต้อง: $_validDetailRows',
                style: const TextStyle(fontSize: 13),
              ),
            ]),
          ]),
        ),
      ),

      // Error table
      if (_errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(isEnglish ? 'Invalid rows' : 'รายการที่ไม่ถูกต้อง',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
            columns: const [
              DataColumn(label: Text('Sheet')),
              DataColumn(label: Text('แถวที่')),
              DataColumn(label: Text('เลขอ้างอิง')),
              DataColumn(label: Text('คอลัมน์')),
              DataColumn(label: Text('ข้อผิดพลาด')),
            ],
            rows: [
              for (final e in _errors)
                for (final err in (e['errors'] as List))
                  DataRow(
                    color: WidgetStateProperty.all(Colors.red.shade50),
                    cells: [
                      DataCell(Text(e['sheet']?.toString() ?? '')),
                      DataCell(Text('${e['row']}')),
                      DataCell(Text(e['ref']?.toString() ?? '')),
                      DataCell(Text(err['column'] ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text(err['message'] ?? '')),
                    ],
                  ),
            ],
          ),
        ),
      ],

      // Header preview
      if (_validHeaders > 0) ...[
        const SizedBox(height: 16),
        Text(
          isEnglish
              ? 'Document preview (header)${_validHeaders > 50 ? ' (showing 50 of $_validHeaders)' : ' ($_validHeaders documents)'}'
              : 'ตัวอย่างเอกสาร (header)${_validHeaders > 50 ? ' (แสดง 50 จาก $_validHeaders เอกสาร)' : ' ($_validHeaders เอกสาร)'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Scrollbar(
          controller: _headerPreviewScrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _headerPreviewScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
              columns: [
                DataColumn(label: Text(isEnglish ? 'Ref No.' : 'เลขอ้างอิง')),
                DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร')),
                DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
                DataColumn(label: Text(isEnglish ? 'Branch' : 'สาขา')),
                DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
                DataColumn(label: Text(isEnglish ? 'Description' : 'คำอธิบาย')),
                DataColumn(label: Text(isEnglish ? 'Total Debit' : 'รวมเดบิต'), numeric: true),
                DataColumn(label: Text(isEnglish ? 'Total Credit' : 'รวมเครดิต'), numeric: true),
              ],
              rows: _validatedHeaders
                  .take(50)
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r['header_ref']?.toString() ?? '')),
                        DataCell(Text(r['doc_no']?.toString() ?? (isEnglish ? '(auto)' : '(อัตโนมัติ)'))),
                        DataCell(Text(r['doc_date']?.toString() ?? '')),
                        DataCell(Text(r['branch_code']?.toString() ?? '-')),
                        DataCell(Text(r['currency_code']?.toString() ?? '')),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(r['description']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(_amountFormat.format(
                            (r['total_debit_fc'] as num?)?.toDouble() ?? 0))),
                        DataCell(Text(_amountFormat.format(
                            (r['total_credit_fc'] as num?)?.toDouble() ?? 0))),
                      ]))
                  .toList(),
            ),
          ),
        ),
      ],

      // Detail preview
      if (_validatedDetails.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          isEnglish
              ? 'Line preview (detail)${_validatedDetails.length > 50 ? ' (showing 50 of ${_validatedDetails.length})' : ' (${_validatedDetails.length} rows)'}'
              : 'ตัวอย่างรายการ (detail)${_validatedDetails.length > 50 ? ' (แสดง 50 จาก ${_validatedDetails.length} รายการ)' : ' (${_validatedDetails.length} รายการ)'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Scrollbar(
          controller: _detailPreviewScrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _detailPreviewScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
              columns: [
                DataColumn(label: Text(isEnglish ? 'Ref No.' : 'เลขอ้างอิง')),
                DataColumn(label: Text(isEnglish ? 'Account Code' : 'รหัสบัญชี')),
                DataColumn(label: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี')),
                DataColumn(label: Text(isEnglish ? 'Description' : 'คำอธิบาย')),
                DataColumn(label: Text(isEnglish ? 'Debit' : 'เดบิต'), numeric: true),
                DataColumn(label: Text(isEnglish ? 'Credit' : 'เครดิต'), numeric: true),
                for (final dt in _dimensionTypes)
                  DataColumn(label: Text(dt['label']?.toString() ?? dt['type_code'].toString())),
              ],
              rows: _validatedDetails
                  .take(50)
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r['header_ref']?.toString() ?? '')),
                        DataCell(Text(r['account_code']?.toString() ?? '')),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(_buildAccountName(r), overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(r['description']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(_amountFormat.format((r['debit_fc'] as num?)?.toDouble() ?? 0))),
                        DataCell(Text(_amountFormat.format((r['credit_fc'] as num?)?.toDouble() ?? 0))),
                        for (final dt in _dimensionTypes)
                          DataCell(Text(
                              ((r['dim_labels'] as Map?)?[dt['type_code']]?.toString()) ?? '-')),
                      ]))
                  .toList(),
            ),
          ),
        ),
      ],
    ]);
  }

  String _buildAccountName(Map<String, dynamic> r) {
    final nameThai = r['account_name_thai']?.toString() ?? '';
    final nameEng = r['account_name_eng']?.toString() ?? '';
    return nameEng.trim().isNotEmpty ? '$nameThai - $nameEng' : nameThai;
  }
}
