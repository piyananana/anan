// lib/cm/screens/cm_gl_account_setup_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../services/cm_gl_account_setup_service.dart';

const _kTheme = Color(0xFF1565C0);

class CmGlAccountSetupScreen extends StatefulWidget {
  const CmGlAccountSetupScreen({super.key});
  @override
  State<CmGlAccountSetupScreen> createState() => _State();
}

class _State extends State<CmGlAccountSetupScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = CmGlAccountSetupService();
  List<Map<String, dynamic>> _rows     = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _docTypes = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.fetchRows(),
        _fetchGlAccounts(),
        _fetchGlDocTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows     = results[0] as List<Map<String, dynamic>>;
        _accounts = results[1] as List<Map<String, dynamic>>;
        _docTypes = results[2] as List<Map<String, dynamic>>;
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGlAccounts() async {
    final headers = await AuthService().getAuthHeader();
    final resp = await http.get(Uri.parse('${AppConfig.apiGl}/gl_account'), headers: headers);
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
  }

  Future<List<Map<String, dynamic>>> _fetchGlDocTypes() async {
    final headers = await AuthService().getAuthHeader();
    final resp = await http.get(Uri.parse('${AppConfig.apiSa}/sa_module_document'), headers: headers);
    if (resp.statusCode != 200) return [];
    final all = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
    return all.where((d) =>
        (d['is_doc_type'] == true || d['is_doc_type'] == 1) &&
        d['sys_module'] == '01' &&
        (d['is_active'] == true || d['is_active'] == 1)).toList();
  }

  Future<void> _editRow(Map<String, dynamic> row) async {
    final isAccount = row['setup_type'] == 'GL_ACCOUNT';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => isAccount
          ? _GlAccountPickerDialog(accounts: _accounts, current: row)
          : _GlDocTypePickerDialog(docTypes: _docTypes, current: row),
    );
    if (result == null) return;
    try {
      await _svc.upsertRow(
        row['setup_key'],
        glAccountId: result['gl_account_id'],
        glDocId:     result['gl_doc_id'],
      );
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกแล้ว'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _clearRow(Map<String, dynamic> row) async {
    try {
      await _svc.upsertRow(row['setup_key']);
      await _loadAll();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
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
        title: const Text('ตั้งค่า GL Account — CM'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'โหลดใหม่',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'กำหนด GL Account และ GL Doc Type เริ่มต้นสำหรับ CM Module',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 60,
                        columnSpacing: 20,
                        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                        columns: const [
                          DataColumn(label: Text('รายการ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          DataColumn(label: Text('ค่าที่ตั้ง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          DataColumn(label: Text('', style: TextStyle(fontSize: 13))),
                        ],
                        rows: _rows.map((row) {
                          final hasValue = row['gl_account_id'] != null || row['gl_doc_id'] != null;
                          final valueText = row['setup_type'] == 'GL_ACCOUNT'
                              ? (row['gl_account_code'] != null
                                  ? '${row['gl_account_code']} - ${row['gl_account_name']}'
                                  : '— ยังไม่กำหนด —')
                              : (row['gl_doc_code'] != null
                                  ? '${row['gl_doc_code']} - ${row['gl_doc_name']}'
                                  : '— ยังไม่กำหนด —');

                          return DataRow(cells: [
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(row['setup_label'] ?? row['setup_key'],
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                Text(row['setup_type'] == 'GL_ACCOUNT' ? 'GL Account' : 'GL Doc Type',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            )),
                            DataCell(Text(
                              valueText,
                              style: TextStyle(
                                fontSize: 13,
                                color: hasValue ? Colors.black87 : Colors.grey.shade400,
                                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                              ),
                            )),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'แก้ไข',
                                color: _kTheme,
                                onPressed: () => _editRow(row),
                              ),
                              if (hasValue)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'ล้างค่า',
                                  color: Colors.red.shade400,
                                  onPressed: () => _clearRow(row),
                                ),
                            ])),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── GL Account Picker Dialog ────────────────────────────────────────────────

class _GlAccountPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic> current;
  const _GlAccountPickerDialog({required this.accounts, required this.current});
  @override
  State<_GlAccountPickerDialog> createState() => _GlAccountPickerDialogState();
}

class _GlAccountPickerDialogState extends State<_GlAccountPickerDialog> {
  String _search = '';
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    final curId = widget.current['gl_account_id'];
    if (curId != null) {
      try {
        _selected = widget.accounts.firstWhere((a) => a['id'] == curId);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.accounts.where((a) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (a['account_code']?.toString().toLowerCase().contains(q) ?? false) ||
             (a['account_name_thai']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return Dialog(
      child: SizedBox(
        width: 480, height: 480,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1565C0),
            child: const Text('เลือก GL Account',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(isDense: true, hintText: 'ค้นหา...',
                  prefixIcon: Icon(Icons.search, size: 18), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final acc = filtered[i];
                final sel = acc['id'] == _selected?['id'];
                return ListTile(
                  dense: true, selected: sel,
                  selectedTileColor: const Color(0xFF1565C0).withOpacity(0.1),
                  title: Text('${acc['account_code']} - ${acc['account_name_thai'] ?? ''}',
                      style: const TextStyle(fontSize: 13)),
                  onTap: () => setState(() => _selected = acc),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                onPressed: _selected == null ? null : () => Navigator.pop(context, {'gl_account_id': _selected!['id']}),
                child: const Text('เลือก'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── GL Doc Type Picker Dialog ────────────────────────────────────────────────

class _GlDocTypePickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> docTypes;
  final Map<String, dynamic> current;
  const _GlDocTypePickerDialog({required this.docTypes, required this.current});
  @override
  State<_GlDocTypePickerDialog> createState() => _GlDocTypePickerDialogState();
}

class _GlDocTypePickerDialogState extends State<_GlDocTypePickerDialog> {
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    final curId = widget.current['gl_doc_id'];
    if (curId != null) {
      try {
        _selected = widget.docTypes.firstWhere((d) => d['id'] == curId);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400, height: 360,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16), color: const Color(0xFF1565C0),
            child: const Text('เลือก GL Doc Type',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.docTypes.length,
              itemBuilder: (_, i) {
                final d = widget.docTypes[i];
                final sel = d['id'] == _selected?['id'];
                return ListTile(
                  dense: true, selected: sel,
                  selectedTileColor: const Color(0xFF1565C0).withOpacity(0.1),
                  title: Text('${d['doc_code']} - ${d['doc_name_thai'] ?? d['doc_name'] ?? ''}',
                      style: const TextStyle(fontSize: 13)),
                  onTap: () => setState(() => _selected = d),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                onPressed: _selected == null ? null : () => Navigator.pop(context, {'gl_doc_id': _selected!['id']}),
                child: const Text('เลือก'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
