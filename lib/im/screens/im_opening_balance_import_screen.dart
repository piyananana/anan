// lib/im/screens/im_opening_balance_import_screen.dart
// ตั้งยอดคงเหลือ+มูลค่าสินค้าเริ่มต้น — bulk import ตรงเข้า im_stock_balance/im_stock_layer
// ไม่ผ่าน GL ไม่ผ่าน im_transaction/AJS (เหมือน ar_customer_balance_import / ap_vendor_balance_import)
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
import '../../utils/date_utils.dart';
import '../../utils/file_download.dart';

class ImOpeningBalanceImportScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;

  const ImOpeningBalanceImportScreen({super.key, required this.onFieldsChanged});

  @override
  State<ImOpeningBalanceImportScreen> createState() => _ImOpeningBalanceImportScreenState();
}

class _ImOpeningBalanceImportScreenState extends State<ImOpeningBalanceImportScreen> {
  bool _isEnglish = false;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  DateTime _asOfDate = DateTime.now();
  final _descCtrl = TextEditingController();

  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileExtension;

  List<Map<String, dynamic>> _templateSheets = [];

  bool _isValidated = false;
  int _totalRows = 0;
  int _validRows = 0;
  int _errorRows = 0;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, dynamic>> _validatedData = [];

  bool _isLoading = false;
  bool _isImporting = false;

  bool _isLoadingBatches = false;
  List<Map<String, dynamic>> _batches = [];
  int? _reversingBatchId;

  static const _appColor = Colors.teal;

