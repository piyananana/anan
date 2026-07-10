// lib/cm/screens/cm_bank_charge_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';
import '../services/cm_period_service.dart';

const _kTheme  = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

const Map<String, String> _typeLabels = {
  'BANK_CHARGE':       'ค่าธรรมเนียมธนาคาร',
  'INTEREST_INCOME':   'ดอกเบี้ยรับ',
  'INTEREST_EXPENSE':  'ดอกเบี้ยจ่าย',
  'OTHER':             'อื่นๆ',
};
const Map<String, String> _statusLabels = {
  'Draft':  'ร่าง',
  'Posted': 'บันทึก GL แล้ว',
  'Voided': 'ยกเลิก',
};
const Map<String, Color> _statusColors = {
  'Draft':  Colors.orange,
  'Posted': Colors.green,
  'Voided': Colors.grey,
};

class CmBankChargeScreen extends StatefulWidget {
  const CmBankChargeScreen({super.key});
  @override
  State<CmBankChargeScreen> createState() => _CmBankChargeScreenState();
}

class _CmBankChargeScreenState extends State<CmBankChargeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _panelOpen = true;

  String _filterStatus = 'Draft';

  List<Map<String, dynamic>> _list  = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  bool _saving  = false;
  bool _isNew   = false;

  // form fields
  int?     _fBankAccId;
  DateTime _fChargeDate = DateTime.now();
  String   _fChargeType = 'BANK_CHARGE';
  int?     _fGlAccId;

  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _glAccounts   = [];

  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
    _loadGlAccounts();
    _loadList();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async =>
      {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};

  Future<void> _loadBankAccounts() async {
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account'), headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() => _bankAccounts = d.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadGlAccounts() async {
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('${AppConfig.apiGl}/gl_account'), headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() => _glAccounts = d.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final h = await _headers();
      final params = _filterStatus.isNotEmpty ? {'status': _filterStatus} : <String, String>{};
      final uri = Uri.parse('${AppConfig.apiCm}/cm_bank_charge')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final r = await http.get(uri, headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() => _list = d.cast<Map<String, dynamic>>());
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _startNew() {
    setState(() {
      _selected     = null;
      _isNew        = true;
      _fBankAccId   = null;
      _fChargeDate  = DateTime.now();
      _fChargeType  = 'BANK_CHARGE';
      _fGlAccId     = null;
      _amountCtrl.text = '';
      _descCtrl.text   = '';
    });
  }

  void _selectItem(Map<String, dynamic> row) {
    setState(() {
      _selected     = row;
      _isNew        = false;
      _fBankAccId   = row['bank_account_id'] as int?;
      _fChargeType  = row['charge_type'] ?? 'BANK_CHARGE';
      _fGlAccId     = row['gl_account_id'] as int?;
      _amountCtrl.text = (row['amount'] as num?)?.toStringAsFixed(2) ?? '';
      _descCtrl.text   = row['description'] ?? '';
      try { _fChargeDate = DateTime.parse(row['charge_date'].toString()); } catch (_) {}
    });
  }

  Future<void> _save() async {
    if (_fBankAccId == null) { _showErr('กรุณาเลือกบัญชีธนาคาร'); return; }
    if (!await CmPeriodService.canPost(context, _fChargeDate)) return;
    setState(() => _saving = true);
    try {
      final h = await _headers();
      final body = json.encode({
        'bank_account_id': _fBankAccId,
        'charge_date':     DateFormat('yyyy-MM-dd').format(_fChargeDate),
        'charge_type':     _fChargeType,
        'amount':          double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        'gl_account_id':   _fGlAccId,
        'description':     _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      });
      if (_isNew) {
        await http.post(Uri.parse('${AppConfig.apiCm}/cm_bank_charge'), headers: h, body: body);
      } else {
        await http.put(Uri.parse('${AppConfig.apiCm}/cm_bank_charge/${_selected!['id']}'),
            headers: h, body: body);
      }
      _showOk(_isNew ? 'เพิ่มรายการสำเร็จ' : 'แก้ไขสำเร็จ');
      await _loadList();
      setState(() { _selected = null; _isNew = false; });
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _post(Map<String, dynamic> row) async {
    DateTime chargeDate = DateTime.now();
    try { chargeDate = DateTime.parse(row['charge_date'].toString()); } catch (_) {}
    if (!await CmPeriodService.canPost(context, chargeDate)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยัน Post GL'),
        content: Text('ต้องการบันทึก GL สำหรับรายการ ${_typeLabels[row['charge_type']] ?? ''} '
            '${_fmt.format((row['amount'] as num?)?.toDouble() ?? 0)} บาท?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post GL'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final h = await _headers();
      await http.put(Uri.parse('${AppConfig.apiCm}/cm_bank_charge/${row['id']}/post'), headers: h);
      _showOk('Post GL สำเร็จ');
      await _loadList();
      if (_selected?['id'] == row['id']) setState(() => _selected = null);
    } catch (e) { _showErr('$e'); }
  }

  Future<void> _void(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันยกเลิก'),
        content: const Text('ต้องการยกเลิกรายการนี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final h = await _headers();
      await http.put(Uri.parse('${AppConfig.apiCm}/cm_bank_charge/${row['id']}/void'), headers: h);
      _showOk('ยกเลิกสำเร็จ');
      await _loadList();
      if (_selected?['id'] == row['id']) setState(() => _selected = null);
    } catch (e) { _showErr('$e'); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบ'),
        content: const Text('ต้องการลบรายการนี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final h = await _headers();
      await http.delete(Uri.parse('${AppConfig.apiCm}/cm_bank_charge/${row['id']}'), headers: h);
      _showOk('ลบสำเร็จ');
      await _loadList();
      if (_selected?['id'] == row['id']) setState(() => _selected = null);
    } catch (e) { _showErr('$e'); }
  }

  void _showOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700));
  }

  void _showErr(String msg) {
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
        toolbarHeight: 40,
        title: const MenuTitle(),
        actions: [
          if (_isNew || (_selected != null && _selected!['status'] == 'Draft'))
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save, size: 16),
              label: const Text('บันทึก', style: TextStyle(fontSize: 13)),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => setState(() { _selected = null; _isNew = false; }),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('ยกเลิก', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle strip
          Container(
            width: 36,
            color: _kTheme,
            child: Column(children: [
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: Colors.white,
                icon: Icon(_panelOpen ? Icons.chevron_left : Icons.chevron_right),
                onPressed: () => setState(() => _panelOpen = !_panelOpen),
              ),
            ]),
          ),
          // Left panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _panelOpen ? 280 : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: 280,
                child: SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.blueGrey.shade200,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(children: [
                          DropdownButtonFormField<String>(
                            value: _filterStatus,
                            decoration: const InputDecoration(
                                labelText: 'สถานะ', isDense: true,
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('ทั้งหมด', style: TextStyle(fontSize: 12))),
                              ..._statusLabels.entries.map((e) =>
                                  DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))),
                            ],
                            onChanged: (v) { setState(() => _filterStatus = v ?? ''); _loadList(); },
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white, foregroundColor: _kTheme,
                                  padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
                              onPressed: _startNew,
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('เพิ่มใหม่', style: TextStyle(fontSize: 12)),
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
                              onPressed: _loadList,
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('รีเฟรช', style: TextStyle(fontSize: 12)),
                            )),
                          ]),
                        ]),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.blueGrey.shade100,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: _list.length,
                                  itemBuilder: (_, i) {
                                    final row = _list[i];
                                    final sel = _selected?['id'] == row['id'];
                                    final status = row['status'] as String? ?? '';
                                    DateTime? dt;
                                    try { dt = DateTime.parse(row['charge_date'].toString()); } catch (_) {}
                                    return InkWell(
                                      onTap: () => _selectItem(row),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        color: sel ? _kTheme.withOpacity(0.12) : null,
                                        child: Row(children: [
                                          Expanded(child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_typeLabels[row['charge_type']] ?? row['charge_type'] ?? '',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              Text('${row['bank_account_code'] ?? ''} ${row['bank_account_name'] ?? ''}'.trim(),
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                  overflow: TextOverflow.ellipsis),
                                              Text(dt != null ? _dateFmt.format(dt) : '',
                                                  style: const TextStyle(fontSize: 10, color: Colors.black45)),
                                            ],
                                          )),
                                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                            Text(_fmt.format((row['amount'] as num?)?.toDouble() ?? 0),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: (_statusColors[status] ?? Colors.grey).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _statusColors[status] ?? Colors.grey),
                                              ),
                                              child: Text(_statusLabels[status] ?? status,
                                                  style: TextStyle(fontSize: 9, color: _statusColors[status] ?? Colors.grey)),
                                            ),
                                          ]),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Right panel
          Expanded(child: _buildRight()),
        ],
      ),
    );
  }

  Widget _buildRight() {
    if (_isNew || (_selected != null && _selected!['status'] == 'Draft')) {
      return _buildForm();
    }
    if (_selected != null) {
      return _buildDetail(_selected!);
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_balance, size: 64, color: Colors.blueGrey.shade200),
        const SizedBox(height: 12),
        Text('เลือกรายการจากแผงซ้าย หรือกด "เพิ่มใหม่"',
            style: TextStyle(color: Colors.blueGrey.shade400)),
      ]),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isNew ? 'เพิ่มรายการใหม่' : 'แก้ไขรายการ',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _field('บัญชีธนาคาร *', SizedBox(
            width: 280,
            child: DropdownButtonFormField<int?>(
              value: _fBankAccId,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              hint: const Text('เลือกบัญชี', style: TextStyle(fontSize: 12)),
              items: _bankAccounts.map((b) => DropdownMenuItem<int?>(
                  value: b['id'] as int?,
                  child: Text('${b['account_code'] ?? ''} - ${b['account_name'] ?? ''}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _fBankAccId = v),
            ),
          )),
          _field('วันที่ *', _datePicker(_fChargeDate, (d) => setState(() => _fChargeDate = d))),
          _field('ประเภท *', SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _fChargeType,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: _typeLabels.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _fChargeType = v ?? 'BANK_CHARGE'),
            ),
          )),
          _field('จำนวนเงิน (บาท)', SizedBox(
            width: 160,
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            ),
          )),
          _field('บัญชี GL', SizedBox(
            width: 280,
            child: DropdownButtonFormField<int?>(
              value: _fGlAccId,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              hint: const Text('เลือกบัญชี GL', style: TextStyle(fontSize: 12)),
              items: _glAccounts.map((a) => DropdownMenuItem<int?>(
                  value: a['id'] as int?,
                  child: Text('${a['account_code'] ?? ''} - ${a['account_name'] ?? ''}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _fGlAccId = v),
            ),
          )),
          _field('คำอธิบาย', SizedBox(
            width: 320,
            child: TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _buildDetail(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? '';
    DateTime? dt;
    try { dt = DateTime.parse(row['charge_date'].toString()); } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_typeLabels[row['charge_type']] ?? row['charge_type'] ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: (_statusColors[status] ?? Colors.grey).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _statusColors[status] ?? Colors.grey),
            ),
            child: Text(_statusLabels[status] ?? status,
                style: TextStyle(fontSize: 12, color: _statusColors[status] ?? Colors.grey)),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 24, runSpacing: 8, children: [
          _infoRow('บัญชีธนาคาร', '${row['bank_account_code'] ?? ''} ${row['bank_account_name'] ?? ''}'.trim()),
          _infoRow('วันที่', dt != null ? _dateFmt.format(dt) : ''),
          _infoRow('จำนวนเงิน', '${_fmt.format((row['amount'] as num?)?.toDouble() ?? 0)} บาท'),
          if (row['gl_account_name'] != null)
            _infoRow('บัญชี GL', '${row['gl_account_code'] ?? ''} ${row['gl_account_name'] ?? ''}'.trim()),
          if (row['gl_doc_no'] != null)
            _infoRow('GL Doc No', row['gl_doc_no'] as String),
          if (row['description'] != null && (row['description'] as String).isNotEmpty)
            _infoRow('คำอธิบาย', row['description'] as String),
        ]),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          if (status == 'Draft') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
              onPressed: () => _post(row),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Post GL'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => _delete(row),
              child: const Text('ลบ'),
            ),
          ],
          if (status == 'Posted')
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => _void(row),
              child: const Text('ยกเลิก (Void)'),
            ),
        ]),
      ]),
    );
  }

  Widget _field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 3),
      child,
    ],
  );

  Widget _infoRow(String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _datePicker(DateTime value, void Function(DateTime) onPick) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: value,
              firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) onPick(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_dateFmt.format(value), style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
          ]),
        ),
      );
}
