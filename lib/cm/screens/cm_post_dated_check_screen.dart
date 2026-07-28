// lib/cm/screens/cm_post_dated_check_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../services/cm_period_service.dart';
import '../../utils/date_utils.dart';

const _kTheme   = Color(0xFF1565C0);
final _fmt      = NumberFormat('#,##0.00', 'en_US');
final _dateFmt  = DateFormat('dd/MM/yyyy');

const Map<String, String> _dirLabels = {
  'RECEIVED': 'รับ (Received)',
  'ISSUED':   'จ่าย (Issued)',
};
const Map<String, String> _statusLabels = {
  'Holding':   'ถือไว้',
  'Deposited': 'นำฝากแล้ว',
  'Cleared':   'เคลียร์แล้ว',
  'Returned':  'คืนแล้ว',
  'Cancelled': 'ยกเลิก',
};
const Map<String, Color> _statusColors = {
  'Holding':   Colors.blue,
  'Deposited': Colors.orange,
  'Cleared':   Colors.green,
  'Returned':  Colors.purple,
  'Cancelled': Colors.grey,
};

class CmPostDatedCheckScreen extends StatefulWidget {
  const CmPostDatedCheckScreen({super.key});
  @override
  State<CmPostDatedCheckScreen> createState() => _CmPostDatedCheckScreenState();
}

