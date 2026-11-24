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

class ImItemImportScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;

  const ImItemImportScreen({super.key, required this.onFieldsChanged});

  @override
  State<ImItemImportScreen> createState() => _ImItemImportScreenState();
}

class _ImItemImportScreenState extends State<ImItemImportScreen> {
  bool _isEnglish = false;
  // File state
  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileExtension;

  // Template (loaded dynamically so it always matches the backend)
  List<Map<String, dynamic>> _templateSheets = [];

  // Validation result
  bool _isValidated = false;
  int _totalRows = 0;
  int _validRows = 0;
  int _errorRows = 0;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, dynamic>> _validatedData = [];

  bool _isLoading = false;
  bool _isImporting = false;

  // การตั้งค่ารหัสอัตโนมัติ (จาก template) — null = ยังโหลดไม่ได้ ไม่แสดงคำเตือน
  bool? _autoNumbering;
  List<String> _autoGroupCodes = [];

  final _previewScrollCtrl = ScrollController();

  static const _appColor = Colors.teal;

  @override
  void initState() {
    super.initState();
    _loadTemplateSheets();
  }

  @override
  void dispose() {
    _previewScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Template definition ─────────────────────────────────────────────────

  Future<void> _loadTemplateSheets() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiIm}/im_item/import/template'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _templateSheets = List<Map<String, dynamic>>.from(data['sheets'] ?? []);
          _autoNumbering = data['auto_numbering'] == true;
          _autoGroupCodes = List<String>.from((data['auto_group_codes'] ?? []).map((e) => e.toString()));
        });
      }
    } catch (_) {}
  }

  // ─── File picker ──────────────────────────────────────────────────────────

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

  // ─── Validate ─────────────────────────────────────────────────────────────

  Future<void> _validate() async {
    if (_fileBytes == null) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();

      final uri = Uri.parse('${AppConfig.apiIm}/im_item/import/validate');
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
        _showSnack(body['message'] ?? (_isEnglish ? 'An error occurred' : 'เกิดข้อผิดพลาด'), isError: true);
      }
    } catch (e) {
      _showSnack((_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Confirm import ───────────────────────────────────────────────────────

  Future<void> _confirmImport() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_validatedData.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((_isEnglish ? 'Confirm import' : 'ยืนยันการนำเข้า')),
        content: Text((_isEnglish ? 'Import $_validRows items?' : 'ต้องการนำเข้าข้อมูลสินค้า $_validRows รายการใช่หรือไม่?')),
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
        Uri.parse('${AppConfig.apiIm}/im_item/import/confirm'),
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
            _isEnglish
                ? 'Imported $imported rows'
                  '${skipped > 0 ? '  |  skipped $skipped duplicate codes' : ''}'
                  '${errs > 0 ? '  |  $errs errors' : ''}'
                : 'นำเข้าสำเร็จ $imported รายการ'
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
        String errMsg = (_isEnglish ? 'Error (${response.statusCode})' : 'เกิดข้อผิดพลาด (${response.statusCode})');
        try {
          final body = jsonDecode(response.body);
          errMsg = body['message'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        _showSnack(errMsg, isError: true);
      }
    } catch (e) {
      _showSnack((_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), isError: true);
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _appColor.shade700,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: (_isEnglish ? 'Start over' : 'เริ่มใหม่'),
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
      body: Column(children: [
        if (_autoNumbering != null) _buildCodeModeBanner(),
        Expanded(
          child: SingleChildScrollView(
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
        ),
      ]),
      bottomNavigationBar: _isValidated && _errorRows == 0 && _validRows > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: (_isImporting || !(MenuScope.of(context)?.canCreate ?? true))
                      ? null
                      : _confirmImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isImporting
                      ? (_isEnglish ? 'Importing...' : 'กำลังนำเข้า...')
                      : (_isEnglish ? 'Confirm import of $_validRows rows' : 'ยืนยันนำเข้าข้อมูล $_validRows รายการ')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ─── Template section ─────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiIm}/im_item/import/template/download?lang=${_isEnglish ? 'en' : 'th'}'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await downloadFile(response.bodyBytes, 'im_item_template.xlsx');
      } else {
        _showSnack((_isEnglish ? 'Template download failed (${response.statusCode})' : 'ดาวน์โหลดเทมเพลตไม่สำเร็จ (${response.statusCode})'), isError: true);
      }
    } catch (e) {
      _showSnack((_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), isError: true);
    }
  }

  Widget _buildTemplateSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.table_chart_outlined, color: _appColor.shade700),
        title: Text((_isEnglish ? 'Import template' : 'เทมเพลตนำเข้าข้อมูล'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text((_isEnglish ? 'Click to see the columns of each sheet' : 'คลิกเพื่อดูรายละเอียดคอลัมน์ในแต่ละ sheet')),
        trailing: OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: Text((_isEnglish ? 'Download template' : 'ดาวน์โหลดเทมเพลต')),
          style: OutlinedButton.styleFrom(
            foregroundColor: _appColor.shade700,
            side: BorderSide(color: _appColor.shade700),
          ),
        ),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _isEnglish
                  ? 'The template has 5 sheets by item data topic (including "ตารางราคา" / Price list to set starting prices for the imported items). '
                      'Every sheet (except "ข้อมูลพื้นฐาน" / General) uses the "old_item_code" column to link to its row in the "ข้อมูลพื้นฐาน" sheet\n'
                      '"ตารางราคา" must use a price list code that already exists (no new price list is created), and the unit (if given) must be the item\'s base or alternate unit\n'
                      '★ = required'
                  : 'เทมเพลตประกอบด้วย 5 sheet ตามหัวข้อข้อมูลสินค้า (รวม "ตารางราคา" สำหรับตั้งราคาตั้งต้นให้สินค้าที่นำเข้า) '
              'ทุก sheet (ยกเว้น "ข้อมูลพื้นฐาน") ใช้คอลัมน์ "old_item_code" (รหัสสินค้าเก่า) เป็นตัวเชื่อมข้อมูลกับแถวใน sheet "ข้อมูลพื้นฐาน"\n'
              '"ตารางราคา" ต้องระบุรหัสตารางราคาที่มีอยู่แล้วในระบบ (ไม่สร้างตารางราคาใหม่) และหน่วยนับ (ถ้าระบุ) ต้องเป็นหน่วยหลักหรือหน่วยทางเลือกของสินค้านั้นเท่านั้น\n'
              '★ = จำเป็นต้องระบุ',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          for (final sheet in _templateSheets) _buildTemplateSheetTile(sheet),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTemplateSheetTile(Map<String, dynamic> sheet) {
    final columns = List<Map<String, dynamic>>.from(sheet['columns'] ?? []);
    return ExpansionTile(
      title: Text((_isEnglish ? (sheet['name_en'] ?? sheet['name']) : sheet['name'])?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            columns: [
              DataColumn(label: Text((_isEnglish ? 'Header name' : 'ชื่อ Header'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text((_isEnglish ? 'Meaning' : 'ความหมาย'),   style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text((_isEnglish ? 'Required' : 'จำเป็น'),      style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text((_isEnglish ? 'Example' : 'ตัวอย่าง'),   style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: columns
                .map((col) => DataRow(cells: [
                      DataCell(Text(col['key']?.toString() ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text((_isEnglish ? (col['label_en'] ?? col['label']) : col['label'])?.toString() ?? '')),
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
      ],
    );
  }

  // ─── Code mode banner ───────────────────────────────────────────────────────

  // คำเตือนใต้ AppBar: รหัสสินค้าใหม่มาจากไหน ตามการตั้งค่ารหัสอัตโนมัติ
  Widget _buildCodeModeBanner() {
    final auto = _autoNumbering == true;
    final text = auto
        ? (_isEnglish ? 'New codes are auto-numbered, but the old code is kept as well' : 'รหัสใหม่อัตโนมัติ แต่ระบบยังเก็บรหัสเก่าไว้ให้ด้วย')
        : (_isEnglish
            ? 'New codes are the same as the old codes; rows without an old code cannot be imported'
            : 'ใช้รหัสใหม่เหมือนรหัสเก่า ถ้าไม่ระบุรหัสเก่า จะนำข้อมูลเข้าไม่ได้');
    final groupNote = !auto && _autoGroupCodes.isNotEmpty
        ? (_isEnglish
            ? '\n(except auto-numbered item categories: ${_autoGroupCodes.join(', ')})'
            : '\n(ยกเว้นหมวดหมู่สินค้าที่ตั้งรหัสอัตโนมัติ: ${_autoGroupCodes.join(', ')})')
        : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: auto ? Colors.blue.shade50 : Colors.orange.shade50,
      child: Row(children: [
        Icon(auto ? Icons.info_outline : Icons.warning_amber_rounded,
            color: auto ? Colors.blue.shade700 : Colors.orange.shade800),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$text$groupNote',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: auto ? Colors.blue.shade900 : Colors.orange.shade900)),
        ),
      ]),
    );
  }

  // ─── File picker section ──────────────────────────────────────────────────

  Widget _buildFilePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((_isEnglish ? 'Select import file' : 'เลือกไฟล์นำเข้า'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text((_isEnglish ? 'Supports .xlsx, .xls, .csv files' : 'รองรับไฟล์ .xlsx, .xls, .csv'),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                  _fileName ?? (_isEnglish ? 'No file selected' : 'ยังไม่ได้เลือกไฟล์'),
                  style: TextStyle(
                      color: _fileName != null ? Colors.black87 : Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text((_isEnglish ? 'Select file' : 'เลือกไฟล์')),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _fileBytes == null || _isLoading ? null : _validate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.fact_check_outlined),
              label: Text((_isEnglish ? 'Validate' : 'ตรวจสอบ')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _appColor.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ─── Validation result section ────────────────────────────────────────────

  Widget _buildResultSection() {
    final allOk = _errorRows == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    ? (_isEnglish ? 'All data is valid and ready to import' : 'ข้อมูลถูกต้องทั้งหมด พร้อมนำเข้า')
                    : (_isEnglish ? 'Invalid data found. Please fix the file and validate again' : 'พบข้อมูลไม่ถูกต้อง กรุณาแก้ไขไฟล์แล้วตรวจสอบใหม่'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: allOk ? Colors.green.shade800 : Colors.orange.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                _isEnglish
                    ? 'Total: $_totalRows rows   Valid: $_validRows rows   Invalid: $_errorRows rows'
                    : 'ทั้งหมด: $_totalRows รายการ   ถูกต้อง: $_validRows รายการ   ไม่ถูกต้อง: $_errorRows รายการ',
                style: const TextStyle(fontSize: 13),
              ),
            ]),
          ]),
        ),
      ),

      if (_errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text((_isEnglish ? 'Invalid rows' : 'รายการที่ไม่ถูกต้อง'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
            columns: [
              DataColumn(label: Text((_isEnglish ? 'Row' : 'แถวที่'))),
              DataColumn(label: Text((_isEnglish ? 'Item code' : 'รหัสสินค้า'))),
              DataColumn(label: Text((_isEnglish ? 'Column' : 'คอลัมน์'))),
              DataColumn(label: Text((_isEnglish ? 'Error' : 'ข้อผิดพลาด'))),
            ],
            rows: [
              for (final e in _errors)
                for (final err in (e['errors'] as List))
                  DataRow(
                    color: WidgetStateProperty.all(Colors.red.shade50),
                    cells: [
                      DataCell(Text('${e['row']}')),
                      DataCell(Text(e['itemCode'] ?? '')),
                      DataCell(Text(err['column'] ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text(err['message'] ?? '')),
                    ],
                  ),
            ],
          ),
        ),
      ],

      if (_validRows > 0) ...[
        const SizedBox(height: 16),
        Text(
          _isEnglish
              ? 'Preview of data to import${_validRows > 50 ? ' (showing 50 of $_validRows rows)' : ' ($_validRows rows)'}'
              : 'ตัวอย่างข้อมูลที่จะนำเข้า${_validRows > 50 ? ' (แสดง 50 จาก $_validRows รายการ)' : ' ($_validRows รายการ)'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text((_isEnglish ? 'Click a row to see all item details' : 'คลิกแถวเพื่อดูรายละเอียดทุกหัวข้อของสินค้า'),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Scrollbar(
          controller: _previewScrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _previewScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
              columns: [
                DataColumn(label: Text((_isEnglish ? 'Item code' : 'รหัสสินค้า'))),
                DataColumn(label: Text((_isEnglish ? 'Category' : 'หมวดหมู่'))),
                DataColumn(label: Text((_isEnglish ? 'Name (Thai)' : 'ชื่อ (ไทย)'))),
                DataColumn(label: Text((_isEnglish ? 'Name (English)' : 'ชื่อ (อังกฤษ)'))),
                DataColumn(label: Text((_isEnglish ? 'Item type' : 'ประเภทสินค้า'))),
                DataColumn(label: Text((_isEnglish ? 'Base unit' : 'หน่วยนับหลัก'))),
                DataColumn(label: Text((_isEnglish ? 'Default warehouse' : 'คลังตั้งต้น'))),
                DataColumn(label: Text((_isEnglish ? 'Active' : 'ใช้งาน'))),
              ],
              rows: _validatedData
                  .take(50)
                  .map((r) => DataRow(
                        onSelectChanged: (_) => _showItemDetailDialog(r),
                        cells: [
                          DataCell(Text(r['item_code']?.toString() ?? (_isEnglish ? '(auto)' : '(อัตโนมัติ)'))),
                          DataCell(Text(_fmt(r['category_code']))),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(r['item_name_th']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(r['item_name_en']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(Text(_fmt(r['item_type']))),
                          DataCell(Text(_fmt(r['base_uom_code']))),
                          DataCell(Text(_fmt(r['default_warehouse_code']))),
                          DataCell(Text(_fmt(r['is_active']))),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    ]);
  }

  // ─── Item detail dialog (tabbed, per im_item_detail_widget sections) ─────

  List<List<String>> get _uomConversionColumns => [
    ['uom_code', (_isEnglish ? 'Unit' : 'หน่วยนับ')],
    ['conversion_factor', (_isEnglish ? 'Conversion factor' : 'อัตราแปลง')],
    ['barcode', (_isEnglish ? 'Barcode' : 'บาร์โค้ด')],
    ['is_purchase_default', (_isEnglish ? 'Default purchase unit' : 'หน่วยซื้อตั้งต้น')],
    ['is_sales_default', (_isEnglish ? 'Default sales unit' : 'หน่วยขายตั้งต้น')],
    ['is_production_default', (_isEnglish ? 'Default production unit' : 'หน่วยผลิตตั้งต้น')],
    ['is_count_default', (_isEnglish ? 'Default count unit' : 'หน่วยตรวจนับตั้งต้น')],
    ['is_report_default', (_isEnglish ? 'Default report unit' : 'หน่วยรายงานตั้งต้น')],
    ['allow_purchase', (_isEnglish ? 'Purchasing' : 'ใช้ซื้อ')],
    ['allow_sales', (_isEnglish ? 'Sales' : 'ใช้ขาย')],
    ['allow_production', (_isEnglish ? 'Production' : 'ใช้ผลิต')],
  ];

  List<List<String>> get _itemWarehouseColumns => [
    ['warehouse_code', (_isEnglish ? 'Warehouse' : 'คลังสินค้า')],
    ['min_stock_qty', (_isEnglish ? 'Minimum stock' : 'สต็อกขั้นต่ำ')],
    ['max_stock_qty', (_isEnglish ? 'Maximum stock' : 'สต็อกสูงสุด')],
    ['reorder_point', (_isEnglish ? 'Reorder point' : 'จุดสั่งซื้อ')],
    ['location_code', (_isEnglish ? 'Location' : 'ตำแหน่งจัดเก็บ')],
  ];

  List<List<String>> get _priceListColumns => [
    ['price_list_code', (_isEnglish ? 'Price list code' : 'รหัสตารางราคา')],
    ['uom_code', (_isEnglish ? 'Unit' : 'หน่วยนับ')],
    ['min_qty', (_isEnglish ? 'Minimum qty' : 'จำนวนขั้นต่ำ')],
    ['unit_price_fc', (_isEnglish ? 'Unit price' : 'ราคาต่อหน่วย')],
    ['price_type', (_isEnglish ? 'Price type' : 'ชนิดราคา')],
    ['effective_from', (_isEnglish ? 'Effective from' : 'มีผลตั้งแต่')],
    ['effective_to', (_isEnglish ? 'Effective to' : 'มีผลถึง')],
  ];

  void _showItemDetailDialog(Map<String, dynamic> row) {
    final tabLabels = [
      (_isEnglish ? 'General' : 'ข้อมูลพื้นฐาน'),
      (_isEnglish ? 'Alternate units' : 'หน่วยนับทางเลือก'),
      (_isEnglish ? 'Warehouse' : 'คลังสินค้า'),
      (_isEnglish ? 'GL accounts' : 'บัญชี GL'),
      (_isEnglish ? 'Price list' : 'ตารางราคา'),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.9,
            child: DefaultTabController(
              length: tabLabels.length,
              child: Column(children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: _appColor.shade700,
                  foregroundColor: Colors.white,
                  title: Text(
                    '${row['item_code']?.toString() ?? (_isEnglish ? '(auto)' : '(อัตโนมัติ)')} - ${row['item_name_th']?.toString() ?? ''}',
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: tabLabels.map((l) => Tab(text: l)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _buildGeneralTab(row),
                    _buildListTable(row['uom_conversions'] as List? ?? [], _uomConversionColumns),
                    _buildListTable(row['item_warehouses'] as List? ?? [], _itemWarehouseColumns),
                    _buildGlAccountTab(row),
                    _buildListTable(row['price_lines'] as List? ?? [], _priceListColumns),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneralTab(Map<String, dynamic> row) {
    final items = <List<String>>[
      [(_isEnglish ? 'Item code' : 'รหัสสินค้า'), row['item_code']?.toString() ?? '(อัตโนมัติ)'],
      [(_isEnglish ? 'Category' : 'หมวดหมู่'), _fmt(row['category_code'])],
      [(_isEnglish ? 'Old code' : 'รหัสเก่า'), _fmt(row['old_item_code'])],
      [(_isEnglish ? 'Name (Thai)' : 'ชื่อ (ไทย)'), _fmt(row['item_name_th'])],
      [(_isEnglish ? 'Name (English)' : 'ชื่อ (อังกฤษ)'), _fmt(row['item_name_en'])],
      [(_isEnglish ? 'Barcode' : 'บาร์โค้ด'), _fmt(row['barcode'])],
      [(_isEnglish ? 'Description' : 'คำอธิบาย'), _fmt(row['description'])],
      [(_isEnglish ? 'Item type' : 'ประเภทสินค้า'), _fmt(row['item_type'])],
      [(_isEnglish ? 'Base unit' : 'หน่วยนับหลัก'), _fmt(row['base_uom_code'])],
      [(_isEnglish ? 'Costing method' : 'วิธีคำนวณต้นทุน'), _fmt(row['costing_method'])],
      [(_isEnglish ? 'Inventory accounting mode' : 'โหมดบัญชีสินค้า'), _fmt(row['accounting_mode'])],
      [(_isEnglish ? 'Standard cost' : 'ต้นทุนมาตรฐาน'), _fmt(row['standard_cost'])],
      [(_isEnglish ? 'Purchasable' : 'ซื้อได้'), _fmt(row['is_purchase_item'])],
      [(_isEnglish ? 'Sellable' : 'ขายได้'), _fmt(row['is_sales_item'])],
      [(_isEnglish ? 'Manufactured' : 'ผลิตได้'), _fmt(row['is_manufactured'])],
      [(_isEnglish ? 'Lot tracked' : 'ติดตาม Lot'), _fmt(row['is_lot_tracked'])],
      [(_isEnglish ? 'Serial tracked' : 'ติดตาม Serial'), _fmt(row['is_serial_tracked'])],
      [(_isEnglish ? 'Shelf life (days)' : 'อายุสินค้า (วัน)'), _fmt(row['shelf_life_days'])],
      [(_isEnglish ? 'Default warehouse' : 'คลังสินค้าตั้งต้น'), _fmt(row['default_warehouse_code'])],
      [(_isEnglish ? 'Minimum stock' : 'สต็อกขั้นต่ำ'), _fmt(row['min_stock_qty'])],
      [(_isEnglish ? 'Maximum stock' : 'สต็อกสูงสุด'), _fmt(row['max_stock_qty'])],
      [(_isEnglish ? 'Reorder point' : 'จุดสั่งซื้อ'), _fmt(row['reorder_point'])],
      [(_isEnglish ? 'Default VAT type' : 'ประเภทภาษี VAT ตั้งต้น'), _fmt(row['default_vat_type'])],
      [(_isEnglish ? 'Active' : 'ใช้งาน'), _fmt(row['is_active'])],
    ];
    return _buildKeyValueTable(items);
  }

  Widget _buildGlAccountTab(Map<String, dynamic> row) {
    final items = <List<String>>[
      [(_isEnglish ? 'Inventory account code' : 'รหัสบัญชีสินค้าคงเหลือ'), _fmt(row['inventory_account_code'])],
      [(_isEnglish ? 'COGS account code' : 'รหัสบัญชีต้นทุนขาย'), _fmt(row['cogs_account_code'])],
      [(_isEnglish ? 'Revenue account code' : 'รหัสบัญชีรายได้'), _fmt(row['revenue_account_code'])],
      [(_isEnglish ? 'Expense account code' : 'รหัสบัญชีค่าใช้จ่าย'), _fmt(row['expense_account_code'])],
      [(_isEnglish ? 'Purchases account code' : 'รหัสบัญชีซื้อ'), _fmt(row['purchases_account_code'])],
    ];
    return _buildKeyValueTable(items);
  }

  Widget _buildKeyValueTable(List<List<String>> items) {
    return _DualScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: items
              .map((kv) => TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(kv[0],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 240),
                        child: Text(kv[1].isEmpty ? '-' : kv[1]),
                      ),
                    ),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildListTable(List<dynamic> rows, List<List<String>> columns) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text((_isEnglish ? 'No data' : 'ไม่มีข้อมูล'), style: const TextStyle(color: Colors.grey)),
      );
    }
    return _DualScrollView(
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        columns: columns
            .map((c) => DataColumn(
                label: Text(c[1],
                    style: const TextStyle(fontWeight: FontWeight.bold))))
            .toList(),
        rows: rows.map((r) {
          final map = r as Map<String, dynamic>;
          return DataRow(
            cells: columns
                .map((c) => DataCell(Text(_fmt(map[c[0]]))))
                .toList(),
          );
        }).toList(),
      ),
    );
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '0';
    final n = v is num ? v : num.tryParse(v.toString()) ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String _fmt(dynamic val) {
    if (val == null) return '';
    if (val is bool) return val ? (_isEnglish ? 'Yes' : 'ใช่') : (_isEnglish ? 'No' : 'ไม่ใช่');
    if (val is List) return val.map((e) => _fmtNum(e)).join(', ');
    if (val is num) return _fmtNum(val);
    return val.toString();
  }
}

// ─── Dual scrollbar (vertical + horizontal) wrapper ─────────────────────────
class _DualScrollView extends StatefulWidget {
  final Widget child;
  const _DualScrollView({required this.child});

  @override
  State<_DualScrollView> createState() => _DualScrollViewState();
}

class _DualScrollViewState extends State<_DualScrollView> {
  final _vertCtrl = ScrollController();
  final _horzCtrl = ScrollController();

  @override
  void dispose() {
    _vertCtrl.dispose();
    _horzCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _vertCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vertCtrl,
        child: Scrollbar(
          controller: _horzCtrl,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 0,
          child: SingleChildScrollView(
            controller: _horzCtrl,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
