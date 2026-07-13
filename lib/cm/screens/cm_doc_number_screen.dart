// lib/cm/screens/cm_doc_number_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';

const _kTheme = Color(0xFF1565C0);
final _dateFmt = DateFormat('dd/MM/yyyy');

const List<String> _kDocTypes = [
  'RECEIPT', 'PAYMENT', 'PETTY_CASH_VOUCHER',
  'PETTY_CASH_RPL', 'INTER_BANK_TRANSFER', 'FX_REVALUATION',
];

const Map<String, String> _kDocTypeLabels = {
  'RECEIPT':             'ใบรับเงิน (RECEIPT)',
  'PAYMENT':             'ใบจ่ายเงิน (PAYMENT)',
  'PETTY_CASH_VOUCHER':  'วาวเชอร์เงินสดย่อย',
  'PETTY_CASH_RPL':      'เบิกชดเชยเงินสดย่อย',
  'INTER_BANK_TRANSFER': 'โอนเงินระหว่างบัญชี',
  'FX_REVALUATION':      'ปรับปรุงอัตราแลกเปลี่ยน',
};

const Map<String, String> _kDateSuffixLabels = {
  '':           'ไม่มี',
  'YY':         'YY (2 หลัก ปี)',
  'YYYY':       'YYYY (4 หลัก ปี)',
  'YYMM':       'YYMM (ปี-เดือน 2+2)',
  'YYYYMM':     'YYYYMM (ปี-เดือน 4+2)',
  'YYYYMMDD':   'YYYYMMDD (ปี-เดือน-วัน)',
};

const Map<String, String> _kResetPeriodLabels = {
  'MONTHLY': 'รีเซ็ตทุกเดือน',
  'YEARLY':  'รีเซ็ตทุกปี',
  'NEVER':   'ไม่รีเซ็ต',
};

class CmDocNumberScreen extends StatefulWidget {
  const CmDocNumberScreen({super.key});
  @override
  State<CmDocNumberScreen> createState() => _State();
}