class _CmPostDatedCheckScreenState extends State<CmPostDatedCheckScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _panelOpen = true;

  // list filters
  String _filterDir    = '';
  String _filterStatus = 'Holding';

  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  bool _saving  = false;

  // form fields
  String   _fDir       = 'RECEIVED';
  DateTime _fCheckDate = DateTime.now();
  int?     _fBankId;
  int?     _fOurBankId;
  bool     _isNew      = false;

  List<Map<String, dynamic>> _banks = [];

  final _checkNoCtrl    = TextEditingController();
  final _payerPayeeCtrl = TextEditingController();
  final _amountCtrl     = TextEditingController();
  final _remarkCtrl     = TextEditingController();

  // summary
  int    _sumCount  = 0;
  double _sumAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _loadList();
    _loadSummary();
  }

  @override
  void dispose() {
    _checkNoCtrl.dispose();
    _payerPayeeCtrl.dispose();
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async =>
      {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};

  Future<void> _loadBanks() async {
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account'), headers: h);
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as List;
        setState(() => _banks = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final h = await _headers();
      final params = <String, String>{};
      if (_filterDir.isNotEmpty)    params['direction'] = _filterDir;
      if (_filterStatus.isNotEmpty) params['status']    = _filterStatus;
      final uri = Uri.parse('${AppConfig.apiCm}/cm_post_dated_check')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final r = await http.get(uri, headers: h);
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as List;
        setState(() => _list = data.cast<Map<String, dynamic>>());
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadSummary() async {
    try {
      final h = await _headers();
      final r = await http.get(
          Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/summary'), headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        setState(() {
          _sumCount  = (d['total_count'] as num?)?.toInt() ?? 0;
          _sumAmount = (d['total_amount'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {}
  }

  void _startNew() {
    setState(() {
      _selected   = null;
      _isNew      = true;
      _fDir       = 'RECEIVED';
      _fCheckDate = DateTime.now();
      _fBankId    = null;
      _fOurBankId = null;
      _checkNoCtrl.text    = '';
      _payerPayeeCtrl.text = '';
      _amountCtrl.text     = '';
      _remarkCtrl.text     = '';
    });
  }

  void _selectItem(Map<String, dynamic> row) {
    setState(() {
      _selected = row;
      _isNew    = false;
      _fDir       = row['direction'] ?? 'RECEIVED';
      _fCheckDate = parseLocalDate(row['check_date']);
      _fBankId    = row['bank_id'] as int?;
      _fOurBankId = row['our_bank_account_id'] as int?;
      _checkNoCtrl.text    = row['check_no'] ?? '';
      _payerPayeeCtrl.text = row['payee_payer_name'] ?? '';
      _amountCtrl.text     = (row['amount'] as num?)?.toStringAsFixed(2) ?? '';
      _remarkCtrl.text     = row['remark'] ?? '';
    });
  }

  Future<void> _save() async {
    final perm = MenuScope.of(context);
    if (!(_isNew ? (perm?.canCreate ?? true) : (perm?.canEdit ?? true))) return;
    if (_checkNoCtrl.text.trim().isEmpty) { _showErr('กรุณากรอกเลขที่เช็ค'); return; }
    if (_fOurBankId == null) { _showErr('กรุณาเลือกบัญชีธนาคารของเรา'); return; }

    final checkDate = formatLocalDate(_fCheckDate);
    if (!await CmPeriodService.canPost(context, _fCheckDate)) return;

    setState(() => _saving = true);
    try {
      final h = await _headers();
      final body = json.encode({
        'direction':         _fDir,
        'check_no':          _checkNoCtrl.text.trim(),
        'check_date':        checkDate,
        'payee_payer_name':  _payerPayeeCtrl.text.trim(),
        'amount':            double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        'bank_id':           _fBankId,
        'our_bank_account_id': _fOurBankId,
        'remark':            _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      });
      if (_isNew) {
        await http.post(Uri.parse('${AppConfig.apiCm}/cm_post_dated_check'), headers: h, body: body);
      } else {
        await http.put(Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/${_selected!['id']}'),
            headers: h, body: body);
      }
      _showOk(_isNew ? 'เพิ่มเช็คสำเร็จ' : 'แก้ไขเช็คสำเร็จ');
      await _loadList();
      await _loadSummary();
      setState(() { _selected = null; _isNew = false; });
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _action(String action, Map<String, dynamic> row) async {
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    final label = switch (action) {
      'present' => 'นำฝาก',
      'clear'   => 'เคลียร์',
      'return'  => 'คืน',
      'cancel'  => 'ยกเลิก',
      _         => action,
    };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ยืนยัน$label'),
        content: Text('ต้องการ$labelเช็คเลขที่ ${row['check_no']} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final h = await _headers();
      await http.put(
          Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/${row['id']}/$action'), headers: h);
      _showOk('$label สำเร็จ');
      await _loadList();
      await _loadSummary();
      if (_selected?['id'] == row['id']) setState(() => _selected = null);
    } catch (e) { _showErr('$e'); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบ'),
        content: Text('ต้องการลบเช็คเลขที่ ${row['check_no']}?'),
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
      await http.delete(
          Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/${row['id']}'), headers: h);
      _showOk('ลบสำเร็จ');
      await _loadList();
      await _loadSummary();
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
          if (_isNew || (_selected != null && _selected!['status'] == 'Holding'))
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
            width: _panelOpen ? 300 : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: 300,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.blueGrey.shade200,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterDir,
                                decoration: const InputDecoration(
                                    labelText: 'ทิศทาง', isDense: true,
                                    filled: true, fillColor: Colors.white,
                                    border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                items: const [
                                  DropdownMenuItem(value: '', child: Text('ทั้งหมด', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'RECEIVED', child: Text('รับ', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'ISSUED', child: Text('จ่าย', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (v) { setState(() => _filterDir = v ?? ''); _loadList(); },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonFormField<String>(
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
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white, foregroundColor: _kTheme,
                                  padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
                              onPressed: (MenuScope.of(context)?.canCreate ?? true) ? _startNew : null,
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
                      // Summary bar
                      Container(
                        color: Colors.blueGrey.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'ถือไว้: $_sumCount รายการ | ${_fmt.format(_sumAmount)} บาท',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                        ),
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
                                    final chkDate = parseLocalDateNullable(row['check_date']);
                                    final status = row['status'] as String? ?? '';
                                    return InkWell(
                                      onTap: () => _selectItem(row),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        color: sel ? _kTheme.withOpacity(0.12) : null,
                                        child: Row(children: [
                                          Expanded(child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(row['check_no'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              Text(row['payee_payer_name'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                                              Text(
                                                chkDate != null ? _dateFmt.format(chkDate) : '',
                                                style: const TextStyle(fontSize: 10, color: Colors.black45),
                                              ),
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
                                            Text(row['direction'] == 'RECEIVED' ? 'รับ' : 'จ่าย',
                                                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
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
    if (_isNew || (_selected != null && _selected!['status'] == 'Holding')) {
      return _buildForm();
    }
    if (_selected != null) {
      return _buildDetail(_selected!);
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long, size: 64, color: Colors.blueGrey.shade200),
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
        Text(_isNew ? 'เพิ่มเช็คล่วงหน้าใหม่' : 'แก้ไขเช็คล่วงหน้า',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _field('ทิศทาง *', SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: _fDir,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: _dirLabels.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _fDir = v ?? 'RECEIVED'),
            ),
          )),
          _field('เลขที่เช็ค *', SizedBox(
            width: 200,
            child: TextField(controller: _checkNoCtrl, decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
          )),
          _field('วันที่บนเช็ค *', _datePicker(_fCheckDate, (d) => setState(() => _fCheckDate = d))),
          _field('ชื่อผู้รับ/จ่าย', SizedBox(
            width: 260,
            child: TextField(controller: _payerPayeeCtrl, decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
          )),
          _field('จำนวนเงิน (บาท)', SizedBox(
            width: 160,
            child: TextField(controller: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
          )),
          _field('บัญชีธนาคารของเรา *', SizedBox(
            width: 260,
            child: DropdownButtonFormField<int?>(
              value: _fOurBankId,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              hint: const Text('เลือกบัญชี', style: TextStyle(fontSize: 12)),
              items: _banks.map((b) => DropdownMenuItem<int?>(
                  value: b['id'] as int?,
                  child: Text('${b['account_code'] ?? ''} - ${b['account_name'] ?? ''}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _fOurBankId = v),
            ),
          )),
          _field('หมายเหตุ', SizedBox(
            width: 300,
            child: TextField(controller: _remarkCtrl, maxLines: 2,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
          )),
        ]),
      ]),
    );
  }

  Widget _buildDetail(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? '';
    final chkDate = parseLocalDateNullable(row['check_date']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('เช็คเลขที่ ${row['check_no'] ?? ''}',
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
          _infoRow('ทิศทาง', _dirLabels[row['direction']] ?? row['direction'] ?? ''),
          _infoRow('วันที่บนเช็ค', chkDate != null ? _dateFmt.format(chkDate) : ''),
          _infoRow('ชื่อผู้รับ/จ่าย', row['payee_payer_name'] ?? ''),
          _infoRow('จำนวนเงิน', '${_fmt.format((row['amount'] as num?)?.toDouble() ?? 0)} บาท'),
          _infoRow('บัญชีธนาคารของเรา', '${row['our_account_code'] ?? ''} ${row['our_account_name'] ?? ''}'.trim()),
          if (row['remark'] != null && (row['remark'] as String).isNotEmpty)
            _infoRow('หมายเหตุ', row['remark'] as String),
        ]),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          if (status == 'Holding') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('present', row),
              child: const Text('นำฝาก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('cancel', row),
              child: const Text('ยกเลิก'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _delete(row),
              child: const Text('ลบ'),
            ),
          ],
          if (status == 'Deposited') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('clear', row),
              child: const Text('เคลียร์'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('return', row),
              child: const Text('คืน'),
            ),
          ],
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