  @override
  void initState() {
    super.initState();
    _loadTemplateSheets();
    _loadBatches();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplateSheets() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiIm}/im_opening_balance/import/template'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _templateSheets = List<Map<String, dynamic>>.from(data['sheets'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoadingBatches = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(Uri.parse('${AppConfig.apiIm}/im_opening_balance/batches'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (mounted) setState(() => _batches = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingBatches = false);
    }
  }

  Future<void> _reverseBatch(Map<String, dynamic> batch) async {
    final id = batch['id'] as int;
    final desc = (batch['description'] as String?)?.isNotEmpty == true ? batch['description'] as String : 'OPBAL-${id.toString().padLeft(6, '0')}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((_isEnglish ? 'Reverse opening balance' : 'ถอยกลับการตั้งยอด')),
        content: Text(_isEnglish
            ? 'Reverse batch "$desc" (${batch['line_count']} rows)? '
                'All balances set by this batch will be reversed. Rows with movements after the opening balance cannot be reversed.'
            : 'ถอยกลับชุดข้อมูล "$desc" (${batch['line_count']} รายการ)? '
            'ยอดคงเหลือที่ตั้งไว้จากชุดนี้จะถูกย้อนกลับทั้งหมด รายการที่มีการเคลื่อนไหวไปแล้วหลังตั้งยอดจะทำให้ถอยกลับไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text((_isEnglish ? 'Cancel' : 'ยกเลิก'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            child: Text((_isEnglish ? 'Confirm reverse' : 'ยืนยันถอยกลับ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reversingBatchId = id);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.put(Uri.parse('${AppConfig.apiIm}/im_opening_balance/batch/$id/reverse'), headers: headers);
      if (response.statusCode == 200) {
        _showSnack((_isEnglish ? 'Batch reversed' : 'ถอยกลับชุดข้อมูลสำเร็จ'));
        await _loadBatches();
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final blocking = (body['blocking_rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (blocking.isNotEmpty) {
          final detail = blocking.map((b) => '• ${b['item_code']} (${b['reason']})').join('\n');
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text((_isEnglish ? 'Cannot reverse' : 'ถอยกลับไม่ได้')),
                content: Text('${body['message']}\n\n$detail'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text((_isEnglish ? 'Close' : 'ปิด')))],
              ),
            );
          }
        } else {
          _showSnack(body['message'] ?? (_isEnglish ? 'An error occurred' : 'เกิดข้อผิดพลาด'), isError: true);
        }
      }
    } catch (e) {
      _showSnack((_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), isError: true);
    } finally {
      if (mounted) setState(() => _reversingBatchId = null);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _asOfDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _asOfDate = picked);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv'], withData: true);
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

  Future<void> _validate() async {
    if (_fileBytes == null) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();

      final uri = Uri.parse('${AppConfig.apiIm}/im_opening_balance/import/validate');
      final request = http.MultipartRequest('POST', uri)..headers.addAll(headers);

      final mimeType = _fileExtension == 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      request.files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: _fileName!, contentType: MediaType.parse(mimeType)));

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

  Future<void> _confirmImport() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_validatedData.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((_isEnglish ? 'Confirm opening balance' : 'ยืนยันการตั้งยอด')),
        content: Text(_isEnglish
            ? 'Set $_validRows opening balance rows as of ${_dateFmt.format(_asOfDate)}?\n'
                'This creates no GL entries and no stock adjustment documents.'
            : 'ต้องการตั้งยอดคงเหลือเริ่มต้น $_validRows รายการ ณ วันที่ ${_dateFmt.format(_asOfDate)} ใช่หรือไม่?\n'
            'การดำเนินการนี้จะไม่สร้างรายการบัญชี (GL) หรือใบปรับยอดสินค้าใดๆ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
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
        Uri.parse('${AppConfig.apiIm}/im_opening_balance/import/confirm'),
        headers: headers,
        body: jsonEncode({
          'import_date': formatLocalDate(_asOfDate),
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'rows': _validatedData,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final imported = data['imported'] ?? 0;
        final errs = (data['errors'] as List?)?.length ?? 0;
        if (mounted) {
          _showSnack((_isEnglish ? 'Set $imported balance rows${errs > 0 ? '  |  $errs errors' : ''}' : 'ตั้งยอดสำเร็จ $imported รายการ${errs > 0 ? '  |  ผิดพลาด $errs รายการ' : ''}'));
          setState(() {
            _fileName = null;
            _fileBytes = null;
            _isValidated = false;
            _errors = [];
            _validatedData = [];
          });
          widget.onFieldsChanged();
          await _loadBatches();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }

  Future<void> _downloadTemplate() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(Uri.parse('${AppConfig.apiIm}/im_opening_balance/import/template/download?lang=${_isEnglish ? 'en' : 'th'}'), headers: headers);
      if (response.statusCode == 200) {
        await downloadFile(response.bodyBytes, 'im_opening_balance_template.xlsx');
      } else {
        _showSnack((_isEnglish ? 'Template download failed (${response.statusCode})' : 'ดาวน์โหลดเทมเพลตไม่สำเร็จ (${response.statusCode})'), isError: true);
      }
    } catch (e) {
      _showSnack((_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), isError: true);
    }
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEnglish
                        ? 'For the first-time (go-live) quantity + cost setup only — writes straight to stock balances. '
                            'No GL posting and no stock adjustment document. Duplicate setups are not blocked; please check yourself.'
                        : 'ใช้สำหรับตั้งยอดคงเหลือ+ต้นทุนสินค้าครั้งแรก (go-live) เท่านั้น — เขียนตรงลงยอดคงเหลือสินค้า '
                    'ไม่ผ่านบัญชี GL และไม่สร้างใบปรับยอดสินค้า ระบบไม่กันการตั้งยอดซ้ำ ผู้ใช้ต้องตรวจสอบเอง',
                    style: const TextStyle(color: Colors.brown, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _buildHeaderFieldsSection(),
          const SizedBox(height: 16),
          _buildTemplateSection(),
          const SizedBox(height: 16),
          _buildFilePickerSection(),
          if (_isValidated) ...[
            const SizedBox(height: 16),
            _buildResultSection(),
          ],
          const SizedBox(height: 16),
          _buildHistorySection(),
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: _isValidated && _errorRows == 0 && _validRows > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: (_isImporting || !(MenuScope.of(context)?.canCreate ?? true)) ? null : _confirmImport,
                  icon: _isImporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isImporting ? (_isEnglish ? 'Setting balances...' : 'กำลังตั้งยอด...') : (_isEnglish ? 'Confirm $_validRows balance rows' : 'ยืนยันตั้งยอด $_validRows รายการ')),
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

  Widget _buildHeaderFieldsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: (_isEnglish ? 'Balance as of *' : 'ตั้งยอด ณ วันที่ *'), border: const OutlineInputBorder(), isDense: true),
                child: Text(_dateFmt.format(_asOfDate)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _descCtrl,
              decoration: InputDecoration(labelText: (_isEnglish ? 'Description (optional)' : 'คำอธิบาย (ไม่บังคับ)'), border: const OutlineInputBorder(), isDense: true),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTemplateSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.table_chart_outlined, color: _appColor.shade700),
        title: Text((_isEnglish ? 'Import template' : 'เทมเพลตนำเข้าข้อมูล'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text((_isEnglish ? 'Click to see the column details' : 'คลิกเพื่อดูรายละเอียดคอลัมน์')),
        trailing: OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: Text((_isEnglish ? 'Download template' : 'ดาวน์โหลดเทมเพลต')),
          style: OutlinedButton.styleFrom(foregroundColor: _appColor.shade700, side: BorderSide(color: _appColor.shade700)),
        ),
        initiallyExpanded: false,
        children: [
          for (final sheet in _templateSheets) _buildTemplateSheetTile(sheet),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTemplateSheetTile(Map<String, dynamic> sheet) {
    final columns = List<Map<String, dynamic>>.from(sheet['columns'] ?? []);
    return ExpansionTile(
      title: Text((_isEnglish ? (sheet['name_en'] ?? sheet['name']) : sheet['name'])?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      initiallyExpanded: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            columns: [
              DataColumn(label: Text((_isEnglish ? 'Header name' : 'ชื่อ Header'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text((_isEnglish ? 'Meaning' : 'ความหมาย'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text((_isEnglish ? 'Required' : 'จำเป็น'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text((_isEnglish ? 'Example' : 'ตัวอย่าง'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: columns
                .map((col) => DataRow(cells: [
                      DataCell(Text(col['key']?.toString() ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text((_isEnglish ? (col['label_en'] ?? col['label']) : col['label'])?.toString() ?? '')),
                      DataCell((col['required'] as bool? ?? false) ? const Icon(Icons.star, color: Colors.red, size: 14) : const Text('-', style: TextStyle(color: Colors.grey))),
                      DataCell(Text(col['example']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((_isEnglish ? 'Select import file' : 'เลือกไฟล์นำเข้า'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text((_isEnglish ? 'Supports .xlsx, .xls, .csv files' : 'รองรับไฟล์ .xlsx, .xls, .csv'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4), color: Colors.grey.shade50),
                child: Text(_fileName ?? (_isEnglish ? 'No file selected' : 'ยังไม่ได้เลือกไฟล์'), style: TextStyle(color: _fileName != null ? Colors.black87 : Colors.grey), overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder_open), label: Text((_isEnglish ? 'Select file' : 'เลือกไฟล์'))),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _fileBytes == null || _isLoading ? null : _validate,
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.fact_check_outlined),
              label: Text((_isEnglish ? 'Validate' : 'ตรวจสอบ')),
              style: ElevatedButton.styleFrom(backgroundColor: _appColor.shade700, foregroundColor: Colors.white),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildHistorySection() {
    final canApprove = MenuScope.of(context)?.canApprove ?? false;
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.history, color: _appColor.shade700),
        title: Text((_isEnglish ? 'Opening balance history' : 'ประวัติการตั้งยอด'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_isLoadingBatches ? (_isEnglish ? 'Loading...' : 'กำลังโหลด...') : '${_batches.length} ชุดข้อมูล'),
        initiallyExpanded: false,
        children: [
          if (_isLoadingBatches)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_batches.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text((_isEnglish ? 'No opening balance history yet' : 'ยังไม่มีประวัติการตั้งยอด'), style: const TextStyle(color: Colors.grey)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                columns: [
                  DataColumn(label: Text((_isEnglish ? 'Balance date' : 'วันที่ตั้งยอด'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text((_isEnglish ? 'Description' : 'คำอธิบาย'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text((_isEnglish ? 'Rows' : 'จำนวนรายการ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text((_isEnglish ? 'By' : 'โดย'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text((_isEnglish ? 'Status' : 'สถานะ'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('')),
                ],
                rows: _batches.map((b) {
                  final isReversed = b['reversed_at'] != null;
                  final id = b['id'] as int;
                  return DataRow(cells: [
                    DataCell(Text(_dateFmt.format(parseLocalDate(b['import_date'])))),
                    DataCell(Text(b['description'] as String? ?? '-')),
                    DataCell(Text('${b['line_count']}')),
                    DataCell(Text(b['created_by'] as String? ?? '-')),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isReversed ? Colors.grey.shade300 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(isReversed ? (_isEnglish ? 'Reversed' : 'ถอยกลับแล้ว') : (_isEnglish ? 'Set' : 'ตั้งยอดแล้ว'), style: const TextStyle(fontSize: 11)),
                    )),
                    DataCell(
                      (canApprove && !isReversed)
                          ? TextButton.icon(
                              onPressed: _reversingBatchId == id ? null : () => _reverseBatch(b),
                              icon: _reversingBatchId == id
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.undo, size: 16),
                              label: Text((_isEnglish ? 'Reverse' : 'ถอยกลับ'), style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final allOk = _errorRows == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        color: allOk ? Colors.green.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(allOk ? Icons.check_circle : Icons.warning_amber_rounded, color: allOk ? Colors.green.shade700 : Colors.orange.shade700, size: 36),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                allOk ? 'ข้อมูลถูกต้องทั้งหมด พร้อมตั้งยอด' : (_isEnglish ? 'Invalid data found. Please fix the file and validate again' : 'พบข้อมูลไม่ถูกต้อง กรุณาแก้ไขไฟล์แล้วตรวจสอบใหม่'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: allOk ? Colors.green.shade800 : Colors.orange.shade800),
              ),
              const SizedBox(height: 4),
              Text(_isEnglish ? 'Total: $_totalRows rows   Valid: $_validRows rows   Invalid: $_errorRows rows' : 'ทั้งหมด: $_totalRows รายการ   ถูกต้อง: $_validRows รายการ   ไม่ถูกต้อง: $_errorRows รายการ', style: const TextStyle(fontSize: 13)),
            ]),
          ]),
        ),
      ),
      if (_errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text((_isEnglish ? 'Invalid rows' : 'รายการที่ไม่ถูกต้อง'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
            columns: [
              DataColumn(label: Text((_isEnglish ? 'Row' : 'แถวที่'))),
              DataColumn(label: Text((_isEnglish ? 'Old item code' : 'รหัสสินค้าเก่า'))),
              DataColumn(label: Text((_isEnglish ? 'Column' : 'คอลัมน์'))),
              DataColumn(label: Text((_isEnglish ? 'Error' : 'ข้อผิดพลาด'))),
            ],
            rows: [
              for (final e in _errors)
                for (final err in (e['errors'] as List))
                  DataRow(color: WidgetStateProperty.all(Colors.red.shade50), cells: [
                    DataCell(Text('${e['row']}')),
                    DataCell(Text(e['itemCode'] ?? '')),
                    DataCell(Text(err['column'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    DataCell(Text(err['message'] ?? '')),
                  ]),
            ],
          ),
        ),
      ],
      if (_validRows > 0) ...[
        const SizedBox(height: 16),
        Text(_isEnglish
            ? 'Preview of balances to set${_validRows > 50 ? ' (showing 50 of $_validRows rows)' : ' ($_validRows rows)'}'
            : 'ตัวอย่างข้อมูลที่จะตั้งยอด${_validRows > 50 ? ' (แสดง 50 จาก $_validRows รายการ)' : ' ($_validRows รายการ)'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            columns: [
              DataColumn(label: Text((_isEnglish ? 'Old item code' : 'รหัสสินค้าเก่า'))),
              DataColumn(label: Text((_isEnglish ? 'Item code' : 'รหัสสินค้า'))),
              DataColumn(label: Text((_isEnglish ? 'Warehouse' : 'คลังสินค้า'))),
              DataColumn(label: Text((_isEnglish ? 'Location' : 'ตำแหน่ง'))),
              DataColumn(label: Text((_isEnglish ? 'Lot' : 'ล็อต'))),
              const DataColumn(label: Text('Serial')),
              DataColumn(label: Text((_isEnglish ? 'Qty' : 'จำนวน')), numeric: true),
              DataColumn(label: Text((_isEnglish ? 'Unit cost' : 'ต้นทุน/หน่วย')), numeric: true),
            ],
            rows: _validatedData.take(50).map((r) => DataRow(cells: [
                  DataCell(Text(r['old_item_code']?.toString() ?? '')),
                  DataCell(Text(r['item_code']?.toString() ?? '')),
                  DataCell(Text(r['warehouse_code']?.toString() ?? '')),
                  DataCell(Text(r['location_code']?.toString() ?? '-')),
                  DataCell(Text(r['lot_no']?.toString() ?? '-')),
                  DataCell(Text(r['serial_no']?.toString() ?? '-')),
                  DataCell(Text('${r['qty'] ?? ''}')),
                  DataCell(Text('${r['unit_cost'] ?? ''}')),
                ])).toList(),
          ),
        ),
      ],
    ]);
  }
}
