// lib/cm/screens/cm_bank_statement_import_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/cm_bank_account.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankStatementImportScreen extends StatefulWidget {
  const CmBankStatementImportScreen({super.key});
  @override
  State<CmBankStatementImportScreen> createState() => _State();
}

class _State extends State<CmBankStatementImportScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;

  // Accounts
  List<CmBankAccount> _bankAccounts = [];
  CmBankAccount?      _selAccount;

  // CSV settings
  int    _skipRows       = 1;
  String _delimiter      = ',';
  int    _colDate        = 0;
  int    _colDescription = 1;
  int    _colDebit       = 2;
  int    _colCredit      = 3;
  int    _colBalance     = 4;
  int    _colReference   = -1;
  String _datePattern    = 'yyyy-MM-dd';

  // Raw CSV
  List<List<String>> _rawRows = [];
  String? _fileName;

  // Parsed preview
  List<Map<String, dynamic>> _previewRows = [];
  String? _parseError;

  bool _importing = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = (json.decode(resp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() {
          _bankAccounts = all.where((a) => a.cmType == 'BANK').toList();
          if (_bankAccounts.isNotEmpty) _selAccount = _bankAccounts.first;
        });
      }
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final content = utf8.decode(file.bytes!, allowMalformed: true);
    setState(() {
      _fileName = file.name;
      _rawRows = _parseCsvRows(content, _delimiter);
      _lastResult = null;
    });
    _buildPreview();
  }

  List<List<String>> _parseCsvRows(String content, String delimiter) {
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    return lines
        .map((line) => line.isEmpty ? <String>[] : _splitCsvLine(line, delimiter))
        .where((cells) => cells.isNotEmpty)
        .toList();
  }

  List<String> _splitCsvLine(String line, String delimiter) {
    if (delimiter == ',') {
      // Handle quoted CSV
      final result = <String>[];
      var inQuotes = false;
      var current  = StringBuffer();
      for (var i = 0; i < line.length; i++) {
        final c = line[i];
        if (c == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            current.write('"'); i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (c == ',' && !inQuotes) {
          result.add(current.toString().trim());
          current = StringBuffer();
        } else {
          current.write(c);
        }
      }
      result.add(current.toString().trim());
      return result;
    }
    return line.split(delimiter).map((s) => s.trim()).toList();
  }

  void _buildPreview() {
    setState(() { _parseError = null; _previewRows = []; });
    if (_rawRows.isEmpty) return;

    final dataRows = _rawRows.skip(_skipRows).toList();
    if (dataRows.isEmpty) {
      setState(() => _parseError = 'ไม่มีข้อมูลหลัง skip ${ _skipRows} แถว');
      return;
    }

    final parsed = <Map<String, dynamic>>[];
    final errors = <String>[];

    for (var i = 0; i < dataRows.length; i++) {
      final cells = dataRows[i];
      if (cells.isEmpty || cells.every((c) => c.trim().isEmpty)) continue;

      String? dateStr;
      if (_colDate >= 0 && _colDate < cells.length) {
        dateStr = _parseDate(cells[_colDate].trim(), _datePattern);
      }
      if (dateStr == null) {
        errors.add('แถว ${i + _skipRows + 1}: ไม่สามารถอ่านวันที่ "${_colDate < cells.length ? cells[_colDate] : ""}"');
        continue;
      }

      double debit   = 0;
      double credit  = 0;
      double? balance;

      if (_colDebit >= 0 && _colDebit < cells.length) {
        debit = _parseAmount(cells[_colDebit]);
      }
      if (_colCredit >= 0 && _colCredit < cells.length) {
        credit = _parseAmount(cells[_colCredit]);
      }
      if (_colBalance >= 0 && _colBalance < cells.length) {
        balance = _parseAmountNullable(cells[_colBalance]);
      }

      parsed.add({
        'line_date':    dateStr,
        'description':  _colDescription >= 0 && _colDescription < cells.length ? cells[_colDescription] : '',
        'debit':        debit,
        'credit':       credit,
        'balance':      balance,
        'reference_no': _colReference >= 0 && _colReference < cells.length ? cells[_colReference] : null,
      });
    }

    setState(() {
      _previewRows = parsed;
      if (errors.isNotEmpty) _parseError = errors.take(5).join('\n');
    });
  }

  String? _parseDate(String raw, String pattern) {
    if (raw.isEmpty) return null;
    try {
      final df = DateFormat(pattern);
      final dt = df.parseLoose(raw);
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {}
    // Try ISO
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {}
    return null;
  }

  double _parseAmount(String raw) {
    if (raw.isEmpty) return 0;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  double? _parseAmountNullable(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned);
  }

  Future<void> _import() async {
    if (_selAccount == null) { _showError('กรุณาเลือกบัญชีธนาคาร'); return; }
    if (_previewRows.isEmpty) { _showError('ไม่มีข้อมูลที่จะนำเข้า'); return; }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันนำเข้า Statement'),
        content: Text('นำเข้า ${_previewRows.length} รายการ เข้า ${_selAccount!.accountNameTh} ใช่หรือไม่?\n'
            'ระบบจะสร้าง Bank Statement ใหม่ (Draft)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('นำเข้า'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _importing = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      // Compute date range from preview rows
      final dates = _previewRows.map((r) => r['line_date'] as String).toList()..sort();
      final resp = await http.post(
          Uri.parse('${AppConfig.apiCm}/cm_bank_statement_import'),
          headers: headers,
          body: json.encode({
            'bank_account_id':     _selAccount!.id,
            'statement_date_from': dates.first,
            'statement_date_to':   dates.last,
            'description':         'Import จาก $_fileName',
            'lines':               _previewRows,
          }));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final result = json.decode(resp.body) as Map<String, dynamic>;
        final imported = result['lines_imported'] ?? 0;
        final errList  = (result['errors'] as List?)?.cast<String>() ?? [];
        setState(() {
          _lastResult = 'นำเข้าสำเร็จ $imported รายการ'
              '${errList.isNotEmpty ? " (${errList.length} รายการมีข้อผิดพลาด)" : ""}';
        });
        if (errList.isNotEmpty) {
          _showError(errList.take(3).join('\n'));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('นำเข้าสำเร็จ $imported รายการ'),
              backgroundColor: Colors.green.shade700));
        }
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
        actions: [
          if (_previewRows.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload, size: 16),
              label: Text('นำเข้า (${_previewRows.length})', style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 36, color: _kTheme,
            child: IconButton(
              padding: EdgeInsets.zero, iconSize: 20, color: Colors.white,
              icon: Icon(_leftExpanded ? Icons.chevron_left : Icons.chevron_right),
              onPressed: () => setState(() => _leftExpanded = !_leftExpanded),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _leftExpanded ? 300 : 0,
            child: ClipRect(child: OverflowBox(
              alignment: Alignment.centerLeft, maxWidth: 300,
              child: _buildLeftPanel(),
            )),
          ),
          if (_leftExpanded) const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildRightPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 32, color: Colors.blueGrey.shade200,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Text('ตั้งค่าการนำเข้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(height: 10),
          // Bank account
          _lbl('บัญชีธนาคาร *'),
          DropdownButtonFormField<CmBankAccount?>(
            value: _selAccount,
            isDense: true,
            decoration: _dec(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: _bankAccounts.map((a) => DropdownMenuItem<CmBankAccount?>(
              value: a,
              child: Text(a.displayName, style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (v) => setState(() => _selAccount = v),
          ),
          const SizedBox(height: 10),
          // File
          _lbl('ไฟล์ CSV'),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: _kTheme,
                side: BorderSide(color: _kTheme),
                minimumSize: const Size.fromHeight(34)),
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file, size: 16),
            label: Text(_fileName ?? 'เลือกไฟล์ .csv / .txt', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 10),
          // Delimiter
          _lbl('ตัวคั่น (Delimiter)'),
          DropdownButtonFormField<String>(
            value: _delimiter,
            isDense: true,
            decoration: _dec(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: const [
              DropdownMenuItem(value: ',', child: Text('จุลภาค (,)')),
              DropdownMenuItem(value: '\t', child: Text('Tab')),
              DropdownMenuItem(value: '|', child: Text('Pipe (|)')),
              DropdownMenuItem(value: ';', child: Text('Semicolon (;)')),
            ],
            onChanged: (v) {
              setState(() {
                _delimiter = v ?? ',';
                if (_rawRows.isNotEmpty && _fileName != null) {
                  // Re-parse is not possible without the original content — just show note
                }
              });
            },
          ),
          const SizedBox(height: 8),
          _lbl('ข้ามแถวแรก (Skip rows)'),
          _numField('จำนวนแถว Header', _skipRows, (v) { setState(() => _skipRows = v); _buildPreview(); }),
          const SizedBox(height: 8),
          _lbl('รูปแบบวันที่'),
          DropdownButtonFormField<String>(
            value: _datePattern,
            isDense: true,
            decoration: _dec(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: const [
              DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('2024-01-31')),
              DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('31/01/2024')),
              DropdownMenuItem(value: 'dd/MM/yy',   child: Text('31/01/24')),
              DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('01/31/2024')),
              DropdownMenuItem(value: 'ddMMyyyy',   child: Text('31012024')),
            ],
            onChanged: (v) { setState(() => _datePattern = v ?? 'yyyy-MM-dd'); _buildPreview(); },
          ),
          const SizedBox(height: 10),
          const Divider(),
          const Text('ตำแหน่ง Column (0 = คอลัมน์แรก)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _colMappingRow('วันที่', _colDate, (v) { setState(() => _colDate = v); _buildPreview(); }),
          _colMappingRow('คำอธิบาย', _colDescription, (v) { setState(() => _colDescription = v); _buildPreview(); }),
          _colMappingRow('เดบิต (รายจ่าย)', _colDebit, (v) { setState(() => _colDebit = v); _buildPreview(); }),
          _colMappingRow('เครดิต (รายรับ)', _colCredit, (v) { setState(() => _colCredit = v); _buildPreview(); }),
          _colMappingRow('ยอดคงเหลือ', _colBalance, (v) { setState(() => _colBalance = v); _buildPreview(); }),
          _colMappingRow('Reference (-1=ไม่มี)', _colReference, (v) { setState(() => _colReference = v); _buildPreview(); }),
          if (_rawRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('จำนวนแถวทั้งหมด: ${_rawRows.length}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text('ข้อมูล: ${_rawRows.isNotEmpty && _rawRows.first.isNotEmpty ? _rawRows.first.length : 0} คอลัมน์',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ]),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_lastResult != null)
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.green.shade50,
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(_lastResult!, style: const TextStyle(fontSize: 13, color: Colors.green)),
          ]),
        ),
      if (_parseError != null)
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.orange.shade50,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_parseError!, style: const TextStyle(fontSize: 12, color: Colors.deepOrange))),
          ]),
        ),
      Expanded(child: _buildPreviewTable()),
    ]);
  }

  Widget _buildPreviewTable() {
    if (_rawRows.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.upload_file, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('เลือกไฟล์ CSV แล้วตั้งค่า mapping คอลัมน์',
            style: TextStyle(color: Colors.grey.shade400)),
      ]));
    }

    if (_previewRows.isEmpty) {
      return Center(child: Text(
          'ไม่สามารถแปลงข้อมูลได้ กรุณาตรวจสอบ mapping',
          style: TextStyle(color: Colors.grey.shade400)));
    }

    final totalDebit  = _previewRows.fold<double>(0, (s, r) => s + (double.tryParse(r['debit']?.toString() ?? '0') ?? 0));
    final totalCredit = _previewRows.fold<double>(0, (s, r) => s + (double.tryParse(r['credit']?.toString() ?? '0') ?? 0));

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.blueGrey.shade50,
        child: Row(children: [
          Text('ตัวอย่าง ${_previewRows.length} รายการ',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('รายจ่ายรวม: ${_fmt.format(totalDebit)}',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          const SizedBox(width: 16),
          Text('รายรับรวม: ${_fmt.format(totalCredit)}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32, dataRowMinHeight: 28, dataRowMaxHeight: 34,
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
              headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('วันที่')),
                DataColumn(label: Text('คำอธิบาย')),
                DataColumn(label: Text('รายจ่าย'), numeric: true),
                DataColumn(label: Text('รายรับ'), numeric: true),
                DataColumn(label: Text('ยอดคงเหลือ'), numeric: true),
                DataColumn(label: Text('Reference')),
              ],
              rows: _previewRows.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                DateTime? dt;
                try { dt = DateTime.parse(r['line_date'].toString()); } catch (_) {}
                final debit  = double.tryParse(r['debit']?.toString() ?? '0') ?? 0;
                final credit = double.tryParse(r['credit']?.toString() ?? '0') ?? 0;
                final bal    = r['balance'] != null ? double.tryParse(r['balance'].toString()) : null;
                return DataRow(cells: [
                  DataCell(Text('${i + 1}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
                  DataCell(Text(dt != null ? _dateFmt.format(dt) : r['line_date']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(SizedBox(width: 180,
                      child: Text(r['description']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  DataCell(Text(debit > 0 ? _fmt.format(debit) : '',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                  DataCell(Text(credit > 0 ? _fmt.format(credit) : '',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700))),
                  DataCell(Text(bal != null ? _fmt.format(bal) : '',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(r['reference_no']?.toString() ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _lbl(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),
  );

  InputDecoration _dec({String? hint}) => InputDecoration(
    isDense: true, filled: true, fillColor: Colors.white,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );

  Widget _numField(String hint, int value, void Function(int) onChanged) {
    final ctrl = TextEditingController(text: '$value');
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 12),
      decoration: _dec(hint: hint),
      onChanged: (v) { final n = int.tryParse(v); if (n != null) onChanged(n); },
    );
  }

  Widget _colMappingRow(String label, int value, void Function(int) onChanged) {
    final ctrl = TextEditingController(text: '$value');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))),
        SizedBox(
          width: 52,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            onChanged: (v) { final n = int.tryParse(v); if (n != null) onChanged(n); },
          ),
        ),
      ]),
    );
  }
}
