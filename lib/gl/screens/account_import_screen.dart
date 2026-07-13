import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/file_download.dart';
import '../models/account.dart';

class AccountImportScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;

  const AccountImportScreen({super.key, required this.onFieldsChanged});

  @override
  State<AccountImportScreen> createState() => _AccountImportScreenState();
}

class _AccountImportScreenState extends State<AccountImportScreen> {
  // File state
  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileExtension;

  // Template (loaded dynamically so it always matches the backend)
  List<Map<String, dynamic>> _templateColumns = [];
  List<Map<String, dynamic>> _accountTypes = [];
  List<Map<String, dynamic>> _dimensionTypes = [];

  // Validation result
  bool _isValidated = false;
  int _totalRows = 0;
  int _validRows = 0;
  int _errorRows = 0;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, dynamic>> _validatedData = [];

  bool _isLoading = false;
  bool _isImporting = false;

  final _previewScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _previewScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Template definition ─────────────────────────────────────────────────

  Future<void> _loadTemplate() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiGl}/gl_account/import/template'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _templateColumns = List<Map<String, dynamic>>.from(
              (data['sheet'] as Map<String, dynamic>?)?['columns'] ?? []);
          _accountTypes = List<Map<String, dynamic>>.from(data['accountTypes'] ?? []);
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
      _validatedData = [];
    });
  }

  // ─── Validate ───────────────────────────────────────────────────────────────

  Future<void> _validate() async {
    if (_fileBytes == null) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();

      final uri = Uri.parse('${AppConfig.apiGl}/gl_account/import/validate');
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
        setState(() {
          _isValidated = true;
          _totalRows = (data['totalRows'] as num).toInt();
          _validRows = (data['validRows'] as num).toInt();
          _errorRows = (data['errorRows'] as num).toInt();
          _errors = List<Map<String, dynamic>>.from(data['errors'] ?? []);
          _validatedData = List<Map<String, dynamic>>.from(data['data'] ?? []);
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
    if (_validatedData.isEmpty) return;
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการนำเข้า'),
        content: Text('ต้องการนำเข้าผังบัญชี $_validRows รายการใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(l.confirm, style: const TextStyle(color: Colors.white)),
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
        Uri.parse('${AppConfig.apiGl}/gl_account/import/confirm'),
        headers: headers,
        body: jsonEncode({'rows': _validatedData}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final imported = data['imported'] ?? 0;
        final skipped = data['skipped'] ?? 0;
        final errs = (data['errors'] as List?)?.length ?? 0;
        if (mounted) {
          _showSnack(
            'นำเข้าสำเร็จ $imported รายการ'
            '${skipped > 0 ? '  |  ข้ามรหัสซ้ำ $skipped รายการ' : ''}'
            '${errs > 0 ? '  |  ผิดพลาด $errs รายการ' : ''}',
          );
          setState(() {
            _fileName = null;
            _fileBytes = null;
            _isValidated = false;
            _errors = [];
            _validatedData = [];
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF303F9F),
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'เริ่มใหม่',
            onPressed: () => setState(() {
              _fileName = null;
              _fileBytes = null;
              _fileExtension = null;
              _isValidated = false;
              _totalRows = 0;
              _validRows = 0;
              _errorRows = 0;
              _errors = [];
              _validatedData = [];
              _isLoading = false;
              _isImporting = false;
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTemplateSection(),
          const SizedBox(height: 16),
          _buildFilePickerSection(),
          if (_isValidated) ...[
            const SizedBox(height: 16),
            _buildResultSection(),
          ],
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: _isValidated && _errorRows == 0 && _validRows > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _isImporting ? null : _confirmImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isImporting
                      ? 'กำลังนำเข้า...'
                      : 'ยืนยันนำเข้าผังบัญชี $_validRows รายการ'),
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
        Uri.parse('${AppConfig.apiGl}/gl_account/import/template/download'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await downloadFile(response.bodyBytes, 'gl_account_template.xlsx');
      } else {
        _showSnack('ดาวน์โหลดเทมเพลตไม่สำเร็จ (${response.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    }
  }

  Widget _buildTemplateSection() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF303F9F)),
        title: const Text('เทมเพลตนำเข้าข้อมูล', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('คลิกเพื่อดูรายละเอียดคอลัมน์และรหัสอ้างอิงที่ใช้ได้'),
        trailing: OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('ดาวน์โหลดเทมเพลต'),
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
              'เทมเพลตประกอบด้วย sheet "ผังบัญชี" 1 sheet ★ = จำเป็นต้องระบุ',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
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
              rows: _templateColumns
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
          const SizedBox(height: 8),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('รหัสอ้างอิงที่ใช้ได้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildReferenceWrap('ประเภทบัญชี (account_type)', _accountTypes),
              const SizedBox(height: 8),
              _buildReferenceWrap('รหัสมิติ (dim_required_types)', _dimensionTypes,
                  codeKey: 'type_code', labelKey: 'name_thai'),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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

  Widget _buildFilePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('เลือกไฟล์นำเข้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('รองรับไฟล์ .xlsx, .xls, .csv', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                  _fileName ?? 'ยังไม่ได้เลือกไฟล์',
                  style: TextStyle(color: _fileName != null ? Colors.black87 : Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('เลือกไฟล์'),
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
              label: const Text('ตรวจสอบ'),
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

  Widget _buildResultSection() {
    final allOk = _errorRows == 0;
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
                    ? 'ข้อมูลถูกต้องทั้งหมด พร้อมนำเข้า'
                    : 'พบข้อมูลไม่ถูกต้อง กรุณาแก้ไขไฟล์แล้วตรวจสอบใหม่',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: allOk ? Colors.green.shade800 : Colors.orange.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                'ทั้งหมด: $_totalRows รายการ'
                '   ถูกต้อง: $_validRows รายการ'
                '   ไม่ถูกต้อง: $_errorRows รายการ',
                style: const TextStyle(fontSize: 13),
              ),
            ]),
          ]),
        ),
      ),

      // Error table
      if (_errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('รายการที่ไม่ถูกต้อง',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
            columns: const [
              DataColumn(label: Text('แถวที่')),
              DataColumn(label: Text('รหัสบัญชี')),
              DataColumn(label: Text('คอลัมน์')),
              DataColumn(label: Text('ข้อผิดพลาด')),
            ],
            rows: [
              for (final e in _errors)
                for (final err in (e['errors'] as List))
                  DataRow(
                    color: WidgetStateProperty.all(Colors.red.shade50),
                    cells: [
                      DataCell(Text('${e['row']}')),
                      DataCell(Text(e['accountCode'] ?? '')),
                      DataCell(Text(err['column'] ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text(err['message'] ?? '')),
                    ],
                  ),
            ],
          ),
        ),
      ],

      // Valid data preview
      if (_validRows > 0) ...[
        const SizedBox(height: 16),
        Text(
          'ตัวอย่างข้อมูลที่จะนำเข้า${_validRows > 50 ? ' (แสดง 50 จาก $_validRows รายการ)' : ' ($_validRows รายการ)'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Scrollbar(
          controller: _previewScrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _previewScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
              columns: const [
                DataColumn(label: Text('รหัสบัญชี')),
                DataColumn(label: Text('รหัสบัญชีแม่')),
                DataColumn(label: Text('ชื่อบัญชี')),
                DataColumn(label: Text('ประเภทบัญชี')),
                DataColumn(label: Text('ยอดดุล')),
                DataColumn(label: Text('หัวบัญชี')),
                DataColumn(label: Text('คุมยอด')),
                DataColumn(label: Text('สกุลเงิน')),
                DataColumn(label: Text('มิติบังคับ')),
              ],
              rows: _validatedData
                  .take(50)
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r['account_code']?.toString() ?? '')),
                        DataCell(Text(_formatCellValue(r['parent_account_code']))),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(_buildAccountName(r), overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(accountTypeOptions[r['account_type']] ?? _formatCellValue(r['account_type']))),
                        DataCell(Text(_formatCellValue(r['normal_balance']))),
                        DataCell(Text(_formatCellValue(r['is_normal_account']))),
                        DataCell(Text(_formatCellValue(r['is_control_account']))),
                        DataCell(Text(_formatCellValue(r['currency_code']))),
                        DataCell(Text(_buildDimRequiredText(r))),
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

  String _buildDimRequiredText(Map<String, dynamic> r) {
    final dimRules = r['dim_rules'] as List? ?? [];
    if (dimRules.isEmpty) return '-';
    return dimRules.map((d) => (d as Map<String, dynamic>)['type_code']?.toString() ?? '').join(', ');
  }

  String _formatCellValue(dynamic val) {
    if (val == null) return '';
    if (val is bool) return val ? 'ใช่' : 'ไม่ใช่';
    if (val is List) return val.join(', ');
    return val.toString();
  }
}