class _State extends State<CmDocNumberScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _rows    = [];
  bool _loading = false;
  List<Map<String, dynamic>> _branches = [];
  String _previewNo = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final results = await Future.wait([
        http.get(Uri.parse('${AppConfig.apiCm}/cm_doc_number_config'), headers: headers),
        http.get(Uri.parse('${AppConfig.apiCd}/cd_branch'), headers: headers),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        setState(() => _rows = List<Map<String, dynamic>>.from(json.decode(results[0].body) as List));
      }
      if (results[1].statusCode == 200) {
        setState(() => _branches = List<Map<String, dynamic>>.from(json.decode(results[1].body) as List));
      }
    } catch (e) { _showError(e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  void _openDialog({Map<String, dynamic>? row}) {
    showDialog(
      context: context,
      builder: (_) => _DocNumberDialog(
        row: row,
        branches: _branches,
        onSaved: () { Navigator.pop(context); _loadData(); },
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบ'),
        content: Text('ลบ config ${_kDocTypeLabels[row['cm_doc_type']] ?? row['cm_doc_type']} '
            '${row['branch_code'] != null ? "(${row['branch_code']})" : "(ทุกสาขา)"} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.delete(
          Uri.parse('${AppConfig.apiCm}/cm_doc_number_config/${row['id']}'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        _loadData();
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) { if (mounted) _showError(e.toString()); }
  }

  Future<void> _preview(Map<String, dynamic> row) async {
    try {
      final headers = await AuthService().getAuthHeader();
      final params = {
        'cm_doc_type': row['cm_doc_type'] as String,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        if (row['branch_id'] != null) 'branch_id': row['branch_id'].toString(),
      };
      final resp = await http.get(
          Uri.parse('${AppConfig.apiCm}/cm_doc_number_config/preview').replace(queryParameters: params),
          headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() => _previewNo = data['doc_no'] ?? '—');
      }
    } catch (_) {}
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
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _openDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('เพิ่ม Config', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (_previewNo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue.shade50,
                  child: Row(children: [
                    const Icon(Icons.visibility, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('ตัวอย่างเลขที่เอกสาร: ', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                    Text(_previewNo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _previewNo = '')),
                  ]),
                ),
              Expanded(
                child: _rows.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.format_list_numbered, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('ยังไม่มี config เลขที่เอกสาร', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
                          onPressed: () => _openDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('เพิ่ม Config'),
                        ),
                      ]))
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 34, dataRowMinHeight: 32, dataRowMaxHeight: 38,
                            columnSpacing: 14,
                            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                            headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            columns: const [
                              DataColumn(label: Text('ประเภทเอกสาร')),
                              DataColumn(label: Text('สาขา')),
                              DataColumn(label: Text('Prefix')),
                              DataColumn(label: Text('Date Suffix')),
                              DataColumn(label: Text('Sep')),
                              DataColumn(label: Text('ความยาว'), numeric: true),
                              DataColumn(label: Text('เลขถัดไป'), numeric: true),
                              DataColumn(label: Text('Reset')),
                              DataColumn(label: Text('ใช้งาน')),
                              DataColumn(label: Text('ตัวอย่าง')),
                              DataColumn(label: Text('แก้ไข')),
                              DataColumn(label: Text('ลบ')),
                            ],
                            rows: _rows.map((row) => DataRow(cells: [
                              DataCell(Text(_kDocTypeLabels[row['cm_doc_type']] ?? row['cm_doc_type'] ?? '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              DataCell(Text(
                                row['branch_code'] != null
                                    ? '${row['branch_code']} ${row['branch_name_thai'] ?? ''}'
                                    : '— ทุกสาขา —',
                                style: TextStyle(fontSize: 12,
                                    color: row['branch_code'] == null ? Colors.grey.shade500 : Colors.black87),
                              )),
                              DataCell(Text(row['prefix'] ?? '', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                              DataCell(Text(_kDateSuffixLabels[row['date_suffix']] ?? row['date_suffix'] ?? '',
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(Text(row['separator'] ?? '', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                              DataCell(Text('${row['running_length'] ?? 4}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${row['next_running_number'] ?? 1}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue))),
                              DataCell(Text(_kResetPeriodLabels[row['reset_period']] ?? row['reset_period'] ?? '',
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(Icon(
                                row['is_active'] == true ? Icons.check_circle : Icons.cancel,
                                size: 16,
                                color: row['is_active'] == true ? Colors.green.shade600 : Colors.grey.shade400,
                              )),
                              DataCell(IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28),
                                tooltip: 'ดูตัวอย่าง',
                                onPressed: () => _preview(row),
                              )),
                              DataCell(IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28),
                                onPressed: () => _openDialog(row: row),
                              )),
                              DataCell(IconButton(
                                icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28),
                                onPressed: () => _delete(row),
                              )),
                            ])).toList(),
                          ),
                        ),
                      ),
              ),
            ]),
    );
  }
}

// ─── Add/Edit Dialog ──────────────────────────────────────────────────────────

class _DocNumberDialog extends StatefulWidget {
  final Map<String, dynamic>? row;
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;

  const _DocNumberDialog({this.row, required this.branches, required this.onSaved});

  @override
  State<_DocNumberDialog> createState() => _DocNumberDialogState();
}

class _DocNumberDialogState extends State<_DocNumberDialog> {
  late String  _docType;
  int?         _branchId;
  late TextEditingController _prefixCtrl;
  late TextEditingController _separatorCtrl;
  late String  _dateSuffix;
  late TextEditingController _runningLengthCtrl;
  late TextEditingController _nextRunningCtrl;
  late String  _resetPeriod;
  late bool    _isActive;

  bool _saving = false;
  String _previewNo = '';

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _docType         = r?['cm_doc_type'] as String? ?? _kDocTypes.first;
    _branchId        = r?['branch_id'] as int?;
    _prefixCtrl      = TextEditingController(text: r?['prefix'] as String? ?? '');
    _separatorCtrl   = TextEditingController(text: r?['separator'] as String? ?? '-');
    _dateSuffix      = r?['date_suffix'] as String? ?? 'YYYYMM';
    _runningLengthCtrl = TextEditingController(text: '${r?['running_length'] ?? 4}');
    _nextRunningCtrl = TextEditingController(text: '${r?['next_running_number'] ?? 1}');
    _resetPeriod     = r?['reset_period'] as String? ?? 'YEARLY';
    _isActive        = r?['is_active'] as bool? ?? true;
    _updatePreview();
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _separatorCtrl.dispose();
    _runningLengthCtrl.dispose();
    _nextRunningCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final now    = DateTime.now();
    final year   = now.year.toString();
    final month  = (now.month).toString().padLeft(2, '0');
    final day    = now.day.toString().padLeft(2, '0');
    String suffix = '';
    switch (_dateSuffix) {
      case 'YY':       suffix = year.substring(2); break;
      case 'YYYY':     suffix = year; break;
      case 'YYMM':     suffix = year.substring(2) + month; break;
      case 'YYYYMM':   suffix = year + month; break;
      case 'YYYYMMDD': suffix = year + month + day; break;
      default:         suffix = ''; break;
    }
    final sep    = _separatorCtrl.text;
    final len    = int.tryParse(_runningLengthCtrl.text) ?? 4;
    final next   = int.tryParse(_nextRunningCtrl.text) ?? 1;
    final num    = next.toString().padLeft(len, '0');
    setState(() => _previewNo = '${_prefixCtrl.text}$suffix$sep$num');
  }

  Future<void> _save() async {
    if (_docType.isEmpty) { _err('กรุณาเลือกประเภทเอกสาร'); return; }
    setState(() => _saving = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      final body = json.encode({
        'cm_doc_type':         _docType,
        'branch_id':           _branchId,
        'prefix':              _prefixCtrl.text,
        'separator':           _separatorCtrl.text,
        'date_suffix':         _dateSuffix,
        'running_length':      int.tryParse(_runningLengthCtrl.text) ?? 4,
        'next_running_number': int.tryParse(_nextRunningCtrl.text) ?? 1,
        'reset_period':        _resetPeriod,
        'is_active':           _isActive,
      });
      http.Response resp;
      if (widget.row == null) {
        resp = await http.post(Uri.parse('${AppConfig.apiCm}/cm_doc_number_config'),
            headers: headers, body: body);
      } else {
        resp = await http.put(
            Uri.parse('${AppConfig.apiCm}/cm_doc_number_config/${widget.row!['id']}'),
            headers: headers, body: body);
      }
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        widget.onSaved();
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _err(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.row == null ? 'เพิ่ม Config เลขที่เอกสาร' : 'แก้ไข Config เลขที่เอกสาร'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Preview banner
            if (_previewNo.isNotEmpty) Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(children: [
                Icon(Icons.preview, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text('ตัวอย่าง: ', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                Text(_previewNo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900, fontFamily: 'monospace')),
              ]),
            ),
            _buildRow('ประเภทเอกสาร *', DropdownButtonFormField<String>(
              value: _docType,
              isDense: true,
              decoration: _dec(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: _kDocTypes.map((t) => DropdownMenuItem(value: t,
                  child: Text('${_kDocTypeLabels[t] ?? t}', style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: widget.row != null ? null : (v) { setState(() => _docType = v ?? _docType); _updatePreview(); },
            )),
            const SizedBox(height: 8),
            _buildRow('สาขา', DropdownButtonFormField<int?>(
              value: _branchId,
              isDense: true,
              decoration: _dec(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              hint: const Text('— ทุกสาขา (global) —', style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('— ทุกสาขา (global) —', style: TextStyle(fontSize: 12))),
                ...widget.branches.map((b) => DropdownMenuItem<int?>(
                  value: b['id'] as int?,
                  child: Text('${b['branch_code']} ${b['branch_name_thai'] ?? ''}', style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: widget.row != null ? null : (v) { setState(() => _branchId = v); _updatePreview(); },
            )),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buildRow('Prefix', TextField(
                controller: _prefixCtrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: _dec(hint: 'เช่น RCT, PMT'),
                onChanged: (_) => _updatePreview(),
              ))),
              const SizedBox(width: 8),
              Expanded(child: _buildRow('ตัวคั่น (Sep)', TextField(
                controller: _separatorCtrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: _dec(hint: '- หรือ ว่าง'),
                onChanged: (_) => _updatePreview(),
              ))),
            ]),
            const SizedBox(height: 8),
            _buildRow('รูปแบบวันที่', DropdownButtonFormField<String>(
              value: _dateSuffix,
              isDense: true,
              decoration: _dec(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: _kDateSuffixLabels.entries.map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) { setState(() => _dateSuffix = v ?? _dateSuffix); _updatePreview(); },
            )),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buildRow('ความยาวตัวเลข', TextField(
                controller: _runningLengthCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12),
                decoration: _dec(hint: '4'),
                onChanged: (_) => _updatePreview(),
              ))),
              const SizedBox(width: 8),
              Expanded(child: _buildRow('เลขถัดไป', TextField(
                controller: _nextRunningCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12),
                decoration: _dec(hint: '1'),
                onChanged: (_) => _updatePreview(),
              ))),
            ]),
            const SizedBox(height: 8),
            _buildRow('รีเซ็ต Running', DropdownButtonFormField<String>(
              value: _resetPeriod,
              isDense: true,
              decoration: _dec(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: _kResetPeriodLabels.entries.map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _resetPeriod = v ?? _resetPeriod),
            )),
            const SizedBox(height: 8),
            Row(children: [
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
              const SizedBox(width: 4),
              Text(_isActive ? 'ใช้งาน' : 'ปิดใช้งาน', style: const TextStyle(fontSize: 12)),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('บันทึก'),
        ),
      ],
    );
  }

  Widget _buildRow(String label, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 2),
      child,
    ]);
  }

  InputDecoration _dec({String? hint}) => InputDecoration(
    isDense: true,
    filled: true, fillColor: Colors.white,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}
