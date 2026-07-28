// lib/cm/screens/cm_check_print_config_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../cm/models/cm_bank_account.dart';

const _kTheme = Color(0xFF1565C0);
final _numFmt  = NumberFormat('#,##0.##', 'en_US');

class CmCheckPrintConfigScreen extends StatefulWidget {
  const CmCheckPrintConfigScreen({super.key});
  @override
  State<CmCheckPrintConfigScreen> createState() => _State();
}

class _State extends State<CmCheckPrintConfigScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;

  List<CmBankAccount> _accounts    = [];
  CmBankAccount?      _selAccount;
  bool _loadingAccounts = false;

  List<Map<String, dynamic>> _configs     = [];
  Map<String, dynamic>?      _selConfig;
  bool _loadingConfigs = false;
  bool _saving         = false;
  bool _isNew          = false;

  // Form controllers
  final _configNameCtrl   = TextEditingController();
  final _paperWCtrl       = TextEditingController(text: '210');
  final _paperHCtrl       = TextEditingController(text: '99');
  final _dateXCtrl        = TextEditingController(text: '150');
  final _dateYCtrl        = TextEditingController(text: '18');
  final _dateFmtCtrl      = TextEditingController(text: 'dd/MM/yyyy');
  final _payeeXCtrl       = TextEditingController(text: '35');
  final _payeeYCtrl       = TextEditingController(text: '38');
  final _amtNumXCtrl      = TextEditingController(text: '155');
  final _amtNumYCtrl      = TextEditingController(text: '38');
  final _amtTxtXCtrl      = TextEditingController(text: '20');
  final _amtTxtYCtrl      = TextEditingController(text: '55');
  final _stubWCtrl        = TextEditingController(text: '50');
  bool _hasStub    = false;
  bool _isDefault  = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    for (final c in [_configNameCtrl, _paperWCtrl, _paperHCtrl,
        _dateXCtrl, _dateYCtrl, _dateFmtCtrl,
        _payeeXCtrl, _payeeYCtrl, _amtNumXCtrl, _amtNumYCtrl,
        _amtTxtXCtrl, _amtTxtYCtrl, _stubWCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = (json.decode(resp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .where((a) => a.cmType == 'BANK')
            .toList();
        setState(() { _accounts = all; _loadingAccounts = false; });
        if (all.isNotEmpty) {
          _selAccount = all.first;
          await _loadConfigs(all.first.id!);
        }
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadConfigs(int bankAccountId) async {
    setState(() { _loadingConfigs = true; _configs = []; _selConfig = null; _isNew = false; });
    try {
      final headers = await AuthService().getAuthHeader();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_check_print_config')
          .replace(queryParameters: {'bank_account_id': bankAccountId.toString()});
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _configs = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingConfigs = false;
          if (_configs.isNotEmpty) _selectConfig(_configs.first);
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingConfigs = false);
      _showError(e.toString());
    }
  }

  void _selectConfig(Map<String, dynamic> cfg) {
    setState(() {
      _selConfig = cfg;
      _isNew     = false;
      _configNameCtrl.text = cfg['config_name'] ?? '';
      _paperWCtrl.text     = cfg['paper_width_mm']?.toString()  ?? '210';
      _paperHCtrl.text     = cfg['paper_height_mm']?.toString() ?? '99';
      _dateXCtrl.text      = cfg['date_x']?.toString()          ?? '150';
      _dateYCtrl.text      = cfg['date_y']?.toString()          ?? '18';
      _dateFmtCtrl.text    = cfg['date_format']?.toString()     ?? 'dd/MM/yyyy';
      _payeeXCtrl.text     = cfg['payee_x']?.toString()         ?? '35';
      _payeeYCtrl.text     = cfg['payee_y']?.toString()         ?? '38';
      _amtNumXCtrl.text    = cfg['amount_num_x']?.toString()    ?? '155';
      _amtNumYCtrl.text    = cfg['amount_num_y']?.toString()    ?? '38';
      _amtTxtXCtrl.text    = cfg['amount_text_x']?.toString()   ?? '20';
      _amtTxtYCtrl.text    = cfg['amount_text_y']?.toString()   ?? '55';
      _stubWCtrl.text      = cfg['stub_width_mm']?.toString()   ?? '50';
      _hasStub    = cfg['has_stub'] == true;
      _isDefault  = cfg['is_default'] == true;
    });
  }

  void _newConfig() {
    setState(() {
      _selConfig = null;
      _isNew = true;
      _configNameCtrl.text = '';
      _paperWCtrl.text  = '210';
      _paperHCtrl.text  = '99';
      _dateXCtrl.text   = '150';
      _dateYCtrl.text   = '18';
      _dateFmtCtrl.text = 'dd/MM/yyyy';
      _payeeXCtrl.text  = '35';
      _payeeYCtrl.text  = '38';
      _amtNumXCtrl.text = '155';
      _amtNumYCtrl.text = '38';
      _amtTxtXCtrl.text = '20';
      _amtTxtYCtrl.text = '55';
      _stubWCtrl.text   = '50';
      _hasStub   = false;
      _isDefault = false;
    });
  }

  Future<void> _save() async {
    final perm = MenuScope.of(context);
    if (!(_isNew ? (perm?.canCreate ?? true) : (perm?.canEdit ?? true))) return;
    if (_selAccount == null) return;
    if (_configNameCtrl.text.trim().isEmpty) {
      _showError('กรุณาระบุชื่อ config');
      return;
    }
    setState(() => _saving = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      final body = json.encode({
        'bank_account_id':  _selAccount!.id,
        'config_name':      _configNameCtrl.text.trim(),
        'paper_width_mm':   double.tryParse(_paperWCtrl.text)  ?? 210,
        'paper_height_mm':  double.tryParse(_paperHCtrl.text)  ?? 99,
        'date_x':           double.tryParse(_dateXCtrl.text)   ?? 150,
        'date_y':           double.tryParse(_dateYCtrl.text)   ?? 18,
        'date_format':      _dateFmtCtrl.text.trim(),
        'payee_x':          double.tryParse(_payeeXCtrl.text)  ?? 35,
        'payee_y':          double.tryParse(_payeeYCtrl.text)  ?? 38,
        'amount_num_x':     double.tryParse(_amtNumXCtrl.text) ?? 155,
        'amount_num_y':     double.tryParse(_amtNumYCtrl.text) ?? 38,
        'amount_text_x':    double.tryParse(_amtTxtXCtrl.text) ?? 20,
        'amount_text_y':    double.tryParse(_amtTxtYCtrl.text) ?? 55,
        'has_stub':         _hasStub,
        'stub_width_mm':    double.tryParse(_stubWCtrl.text)   ?? 50,
        'is_default':       _isDefault,
      });
      http.Response resp;
      if (_isNew) {
        resp = await http.post(Uri.parse('${AppConfig.apiCm}/cm_check_print_config'),
            headers: headers, body: body);
      } else {
        resp = await http.put(
            Uri.parse('${AppConfig.apiCm}/cm_check_print_config/${_selConfig!['id']}'),
            headers: headers, body: body);
      }
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isNew ? 'เพิ่ม config แล้ว' : 'บันทึกแล้ว'),
                backgroundColor: Colors.green.shade700));
        await _loadConfigs(_selAccount!.id!);
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> cfg) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบ'),
        content: Text('ลบ config "${cfg['config_name']}" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.delete(
          Uri.parse('${AppConfig.apiCm}/cm_check_print_config/${cfg['id']}'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('ลบแล้ว'), backgroundColor: Colors.green.shade700));
        await _loadConfigs(_selAccount!.id!);
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
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
            width: _leftExpanded ? 240 : 0,
            child: ClipRect(child: OverflowBox(
              alignment: Alignment.centerLeft, maxWidth: 240,
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text('บัญชีธนาคาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: _loadingAccounts
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _accounts.length,
                itemBuilder: (_, i) {
                  final a = _accounts[i];
                  final sel = _selAccount?.id == a.id;
                  return InkWell(
                    onTap: () async {
                      setState(() { _selAccount = a; });
                      await _loadConfigs(a.id!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: sel ? _kTheme.withOpacity(0.12) : null,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.accountCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: sel ? _kTheme : Colors.black87)),
                        Text('${a.accountNameTh} (${a.bankShortName})',
                            style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ]),
                    ),
                  );
                },
              )),
      ]),
    );
  }

  Widget _buildRightPanel() {
    if (_selAccount == null) {
      return const Center(child: Text('เลือกบัญชีธนาคาร', style: TextStyle(color: Colors.grey)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Config list header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.grey.shade50,
        child: Row(children: [
          Text('Config ของ ${_selAccount!.accountCode}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            onPressed: _newConfig,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('เพิ่ม Config', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
      const Divider(height: 1),
      // Config list
      if (_loadingConfigs)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
      else if (_configs.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 32, dataRowMinHeight: 30, dataRowMaxHeight: 36,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            columns: const [
              DataColumn(label: Text('ชื่อ Config')),
              DataColumn(label: Text('กระดาษ (mm)')),
              DataColumn(label: Text('Default')),
              DataColumn(label: Text('')),
            ],
            rows: _configs.map((c) {
              final sel = _selConfig?['id'] == c['id'];
              return DataRow(
                selected: sel,
                color: WidgetStateProperty.resolveWith((_) => sel ? _kTheme.withOpacity(0.08) : null),
                onSelectChanged: (_) => _selectConfig(c),
                cells: [
                  DataCell(Text(c['config_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(
                    '${_numFmt.format(double.tryParse(c['paper_width_mm']?.toString() ?? '210') ?? 210)}'
                    ' × ${_numFmt.format(double.tryParse(c['paper_height_mm']?.toString() ?? '99') ?? 99)}',
                    style: const TextStyle(fontSize: 12),
                  )),
                  DataCell(c['is_default'] == true
                      ? Icon(Icons.star, size: 16, color: Colors.amber.shade700)
                      : const SizedBox.shrink()),
                  DataCell(IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                    onPressed: () => _delete(c),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28),
                    tooltip: 'ลบ',
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      const Divider(),
      // Form
      Expanded(child: (_selConfig != null || _isNew) ? _buildForm() : const Center(
        child: Text('เลือก config หรือกด "เพิ่ม Config"', style: TextStyle(color: Colors.grey)),
      )),
    ]);
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isNew ? 'เพิ่ม Config ใหม่' : 'แก้ไข Config',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _formRow('ชื่อ Config *', _configNameCtrl, isText: true, width: 240),
        const SizedBox(height: 8),
        Row(children: [
          _formRow('กระดาษกว้าง (mm)', _paperWCtrl, width: 120),
          const SizedBox(width: 16),
          _formRow('กระดาษสูง (mm)', _paperHCtrl, width: 120),
        ]),
        const SizedBox(height: 12),
        const Text('ตำแหน่งฟิลด์ (mm จากมุมซ้ายบน)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        _positionRow('วันที่', _dateXCtrl, _dateYCtrl),
        const SizedBox(height: 4),
        _formRow('รูปแบบวันที่', _dateFmtCtrl, isText: true, width: 140,
            hint: 'dd/MM/yyyy'),
        const SizedBox(height: 8),
        _positionRow('ชื่อผู้รับเงิน', _payeeXCtrl, _payeeYCtrl),
        const SizedBox(height: 8),
        _positionRow('จำนวนเงิน (ตัวเลข)', _amtNumXCtrl, _amtNumYCtrl),
        const SizedBox(height: 8),
        _positionRow('จำนวนเงิน (ตัวอักษร)', _amtTxtXCtrl, _amtTxtYCtrl),
        const SizedBox(height: 12),
        Row(children: [
          Checkbox(value: _hasStub, onChanged: (v) => setState(() => _hasStub = v ?? false),
              visualDensity: VisualDensity.compact),
          const Text('มี Stub', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 16),
          if (_hasStub) ...[
            _formRow('ความกว้าง Stub (mm)', _stubWCtrl, width: 120),
          ],
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Checkbox(value: _isDefault, onChanged: (v) => setState(() => _isDefault = v ?? false),
              visualDensity: VisualDensity.compact),
          const Text('ใช้เป็น Default', style: TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 16),
            label: const Text('บันทึก', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _formRow(String label, TextEditingController ctrl,
      {bool isText = false, double width = 100, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 2),
      SizedBox(
        width: width,
        child: TextField(
          controller: ctrl,
          keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: const OutlineInputBorder(),
            filled: true, fillColor: Colors.white,
            hintText: hint,
          ),
        ),
      ),
    ]);
  }

  Widget _positionRow(String label, TextEditingController xCtrl, TextEditingController yCtrl) {
    return Row(children: [
      SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 12))),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('X (mm)', style: TextStyle(fontSize: 10, color: Colors.black45)),
        SizedBox(
          width: 80,
          child: TextField(
            controller: xCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
          ),
        ),
      ]),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Y (mm)', style: TextStyle(fontSize: 10, color: Colors.black45)),
        SizedBox(
          width: 80,
          child: TextField(
            controller: yCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
          ),
        ),
      ]),
    ]);
  }
}
